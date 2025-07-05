// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @author Zakaria Saif
 * @notice Mock ERC20 token for testing purposes
 * @dev Used to simulate WETH, WBTC, and other tokens in tests
 */
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 tokenDecimals,
        address initialAccount,
        uint256 initialBalance
    ) ERC20(name, symbol) {
        _decimals = tokenDecimals;
        _mint(initialAccount, initialBalance);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }

    function faucet(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}