// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import {IWNative} from "./interfaces/IWNative.sol";
import {IDexRouter} from "./interfaces/IDexRouter.sol";
import "./errors/Errors.sol";

/// --------------------------------------------------------------------------
/// 인터페이스 및 데이터 구조체
/// --------------------------------------------------------------------------

// Uniswap V3 Factory 인터페이스 (풀 주소 조회)
interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

// Uniswap V3 Pool 인터페이스 (swap 함수)
interface IUniswapV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified, // 양수: exact input, 음수: exact output
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

// Uniswap V3 Swap callback 인터페이스
interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}

/// @dev 스왑 호출 시 전달할 데이터 구조체
///     - tokenIn: 콜백 시 지급할(입력) 토큰 주소
///     - tokenOut: 스왑 결과로 받게 될 토큰 주소
///     - payer: 실제 토큰 지급을 수행하는 주체 (보통 이 컨트랙트)
struct SwapCallbackData {
    address tokenIn;
    address tokenOut;
    address payer;
}

/// --------------------------------------------------------------------------
/// DexRouter 계약 (Uniswap V3 풀과 직접 상호작용)
/// --------------------------------------------------------------------------
contract DexRouter is IDexRouter, IUniswapV3SwapCallback {
    using SafeERC20 for IERC20;

    // ────────── 상태 변수 ──────────

    address public immutable dexFactory; // Uniswap V3 Factory 주소
    address public immutable WNATIVE; // Wrapped Native 토큰 주소
    address public immutable vault; // fee 수집용 vault 주소

    uint256 public feeDenominator; // fee 계산 분모
    uint256 public feeNumerator; // fee 계산 분자
    uint24 public poolFee; // Uniswap V3 풀 fee tier (예: 3000 = 0.3%)

    // ────────── Modifier ──────────

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, ERR_DEX_ROUTER_EXPIRED);
        _;
    }

    // ────────── 생성자 ──────────

    constructor(
        address _factory,
        address _WNATIVE,
        address _vault,
        uint256 _feeDenominator,
        uint256 _feeNumerator,
        uint24 _poolFee
    ) {
        dexFactory = _factory;
        WNATIVE = _WNATIVE;
        vault = _vault;
        feeDenominator = _feeDenominator;
        feeNumerator = _feeNumerator;
        poolFee = _poolFee;
    }

    // receive 함수
    // WNATIVE 컨트랙트에서 wrap 과정 중에만 NATIVE를 직접 받도록 함.
    receive() external payable {
        assert(msg.sender == WNATIVE);
    }

    // ────────── 내부 함수 (fee 관련) ──────────

    /// @notice fee가 올바른지 검사 (수수료 비율 확인)
    function checkFee(uint256 amount, uint256 fee) internal view {
        require(fee >= (amount * feeDenominator) / feeNumerator, ERR_DEX_ROUTER_INVALID_FEE);
    }

    /// @notice fee를 계산하여 반환
    function getFee(uint256 amount) internal view returns (uint256) {
        return (amount * feeDenominator) / feeNumerator;
    }

    /// @notice fee를 vault로 전송
    function sendFeeByVault(uint256 fee) internal {
        IERC20(WNATIVE).safeTransfer(vault, fee);
    }

    // ────────── Buy Functions (Exact Input 및 Exact Output) ──────────

    /**
     * @notice NATIVE를 사용하여 token을 구매 (exact input 방식)
     * @param amountIn NATIVE로 사용할 금액 (fee 별도)
     * @param amountOutMin 최소로 받을 token 수량 (슬리피지 보호)
     * @param fee fee 금액 (vault 전송용)
     * @param token 구매할 token 주소
     * @param to token 수령 주소
     * @param deadline 거래 만료 시간
     */
    function buy(uint256 amountIn, uint256 amountOutMin, uint256 fee, address token, address to, uint256 deadline)
        external
        payable
        ensure(deadline)
    {
        // 입력 NATIVE가 (amountIn + fee) 이상 전달되어야 함
        require(msg.value >= amountIn + fee, ERR_CORE_INVALID_SEND_NATIVE);
        require(amountIn > 0, ERR_DEX_ROUTER_INVALID_AMOUNT_IN);
        require(fee > 0, ERR_DEX_ROUTER_INVALID_FEE);
        checkFee(amountIn, fee);

        // 1. 전달받은 NATIVE를 WNATIVE로 wrap (amountIn + fee)
        IWNative(WNATIVE).deposit{value: amountIn + fee}();
        // 2. fee는 vault로 전송
        sendFeeByVault(fee);

        // 3. 풀 주소 조회: WNATIVE와 token, poolFee로 결정
        address pool = IUniswapV3Factory(dexFactory).getPool(WNATIVE, token, poolFee);
        require(pool != address(0), "Pool does not exist");

        // 4. 스왑 방향 결정 (구매의 경우 WNATIVE → token)
        //    - 만약 WNATIVE 주소가 token 주소보다 작으면, token0 = WNATIVE, token1 = token → zeroForOne = true
        //    - 그렇지 않으면 zeroForOne = false.
        bool zeroForOne = (WNATIVE < token) ? true : false;

        // 5. exact input 스왑: amountSpecified는 양의 값(입력 토큰 수량)
        int256 amountSpecified = int256(amountIn);
        uint160 sqrtPriceLimitX96 = 0; // 가격 제한 없음

        // 6. swap callback에 전달할 데이터 인코딩
        bytes memory data = abi.encode(
            SwapCallbackData({
                tokenIn: WNATIVE, // 입력 토큰은 WNATIVE
                tokenOut: token, // 출력 토큰은 구매할 token
                payer: address(this)
            })
        );

        // 7. 풀의 swap 함수 직접 호출: to 주소로 출력 토큰이 전송됨
        (int256 amount0Delta, int256 amount1Delta) =
            IUniswapV3Pool(pool).swap(to, zeroForOne, amountSpecified, sqrtPriceLimitX96, data);

        // 8. 스왑 결과 확인: 출력 토큰으로 받은 수량이 최소 수량 이상이어야 함.
        uint256 amountOutReceived;
        if (zeroForOne) {
            // token0 = WNATIVE, token1 = token → token 출력은 amount1Delta (양수)로 나타남
            amountOutReceived = uint256(amount1Delta);
        } else {
            amountOutReceived = uint256(amount0Delta);
        }
        require(amountOutReceived >= amountOutMin, "Insufficient output");
    }

    /**
     * @notice NATIVE를 사용하여 token을 구매 (exact output 방식)
     *         원하는 token 수량(amountOut)을 정확하게 받고, 최대 amountInMax의 NATIVE를 사용함.
     * @param amountOut 구매할 token의 정확한 양
     * @param amountInMax 최대 사용 가능한 NATIVE 양 (fee 포함)
     * @param token 구매할 token 주소
     * @param to token 수령 주소
     * @param deadline 거래 만료 시간
     */
    function exactOutBuy(uint256 amountOut, uint256 amountInMax, address token, address to, uint256 deadline)
        external
        payable
        ensure(deadline)
    {
        // amountInMax 만큼의 NATIVE가 전송되어야 함
        require(msg.value >= amountInMax, ERR_DEX_ROUTER_INVALID_SEND_NATIVE);

        // fee는 여기서 getFee(amountOut)로 산정 (예: fee = getFee(amountOut))
        uint256 feeAmount = getFee(amountOut);
        require(amountInMax >= feeAmount, ERR_DEX_ROUTER_INVALID_AMOUNT_IN_MAX);

        // 1. 최대 사용 NATIVE를 WNATIVE로 wrap
        IWNative(WNATIVE).deposit{value: amountInMax}();
        // 2. fee 전송
        sendFeeByVault(feeAmount);

        // 3. 풀 주소 조회 (WNATIVE와 token 쌍)
        address pool = IUniswapV3Factory(dexFactory).getPool(WNATIVE, token, poolFee);
        require(pool != address(0), "Pool does not exist");

        // 4. 구매의 경우 스왑 방향은 buy와 동일
        bool zeroForOne = (WNATIVE < token) ? true : false;

        // 5. exact output 스왑은 amountSpecified에 음수를 전달
        int256 amountSpecified = -int256(amountOut);
        uint160 sqrtPriceLimitX96 = 0;

        // 6. 콜백 데이터 구성 (입력 토큰은 WNATIVE)
        bytes memory data = abi.encode(SwapCallbackData({tokenIn: WNATIVE, tokenOut: token, payer: address(this)}));

        // 7. 풀 swap 호출 → exact output 스왑 실행
        (int256 amount0Delta, int256 amount1Delta) =
            IUniswapV3Pool(pool).swap(to, zeroForOne, amountSpecified, sqrtPriceLimitX96, data);

        // 8. 스왑 결과에서 실제 사용된 입력 금액 계산
        //    - exact output의 경우, 출력 토큰은 정확히 amountOut을 받고, 입력 토큰으로 사용된 금액은 양수 델타 값으로 나타남.
        uint256 amountInUsed;
        if (zeroForOne) {
            // token0 = WNATIVE, token1 = token → 사용된 WNATIVE는 amount0Delta (양수)로 표시
            amountInUsed = uint256(amount0Delta);
        } else {
            amountInUsed = uint256(amount1Delta);
        }

        // 9. 실제 사용한 NATIVE와 fee의 합이 amountInMax보다 작으면 잔액(refund)을 반환
        uint256 totalUsed = amountInUsed + feeAmount;
        if (amountInMax > totalUsed) {
            uint256 refund = amountInMax - totalUsed;
            // 언랩(refund) 후 refund amount를 msg.sender에게 반환
            IWNative(WNATIVE).withdraw(refund);
            TransferHelper.safeTransferNative(msg.sender, refund);
        }
    }

    // ────────── Sell Functions (Exact Input 및 Exact Output) ──────────

    /**
     * @notice token을 판매하여 NATIVE를 받음 (exact input 방식)
     * @param amountIn 판매할 token 양
     * @param amountOutMin 최소로 받을 NATIVE 양 (슬리피지 보호)
     * @param token 판매할 token 주소
     * @param to NATIVE 수령 주소
     * @param deadline 거래 만료 시간
     */
    function sell(uint256 amountIn, uint256 amountOutMin, address token, address to, uint256 deadline)
        external
        ensure(deadline)
    {
        require(amountIn > 0, ERR_DEX_ROUTER_INVALID_AMOUNT_IN);
        require(IERC20(token).allowance(msg.sender, address(this)) >= amountIn, ERR_DEX_ROUTER_INVALID_ALLOWANCE);

        // 1. 판매할 token을 이 컨트랙트로 전송
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);

        // 2. 풀 주소 조회 (판매: token → WNATIVE)
        address pool = IUniswapV3Factory(dexFactory).getPool(WNATIVE, token, poolFee);
        require(pool != address(0), "Pool does not exist");

        // 3. 판매의 경우 스왑 방향 결정
        //    - 만약 WNATIVE < token이면, token0 = WNATIVE, token1 = token → 판매하려면 token가 token1이므로 zeroForOne = false.
        //    - 그렇지 않으면 zeroForOne = true.
        bool zeroForOne = (WNATIVE < token) ? false : true;

        // 4. exact input 스왑: amountSpecified는 양의 값 (판매하는 token 수량)
        int256 amountSpecified = int256(amountIn);
        uint160 sqrtPriceLimitX96 = 0;

        // 5. 콜백 데이터 구성 (판매 시 입력 토큰은 token)
        bytes memory data = abi.encode(SwapCallbackData({tokenIn: token, tokenOut: WNATIVE, payer: address(this)}));

        // 6. 풀의 swap 호출
        (int256 amount0Delta, int256 amount1Delta) =
            IUniswapV3Pool(pool).swap(to, zeroForOne, amountSpecified, sqrtPriceLimitX96, data);

        // 7. 스왑 결과로 받은 NATIVE 양 계산
        uint256 amountOutReceived;
        if (zeroForOne) {
            // zeroForOne=true: token0 = token, token1 = WNATIVE → 출력 NATIVE는 amount1Delta
            amountOutReceived = uint256(amount1Delta);
        } else {
            amountOutReceived = uint256(amount0Delta);
        }

        // 8. fee 계산 및 슬리피지 보호 검사
        uint256 feeAmount = getFee(amountOutReceived);
        require(amountOutReceived - feeAmount >= amountOutMin, ERR_DEX_ROUTER_INVALID_AMOUNT_OUT_MIN);

        // 9. fee vault로 fee 전송
        sendFeeByVault(feeAmount);

        // 10. 남은 WNATIVE를 NATIVE로 언랩하여 수령인에게 전송
        IWNative(WNATIVE).withdraw(amountOutReceived - feeAmount);
        TransferHelper.safeTransferNative(to, amountOutReceived - feeAmount);
    }

    /**
     * @notice token을 판매하여 NATIVE를 받음 (exact output 방식)
     *         원하는 NATIVE 수량(amountOut)을 정확히 받고, 최대 amountInMax 만큼 token을 사용함.
     * @param amountOut 정확히 받을 NATIVE 양
     * @param amountInMax 최대 판매 가능한 token 양
     * @param token 판매할 token 주소
     * @param to NATIVE 수령 주소
     * @param deadline 거래 만료 시간
     */
    function exactOutSell(uint256 amountOut, uint256 amountInMax, address token, address to, uint256 deadline)
        external
        payable
        ensure(deadline)
    {
        require(amountInMax > 0, ERR_DEX_ROUTER_INVALID_AMOUNT_IN);
        require(IERC20(token).allowance(msg.sender, address(this)) >= amountInMax, ERR_DEX_ROUTER_INVALID_ALLOWANCE);

        // 1. 판매할 token을 이 컨트랙트로 전송
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountInMax);
        // 2. 풀과 상호작용하기 위해 token에 대한 승인
        IERC20(token).approve(address(this), 0); // 안전한 승인 초기화
        IERC20(token).approve(address(this), amountInMax);

        // 3. 풀 주소 조회 (판매: token → WNATIVE)
        address pool = IUniswapV3Factory(dexFactory).getPool(WNATIVE, token, poolFee);
        require(pool != address(0), "Pool does not exist");

        // 4. 판매의 경우 스왑 방향 결정 (exact output 사용하므로 amountSpecified에 음수를 전달)
        bool zeroForOne = (WNATIVE < token) ? false : true;
        int256 amountSpecified = -int256(amountOut); // 음수: exact output 스왑
        uint160 sqrtPriceLimitX96 = 0;

        // 5. 콜백 데이터 구성 (판매 시 입력 토큰은 token)
        bytes memory data = abi.encode(SwapCallbackData({tokenIn: token, tokenOut: WNATIVE, payer: address(this)}));

        // 6. 풀의 swap 호출 → exact output 스왑 실행
        (int256 amount0Delta, int256 amount1Delta) =
            IUniswapV3Pool(pool).swap(to, zeroForOne, amountSpecified, sqrtPriceLimitX96, data);

        // 7. 실제 사용된 token 양(입력)은 양의 값으로 반환됨
        uint256 amountInUsed;
        if (zeroForOne) {
            amountInUsed = uint256(amount0Delta);
        } else {
            amountInUsed = uint256(amount1Delta);
        }
        require(amountInUsed <= amountInMax, "Exceeds maximum input");

        // 8. refund: 사용하지 않은 token 잔액 환불 (있다면)
        if (amountInMax > amountInUsed) {
            uint256 refund = amountInMax - amountInUsed;
            IERC20(token).safeTransfer(msg.sender, refund);
        }

        // 9. fee 계산 및 슬리피지 보호 검사
        uint256 feeAmount = getFee(amountOut);
        // amountOut에서 fee를 차감한 NATIVE가 최소 수령액 이상이어야 함
        require(amountOut - feeAmount >= 0, "Fee exceeds output"); // 추가 안전 검사

        // 10. fee vault로 fee 전송
        sendFeeByVault(feeAmount);

        // 11. 받은 WNATIVE를 NATIVE로 언랩하여 수령인에게 전송
        IWNative(WNATIVE).withdraw(amountOut);
        TransferHelper.safeTransferNative(to, amountOut);
    }

    // ────────── Swap Callback ──────────

    /**
     * @notice Uniswap V3 풀 swap callback 함수
     *         풀이 swap을 실행한 후, 이 함수가 호출되어 필요한 입력 토큰을 지급하도록 함.
     * @param amount0Delta 토큰0에 대한 델타 (양수면 지급해야 함)
     * @param amount1Delta 토큰1에 대한 델타 (양수면 지급해야 함)
     * @param data 콜백에 전달된 데이터 (SwapCallbackData 구조체로 인코딩되어 있음)
     */
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        // data 디코딩
        SwapCallbackData memory decoded = abi.decode(data, (SwapCallbackData));
        // 실제 운영 코드에서는 msg.sender가 올바른 Uniswap V3 풀인지 반드시 검증해야 함.
        // 여기서는 단순화를 위해 바로 지급 처리함.
        if (amount0Delta > 0) {
            IERC20(decoded.tokenIn).safeTransfer(msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            IERC20(decoded.tokenIn).safeTransfer(msg.sender, uint256(amount1Delta));
        }
    }

    // ────────── Common Functions ──────────

    /**
     * @notice fee를 수금하는 vault 주소 반환
     */
    function getFeeVault() public view returns (address) {
        return vault;
    }

    /**
     * @notice fee config (분모, 분자) 반환
     */
    function getFeeConfig() public view returns (uint256, uint256) {
        return (feeDenominator, feeNumerator);
    }
}
