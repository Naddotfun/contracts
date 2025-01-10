// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IUniswapV2Pair} from "./uniswap/interfaces/IUniswapV2Pair.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import {IDexRouter} from "./interfaces/IDexRouter.sol";
import {IWNative} from "./interfaces/IWNative.sol";
import {UniswapV2Library} from "./uniswap/libraries/UniswapV2Library.sol";
import "./errors/Errors.sol";

/**
 * @title Core
 * @notice Core contract for managing bonding curve operations and Native token interactions
 * @dev Handles creation of bonding curves, buying and selling operations with various payment mNativeods
 */
contract DexRouter is IDexRouter {
    using SafeERC20 for IERC20;
    address public immutable dexFactory;
    address public immutable WNATIVE;
    address public immutable vault;

    uint public feeDenominator;
    uint public feeNumerator;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, ERR_DEX_ROUTER_EXPIRED);
        _;
    }

    constructor(
        address _factory,
        address _WNATIVE,
        address _vault,
        uint _feeDenominator,
        uint _feeNumerator
    ) {
        dexFactory = _factory;
        WNATIVE = _WNATIVE;
        vault = _vault;
        feeDenominator = _feeDenominator;
        feeNumerator = _feeNumerator;
    }

    receive() external payable {
        assert(msg.sender == WNATIVE); // only accept NATIVE via fallback from the WNATIVE contract
    }

    function checkFee(uint amount, uint fee) internal view {
        require(
            fee >= (amount * feeDenominator) / feeNumerator,
            ERR_DEX_ROUTER_INVALID_FEE
        );
    }

    function getFee(uint amount) internal view returns (uint) {
        return (amount * feeDenominator) / feeNumerator;
    }

    /**
     * @notice Sends fee to the vault
     * @param fee Amount of fee to send
     */
    function sendFeeByVault(uint256 fee) internal {
        IERC20(WNATIVE).safeTransfer(address(vault), fee);
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        address to,
        address pair
    ) private {
        (address token0, ) = UniswapV2Library.sortTokens(tokenIn, tokenOut);
        IUniswapV2Pair(pair).swap(
            token0 == tokenIn ? 0 : amountOut,
            token0 == tokenIn ? amountOut : 0,
            to,
            new bytes(0)
        );
    }

    //----------------------------Buy Functions ---------------------------------------------------
    /**
     * @notice Buys tokens from a bonding curve
     * @param amountIn Native amount to spend
     * @param fee Fee amount for the transaction
     * @param token Address of the token to buy
     * @param to Address to receive the bought tokens
     * @param deadline Timestamp before which the transaction must be executed
     */
    function buy(
        uint256 amountIn,
        uint256 fee,
        address token,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) {
        require(
            msg.value >= amountIn + fee,
            ERR_DEX_ROUTER_INVALID_SEND_NATIVE
        );
        require(amountIn > 0, ERR_DEX_ROUTER_INVALID_AMOUNT_IN);
        require(fee > 0, ERR_DEX_ROUTER_INVALID_FEE);
        checkFee(amountIn, fee);

        address pair = UniswapV2Library.pairFor(dexFactory, WNATIVE, token);
        (uint reserveNative, uint reserveToken) = UniswapV2Library.getReserves(
            dexFactory,
            WNATIVE,
            token
        );
        uint amountOut = UniswapV2Library.getAmountOut(
            amountIn,
            reserveNative,
            reserveToken
        );

        IWNative(WNATIVE).deposit{value: amountIn + fee}();
        //send Fee
        sendFeeByVault(fee);
        //send Pair
        IERC20(WNATIVE).safeTransfer(pair, amountIn);
        //swap
        _swap(WNATIVE, token, amountOut, to, pair);
    }

    /**
     * @notice Buys tokens with slippage protection
     * @param amountIn Native amount to spend
     * @param amountOutMin Minimum amount of tokens to receive
     * @param fee Fee amount for the transaction
     * @param token Address of the token to buy
     * @param to Address to receive the bought tokens
     * @param deadline Timestamp before which the transaction must be executed
     */
    function protectBuy(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 fee,
        address token,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) {
        require(msg.value >= amountIn + fee, ERR_CORE_INVALID_SEND_NATIVE);
        require(amountIn > 0, ERR_DEX_ROUTER_INVALID_AMOUNT_IN);
        require(fee > 0, ERR_DEX_ROUTER_INVALID_FEE);

        checkFee(amountIn, fee);

        address pair = UniswapV2Library.pairFor(dexFactory, WNATIVE, token);
        (uint reserveNative, uint reserveToken) = UniswapV2Library.getReserves(
            dexFactory,
            WNATIVE,
            token
        );
        uint amountOut = UniswapV2Library.getAmountOut(
            amountIn,
            reserveNative,
            reserveToken
        );
        require(
            amountOut >= amountOutMin,
            ERR_DEX_ROUTER_INVALID_AMOUNT_OUT_MIN
        );
        {
            IWNative(WNATIVE).deposit{value: amountIn + fee}();

            sendFeeByVault(fee);

            IERC20(WNATIVE).safeTransfer(pair, amountIn);
            _swap(WNATIVE, token, amountOut, to, pair);
        }
    }

    /**
     * @notice Buys an exact amount of tokens from a bonding curve
     * @param amountOut Amount of tokens to buy
     * @param amountInMax Maximum Native amount to spend
     * @param token Address of the token to buy
     * @param to Address to receive the bought tokens
     * @param deadline Timestamp before which the transaction must be executed
     */
    function exactOutBuy(
        uint256 amountOut,
        uint256 amountInMax,
        address token,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) {
        require(msg.value >= amountInMax, ERR_DEX_ROUTER_INVALID_SEND_NATIVE);
        address pair = UniswapV2Library.pairFor(dexFactory, WNATIVE, token);
        (uint reserveNative, uint reserveToken) = UniswapV2Library.getReserves(
            dexFactory,
            WNATIVE,
            token
        );
        uint amountIn = UniswapV2Library.getAmountIn(
            amountOut,
            reserveNative,
            reserveToken
        );

        uint fee = getFee(amountIn);
        require(
            amountIn + fee <= amountInMax,
            ERR_DEX_ROUTER_INVALID_AMOUNT_IN_MAX
        );
        {
            IWNative(WNATIVE).deposit{value: amountIn + fee}();
            sendFeeByVault(fee);
            IERC20(WNATIVE).safeTransfer(pair, amountIn);
            _swap(WNATIVE, token, amountOut, to, pair);
            uint256 restValue = amountInMax - (amountIn + fee);
            if (restValue > 0) {
                TransferHelper.safeTransferNative(msg.sender, restValue);
            }
        }
    }

    // //-------------Sell Functions ---------------------------------------------

    /**
     * @notice Market sells tokens at the current bonding curve price. Market orders are executed immediately at the best current price,
     *         without any slippage protection. Use with caution as the execution price may vary from the displayed price.
     * @param amountIn Token amount to market sell
     * @param token Address of the token to sell
     * @param to Address to receive the Native
     * @param deadline Timestamp before which the transaction must be executed
     */
    function sell(
        uint256 amountIn,
        address token,
        address to,
        uint256 deadline
    ) external ensure(deadline) {
        require(amountIn > 0, ERR_DEX_ROUTER_INVALID_AMOUNT_IN);
        require(
            IERC20(token).allowance(msg.sender, address(this)) >= amountIn,
            ERR_DEX_ROUTER_INVALID_ALLOWANCE
        );
        address pair = UniswapV2Library.pairFor(dexFactory, WNATIVE, token);

        (uint reserveNative, uint reserveToken) = UniswapV2Library.getReserves(
            dexFactory,
            WNATIVE,
            token
        );
        uint amountOut = UniswapV2Library.getAmountOut(
            amountIn,
            reserveToken,
            reserveNative
        );
        uint fee = getFee(amountOut);
        {
            //send Pair
            IERC20(token).safeTransferFrom(msg.sender, pair, amountIn);

            //swap
            _swap(token, WNATIVE, amountOut, address(this), pair);

            sendFeeByVault(fee);

            IWNative(WNATIVE).withdraw(amountOut - fee);
            //send Fee

            TransferHelper.safeTransferNative(to, amountOut - fee);
        }
    }

    /**
     * @notice Market sells tokens at the current bonding curve price. with permit
     * @param amountIn Token amount to sell
     * @param token Address of the token to sell
     * @param from Address of the token owner
     * @param to Address to receive the sold tokens
     * @param deadline Timestamp before which the transaction must be executed
     * @param v v parameter of the permit signature
     * @param r r parameter of the permit signature
     * @param s s parameter of the permit signature
     */
    function sellPermit(
        uint256 amountIn,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(token).permit(
            from,
            address(this),
            amountIn,
            deadline,
            v,
            r,
            s
        );
        address pair = UniswapV2Library.pairFor(dexFactory, WNATIVE, token);

        (uint reserveNative, uint reserveToken) = UniswapV2Library.getReserves(
            dexFactory,
            WNATIVE,
            token
        );
        uint amountOut = UniswapV2Library.getAmountOut(
            amountIn,
            reserveToken,
            reserveNative
        );
        uint fee = getFee(amountOut);
        {
            //send Pair
            IERC20(token).safeTransferFrom(msg.sender, pair, amountIn);

            //swap
            _swap(token, WNATIVE, amountOut, address(this), pair);

            IWNative(WNATIVE).withdraw(amountOut);
            //send Fee
            sendFeeByVault(fee);

            TransferHelper.safeTransferNative(to, amountOut - fee);
        }
    }

    /**
     * @notice Sells tokens with slippage protection
     * @param amountIn Token amount to sell
     * @param amountOutMin Minimum amount of Native to receive (slippage protection)
     * @param token Address of the token to sell
     * @param to Address to receive the Native
     * @param deadline Timestamp before which the transaction must be executed
     */
    function protectSell(
        uint256 amountIn,
        uint256 amountOutMin,
        address token,
        address to,
        uint256 deadline
    ) external ensure(deadline) {
        require(amountIn > 0, ERR_DEX_ROUTER_INVALID_AMOUNT_IN);
        require(
            IERC20(token).allowance(msg.sender, address(this)) > amountIn,
            ERR_DEX_ROUTER_INVALID_ALLOWANCE
        );
        address pair = UniswapV2Library.pairFor(dexFactory, WNATIVE, token);

        (uint reserveNative, uint reserveToken) = UniswapV2Library.getReserves(
            dexFactory,
            WNATIVE,
            token
        );
        uint amountOut = UniswapV2Library.getAmountOut(
            amountIn,
            reserveToken,
            reserveNative
        );
        uint fee = getFee(amountOut);
        require(
            amountOut - fee >= amountOutMin,
            ERR_DEX_ROUTER_INVALID_AMOUNT_OUT_MIN
        );
        {
            IERC20(token).safeTransferFrom(msg.sender, pair, amountIn);

            _swap(token, WNATIVE, amountOut, address(this), pair);

            sendFeeByVault(fee);

            IWNative(WNATIVE).withdraw(amountOut - fee);
            //send Fee

            TransferHelper.safeTransferNative(to, amountOut - fee);
        }
    }

    /**
     * @notice Sells tokens with slippage protection with permit
     * @param amountIn Token amount to sell
     * @param amountOutMin Minimum amount of Native to receive
     * @param token Address of the token to sell
     * @param from Address of the token owner
     * @param to Address to receive the sold tokens
     * @param deadline Timestamp before which the transaction must be executed
     * @param v v parameter of the permit signature
     * @param r r parameter of the permit signature
     * @param s s parameter of the permit signature
     */
    function protectSellPermit(
        uint256 amountIn,
        uint256 amountOutMin,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external ensure(deadline) {
        // EIP-2612 permit: approve by signature
        require(amountIn > 0, ERR_CORE_INVALID_AMOUNT_IN);
        IERC20Permit(token).permit(
            from,
            address(this),
            amountIn,
            deadline,
            v,
            r,
            s
        );
        address pair = UniswapV2Library.pairFor(dexFactory, WNATIVE, token);

        (uint reserveNative, uint reserveToken) = UniswapV2Library.getReserves(
            dexFactory,
            WNATIVE,
            token
        );
        uint amountOut = UniswapV2Library.getAmountOut(
            amountIn,
            reserveToken,
            reserveNative
        );
        uint fee = getFee(amountOut);
        require(
            amountOut - fee >= amountOutMin,
            ERR_DEX_ROUTER_INVALID_AMOUNT_OUT_MIN
        );
        {
            IERC20(token).safeTransferFrom(msg.sender, pair, amountIn);

            _swap(token, WNATIVE, amountOut, address(this), pair);

            sendFeeByVault(fee);

            IWNative(WNATIVE).withdraw(amountOut - fee);
            //send Fee

            TransferHelper.safeTransferNative(to, amountOut - fee);
        }
    }

    //amountOut 은 fee + amountOut 이어야함.

    /**
     * @notice Sells tokens for an exact amount of Native on the bonding curve
     * @param amountOut Exact amount of ETH to receive
     * @param amountInMax Maximum token amount willing to sell
     * @param token Address of the token to sell
     * @param to Address to receive the ETH
     * @param deadline Timestamp before which the transaction must be executed
     */
    function exactOutSell(
        uint256 amountOut,
        uint256 amountInMax,
        address token,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) {
        require(amountInMax > 0, ERR_DEX_ROUTER_INVALID_AMOUNT_IN);
        require(
            IERC20(token).allowance(msg.sender, address(this)) > amountInMax,
            ERR_DEX_ROUTER_INVALID_ALLOWANCE
        );
        address pair = UniswapV2Library.pairFor(dexFactory, WNATIVE, token);

        uint256 fee = msg.value;
        checkFee(amountOut, fee);

        (uint reserveNative, uint reserveToken) = UniswapV2Library.getReserves(
            dexFactory,
            WNATIVE,
            token
        );
        uint amountIn = UniswapV2Library.getAmountIn(
            amountOut,
            reserveToken,
            reserveNative
        );

        require(amountIn <= amountInMax, ERR_DEX_ROUTER_INVALID_AMOUNT_IN_MAX);
        {
            IWNative(WNATIVE).deposit{value: fee}();
            sendFeeByVault(fee);

            IERC20(token).safeTransferFrom(msg.sender, pair, amountIn);

            _swap(token, WNATIVE, amountOut, address(this), pair);
            IWNative(WNATIVE).withdraw(amountOut);

            TransferHelper.safeTransferNative(to, amountOut);
        }
    }

    /**
     * @notice Sells tokens for an exact amount of Native on the bonding curve with permit
     * @param amountOut Amount of Native to receive
     * @param amountInMax Maximum token amount to sell
     * @param token Address of the token to sell
     * @param from Address of the token owner
     * @param to Address to receive the sold tokens
     * @param deadline Timestamp before which the transaction must be executed
     * @param v v parameter of the permit signature
     * @param r r parameter of the permit signature
     * @param s s parameter of the permit signature
     */
    function exactOutSellPermit(
        uint256 amountOut,
        uint256 amountInMax,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable ensure(deadline) {
        require(amountInMax > 0, ERR_DEX_ROUTER_INVALID_AMOUNT_IN_MAX);
        IERC20Permit(token).permit(
            from,
            address(this),
            amountInMax,
            deadline,
            v,
            r,
            s
        );
        address pair = UniswapV2Library.pairFor(dexFactory, WNATIVE, token);

        uint256 fee = msg.value;
        checkFee(amountOut, fee);

        (uint reserveNative, uint reserveToken) = UniswapV2Library.getReserves(
            dexFactory,
            WNATIVE,
            token
        );
        uint amountIn = UniswapV2Library.getAmountIn(
            amountOut,
            reserveToken,
            reserveNative
        );

        require(amountIn <= amountInMax, ERR_DEX_ROUTER_INVALID_AMOUNT_IN_MAX);
        {
            IWNative(WNATIVE).deposit{value: fee}();
            sendFeeByVault(fee);

            IERC20(token).safeTransferFrom(msg.sender, pair, amountIn);

            _swap(token, WNATIVE, amountOut, address(this), pair);
            IWNative(WNATIVE).withdraw(amountOut);

            TransferHelper.safeTransferNative(to, amountOut);
        }
    }

    //----------------------------Common Functions ---------------------------------------------------

    // /**
    //  * @notice Gets curve data from the factory
    //  * @param _factory Factory contract address
    //  * @param token Token address
    //  * @return curve Bonding curve address
    //  * @return virtualNative Virtual Native reserve
    //  * @return virtualToken Virtual token reserve
    //  * @return k Constant product value
    //  */
    // function getCurveData(
    //     address _factory,
    //     address token
    // )
    //     public
    //     view
    //     returns (
    //         address curve,
    //         uint256 virtualNative,
    //         uint256 virtualToken,
    //         uint256 k
    //     )
    // {
    //     (curve, virtualNative, virtualToken, k) = BondingCurveLibrary
    //         .getCurveData(_factory, token);
    // }

    // /**
    //  * @notice Gets curve data directly from a curve contract
    //  * @param curve Bonding curve address
    //  * @return virtualNative Virtual Native reserve
    //  * @return virtualToken Virtual token reserve
    //  * @return k Constant product value
    //  */
    // function getCurveData(
    //     address curve
    // )
    //     public
    //     view
    //     returns (uint256 virtualNative, uint256 virtualToken, uint256 k)
    // {
    //     (virtualNative, virtualToken, k) = BondingCurveLibrary.getCurveData(
    //         curve
    //     );
    // }

    // /**
    //  * @notice Calculates the output amount for a given input
    //  * @param amountIn Input amount
    //  * @param k Constant product value
    //  * @param reserveIn Input reserve
    //  * @param reserveOut Output reserve
    //  * @return amountOut Calculated output amount
    //  */
    // function getAmountOut(
    //     uint256 amountIn,
    //     uint256 k,
    //     uint256 reserveIn,
    //     uint256 reserveOut
    // ) public pure returns (uint256 amountOut) {
    //     amountOut = BondingCurveLibrary.getAmountOut(
    //         amountIn,
    //         k,
    //         reserveIn,
    //         reserveOut
    //     );
    // }

    // /**
    //  * @notice Calculates the input amount required for a desired output
    //  * @param amountOut Desired output amount
    //  * @param k Constant product value
    //  * @param reserveIn Input reserve
    //  * @param reserveOut Output reserve
    //  * @return amountIn Required input amount
    //  */
    // function getAmountIn(
    //     uint256 amountOut,
    //     uint256 k,
    //     uint256 reserveIn,
    //     uint256 reserveOut
    // ) public pure returns (uint256 amountIn) {
    //     amountIn = BondingCurveLibrary.getAmountIn(
    //         amountOut,
    //         k,
    //         reserveIn,
    //         reserveOut
    //     );
    // }

    /**
     * @notice Gets the address of the fee collection vault
     * @return Address of the vault
     */
    function getFeeVault() public view returns (address) {
        return address(vault);
    }

    function getFeeConfig() public view returns (uint, uint) {
        return (feeDenominator, feeNumerator);
    }
}
