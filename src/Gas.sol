// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// note: compiling with solidity 0.8.24 seems to be cheaper than newer releases
// 442 882 -> solidity 0.8.27
// 442 253 -> solidity 0.8.24
contract GasContract {
    address private immutable contractOwner;
    mapping(address => uint256) whiteListStruct;

    address[5] public administrators;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public whitelist;

    event AddedToWhitelist(address userAddress, uint256 tier);
    event WhiteListTransfer(address indexed);

    error TierGraterThan255();
    error NotContractOwner();

    constructor(address[] memory _admins, uint256 _totalSupply) payable {
        contractOwner = msg.sender;
        
        assembly {
            
            // Calculate the storage slot for balances[msg.sender]
            mstore(0x0, caller())
            mstore(0x20, balances.slot)
            let balancesSlot := keccak256(0x0, 0x40)

            // Store _totalSupply in the calculated storage slot
            sstore(balancesSlot, _totalSupply)

            // Loop through _admins and set administrators
            for { let i := 0 } lt(i, 5) { i := add(i, 1) } {
                let admin := mload(add(add(_admins, 0x20), mul(i, 0x20)))
                sstore(add(administrators.slot, i), admin)
            }
        }
    }

    function checkForAdmin(address _user) external view returns (bool) {
        return _user == contractOwner;
    }

    function balanceOf(address _user) public view returns (uint256) {
        return balances[_user];
    }

    function transfer(address _recipient, uint256 _amount, string calldata) public {
        unchecked {
            balances[msg.sender] -= _amount;
            balances[_recipient] += _amount;
        }
    }

    function addToWhitelist(address _userAddrs, uint256 _tier) public {
        if (msg.sender != contractOwner) revert NotContractOwner();
        if(_tier >= 255) revert TierGraterThan255();
        whitelist[_userAddrs] = _tier > 3 ? 3 : _tier;
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    // Making this function external decreases gas usage; but this doesn't happen for other functions (eg. balanceOf)
    function whiteTransfer(address _recipient, uint256 _amount) external {
        unchecked {
            uint256 usersTier = whitelist[msg.sender];
            whiteListStruct[msg.sender] = _amount;
            balances[msg.sender] -= _amount - usersTier ;
            balances[_recipient] += _amount - usersTier;
        }
        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(address sender) external view returns (bool, uint256) {
        return (true, whiteListStruct[sender]);
    }
}


// team,score,github
// G1,399012,https://github.com/DariusPrzydzial/GasOptimisationFoundry/
// G4,419984,https://github.com/Ultra-Tech-code/Gas-optimization
// G5,440545,https://gist.github.com/AlexCZM/5130a1e510c4c69b6f980d6b3842f21c
// G2,448049,https://github.com/brolag/gas-optimization
// G7,496821,https://github.com/RichuAK/GasOptimisationFoundry
// G6,624111,https://github.com/bogdoslavik/GasOptimisationFoundry
// G8,626888,https://github.com/rakimsth/ExpertSolidityBootcamp
// G1,1901618,https://github.com/dvgui/AdvancedSolOpt
// G3,2270853,https://github.com/Nandinho42069/gasOptimiser/blob/main/GOptimizer/src/Gas.sol