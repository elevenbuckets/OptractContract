pragma solidity ^0.5.2;
import "./lib/safe-math.sol";


contract BlockRegistry{
    using SafeMath for uint256;

    // Variables
    address[4] public managers;  // use "coreManagers" and "managers" as in "MemberShip.sol"?
    address[16] public validators;
    uint public nowSblockNo;  // start from 1
    uint public sblockTimeStep = 60 minutes;  // what's the balance between UX and cost-control?
    bool public opRoundStatus = true;  // need `true` for 1st round;is it redundant?
    uint public opRound;
    uint public latestLotterySblock;
    uint public roundVote1Count;
    uint public roundVote2Count;
    uint public articleCount;

    struct blockStat{
        // address validator;
        uint blockHeight;  // block.number while submission
        bytes32 merkleRoot;  // IPFs hash string to bytes32: 
        bytes32 ipfsAddr;  // string to hex (in js): ethUtils.bufferToHex(bs58.decode(ipfsHash).slice(2));
        uint timestamp;
        uint uniqArticleCount;
        uint vote1Count;
        uint vote2Count;
        uint opRound;
        // the following could have no values other than default
        uint lotteryWinningNumber;
        bytes32 lotteryIpfs;
        uint minSuccessRate;  // shoud be an integer between 0 and 100
        bytes32 succesRateDB;  // IPFS contain success rate
        bytes32 finanListIpfs;
    }
    mapping (uint => blockStat) public blockHistory;


    constructor() public {
        // always INITIALIZE ARRAY VALUES!!!
        managers = [ 0xB440ea2780614b3c6a00e512f432785E7dfAFA3E,
                     0x4AD56641C569C91C64C28a904cda50AE5326Da41,
                     0xaF7400787c54422Be8B44154B1273661f1259CcD,
                     address(0)];
        validators = [ 0xB440ea2780614b3c6a00e512f432785E7dfAFA3E,
                       0x4AD56641C569C91C64C28a904cda50AE5326Da41,
                       0xaF7400787c54422Be8B44154B1273661f1259CcD,
                       address(0), address(0), address(0), address(0), address(0),
                       address(0), address(0), address(0), address(0), address(0),
                       address(0), address(0), address(0)];
        // prevTimeStamp = block.timestamp - sblockTimeStep;
        blockHistory[0] = blockStat(block.number, '0x0', '0x0', block.timestamp, 0, 0, 0, 0, 0, '0x0', 0, '0x0', '0x0');
        nowSblockNo = 1;
    }

    // Modifiers
    modifier managerOnly() {
        require(msg.sender != address(0));
        require(msg.sender == managers[0] || msg.sender == managers[1] || msg.sender == managers[2] || msg.sender == managers[3]);
        _;
    }

    modifier validatorOnly() {
        require(msg.sender != address(0));
        require(msg.sender == validators[0] || msg.sender == validators[1] || msg.sender == validators[2] ||
                msg.sender == validators[3] || msg.sender == validators[4] || msg.sender == validators[5] ||
                msg.sender == validators[6] || msg.sender == validators[7] || msg.sender == validators[8] ||
                msg.sender == validators[9] || msg.sender == validators[10] || msg.sender == validators[11] ||
                msg.sender == validators[12] || msg.sender == validators[13] || msg.sender == validators[14] ||
                msg.sender == validators[15]);
        _;
    }

    function toggleGame() public validatorOnly returns(uint) {
        // this function is for dev only, should not exist in real product
        opRoundStatus = !opRoundStatus;
        return opRound;
    }

    function submitMerkleRoot(
        bytes32 _merkleRoot,
        bytes32 _ipfsAddr,
        uint _uniqArticleCount,
        uint _vote1Count,
        uint _vote2Count,
        bytes32 _lotteryIpfs,
        uint _minSuccessRate,
        bytes32 _successRateDB,
        bytes32 _finalListIpfs
    ) public validatorOnly returns (bool) {
        // In other words, this function generate a new sblock.
        // * block.number at this point is end of this sblock
        // * block.number+1 is begin of next sblock
        // ToDo
        //   * (?) add a function to change opRound to 0 to (temporary) disable the round (or add a bool to do that?).
        //     - opRound: a opRound contains `vote phase` and `claim-and-vote phase`, 

        // comment some "require" for test purpose
        // require(block.timestamp >= blockHistory[nowSblockNo] + sblockTimeStep, 'too soon');
        require(block.timestamp >= blockHistory[nowSblockNo].timestamp + 2 minutes);  // 2 min is for test purpose, should be 1 hour(?)
        require(block.number >= blockHistory[nowSblockNo].blockHeight + 5);  // 5 is for test purpose, should be ?
        require(blockHistory[nowSblockNo].merkleRoot != _merkleRoot && blockHistory[nowSblockNo].ipfsAddr != _ipfsAddr);  // prevent re-submission
        require(blockHistory[nowSblockNo+1].blockHeight == 0 && blockHistory[nowSblockNo+1].merkleRoot == 0x0
                && blockHistory[nowSblockNo+1].ipfsAddr == 0x0 && blockHistory[nowSblockNo+1].timestamp == 0);
        // require: ...
        require(_minSuccessRate >= 0 && _minSuccessRate < 100);

        // determine which phase of a OpRound: genesis round, lottery, finalist, or regular (nothing happened) sblock
        // note that two kind of votes use same voteCount in smart contract
        if (opRound == 0 && articleCount + _uniqArticleCount >= 100 ) {
            // genesis round: 100 is a manually determined threshold
            require(_lotteryIpfs == '0x0' && _minSuccessRate == 0 && _finalListIpfs == '0x0' && _successRateDB == '0x0');
            roundVote1Count += _vote1Count; roundVote2Count += _vote2Count; articleCount += _uniqArticleCount;
            blockHistory[nowSblockNo] = blockStat(
                block.number, _merkleRoot, _ipfsAddr, block.timestamp, _uniqArticleCount, _vote1Count, _vote2Count, opRound,
                0, '0x0', 0, '0x0', '0x0'
            );
            opRound += 1;  // i.e., this if-statement exec only once
        } else if (roundVote1Count + _vote1Count >= 500 && opRound != 0 && latestLotterySblock < nowSblockNo) {
            // lottery; 500 is manully determined; the vote here is `vote1`
            require(_finalListIpfs == '0x0' && _successRateDB == '0x0');
            latestLotterySblock = nowSblockNo;
            uint winNumber = uint(keccak256(abi.encodePacked(_merkleRoot, block.number)));  // need to sync this eq. with calcWinningNumber()
            blockHistory[nowSblockNo] = blockStat(
                block.number, _merkleRoot, _ipfsAddr, block.timestamp, _uniqArticleCount, _vote1Count, _vote2Count, opRound,
                winNumber, _lotteryIpfs, _minSuccessRate, '0x0', '0x0'
            );
            roundVote1Count = 0;
            roundVote2Count = 0;
            articleCount = 0;
        } else if (roundVote2Count + _vote2Count >= 500 && opRound != 0 && latestLotterySblock > nowSblockNo) {
            // finalist
            require(_lotteryIpfs == '0x0' && _minSuccessRate == 0);
            roundVote1Count += _vote1Count; articleCount += _uniqArticleCount;
            blockHistory[nowSblockNo] = blockStat(
                block.number, _merkleRoot, _ipfsAddr, block.timestamp, _uniqArticleCount, _vote1Count, _vote2Count, opRound,
                0, '0x0', 0, _successRateDB, _finalListIpfs
            );
            opRound += 1;
            roundVote2Count = 0;
        } else {  // regular sblock, only accumulate votes
            require(_lotteryIpfs == '0x0' && _minSuccessRate == 0 && _finalListIpfs == '0x0' && _successRateDB == '0x0');
            roundVote1Count += _vote1Count; roundVote2Count += _vote2Count; articleCount += _uniqArticleCount;
            blockHistory[nowSblockNo] = blockStat(
                block.number, _merkleRoot, _ipfsAddr, block.timestamp, _uniqArticleCount, _vote1Count, _vote2Count, opRound,
                0, '0x0', 0, '0x0', '0x0'
            );
        }
        nowSblockNo += 1;

        return true;
    }

    // Lottery related
    function calcLatestWinningNumber() public view returns(uint) {
        require(nowSblockNo > 1);
        return calcWinningNumber(nowSblockNo-1);
    }

    function calcWinningNumber(uint _sblockNo) public view returns(uint) {
        require(_sblockNo < nowSblockNo);
        require(block.number > blockHistory[_sblockNo].blockHeight);  // if equal, then there's no blockhash(_sblockNo)
        require(blockHistory[_sblockNo].merkleRoot != 0x0);
        // require: ...
        // *merkle root of K+y*, as well as *defense of block K+y* and latest *Eth block hash at the time of block K+y committed*
        return uint(keccak256(abi.encodePacked(
            blockHistory[_sblockNo].merkleRoot,
            blockHistory[_sblockNo].blockHeight  // blockhash() of this uint could be `0x0` if sblock too long (>256 main chain block)
        )));
    }

    function txExist(bytes32[] memory proof, bool[] memory isLeft, bytes32 txHash, uint _sblockNo) public view returns (bool){
        require(_sblockNo < nowSblockNo);
        require(blockHistory[_sblockNo].merkleRoot != 0x0);
        return merkleTreeValidator(proof, isLeft, txHash, blockHistory[_sblockNo].merkleRoot);
    }

    function claimReward(
        bytes32[] calldata proof1, bool[] calldata isLeft1, bytes32 txHash1, uint sblockNo1,
        bytes32[] calldata proof2, bool[] calldata isLeft2, bytes32 txHash2, uint sblockNo2
    ) external view returns(bool) {
        // need to proof both articles are in the tree and both submitted by the msg.sender (using calcLeaf() below)
        require(sblockNo1 > nowSblockNo && sblockNo1 < nowSblockNo + 12);
        // require(sblockNo2 == sblockNo1 + 2);  // is it always true?
        // require txHash1 = generateTxHash(msg.sender, ...)
        require(txExist(proof1, isLeft1, txHash1, sblockNo1) && txExist(proof2, isLeft2, txHash2, sblockNo2));
    }

    // merkle tree and leaves
    function merkleTreeValidator(
        bytes32[] memory proof,
        bool[] memory isLeft,
        bytes32 targetLeaf,
        bytes32 _merkleRoot
    ) public pure returns (bool) {
        require(proof.length < 32);  // 2**32 ~ 4.3e9 leaves!
        require(proof.length == isLeft.length);

        bytes32 targetHash = targetLeaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofEle = proof[i];
            if (isLeft[i]) {
                targetHash = keccak256(abi.encodePacked(proofEle, targetHash));
            } else if (!isLeft[i]) {
                targetHash = keccak256(abi.encodePacked(targetHash, proofEle));
            } else {
                return false;
            }
        }
        return targetHash == _merkleRoot;
    }

    // TODO: update these calcLeaf()
    // function calcLeaf(
    //     uint _nonce,
    //     bytes32 _ipfs,
    //     uint _since,
    //     uint _agree,
    //     uint _disagree,
    //     bytes32 _reply,
    //     bytes32 _comment
    // ) external view returns (bytes32) {
    //     // note: the "category" field is not here yet
    //     return keccak256(abi.encodePacked(_nonce, msg.sender, _ipfs, _since, _agree, _disagree, _reply, _comment));
    // }

    // function calcLeaf2(
    //     uint _nonce,
    //     address _sender,
    //     bytes32 _ipfs,
    //     uint _since,
    //     uint _agree,
    //     uint _disagree,
    //     bytes32 _reply,
    //     bytes32 _comment
    // ) external view managerOnly returns (bytes32) {
    //     return keccak256(abi.encodePacked(_nonce, _sender, _ipfs, _since, _agree, _disagree, _reply, _comment));
    // }

    // function calcAccountStateSummaryLeaf(
    //     address _account,
    //     uint _start,
    //     uint _end,
    //     uint _gain,
    //     uint _apUsed,
    //     uint _accReward
    // ) external view validatorOnly returns (bytes32){
    //     return keccak256(abi.encodePacked(msg.sender, _account, _start, _end, _gain, _apUsed, _accReward));
    // }

    // query
    function getBlockNo() external view returns (uint) {
        return nowSblockNo;
    }

    function getBlockInfo(uint _sblockNo) external view returns (uint, bytes32, bytes32) {
        // TODO: update the results
        return (blockHistory[_sblockNo].blockHeight, blockHistory[_sblockNo].merkleRoot, blockHistory[_sblockNo].ipfsAddr);
    }

    function queryValidator(uint _idx) external view returns (address) {
        require(_idx>=0 && _idx < 16);
        return validators[_idx];
    }

    function isValidator() external view returns (bool) {
        if (msg.sender == address(0)) {
            return false;
        } else {
            return (msg.sender == validators[0] || msg.sender == validators[1] || msg.sender == validators[2] ||
                    msg.sender == validators[3] || msg.sender == validators[4] || msg.sender == validators[5] ||
                    msg.sender == validators[6] || msg.sender == validators[7] || msg.sender == validators[8] ||
                    msg.sender == validators[9] || msg.sender == validators[10] || msg.sender == validators[11] ||
                    msg.sender == validators[12] || msg.sender == validators[13] || msg.sender == validators[14] ||
                    msg.sender == validators[15]);
        }
    }

    function queryManagers() external view returns (address[4] memory) {
        return managers;
    }

    // upgradable
    function setValidator(address _newValidator, uint _idx) public managerOnly returns (bool) {
        require(_newValidator != address(0));
        require(_idx >=0 && _idx < 16);
        validators[_idx] = _newValidator;
        return true;
    }

    function setManager(address _newManager) public managerOnly returns (bool) {
        // assume no need to change first 3 managers
        managers[3] = _newManager;
        return true;
    }

}
