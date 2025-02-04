// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract MockFailedMintDSC is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__AmountMustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();
    error DecentralizedStableCoin__MintFailedDueToPrice();

    address public mockAggregator;
    uint256 public constant MIN_PRICE_THRESHOLD = 1000; // Example threshold for minting

    constructor(address _mockAggregator) ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {
        mockAggregator = _mockAggregator;
    }

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

        // Check the price from the mock aggregator
        (, int256 price,,,) = MockV3Aggregator(mockAggregator).latestRoundData();
        if (uint256(price) < MIN_PRICE_THRESHOLD) {
            revert DecentralizedStableCoin__MintFailedDueToPrice();
        }

        _mint(_to, _amount);
        return true;
    }
}
