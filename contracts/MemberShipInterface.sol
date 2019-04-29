pragma solidity ^0.5.2;

interface MemberShip {

    function buyMembership() external payable returns (bool);
    function renewMembership() external payable returns (uint);

    function addWhitelistApps(address _addr) external returns (bool);
    function rmWhitelistApps(address _addr) external returns (bool);
    function addPenalty(uint _id, uint _penalty) external returns (uint);
    function readNotes(uint _id) external view returns (string memory);
    function addNotes(uint _id, string calldata _notes) external;
    function addrIsMember(address _addr) external view returns (bool);
    function addrIsActiveMember(address _addr) external view returns (bool);
    function idIsMember(uint _id) external view returns (bool);
    function idIsActiveMember(uint _id) external view returns (bool);
    function addrToId(address _addr) external view returns (uint);
    function getMemberInfo(address _addr) external view returns (uint, bytes32, uint, uint);
    function pause() external;
    function unpause() external;
    function updateManager(address _addr, uint _id) external;
    function updateQOTAddr(address _addr) external;

}
