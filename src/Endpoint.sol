// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IWNAD} from "./interfaces/IWNAD.sol";
import {NadsPumpLibrary} from "./utils/NadsPumpLibrary.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import "./errors/Errors.sol";

contract Endpoint {
    using TransferHelper for IERC20;

    address public immutable factory;
    address public immutable WNAD;

    constructor(address _factory, address _WNAD) {
        factory = _factory;
        WNAD = _WNAD;
    }

    event Buy(address indexed sender, uint256 amountIn, uint256 amountOut, address token, address curve);
    event Sell(address indexed sender, uint256 amountIn, uint256 amountOut, address token, address curve);

    receive() external payable {
        assert(msg.sender == WNAD); // only accept NAD via fallback from the WNAD contract
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, ERR_EXPIRED);
        _;
    }

    //----------------------------Buy Functions ---------------------------------------------------

    function buyAmountOutMin(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 fee,
        address token,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) {
        require(msg.value >= amountIn + fee, ERR_INVALID_SEND_NAD);
        IWNAD(WNAD).deposit{value: amountIn + fee}();

        // Get curve and reserves
        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);

        // Calculate and verify amountOut
        // uint256 amountOut = getAmountOut(amountIn, amountOutMin, virtualNad, virtualToken, k);
        uint256 amountOut = getAmountOut(k, amountIn, virtualNad, virtualToken);
        require(amountOut >= amountOutMin, ERR_INVALID_AMOUNT_OUT);
        // Transfer tokens and call buy on BondingCurve
        IERC20(WNAD).safeTransferERC20(curve, amountIn);
        IBondingCurve(curve).buy(to, fee, amountOut);
        emit Buy(msg.sender, amountIn, amountOut, token, curve);
    }

    function buyExactAmountOut(uint256 amountOut, uint256 amountInMax, address token, address to, uint256 deadline)
        external
        payable
        ensure(deadline)
    {
        require(msg.value >= amountInMax, ERR_INVALID_SEND_NAD);
        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);
        (uint256 fee, uint256 amountIn) =
            getAmountInAndFee(curve, getAmountIn(curve, amountOut, virtualNad, virtualToken));
        uint256 totalAmountIn = amountIn + fee;
        require(totalAmountIn <= amountInMax, ERR_INVALID_AMOUNT_IN_MAX);
        require(msg.value >= totalAmountIn, ERR_INVALID_SEND_NAD);
        uint256 resetValue = amountInMax - totalAmountIn;
        if (resetValue > 0) {
            TransferHelper.safeTransferNad(msg.sender, resetValue);
        }
        IWNAD(WNAD).deposit{value: totalAmountIn}();
        IERC20(WNAD).safeTransferERC20(curve, totalAmountIn);
        IBondingCurve(curve).buy(to, fee, amountOut);
        emit Buy(msg.sender, amountIn, amountOut, token, curve);
    }

    function sellAmountOutMin(
        uint256 amountIn,
        uint256 amountOutMin,
        address token,
        address from,
        address to,
        uint256 deadline
    ) external ensure(deadline) {
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        require(allowance >= amountIn, ERR_INVALID_ALLOWANCE);
        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);

        (uint256 amountOutAdjustedFee, uint256 fee) =
            getAmountOutAndFee(curve, getAmountOut(k, amountIn, virtualToken, virtualNad));
        require(amountOutAdjustedFee >= amountOutMin, ERR_INVALID_AMOUNT_OUT);
        // Transfer tokens to curve and call sell on BondingCurve
        IERC20(token).safeTransferFrom(from, curve, amountIn);
        IBondingCurve(curve).sell(address(this), fee, amountOutAdjustedFee);
        IWNAD(WNAD).withdraw(amountOutAdjustedFee);
        TransferHelper.safeTransferNad(to, amountOutAdjustedFee);
        emit Sell(msg.sender, amountIn, amountOutAdjustedFee, token, curve);
    }

    //유저용
    function sellAmountOutMinWithPermit(
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
        IERC20Permit(token).permit(from, address(this), amountIn, deadline, v, r, s);

        // Safe transfer the token from user to this contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);

        // Get curve and reserves
        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);

        // Calculate and verify amountOut

        (uint256 fee, uint256 amountOutAdjustedFee) =
            getAmountOutAndFee(curve, getAmountOut(k, amountIn, virtualToken, virtualNad));

        require(amountOutAdjustedFee >= amountOutMin, ERR_INVALID_AMOUNT_OUT);
        // Transfer tokens to curve and call sell on BondingCurve
        IERC20(token).safeTransferFrom(address(this), curve, amountIn);
        IBondingCurve(curve).sell(address(this), fee, amountOutAdjustedFee);

        // Convert WNAD to NAD and transfer to the recipient
        IWNAD(WNAD).withdraw(amountOutAdjustedFee);
        TransferHelper.safeTransferNad(to, amountOutAdjustedFee);
        emit Sell(msg.sender, amountIn, amountOutAdjustedFee, token, curve);
    }
    //애초에 fee 를 계산해서 넣어주면 되자나 예상 amountOut 과 fee 를 계산해서 넣어주면 됨.

    function sellExactAmountOut(
        uint256 amountOut,
        uint256 fee,
        uint256 amountInMax,
        address token,
        address to,
        uint256 deadline
    ) external ensure(deadline) {
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        require(allowance >= amountInMax, ERR_INVALID_ALLOWANCE);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountInMax);
        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);
        uint256 amountIn = getAmountIn(curve, amountOut + fee, virtualToken, virtualNad);
        require(amountIn <= amountInMax, ERR_INVALID_AMOUNT_IN_MAX);
        if (amountIn < amountInMax) {
            IERC20(token).safeTransferERC20(msg.sender, amountInMax - amountIn);
        }
        //amountIn 이 구해졌으니
        IERC20(token).safeTransferERC20(curve, amountIn);

        IBondingCurve(curve).sell(address(this), fee, amountOut);
        IWNAD(WNAD).withdraw(amountOut);
        TransferHelper.safeTransferNad(to, amountOut);
        emit Sell(msg.sender, amountIn, amountOut, token, curve);
    }
    //----------------------------Common Functions ---------------------------------------------------

    function getCurveData(address _factory, address token)
        internal
        view
        returns (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k)
    {
        (curve, virtualNad, virtualToken, k) = NadsPumpLibrary.getCurveData(_factory, token);
    }

    function getAmountOutAndFee(address curve, uint256 amountOut)
        internal
        view
        returns (uint256 fee, uint256 adjustedAmountOut)
    {
        (adjustedAmountOut, fee) = NadsPumpLibrary.getAmountAndFee(curve, amountOut);
    }

    function getAmountOut(uint256 k, uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        amountOut = NadsPumpLibrary.getAmountOut(k, amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(address curve, uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        view
        returns (uint256 amountIn)
    {
        amountIn = NadsPumpLibrary.getAmountIn(curve, amountOut, reserveIn, reserveOut);
    }

    function getAmountInAndFee(address curve, uint256 amountIn)
        internal
        view
        returns (uint256 fee, uint256 adjustedAmountIn)
    {
        (fee, adjustedAmountIn) = NadsPumpLibrary.getAmountInAndFee(curve, amountIn);
    }
}
