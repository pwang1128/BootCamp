// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

abstract contract Stages {
	enum stages {ADMISSION, VIEW_N_TRADE, VOTING}
	stages internal curStage;
	uint internal stageStartTime;
	constructor() {
      	curStage = stages.ADMISSION;
		stageStartTime = block.timestamp;
	}

    // Helper functions
    
    function strcmp(string memory a, string memory b) internal pure returns (bool){
        return (keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b)));
    }
    
    uint constant admissionDuration =  1 weeks;
    uint constant viewntradeDuration = 10 days 
    uint constant votingDuration = 4 days; 
    function reward () internal virtual {} 

    //return the current stage
    function getStage () public view returns (string memory) {
        if (curStage == stages.ADMISSION) return "Stage 1: Admission";
        else if (curStage == stages.VIEW_N_TRADE) return "Stage 2: View and Trade NFT";
        else  return "Stage 3: Vote the Best NFT";
    }

}



contract NFTCompetition is Stages{
    
    address ownerSC; // owner of the smart contract
    constructor(){
        ownerSC = msg.sender;
    }
    

    uint public admissionFee = 0.0003 ether;
    uint private totalAdmissionFee = 0 ether;           // total admission fee collected 

    mapping(address => bool) public paidAdmitFee;      // whether an address has paid admission fee
    address [] private partiList;                   // participants list
    uint8 public nParti;                        // = no of participants = no of total NFT submission
    mapping(address => uint) public accBalance;    // check the account balance of an address
    mapping(address => bool) public voted;         // whether an account has voted
    mapping(uint8 => string) public viewNFT;
    mapping(address => bool) public participated;
    mapping(string => uint) public bidPrice;

    struct NFT {string link; address owner; uint8 nVote; address bidder;}
    mapping(uint8 => NFT) private NFTInfo;


    // The following 3 will be executed by potential participants/ participants in order to proceed to next stage after certain period
	function Admission_To_ViewNTrade () external payable returns (bool) {
        require (curStage == stages.ADMISSION);
        if (block.timestamp > stageStartTime + admissionDuration) {
            stageStartTime =  block.timestamp;
            curStage = stages.VIEW_N_TRADE;
            payable(msg.sender).transfer(tx.gasprice); // provide an incentive for anybody to help proceed the competition
            return true;
        }
        return false;
    }
	function ViewNTrade_To_Voting () external payable returns (bool){
        require (curStage == stages.VIEW_N_TRADE);
        if (block.timestamp > stageStartTime + viewntradeDuration) {
            stageStartTime =  block.timestamp;
            curStage = stages.VOTING;
            payable(msg.sender).transfer(tx.gasprice);
            return true;
        }
        return false;
    }
	function AnnounceResult () external returns (bool){ 
        require (curStage == stages.VOTING);
        if (block.timestamp > stageStartTime + votingDuration) {
            stageStartTime =  block.timestamp;
            reward();
            curStage = stages.ADMISSION;
            payable(msg.sender).transfer(tx.gasprice);
            return true;
        }
        return false;
    }

    // Helper function: check if this NFT has participated the competition
    function inNFTList (string memory thisNFT) private view returns (bool){
        for (uint8 i = 0 ; i < nParti; i++){
            if (strcmp(NFTInfo[i].link , thisNFT)) return true; 
        }
        return false;
    }

    // Helper function: return the uint8 NFT ID in the NFTInfo
    function NFTID (string memory link) private view returns (uint8){
        require(inNFTList(link));
        for (uint8 i = 0; i < nParti; i++){
            if (strcmp(NFTInfo[i].link, link)) return i;
        }
    }

    //check the current bid price of an NFT
    function checkBidPrice (string memory _thisNFT) public view returns(uint){
        return bidPrice[_thisNFT];
    }


    // To receive ether:
    // Make sure the sender account is an EOA and currently is at Admission/ View&Trade Stage
    // if the sender is one of the participants, top up his account
    // if the sender is not yet a participant and the value received > admission, add him as a participant and top up the remainder value
    receive() external payable{
        require (msg.sender == tx.origin, "");             
        require (curStage == stages.ADMISSION || curStage == stages.VIEW_N_TRADE, "No top up during voting stage");
        if (paidAdmitFee[msg.sender]) accBalance[msg.sender] += msg.value; 

        else if (msg.value >= admissionFee && curStage == stages.ADMISSION) {
            paidAdmitFee[msg.sender] = true;
            accBalance[msg.sender] = msg.value - admissionFee;
            totalAdmissionFee += admissionFee;
        }

        // if the payment is initiated by a contract address or the admission fee paid is not enough, the payment will be forfeited.
    }

    event FallBackIsCalled();
    fallback() external payable{
        emit FallBackIsCalled();
    }

    ///////// STAGE 1: Admission Stage //////////////////////////////////////

    // After participants paid admission fee, they can join the competition and submit their link to their NFT
    function joinCompetition (address _thisGuy, string calldata _thisNFT) external {
        require (curStage == stages.ADMISSION, "Admission Stage passed");
        require (paidAdmitFee[_thisGuy], "Please pay the admission fee");
        ////require (_thisNFT, "Invalid NFT");

        partiList.push(_thisGuy);
        participated[_thisGuy] = true;
        NFTInfo[nParti] = NFT(_thisNFT,_thisGuy,0,address(0)); 
        viewNFT[nParti] = _thisNFT;
        nParti++;
    }

    ///////// STAGE 2 : View and Trade NFT //////////////////////////////////////

    // Propose a bid
    error LowerThanCurBidPrice();
    function raiseBid (address _thisGuy, string calldata _link, uint _priceWei) external { 
        require (curStage == stages.VIEW_N_TRADE, "No trading at this stage");
        require (inNFTList(_link), "This NFT has not participated");
        require (participated[_thisGuy], "You have not joined this competition");
        require (_priceWei >= 1 gwei, "Not enough for tx fee");

        require(_thisGuy != NFTInfo[NFTID(_link)].owner, "No self-bid");
        require(_priceWei > accBalance[_thisGuy], "You don't have enough money. Please top up"); // see if this guy hv enough balance
        
        if (_priceWei > bidPrice[_link] ||  // larger than the current bid price 
            accBalance[NFTInfo[NFTID(_link)].bidder] < bidPrice[_link]) { // the current highest-bid holder does not has enough money
            NFTInfo[NFTID(_link)].bidder = _thisGuy;
            bidPrice[_link] = _priceWei;
        }
        else revert LowerThanCurBidPrice(); 
    }


    // Owner of the NFT can accept the bid price proposed by the highest
    error BidderNotEnoughBalance();
    error NotOwnedByU();
    function acceptTrade(address _thisGuy, string calldata _link) external returns (bool){ // *******gas is infinite//
        require (curStage == stages.VIEW_N_TRADE, "No trading at this stage");
        require (inNFTList(_link), "This NFT has not participated");
        require (participated[_thisGuy], "You have not joined this competition");

        //require(_thisGuy != NFTInfo[NFTID(_link)].owner);
        
        if (_thisGuy != NFTInfo[NFTID(_link)].owner) revert NotOwnedByU();
        if (accBalance[NFTInfo[NFTID(_link)].bidder] < bidPrice[_link]) 
            revert BidderNotEnoughBalance();

        accBalance[NFTInfo[NFTID(_link)].bidder] -= bidPrice[_link];
        accBalance[NFTInfo[NFTID(_link)].owner] += bidPrice[_link];
        
        bidPrice[_link]=0;
        NFTInfo[NFTID(_link)].bidder = address(0); 
        NFTInfo[NFTID(_link)].owner = _thisGuy;
        return true;
    }

    ///////// STAGE 3: Voting Stage //////////////////////////////////////
    // Participants can cast their votes on exactly 2 different NFTs
    error VotedAlready();
    function castVote (address _thisGuy, string memory _l1, string memory _l2) external{ 
        require (curStage == stages.VOTING, "Not at voting stage block.timestamp");
        require (participated[_thisGuy], "You have not joined this competition");
        require (inNFTList(_l1) && inNFTList(_l2), "The NFT has not participated");
        require (strcmp(_l1, _l2), "No double vote");

        if (voted[_thisGuy]) revert VotedAlready();

        NFTInfo[NFTID(_l1)].nVote +=1;
        NFTInfo[NFTID(_l2)].nVote +=1;

        voted[_thisGuy] = true;
    }

    ////////////// Reward Stage/////////////////////////////////////////////
    // Close the competition by distributing all the rewards
    // This function will be called after Voting stage ends
    function reward () internal override {

        // find out the number of votes
        // find out the first 3 number of votes, and the number of NFT earned respective votes
        uint8[2] memory first = [0,0];     // [ nVote, nOfNFTWithNVote]
        uint8[2] memory second = [0,0];
        uint8[2] memory third = [0,0]; 
        for (uint8 i = 0; i < nParti; i++){
            if (NFTInfo[i].nVote > first[0]) {
                third = second;
                second = first;
                first = [NFTInfo[i].nVote, 1];
            }
            else if (NFTInfo[i].nVote == first[0]) {
                first[1] +=1;
            }
            else if (NFTInfo[i].nVote > second[0]) {
                third = second;
               second[0] = NFTInfo[i].nVote;
            }
            else if (NFTInfo[i].nVote == second[0]) {
                second[1] +=1;
            }
            else if (NFTInfo[i].nVote > third[0]) {
                third[0] = NFTInfo[i].nVote;
            }
            else if (NFTInfo[i].nVote == third[0]) {
                third[1] +=1;
            }
        }

        // distribute the reward to the owner of the NFT by updating their account balance
        for (uint8 i = 0; i < nParti; i++){
            if (NFTInfo[i].nVote == first[0] && first[1] != 0){
                accBalance[NFTInfo[i].owner] += totalAdmissionFee *9/20 / first[1];
                
            }
            else if (NFTInfo[i].nVote == second[0] && second[1] != 0){
                accBalance[NFTInfo[i].owner] += totalAdmissionFee *3/10 / second[1];
            }
            else if (NFTInfo[i].nVote == third[0] && third[1] != 0){
                accBalance[NFTInfo[i].owner] += totalAdmissionFee *3/20 / third[1];
            }
        }
        
        // close the competition by sending the account balance to participants who have voted
        for (uint8 i = 0; i < nParti; i++) {
            if (!voted[partiList[i]]) continue;
            payable(partiList[i]).transfer(accBalance[partiList[i]]);
        }

        
        // pay all remaining value of the sc to owner of sc
        payable(ownerSC).transfer(address(this).balance);

        // delete all the data contained in this round of competition and start a new round 
        // (This part of the code will be skipped)

    }
}