// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IToken} from "./interfaces/IToken.sol";
import {ICore} from "./interfaces/ICore.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2ERC20} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2ERC20.sol";

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/UniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/UniswapV3Pool.sol";

import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import {BondingCurveLibrary} from "./utils/BondingCurveLibrary.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./errors/Errors.sol";

/**
 * @title BondingCurve
 * @dev Implementation of a bonding curve for token price discovery
 * Manages the relationship between Native and project tokens using a constant product formula
 */
contract BondingCurve is IBondingCurve {
    using SafeERC20 for IERC20;
    using Math for uint256;
    // Immutable state variables

    address immutable factory;
    address immutable core;
    address public immutable wNative; // Wrapped Native token address
    address public token; // Project token address
    address public pool;
    // Virtual reserves for price calculation
    uint256 private virtualNative; // Virtual Native reserve
    uint256 private virtualToken; // Virtual token reserve
    uint256 private k; // Constant product parameter
    uint256 private targetToken; // Target token amount for listing
    uint256 constant Q96 = 2 ** 96;
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

        (uint256 _realNativeReserves, uint256 _realTokenReserves) = getReserves();

        // Ensure remaining tokens stay above target
        require(_realTokenReserves - amountOut >= targetToken, ERR_BONDING_CURVE_OVERFLOW_TARGET);

        uint256 balanceNative;

        {
            require(to != _wNative && to != _token, ERR_BONDING_CURVE_INVALID_TO);
            IERC20(_token).safeTransfer(core, amountOut);

            balanceNative = IERC20(wNative).balanceOf(address(this));
        }

        uint256 amountNativeIn = balanceNative - _realNativeReserves;
        _update(amountNativeIn, amountOut, true);
        require(virtualNative * virtualToken >= k, ERR_BONDING_CURVE_INVALID_K);
        emit Buy(to, token, amountNativeIn, amountOut);
        _checkTarget();
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
        (uint256 _realNativeReserves, uint256 _realTokenReserves) = getReserves();
        require(amountOut <= _realNativeReserves, ERR_BONDING_CURVE_INVALID_AMOUNT_OUT);

        uint256 balanceToken;

        {
            require(to != _wNative && to != _token, ERR_BONDING_CURVE_INVALID_TO);
            IERC20(_wNative).safeTransfer(core, amountOut);
            balanceToken = IERC20(_token).balanceOf(address(this));
        }

        uint256 amountTokenIn = balanceToken - _realTokenReserves;

        require(amountTokenIn > 0, ERR_BONDING_CURVE_INVALID_AMOUNT_IN);
        _update(amountTokenIn, amountOut, false);
        require(virtualNative * virtualToken >= k, ERR_BONDING_CURVE_INVALID_K);
        emit Sell(to, token, amountTokenIn, amountOut);
        _checkTarget();
    }

    // /**
    //  * @notice Lists the token on Uniswap after reaching target
    //  * @dev Creates trading pair and provides initial liquidity
    //  */
    // function listing() external returns (address) {
    //     require(lock == true, ERR_BONDING_CURVE_ONLY_LOCK);
    //     require(!isListing, ERR_BONDING_CURVE_ALREADY_LISTED);
    //     IBondingCurveFactory _factory = IBondingCurveFactory(factory);
    //     pair = IUniswapV2Factory(_factory.getDexFactory()).createPair(wNative, token);
    //     uint256 listingFee = _factory.getListingFee();
    //     //send Listing Fee

    //     // Transfer remaining tokens to the pair
    //     uint256 burnTokenAmount;
    //     {
    //         burnTokenAmount = realTokenReserves - ((realNativeReserves - listingFee) * virtualToken) / virtualNative;
    //         IToken(token).burn(burnTokenAmount);
    //         IERC20(wNative).safeTransfer(ICore(_factory.getCore()).getFeeVault(), listingFee);
    //     }

    //     uint256 listingNativeAmount = IERC20(wNative).balanceOf(address(this));
    //     uint256 listingTokenAmount = IERC20(token).balanceOf(address(this));
    //     IERC20(wNative).transfer(pair, listingNativeAmount);
    //     IERC20(token).transfer(pair, listingTokenAmount);

    //     // Reset reserves and provide liquidity
    //     realNativeReserves = 0;
    //     realTokenReserves = 0;
    //     uint256 liquidity = IUniswapV2Pair(pair).mint(address(this));

    //     IUniswapV2ERC20(pair).transfer(address(0), liquidity);
    //     isListing = true;
    //     emit Listing(address(this), token, pair, listingNativeAmount, listingTokenAmount, liquidity);
    //     return pair;
    // }

    /**
     * @notice Executes the listing on Uniswap V3.
     * @dev 기존 v2 listing()의 burnTokenAmount 등 비즈니스 로직은 그대로 유지하면서,
     *      Uniswap V3 풀 생성, 초기화, full range liquidity mint까지 수행.
     */
    function listing() external returns (address) {
        require(lock == true, ERR_BONDING_CURVE_ONLY_LOCK);
        require(!isListing, ERR_BONDING_CURVE_ALREADY_LISTED);

        IBondingCurveFactory _factory = IBondingCurveFactory(factory);
        // 1. Uniswap V3 풀 생성 (wNative, token, 지정된 poolFee 사용)
        IUniswapV3Pool _pool =
            IUniswapV3Pool(IUniswapV3Factory(_factory.getDexFactory()).createPool(wNative, token, poolFee));
        pool = address(_pool);
        require(address(_pool) != address(0), "Pool creation failed");

        // 2. Listing fee 처리 및 기존 v2 로직: burnTokenAmount 계산 등 (변경 없음)
        uint256 listingFee = _factory.getListingFee();
        uint256 burnTokenAmount = realTokenReserves - ((realNativeReserves - listingFee) * virtualToken) / virtualNative;
        IToken(token).burn(burnTokenAmount);
        IERC20(wNative).safeTransfer(ICore(_factory.getCore()).getFeeVault(), listingFee);

        // 3. 현재 컨트랙트 보유 잔액 확인
        uint256 nativeBalance = IERC20(wNative).balanceOf(address(this));
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        require(nativeBalance > 0, "Insufficient WNATIVE balance");
        require(tokenBalance > 0, "Insufficient token balance");

        // 4. 초기 가격 계산
        // Uniswap V3 풀은 토큰 순서에 따라 token0, token1이 정해지므로, wNative < token인 경우:
        // price = tokenBalance / nativeBalance  → √price = sqrt(tokenBalance/nativeBalance)
        uint160 sqrtPriceX96;
        if (wNative < token) {
            // sqrtPriceX96 = sqrt( (tokenBalance / nativeBalance) ) * Q96
            // 이를 위해 tokenBalance * Q96^2 / nativeBalance의 제곱근을 구함.
            sqrtPriceX96 = uint160(Math.sqrt((tokenBalance * (Q96 * Q96)) / nativeBalance));
        } else {
            sqrtPriceX96 = uint160(Math.sqrt((nativeBalance * (Q96 * Q96)) / tokenBalance));
        }

        // 5. 풀 초기화: 초기 √PriceX96 설정
        _pool.initialize(sqrtPriceX96);

        // 6. 제공할 liquidity 계산 (full range: tickLower = type(int24).min, tickUpper = type(int24).max)
        uint128 liquidityDesired;
        uint256 liquidity0;
        uint256 liquidity1;
        if (wNative < token) {
            // token0 = wNative, token1 = token
            liquidity0 = (nativeBalance * Q96) / sqrtPriceX96;
            liquidity1 = (tokenBalance * sqrtPriceX96) / Q96;
        } else {
            // token0 = token, token1 = wNative
            liquidity0 = (tokenBalance * Q96) / sqrtPriceX96;
            liquidity1 = (nativeBalance * sqrtPriceX96) / Q96;
        }
        liquidityDesired = uint128(liquidity0 < liquidity1 ? liquidity0 : liquidity1);

        // 7. Liquidity mint: full range liquidity 추가
        //    mint() 호출 시, Uniswap V3 풀은 uniswapV3MintCallback을 호출하여 필요한 토큰 전송을 요청함.
        //mint 의 address(this)는 추후 스테이킹 컨트랙트에 주기
        (uint256 amount0Mint, uint256 amount1Mint) =
            _pool.mint(address(this), type(int24).min, type(int24).max, liquidityDesired, "");
        bytes32 memory position = keccak256(abi.encodePacked(address(this), type(int24).min, type(int24).max));
        (uint128 liquidity,,,,) = _pool.positions(position);

        // 8. 상태 업데이트 및 이벤트 기록
        isListing = true;
        realNativeReserves = 0;
        realTokenReserves = 0;
        pool = pool;
        emit Listing(msg.sender, token, pool, nativeBalance, tokenBalance, position, liquidity);
        return pool;
    }

    /**
     * @notice Uniswap V3 mint callback.
     * @dev Called by the pool during mint; transfers owed tokens.
     */
    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata) external {
        require(msg.sender == pool, "CB");

        // wNative가 token0인 경우
        if (wNative < token) {
            IERC20(wNative).safeTransfer(msg.sender, amount0Owed);
            IERC20(token).safeTransfer(msg.sender, amount1Owed);
        } else {
            IERC20(token).safeTransfer(msg.sender, amount0Owed);
            IERC20(wNative).safeTransfer(msg.sender, amount1Owed);
        }
    }
    /**
     * @notice Uniswap V3 mint callback 함수
     * - mint() 호출 후 풀에서 필요한 토큰을 요청할 때 호출됨
     * @param amount0Owed 토큰0로 지급해야 할 금액
     * @param amount1Owed 토큰1로 지급해야 할 금액
     * @param data 추가 데이터 (여기선 사용하지 않음)
     */

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external {
        // 실제 배포시 msg.sender가 올바른 풀인지 확인하는 로직 필요합니다.
        // 여기서는 단순화하여 조건에 따라 토큰 전송합니다.
        if (wNative < token) {
            if (amount0Owed > 0) {
                IERC20(wNative).safeTransfer(msg.sender, amount0Owed);
            }
            if (amount1Owed > 0) {
                IERC20(token).safeTransfer(msg.sender, amount1Owed);
            }
        } else {
            if (amount0Owed > 0) {
                IERC20(token).safeTransfer(msg.sender, amount0Owed);
            }
            if (amount1Owed > 0) {
                IERC20(wNative).safeTransfer(msg.sender, amount1Owed);
            }
        }
    }
    // /**
    //  * @dev Burns liquidity tokens by sending them to the zero address
    //  * @notice This function can only be called after listing is completed
    //  * @notice Sends all liquidity tokens held by this contract to address(0)
    //  */
    // function burnLiquidity() external {
    //     // Verify that the bonding curve has been listed on Uniswap
    //     require(isListing, ERR_BONDING_CURVE_MUST_LISTING);

    //     // Get the current LP token balance of this contract
    //     uint liquidity = IUniswapV2ERC20(pair).balanceOf(address(this));

    //     // Burn the LP tokens by transferring them to the zero address

    //     // Emit event to log the burning of LP tokens
    //     emit BurnLiquidity(pair, liquidity);
    // }

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

        emit Sync(token, realNativeReserves, realTokenReserves, virtualNative, virtualToken);
    }

    function _checkTarget() private {
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
    function getReserves() public view override returns (uint256 nativeReserves, uint256 tokenReserves) {
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
    function getFee() public view returns (uint8 denominator, uint16 numerator) {
        Fee memory fee = feeConfig;
        denominator = fee.denominator;
        numerator = fee.numerator;
    }

    function getFeeConfig() external view returns (uint8 denominator, uint16 numerator) {
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
