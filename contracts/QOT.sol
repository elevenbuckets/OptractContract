pragma solidity ^0.5.2;
import "./ERC20/tokens/StandardToken.sol";

contract QOT is StandardToken {
    string private _symbol = "QOT";
    uint8 private _decimals = 12;
    uint256 public _maxSupply = 100000000000000000000000;
    address public owner;
    address[16] public mining;
    // uint256 public reward = 15000000000000;

    modifier ownerOnly() {
       require(msg.sender == owner);
       _;
    }

    // TODO: move miningOnly() and probably some access control to QOTaccessControl.sol?
    modifier miningOnly() {
        require(msg.sender != address(0));
        require(msg.sender == mining[0] || msg.sender == mining[1] || msg.sender == mining[2] ||
                msg.sender == mining[3] || msg.sender == mining[4] || msg.sender == mining[5] ||
                msg.sender == mining[6] || msg.sender == mining[7] || msg.sender == mining[8] ||
                msg.sender == mining[9] || msg.sender == mining[10] || msg.sender == mining[11] ||
                msg.sender == mining[12] || msg.sender == mining[13] || msg.sender == mining[14] ||
                msg.sender == mining[15]);
        _;
    }

    constructor() public {
       owner = msg.sender;
       totalSupply = 300000000000002500;
       _balances[0xB440ea2780614b3c6a00e512f432785E7dfAFA3E] = 100000000000000000;  // J
       _balances[0x4AD56641C569C91C64C28a904cda50AE5326Da41] = 100000000000000000;  // K
       _balances[0xaF7400787c54422Be8B44154B1273661f1259CcD] = 100000000000000000;  // L

       _balances[0xbb3Ac1Ef7Ae6A4a893429a60423F7c9AcdCb02aD] = 500;  // J
       _balances[0x89a3203156e4B756d58b6f32dB94249992d4d384] = 500;  // J
       _balances[0xf053b7f56bEfFBf660bBf81a7fd98880F1F550e7] = 500;  // J
       _balances[0x1B27DdcCB19A3706c6c44465B508cf905EeB4c62] = 500;  // K
       _balances[0xa87e88dF1dd3A1862ACf87E6c57FDCd8f7dB1716] = 500;  // K

    }

    function symbol() public view returns (string memory){
        return _symbol;
    }

    function decimals() public view returns (uint8){
        return _decimals;
    }

    // TODO: Making mining contract upgradable while limit owner from changing this arbitrarily
    function setMining(address _mining, uint _idx) ownerOnly external returns (bool) {
        require(_idx < 16);
	mining[_idx] = _mining;
	return true;
    }

    function queryMining(uint _idx) external view returns(address) {
        return mining[_idx];
    }

    function isMining() external view returns(bool){
        if (msg.sender == address(0)){
            return false;
        } else {
            return(msg.sender == mining[0] || msg.sender == mining[1] || msg.sender == mining[2] ||
                    msg.sender == mining[3] || msg.sender == mining[4] || msg.sender == mining[5] ||
                    msg.sender == mining[6] || msg.sender == mining[7] || msg.sender == mining[8] ||
                    msg.sender == mining[9] || msg.sender == mining[10] || msg.sender == mining[11] ||
                    msg.sender == mining[12] || msg.sender == mining[13] || msg.sender == mining[14] ||
                    msg.sender == mining[15]);
        }
    }

    function mint(address toAddress, uint _amount) miningOnly external returns (bool) {
        // assume verified by the mining() function
	require(totalSupply < _maxSupply);
	_balances[toAddress] += _amount;
	totalSupply += _amount;
	return true;
    }

    function burn(uint256 amount) external returns (bool) {
	require(_balances[msg.sender] >= amount);
	_balances[msg.sender] -= amount;
	totalSupply -= amount;

	return true;
    }
}
