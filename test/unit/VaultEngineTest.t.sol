// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/VaultEngine.sol";
import "../../src/VaultStablecoin.sol";
import "../../src/mocks/MockERC20.sol";
import "lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract VaultEngineTest is Test {
    VaultEngine engine;
    VaultStablecoin stablecoin;
    MockERC20 weth;
    MockERC20 wbtc;
    MockV3Aggregator ethPriceFeed;
    MockV3Aggregator btcPriceFeed;

    address public USER = makeAddr("user");
    address public OWNER = makeAddr("owner");

    uint256 constant STARTING_BALANCE = 1000 ether;
    uint256 constant ETH_PRICE = 2000e8;
    uint256 constant BTC_PRICE = 40000e8;
    uint8 constant DECIMALS = 8;
    uint256 constant PRECISION = 1e18;
    uint256 constant ADDITIONAL_FEED_PRECISION = 1e10;

    function setUp() public {
        vm.startPrank(OWNER);

        weth = new MockERC20("Wrapped Ether", "WETH", 18, OWNER, STARTING_BALANCE * 10);
        wbtc = new MockERC20("Wrapped Bitcoin", "WBTC", 18, OWNER, STARTING_BALANCE * 10);

        ethPriceFeed = new MockV3Aggregator(DECIMALS, int256(ETH_PRICE));
        btcPriceFeed = new MockV3Aggregator(DECIMALS, int256(BTC_PRICE));

        stablecoin = new VaultStablecoin(OWNER);
        stablecoin.mint(OWNER, 1000000e18); // Bootstrap supply

        address[] memory tokens = new address[](2);
        address[] memory priceFeeds = new address[](2);
        tokens[0] = address(weth);
        tokens[1] = address(wbtc);
        priceFeeds[0] = address(ethPriceFeed);
        priceFeeds[1] = address(btcPriceFeed);

        engine = new VaultEngine(tokens, priceFeeds, address(stablecoin));
        stablecoin.transferOwnership(address(engine));

        weth.transfer(USER, STARTING_BALANCE);
        wbtc.transfer(USER, STARTING_BALANCE);

        vm.stopPrank();
    }

    // ===================== Constructor =====================

    function test_ConstructorSetsTokensCorrectly() public view {
        address[] memory supported = engine.getSupportedTokens();
        assertEq(supported.length, 2);
        assertEq(supported[0], address(weth));
        assertEq(supported[1], address(wbtc));
    }

    function test_ConstructorSetsPriceFeedsCorrectly() public view {
        assertEq(engine.getCollateralTokenPriceFeed(address(weth)), address(ethPriceFeed));
        assertEq(engine.getCollateralTokenPriceFeed(address(wbtc)), address(btcPriceFeed));
    }

    function test_ConstructorRevertsOnMismatchedArrays() public {
        address[] memory tokens = new address[](2);
        address[] memory feeds = new address[](1);
        tokens[0] = address(weth);
        tokens[1] = address(wbtc);
        feeds[0] = address(ethPriceFeed);

        vm.expectRevert();
        new VaultEngine(tokens, feeds, address(stablecoin));
    }

    function test_ConstructorRevertsOnZeroStablecoinAddress() public {
        address[] memory tokens = new address[](1);
        address[] memory feeds = new address[](1);
        tokens[0] = address(weth);
        feeds[0] = address(ethPriceFeed);

        vm.expectRevert();
        new VaultEngine(tokens, feeds, address(0));
    }

    // ===================== Deposit Collateral =====================

    function test_DepositCollateralUpdatesBalance() public {
        uint256 amount = 10 ether;
        vm.startPrank(USER);
        weth.approve(address(engine), amount);
        engine.depositCollateral(address(weth), amount);
        vm.stopPrank();

        assertEq(engine.getCollateralBalanceOfUser(USER, address(weth)), amount);
        assertEq(weth.balanceOf(address(engine)), amount);
    }

    function test_DepositRevertsOnZeroAmount() public {
        vm.startPrank(USER);
        weth.approve(address(engine), 1 ether);
        vm.expectRevert();
        engine.depositCollateral(address(weth), 0);
        vm.stopPrank();
    }

    function test_DepositRevertsOnUnsupportedToken() public {
        MockERC20 fake = new MockERC20("Fake", "FAKE", 18, USER, 100 ether);
        vm.startPrank(USER);
        fake.approve(address(engine), 10 ether);
        vm.expectRevert();
        engine.depositCollateral(address(fake), 10 ether);
        vm.stopPrank();
    }

    // ===================== Redeem Collateral =====================

    function test_RedeemCollateralUpdatesBalance() public {
        uint256 depositAmt = 10 ether;
        uint256 redeemAmt = 4 ether;

        vm.startPrank(USER);
        weth.approve(address(engine), depositAmt);
        engine.depositCollateral(address(weth), depositAmt);
        engine.redeemCollateral(address(weth), redeemAmt);
        vm.stopPrank();

        assertEq(engine.getCollateralBalanceOfUser(USER, address(weth)), depositAmt - redeemAmt);
        assertEq(weth.balanceOf(USER), STARTING_BALANCE - depositAmt + redeemAmt);
    }

    function test_RedeemRevertsOnZeroAmount() public {
        vm.startPrank(USER);
        vm.expectRevert();
        engine.redeemCollateral(address(weth), 0);
        vm.stopPrank();
    }

    function test_RedeemRevertsWhenMoreThanDeposited() public {
        vm.startPrank(USER);
        weth.approve(address(engine), 5 ether);
        engine.depositCollateral(address(weth), 5 ether);
        vm.expectRevert();
        engine.redeemCollateral(address(weth), 6 ether);
        vm.stopPrank();
    }

    // ===================== Mint Stablecoin =====================

    function test_MintStablecoinWorks() public {
        uint256 collateral = 10 ether;
        // With $2000 ETH, 10 ETH = $20k collateral → can mint up to $10k at 200% ratio
        uint256 mintAmount = 5000e18;

        vm.startPrank(USER);
        weth.approve(address(engine), collateral);
        engine.depositCollateral(address(weth), collateral);
        engine.mintStablecoin(mintAmount);
        vm.stopPrank();

        assertEq(stablecoin.balanceOf(USER), mintAmount);
    }

    function test_MintRevertsOnZeroAmount() public {
        vm.startPrank(USER);
        weth.approve(address(engine), 10 ether);
        engine.depositCollateral(address(weth), 10 ether);
        vm.expectRevert();
        engine.mintStablecoin(0);
        vm.stopPrank();
    }

    function test_MintRevertsWithoutCollateral() public {
        vm.startPrank(USER);
        vm.expectRevert();
        engine.mintStablecoin(100e18);
        vm.stopPrank();
    }

    function test_MintRevertsWhenExceedingCollateralRatio() public {
        uint256 collateral = 10 ether;
        // $20k collateral → max $10k mint. Try $10001
        // But also limited by 1% of supply = 10000e18
        // So mint exactly at threshold (10000e18) succeeds but 10001e18 breaks health factor
        uint256 tooMuch = 10001e18;

        vm.startPrank(USER);
        weth.approve(address(engine), collateral);
        engine.depositCollateral(address(weth), collateral);
        vm.expectRevert();
        engine.mintStablecoin(tooMuch);
        vm.stopPrank();
    }

    // ===================== Burn Stablecoin =====================

    function test_BurnStablecoinWorks() public {
        uint256 collateral = 10 ether;
        uint256 mintAmount = 5000e18;

        vm.startPrank(USER);
        weth.approve(address(engine), collateral);
        engine.depositCollateral(address(weth), collateral);
        engine.mintStablecoin(mintAmount);

        stablecoin.approve(address(engine), mintAmount);
        engine.burnStablecoin(mintAmount);
        vm.stopPrank();

        assertEq(stablecoin.balanceOf(USER), 0);
    }

    function test_BurnRevertsOnZeroAmount() public {
        vm.startPrank(USER);
        vm.expectRevert();
        engine.burnStablecoin(0);
        vm.stopPrank();
    }

    // ===================== Health Factor =====================

    function test_HealthFactorMaxWhenNoDebt() public {
        vm.startPrank(USER);
        weth.approve(address(engine), 10 ether);
        engine.depositCollateral(address(weth), 10 ether);
        vm.stopPrank();

        uint256 hf = engine.getHealthFactor(USER);
        assertEq(hf, type(uint256).max);
    }

    function test_HealthFactorCorrectWithDebt() public {
        uint256 collateral = 10 ether;
        uint256 mintAmount = 5000e18;

        vm.startPrank(USER);
        weth.approve(address(engine), collateral);
        engine.depositCollateral(address(weth), collateral);
        engine.mintStablecoin(mintAmount);
        vm.stopPrank();

        uint256 hf = engine.getHealthFactor(USER);
        // 10 ETH * $2000 = $20000 collateral
        // Adjusted: $20000 * 50 / 100 = $10000
        // HF = $10000 * 1e18 / $5000 = 2e18
        assertEq(hf, 2e18);
    }

    function test_HealthFactorAt1WhenExactlyAtThreshold() public {
        uint256 collateral = 10 ether;
        // $20000 collateral → adjusted $10000 → HF = $10000 / $10000 = 1e18
        uint256 mintAmount = 10000e18;

        vm.startPrank(USER);
        weth.approve(address(engine), collateral);
        engine.depositCollateral(address(weth), collateral);
        engine.mintStablecoin(mintAmount);
        vm.stopPrank();

        uint256 hf = engine.getHealthFactor(USER);
        assertEq(hf, 1e18);
    }

    // ===================== Deposit & Mint Combined =====================

    function test_DepositAndMintInOneTransaction() public {
        uint256 collateral = 10 ether;
        uint256 mintAmount = 5000e18;

        vm.startPrank(USER);
        weth.approve(address(engine), collateral);
        engine.depositCollateralAndMintStablecoin(address(weth), collateral, mintAmount);
        vm.stopPrank();

        assertEq(engine.getCollateralBalanceOfUser(USER, address(weth)), collateral);
        assertEq(stablecoin.balanceOf(USER), mintAmount);
        assertGe(engine.getHealthFactor(USER), 1e18);
    }

    // ===================== Collateral Value =====================

    function test_CollateralValueSingleToken() public {
        uint256 amount = 10 ether;
        vm.startPrank(USER);
        weth.approve(address(engine), amount);
        engine.depositCollateral(address(weth), amount);
        vm.stopPrank();

        uint256 value = engine.getCollateralValue(USER);
        // 10 * 2000e8 * 1e10 / 1e18 * 1e18 → 10 * 2000e18 = 20000e18
        uint256 expected = (amount * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        assertEq(value, expected);
    }

    function test_CollateralValueMultipleTokens() public {
        vm.startPrank(USER);
        weth.approve(address(engine), 10 ether);
        wbtc.approve(address(engine), 1 ether);
        engine.depositCollateral(address(weth), 10 ether);
        engine.depositCollateral(address(wbtc), 1 ether);
        vm.stopPrank();

        uint256 value = engine.getCollateralValue(USER);
        uint256 ethValue = (10 ether * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 btcValue = (1 ether * BTC_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        assertEq(value, ethValue + btcValue);
    }

    // ===================== Account Information =====================

    function test_GetAccountInformation() public {
        uint256 collateral = 10 ether;
        uint256 mintAmount = 5000e18;

        vm.startPrank(USER);
        weth.approve(address(engine), collateral);
        engine.depositCollateral(address(weth), collateral);
        engine.mintStablecoin(mintAmount);
        vm.stopPrank();

        (uint256 minted, uint256 colValue) = engine.getAccountInformation(USER);
        assertEq(minted, mintAmount);
        uint256 expectedValue = (collateral * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        assertEq(colValue, expectedValue);
    }

    // ===================== View Functions =====================

    function test_GetStablecoinReturnsCorrectAddress() public view {
        assertEq(engine.getStablecoin(), address(stablecoin));
    }

    function test_GetConstantsReturnCorrectValues() public view {
        assertEq(engine.getLiquidationThreshold(), 50);
        assertEq(engine.getLiquidationBonus(), 10);
        assertEq(engine.getMinHealthFactor(), 1e18);
        assertEq(engine.getPrecision(), 1e18);
    }
}
