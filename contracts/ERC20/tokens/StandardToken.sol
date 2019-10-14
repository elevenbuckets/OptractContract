pragma solidity ^0.5.2;
import "./ERC20.sol";
import "../../lib/safe-math.sol";
import "../../QOTaccessControl.sol";

contract StandardToken is ERC20, accessControl {
    using SafeMath for uint256;

    mapping (address => uint256) internal _balances;

    // The outside mapping key will be the owner, and the inside mapping key is spender
    mapping (address => mapping (address => uint256)) private _allowed;
    
    uint256 public totalSupply;

    /**
    * @dev Gets the balance of the specified address.
    * @param _owner The address to query the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address _owner) external view returns (uint256){
        return _balances[_owner];
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param _owner address The address which owns the funds.
     * @param _spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address _owner, address _spender) external view returns (uint256){
        return _allowed[_owner][_spender];
    }
    /**
    * @dev Transfer token for a specified address
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function transfer(address to, uint256 value) external returns (bool){
        require(value <= _balances[msg.sender]);
        require(to != address(0));
        require(super.isManager(msg.sender) || 
                ( _balances[msg.sender] > super.queryMinHoldingsToTransfer() && value <= super.queryMaxTransfer() )
               );
        _balances[msg.sender] = _balances[msg.sender].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(msg.sender, to, value);
        return true;
    }

    /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param spender The address which will spend the funds.
   * @param value The amount of tokens to be spent.
   */
    function approve(address spender, uint256 value) external returns (bool){
        require(spender != address(0));
        require(super.isManager(spender) || super.isSpender(spender));
        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true; 
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool){
        require(value <= _allowed[from][msg.sender]);
        require(value <= _balances[from]);
        require(to != address(0));
        require(super.isManager(msg.sender) || super.isSpender(msg.sender));
        _balances[msg.sender] = _balances[msg.sender].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(msg.sender, to, value);
        return true;
    }
}
