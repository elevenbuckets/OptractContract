pragma solidity ^0.5.2;

import "./Interfaces/QOTInterface.sol";

// TODO: check integer overflow

contract MemberShip {
    address public owner;
    address[3] public coreManagers;
    address[8] public managers;
    address public QOTAddr;
    uint public totalId;  // id 0 is not used and will start from 1
    uint public fee = 0.01 ether;
    // uint public memberPeriod = 160000;  // 40000 blocks ~ a week in rinkeby, for test only
    uint public memberPeriod = 30 days;
    bool public paused;
    uint public activeMemberCount;  // need to call function to update this value

    struct MemberInfo {
        address addr;
        uint since;  // beginning block.timestamp of previous membership
        uint penalty;  // the membership is valid until: since + memberPeriod - penalty;
        bytes32 kycid;  // know your customer id, leave it for future
        string notes;
    }

    mapping (uint => MemberInfo) internal memberDB;  // id to MemberInfo
    mapping (address => uint) internal addressToId;  // address to membership

    mapping (address => bool) internal specialMember;
    uint public specialMemberBonus = 10000 days;  // value set in constructor

    mapping (address => bool) public appWhitelist;

    constructor(address _QOTAddr) public {
        owner = msg.sender;
        coreManagers = [0xB440ea2780614b3c6a00e512f432785E7dfAFA3E,
                        0x4AD56641C569C91C64C28a904cda50AE5326Da41,
                        0xaF7400787c54422Be8B44154B1273661f1259CcD];
        managers = [address(0), address(0), address(0), address(0), address(0), address(0), address(0), address(0)];
        QOTAddr = _QOTAddr;

        for (uint8 i=0; i<3; i++){
            _assignMembership(coreManagers[i]);
            specialMember[coreManagers[i]] = true;
            appWhitelist[coreManagers[i]] = true;
        }
        assert(totalId == 3);
        activeMemberCount = 3;  // manually set an initial value
    }

    modifier ownerOnly() {
        require(msg.sender == owner);
        _;
    }

    modifier coreManagerOnly() {
        require(msg.sender != address(0));
        require(msg.sender == coreManagers[0] || msg.sender == coreManagers[1] || msg.sender == coreManagers[2]);
        _;
    }

    modifier managerOnly() {
        require(msg.sender != address(0));
        require(msg.sender == coreManagers[0] || msg.sender == coreManagers[1] || msg.sender == coreManagers[2] ||
                msg.sender == managers[0] || msg.sender == managers[1] || msg.sender == managers[2] ||
                msg.sender == managers[3] || msg.sender == managers[4] || msg.sender == managers[5] ||
                msg.sender == managers[6] || msg.sender == managers[7]);
        _;
    }

    modifier feePaid() {
        require(msg.value >= fee);  // or "=="?
        _;
    }

    modifier isMember() {
        require(msg.sender != address(0));
        require(memberDB[addressToId[msg.sender]].since > 0);
        _;
    }

    modifier isActiveMember() {
        require(msg.sender != address(0));
        uint _id = addressToId[msg.sender];
        require(_id != 0);
        require(idExpireTime(_id) > block.timestamp);
        _;
    }

    modifier isAppWhitelist() {
        require(appWhitelist[msg.sender]);
        _;
    }

    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    modifier whenPaused {
        require(paused);
        _;
    }

    // membership
    function buyMembership() public payable feePaid whenNotPaused returns (bool) {
        require(addressToId[msg.sender] == 0);  // the user is not yet a member
        _assignMembership(msg.sender);
        return true;
    }

    function _assignMembership(address _addr) internal {
        totalId += 1;  // make it start from 1
        addressToId[_addr] = totalId;
        memberDB[totalId] = MemberInfo(_addr, block.timestamp, 0, bytes32(0), "");
    }

    function renewMembership() public payable feePaid whenNotPaused returns (uint) {
        uint _id = addressToId[msg.sender];
        require(msg.sender != address(0) && addressToId[msg.sender] != 0 && memberDB[_id].addr == msg.sender);
        uint _bonus;
        if (specialMember[memberDB[_id].addr]) {
            _bonus = specialMemberBonus;
        }
        require(block.timestamp > memberDB[_id].since + memberPeriod + _bonus - 7 days);
        memberDB[_id].since = block.timestamp;
        return block.timestamp;
    }

    function assginKYCid(uint _id, bytes32 _kycid) external managerOnly returns (bool) {
        // instead of "managerOnly", probably add another group to do that
        require(memberDB[_id].since > 0 && memberDB[_id].addr != address(0));
        memberDB[_id].kycid = _kycid;
        return true;
    }

    function addWhitelistApps(address _addr) public coreManagerOnly returns (bool) {
        appWhitelist[_addr] = true;
        return true;
    }

    function rmWhitelistApps(address _addr) public coreManagerOnly returns (bool) {
        appWhitelist[_addr] = false;
        return true;
    }

    function addPenalty(uint _id, uint _penalty) external returns (uint) {
        require(appWhitelist[msg.sender] == true);  // the msg.sender (usually a contract) is in appWhitelist
        require(memberDB[_id].since > 0);  // is a member
        // require(_penalty < memberPeriod);  // prevent too much penalty

        // In case of really large _penalty
        uint expireTime = idExpireTime(_id);
        if (expireTime > _penalty) {
            memberDB[_id].penalty += _penalty;
        } else {
            memberDB[_id].penalty = expireTime;
        }

        return memberDB[_id].penalty;
    }

    function readNotes(uint _id) external view returns (string memory) {
        require(memberDB[_id].since > 0);
        return memberDB[_id].notes;
    }

    function addNotes(uint _id, string calldata _notes) external managerOnly {
        require(memberDB[_id].since > 0);
        memberDB[_id].notes = _notes;
    }

    function toggleSpeicalMember(address _addr) public coreManagerOnly {  // for test only; should remove in future
        require(addrIsMember(_addr));
        specialMember[_addr] = !specialMember[_addr];
    }

    // some query functions
    function addrIsMember(address _addr) public view returns (bool) {
        require(_addr != address(0));
        return idIsMember(addressToId[_addr]);
    }

    function addrIsActiveMember(address _addr) public view returns (bool) {
        require(_addr != address(0));
        return idIsActiveMember(addressToId[_addr]);
    }

    function idIsMember(uint _id) public view returns (bool) {
        if (_id != 0 && memberDB[_id].addr != address(0)) {
            return true;
        } else {
            return false;
        }
    }

    function idIsActiveMember(uint _id) public view returns (bool) {
        require (_id > 0 || memberDB[_id].since > 0);
        if (idExpireTime(_id) > block.timestamp) {
            return true;  // not yet expire
        } else {
            return false;
        }
    }

    function idExpireTime(uint _id) public view returns (uint) {
        if (specialMember[memberDB[_id].addr]) {
            return memberDB[_id].since + memberPeriod - memberDB[_id].penalty + specialMemberBonus;
        } else {
            return memberDB[_id].since + memberPeriod - memberDB[_id].penalty;
        }
    }

    function addrToId(address _addr) external view returns (uint) {
        return addressToId[_addr];
    }


    function getMemberInfo(address _addr) external view returns (uint, bytes32, uint, uint){
        uint _id = addressToId[_addr];
        uint status;  // 0=connection error, 1=active, 2=inactive, 3=not member
        if (_id == 0) {
            status = 3;
        } else {
            if (idIsActiveMember(_id)){
                status = 1;
            } else {
                status = 2;
            }
        }
        return (status, bytes32(_id), memberDB[_id].since, memberDB[_id].penalty);
    }

    function getActiveMemberCount() public view returns (uint){
        return(activeMemberCount);
    }

    function updateActiveMembers() public isAppWhitelist returns (uint){
        activeMemberCount = _countActiveMembers();
        return(activeMemberCount);
    }

    function _countActiveMembers() internal view returns (uint) {
        uint _count = 0;
        for (uint i = 0; i < totalId; i++) {
            if (idExpireTime(i) > block.timestamp) {
                _count += 1;
            }
        }
        return _count;
    }

    // upgradable
    function pause() external coreManagerOnly whenNotPaused {
        paused = true;
    }

    function unpause() public ownerOnly whenPaused {
        // set to ownerOnly in case accounts of other managers are compromised
        paused = false;
    }

    function updateManager(address _addr, uint _id) public coreManagerOnly {
        // "managers" can assign KYC id
        require(_addr != address(0));
        managers[_id] = _addr;
    }

    function updateQOTAddr(address _addr) external ownerOnly {
        QOTAddr = _addr;
    }

}
