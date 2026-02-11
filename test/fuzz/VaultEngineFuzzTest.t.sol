// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/VaultEngine.sol";
import "../../src/VaultStablecoin.sol";
import "../../src/mocks/MockERC20.sol";
import "lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";


contract VaultEngineFuzzTest is Test {
    VaultEngine engine;
    VaultStablecoin stablecoin;
    MockERC20 weth;
    MockERC20 wbtc;
    MockV3Aggregator ethPriceFeed;
    MockV3Aggregator btcPriceFeed;

    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    address public OWNER = makeAddr("owner");

    uint256 constant STARTING_BALANCE = 100 ether;
    uint256 constant ETH_PRICE = 2000e8; // $2000 with 8 decimals (Chainlink format)
    uint256 constant BTC_PRICE = 40000e8; // $40000 with 8 decimals (Chainlink format)
    uint8 constant DECIMALS = 8;
    uint256 constant PRECISION = 1e18;
    uint256 constant ADDITIONAL_FEED_PRECISION = 1e10;

    function setUp() public {
        vm.startPrank(OWNER);
        
        // Deploy mocks
        weth = new MockERC20("Wrapped Ether", "WETH", 18, OWNER, STARTING_BALANCE * 3);
        wbtc = new MockERC20("Wrapped Bitcoin", "WBTC", 18, OWNER, STARTING_BALANCE * 3);
        
        ethPriceFeed = new MockV3Aggregator(DECIMALS, int256(ETH_PRICE));
        btcPriceFeed = new MockV3Aggregator(DECIMALS, int256(BTC_PRICE));

        // Deploy stablecoin with OWNER and initialize with base supply
        stablecoin = new VaultStablecoin(OWNER);
        
        // Initialize base supply (stop/restart prank to avoid overlap)
        stablecoin.mint(OWNER, 1000000e18);

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

        // Distribute tokens to users
        weth.transfer(USER, STARTING_BALANCE);
        wbtc.transfer(USER, STARTING_BALANCE);
        weth.transfer(LIQUIDATOR, STARTING_BALANCE);
        wbtc.transfer(LIQUIDATOR, STARTING_BALANCE);
        
        vm.stopPrank();
    }

    // ============================================
    // Deposit Collateral Fuzz Tests
    // ============================================

    function testFuzz_DepositCollateral(uint256 amount) public {
        amount = bound(amount, 1, STARTING_BALANCE);
        
        vm.startPrank(USER);
        weth.approve(address(engine), amount);
        engine.depositCollateral(address(weth), amount);
        vm.stopPrank();

        assertEq(engine.getCollateralBalanceOfUser(USER, address(weth)), amount);
    }

    function testFuzz_DepositMultipleCollateralTypes(uint256 ethAmount, uint256 btcAmount) public {
        ethAmount = bound(ethAmount, 1, STARTING_BALANCE);
        btcAmount = bound(btcAmount, 1, STARTING_BALANCE);
        
        vm.startPrank(USER);
        weth.approve(address(engine), ethAmount);
        wbtc.approve(address(engine), btcAmount);
        
        engine.depositCollateral(address(weth), ethAmount);
        engine.depositCollateral(address(wbtc), btcAmount);
        vm.stopPrank();

        assertEq(engine.getCollateralBalanceOfUser(USER, address(weth)), ethAmount);
        assertEq(engine.getCollateralBalanceOfUser(USER, address(wbtc)), btcAmount);
    }

    // ============================================
    // Mint Stablecoin Fuzz Tests
    // ============================================

    function testFuzz_MintStablecoin(uint256 collateralAmount, uint256 mintAmount) public {
        collateralAmount = bound(collateralAmount, 1 ether, STARTING_BALANCE);
        uint256 maxCollateralUsd = (collateralAmount * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 maxMint = maxCollateralUsd / 2; // 50% max collateral ratio
        uint256 maxAllowedMint = stablecoin.totalSupply() / 100; // 1% of total supply
        maxMint = maxMint > maxAllowedMint ? maxAllowedMint : maxMint; // Take the minimum
        mintAmount = bound(mintAmount, 1e18, maxMint);

        vm.startPrank(USER);
        weth.approve(address(engine), collateralAmount);
        engine.depositCollateral(address(weth), collateralAmount);
        engine.mintStablecoin(mintAmount);
        vm.stopPrank();

        assertEq(stablecoin.balanceOf(USER), mintAmount);
        assertGe(engine.getHealthFactor(USER), 1e18);
    }

    function testFuzz_DepositAndMintInOneTransaction(uint256 collateralAmount, uint256 mintAmount) public {
        collateralAmount = bound(collateralAmount, 1 ether, STARTING_BALANCE);
        uint256 maxCollateralUsd = (collateralAmount * ETH_PRICE * 1e10); // Convert to USD with 18 decimals
        uint256 maxMint = maxCollateralUsd / 2; // 50% max collateral ratio
        uint256 maxAllowedMint = stablecoin.totalSupply() / 100; // 1% of total supply
        maxMint = maxMint > maxAllowedMint ? maxAllowedMint : maxMint; // Take the minimum
        mintAmount = bound(mintAmount, 1e18, maxMint);

        vm.startPrank(USER);
        weth.approve(address(engine), collateralAmount);
        engine.depositCollateralAndMintStablecoin(address(weth), collateralAmount, mintAmount);
        vm.stopPrank();

        assertEq(engine.getCollateralBalanceOfUser(USER, address(weth)), collateralAmount);
        assertEq(stablecoin.balanceOf(USER), mintAmount);
        assertGe(engine.getHealthFactor(USER), 1e18);
    }

    // ============================================
    // Redeem Collateral Fuzz Tests
    // ============================================

    function testFuzz_RedeemCollateral(uint256 depositAmount, uint256 redeemAmount) public {
        depositAmount = bound(depositAmount, 1 ether, STARTING_BALANCE);
        redeemAmount = bound(redeemAmount, 1, depositAmount);

        vm.startPrank(USER);
        weth.approve(address(engine), depositAmount);
        engine.depositCollateral(address(weth), depositAmount);
        engine.redeemCollateral(address(weth), redeemAmount);
        vm.stopPrank();

        assertEq(engine.getCollateralBalanceOfUser(USER, address(weth)), depositAmount - redeemAmount);
        assertEq(weth.balanceOf(USER), STARTING_BALANCE - depositAmount + redeemAmount);
    }

    function testFuzz_RedeemCollateralForStablecoin(
        uint256 collateralAmount,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        collateralAmount = bound(collateralAmount, 5 ether, STARTING_BALANCE);
        uint256 maxCollateralUsd = (collateralAmount * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 maxMint = maxCollateralUsd / 3; // 33% max ratio for extra safety
        uint256 maxAllowedMint = stablecoin.totalSupply() / 100; // 1% of total supply
        maxMint = maxMint > maxAllowedMint ? maxAllowedMint : maxMint; // Take the minimum
        mintAmount = bound(mintAmount, 1e18, maxMint);
        burnAmount = bound(burnAmount, 1e18, mintAmount);

        vm.startPrank(USER);
        weth.approve(address(engine), collateralAmount);
        engine.depositCollateralAndMintStablecoin(address(weth), collateralAmount, mintAmount);
        
        uint256 redeemAmount = (burnAmount * PRECISION) / (ETH_PRICE * ADDITIONAL_FEED_PRECISION);
        if (redeemAmount > 0 && redeemAmount < collateralAmount / 2) {
            stablecoin.approve(address(engine), burnAmount);
            engine.redeemCollateralForStablecoin(address(weth), redeemAmount, burnAmount);
        }
        vm.stopPrank();

        assertGe(engine.getHealthFactor(USER), 1e18);
    }

    // ============================================
    // Burn Stablecoin Fuzz Tests
    // ============================================

    function testFuzz_BurnStablecoin(uint256 collateralAmount, uint256 mintAmount, uint256 burnAmount) public {
        collateralAmount = bound(collateralAmount, 1 ether, STARTING_BALANCE);
        uint256 maxCollateralUsd = (collateralAmount * ETH_PRICE * 1e10); // Convert to USD with 18 decimals
        uint256 maxMint = maxCollateralUsd / 2; // 50% max collateral ratio
        uint256 maxAllowedMint = stablecoin.totalSupply() / 100; // 1% of total supply
        maxMint = maxMint > maxAllowedMint ? maxAllowedMint : maxMint; // Take the minimum
        mintAmount = bound(mintAmount, 1e18, maxMint);
        burnAmount = bound(burnAmount, 1e18, mintAmount);

        vm.startPrank(USER);
        weth.approve(address(engine), collateralAmount);
        engine.depositCollateralAndMintStablecoin(address(weth), collateralAmount, mintAmount);
        
        stablecoin.approve(address(engine), burnAmount);
        engine.burnStablecoin(burnAmount);
        vm.stopPrank();

        assertEq(stablecoin.balanceOf(USER), mintAmount - burnAmount);
    }

    // ============================================
    // Health Factor Fuzz Tests
    // ============================================

    function testFuzz_HealthFactorAlwaysValid(uint256 collateralAmount, uint256 mintAmount) public {
        collateralAmount = bound(collateralAmount, 1 ether, STARTING_BALANCE);
        uint256 maxMint = (collateralAmount * ETH_PRICE) / 2e8;
        mintAmount = bound(mintAmount, 1e18, maxMint - 1e18);

        vm.startPrank(USER);
        weth.approve(address(engine), collateralAmount);
        engine.depositCollateralAndMintStablecoin(address(weth), collateralAmount, mintAmount);
        vm.stopPrank();

        uint256 healthFactor = engine.getHealthFactor(USER);
        assertGe(healthFactor, 1e18, "Health factor below minimum");
    }

    // ============================================
    // Liquidation Fuzz Tests
    // ============================================

    function testFuzz_Liquidation(uint256 collateralAmount, uint256 priceDropPercent) public {
        collateralAmount = bound(collateralAmount, 10 ether, STARTING_BALANCE);
        priceDropPercent = bound(priceDropPercent, 51, 70); // 51-70% drop
        
        uint256 maxCollateralUsd = (collateralAmount * ETH_PRICE * 1e10); // Convert to USD with 18 decimals
        uint256 maxMint = maxCollateralUsd / 2; // 50% max collateral ratio
        uint256 maxAllowedMint = stablecoin.totalSupply() / 100; // 1% of total supply
        maxMint = maxMint > maxAllowedMint ? maxAllowedMint : maxMint; // Take the minimum
        uint256 mintAmount = maxMint * 99 / 100; // Mint 99% of max allowed

        // User deposits and mints
        vm.startPrank(USER);
        weth.approve(address(engine), collateralAmount);
        engine.depositCollateralAndMintStablecoin(address(weth), collateralAmount, mintAmount);
        vm.stopPrank();

        // Price drops
        uint256 newPrice = (ETH_PRICE * (100 - priceDropPercent)) / 100;
        ethPriceFeed.updateAnswer(int256(newPrice));

        // Verify user is liquidatable
        uint256 healthFactorBefore = engine.getHealthFactor(USER);
        if (healthFactorBefore >= 1e18) return; // Skip if still healthy

        // Prepare liquidator with stablecoin
        uint256 debtToCover = mintAmount / 2; // Cover half the debt
        
        // Give liquidator more stablecoin directly instead of trying to mint
        vm.startPrank(OWNER);
        stablecoin.transfer(LIQUIDATOR, debtToCover);
        vm.stopPrank();
        
        vm.startPrank(LIQUIDATOR);
        // Liquidate
        stablecoin.approve(address(engine), debtToCover);
        engine.liquidate(address(weth), USER, debtToCover);
        vm.stopPrank();

        // Verify liquidation improved health factor
        uint256 healthFactorAfter = engine.getHealthFactor(USER);
        assertGt(healthFactorAfter, healthFactorBefore, "Health factor should improve");
    }

    // ============================================
    // Edge Cases and Invariants
    // ============================================

    function testFuzz_CannotMintWithoutCollateral(uint256 mintAmount) public {
        mintAmount = bound(mintAmount, 1, type(uint128).max);
        
        vm.startPrank(USER);
        vm.expectRevert();
        engine.mintStablecoin(mintAmount);
        vm.stopPrank();
    }

    function testFuzz_CannotRedeemMoreThanDeposited(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1 ether, STARTING_BALANCE);
        uint256 redeemAmount = depositAmount + 1;

        vm.startPrank(USER);
        weth.approve(address(engine), depositAmount);
        engine.depositCollateral(address(weth), depositAmount);
        
        vm.expectRevert();
        engine.redeemCollateral(address(weth), redeemAmount);
        vm.stopPrank();
    }

    function testFuzz_CollateralValueAlwaysAccurate(uint256 ethAmount, uint256 btcAmount) public {
        ethAmount = bound(ethAmount, 1 ether, STARTING_BALANCE);
        btcAmount = bound(btcAmount, 0.1 ether, STARTING_BALANCE);

        vm.startPrank(USER);
        weth.approve(address(engine), ethAmount);
        wbtc.approve(address(engine), btcAmount);
        
        engine.depositCollateral(address(weth), ethAmount);
        engine.depositCollateral(address(wbtc), btcAmount);
        vm.stopPrank();

        // Calculate expected value in USD (18 decimals)
        uint256 ethValue = (ethAmount * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 btcValue = (btcAmount * BTC_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 expectedValue = ethValue + btcValue;
        uint256 actualValue = engine.getCollateralValue(USER);
        
        assertApproxEqRel(actualValue, expectedValue, 0.001e18, "Collateral value mismatch");
    }

    function testFuzz_MultipleUsersIndependent(
        uint256 user1Collateral,
        uint256 user1Mint,
        uint256 user2Collateral,
        uint256 user2Mint
    ) public {
        address USER2 = makeAddr("user2");
        
        // Give USER2 tokens
        vm.prank(OWNER);
        weth.transfer(USER2, STARTING_BALANCE);
        
        // Bound amounts
        user1Collateral = bound(user1Collateral, 2 ether, STARTING_BALANCE);
        user2Collateral = bound(user2Collateral, 2 ether, STARTING_BALANCE);
        
        // Calculate max mint amounts for both users
        uint256 maxCollateralUsd1 = (user1Collateral * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 maxCollateralUsd2 = (user2Collateral * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        
        uint256 maxMint1 = maxCollateralUsd1 / 2; // 50% max collateral ratio
        uint256 maxMint2 = maxCollateralUsd2 / 2; // 50% max collateral ratio
        
        uint256 maxAllowedMint = stablecoin.totalSupply() / 200; // 0.5% of supply for each user
        maxMint1 = maxMint1 > maxAllowedMint ? maxAllowedMint : maxMint1;
        maxMint2 = maxMint2 > maxAllowedMint ? maxAllowedMint : maxMint2;
        
        user1Mint = bound(user1Mint, 1e18, maxMint1);
        user2Mint = bound(user2Mint, 1e18, maxMint2);
        
        // User 1 operations
        vm.startPrank(USER);
        weth.approve(address(engine), user1Collateral);
        engine.depositCollateralAndMintStablecoin(address(weth), user1Collateral, user1Mint);
        vm.stopPrank();
        
        // User 2 operations
        vm.startPrank(USER2);
        weth.approve(address(engine), user2Collateral);
        engine.depositCollateralAndMintStablecoin(address(weth), user2Collateral, user2Mint);
        vm.stopPrank();
        
        // Verify independence
        assertEq(engine.getCollateralBalanceOfUser(USER, address(weth)), user1Collateral);
        assertEq(engine.getCollateralBalanceOfUser(USER2, address(weth)), user2Collateral);
        assertEq(stablecoin.balanceOf(USER), user1Mint);
        assertEq(stablecoin.balanceOf(USER2), user2Mint);
        assertGe(engine.getHealthFactor(USER), 1e18);
        assertGe(engine.getHealthFactor(USER2), 1e18);
    }

    function testFuzz_CannotBreakProtocolWithZeroValues(uint256 amount) public {
        amount = bound(amount, 1, STARTING_BALANCE);
        
        vm.startPrank(USER);
        weth.approve(address(engine), amount);
        
        // Should revert on zero deposits
        vm.expectRevert();
        engine.depositCollateral(address(weth), 0);
        
        // Should revert on zero minting
        engine.depositCollateral(address(weth), amount);
        vm.expectRevert();
        engine.mintStablecoin(0);
        
        vm.stopPrank();
    }
}