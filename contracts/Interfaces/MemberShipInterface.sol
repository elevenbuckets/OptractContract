pragma solidity ^0.5.2;

interface MemberShipInterface {

    function buyMembership() external payable returns (bool);
    function renewMembership() external payable returns (uint);
    function assginKYCid(uint _id, bytes32 _kycid) external returns (bool);
    function addWhitelistApps(address _addr) external returns (bool);
    function rmWhitelistApps(address _addr) external returns (bool);
    function addPenalty(uint _id, uint _penalty) external returns (uint);
    function readNotes(uint _id) external view returns (string memory);
    function addNotes(uint _id, string calldata _notes) external;
    function toggleSpeicalMember(address _addr) external;  // for dev only
    function addrIsMember(address _addr) external view returns (bool);
    function addrIsActiveMember(address _addr) external view returns (bool);
    function idIsMember(uint _id) external view returns (bool);
    function idIsActiveMember(uint _id) external view returns (bool);
    function idExpireTime(uint _id) external view returns (uint);
    function addrToId(address _addr) external view returns (uint);
    function getMemberInfo(address _addr) external view returns (uint, bytes32, uint, uint);
    function getActiveMemberCount() external view returns (uint);
    function updateActiveMembers() external returns (uint);
    function pause() external;
    function unpause() external;
    function updateManager(address _addr, uint _id) external;
    function updateQOTAddr(address _addr) external;

}
