// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./libraries/UniswapV2Library.sol";
import "../interfaces/IWNative.sol";

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TransferHelper} from "../utils/TransferHelper.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UniswapV2Router is IUniswapV2Router {
    using SafeERC20 for IERC20;

    address public immutable override factory;
    address public immutable override WNATIVE;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");
        _;
    }

    constructor(address _factory, address _WNATIVE) {
        factory = _factory;
        WNATIVE = _WNATIVE;
    }

    receive() external payable {
        assert(msg.sender == WNATIVE); // only accept NATIVE via fallback from the WNATIVE contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (IUniswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IUniswapV2Factory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = UniswapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "UniswapV2Router: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = UniswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "UniswapV2Router: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        IERC20(tokenA).safeTransferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pair, amountB);
        liquidity = IUniswapV2Pair(pair).mint(to);
    }

    function addLiquidityNative(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountNATIVE, uint256 liquidity)
    {
        (amountToken, amountNATIVE) =
            _addLiquidity(token, WNATIVE, amountTokenDesired, msg.value, amountTokenMin, amountNativeMin);
        address pair = UniswapV2Library.pairFor(factory, token, WNATIVE);
        IERC20(token).safeTransferFrom(msg.sender, pair, amountToken);
        IWNative(WNATIVE).deposit{value: amountNATIVE}();
        assert(IWNative(WNATIVE).transfer(pair, amountNATIVE));
        liquidity = IUniswapV2Pair(pair).mint(to);
        // refund dust native, if any
        if (msg.value > amountNATIVE) {
            TransferHelper.safeTransferNative(msg.sender, msg.value - amountNATIVE);
        }
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);

        IERC20(pair).safeTransferFrom(msg.sender, pair, liquidity);
        (uint256 amount0, uint256 amount1) = IUniswapV2Pair(pair).burn(to);
        (address token0,) = UniswapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "UniswapV2Router: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "UniswapV2Router: INSUFFICIENT_B_AMOUNT");
    }

    function removeLiquidityNative(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountToken, uint256 amountNATIVE) {
        (amountToken, amountNATIVE) =
            removeLiquidity(token, WNATIVE, liquidity, amountTokenMin, amountNativeMin, address(this), deadline);
        IERC20(token).safeTransfer(to, amountToken);
        IWNative(WNATIVE).withdraw(amountNATIVE);
        TransferHelper.safeTransferNative(to, amountNATIVE);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        IERC20Permit(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    function removeLiquidityNativeWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountToken, uint256 amountNATIVE) {
        address pair = UniswapV2Library.pairFor(factory, token, WNATIVE);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        IERC20Permit(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountNATIVE) =
            removeLiquidityNative(token, liquidity, amountTokenMin, amountNativeMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityNativeSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountNative) {
        (, amountNative) =
            removeLiquidity(token, WNATIVE, liquidity, amountTokenMin, amountNativeMin, address(this), deadline);
        IERC20(token).safeTransfer(to, IERC20(token).balanceOf(address(this)));
        IWNative(WNATIVE).withdraw(amountNative);
        TransferHelper.safeTransferNative(to, amountNative);
    }

    function removeLiquidityNativeWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountNative) {
        address pair = UniswapV2Library.pairFor(factory, token, WNATIVE);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        IERC20Permit(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountNative = removeLiquidityNativeSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountNativeMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapExactNativeForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == WNATIVE, "UniswapV2Router: INVALID_PATH");
        amounts = UniswapV2Library.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        IWNative(WNATIVE).deposit{value: amounts[0]}();
        assert(IWNative(WNATIVE).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactNative(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WNATIVE, "UniswapV2Router: INVALID_PATH");
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));
        IWNative(WNATIVE).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferNative(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForNative(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WNATIVE, "UniswapV2Router: INVALID_PATH");
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));
        IWNative(WNATIVE).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferNative(to, amounts[amounts.length - 1]);
    }

    function swapNativeForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == WNATIVE, "UniswapV2Router: INVALID_PATH");
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");
        IWNative(WNATIVE).deposit{value: amounts[0]}();
        assert(IWNative(WNATIVE).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) {
            TransferHelper.safeTransferNative(msg.sender, msg.value - amounts[0]);
        }
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;

                amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        IERC20(path[0]).safeTransferFrom(msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn);
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactNativeForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) {
        require(path[0] == WNATIVE, "UniswapV2Router: INVALID_PATH");
        uint256 amountIn = msg.value;
        IWNative(WNATIVE).deposit{value: amountIn}();
        assert(IWNative(WNATIVE).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn));
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactTokensForNativeSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == WNATIVE, "UniswapV2Router: INVALID_PATH");
        IERC20(path[0]).safeTransferFrom(msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn);
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint256 amountOut = IERC20(WNATIVE).balanceOf(address(this));
        require(amountOut >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        IWNative(WNATIVE).withdraw(amountOut);
        TransferHelper.safeTransferNative(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB)
        public
        pure
        virtual
        override
        returns (uint256 amountB)
    {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountOut)
    {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountIn)
    {
        return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    }
}
