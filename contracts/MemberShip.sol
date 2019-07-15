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
    uint public lastMemberCountUpdate;  // use this to prevent too frequent update; see updateActiveMemberCount()
    bool public paused;
    uint public activeMemberCount;  // need to call function to update this value

    struct MemberInfo {
        address addr;
        uint8 tier;  // 8 bit of choices. Default tier is 1; tier>128 are vip (i.e., highest bit is 1). 0 and 128 are not used
        uint since;  // beginning block.timestamp of previous membership
        uint penalty;  // the membership is valid until: since + memberPeriod - penalty;
        bytes32 kycid;  // know your customer id, leave it for future
        string notes;
    }

    mapping (uint => MemberInfo) internal memberDB;  // id to MemberInfo
    mapping (address => uint) internal addressToId;  // address to membership
    uint public vipMemberBonus = 3650 days;

    address[16] public appWhitelist;

    constructor(address _QOTAddr) public {
        owner = msg.sender;
        coreManagers = [0xB440ea2780614b3c6a00e512f432785E7dfAFA3E,
                        0x4AD56641C569C91C64C28a904cda50AE5326Da41,
                        0xaF7400787c54422Be8B44154B1273661f1259CcD];
        managers = [address(0), address(0), address(0), address(0), address(0), address(0), address(0), address(0)];
        appWhitelist = [
            address(0), address(0), address(0), address(0), address(0), address(0), address(0), address(0),
            address(0), address(0), address(0), address(0), address(0), address(0), address(0), address(0)
        ];
        QOTAddr = _QOTAddr;

        for (uint8 i=0; i<3; i++){
            _assignMembership(coreManagers[i], 255);
            appWhitelist[i] = coreManagers[i];
        }
        assert(totalId == 3);
        activeMemberCount = 3;  // manually set an initial value
        lastMemberCountUpdate = block.timestamp;
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
        require(addressToId[msg.sender] != 0);
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
        require(msg.sender != address(0));
        require(msg.sender == appWhitelist[0] || msg.sender == appWhitelist[1] || msg.sender == appWhitelist[2] ||
                msg.sender == appWhitelist[3] || msg.sender == appWhitelist[4] || msg.sender == appWhitelist[5] ||
                msg.sender == appWhitelist[6] || msg.sender == appWhitelist[7] || msg.sender == appWhitelist[8] ||
                msg.sender == appWhitelist[9] || msg.sender == appWhitelist[10] || msg.sender == appWhitelist[11] ||
                msg.sender == appWhitelist[12] || msg.sender == appWhitelist[13] || msg.sender == appWhitelist[14] ||
                msg.sender == appWhitelist[15]
               );
        _;
    }

    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    modifier whenPaused() {
        require(paused);
        _;
    }

    // membership
    function buyMembership() public payable feePaid whenNotPaused returns (bool) {
        require(addressToId[msg.sender] == 0);  // the user is not yet a member
        // TODO: uint8 _tier = determineTier(msg.sender); _assignMembership(msg.sender, _tier);
        _assignMembership(msg.sender, 1);
        return true;
    }

    function _assignMembership(address _addr, uint8 _tier) internal {
        totalId += 1;  // make it start from 1
        addressToId[_addr] = totalId;
        memberDB[totalId] = MemberInfo(_addr, _tier, block.timestamp, 0, bytes32(0), "");
    }

    function renewMembership() public payable feePaid isMember whenNotPaused returns (uint) {
        uint _id = addressToId[msg.sender];
        uint _bonus;
        if (isVipTier(_id)) {
            _bonus = vipMemberBonus;
        }
        require(block.timestamp > idExpireTime(_id) - 7 days);

        // renew membership (and remove vip tier if possible)
        memberDB[_id].since = block.timestamp;
        _removeVipTier(_id);
        return (block.timestamp + memberPeriod + _bonus);  // return expire time
    }

    function updateTier(uint8 _tier, address _addr) public coreManagerOnly returns(bool){
        // should eventually use `determineTier(_addr)` and remove the `_tier` argument
        require(addrIsMember(_addr));  // or addrIsActiveMember()?
        require(_tier != 0 && _tier != 128);  // 0 and 128 are not used
        // TODO: determine tier base on the amount of QOT the member owns;
        // Q: Users call this function?
        // Q: should the sufficient amount of QOT "locked" in a pool for enough time?
        // Q: Is downgrade tier happen here? Or only while renewMembership()?
        uint _id = addressToId[_addr];
        memberDB[_id].tier = _tier;
        return true;
    }

    function determineTier(address _addr) public view returns(uint8) {
        require(addrIsMember(_addr) == true);
        uint8 tier=1;  // the basic tier
        // uint _bal = QOTInterface(QOTAddr).balanceOf(_addr);
        // TODO: depend of _bal and give a tier?
        return tier;
    }

    function isVipTier(uint _id) public view returns(bool){
        return(memberDB[_id].tier > 128);  // tier 128 should not exist
    }

    function _removeVipTier(uint _id) internal returns(uint8) {
        // don't do any check, assume the _id is already member
        if (memberDB[_id].tier > 128) {
            memberDB[_id].tier = memberDB[_id].tier - 128;
        }
        return memberDB[_id].tier;
    }

    function assginKYCid(uint _id, bytes32 _kycid) external managerOnly returns (bool) {
        // instead of "managerOnly", probably add another group to do that
        require(memberDB[_id].since > 0 && memberDB[_id].addr != address(0));
        memberDB[_id].kycid = _kycid;
        return true;
    }

    function addAppWhitelist(address _addr, uint _idx) public coreManagerOnly returns (bool) {
        require(_addr != address(0));
        require(appWhitelist[_idx] == address(0));
        appWhitelist[_idx] = _addr;
        return true;
    }

    function replaceAppWhitelist(address _addr, uint _idx) public coreManagerOnly returns (address) {
        require(_addr != address(0));
        require(appWhitelist[_idx] != address(0));
        address _addrorig = appWhitelist[_idx];
        appWhitelist[_idx] = _addr;
        return _addrorig;
    }

    function rmAppWhitelist(uint _idx) public coreManagerOnly returns (address) {
        require(appWhitelist[_idx] != address(0));
        address _addr = appWhitelist[_idx];
        delete appWhitelist[_idx];
        return _addr;
    }

    function getAppWhitelist() external view managerOnly returns (address[16] memory) {
        return appWhitelist;
    }

    function addPenalty(uint _id, uint _penalty) external isAppWhitelist returns (uint) {
        require(memberDB[_id].since > 0);  // is a member
        require(_penalty < memberDB[_id].since + memberPeriod);  // prevent overflow while calculate idExpireTime(_id)
        // require(_penalty < memberPeriod);  // or, can we ban someone for many memberPeriods?
        // require(_penalty < 3*memberPeriod);
        // or, only core manager can set a really large _panalty (like 6 months or more) for extreme case
        memberDB[_id].penalty = _penalty;

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
        require (_id != 0 || memberDB[_id].since > 0);
        if (idExpireTime(_id) > block.timestamp) {
            return true;  // not yet expire
        } else {
            return false;
        }
    }

    function idExpireTime(uint _id) public view returns (uint) {
        uint _bonus;
        if (isVipTier(_id)) {
            _bonus = vipMemberBonus;
        }
        uint _expectTime = memberDB[_id].since + memberPeriod + _bonus;
        if (_expectTime > memberDB[_id].penalty) {
            return _expectTime - memberDB[_id].penalty
        } else {
            return 0;
        }
    }

    function addrToId(address _addr) external view returns (uint) {
        return addressToId[_addr];
    }

    function getMemberInfo(address _addr) external view returns (uint, bytes32, uint8, uint, uint, bytes32){
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
        return (status, bytes32(_id), memberDB[_id].tier, memberDB[_id].since, memberDB[_id].penalty, memberDB[_id].kycid);
    }

    function getActiveMemberCount() public view isMember returns (uint){
        return(activeMemberCount);
    }

    function updateActiveMemberCount(bool _forced) public isAppWhitelist returns (uint){
        // only update once per _cooldownTime, unless set _forced to true
        require(block.timestamp > lastMemberCountUpdate);
        uint _cooldownTime = 24 hours;  // or 12 hours? Is this also sort of grace period when a membership expires?
        if ((block.timestamp - lastMemberCountUpdate < _cooldownTime && _forced) ||
            (block.timestamp - lastMemberCountUpdate > _cooldownTime)) {
            activeMemberCount = _countActiveMembers();
            lastMemberCountUpdate = block.timestamp;
        }  // else don't count
        return(activeMemberCount);
    }

    function _countActiveMembers() internal view returns (uint) {
        uint _count = 0;
        for (uint i = 0; i <= totalId; i++) {
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

    function updateOwner(address _addr) public ownerOnly {
        require(addrIsActiveMember(_addr));
        owner = _addr;
    }

    function updateManager(address _addr, uint _id) public coreManagerOnly {
        // "managers" can assign KYC id
        require(_addr != address(0));
        managers[_id] = _addr;
    }

    function getManagers() external view coreManagerOnly returns(address[8] memory) {
        return managers;
    }

    function updateQOTAddr(address _addr) external ownerOnly {
        QOTAddr = _addr;
    }

}
