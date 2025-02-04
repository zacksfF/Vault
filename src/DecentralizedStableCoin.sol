// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * ===============================================
 * |           Layout of Contract               |
 * ===============================================
 * | Section                 | Description      |
 * |-------------------------|-----------------|
 * | Version                 | Solidity version declaration |
 * | Imports                 | Import necessary dependencies |
 * | Interfaces, Libraries, Contracts | Define interfaces, libraries, and main contract |
 * | Errors                  | Custom error definitions |
 * | Type Declarations       | Define structs, enums, and types |
 * | State Variables         | Declare storage variables |
 * | Events                  | Define event logs |
 * | Modifiers               | Define function modifiers |
 * | Functions               | Define contract functions |
 * ===============================================
 * 
 * ===============================================
 * |          Layout of Functions               |
 * ===============================================
 * | Section                 | Description      |
 * |-------------------------|-----------------|
 * | Constructor             | Initializes the contract |
 * | Receive Function        | Handles native token deposits (if applicable) |
 * | Fallback Function       | Handles calls to non-existent functions |
 * | External Functions      | Callable by external accounts/contracts |
 * | Public Functions        | Callable both externally and internally |
 * | Internal Functions      | Callable only within the contract and derived contracts |
 * | Private Functions       | Callable only within the contract |
 * | View & Pure Functions   | Read-only or computation-only functions |
 * ===============================================
 */


contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__AmountMustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    /*
    In the latest versions of OpenZeppelin contracts, Ownable must be declared with an address of the contract owner
    as a parameter.
    */
    constructor(address initialOwner) ERC20("DecentralizedStableCoin", "DSC") Ownable(initialOwner) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
