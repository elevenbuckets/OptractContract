pragma solidity ^0.5.2;
// import "./lib/safe-math.sol";
import "./Interfaces/MemberShipInterface.sol";
import "./Interfaces/QOTInterface.sol";

// TODO: use safemath

contract BlockRegistry{
    // using SafeMath for uint256;

    // Variables
    address[4] public managers;  // use "coreManagers" and "managers" as in "MemberShip.sol"?
    address[16] public validators;
    address public memberContractAddr;
    address public QOTAddr;
    uint public nowSblockNo;  // start from 1
    uint public sblockTimeStep = 5 minutes;  // it's a minimum timestep
    // bool public opRoundStatus = true;  // need `true` for 1st round; or simply use "pause/unpause"?
    uint public opRound;
    uint public articleCount;
    // variables with `v1` or `vote1`: lottery; with `v2` or `vote2`: claim
    uint public roundVote1Count;
    uint public roundVote2Count;
    uint public vote1Threshold = 40;  // between 5 and 95, step 5
    uint public vote2Threshold = 40;  // between 5 and 95, step 5
    uint public v1EndTime;
    uint public v2EndTime;
    bool public atV1;
    uint8 public numRange = 8;  // it means pick x out of 16 numbers; should eventually make it constant
    uint public maxVoteTime1 = 12 hours;  // duration of v1-vote
    uint public maxVoteTime2 = 12 hours;  // duration of v2-claim
    uint public reward = 2000000000000;  // should be a global (constant) variable. Or fix a value in QOT

    struct blockStat{
        address validator;
        uint blockHeight;  // block.number while submission
        bytes32 merkleRoot;  // IPFs hash string to bytes32: 
        bytes32 ipfsAddr;  // string to hex (in js): ethUtils.bufferToHex(bs58.decode(ipfsHash).slice(2));
        uint timestamp;
        uint uniqArticleCount;
        uint vote1Count;
        uint vote2Count;
        bytes32 opRoundId;
        bytes32 aidMerkleRoot;
        bytes32 aidIpfsAddr;
    }
    mapping (uint => blockStat) public blockHistory;  // sblockNo to blockStat

    struct opRoundStruct{
        // update during creation of this opRound
        bytes32 id;
        uint initBlockNo;
        // update in lottery-sblock
        uint lotteryBlockNo;
        bytes32 lotteryWinNumber;
        // update in final-sblock
        uint minSuccessRate;  // shoud be an integer between 0 and 100; this is used in next opRound
        uint baseline;  // i.e, the total votes of the vote2 winner
        bytes32 succesRateDB;  // IPFS contain success rate
        bytes32 finalListIpfs;
    }
    mapping (uint => opRoundStruct) opRoundHistory;
    mapping (bytes32 => uint) opRoundIdToNum;  // opRound id to opRound number
    // mapping (uint => uint) public lotterySblockNo;  // give `opRound`, return the corresponding `sblock_no` while lottery happened
    // mapping (uint => bytes32) public opRoundLog;  // opRound index to opRound id
    mapping (uint => mapping(address => bool)) opRoundClaimed;

    constructor(address _memberContractAddr, address _QOTAddr) public {
        memberContractAddr = _memberContractAddr;
        QOTAddr = _QOTAddr;
        managers = [ 0xB440ea2780614b3c6a00e512f432785E7dfAFA3E,
                     0x4AD56641C569C91C64C28a904cda50AE5326Da41,
                     0xaF7400787c54422Be8B44154B1273661f1259CcD,
                     address(0)];
        validators = [ 0xB440ea2780614b3c6a00e512f432785E7dfAFA3E,
                       0x4AD56641C569C91C64C28a904cda50AE5326Da41,  // kai
                       0xaF7400787c54422Be8B44154B1273661f1259CcD,
                       0x664F5e320399B2fc5f32591c3a1A82e2b761769E,  // kai
                       0x94a34659aC860FE7e7985096FB70217fb2cc8DEc,  // kai
                       address(0), address(0), address(0), address(0), address(0),
                       address(0), address(0), address(0), address(0), address(0),
                       address(0)];
        blockHistory[0] = blockStat(msg.sender, block.number, 0x0, 0x0, block.timestamp,
                                    0, 0, 0, 0x0, 0x0, 0x0);
        // opRoundHistory[0] = opRoundStruct(0x0000000000000000000000000000000000000000000000000000000000000001,
        //                                   nowSblockNo, 0, 0x0, 0, 0, 0x0, 0x0);
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

    // some adjustable functions only for developing phase
    function updateMaxVoteTime1(uint _seconds) public validatorOnly {
        require(_seconds > 180 && _seconds < 86400);  // restrict to a range
        maxVoteTime1 = _seconds;
    }

    function updateMaxVoteTime2(uint _seconds) public validatorOnly {
        require(_seconds > 180 && _seconds < 86400);  // restrict to a range
        maxVoteTime2 = _seconds;
    }


    function setThreshold(uint _x, uint _y) public validatorOnly{
        require(_x >= 5 && _x <=95);
        require(_y >= 5 && _y <=95);
        vote1Threshold = _x;
        vote2Threshold = _y;
    }

    // some internal functions
    function _increaseThreshold(uint _x) internal pure returns(uint) {
        if (_x <= 90) {
            return _x + 5;
        } else {
            return 95;
        }
    }

    function _decreaseThreshold(uint _x) internal pure returns(uint) {
        if (_x >= 100) {
            return 95;
        } else if (_x >= 10) {
            return _x - 5;
        } else {
            return 5;
        }
    }

    function _toNextOpRound(bytes32 _mr, uint _minSuccessRate, uint _baseline, bytes32 _successRateDB, bytes32 _finalListIpfs) internal {
        roundVote1Count = 0;
        roundVote2Count = 0;
        articleCount = 0;
        // MemberShipInterface(memberContractAddr).updateActiveMemberCount(false);  // note: if too frequent, it will not update unless set 'forced=true'

        // update current opRoundHistory
        opRoundHistory[opRound].minSuccessRate = _minSuccessRate;  // next opRound need this
        opRoundHistory[opRound].baseline = _baseline;
        opRoundHistory[opRound].succesRateDB = _successRateDB;
        opRoundHistory[opRound].finalListIpfs = _finalListIpfs;

        // for next opRound
        atV1 = true;
        opRound += 1;
        bytes32 _oid = bytes32(keccak256(abi.encodePacked(_mr, opRound)));
        opRoundHistory[opRound] = opRoundStruct(_oid, nowSblockNo+1, 0, 0x0, 0, 0, 0x0, 0x0);
        opRoundIdToNum[_oid] = opRound;
    }

    // create a new sblock
    function submitMerkleRoot(
        bytes32 _merkleRoot,
        bytes32 _ipfsAddr,
        bytes32 _aidMerkleRoot,
        bytes32 _aidIpfsAddr,
        bytes32 _successRateDB,
        bytes32 _finalListIpfs,
        uint[5] memory _ints // uint _uniqArticleCount, uint _vote1Count, uint _vote2Count, uint _minSuccessRate, uint _baseline
    ) public validatorOnly returns (bool) {
        // Note: a `opRound` contains two parts: `(v1)vote` and `(v2)claim`,
        //       (v2) may not happen if (v1) takes more than maxVoteTime.
        // comment some "require"s for test purpose
        // require(block.timestamp >= blockHistory[nowSblockNo] + sblockTimeStep, 'too soon');
        require(block.timestamp >= blockHistory[nowSblockNo-1].timestamp + sblockTimeStep);  // 2 min is for test purpose, should be 1 hour(?)
        require(block.number >= blockHistory[nowSblockNo-1].blockHeight + 1);
        require(_merkleRoot != 0x0 && _ipfsAddr != 0x0);
        require(blockHistory[nowSblockNo-1].merkleRoot != _merkleRoot && blockHistory[nowSblockNo-1].ipfsAddr != _ipfsAddr);  // prevent re-submission
        require(blockHistory[nowSblockNo].blockHeight == 0 && blockHistory[nowSblockNo].merkleRoot == 0x0 &&
                blockHistory[nowSblockNo].ipfsAddr == 0x0 && blockHistory[nowSblockNo].timestamp == 0);
        require(_aidMerkleRoot != 0x0 && _aidIpfsAddr != 0x0);
        uint _uniqArticleCount = _ints[0];
        uint _vote1Count = _ints[1];
        uint _vote2Count = _ints[2];
        uint _minSuccessRate = _ints[3];
        uint _baseline = _ints[4];
        require(_minSuccessRate >= 0 && _minSuccessRate < 100);  // need the equal for genesis round
        // require: ...

        // a sblock in a opRound cound be of type: genesis, lottery, lottery-NDR, finalist, finalist-NDR, or regular
        // (NDR = no-draw-round)
        if (opRound == 0 && articleCount + _uniqArticleCount >= 7) {  // genesis; set small number for test purpose
            blockHistory[nowSblockNo] = blockStat(
                msg.sender, block.number, _merkleRoot, _ipfsAddr, block.timestamp,
                _uniqArticleCount, _vote1Count, _vote2Count, opRoundHistory[opRound].id,
                _aidMerkleRoot, _aidIpfsAddr
            );
            v2EndTime = block.timestamp;  // although no 'claiming', still need to record a time
            _toNextOpRound(_merkleRoot, 0, 0, 0x0, 0x0);
        } else if (opRound != 0 && atV1 && (block.timestamp - v2EndTime > maxVoteTime1)) {  // A "no-draw-round"! Proceed to next OpRound
            // TODO: uncomment following lines?
            // require(minSuccessRate == opRoundHistory[opRound-1].minSuccessRate);
            // require(_baseline == 0);
            // require(_finalListIpfs == '0x0');
            // require(_successRateDB == opRoundHistory[opRound-1].succesRateDB);
            blockHistory[nowSblockNo] = blockStat(
                msg.sender, block.number, _merkleRoot, _ipfsAddr, block.timestamp,
                _uniqArticleCount, _vote1Count, _vote2Count, opRoundHistory[opRound].id,
                _aidMerkleRoot, _aidIpfsAddr
            );
            v1EndTime = block.timestamp-1;  // or don't update? BTW, subtract by 1 to make sure v2EndTime > v1Endtime (or no need?)
            v2EndTime = block.timestamp;  // in case next submit() fall into this if-statement again
            vote1Threshold = _decreaseThreshold(vote1Threshold);
            // opRoundHistory[opRound].lotteryBlockNo = nowSblockNo;  // should keep it 0
            _toNextOpRound(_merkleRoot, _minSuccessRate, _baseline, _successRateDB, _finalListIpfs);
        } else if (opRound != 0 && atV1 && isEnoughV1(roundVote1Count+_vote1Count)) {  // lottery
            require(opRoundHistory[opRound].lotteryBlockNo == 0 && opRoundHistory[opRound].lotteryWinNumber == 0x0);
            blockHistory[nowSblockNo] = blockStat(
                msg.sender, block.number, _merkleRoot, _ipfsAddr, block.timestamp,
                _uniqArticleCount, _vote1Count, _vote2Count, opRoundHistory[opRound].id,
                _aidMerkleRoot, _aidIpfsAddr
            );
            v1EndTime = block.timestamp;
            vote1Threshold = _increaseThreshold(vote1Threshold);
            opRoundHistory[opRound].lotteryBlockNo = nowSblockNo;
            opRoundHistory[opRound].lotteryWinNumber = calcLotteryWinNumber(_merkleRoot, blockhash(block.number-1));
            roundVote2Count = 0;  // should be 0 already but reset anyway
            atV1 = false;
        } else if (opRound != 0 && atV1 == false && (block.timestamp - v1EndTime > maxVoteTime2)) {  // too long! End this Opround-v2 and proceed to next OpRound
            // TODO: uncomment following lines?
            // require(minSuccessRate == opRoundHistory[opRound-1].minSuccessRate);
            // require(_baseline == 0);
            // require(_finalListIpfs == '0x0');
            // require(_successRateDB == opRoundHistory[opRound-1].succesRateDB);
            blockHistory[nowSblockNo] = blockStat(
                msg.sender, block.number, _merkleRoot, _ipfsAddr, block.timestamp,
                _uniqArticleCount, _vote1Count, _vote2Count, opRoundHistory[opRound].id,
                _aidMerkleRoot, _aidIpfsAddr
            );
            vote2Threshold = _decreaseThreshold(vote2Threshold);
            v2EndTime = block.timestamp;
            // should validator update new _successRateDB in NDR? should _baseline and finalListIpfs have values?
            _toNextOpRound(_merkleRoot, _minSuccessRate, _baseline, _successRateDB, _finalListIpfs);
        } else if (opRound != 0 && atV1 == false && isEnoughV2(roundVote2Count+_vote2Count)) { // finalist
            // require(_finalListIpfs != 0x0 && _successRateDB != 0x0);
            require(_baseline >= 1);  // what else reasonable value?
            blockHistory[nowSblockNo] = blockStat(
                msg.sender, block.number, _merkleRoot, _ipfsAddr, block.timestamp,
                _uniqArticleCount, _vote1Count, _vote2Count, opRoundHistory[opRound].id,
                _aidMerkleRoot, _aidIpfsAddr
            );
            vote2Threshold = _increaseThreshold(vote2Threshold);
            v2EndTime = block.timestamp;
            _toNextOpRound(_merkleRoot, _minSuccessRate, _baseline, _successRateDB, _finalListIpfs);
        } else {  // regular sblock, only accumulate votes
            roundVote1Count += _vote1Count;
            roundVote2Count += _vote2Count;
            articleCount += _uniqArticleCount;  // right now, this is only used in genesis
            blockHistory[nowSblockNo] = blockStat(
                msg.sender, block.number, _merkleRoot, _ipfsAddr, block.timestamp,
                _uniqArticleCount, _vote1Count, _vote2Count, opRoundHistory[opRound].id,
                _aidMerkleRoot, _aidIpfsAddr
            );
        }

        nowSblockNo += 1;

        return true;
    }

    function isEnoughV1(uint v1Count) public view returns (bool) {
        uint activeMemberCount = MemberShipInterface(memberContractAddr).getActiveMemberCount();
        require(activeMemberCount >= 3);  // '3' is num of coreManagers, or use 1? 100?
        uint vote1Rate = (100 * v1Count) / activeMemberCount;
        // assert(vote1Rate <= 100);  // not true if every can vote multiple times
        if (vote1Rate >= vote1Threshold) {
            return true;
        }
    }

    function isEnoughV2(uint v2Count) public view returns (bool) {
        uint activeMemberCount = MemberShipInterface(memberContractAddr).getActiveMemberCount();
        require(activeMemberCount >= 3);  // '3' is num of coreManagers, or use 1? 100?
        // vote2Rate select ABOUT 25% of people from 50% of member, i.e., ~1/8 of total members
        // Here try to keep vote2Rate roughly in the range of 0 and 100, so multiply 8 back.
        // Note that the '1/8' factor is uncertain, could either over or underestimated
        uint vote2Rate = (8 * 100 * v2Count) / activeMemberCount;
        if (vote2Rate >= vote2Threshold) {
            return true;
        }
    }

    // Lottery related
    function calcLotteryWinNumber(bytes32 _mr, bytes32 _bhash) public pure returns(bytes32) {
        // require(_mr != 0x0 && _bhash != 0x0);  // leave these checks to other function
        return keccak256(abi.encodePacked(_mr, _bhash));
    }

    function _getBytes32HexNthDigit(bytes32 _ticket, uint8 _digit) public pure returns(bytes1){
        require(_digit >=0 && _digit <=63);  // treat bytes32 as 64 hex characters
        if (_digit % 2 == 1) {
            return bytes1(uint8(_ticket[_digit/2])%16);  // _digit/2 = Math.floor(digit/2)
        } else {
            return bytes1(uint8(_ticket[_digit/2])/16);
        }
    }

    function lotteryWins(bytes32 _winHex, bytes32 _ticket, uint8 _numRange) public pure returns(bool) {
        // NOTE: in real product, should either record _numRange or make it constant
        // Rule: A ticket wins if: it's X-th digit (count from behind) is Y
        // where `X` is determined by first digit of `lotteryWinNumber` (in the range of 0 and 3)
        // and `Y` is the last digit of `winHex`
        // the rule of determining `X` and `Y` should sync with 'libSampleTicket.js' in 'OptractP2PCli'
        require(_numRange >= 1 && _numRange <= 16);
        uint8 refDigit = uint8(_getBytes32HexNthDigit(_winHex, 0)) % 4;
        bytes1 winHexChar1 = _getBytes32HexNthDigit(_winHex, 63);  // last digit
        uint8 w1 = uint8(winHexChar1);
        uint8 w2 = (w1 + _numRange) % 16;
        uint8 t = uint8(_getBytes32HexNthDigit(_ticket, 63 - refDigit));
        if (w2 > w1)  {
            if (t >= w1 && t < w2) {
                return true;
            }
        } else {
            if (t >= w1 || t < w2) {
                return true;
            }
        }
        return false;
    }

    function _isWinningTicket(uint _opRound, bytes32 _ticket) internal view returns(bool) {
        require(opRound >= _opRound && opRoundHistory[_opRound].lotteryWinNumber != 0x0);
        bytes32 winHex = opRoundHistory[_opRound].lotteryWinNumber;
        return lotteryWins(winHex, _ticket, numRange);
    }

    function setNumRange(uint8 _numRange) public managerOnly {  // for test only
        require(_numRange >= 1 && _numRange <=15);
        numRange = _numRange;
    }

    function isWinningTicket(uint _opRound, bytes32 _ticket) public view returns(bool, uint) {
        // TODO: add all merkle validation arguments in order to verify the txHash is BEFORE the lottery
        return (_isWinningTicket(_opRound, _ticket), opRoundHistory[_opRound-1].minSuccessRate);
    }

    // claim reward
    function setReward(uint _reward) public managerOnly {
        require(_reward < reward*10);  // other better restrictions?
        reward = _reward;
    }

    function txExist(bytes32[] memory proof, bool[] memory isLeft, bytes32 txHash, uint _sblockNo) public view returns (bool){
        require(_sblockNo < nowSblockNo);
        require(blockHistory[_sblockNo].merkleRoot != 0x0);
        return merkleTreeValidator(proof, isLeft, txHash, blockHistory[_sblockNo].merkleRoot);
    }

    function aidExist(bytes32[] memory proof, bool[] memory isLeft, bytes32 aid, uint _sblockNo) public view returns (bool){
        require(_sblockNo < nowSblockNo);
        require(blockHistory[_sblockNo].aidMerkleRoot != 0x0);
        return merkleTreeValidator(proof, isLeft, aid, blockHistory[_sblockNo].aidMerkleRoot);
    }

    function verifySignatureWithPrefix(address _signer, bytes32[6] memory b32s, uint8 _v) public pure returns(bool){
        // assume the "payload" (b32s[3]) already contain prefix. Otherwise need to add prefix:
        //      bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        //      bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, _msg));
        //      return _signer == ecrecover(prefixedHash, _v, _r, _s);
        return _signer == ecrecover(b32s[3], _v, b32s[4], b32s[5]);
    }

    function withdraw(
        bytes32[6] calldata b32s, uint[5] calldata uints,
        bytes32[] calldata claimProof, bytes32[] calldata proof1, bytes32[] calldata proof2,
        uint24[3] calldata uintIsLeft,
        uint8 _v
    ) external {
        // note: v1 is vote by the user in _opRound, v2 is the article used for claim
        // note: "b32s" and "uints" are also used in "verifySignatureWithPrefix()" and "genV2Txhash()":
        //     b32s = [_comment, v1leaf, v2leaf, _payload, _r, _s]
        //     uints = [_opRound, v1block, v2block, claimBlock, since]
        //     uintIsLeft =  [claimIsLeft, v1IsLeft, v2IsLeft]
        // note about restrictions: the total amount of tx per block is restricted to 2**24, it means
        //     `0 < proof.length <= 24` and `0 < isLeft.length <= 24`; the bool array `isLeft` of length
        //     24 can convert to a uint24 (see `_uintToBoolArr()`)

        require(uints[1] <= opRoundHistory[uints[0]].lotteryBlockNo);
        require(uints[2] <= opRoundHistory[uints[0]].lotteryBlockNo);
        require(_isWinningTicket(uints[0], b32s[1]));
        require(_isWinningTicket(uints[0], b32s[2]));
        require(opRound >= uints[0] && opRound < uints[0] + 16);  // can withdraw at this and some opRounds later

        // verify signature, generate txHash and proof the existence of all txHashes
        require(verifySignatureWithPrefix(msg.sender, b32s, _v));
        bytes32 txhash = genV2TxhashWrapper(msg.sender, b32s, uints, _v);
        require(txExistUintSide(claimProof, uintIsLeft[0], txhash, uints[3]));
        require(txExistUintSide(proof1, uintIsLeft[1], b32s[1], uints[1]));
        require(txExistUintSide(proof2, uintIsLeft[2], b32s[2], uints[2]));

        require(opRoundClaimed[uints[0]][msg.sender] == false); //, "An account can only withdraw once per opRound if qualified");
        opRoundClaimed[uints[0]][msg.sender] = true;

        QOTInterface(QOTAddr).mint(msg.sender, reward);
    }

    function genV2TxhashWrapper(address _sender, bytes32[6] memory b32s, uint[5] memory uints, uint8 _v) internal view returns(bytes32) {
        return genV2Txhash(_sender, uints[0], b32s[0], uints[1], b32s[1], uints[2], b32s[2], uints[4], _v, b32s[4], b32s[5]);
    }

    function genV2Txhash(
        address _sender, uint _opRound, bytes32 _comment, uint v1block, bytes32 v1leaf, uint v2block, bytes32 v2leaf, uint since,
        uint8 _v, bytes32 _r, bytes32 _s
    ) public view returns(bytes32) {
        //   ['uint', 'address', 'bytes32', 'bytes32', 'bytes32', 'uint', 'bytes32', 'uint', 'bytes32', 'uint', 'uint8', 'bytes32', 'bytes32]],
        //   [opround,  account,  comment,        aid,       oid, v1block,   v1leaf, v2block,   v2leaf,  since, v, r, s]
        return(keccak256(abi.encodePacked(  // in daemon.js, use web3.utils.soliditySha3()
                _opRound,
                hex"000000000000000000000000", _sender,  // nodejs abi.encodeParameter append zeros to make _sender 32 bytes
                _comment,
                hex"11be020000000000000000000000000000000000000000000000000000000000",  // aid
                opRoundHistory[_opRound].id,  // oid
                v1block,
                v1leaf,
                v2block,
                v2leaf,
                since,
                hex"00000000000000000000000000000000000000000000000000000000000000",  _v,  // make _v 32 bytes
                _r, _s
        )));
    }

    function txExistUintSide(bytes32[] memory proof, uint24 isLeftInt, bytes32 txHash, uint _sblockNo) public view returns (bool){
        require(_sblockNo < nowSblockNo);
        require(blockHistory[_sblockNo].merkleRoot != 0x0);
        bool[] memory isLeft = _uintToBoolArr(isLeftInt, uint8(proof.length));
        return merkleTreeValidator(proof, isLeft, txHash, blockHistory[_sblockNo].merkleRoot);
    }

    function _uintToBoolArr(uint24 x, uint8 length) public pure returns (bool[] memory isLeft){
        // for example, if x=10, length=6 => x in binary is '001010' => bool array [f, f, t, f, t, f]
        require(length >= 1 && length <= 24);
        isLeft = new bool[](length);
        for (uint i=0; i<length; i++){
            if (x%2 == 1) {
                isLeft[length-i-1] = true;
            }
            x = x >> 1;
        }
        return(isLeft);
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

    // query
    function getBlockNo() external view returns (uint) {
        return nowSblockNo;
    }

    function getBlockInfo(uint _sblockNo) external view returns (uint, bytes32, bytes32, bytes32, bytes32, bytes32, address) {
        // TODO: update the results
        return (blockHistory[_sblockNo].blockHeight,
                blockHistory[_sblockNo].merkleRoot,
                blockHistory[_sblockNo].ipfsAddr,
                blockHistory[_sblockNo].aidMerkleRoot,
                blockHistory[_sblockNo].aidIpfsAddr,
                blockHistory[_sblockNo].opRoundId,
                blockHistory[_sblockNo].validator
               );
    }

    function queryValidator(uint _idx) external view returns (address) {
        require(_idx>=0 && _idx < 16);
        return validators[_idx];
    }

    function isValidator(address _addr) external view returns (bool) {
        if (_addr == address(0)) {
            return false;
        } else {
            return (_addr == validators[0] || _addr == validators[1] || _addr == validators[2] ||
                    _addr == validators[3] || _addr == validators[4] || _addr == validators[5] ||
                    _addr == validators[6] || _addr == validators[7] || _addr == validators[8] ||
                    _addr == validators[9] || _addr == validators[10] || _addr == validators[11] ||
                    _addr == validators[12] || _addr == validators[13] || _addr == validators[14] ||
                    _addr == validators[15]);
        }
    }

    function queryManagers() external view returns (address[4] memory) {
        return managers;
    }

    function queryOpRound() external view returns (uint) {
        return opRound;
    }

    function queryOpRoundId(uint _opRound) external view returns (bytes32) {
        if (_opRound != 0) {
            return opRoundHistory[_opRound].id;
        } else {
            return opRoundHistory[opRound].id;  // current opRound
        }
    }

    function queryOpRoundLottery(uint _opRound) external view returns (uint, uint, bytes32) {
        uint i;
        if (_opRound == 0) {
            i = opRound;
        } else {
            i = _opRound;
        }
        return (i, opRoundHistory[i].lotteryBlockNo, opRoundHistory[i].lotteryWinNumber);
    }

    function queryOpRoundInfo(uint _opRound) external view returns (uint, bytes32, uint) {
        uint i;
        if (_opRound == 0) {
            i = opRound;
        } else {
            i = _opRound;
        }
        return (i, opRoundHistory[i].id, opRoundHistory[i].initBlockNo);
    }

    function queryOpRoundResult(uint _opRound) external view returns (uint, bytes32, uint, uint, bytes32, bytes32, uint, bytes32, uint) {
        // this function returns default values (0 and 0x0) for current pending opRound
        // this function is different from other `queryOpRound*()` in that a input of 0 does not mean query current opRound
        // For opRoundHistory[0], the id is '0x1' and the initBlockNo is the block.height during construction
        uint i;
        uint op;
        if (_opRound == opRound) {  // return (0, 0x0, 0, 0, 0x0, 0x0, 0, 0x0, 0);
            op = 0;
            i = opRound + 2;
            // 'stack too deep' if return (0, 0x0, ...) here and also return in next else-block!?
        } else {
            op = _opRound;
            i = _opRound;
        }
        return (op,
                opRoundHistory[i].id,
                opRoundHistory[i].initBlockNo,
                opRoundHistory[i].minSuccessRate,
                opRoundHistory[i].succesRateDB,
                opRoundHistory[i].finalListIpfs,
                opRoundHistory[i].lotteryBlockNo,
                opRoundHistory[i].lotteryWinNumber,
                opRoundHistory[i].baseline
               );
    }

    function queryOpRoundProgress() external view returns (uint, bool, uint, uint, uint, uint) {
        return(articleCount, atV1, v1EndTime, v2EndTime, roundVote1Count, roundVote2Count);
    }

    function queryVoteThresholds() external view returns(uint, uint, uint) {
        return (opRound, vote1Threshold, vote2Threshold);
    }

    function queryFinalist(uint _opRound) external view returns(uint, uint, bytes32){
        uint i;
        if (_opRound == 0) {
            i = opRound;
        } else {
            i = _opRound;
        }
        return (i, opRoundHistory[i].baseline, opRoundHistory[i].finalListIpfs);
    }

    // upgradable
    function setSblockTimeStep(uint _time) public managerOnly returns(bool) {
        require(_time > 60);
        sblockTimeStep = _time;
        return true;
    }

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
