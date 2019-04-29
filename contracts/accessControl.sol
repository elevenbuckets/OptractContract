pragma solidity ^0.5.2;

// inherited by ./ERC721/tokens/nf-token.sol in order to add functions into ERC 721 token

contract accessControl {
    address public owner;
    address[5] public managers;
    address[7] public mining;

    constructor() public {
        // always INITIALIZE ARRAY VALUES!!!
        managers = [ 0xB440ea2780614b3c6a00e512f432785E7dfAFA3E,
                     0x4AD56641C569C91C64C28a904cda50AE5326Da41,
                     0xaF7400787c54422Be8B44154B1273661f1259CcD,
                     address(0),
                     address(0)];

        // note: only "mining" address can mint or transfer
        mining = [address(0), address(0), address(0), address(0), address(0), address(0), address(0)];
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
                   _addr == managers[3] || _addr == managers[4]) {
            return true;
        } else {
            return false;
        }
    }

    function isMiner(address _addr) internal view returns (bool) {
        if (_addr == address(0) ) {
            return false;
        } else if (_addr == mining[0] || _addr == mining[1] || _addr == mining[2] ||
                   _addr == mining[3] || _addr == mining[4] || _addr == mining[5] ||
                   _addr == mining[6]){
            return true;
        } else {
            return false;
        }
    }

    function isMinerOrManager(address _addr) internal view returns (bool) {
        if (isMiner(_addr) || isManager(_addr)) {
            return true;
        } else {
            return false;
        }
    }

    function setMining(address _miningAddress, uint8 _idx) external managerOnly returns (bool) {
        require(_idx < 7);  // max 7 addresses can mint and burn
        //require(mining[_idx] == address(0)); // comment to allow this to be changed many times
        mining[_idx] = _miningAddress;
        return true;
    }

    function addManager(address _newAddr, uint8 _idx) external managerOnly returns (bool) {
        require(_idx == 3 || _idx == 4);  // cannot replace the first 3 managers in this contract!
        managers[_idx] = _newAddr;
        return true;
    }

    function queryMining(uint _idx) external view returns (address) {
        return mining[_idx];
    }

    function queryManager(uint _idx) external view returns (address) {
        return managers[_idx];
    }

}
