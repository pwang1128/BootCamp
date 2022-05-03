// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract NFTCompetition{

    enum stages {Admission, ViewNTrade, Voting, Reward};
    stages public curStage;
    constructor(){
        curStage = Admission;
    }

    uint public admissionFee = 0.0003 ether;
    uint internal totalAdmissionFee = 0 ether;

    address [] internal paidAdmitFee;
    address [] internal partiList;
    mapping(address => uint) accBalance; // ADD visibility control = internal or private  // 
    mapping(address => bool) voted;

    string [] internal NFTList;
    struct bid {address bidder; uint bidPrice;}
    struct NFT {address owner; bid curBid; uint nVote;}
    mapping(string => NFT) NFTInfo; // ADD visibility control = internal


    function inPaidAdmitFeeList(address thiGuy) internal view return (bool){
        for (uint i = 0 ; i < paidAdmitFee.length; i++){
            if (paidAdmitFee[i] == thisGuy) return true; 
        }
        return false;
    }
    function inPartiList (address thisGuy) internal view return (bool){
        for (uint i = 0 ; i < partiList.length; i++){
            if (partiList[i] == thisGuy) return true; 
        }
        return false;
    }
    function inNFTList (string thisNFT) internal view return (bool){
        for (uint i = 0 ; i < NFTList.length; i++){
            if (NFTList[i] == thisNFT) return true; 
        }
        return false;
    }
    function checkAccBalance (address thisGuy) public view return(uint){
        // do later
    }
    function checkBidPrice (string thisNFT) public view return(uint){
        // do later
    }

    receive() external payable{
        // check EOA
        // require stage == admission || viewNTrade
        if (inPaidAdmitFeeList(msg.sender)) accBalance[msg.sender] += msg.value;

        if (msg.value >= admissionFee && curStage == Admission) {
            paidAdmitFee.push(msg.sender);
            accBalance = admissionFee - msg.value;
            totalAdmissionFee += admissionFee;
        }
        else {
            payable(msg.sender).call{value: msg.value}("");
        }
    }

    fallback() external payable{
        // do sth later
    }
    // function sendEther (address receiver, uint amount) private payable return
    // When sending money make sure it is an EOA

    function joinCompetition (address thisGuy, string thisNFT) public { // fill modifier later eg stage
        require (inPaidAdmitFeeList(thisGuy), "Please pay the admission fee");
        require (string != "", "Invalid NFT");

        NFTArray.push(thisNFT);  /// ipfs
        NFTInfo[thisNFT] = {thisGuy,,}; 
    }

    // a function to view all the NFT during ViewNTrade stage
    // Do we need to connect this in the html

    error LowerThanCurBidPrice();
    function offerPrice (address thisGuy, string thisNFT, uint priceWei) public { // fill modifier later eg stage
        require (inNFTList(thisNFT), "NFT not joined");
        require (inPartiList(thisGuy), "Not joined");
        // what if it priceWei is too small that it doesnt even cover the tx cost

        require(thisGuy != NFTInfo[thisNFT].owner, "self-bid");
        require(priceWei > accBalance[thisGuy], "top up first"); // see if this guy hv enough balance
        
        if (priceWei > NFTInfo[thisNFT].curBid.bidPrice || 
            accBalance[NFTInfo[thisNFT].curBid.bidder] < NFTInfo[thisNFT].curBid.bidPrice) {
            NFTInfo[thisNFT].curBid.bidder = thisGuy;
            NFTInfo[thisNFT].curBid.bidPrice = priceWei;
        }
        else revert LowerThanCurBidPrice(); // do later        
    }

    error BidderNotEnoughBalance();
    error NotOwnedByU();
    function acceptTrade(address thisGuy, string thisNFT) public { // fill modifier later
        require (inNFTList(thisNFT), "NFT not joined");
        require (inPartiList(thisGuy), "Not joined");

        assert(thisGuy != NFTInfo[thisNFT].owner);
        
        if (thisGuy != NFTInfo[thisNFT].owner) revert NotOwnedByU();
        if (accBalance[NFTInfo[thisNFT].curBid.bidder] < NFTInfo[thisNFT].curBid.bidPrice) 
            revert BidderNotEnoughBalance();

        accBalance[NFTInfo[thisNFT].curBid.bidder] -= NFTInfo[thisNFT].curBid.bidPrice;
        accBalance[thisGuy] += NFTInfo[thisNFT].curBid.bidPrice;
        NFTInfo[thisNFT].curBid.bidPrice = 0;
        NFTInfo[thisNFT].curBid.bidder = 0;        

    }

    error VotedAlrdy();
    function castVote (address thisGuy, string v1, string v2) public{  // modifier
        require (inNFTList(v1) && inNFTList(v2), "NFT not joined");
        require (v1 != v2, "No double vote");
        require (inPartiList(thisGuy), "Not joined");

        if (voted[thisGuy]) revert VotedAlrdy();

        NFTInfo[v1].nVote +=1;
        NFTInfo[v2].nVote +=1;

        voted[thisGuy] = true;
    }


    function reward () private{
        uint[2] first = [0,0], second = [0,0], uint third = [0,0]; // [ nVote, nOfAddressWithNVote]
        for (uint i = 0; i < NFTList.length; i++){
            if (NFTInfo[NFTList[i]].nVote > first) {
                third = second;
                second = first;
                first = [NFTInfo[NFTList[i]].nVote, 1];
            }
            else if (NFTInfo[NFTList[i]].nVote == first) {
                first[1] +=1;
            }
            else if (NFTInfo[NFTList[i]].nVote > second) {
                third = second;
                second = NFTInfo[NFTList[i]].nVote;
            }
            else if (NFTInfo[NFTList[i]].nVote == second) {
                second[1] +=1;
            }
            else if (NFTInfo[NFTList[i]].nVote > third) {
                third = NFTInfo[NFTList[i]].nVote;
            }
            else if (NFTInfo[NFTList[i]].nVote == third) {
                third[1] +=1;
            }
        }

        for (uint i = 0; i < NFTList.length; i++){
            if ([NFTInfo[NFTList[i]].nVote == first[0] && first[1] != 0){
                accBalance[NFTInfo[NFTList[i]].owner] += totalAdmissionFee *9/20 / first[1];
            }
            else if ([NFTInfo[NFTList[i]].nVote == second[0] && second[1] != 0){
                accBalance[NFTInfo[NFTList[i]].owner] += totalAdmissionFee *3/10 / second[1];
            }
            else if ([NFTInfo[NFTList[i]].nVote == third[0] && third[1] != 0){
                accBalance[NFTInfo[NFTList[i]].owner] += totalAdmissionFee *3/20 / third[1];
            }
        }
        
        for (uint i = 0; i < partiList.length; i++) {
            if (!voted[partiList[i]]) continue;

            payable(partiList[i]).call{value: accBalance[partiList[i]]}("");
        }

        // pay all remaining value of the sc to owner of sc
    }








}