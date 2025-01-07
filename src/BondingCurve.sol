// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IUniswapV2Factory} from "./uniswap/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "./uniswap/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2ERC20} from "./uniswap/interfaces/IUniswapV2ERC20.sol";
import {ICore} from "./interfaces/ICore.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import "./errors/Errors.sol";

/**
 * @title BondingCurve
 * @dev Implementation of a bonding curve for token price discovery
 * Manages the relationship between Native and project tokens using a constant product formula
 */
contract BondingCurve is IBondingCurve {
    using TransferHelper for IERC20;

    // Immutable state variables
    address immutable factory;
    address immutable core;
    address public immutable wNative; // Wrapped Native token address
    address public token; // Project token address
    address public pair;
    // Virtual reserves for price calculation
    uint256 private virtualNative; // Virtual Native reserve
    uint256 private virtualToken; // Virtual token reserve
    uint256 private k; // Constant product parameter
    uint256 private targetToken; // Target token amount for listing

    /**
     * @dev Fee configuration structure
     * @param denominator Fee percentage denominator
     * @param numerator Fee percentage numerator
     */
    struct Fee {
        uint8 denominator;
        uint16 numerator;
    }
    Fee feeConfig;

    // Real reserves tracking actual balances
    uint256 realNativeReserves;
    uint256 realTokenReserves;

    // State flags
    bool public lock; // Locks trading when target is reached
    bool public isListing; // Indicates if token is listed on DEX

    /**
     * @dev Ensures the contract is not locked
     */
    modifier islock() {
        require(!lock, ERR_BONDING_CURVE_LOCKED);
        _;
    }

    /**
     * @dev Restricts function access to core contract only
     */
    modifier onlyCore() {
        require(msg.sender == core, ERR_BONDING_CURVE_ONLY_OWNER);
        _;
    }

    /**
     * @dev Constructor sets immutable factory and core addresses
     * @param _core Address of the core contract
     * @param _wNative Address of the WNATIVE token
     */
    constructor(address _core, address _wNative) {
        factory = msg.sender;
        core = _core;
        wNative = _wNative;
    }

    /**
     * @notice Initializes the bonding curve with its parameters
     * @dev Called once by factory during deployment
     * @param _token Project token address
     * @param _virtualNative Initial virtual Native reserve
     * @param _virtualToken Initial virtual token reserve
     * @param _k Constant product parameter
     * @param _targetToken Target token amount for DEX listing
     * @param _feeDenominator Fee denominator
     * @param _feeNumerator Fee numerator
     */
    function initialize(
        address _token,
        uint256 _virtualNative,
        uint256 _virtualToken,
        uint256 _k,
        uint256 _targetToken,
        uint8 _feeDenominator,
        uint16 _feeNumerator
    ) external {
        require(msg.sender == factory, ERR_BONDING_CURVE_ONLY_FACTORY);
        token = _token;
        virtualNative = _virtualNative;
        virtualToken = _virtualToken;
        k = _k;
        realNativeReserves = IERC20(wNative).balanceOf(address(this));
        realTokenReserves = IERC20(_token).balanceOf(address(this));
        targetToken = _targetToken;
        feeConfig = Fee(_feeDenominator, _feeNumerator);
        isListing = false;
    }

    /**
     * @notice Executes a buy order on the bonding curve
     * @dev Transfers tokens and updates reserves accordingly
     * @param to Recipient address
     * @param amountOut Amount of tokens to buy
     */
    function buy(address to, uint256 amountOut) external islock onlyCore {
        require(amountOut > 0, ERR_BONDING_CURVE_INVALID_AMOUNT_OUT);
        address _wNative = wNative; //gas savings
        address _token = token; //gas savings

        (
            uint256 _realNativeReserves,
            uint256 _realTokenReserves
        ) = getReserves();

        // Ensure remaining tokens stay above target
        require(
            _realTokenReserves - amountOut >= targetToken,
            ERR_BONDING_CURVE_OVERFLOW_TARGET
        );

        uint256 balanceNative;

        {
            require(
                to != _wNative && to != _token,
                ERR_BONDING_CURVE_INVALID_TO
            );
            IERC20(_token).safeTransferERC20(core, amountOut);

            balanceNative = IERC20(wNative).balanceOf(address(this));
        }

        uint256 amountNativeIn = balanceNative - _realNativeReserves;
        emit Buy(to, token, amountNativeIn, amountOut);
        _update(amountNativeIn, amountOut, true);
        require(virtualNative * virtualToken >= k, ERR_BONDING_CURVE_INVALID_K);
    }

    /**
     * @notice Executes a sell order on the bonding curve
     * @dev Transfers tokens and updates reserves accordingly
     * @param to Recipient address
     * @param amountOut Amount of native to receive
     */
    function sell(address to, uint256 amountOut) external islock onlyCore {
        require(amountOut > 0, ERR_BONDING_CURVE_INVALID_AMOUNT_OUT);

        address _wNative = wNative;
        address _token = token;
        (
            uint256 _realNativeReserves,
            uint256 _realTokenReserves
        ) = getReserves();
        require(
            amountOut <= _realNativeReserves,
            ERR_BONDING_CURVE_INVALID_AMOUNT_OUT
        );

        uint256 balanceToken;

        {
            require(
                to != _wNative && to != _token,
                ERR_BONDING_CURVE_INVALID_TO
            );
            IERC20(_wNative).safeTransferERC20(core, amountOut);
            balanceToken = IERC20(_token).balanceOf(address(this));
        }

        uint256 amountTokenIn = balanceToken - _realTokenReserves;

        require(amountTokenIn > 0, ERR_BONDING_CURVE_INVALID_AMOUNT_IN);
        emit Sell(to, token, amountTokenIn, amountOut);
        _update(amountTokenIn, amountOut, false);
        require(virtualNative * virtualToken >= k, ERR_BONDING_CURVE_INVALID_K);
    }

    /**
     * @notice Lists the token on Uniswap after reaching target
     * @dev Creates trading pair and provides initial liquidity

     */
    function listing() external returns (address) {
        require(lock == true, ERR_BONDING_CURVE_ONLY_LOCK);
        require(!isListing, ERR_BONDING_CURVE_ALREADY_LISTED);
        IBondingCurveFactory _factory = IBondingCurveFactory(factory);
        pair = IUniswapV2Factory(_factory.getDexFactory()).createPair(
            wNative,
            token
        );

        // Transfer listing fee to fee vault
        IERC20(wNative).transfer(
            ICore(_factory.getCore()).getFeeVault(),
            _factory.getListingFee()
        );

        // Transfer remaining tokens to the pair
        uint256 listingNativeAmount = IERC20(wNative).balanceOf(address(this));
        IERC20(wNative).transfer(pair, listingNativeAmount);
        uint256 listingTokenAmount = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(pair, listingTokenAmount);

        // Reset reserves and provide liquidity
        realNativeReserves = 0;
        realTokenReserves = 0;
        uint256 liquidity = IUniswapV2Pair(pair).mint(address(this));

        isListing = true;
        emit Listing(
            address(this),
            token,
            pair,
            listingNativeAmount,
            listingTokenAmount,
            liquidity
        );
        return pair;
    }

    /**
     * @dev Burns liquidity tokens by sending them to the zero address
     * @notice This function can only be called after listing is completed
     * @notice Sends all liquidity tokens held by this contract to address(0)
     */
    function burnLiquidity() external {
        // Verify that the bonding curve has been listed on Uniswap
        require(isListing, ERR_BONDING_CURVE_MUST_LISTING);

        // Get the current LP token balance of this contract
        uint liquidity = IUniswapV2ERC20(pair).balanceOf(address(this));

        // Burn the LP tokens by transferring them to the zero address
        IUniswapV2ERC20(pair).transfer(address(0), liquidity);

        // Emit event to log the burning of LP tokens
        emit BurnLiquidity(pair, liquidity);
    }

    /**
     * @dev Updates virtual and real reserves after trades
     * @param amountIn Amount of tokens coming in
     * @param amountOut Amount of tokens going out
     * @param isBuy Whether this update is for a buy order
     */
    function _update(uint256 amountIn, uint256 amountOut, bool isBuy) private {
        realNativeReserves = IERC20(wNative).balanceOf(address(this));
        realTokenReserves = IERC20(token).balanceOf(address(this));

        if (isBuy) {
            virtualNative += amountIn;
            virtualToken -= amountOut;
        } else {
            virtualNative -= amountOut;
            virtualToken += amountIn;
        }

        emit Sync(
            token,
            realNativeReserves,
            realTokenReserves,
            virtualNative,
            virtualToken
        );
        // Lock trading if target is reached
        if (realTokenReserves == getTargetToken()) {
            lock = true;
            emit Lock(token);
        }
    }

    // View functions

    /**
     * @notice Gets the current real token reserves
     * @return nativeReserves The current real Native reserves
     * @return tokenReserves The current real token reserves
     */
    function getReserves()
        public
        view
        override
        returns (uint256 nativeReserves, uint256 tokenReserves)
    {
        nativeReserves = realNativeReserves;
        tokenReserves = realTokenReserves;
    }

    /**
     * @notice Gets the current virtual reserves
     * @return virtualNativeReserve The current virtual Native reserves
     * @return virtualTokenReserve The current virtual token reserves
     */
    function getVirtualReserves()
        public
        view
        override
        returns (uint256 virtualNativeReserve, uint256 virtualTokenReserve)
    {
        virtualNativeReserve = virtualNative;
        virtualTokenReserve = virtualToken;
    }

    /**
     * @notice Gets the current fee configuration
     * @return denominator The fee denominator
     * @return numerator The fee numerator
     */
    function getFee()
        public
        view
        returns (uint8 denominator, uint16 numerator)
    {
        Fee memory fee = feeConfig;
        denominator = fee.denominator;
        numerator = fee.numerator;
    }

    function getFeeConfig()
        external
        view
        returns (uint8 denominator, uint16 numerator)
    {
        Fee memory fee = feeConfig;
        denominator = fee.denominator;
        numerator = fee.numerator;
    }

    /**
     * @notice Gets the constant product parameter
     */
    function getK() external view override returns (uint256) {
        return k;
    }

    /**
     * @notice Gets the target token amount for listing
     */
    function getTargetToken() public view returns (uint256) {
        return targetToken;
    }

    /**
     * @notice Checks if trading is locked
     */
    function getLock() public view returns (bool) {
        return lock;
    }

    /**
     * @notice Checks if token is listed on DEX
     */
    function getIsListing() public view returns (bool) {
        return isListing;
    }
}
