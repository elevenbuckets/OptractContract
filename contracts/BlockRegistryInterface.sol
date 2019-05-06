pragma solidity ^0.5.2;

interface BlockRegistryInterface {

    function submitMerkleRoot(uint _initHeight, bytes32 _merkleRoot, bytes32 _ipfsAddr) external returns (bool);
    function merkleTreeValidator(bytes32[] calldata proof, bool[] calldata isLeft, bytes32 targetLeaf, bytes32 _merkleRoot) external pure returns (bool);
    function calcLeaf(uint _nonce, bytes32 _ipfs, uint _since, uint _agree, uint _disagree, bytes32 _reply, bytes32 _comment) external view returns (bytes32);
    function calcLeaf2(uint _nonce, address _sender, bytes32 _ipfs, uint _since, uint _agree, uint _disagree, bytes32 _reply, bytes32 _comment) external view returns (bytes32);
    function calcAccountStateSummaryLeaf(address _account, uint _start, uint _end, uint _gain, uint _apUsed, uint _accReward) external returns (bytes32);
    function getBlockNo() external view returns (uint);
    function getBlockInfo(uint _sblockNo) external view returns (uint, bytes32, string memory);
    function queryValidator(uint _idx) external view returns (address);
    function queryManagers() external view returns (address[4] memory);
    function setValidator(address _newValidator, uint _idx) external returns (bool);
    function setManager(address _newManager) external returns (bool);
}
