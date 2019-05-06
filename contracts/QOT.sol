pragma solidity ^0.5.2;
import "./ERC20/tokens/StandardToken.sol";

contract QOT is StandardToken {
    string private _symbol = "QOT";
    uint8 private _decimals = 12;
    uint256 public _maxSupply = 100000000000000000000000;
    address public owner;
    address[16] public miners;
    // uint256 public reward = 15000000000000;

    modifier ownerOnly() {
       require(msg.sender == owner);
       _;
    }

    modifier minerOnly() {
        require(msg.sender != address(0));
        require(msg.sender == miners[0] || msg.sender == miners[1] || msg.sender == miners[2] || 
                msg.sender == miners[3] || msg.sender == miners[4] || msg.sender == miners[5] || 
                msg.sender == miners[6] || msg.sender == miners[7] || msg.sender == miners[8] || 
                msg.sender == miners[9] || msg.sender == miners[10] || msg.sender == miners[11] || 
                msg.sender == miners[12] || msg.sender == miners[13] || msg.sender == miners[14] ||
                msg.sender == miners[15]);
        _;
    }

    constructor() public {
       owner = msg.sender;
       totalSupply = 300000000000000000;  // from StandardToken.sol
       _balances[0xB440ea2780614b3c6a00e512f432785E7dfAFA3E] = 100000000000000000;
       _balances[0x4AD56641C569C91C64C28a904cda50AE5326Da41] = 100000000000000000;
       _balances[0xaF7400787c54422Be8B44154B1273661f1259CcD] = 100000000000000000;
    }

    function symbol() public view returns (string memory){
        return _symbol;
    }

    function decimals() public view returns (uint8){
        return _decimals;
    }

    // TODO: Making mining contract upgradable while limit owner from changing this arbitrarily
    function setMining(address _miner, uint _idx) ownerOnly external returns (bool) {
	//require(miners[_idx] == address(0)); // For debug, allow this to be changed many times
	miners[_idx] = _miner;
	return true;
    }

    function queryMining(uint _idx) external view returns(address) {
        return miners[_idx];
    }

    function mint(address toAddress, uint _amount) minerOnly external returns (bool) {
        // assume verified by the miner() function
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
