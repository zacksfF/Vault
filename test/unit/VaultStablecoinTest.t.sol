// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/VaultStablecoin.sol";
import "../../src/libraries/VaultErrors.sol";


contract VaultStablecoinTest is Test {
    VaultStablecoin stablecoin;
    address public OWNER = makeAddr("owner");
    address public USER = makeAddr("user");

    function setUp() public {
        vm.prank(OWNER);
        stablecoin = new VaultStablecoin(OWNER);
    }

    // ===================== Constructor =====================

    function test_NameAndSymbol() public view {
        assertEq(stablecoin.name(), "Vault USD");
        assertEq(stablecoin.symbol(), "vUSD");
    }

    function test_OwnerIsSet() public view {
        assertEq(stablecoin.owner(), OWNER);
    }

    function test_ConstructorRevertsOnZeroAddress() public {
        vm.expectRevert();
        new VaultStablecoin(address(0));
    }

    // ===================== Mint =====================

    function test_MintFirstTimeWhenSupplyIsZero() public {
        vm.prank(OWNER);
        bool success = stablecoin.mint(USER, 1000e18);
        assertTrue(success);
        assertEq(stablecoin.balanceOf(USER), 1000e18);
    }

    function test_MintRevertsForNonOwner() public {
        vm.prank(USER);
        vm.expectRevert();
        stablecoin.mint(USER, 100e18);
    }

    function test_MintRevertsOnZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert();
        stablecoin.mint(address(0), 100e18);
    }

    function test_MintRevertsOnZeroAmount() public {
        vm.prank(OWNER);
        vm.expectRevert();
        stablecoin.mint(USER, 0);
    }

    function test_MintRespectsDailyLimit() public {
        // First mint to bootstrap supply
        vm.prank(OWNER);
        stablecoin.mint(USER, 500000e18);

        // Next mint should be bounded by 1% of supply = 5000e18
        // and also by daily limit of 1M
        vm.prank(OWNER);
        bool success = stablecoin.mint(USER, 5000e18);
        assertTrue(success);
    }

    function test_MintRevertsWhenExceeding1PercentOfSupply() public {
        // Bootstrap with 100k
        vm.prank(OWNER);
        stablecoin.mint(USER, 100000e18);

        // 1% of 100k = 1000. Try minting 1001
        vm.prank(OWNER);
        vm.expectRevert("Cannot mint more than 1% of supply at once");
        stablecoin.mint(USER, 1001e18);
    }

    function test_MintRevertsWhenExceedingDailyLimit() public {
        // Bootstrap supply so 1% check doesn't block us
        vm.prank(OWNER);
        stablecoin.mint(USER, 999999e18);

        // Daily limit is 1M, we already minted 999999, try minting 1% of supply (~10000)
        // dailyMintAmount is now 999999e18, next mint of even 1e18 would push total to 1M which is exactly the limit
        vm.prank(OWNER);
        bool success = stablecoin.mint(USER, 1e18);
        assertTrue(success);

        // Now total daily is exactly 1M, next should fail
        vm.prank(OWNER);
        vm.expectRevert("Daily mint limit exceeded");
        stablecoin.mint(USER, 1e18);
    }

    // ===================== Burn =====================

    function test_BurnWorks() public {
        vm.prank(OWNER);
        stablecoin.mint(USER, 1000e18);

        vm.prank(USER);
        stablecoin.burn(500e18);

        assertEq(stablecoin.balanceOf(USER), 500e18);
    }

    function test_BurnRevertsOnZeroAmount() public {
        vm.prank(USER);
        vm.expectRevert();
        stablecoin.burn(0);
    }

    function test_BurnRevertsOnInsufficientBalance() public {
        vm.prank(OWNER);
        stablecoin.mint(USER, 100e18);

        vm.prank(USER);
        vm.expectRevert();
        stablecoin.burn(101e18);
    }

    // ===================== BurnFrom =====================

    function test_BurnFromByOwnerBypassesAllowance() public {
        vm.prank(OWNER);
        stablecoin.mint(USER, 1000e18);

        // Owner burns from user without allowance
        vm.prank(OWNER);
        stablecoin.burnFrom(USER, 500e18);

        assertEq(stablecoin.balanceOf(USER), 500e18);
    }

    function test_BurnFromByNonOwnerRequiresAllowance() public {
        address burner = makeAddr("burner");

        vm.prank(OWNER);
        stablecoin.mint(USER, 1000e18);

        // Without allowance → should revert
        vm.prank(burner);
        vm.expectRevert();
        stablecoin.burnFrom(USER, 100e18);

        // With allowance → should succeed
        vm.prank(USER);
        stablecoin.approve(burner, 100e18);

        vm.prank(burner);
        stablecoin.burnFrom(USER, 100e18);

        assertEq(stablecoin.balanceOf(USER), 900e18);
    }

    function test_BurnFromRevertsOnZeroAmount() public {
        vm.prank(OWNER);
        vm.expectRevert();
        stablecoin.burnFrom(USER, 0);
    }

    function test_BurnFromRevertsOnZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert();
        stablecoin.burnFrom(address(0), 100e18);
    }
}
