// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./Ownable.sol";

contract GasContract is Ownable {
    uint256 public immutable totalSupply = 0; // cannot be updated
    uint256 public paymentCounter = 0;
    mapping(address => uint256) public balances;
    uint256 public tradePercent = 12;
    address public contractOwner;
    uint256 public tradeMode = 0;
    mapping(address => Payment[]) public payments;
    mapping(address => uint256) public whitelist;
    address[5] public administrators;
    bool public isReady = false;
    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }
    PaymentType constant defaultPayment = PaymentType.Unknown;

    History[] public paymentHistory; // when a payment was updated

    struct Payment {
        PaymentType paymentType;
        uint256 paymentID;
        bool adminUpdated;
        string recipientName; // max 8 characters
        address recipient;
        address admin; // administrators address
        uint256 amount;
    }

    struct History {
        uint256 lastUpdate;
        uint256 blockNumber;
        address updatedBy;
    }
    bool wasLastOdd = true;
    mapping(address => uint256) public isOddWhitelistUser;

    struct ImportantStruct {
        address sender;
        bool paymentStatus;
        uint256 amount;
        uint256 bigValue;
        uint16 valueA; // max 3 digits
        uint16 valueB; // max 3 digits
    }
    mapping(address => ImportantStruct) public whiteListStruct;

    error NotAdminOrOwner();
    error NotWhitelisted();
    error IncorrectTier();
    error AddressZero();
    error AmountExceedsBalance();
    error NameTooLong();
    error IdZero();
    error AmountNotGreaterThanZero();
    error TierGraterThan255();
    error AmountNotGraterThan3();

    modifier onlyAdminOrOwner() {
        if (contractOwner != msg.sender || !checkForAdmin(msg.sender)) {
            revert NotAdminOrOwner();
        }
        _;
    }

    modifier checkIfWhiteListed() {
        uint256 usersTier = whitelist[msg.sender];
        if(usersTier == 0) revert NotWhitelisted();
        if(usersTier > 4) revert IncorrectTier();
        _;
    }

    event AddedToWhitelist(address userAddress, uint256 tier);
    event WhiteListTransfer(address indexed);
    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        string recipient
    );

    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;

        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (_admins[ii] != address(0)) {
                administrators[ii] = _admins[ii];
                if (_admins[ii] == contractOwner) {
                    balances[contractOwner] = totalSupply;
                } else {
                    balances[_admins[ii]] = 0;
                }
                if (_admins[ii] == contractOwner) {
                    emit supplyChanged(_admins[ii], totalSupply);
                } else if (_admins[ii] != contractOwner) {
                    emit supplyChanged(_admins[ii], 0);
                }
            }
        }
    }

    function getPaymentHistory() public view returns (History[] memory paymentHistory_) {
        return paymentHistory;
    }

    function checkForAdmin(address _user) public view returns (bool admin_) {
        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (administrators[ii] == _user) {
                admin_ = true;
                break;
            }
        }
        return admin_;
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
        return balances[_user];
    }

    function getTradingMode() public pure returns (bool mode_) {
        mode_ = true;
    }

    function addHistory(
        address _updateAddress,
        bool _tradeMode
    ) public returns (bool status_, bool tradeMode_) {
        History memory history;
        history.blockNumber = block.number;
        history.lastUpdate = block.timestamp;
        history.updatedBy = _updateAddress;
        paymentHistory.push(history);
        bool[] memory status = new bool[](tradePercent);
        for (uint256 i = 0; i < tradePercent; i++) {
            status[i] = true;
        }
        return ((status[0] == true), _tradeMode);
    }

    function getPayments(address _user) public view returns (Payment[] memory payments_) {
        if (_user == address(0)) revert AddressZero();
        return payments[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public returns (bool status_) {
        if(balances[msg.sender] < _amount) revert AmountExceedsBalance();
        if(bytes(_name).length > 8) revert NameTooLong();
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        Payment memory payment;
        payment.admin = address(0);
        payment.adminUpdated = false;
        payment.paymentType = PaymentType.BasicPayment;
        payment.recipient = _recipient;
        payment.amount = _amount;
        payment.recipientName = _name;
        payment.paymentID = ++paymentCounter;
        payments[msg.sender].push(payment);
        bool[] memory status = new bool[](tradePercent);
        for (uint256 i = 0; i < tradePercent; i++) {
            status[i] = true;
        }
        emit Transfer(_recipient, _amount);
        return (status[0] == true);
    }

    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) public onlyAdminOrOwner {
        if (_ID <= 0) revert IdZero();
        if(_amount <= 0) revert AmountNotGreaterThanZero();
        if(_user == address(0)) revert AddressZero();
        for (uint256 ii = 0; ii < payments[_user].length; ii++) {
            if (payments[_user][ii].paymentID == _ID) {
                payments[_user][ii].adminUpdated = true;
                payments[_user][ii].admin = _user;
                payments[_user][ii].paymentType = _type;
                payments[_user][ii].amount = _amount;
                bool tradingMode = getTradingMode();
                addHistory(_user, tradingMode);
                emit PaymentUpdated(
                    msg.sender,
                    _ID,
                    _amount,
                    payments[_user][ii].recipientName
                );
            }
        }
    }

    function addToWhitelist(address _userAddrs, uint256 _tier) public onlyAdminOrOwner {
        if(_tier >= 255) revert TierGraterThan255();
        if (_tier > 3) {
            whitelist[_userAddrs] = 3;
        } else {
            whitelist[_userAddrs] = _tier;
        }
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(address _recipient, uint256 _amount) public checkIfWhiteListed {
        whiteListStruct[msg.sender] = ImportantStruct(msg.sender, true, _amount, 0, 0, 0);
        if (balances[msg.sender] < _amount) revert AmountExceedsBalance();
        if (_amount <= 3) revert AmountNotGraterThan3();
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        balances[msg.sender] += whitelist[msg.sender];
        balances[_recipient] -= whitelist[msg.sender];

        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(
        address sender
    ) public view returns (bool, uint256) {
        return (
            whiteListStruct[sender].paymentStatus,
            whiteListStruct[sender].amount
        );
    }

    // receive() external payable {
    //     payable(msg.sender).transfer(msg.value);
    // }

    // fallback() external payable {
    //     payable(msg.sender).transfer(msg.value);
    // }
}


// team,score,github
// G4,419984,https://github.com/Ultra-Tech-code/Gas-optimization
// G5,440545,https://gist.github.com/AlexCZM/5130a1e510c4c69b6f980d6b3842f21c
// G2,448049,https://github.com/brolag/gas-optimization
// G7,496821,https://github.com/RichuAK/GasOptimisationFoundry
// G6,624111,https://github.com/bogdoslavik/GasOptimisationFoundry
// G8,626888,https://github.com/rakimsth/ExpertSolidityBootcamp
// G1,1901618,https://github.com/dvgui/AdvancedSolOpt
// G3,2270853,https://github.com/Nandinho42069/gasOptimiser/blob/main/GOptimizer/src/Gas.sol
