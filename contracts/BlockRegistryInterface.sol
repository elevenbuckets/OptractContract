pragma solidity ^0.5.2;

interface BlockRegistryInterface {

    function submitMerkleRoot(uint _initHeight, bytes32 _merkleRoot, bytes32 _ipfsAddr) external returns (bool);
    function merkleTreeValidator(bytes32[] calldata proof, bool[] calldata isLeft, bytes32 targetLeaf, bytes32 _merkleRoot) external pure returns (bool);
    function getSblockNo() external view returns (uint);
    function getBlockInfo(uint _sblockNo) external view returns (uint, bytes32, string memory);
    function queryValidator(uint _idx) external view returns (address);
    function queryManagers() external view returns (address[4] memory);
    function setValidator(address _newValidator, uint _idx) external returns (bool);
    function setManager(address _newManager) external returns (bool);
}
