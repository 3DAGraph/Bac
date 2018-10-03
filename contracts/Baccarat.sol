pragma solidity ^0.4.24;

// 如果是有安裝 truffle framework
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";

// 用其他方式佈署 
//import "github.com/OpenZeppelin/zeppelin-solidity/contracts/math/SafeMath.sol";
//import "github.com/OpenZeppelin/zeppelin-solidity/contracts/ownership/Ownable.sol";

contract Baccarat is Ownable {
    using SafeMath for uint256;

    address public callAddr;
    mapping (uint256 => GameRecords) public records;
    uint32 public gameId = 1;
    uint32 public fee = 97;
    uint256 public createValue = 1.0 ether; // 開局金額 1.0 ether
    uint256 public baseBet = 0.1 ether;     // 玩家壓注金額 0.1 ether

    struct GameRecords {
        address BankerAddress;  // 開局者地址
        address PlayerAddress;  // 入局者地址
        uint256 WinValue;       // 輸贏金額
        uint32  GameId;         // 局號(唯一不重複)
        uint8   Bank1;          // 莊家: 第1張牌
        uint8   Bank2;          // 莊家: 第2張牌
        uint8   Bank3;          // 莊家: 第3張牌
        uint8   Player1;        // 閒家: 第1張牌
        uint8   Player2;        // 閒家: 第2張牌
        uint8   Player3;        // 閒家: 第3張牌
        uint8   GameResult;     // 勝負結果: 莊or閒or和
        uint8   IsOpening;      // 牌局是否開啟中
    }

    function getHistory(uint32 _gameId) public view returns (uint8[],uint8[],uint8) {
        uint8[] memory bank = new uint8[](3);
        uint8[] memory player = new uint8[](3);
        bank[0] = records[_gameId].Bank1;
        bank[1] = records[_gameId].Bank2;
        bank[2] = records[_gameId].Bank3;
        player[0] =  records[_gameId].Player1;
        player[1] =  records[_gameId].Player2;
        player[2] =  records[_gameId].Player3;

        return (bank, player, records[_gameId].GameResult);
    }

    function IsOpeningRoom(uint _gameId) public view returns (uint8) {
        return (records[_gameId].IsOpening);
    }

    constructor() public {
    }

    function createRoom() public payable {
        require(!isContract(msg.sender));
        require(msg.value == createValue);
        require(msg.sender != address(0x0));
        records[gameId] = GameRecords(msg.sender, address(0x0), 0, gameId, 0,0,0, 0,0,0, 0, 1);
        gameId++;
    }

    // 機率合約得到的數字: 1 ~ 52
    // 各數字代表以下牌
    // 黑桃:  1 ~ 13
    // 紅桃: 14 ~ 26
    // 方塊: 27 ~ 39
    // 梅花: 40 ~ 52
    // 10,J,Q,K 代表0

    function play(uint8 _gameId, uint8 _result) public payable {
        require(_gameId > 0);
        require(_result >= 1 && _result <= 3);
        require(records[_gameId].BankerAddress != address(0x0));
        require(records[_gameId].IsOpening == 1);
        require(!isContract(msg.sender));
        require(msg.value == baseBet);

        BaccaratRand c = BaccaratRand(callAddr);
        uint8 player1 = uint8(c.random.value(1)());
        uint8 bank1 = uint8(c.random.value(1)());
        uint8 player2 = uint8(c.random.value(1)());
        uint8 bank2 = uint8(c.random.value(1)());
        uint8 player3 = 0;
        uint8 bank3 = 0;

        // // 計算閒家牌
        uint8 player = calCard(player1, player2);
        // // 計算莊家牌
        uint8 bank = calCard(bank1, bank2);

        // // 不需補牌的狀況
        if (player == 8 || player == 9 || bank == 8 || bank == 9) {
            // 莊閒任何一方兩牌合計共的8或9點為例牌(Natural)，對方不須補牌，即定勝負（雙方同持8或9點話為和）
        }
        else if ((player == 6 || player == 7) && (bank == 6 || bank == 7)) {
            // 另外莊閒兩方各持6、7點的話亦為即定勝負（雙方同持6或7點的話為和）
        }
        else {
            // 閒家補牌
            if (player >= 0 && player <= 5) {
                player3 = c.random.value(1)();
                player = calCard(player, player3);
            }

            // 莊家補牌
            if (bank >= 0 && bank <= 3) {
                bank3 = c.random.value(1)();
                bank = calCard(bank, bank3);
            }
            else if (bank == 4 && player3 != 8) {
                bank3 = c.random.value(1)();
                bank = calCard(bank, bank3);
            }
            else if (bank == 5 && player3 >= 2 && player3 <= 7) {
                bank3 = c.random.value(1)();
                bank = calCard(bank, bank3);
            }
            else if (bank == 6 && player3 >= 6 && player3 <= 7) {
                bank3 = c.random.value(1)();
                bank = calCard(bank, bank3);
            }
        }

        if (bank > player) {
            records[_gameId].GameResult = 1;
            if (_result == records[_gameId].GameResult) {
                records[_gameId].WinValue = baseBet.mul(195).div(100);
            }
        }
        else if (bank < player) {
            records[_gameId].GameResult = 2;
            if (_result == records[_gameId].GameResult) {
                records[_gameId].WinValue = baseBet.mul(2);
            }
        }
        else {
            records[_gameId].GameResult = 3;
            if (_result == records[_gameId].GameResult) {
                records[_gameId].WinValue = baseBet.mul(9);
            }
        }

        // 派獎
        records[_gameId].PlayerAddress = msg.sender;
        if (records[_gameId].WinValue > 0) {
            uint256 value = records[_gameId].WinValue;
            address(records[_gameId].BankerAddress).transfer(createValue.add(baseBet).sub(value));
            value = value.mul(97).div(100);
            address(records[_gameId].PlayerAddress).transfer(value);
            records[_gameId].WinValue = value;
        }
        else {
            address(records[_gameId].BankerAddress).transfer(createValue.add(baseBet.mul(fee).div(100)));
        }

        // // 寫紀錄
        records[_gameId].Bank1 = bank1;
        records[_gameId].Bank2 = bank2;
        records[_gameId].Bank3 = bank3;
        records[_gameId].Player1 = player1;
        records[_gameId].Player2 = player2;
        records[_gameId].Player3 = player3;
        records[_gameId].IsOpening = 0;
    }

    function calCard(uint8 _card1, uint8 _card2) internal pure returns(uint8) {
        uint8 card1 = _card1 % 13;
        uint8 card2 = _card2 % 13;

        if (card1 > 9)
            card1 = 0;
        if (card2 > 9)
            card2 = 0;
        uint8 total = card1 + card2;
        if (total > 9)
            total = total - 10;

        return total;
    }
    
    function Balance() public view returns(uint256) {
        return address(this).balance;
    }

    /* Depoit */
    function() public payable { }
    
    /* Owner */
    /*
    function withdrawAll() public onlyOwner {
        owner.transfer(address(this).balance);
    }*/

    function withdrawAmount(uint256 _amount) public onlyOwner {
        uint256 value = 1.0 ether;
        owner.transfer(_amount * value);
    }
    
    function kill() public onlyOwner {
        owner.transfer(address(this).balance);
        selfdestruct(owner);
    }

    /* Util */
    function setCalleeContract(address _caller) public onlyOwner {
        callAddr = _caller;
    }

    function isContract(address addr) private view returns(bool) {
        uint size;
        assembly { size := extcodesize(addr) } // solium-disable-line
        return size > 0;
    }
}

contract BaccaratRand {
    function random() public payable returns(uint8);
}
