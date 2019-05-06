pragma solidity ^0.5.2;
import "./ERC721/math/safe-math.sol";


contract BlockRegistry{
    using SafeMath for uint256;

    // Variables
    address[4] public managers;  // use "coreManagers" and "managers" as in "MemberShip.sol"?
    address[16] public validators;
    uint public initHeight;
    uint public sblockNo;  // start from 1
    // uint public prevTimeStamp;
    uint public sblockTimeStep = 60 minutes;  // what's the balance between UX and cost-control?

    struct blockStat{
        uint blockHeight;
        bytes32 merkleRoot;
        // string ipfsAddr;
        // save ipfsAddr in bytes32 (instead of string) to save storage; to convert ipfsAddr from
        // string to hex: 1. strip the 'Qm', 2. convert to hex
        bytes32 ipfsAddr;
        uint timestamp;
    }
    mapping (uint => blockStat) public blockHistory;

    // struct articleStatStruct{
    //     address authorAddr;
    //     uint since;
    //     uint8 status;  // should contain: unknown / active / archived / flagged / debate /  ...
    //     uint8 category;  // contain politics / blockchain / ...? or?
    //     uint32 agree;  // uint32 ~ 4e9
    //     uint32 disagree;
    // }
    // mapping (bytes32 => articleStatStruct) public articleStat;


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
        blockHistory[0] = blockStat(block.number, '0x0', '0x0', block.timestamp);  // or some more "meaningful" data?
        sblockNo = 1;
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

    function submitMerkleRoot(uint _initHeight, bytes32 _merkleRoot, bytes32 _ipfsAddr) public validatorOnly returns (bool) {
        // require(block.timestamp >= blockHistory[sblockNo] + sblockTimeStep, 'too soon');
        require(block.timestamp >= blockHistory[sblockNo].timestamp + 2 minutes);  // for test purpose, use 2 min instead of sblockTimeStep
        require(blockHistory[sblockNo+1].blockHeight == 0 && blockHistory[sblockNo+1].timestamp == 0);
        // comment following lines for debug purpose
        // require(blockHistory[_initHeight].blockHeight == 0 &&
        //         blockHistory[_initHeight].merkleRoot == 0x0 &&
        //         keccak256(abi.encodePacked(blockHistory[_initHeight].ipfsAddr)) == keccak256(abi.encodePacked('')),
        //         'side-block exists');
        // require(blockHistory[sblockNo-1].blockHeight < _initHeight);
        blockHistory[sblockNo] = blockStat(_initHeight, _merkleRoot, _ipfsAddr, block.timestamp);
        // Q: or blockHistory[block.number]?
        // Q: is it worth to add the field such as "prevInitHeight" in the struct?
        sblockNo += 1;
        return true;
    }

    // merkle tree and leaves
    function merkleTreeValidator(
        bytes32[] calldata proof,
        bool[] calldata isLeft,
        bytes32 targetLeaf,
        bytes32 _merkleRoot
    ) external pure returns (bool) {
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

    function calcLeaf(
        uint _nonce,
        bytes32 _ipfs,
        uint _since,
        uint _agree,
        uint _disagree,
        bytes32 _reply,
        bytes32 _comment
    ) external view returns (bytes32) {
        // note: the "category" field is not here yet
        return keccak256(abi.encodePacked(_nonce, msg.sender, _ipfs, _since, _agree, _disagree, _reply, _comment));
    }

    function calcLeaf2(
        uint _nonce,
        address _sender,
        bytes32 _ipfs,
        uint _since,
        uint _agree,
        uint _disagree,
        bytes32 _reply,
        bytes32 _comment
    ) external view managerOnly returns (bytes32) {
        return keccak256(abi.encodePacked(_nonce, _sender, _ipfs, _since, _agree, _disagree, _reply, _comment));
    }

    // function getActiveArticles() external view returns (bytes32[] memory) {
    //     bytes32[] memory articles;
    //     return articles;
    // }

    function calcAccountStateSummaryLeaf(
        address _account,
        uint _start,
        uint _end,
        uint _gain,
        uint _apUsed,
        uint _accReward
    ) external view validatorOnly returns (bytes32){
        return keccak256(abi.encodePacked(msg.sender, _account, _start, _end, _gain, _apUsed, _accReward));
    }

    // query
    function getBlockNo() external view returns (uint) {
        return sblockNo;
    }

    function getBlockInfo(uint _sblockNo) external view returns (uint, bytes32, bytes32) {
        return (blockHistory[_sblockNo].blockHeight, blockHistory[_sblockNo].merkleRoot, blockHistory[_sblockNo].ipfsAddr);
    }

    function queryValidator(uint _idx) external view returns (address) {
        require(_idx>=0 && _idx < 16);
        return validators[_idx];
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
