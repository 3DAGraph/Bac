pragma solidity ^0.4.24;

// 如果是有安裝 truffle framework
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";

// 用其他方式佈署 
// import "github.com/OpenZeppelin/zeppelin-solidity/contracts/math/SafeMath.sol";
// import "github.com/OpenZeppelin/zeppelin-solidity/contracts/ownership/Ownable.sol";

contract BaccaratRand is Ownable {
    using SafeMath for uint256;
    address calleeContract;
    uint256 private blocks = block.number;
    uint256 private gameId = 0;

    constructor() public {
    }

    function random() public payable returns(uint256) {
        require(msg.value == 1);
        require(msg.sender == calleeContract);
        require(isContract(msg.sender));

        uint256 balance = calleeContract.balance;
        uint256 modulo = 52;
        uint256 timestamp = block.timestamp;
        
        blocks = blocks.add(block.number);
        gameId = gameId.add(gameId);
        timestamp = timestamp.add(block.timestamp);
        
        uint256 seed = uint256(keccak256(abi.encodePacked(gameId + removeValueZero(balance) + timestamp + blocks)));
        uint256 result = 0;
        result = (seed % modulo).add(1);
        msg.sender.transfer(1);

        return result;
    }

    /* Depoit */
    function() public payable { }
    
    /* Owner */
    function withdrawAll() public onlyOwner {
        owner.transfer(address(this).balance);
    }

    function withdrawAmount(uint256 _amount) public onlyOwner {
        uint256 value = 1.0 ether;
        owner.transfer(_amount * value);
    }
    
    function kill() public onlyOwner {
        owner.transfer(address(this).balance);
        selfdestruct(owner);
    }

    function setCalleeContract(address _calleeContract) public onlyOwner {
        require(_calleeContract != address(0), "");
        calleeContract = _calleeContract;
    }

    /* Util */
    function isContract(address addr) private view returns(bool) {
        uint size;
        assembly { size := extcodesize(addr) } // solium-disable-line
        return size > 0;
    }
    
    function removeValueZero(uint256 _balance) private pure returns(uint256) {
        uint256 v = 0;
        uint256 balance = _balance;
        
        while(v == 0) {
            if (balance % 10 != 0)
                v = balance % 10;
            else
                balance = balance.div(10);
            
            if (v != 0)
                break;
        }
        
        return balance;
    }
}