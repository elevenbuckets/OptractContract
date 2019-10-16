pragma solidity ^0.5.2;

// import "./Interfaces/MemberShipInterface.sol";

contract accessControl {
    address public owner;
    address public memberCtrAddr;
    address[8] public managers;
    address[8] public spenders;
    uint public minHoldingsToTransfer = 5000;
    uint public maxTransfer = 2500;

    constructor() public {
        managers = [ 0xB440ea2780614b3c6a00e512f432785E7dfAFA3E,
                     0x4AD56641C569C91C64C28a904cda50AE5326Da41,
                     0xaF7400787c54422Be8B44154B1273661f1259CcD,
                     address(0), address(0), address(0), address(0), address(0)];
        spenders = [ address(0), address(0), address(0), address(0),
                     address(0), address(0), address(0), address(0) ];
    }

    modifier ownerOnly() {
        require(msg.sender == owner);
        _;
    }

    modifier managerOnly() {
        require(isManager(msg.sender));
        _;
    }

    function isManager(address _addr) internal view returns (bool) {
        if (_addr == address(0) ) {  // managers 3/4 may be 0
            return false;
        } else if (_addr == managers[0] || _addr == managers[1] || _addr == managers[2] ||
                   _addr == managers[3] || _addr == managers[4] || _addr == managers[5] ||
                   _addr == managers[6] || _addr == managers[7]
                  ) {
            return true;
        } else {
            return false;
        }
    }

    function isSpender(address _addr) internal view returns (bool) {
        if (_addr == address(0) ) {
            return false;
        } else if (_addr == spenders[0] || _addr == spenders[1] || _addr == spenders[2] ||
                   _addr == spenders[3] || _addr == spenders[4] || _addr == spenders[5] ||
                   _addr == spenders[6] || _addr == spenders[7]
                  ) {
            return true;
        } else {
            return false;
        }
    }

    function setMemberCtrAddr(address _memberCtrAddr) public ownerOnly returns (bool) {
        memberCtrAddr = _memberCtrAddr;
        return true;
    }

    function addManager(address _newAddr, uint8 _idx) external managerOnly returns (bool) {
        require(_idx > 3);  // cannot replace the first 3 managers in this contract!
        managers[_idx] = _newAddr;
        return true;
    }

    function queryManager(uint _idx) external view returns (address) {
        return managers[_idx];
    }

    function addSpender(address _newAddr, uint8 _idx) external managerOnly returns (bool) {
        spenders[_idx] = _newAddr;
        return true;
    }

    function querySpender(uint _idx) external view returns (address) {
        return spenders[_idx];
    }

    function setMinHoldingsToTransfer(uint _amount) external managerOnly returns (bool) {
        minHoldingsToTransfer = _amount;
        return true;
    }

    function queryMinHoldingsToTransfer() public view returns (uint) {
        return minHoldingsToTransfer;
    }


    function setMaxTransfer(uint _amount) external managerOnly returns (bool) {
        maxTransfer = _amount;
        return true;
    }

    function queryMaxTransfer() public view returns (uint) {
        return maxTransfer;
    }

    function queryQuotas() external view returns (uint, uint) {
        return (minHoldingsToTransfer, maxTransfer);
    }

}
