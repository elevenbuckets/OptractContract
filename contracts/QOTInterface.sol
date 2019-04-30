pragma solidity ^0.5.2;
import "./ERC20/tokens/StandardToken.sol";

contract QOTInterface is StandardToken {
    function symbol() public view returns (string memory);
    function decimals() public view returns (uint8);
    function setMiner(address _miner, uint _idx) external returns (bool);
    function queryMiner(uint _idx) external returns(address);
    function mint(address toAddress, uint _amount) external returns (bool);
    function burn(uint256 amount) external returns (bool);
}
