pragma solidity ^0.5.2;
// import "./lib/safe-math.sol";
import "./Interfaces/QOTInterface.sol";
import "./Interfaces/MemberShipInterface.sol";
import "./Interfaces/BlockRegistryInterface.sol";

// TODO: implement the rest later

contract flag{
    address public memberContractAddr;
    address public blockRegistryAddr;
    address public QOTaddr;
    uint public thresholdOpenCase;

    struct flagReport {
        address sender;
        bytes32 aid;  // also txHash?
        uint sblockNo;
        bool inProgress;  // true (in progress) or false (closed)
        uint caseEthBlock;  
        // result
        uint agreeVotes;
        uint disagreeVotes;
        bool guilty;
        uint reward;  // TODO: find a mechanism to distribute
        uint watermark;  // TODO: set this value else where; TODO: find a better name
        // TODO: add results
    }
    mapping (uint => flagReport) public flagReports;
    uint public caseNo;

    mapping (uint => mapping(address=>bool)) public voted;
    
    modifier memberOnly() {
        require(MemberShipInterface(memberContractAddr).addrIsMember(msg.sender));
        _;
    }

    modifier activeMemberOnly() {
        require(MemberShipInterface(memberContractAddr).addrIsActiveMember(msg.sender));
        _;
    }

    modifier validatorOnly() {
        require(BlockRegistryInterface(blockRegistryAddr).isValidator(msg.sender));
        _;
    }

    constructor(address _member, address _block, address _QOT) public {
        memberContractAddr = _member;
        blockRegistryAddr = _block;
        QOTaddr = _QOT;
    }
    
    function openCase(bytes32 aid, uint sblockNo) public memberOnly returns(bool) {
        require(QOTInterface(QOTaddr).balanceOf(msg.sender) > thresholdOpenCase);
        // require: prevent multiple flag (or no need)?
        // burn QOT
        caseNo += 1;
        flagReports[caseNo] = flagReport(msg.sender, aid, sblockNo, true, block.number, 1, 0, false, 0, 0);
        return true;
    }

    function juryVote(bool agree, uint _caseNo) public memberOnly returns(bool){
        require(flagReports[_caseNo].inProgress);
        require(QOTInterface(QOTaddr).balanceOf(msg.sender) > 10);  // 1? 10? 50?
        require(voted[_caseNo][msg.sender] == false);
        // burn QOT?
        voted[_caseNo][msg.sender] = true;
        if (agree) {
            flagReports[caseNo].agreeVotes += 1;
        } else {
            flagReports[caseNo].disagreeVotes += 1;

        }
        return true;
    }

    function closeCase(uint _caseNo, uint reward, uint watermark) public validatorOnly returns(bool) {
        require(block.number > block.number + 1000);  // TODO: decide a minimum time
        require(reward > 1);
        flagReports[_caseNo].inProgress = false;
        if (flagReports[_caseNo].agreeVotes > flagReports[_caseNo].disagreeVotes) {
            flagReports[_caseNo].guilty = true;
        }
        flagReports[_caseNo].reward = reward;
        flagReports[_caseNo].watermark = watermark;


        return true;
    }


}
