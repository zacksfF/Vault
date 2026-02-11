// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/VaultEngine.sol";
import "../../src/VaultStablecoin.sol";
import "../../src/mocks/MockERC20.sol";
import "lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";

/**
 * @title DepositAndMintTest
 * @notice Integration tests for depositing collateral and minting stablecoins
 * @dev Tests the complete flow of depositing collateral and minting stablecoins
 */
contract DepositAndMintTest is Test {
    VaultEngine public engine;
    VaultStablecoin public stablecoin;
    MockERC20 public weth;
    MockERC20 public wbtc;
    MockV3Aggregator public ethPriceFeed;
    MockV3Aggregator public btcPriceFeed;

    address public USER = makeAddr("user");
    address public OWNER = makeAddr("owner");

    uint256 constant STARTING_BALANCE = 1000 ether;
    uint256 constant ETH_PRICE = 2000e8; // $2000 with 8 decimals (Chainlink format)
    uint256 constant BTC_PRICE = 40000e8; // $40000 with 8 decimals (Chainlink format)
    uint256 constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 constant PRECISION = 1e18;
    uint8 constant DECIMALS = 8;

    function setUp() public {
        vm.startPrank(OWNER);
        
        // Deploy mocks
        weth = new MockERC20("Wrapped Ether", "WETH", 18, OWNER, STARTING_BALANCE * 10);
        wbtc = new MockERC20("Wrapped Bitcoin", "WBTC", 18, OWNER, STARTING_BALANCE * 10);

        // Deploy stablecoin with OWNER and bootstrap supply
        stablecoin = new VaultStablecoin(OWNER);
        stablecoin.mint(OWNER, 1000000e18); // Bootstrap with 1M supply
        vm.warp(block.timestamp + 1 days + 1); // Reset daily mint counter

        // Create price feeds AFTER warp so timestamps are fresh
        ethPriceFeed = new MockV3Aggregator(DECIMALS, int256(ETH_PRICE));
        btcPriceFeed = new MockV3Aggregator(DECIMALS, int256(BTC_PRICE));

        // Deploy engine
        address[] memory tokens = new address[](2);
        address[] memory priceFeeds = new address[](2);
        
        tokens[0] = address(weth);
        tokens[1] = address(wbtc);
        priceFeeds[0] = address(ethPriceFeed);
        priceFeeds[1] = address(btcPriceFeed);

        engine = new VaultEngine(tokens, priceFeeds, address(stablecoin));
        
        // Transfer ownership of stablecoin to engine
        stablecoin.transferOwnership(address(engine));

        // Distribute tokens to user
        weth.transfer(USER, STARTING_BALANCE);
        wbtc.transfer(USER, STARTING_BALANCE);
        
        vm.stopPrank();
    }

    // ============================================
    // Deposit Collateral Tests
    // ============================================

    function test_CanDepositCollateral() public {
        uint256 depositAmount = 10 ether;
        
        vm.startPrank(USER);
        weth.approve(address(engine), depositAmount);
        engine.depositCollateral(address(weth), depositAmount);
        vm.stopPrank();

        assertEq(engine.getCollateralBalanceOfUser(USER, address(weth)), depositAmount);
        assertEq(weth.balanceOf(USER), STARTING_BALANCE - depositAmount);
        assertEq(weth.balanceOf(address(engine)), depositAmount);
    }

    function test_CanDepositMultipleCollateralTypes() public {
        uint256 ethAmount = 10 ether;
        uint256 btcAmount = 5 ether;
        
        vm.startPrank(USER);
        weth.approve(address(engine), ethAmount);
        wbtc.approve(address(engine), btcAmount);
        
        engine.depositCollateral(address(weth), ethAmount);
        engine.depositCollateral(address(wbtc), btcAmount);
        vm.stopPrank();

        assertEq(engine.getCollateralBalanceOfUser(USER, address(weth)), ethAmount);
        assertEq(engine.getCollateralBalanceOfUser(USER, address(wbtc)), btcAmount);
    }

    function test_RevertsWhenDepositingZeroAmount() public {
        vm.startPrank(USER);
        weth.approve(address(engine), 1 ether);
        vm.expectRevert();
        engine.depositCollateral(address(weth), 0);
        vm.stopPrank();
    }

    function test_RevertsWhenDepositingUnsupportedToken() public {
        MockERC20 unsupportedToken = new MockERC20("Unsupported", "UNS", 18, USER, 100 ether);
        
        vm.startPrank(USER);
        unsupportedToken.approve(address(engine), 10 ether);
        vm.expectRevert();
        engine.depositCollateral(address(unsupportedToken), 10 ether);
        vm.stopPrank();
    }

    // ============================================
    // Mint Stablecoin Tests
    // ============================================

    function test_CanMintStablecoinAfterDepositingCollateral() public {
        uint256 collateralAmount = 10 ether;
        uint256 collateralValueUsd = (collateralAmount * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 maxMint = collateralValueUsd / 2; // 50% max collateral ratio
        // When supply is 0, first mint is unlimited (up to daily limit)
        // When supply > 0, limit is 1% of supply
        uint256 currentSupply = stablecoin.totalSupply();
        uint256 maxAllowedMint = currentSupply == 0 ? type(uint256).max : currentSupply / 100;
        maxMint = maxMint > maxAllowedMint ? maxAllowedMint : maxMint;
        uint256 mintAmount = maxMint * 80 / 100; // Mint 80% of max to be safe
        
        vm.startPrank(USER);
        weth.approve(address(engine), collateralAmount);
        engine.depositCollateral(address(weth), collateralAmount);
        engine.mintStablecoin(mintAmount);
        vm.stopPrank();

        assertEq(stablecoin.balanceOf(USER), mintAmount);
        assertGe(engine.getHealthFactor(USER), 1e18);
    }

    function test_RevertsWhenMintingWithoutCollateral() public {
        vm.startPrank(USER);
        vm.expectRevert();
        engine.mintStablecoin(100e18);
        vm.stopPrank();
    }

    function test_RevertsWhenMintingZeroAmount() public {
        uint256 collateralAmount = 10 ether;
        
        vm.startPrank(USER);
        weth.approve(address(engine), collateralAmount);
        engine.depositCollateral(address(weth), collateralAmount);
        vm.expectRevert();
        engine.mintStablecoin(0);
        vm.stopPrank();
    }

    function test_RevertsWhenMintingTooMuch() public {
        uint256 collateralAmount = 10 ether;
        uint256 collateralValueUsd = (collateralAmount * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 maxMint = collateralValueUsd / 2; // 50% max collateral ratio
        uint256 mintAmount = maxMint + 1e18; // Try to mint more than allowed
        
        vm.startPrank(USER);
        weth.approve(address(engine), collateralAmount);
        engine.depositCollateral(address(weth), collateralAmount);
        vm.expectRevert();
        engine.mintStablecoin(mintAmount);
        vm.stopPrank();
    }

    // ============================================
    // Deposit and Mint in One Transaction Tests
    // ============================================

    function test_CanDepositAndMintInOneTransaction() public {
        uint256 collateralAmount = 10 ether;
        uint256 collateralValueUsd = (collateralAmount * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 maxMint = collateralValueUsd / 2; // 50% max collateral ratio
        // When supply is 0, first mint is unlimited (up to daily limit)
        // When supply > 0, limit is 1% of supply
        uint256 currentSupply = stablecoin.totalSupply();
        uint256 maxAllowedMint = currentSupply == 0 ? type(uint256).max : currentSupply / 100;
        maxMint = maxMint > maxAllowedMint ? maxAllowedMint : maxMint;
        uint256 mintAmount = maxMint * 80 / 100; // Mint 80% of max to be safe
        
        vm.startPrank(USER);
        weth.approve(address(engine), collateralAmount);
        engine.depositCollateralAndMintStablecoin(address(weth), collateralAmount, mintAmount);
        vm.stopPrank();

        assertEq(engine.getCollateralBalanceOfUser(USER, address(weth)), collateralAmount);
        assertEq(stablecoin.balanceOf(USER), mintAmount);
        assertGe(engine.getHealthFactor(USER), 1e18);
        assertEq(weth.balanceOf(address(engine)), collateralAmount);
    }

    function test_CanDepositMultipleCollateralsAndMint() public {
        uint256 ethAmount = 10 ether;
        uint256 btcAmount = 5 ether;
        
        // Deposit ETH first
        vm.startPrank(USER);
        weth.approve(address(engine), ethAmount);
        engine.depositCollateral(address(weth), ethAmount);
        
        // Deposit BTC
        wbtc.approve(address(engine), btcAmount);
        engine.depositCollateral(address(wbtc), btcAmount);
        
        // Calculate total collateral value
        uint256 ethValueUsd = (ethAmount * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 btcValueUsd = (btcAmount * BTC_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 totalCollateralValueUsd = ethValueUsd + btcValueUsd;
        uint256 maxMint = totalCollateralValueUsd / 2; // 50% max collateral ratio
        // When supply is 0, first mint is unlimited (up to daily limit)
        // When supply > 0, limit is 1% of supply
        uint256 currentSupply = stablecoin.totalSupply();
        uint256 maxAllowedMint = currentSupply == 0 ? type(uint256).max : currentSupply / 100;
        maxMint = maxMint > maxAllowedMint ? maxAllowedMint : maxMint;
        uint256 mintAmount = maxMint * 80 / 100; // Mint 80% of max to be safe
        
        // Mint stablecoin
        engine.mintStablecoin(mintAmount);
        vm.stopPrank();

        assertEq(engine.getCollateralBalanceOfUser(USER, address(weth)), ethAmount);
        assertEq(engine.getCollateralBalanceOfUser(USER, address(wbtc)), btcAmount);
        assertEq(stablecoin.balanceOf(USER), mintAmount);
        assertGe(engine.getHealthFactor(USER), 1e18);
    }

    function test_RevertsWhenDepositingAndMintingWithZeroAmounts() public {
        vm.startPrank(USER);
        weth.approve(address(engine), 10 ether);
        vm.expectRevert();
        engine.depositCollateralAndMintStablecoin(address(weth), 0, 1e18);
        vm.expectRevert();
        engine.depositCollateralAndMintStablecoin(address(weth), 10 ether, 0);
        vm.stopPrank();
    }

    // ============================================
    // Health Factor Tests
    // ============================================

    function test_HealthFactorIsCorrectAfterDepositAndMint() public {
        uint256 collateralAmount = 10 ether;
        uint256 collateralValueUsd = (collateralAmount * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 maxMint = collateralValueUsd / 2; // 50% max collateral ratio
        // When supply is 0, first mint is unlimited (up to daily limit)
        // When supply > 0, limit is 1% of supply
        uint256 currentSupply = stablecoin.totalSupply();
        uint256 maxAllowedMint = currentSupply == 0 ? type(uint256).max : currentSupply / 100;
        maxMint = maxMint > maxAllowedMint ? maxAllowedMint : maxMint;
        uint256 mintAmount = maxMint * 80 / 100; // Mint 80% of max to be safe
        
        vm.startPrank(USER);
        weth.approve(address(engine), collateralAmount);
        engine.depositCollateralAndMintStablecoin(address(weth), collateralAmount, mintAmount);
        vm.stopPrank();

        uint256 healthFactor = engine.getHealthFactor(USER);
        assertGe(healthFactor, 1e18, "Health factor should be at least 1.0");
        
        // Verify health factor calculation
        // HF = (Collateral Value * 50%) / Debt
        // With 80% of max mint: HF should be around 1.25 (1.25e18)
        // Expected HF = (collateralValueUsd * 50 / 100) / (mintAmount)
        uint256 expectedHF = (collateralValueUsd * 50 / 100 * PRECISION) / mintAmount;
        assertApproxEqRel(healthFactor, expectedHF, 0.01e18, "Health factor calculation incorrect");
    }

    function test_HealthFactorIncreasesWhenAddingMoreCollateral() public {
        uint256 initialCollateral = 10 ether;
        uint256 additionalCollateral = 5 ether;
        uint256 initialCollateralValueUsd = (initialCollateral * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 maxMint = initialCollateralValueUsd / 2;
        uint256 maxAllowedMint = stablecoin.totalSupply() / 100;
        maxMint = maxMint > maxAllowedMint ? maxAllowedMint : maxMint;
        uint256 mintAmount = maxMint * 80 / 100;
        
        vm.startPrank(USER);
        weth.approve(address(engine), initialCollateral + additionalCollateral);
        engine.depositCollateralAndMintStablecoin(address(weth), initialCollateral, mintAmount);
        
        uint256 healthFactorBefore = engine.getHealthFactor(USER);
        
        engine.depositCollateral(address(weth), additionalCollateral);
        
        uint256 healthFactorAfter = engine.getHealthFactor(USER);
        vm.stopPrank();

        assertGt(healthFactorAfter, healthFactorBefore, "Health factor should increase with more collateral");
    }

    // ============================================
    // Account Information Tests
    // ============================================

    function test_GetAccountInformationReturnsCorrectValues() public {
        uint256 collateralAmount = 10 ether;
        uint256 collateralValueUsd = (collateralAmount * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 maxMint = collateralValueUsd / 2;
        uint256 maxAllowedMint = stablecoin.totalSupply() / 100;
        maxMint = maxMint > maxAllowedMint ? maxAllowedMint : maxMint;
        uint256 mintAmount = maxMint * 80 / 100;
        
        vm.startPrank(USER);
        weth.approve(address(engine), collateralAmount);
        engine.depositCollateralAndMintStablecoin(address(weth), collateralAmount, mintAmount);
        vm.stopPrank();

        (uint256 totalStablecoinMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        
        assertEq(totalStablecoinMinted, mintAmount, "Total stablecoin minted should match");
        assertApproxEqRel(collateralValueInUsd, collateralValueUsd, 0.001e18, "Collateral value should match");
    }

    // ============================================
    // Edge Cases and Integration Scenarios
    // ============================================

    function test_MultipleDepositsAndMints() public {
        uint256 firstDeposit = 5 ether;
        uint256 secondDeposit = 5 ether;
        uint256 totalCollateral = firstDeposit + secondDeposit;
        
        vm.startPrank(USER);
        weth.approve(address(engine), totalCollateral);
        
        // First deposit
        engine.depositCollateral(address(weth), firstDeposit);
        
        // Second deposit
        engine.depositCollateral(address(weth), secondDeposit);
        
        // Calculate max mint based on total collateral
        uint256 totalCollateralValueUsd = (totalCollateral * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 maxMint = totalCollateralValueUsd / 2;
        uint256 maxAllowedMint = stablecoin.totalSupply() / 100;
        maxMint = maxMint > maxAllowedMint ? maxAllowedMint : maxMint;
        uint256 mintAmount = maxMint * 80 / 100;
        
        // Mint stablecoin
        engine.mintStablecoin(mintAmount);
        vm.stopPrank();

        assertEq(engine.getCollateralBalanceOfUser(USER, address(weth)), totalCollateral);
        assertEq(stablecoin.balanceOf(USER), mintAmount);
        assertGe(engine.getHealthFactor(USER), 1e18);
    }

    function test_DepositAndMintWithDifferentCollateralTypes() public {
        uint256 ethAmount = 10 ether;
        uint256 btcAmount = 1 ether; // 1 BTC
        
        vm.startPrank(USER);
        weth.approve(address(engine), ethAmount);
        wbtc.approve(address(engine), btcAmount);
        
        // Deposit both collateral types
        engine.depositCollateral(address(weth), ethAmount);
        engine.depositCollateral(address(wbtc), btcAmount);
        
        // Calculate total collateral value
        uint256 ethValueUsd = (ethAmount * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 btcValueUsd = (btcAmount * BTC_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 totalCollateralValueUsd = ethValueUsd + btcValueUsd;
        
        uint256 maxMint = totalCollateralValueUsd / 2;
        uint256 maxAllowedMint = stablecoin.totalSupply() / 100;
        maxMint = maxMint > maxAllowedMint ? maxAllowedMint : maxMint;
        uint256 mintAmount = maxMint * 80 / 100;
        
        // Mint stablecoin
        engine.mintStablecoin(mintAmount);
        vm.stopPrank();

        assertEq(engine.getCollateralBalanceOfUser(USER, address(weth)), ethAmount);
        assertEq(engine.getCollateralBalanceOfUser(USER, address(wbtc)), btcAmount);
        assertEq(stablecoin.balanceOf(USER), mintAmount);
        assertGe(engine.getHealthFactor(USER), 1e18);
    }
}
