// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {PriceOracle} from "src/libraries/PriceOracle.sol";
import {VaultMath} from "src/libraries/VaultMath.sol";
import {MockPriceFeed} from "src/mocks/MockPriceFeed.sol";
import "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @dev External wrapper so vm.expectRevert works for library internal calls
contract PriceOracleWrapper {
	function getLatestPrice(AggregatorV3Interface priceFeed) external view returns (uint256) {
		return PriceOracle.getLatestPrice(priceFeed);
	}
}

/// @title PriceOracleTest
/// @notice Unit tests for the PriceOracle library
contract PriceOracleTest is Test {
	PriceOracleWrapper wrapper;

	function setUp() public {
		wrapper = new PriceOracleWrapper();
	}

	function testGetLatestPrice_returnsScaledPrice() public {
		vm.roll(100);
		vm.warp(100);

		MockPriceFeed mock = new MockPriceFeed(8, int256(2000e8));

		uint256 price = wrapper.getLatestPrice(AggregatorV3Interface(address(mock)));

		uint256 expected = uint256(2000e8) * VaultMath.ADDITIONAL_FEED_PRECISION;
		assertEq(price, expected);
	}

	function testRevertsOnInvalidPriceZero() public {
		vm.roll(1);
		vm.warp(1);
		MockPriceFeed mock = new MockPriceFeed(8, int256(1e8));
		mock.updateAnswer(0);

		vm.expectRevert(bytes("Invalid price"));
		wrapper.getLatestPrice(AggregatorV3Interface(address(mock)));
	}

	function testRevertsOnStaleTime() public {
		vm.roll(1);
		vm.warp(100000);

		MockPriceFeed mock = new MockPriceFeed(8, int256(2000e8));

		// Set the latest round's updatedAt to older than timeout (3 hours)
		uint256 old = block.timestamp - (3 hours + 1);
		mock.setRoundData(1, int256(2000e8), old, old, 1);

		vm.expectRevert(bytes("Price too stale (time)"));
		wrapper.getLatestPrice(AggregatorV3Interface(address(mock)));
	}

	function testRevertsOnStaleBlocks() public {
		vm.roll(10000);
		vm.warp(10000);

		MockPriceFeed mock = new MockPriceFeed(8, int256(2000e8));
		// Set updatedAt to 5000 (gap=5000, blockAge=333 > 240)
		// Keep within 3 hours so time-based check passes
		mock.setRoundData(1, int256(2000e8), 5000, 5000, 1);

		vm.expectRevert(bytes("Price too stale (blocks)"));
		wrapper.getLatestPrice(AggregatorV3Interface(address(mock)));
	}
}
