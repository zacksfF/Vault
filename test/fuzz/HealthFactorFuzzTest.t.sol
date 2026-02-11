// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/VaultEngine.sol";
import "../../src/VaultStablecoin.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/libraries/VaultMath.sol";
import "lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";



contract HealthFactorFuzzTest is Test {
    VaultEngine engine;
    VaultStablecoin stablecoin;
    MockERC20 weth;
    MockV3Aggregator ethPriceFeed;

    address public USER = makeAddr("user");
    address public OWNER = makeAddr("owner");

    uint256 constant STARTING_BALANCE = 1000 ether;
    uint256 constant ETH_PRICE = 2000e8;
    uint8 constant DECIMALS = 8;
    uint256 constant PRECISION = 1e18;
    uint256 constant ADDITIONAL_FEED_PRECISION = 1e10;

    function setUp() public {
        vm.startPrank(OWNER);

        weth = new MockERC20("Wrapped Ether", "WETH", 18, OWNER, STARTING_BALANCE * 10);
        ethPriceFeed = new MockV3Aggregator(DECIMALS, int256(ETH_PRICE));
        stablecoin = new VaultStablecoin(OWNER);

        address[] memory tokens = new address[](1);
        address[] memory priceFeeds = new address[](1);
        tokens[0] = address(weth);
        priceFeeds[0] = address(ethPriceFeed);

        engine = new VaultEngine(tokens, priceFeeds, address(stablecoin));
        stablecoin.transferOwnership(address(engine));
        weth.transfer(USER, STARTING_BALANCE);

        vm.stopPrank();
    }

    // ===================== Fuzz: Health Factor Invariants =====================

    function testFuzz_HealthFactorAlwaysAboveMinAfterValidMint(uint256 collateral, uint256 mintAmount) public {
        collateral = bound(collateral, 1 ether, STARTING_BALANCE);
        uint256 collateralValueUsd = (collateral * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        // At 200% ratio, max mint = collateralValue * 50 / 100
        uint256 maxMint = (collateralValueUsd * 50) / 100;
        mintAmount = bound(mintAmount, 1e18, maxMint);

        vm.startPrank(USER);
        weth.approve(address(engine), collateral);
        engine.depositCollateral(address(weth), collateral);
        engine.mintStablecoin(mintAmount);
        vm.stopPrank();

        uint256 hf = engine.getHealthFactor(USER);
        assertGe(hf, 1e18, "Health factor must be >= 1 for valid operations");
    }

    function testFuzz_HealthFactorInfiniteWithNoDebt(uint256 collateral) public {
        collateral = bound(collateral, 1 ether, STARTING_BALANCE);

        vm.startPrank(USER);
        weth.approve(address(engine), collateral);
        engine.depositCollateral(address(weth), collateral);
        vm.stopPrank();

        uint256 hf = engine.getHealthFactor(USER);
        assertEq(hf, type(uint256).max, "HF should be max with no debt");
    }

    function testFuzz_HealthFactorFormula(uint256 collateralValue, uint256 debt) public pure {
        collateralValue = bound(collateralValue, 1e18, 1e30);
        debt = bound(debt, 1e18, collateralValue);

        uint256 hf = VaultMath.calculateHealthFactor(collateralValue, debt);

        // Manual calculation: (collateralValue * 50 / 100 * 1e18) / debt
        uint256 expected = (collateralValue * 50 * 1e18) / (100 * debt);
        // Allow 1 wei rounding difference due to integer division order
        assertApproxEqAbs(hf, expected, 1, "Health factor formula mismatch");
    }

    function testFuzz_CollateralDepositNeverDecreasesHealthFactor(
        uint256 initialCollateral,
        uint256 mintAmount,
        uint256 additionalCollateral
    ) public {
        initialCollateral = bound(initialCollateral, 2 ether, STARTING_BALANCE / 2);
        additionalCollateral = bound(additionalCollateral, 1 ether, STARTING_BALANCE / 2);

        uint256 collateralValueUsd = (initialCollateral * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 maxMint = (collateralValueUsd * 50) / 100;
        mintAmount = bound(mintAmount, 1e18, maxMint);

        vm.startPrank(USER);
        weth.approve(address(engine), initialCollateral + additionalCollateral);
        engine.depositCollateral(address(weth), initialCollateral);
        engine.mintStablecoin(mintAmount);

        uint256 hfBefore = engine.getHealthFactor(USER);

        engine.depositCollateral(address(weth), additionalCollateral);

        uint256 hfAfter = engine.getHealthFactor(USER);
        vm.stopPrank();

        assertGe(hfAfter, hfBefore, "Adding collateral should never decrease health factor");
    }

    function testFuzz_BurnNeverDecreasesHealthFactor(
        uint256 collateral,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        collateral = bound(collateral, 2 ether, STARTING_BALANCE);
        uint256 collateralValueUsd = (collateral * ETH_PRICE * ADDITIONAL_FEED_PRECISION) / PRECISION;
        uint256 maxMint = (collateralValueUsd * 50) / 100;
        mintAmount = bound(mintAmount, 2e18, maxMint);
        burnAmount = bound(burnAmount, 1e18, mintAmount - 1e18);

        vm.startPrank(USER);
        weth.approve(address(engine), collateral);
        engine.depositCollateral(address(weth), collateral);
        engine.mintStablecoin(mintAmount);

        uint256 hfBefore = engine.getHealthFactor(USER);

        stablecoin.approve(address(engine), burnAmount);
        engine.burnStablecoin(burnAmount);

        uint256 hfAfter = engine.getHealthFactor(USER);
        vm.stopPrank();

        assertGe(hfAfter, hfBefore, "Burning debt should never decrease health factor");
    }
}
