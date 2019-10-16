pragma solidity ^0.5.2;

interface BlockRegistryInterface {

    function updateMaxVoteTime(uint _seconds) external;
    function setThreshold(uint _x, uint _y) external;
    function submitMerkleRoot(
        bytes32 _merkleRoot,
        bytes32 _ipfsAddr,
        bytes32 _aidMerkleRoot,
        bytes32 _aidIpfsAddr,
        bytes32 _successRateDB,
        bytes32 _finalListIpfs,
        uint[5] calldata _ints // uint _uniqArticleCount, uint _vote1Count, uint _vote2Count, uint _minSuccessRate, uint _baseline
    ) external returns (bool);
    function isEnoughV1(uint v1Count) external view returns (bool);
    function isEnoughV2(uint v2Count) external view returns (bool);
    function calcLotteryWinNumber(bytes32 _mr, bytes32 _bhash) external pure returns(bytes32);
    function lotteryWins(bytes32 _winHex, bytes32 _ticket, uint8 _numRange) external pure returns(bool);
    function isWinningTicket(uint _opRound, bytes32 _ticket) external view returns(bool, uint);
    function txExist(bytes32[] calldata proof, bool[] calldata isLeft, bytes32 txHash, uint _sblockNo) external view returns (bool);
    function aidExist(bytes32[] calldata proof, bool[] calldata isLeft, bytes32 aid, uint _sblockNo) external view returns (bool);
    function setReward(uint _reward) external;
    function withdraw(
        bytes32[6] calldata b32s, uint[5] calldata uints,
        bytes32[] calldata claimProof, bytes32[] calldata proof1, bytes32[] calldata proof2,
        uint24[3] calldata uintIsLeft, uint8 _v
    ) external returns(bool);
    function merkleTreeValidator(bytes32[] calldata proof, bool[] calldata isLeft, bytes32 targetLeaf, bytes32 _merkleRoot) external pure returns (bool);
    // function calcLeaf(uint _nonce, bytes32 _ipfs, uint _since, uint _agree, uint _disagree, bytes32 _reply, bytes32 _comment) external view returns (bytes32);
    function getBlockNo() external view returns (uint);
    function getBlockInfo(uint _sblockNo) external view returns (uint, bytes32, bytes32, bytes32, bytes32, bytes32, address);
    function queryValidator(uint _idx) external view returns (address);
    function isValidator(address _addr) external view returns (bool);
    function queryManagers() external view returns (address[4] memory);
    function queryOpRound() external view returns (uint);
    function queryOpRoundId(uint _opRound) external view returns (bytes32);
    function queryOpRoundLottery(uint _opRound) external view returns (uint, uint, bytes32);
    function queryOpRoundInfo(uint _opRound) external view returns (uint, bytes32, uint);
    function queryOpRoundResult(uint _opRound) external view returns (uint, bytes32, uint, uint, bytes32, bytes32, uint, bytes32, uint);
    function queryOpRoundProgress() external view returns (uint, bool, uint, uint, uint, uint);
    function queryVoteThresholds() external view returns(uint, uint, uint);
    function queryFinalist(uint _opRound) external view returns(uint, uint, bytes32);
    function setValidator(address _newValidator, uint _idx) external returns (bool);
    function setManager(address _newManager) external returns (bool);
}
