// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {PriceOracle} from "src/libraries/PriceOracle.sol";
import {VaultMath} from "src/libraries/VaultMath.sol";
import {MockPriceFeed} from "src/mocks/MockPriceFeed.sol";
import "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract PriceOracleTest is Test {
	function testGetLatestPrice_returnsScaledPrice() public {
		// keep block.number and block.timestamp aligned so both staleness checks pass
		vm.roll(100);
		vm.warp(100);

		MockPriceFeed mock = new MockPriceFeed(8, int256(2000e8));

		uint256 price = PriceOracle.getLatestPrice(AggregatorV3Interface(address(mock)));

		uint256 expected = uint256(2000e8) * VaultMath.ADDITIONAL_FEED_PRECISION;
		assertEq(price, expected);
	}

	function testRevertsOnInvalidPriceZero() public {
		vm.roll(1);
		vm.warp(1);
		MockPriceFeed mock = new MockPriceFeed(8, int256(1e8));
		// set the latest answer to zero
		mock.updateAnswer(0);

		vm.expectRevert(bytes("Invalid price"));
		PriceOracle.getLatestPrice(AggregatorV3Interface(address(mock)));
	}

	function testRevertsOnStaleTime() public {
		// normal block/ts
		vm.roll(1);
		vm.warp(100000);

		MockPriceFeed mock = new MockPriceFeed(8, int256(2000e8));

		// set the round's updatedAt to older than timeout (3 hours)
		uint256 old = block.timestamp - (3 hours + 1);
		// use a new round id
		mock.updateRoundData(2, int256(2000e8), old, old);

		vm.expectRevert(bytes("Price too stale (time)"));
		PriceOracle.getLatestPrice(AggregatorV3Interface(address(mock)));
	}

	function testRevertsOnStaleBlocks() public {
		// Make block.number large while keeping timestamp small so block-based check fails
		vm.roll(10000);
		vm.warp(1000);

		MockPriceFeed mock = new MockPriceFeed(8, int256(2000e8));

		// time-based check passes (updatedAt == block.timestamp), but block check should fail
		vm.expectRevert(bytes("Price too stale (blocks)"));
		PriceOracle.getLatestPrice(AggregatorV3Interface(address(mock)));
	}
}

