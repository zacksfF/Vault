// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;



import "forge-std/Test.sol";
import "../../src/VaultEngine.sol";
import "../../src/VaultStablecoin.sol";
import "../../src/mocks/MockERC20.sol";
import "lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract LiquidationTest is Test {
    VaultEngine engine;
    VaultStablecoin stablecoin;
    MockERC20 weth;
    MockERC20 wbtc;
    MockV3Aggregator ethPriceFeed;
    MockV3Aggregator btcPriceFeed;

    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    address public OWNER = makeAddr("owner");

    uint256 constant STARTING_BALANCE = 1000 ether;
    uint256 constant ETH_PRICE = 2000e8;
    uint256 constant BTC_PRICE = 40000e8;
    uint256 constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 constant PRECISION = 1e18;
    uint8 constant DECIMALS = 8;

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
        weth.transfer(LIQUIDATOR, STARTING_BALANCE);

        vm.stopPrank();
    }

    /// @dev Helper: USER deposits collateral and mints stablecoin
    function _setupUserPosition(uint256 collateral, uint256 mintAmount) internal {
        vm.startPrank(USER);
        weth.approve(address(engine), collateral);
        engine.depositCollateralAndMintStablecoin(address(weth), collateral, mintAmount);
        vm.stopPrank();
    }

    /// @dev Helper: give LIQUIDATOR stablecoin to pay off debt
    function _giveLiquidatorStablecoin(uint256 amount) internal {
        // Liquidator deposits collateral and mints stablecoin
        vm.startPrank(LIQUIDATOR);
        weth.approve(address(engine), STARTING_BALANCE);
        engine.depositCollateral(address(weth), STARTING_BALANCE);
        engine.mintStablecoin(amount);
        vm.stopPrank();
    }

    // ===================== Liquidation Reverts =====================

    function test_LiquidateRevertsWhenPositionIsHealthy() public {
        _setupUserPosition(10 ether, 5000e18);

        _giveLiquidatorStablecoin(1000e18);

        vm.startPrank(LIQUIDATOR);
        stablecoin.approve(address(engine), 1000e18);
        vm.expectRevert();
        engine.liquidate(address(weth), USER, 1000e18);
        vm.stopPrank();
    }

    function test_LiquidateRevertsOnZeroDebt() public {
        vm.startPrank(LIQUIDATOR);
        vm.expectRevert();
        engine.liquidate(address(weth), USER, 0);
        vm.stopPrank();
    }

    function test_LiquidateRevertsOnUnsupportedToken() public {
        MockERC20 fake = new MockERC20("Fake", "FAKE", 18, LIQUIDATOR, 100 ether);

        vm.startPrank(LIQUIDATOR);
        vm.expectRevert();
        engine.liquidate(address(fake), USER, 1000e18);
        vm.stopPrank();
    }

    // ===================== Successful Liquidation =====================

    function test_LiquidationSucceedsAfterPriceDrop() public {
        // User deposits 10 ETH ($20k) and mints $9000 (HF ≈ 1.11)
        _setupUserPosition(10 ether, 9000e18);

        // Liquidator gets stablecoin
        _giveLiquidatorStablecoin(5000e18);

        // Price drops to $1000 → collateral = $10k, adjusted = $5k, HF = 5k/9k ≈ 0.55
        ethPriceFeed.updateAnswer(int256(1000e8));

        uint256 userHfBefore = engine.getHealthFactor(USER);
        assertLt(userHfBefore, 1e18, "User should be liquidatable");

        // Liquidator covers half the debt
        uint256 debtToCover = 4500e18;

        vm.startPrank(LIQUIDATOR);
        stablecoin.approve(address(engine), debtToCover);
        engine.liquidate(address(weth), USER, debtToCover);
        vm.stopPrank();

        // User's health factor should have improved
        uint256 userHfAfter = engine.getHealthFactor(USER);
        assertGt(userHfAfter, userHfBefore, "Health factor should improve after liquidation");
    }

    function test_LiquidatorReceivesBonusCollateral() public {
        _setupUserPosition(10 ether, 9000e18);
        _giveLiquidatorStablecoin(5000e18);

        // Price drops to $1000
        ethPriceFeed.updateAnswer(int256(1000e8));

        uint256 debtToCover = 2000e18;
        uint256 liquidatorWethBefore = weth.balanceOf(LIQUIDATOR);

        vm.startPrank(LIQUIDATOR);
        stablecoin.approve(address(engine), debtToCover);
        engine.liquidate(address(weth), USER, debtToCover);
        vm.stopPrank();

        uint256 liquidatorWethAfter = weth.balanceOf(LIQUIDATOR);
        uint256 wethReceived = liquidatorWethAfter - liquidatorWethBefore;

        // At $1000/ETH: $2000 debt = 2 ETH + 10% bonus = 2.2 ETH
        uint256 expectedBaseCollateral = 2 ether;
        uint256 expectedBonus = (expectedBaseCollateral * 10) / 100;
        uint256 expectedTotal = expectedBaseCollateral + expectedBonus;

        assertEq(wethReceived, expectedTotal, "Liquidator should get base + 10% bonus");
    }

    // ===================== Full Journey =====================

    function test_FullJourney_DepositMintDropLiquidateRedeem() public {
        // 1. User deposits and mints
        _setupUserPosition(10 ether, 8000e18);

        uint256 hf1 = engine.getHealthFactor(USER);
        assertGe(hf1, 1e18, "Position should start healthy");

        // 2. Price drops making position liquidatable
        ethPriceFeed.updateAnswer(int256(900e8));

        uint256 hf2 = engine.getHealthFactor(USER);
        assertLt(hf2, 1e18, "Position should be underwater after price drop");

        // 3. Liquidator steps in
        // Need to give liquidator stablecoin at the original price
        // Liquidator deposits at the new price ($900)
        _giveLiquidatorStablecoin(4000e18);

        vm.startPrank(LIQUIDATOR);
        stablecoin.approve(address(engine), 4000e18);
        engine.liquidate(address(weth), USER, 4000e18);
        vm.stopPrank();

        // 4. User's position should be improved
        uint256 hf3 = engine.getHealthFactor(USER);
        assertGt(hf3, hf2, "Health factor should improve post-liquidation");
    }
}
