pragma solidity ^0.4.18;

import "./Owner.sol";
import "./lib/iterableMapping.sol";

contract Token is Owner
{
    using iterableMapping for iterableMapping.itMap;
    using iterable2DMapping for iterable2DMapping.it2DMap;
    
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint public totalSupply;
    uint public sellPrice = 1 ether;
    uint public buyPrice = 1 ether;

    mapping (address => uint) public balanceOf;
    iterable2DMapping.it2DMap allowance;
    mapping (address => bool) public frozenAccount;

    event FrozenFunds(address target, bool frozen);
    event Transfer(address indexed from, address indexed to, uint value);
    event Burn(address indexed from, uint value);

    /*
     * Constrctor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    function Token(uint _supply,string _name,string _symbol) public payable
    {
        totalSupply = _supply * 10 ** uint(decimals); // Update total supply with the decimal amount
        balanceOf[msg.sender] = totalSupply/10;       // Give the creator 1/10 initial tokens
        balanceOf[this] = totalSupply*9/10;           // Minter has the rest
        name = _name;                                 // Set the name for display purposes
        symbol = _symbol;                             // Set the symbol for display purposes
    }

    // return user and minter's ether & token balances
    function getBalances() public view returns (uint minter_token,uint user_token,uint minter_ether,uint user_ether)
    {
      return (balanceOf[this],balanceOf[msg.sender],this.balance,msg.sender.balance);
    }

    /*
     * Transfer tokens
     *
     * Send `_amount` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _amount the amount to send
     */
    function transfer(address _to, uint _amount) public
    {
        _transfer(msg.sender, _to, _amount);
    }

    /*
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint _amount) internal
    {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != 0x0);
        // Check if the sender has enough
        require(balanceOf[_from] >= _amount);
        // Check for overflows
        require(balanceOf[_to] + _amount > balanceOf[_to]);
        // Check whether 2 address is frozen
        require(!frozenAccount[_from] && !frozenAccount[_to]);
        // Save this for an assertion in the future
        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        // Subtract from the sender
        balanceOf[_from] -= _amount;
        // Add the same to the recipient
        balanceOf[_to] += _amount;
        Transfer(_from, _to, _amount);
        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }

    /*
     * @notice Create `_amount` tokens and send it to `_target`
     * @param _target Address to receive the tokens
     * @param _amount the amount of tokens it will receive
     */
    function mint(address _target, uint _amount) onlyOwner public
    {
        require(_target != 0x0);          // Prevent mint in vein
        balanceOf[_target] += _amount;
        totalSupply += _amount;
        Transfer(0, this, _amount);
        Transfer(this, _target, _amount);
    }
    
    /*
     * Destroy tokens
     *
     * Remove `_amount` tokens from the system irreversibly
     *
     * @param _amount the amount of money to burn
     */
    function burn(uint _amount) public returns (bool success)
    {
        require(balanceOf[msg.sender] >= _amount);   // Check if the sender has enough
        balanceOf[msg.sender] -= _amount;            // Subtract from the sender
        totalSupply -= _amount;                      // Updates totalSupply
        Burn(msg.sender, _amount);
        return true;
    }

    /*
     * @notice Allow users to buy tokens for `newBuyPrice` eth and sell tokens for `newSellPrice` eth
     * @param _sellPrice Price the users can sell to the contract
     * @param _buyPrice Price users can buy from the contract
     */
    function setPrices(uint _sellPrice, uint _buyPrice) onlyOwner public
    {
        setSellPrice(_sellPrice);
        setBuyPrice(_buyPrice);
    }

    function setSellPrice(uint _sellPrice) onlyOwner public
    {
        sellPrice = _sellPrice;
    }

    function setBuyPrice(uint _buyPrice) onlyOwner public
    {
        buyPrice = _buyPrice;
    }

    /*
     * @notice Sell `amount` tokens to contract
     * @param amount amount of tokens to be sold
     */
    function sell(uint _amount) public returns (uint revenue)
    {
        revenue=_amount * sellPrice/1 ether;
        require(this.balance >= revenue);                 // checks if the contract has enough ether to buy
        _transfer(msg.sender, this, revenue*1 ether/sellPrice);   // makes the transfers
        msg.sender.transfer(revenue);                     // sends ether to the seller. It's important to do this last to avoid recursion attacks
        return revenue;
    }


    // @notice Buy tokens from contract by sending ether
    function buy() payable public returns (uint amount)
    {
        amount = msg.value*1 ether / buyPrice;               // calculates the amount
        _transfer(this, msg.sender, amount);         // makes the transfers
        return amount;
    }

    /*
     * @notice toggle allow/prevent `_target` from sending & receiving tokens
     * @param _target Address to be frozen
     */
    function toggleFrozen(address _target) onlyOwner public
    {
        setFrozen(_target, !frozenAccount[_target]);
    }

    /*
     * @notice `_isFrozen? Prevent | Allow` `_target` from sending & receiving tokens
     * @param _target Address to be frozen
     * @param freeze either to freeze it or not
     */
    function setFrozen(address _target, bool _isFrozen) onlyOwner public
    {
        frozenAccount[_target] = _isFrozen;
        FrozenFunds(_target, _isFrozen);
    }

    /*
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_amount` tokens in your behalf
     *
     * @param _spender The address authorized to spend
     * @param _amount the max amount they can spend
     */
    function approve(address _spender, uint _amount) public returns (bool success)
    {
        allowance.insert(msg.sender,_spender, _amount);
        return true;
    }
    
    /*
     * get every allowance and addresses you have approved
     *
     * @return account The addresses who you have authorized your tokens to
     * @return value The allowance amount for account has the exact same index
     */
    function getMyAllowance() public view returns (address[] account,uint[] value)
    {
        account = allowance.data[msg.sender].keyIndex;
        value = allowance.data[msg.sender].traverse();
    }
    
    /*
     * get every allowance and addresses who have approved you
     *
     * @return account The addresses authorized you their tokens
     * @return value The allowance amount for account has the exact same index
     */
    function getForMeAllowance() public view returns (address[] account,uint[] value)
    {
        (account,value) =  allowance.traverse_outward(msg.sender);
    }
    
    /*
     * Transfer tokens from other address
     *
     * Send `_amount` tokens to `_to` in behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _amount the amount to send
     */
    function transferFrom(address _from, address _to, uint _amount) public returns (bool success)
    {
        require(_amount <= allowance.data[_from].data[_to]);     // Check allowance
        allowance.data[_from].modify(_to, -_amount);             // Modify the referenced value
        _transfer(_from, _to, _amount);
        return true;
    }

    /*
     * Destroy tokens from other account
     *
     * Remove `_amount` tokens from the system irreversibly on behalf of `_from`.
     *
     * @param _from the address of the sender
     * @param _amount the amount of money to burn
     */
    function burnFrom(address _from, uint _amount) public returns (bool success)
    {
        require(balanceOf[_from] >= _amount);                       // Check if the targeted balance is enough
        require(_amount <= allowance.data[_from].data[msg.sender]); // Check allowance
        balanceOf[_from] -= _amount;                                // Subtract from the targeted balance
        allowance.data[_from].modify(msg.sender, -_amount);         // Modify the referenced value
        totalSupply -= _amount;                                     // Update totalSupply
        Burn(_from, _amount);
        return true;
    }
}
