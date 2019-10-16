pragma solidity ^0.5.2;
// This is a contract to help determine inappropriate contents in Optract. The procedure of a
// "flag-event" is:
// * A qualified member open a "case"
// * Qualified members "jury-vote"
// * After sometime (min 72 hours) the validator close the case and make changes if necessary.
// since in Optract, members has to hold enough QOT to vote. The amount of minumum holding of
// QOT by a user in order to curate, or "watermark", is adjustable through QOTaccessControl.sol
// and also here while closing a case.
// 
// 
// import "./lib/safe-math.sol";
import "./Interfaces/QOTInterface.sol";
import "./Interfaces/MemberShipInterface.sol";
import "./Interfaces/BlockRegistryInterface.sol";

// TODO: 

contract flag{
    address public memberContractAddr;
    address public blockRegistryAddr;
    address public QOTaddr;
    uint public thresholdOpenCase;
    uint public voteMinQOTholding = 10000000000000;

    struct flagReport {
        address sender;
        bytes32 aid;  // and/or txHash?
        uint aidSblockNo;
        bool inProgress;  // true (in progress) or false (closed)
        uint since;  // current time
        // result
        uint agreeFlag;
        uint disagreeFlag;
        bool guilty;
        uint reward;  // TODO: find a mechanism to distribute
        uint watermark;  // TODO: set this value else where; TODO: find a better name
    }
    mapping (uint => flagReport) public flagReports;
    uint public caseNo;

    mapping (uint => mapping(address=>bool)) public voted;
    mapping (bytes32 => uint) public aid2Flag;
    
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
        // require(aid2Flag[aid] == bytes32(0));  // TODO: or?
        // require: prevent multiple flag in same article (or no need)?
        // burn QOT
        caseNo += 1;
        // assume the opener vote agree by default
        flagReports[caseNo] = flagReport(msg.sender, aid, sblockNo, true, block.timestamp, 1, 0, false, 0, 0);
        aid2Flag[aid] = caseNo;
        return true;
    }

    function queryCase(uint _id) public view returns(address, bytes32, uint, bool, uint) {
        require(_id >= caseNo);
        return (flagReports[_id].sender,
                flagReports[_id].aid,
                flagReports[_id].aidSblockNo,
                flagReports[_id].inProgress,
                flagReports[_id].since
               );
    }

    function queryCaseResult(uint _id) public view returns(bytes32, bool, uint, uint, bool, uint, uint) {
        require(_id >= caseNo);
        // stack-too-deep so split some to here
        return (flagReports[_id].aid,
                flagReports[_id].inProgress,
                flagReports[_id].agreeFlag,
                flagReports[_id].disagreeFlag,
                flagReports[_id].guilty,
                flagReports[_id].reward,
                flagReports[_id].watermark
               );
    }

    function juryVote(bool agree, uint _caseNo) public memberOnly returns(bool){
        require(flagReports[_caseNo].inProgress);
        require(QOTInterface(QOTaddr).balanceOf(msg.sender) > voteMinQOTholding);
        require(voted[_caseNo][msg.sender] == false);
        // burn QOT?
        voted[_caseNo][msg.sender] = true;
        if (agree) {
            flagReports[caseNo].agreeFlag+= 1;
        } else {
            flagReports[caseNo].disagreeFlag += 1;

        }
        return true;
    }

    function closeCase(uint _caseNo, uint reward, uint watermark) public validatorOnly returns(bool) {
        require(block.number > block.number + 1000);  // TODO: decide a minimum time
        // require(reward > 1);
        require(watermark > 1); // also see updateCurationMinQOTholding() in MemberShip.sol 
        flagReports[_caseNo].inProgress = false;
        if (flagReports[_caseNo].agreeFlag > flagReports[_caseNo].disagreeFlag) {
            flagReports[_caseNo].guilty = true;
        }
        flagReports[_caseNo].reward = reward;
        // TODO: reward the winner(s)
        // QOTInterface(QOTaddr).mint(reward)  // TODO: need to add flagContractAddr to "mining" in QOT
        flagReports[_caseNo].watermark = watermark;
        MemberShipInterface(memberContractAddr).updateCurationMinQOTholding(watermark);  // or record the "watermark" in blockRegistry?
        
        return true;
    }

    function setVoteMinQOTholding(uint _x) public returns(bool){
        voteMinQOTholding = _x;
    }

}
