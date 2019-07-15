pragma solidity ^0.5.2;

interface MemberShipInterface {

    function buyMembership() external payable returns (bool);
    function renewMembership() external payable returns (uint);
    function updateTier(uint8 _tier, address _addr) external returns(bool);
    function determineTier(address _addr) external view returns(uint8);
    function isViplTier(uint _id) external view returns(bool);
    function assginKYCid(uint _id, bytes32 _kycid) external returns (bool);
    function addAppWhitelist(address _addr, uint _idx) external returns (bool);
    function replaceAppWhitelist(address _addr, uint _idx) external returns (address);
    function rmAppWhitelist(uint _idx) external returns (address);
    function getAppWhitelist() external view returns (address[16] memory);
    function addPenalty(uint _id, uint _penalty) external returns (uint);
    function readNotes(uint _id) external view returns (string memory);
    function addNotes(uint _id, string calldata _notes) external;
    function addrIsMember(address _addr) external view returns (bool);
    function addrIsActiveMember(address _addr) external view returns (bool);
    function idIsMember(uint _id) external view returns (bool);
    function idIsActiveMember(uint _id) external view returns (bool);
    function idExpireTime(uint _id) external view returns (uint);
    function addrExpireTime(address _addr) external view returns (uint);
    function addrToId(address _addr) external view returns (uint);
    function getMemberInfo(address _addr) external view returns (uint, bytes32, uint8, uint, uint, uint, bytes32);
    function getActiveMemberCount() external view returns (uint);
    function updateActiveMemberCount(bool _forced) external returns (uint);
    function pause() external;
    function unpause() external;
    function updateManager(address _addr, uint _id) external;
    function updateQOTAddr(address _addr) external;

}
