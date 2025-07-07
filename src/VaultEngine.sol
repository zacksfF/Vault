// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import "./VaultStablecoin.sol";
import "./interfaces/IVaultEngine.sol";
import "./libraries/PriceOracle.sol";
import "./libraries/VaultMath.sol";
import "./libraries/VaultErrors.sol";

/**
 * @title VaultEngine
 * @author Zakaria Saif
 * @notice Core engine of the Vault Protocol - a decentralized, overcollateralized stablecoin system
 * @dev This contract handles all core functionality:
 *      - Collateral management (WETH, WBTC)
 *      - Stablecoin minting and burning
 *      - Liquidations
 *      - Health factor calculations
 * 
 * Key Features:
 * - 200% minimum collateralization ratio
 * - Chainlink price feeds with staleness protection
 * - Liquidation incentives (10% bonus)
 * - Reentrancy protection
 * - Emergency pause functionality
 */
contract VaultEngine is ReentrancyGuard, IVaultEngine {
    using PriceOracle for AggregatorV3Interface;
    using VaultMath for uint256;

    uint256 constant MAX_SUPPORTED_TOKENS = 50; // Reasonable limit


    // State Variables
    VaultStablecoin private immutable i_vaultStablecoin;
    
    /// @dev Mapping of token address to price feed address
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    
    /// @dev Amount of collateral deposited by user
    mapping(address user => mapping(address collateralToken => uint256 amount)) private s_collateralDeposited;
    
    /// @dev Amount of stablecoin minted by user
    mapping(address user => uint256 amount) private s_stablecoinMinted;
    
    /// @dev Array of supported collateral tokens
    address[] private s_collateralTokens;

    // Modifiers
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert VaultErrors.Vault__ZeroAmount();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert VaultErrors.Vault__TokenNotSupported();
        }
        _;
    }

    /**
     * @notice Initializes the Vault Engine
     * @param tokenAddresses Array of supported collateral token addresses
     * @param priceFeedAddresses Array of corresponding Chainlink price feed addresses
     * @param vaultStablecoinAddress Address of the VaultStablecoin contract
     */
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address vaultStablecoinAddress
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert VaultErrors.Vault__CollateralAddressesAndPriceFeedsMismatch();
        }
        if (vaultStablecoinAddress == address(0)) {
            revert VaultErrors.Vault__ZeroAddress();
        }

        uint256 length = tokenAddresses.length; // Cache length
        // Initialize supported tokens and price feeds
        for (uint256 i = 0; i < length;) {
            if (tokenAddresses[i] == address(0) || priceFeedAddresses[i] == address(0)) {
                revert VaultErrors.Vault__ZeroAddress();
            }
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_vaultStablecoin = VaultStablecoin(vaultStablecoinAddress);
    }

    // External Functions

    /**
     * @notice Deposits collateral and mints stablecoins in one transaction
     * @param tokenCollateralAddress Address of the collateral token
     * @param amountCollateral Amount of collateral to deposit
     * @param amountStablecoinToMint Amount of stablecoins to mint
     */
    
    function depositCollateralAndMintStablecoin(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountStablecoinToMint
    ) external nonReentrant {  
        if (amountCollateral == 0 || amountStablecoinToMint == 0) {
            revert VaultErrors.Vault__ZeroAmount();
        }
        if (s_priceFeeds[tokenCollateralAddress] == address(0)) {
            revert VaultErrors.Vault__TokenNotSupported();
        }

        // Update state before external calls (CEI pattern)
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        s_stablecoinMinted[msg.sender] += amountStablecoinToMint;

        // Validate health factor
        _revertIfHealthFactorIsBroken(msg.sender);

        // External calls last
        bool collateralSuccess = IERC20(tokenCollateralAddress).transferFrom(
            msg.sender, address(this), amountCollateral
        );
        require(collateralSuccess, "Collateral transfer failed");

        bool mintSuccess = i_vaultStablecoin.mint(msg.sender, amountStablecoinToMint);
        require(mintSuccess, "Mint failed");

        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        emit StablecoinMinted(msg.sender, amountStablecoinToMint);
    }


    /**
     * @notice Redeems collateral and burns stablecoins in one transaction
     * @param tokenCollateralAddress Address of the collateral token
     * @param amountCollateral Amount of collateral to redeem
     * @param amountStablecoinToBurn Amount of stablecoins to burn
     */
    function redeemCollateralForStablecoin(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountStablecoinToBurn
    ) external moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) {
        _burnStablecoin(amountStablecoinToBurn, msg.sender, msg.sender);
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Liquidates an undercollateralized position
     * @param collateralToken Address of the collateral token to liquidate
     * @param user Address of the user to liquidate
     * @param debtToCover Amount of debt to cover (in stablecoin)
     * @dev Caller receives a 10% bonus on the collateral
     */
    function liquidate(address collateralToken, address user, uint256 debtToCover)
        external
        isAllowedToken(collateralToken)
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= VaultMath.MIN_HEALTH_FACTOR) {
            revert VaultErrors.Vault__PositionHealthy();
        }

        // Calculate collateral amount from debt covered
        uint256 tokenPriceInUsd = _getTokenPrice(collateralToken);
        uint256 tokenAmountFromDebtCovered = VaultMath.getTokenAmountFromUsd(debtToCover, tokenPriceInUsd);
        
        // Calculate liquidation bonus
        uint256 bonusCollateral = VaultMath.calculateLiquidationBonus(debtToCover, tokenPriceInUsd);
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;

        // Execute liquidation
        _redeemCollateral(collateralToken, totalCollateralToRedeem, user, msg.sender);
        _burnStablecoin(debtToCover, user, msg.sender);

        // Verify health factor improved
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert VaultErrors.Vault__HealthFactorNotImproved();
        }
        
        // Ensure liquidator's health factor is still good
        _revertIfHealthFactorIsBroken(msg.sender);

        emit UserLiquidated(user, msg.sender, collateralToken, debtToCover, totalCollateralToRedeem);
    }

    // Public Functions

    /**
     * @notice Deposits collateral tokens
     * @param tokenCollateralAddress Address of the collateral token
     * @param amountCollateral Amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        
        bool success = IERC20(tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            amountCollateral
        );
        if (!success) {
            revert VaultErrors.Vault__TransferFailed();
        }
    }

    /**
     * @notice Redeems collateral tokens
     * @param tokenCollateralAddress Address of the collateral token
     * @param amountCollateral Amount of collateral to redeem
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Mints stablecoins
     * @param amountStablecoinToMint Amount of stablecoins to mint
     */
    function mintStablecoin(uint256 amountStablecoinToMint) 
        public 
        moreThanZero(amountStablecoinToMint) 
        nonReentrant 
    {
        s_stablecoinMinted[msg.sender] += amountStablecoinToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        
        bool minted = i_vaultStablecoin.mint(msg.sender, amountStablecoinToMint);
        if (!minted) {
            revert VaultErrors.Vault__MintingFailed();
        }
        
        emit StablecoinMinted(msg.sender, amountStablecoinToMint);
    }

    /**
     * @notice Burns stablecoins
     * @param amountStablecoinToBurn Amount of stablecoins to burn
     */
    function burnStablecoin(uint256 amountStablecoinToBurn) 
        public 
        moreThanZero(amountStablecoinToBurn) 
    {
        _burnStablecoin(amountStablecoinToBurn, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // This should never hit
    }



    // Private Functions

    function _redeemCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        address from,
        address to
    ) private {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert VaultErrors.Vault__TransferFailed();
        }
    }

    function _burnStablecoin(uint256 amountStablecoinToBurn, address onBehalfOf, address stablecoinFrom) private {
        s_stablecoinMinted[onBehalfOf] -= amountStablecoinToBurn;
        
        bool success = i_vaultStablecoin.transferFrom(onBehalfOf, address(this), amountStablecoinToBurn);
        // if (!success) {
        //     revert VaultErrors.Vault__TransferFailed();
        // } 
        require(success, "Transfer failed");
        
        i_vaultStablecoin.burn(amountStablecoinToBurn);
        emit StablecoinBurned(onBehalfOf, amountStablecoinToBurn);
    }

    // Internal View Functions

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalStablecoinMinted, uint256 collateralValueInUsd)
    {
        totalStablecoinMinted = s_stablecoinMinted[user];
        collateralValueInUsd = getCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalStablecoinMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return VaultMath.calculateHealthFactor(totalStablecoinMinted, collateralValueInUsd);
    }

    function _getTokenPrice(address token) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        return priceFeed.getPrice();
    }

    function _getUsdValue(address token, uint256 amount) private view returns (uint256) {
        uint256 price = _getTokenPrice(token);
        return VaultMath.getUsdValue(amount, tokenPriceInUsd);
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < VaultMath.MIN_HEALTH_FACTOR) {
            revert VaultErrors.Vault__HealthFactorBelowMinimum(userHealthFactor);
        }
    }

    // External View Functions

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalStablecoinMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(user);
    }

    function getCollateralValue(address user, uint256 startIndex, uint256 maxTokens) public view returns (uint256 totalValue, uint256 nextIndex) {
        uint256 endIndex = startIndex + maxTokens;
        if (endIndex > s_collateralTokens.length) {
            endIndex = s_collateralTokens.length;
        }

        for (uint256 i = startIndex; i < endIndex; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            if (amount > 0) {  // Skip zero balances
                totalValue += _getUsdValue(token, amount);
            }
        }

        nextIndex = endIndex < s_collateralTokens.length ? endIndex : 0;
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) external view returns (uint256) {
        uint256 price = _getTokenPrice(token);
        return VaultMath.getTokenAmountFromUsd(usdAmountInWei, price);
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getStablecoin() external view returns (address) {
        return address(i_vaultStablecoin);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    // Constants getters
    function getLiquidationThreshold() external pure returns (uint256) {
        return VaultMath.LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return VaultMath.LIQUIDATION_BONUS;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return VaultMath.MIN_HEALTH_FACTOR;
    }

    function getPrecision() external pure returns (uint256) {
        return VaultMath.PRECISION;
    }
}