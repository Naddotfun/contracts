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
import {Test, console} from "forge-std/Test.sol";

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
    function buy(uint256 amountIn, uint256 fee, address token, address to, uint256 deadline)
        external
        payable
        ensure(deadline)
    {
        uint256 totalAmountIn = amountIn + fee;
        require(msg.value >= totalAmountIn, ERR_INVALID_SEND_NAD);
        IWNAD(WNAD).deposit{value: totalAmountIn}();

        // Get curve and reserves
        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);

        // Calculate and verify amountOut
        uint256 amountOut = getAmountOut(amountIn, k, virtualNad, virtualToken);
        require(amountOut > 0, ERR_INVALID_AMOUNT_OUT);

        IERC20(WNAD).safeTransferERC20(curve, totalAmountIn);
        IBondingCurve(curve).buy(to, fee, amountOut);
        emit Buy(msg.sender, amountIn, amountOut, token, curve);
    }

    function buyAmountOutMin(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 fee,
        address token,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) {
        uint256 totalAmountIn = amountIn + fee;
        require(msg.value >= totalAmountIn, ERR_INVALID_SEND_NAD);
        IWNAD(WNAD).deposit{value: totalAmountIn}();

        // Get curve and reserves
        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);

        // Calculate and verify amountOut
        // uint256 amountOut = getAmountOut(amountIn, amountOutMin, virtualNad, virtualToken, k);
        uint256 amountOut = getAmountOut(amountIn, k, virtualNad, virtualToken);
        // console.log("Amount Out", amountOut);
        require(amountOut >= amountOutMin, ERR_INVALID_AMOUNT_OUT);

        IERC20(WNAD).safeTransferERC20(curve, totalAmountIn);
        // console.log("BuyAmountOutMin amountIn", amountIn);
        // console.log("BuyAmountOutMin virtualNad", virtualNad);
        // console.log("BuyAmountOutMin virtualToken", virtualToken);
        // console.log("BuyAmountOutMin AmountOut", amountOut);
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
        uint256 amountIn = getAmountIn(amountOut, k, virtualNad, virtualToken);
        //buy 일때는 amountIn + fee를 보내야함 .
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        // (uint256 fee, uint256 adjustedAmount) = getFeeAndAdjustedAmount(amountIn, denominator, numerator);
        uint256 fee = NadsPumpLibrary.getFeeAmount(amountIn, denominator, numerator);

        uint256 totalAmountIn = fee + amountIn;

        require(totalAmountIn <= amountInMax, ERR_INVALID_AMOUNT_IN_MAX);

        uint256 resetValue = amountInMax - totalAmountIn;
        if (resetValue > 0) {
            TransferHelper.safeTransferNad(msg.sender, resetValue);
        }
        IWNAD(WNAD).deposit{value: totalAmountIn}();
        IERC20(WNAD).safeTransferERC20(curve, totalAmountIn);
        IBondingCurve(curve).buy(to, fee, amountOut);
        emit Buy(msg.sender, amountIn, amountOut, token, curve);
    }
    // //-------------Sell Functions ---------------------------------------------
    //amountOutMin 은 fee 제외하고 받아야할 최소수량

    function sell(uint256 amountIn, address token, address to, uint256 deadline) external ensure(deadline) {
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        require(allowance >= amountIn, ERR_INVALID_ALLOWANCE);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);

        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);

        //sell 은 amountOut 에서 fee 를 때감
        uint256 amountOut = getAmountOut(amountIn, k, virtualToken, virtualNad);
        console.log("AmountOut = ", amountOut);
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        uint256 fee = NadsPumpLibrary.getFeeAmount(amountOut, denominator, numerator);
        uint256 adjustedAmountOut = amountOut - fee;
        console.log("AdjustedAmountOut", adjustedAmountOut);
        console.log("Fee", fee);
        // Transfer tokens to curve and call sell on BondingCurve
        IERC20(token).safeTransferERC20(curve, amountIn);
        // console.log(IERC20(WNAD).balanceOf(address(this)));
        IBondingCurve(curve).sell(address(this), fee, adjustedAmountOut);
        // console.log(IERC20(WNAD).balanceOf(address(this)));
        IWNAD(WNAD).withdraw(adjustedAmountOut);
        TransferHelper.safeTransferNad(to, adjustedAmountOut);
        emit Sell(msg.sender, amountIn, adjustedAmountOut, token, curve);
    }

    function sellAmountOutMin(
        uint256 amountIn,
        uint256 amountOutMin, //front = 10000 slippage = 10% -> 9000 이하로 받으면 revert
        address token,
        address to,
        uint256 deadline
    ) external ensure(deadline) {
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        require(allowance >= amountIn, ERR_INVALID_ALLOWANCE);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);

        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);

        //sell 은 amountOut 에서 fee 를 때감
        uint256 amountOut = getAmountOut(amountIn, k, virtualToken, virtualNad);
        console.log("AmountOut = ", amountOut);
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        uint256 fee = NadsPumpLibrary.getFeeAmount(amountOut, denominator, numerator);
        uint256 adjustedAmountOut = amountOut - fee;
        console.log("AdjustedAmountOut", adjustedAmountOut);
        console.log("Fee", fee);
        require(adjustedAmountOut >= amountOutMin, ERR_INVALID_AMOUNT_OUT);
        // Transfer tokens to curve and call sell on BondingCurve
        IERC20(token).safeTransferERC20(curve, amountIn);
        // console.log(IERC20(WNAD).balanceOf(address(this)));
        IBondingCurve(curve).sell(address(this), fee, adjustedAmountOut);
        // console.log(IERC20(WNAD).balanceOf(address(this)));
        IWNAD(WNAD).withdraw(adjustedAmountOut);
        TransferHelper.safeTransferNad(to, adjustedAmountOut);
        emit Sell(msg.sender, amountIn, adjustedAmountOut, token, curve);
    }

    // //유저용
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
        uint256 allowance = IERC20(token).allowance(from, address(this));

        require(allowance >= amountIn, ERR_INVALID_ALLOWANCE);
        // Safe transfer the token from user to this contract
        IERC20(token).safeTransferFrom(from, address(this), amountIn);

        // Get curve and reserves
        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);

        // Calculate and verify amountOut
        uint256 amountOut = getAmountOut(amountIn, k, virtualToken, virtualNad);
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        uint256 fee = NadsPumpLibrary.getFeeAmount(amountOut, denominator, numerator);
        uint256 adjustedAmountOut = amountOut - fee;

        require(adjustedAmountOut >= amountOutMin, ERR_INVALID_AMOUNT_OUT);
        // Transfer tokens to curve and call sell on BondingCurve
        IERC20(token).safeTransferFrom(address(this), curve, amountIn);
        IBondingCurve(curve).sell(address(this), fee, adjustedAmountOut);

        // Convert WNAD to NAD and transfer to the recipient
        IWNAD(WNAD).withdraw(adjustedAmountOut);
        TransferHelper.safeTransferNad(to, adjustedAmountOut);
        emit Sell(msg.sender, amountIn, adjustedAmountOut, token, curve);
    }
    // //애초에 fee 를 계산해서 넣어주면 되자나 예상 amountOut 과 fee 를 계산해서 넣어주면 됨.

    function sellExactAmountOut(uint256 amountOut, uint256 amountInMax, address token, address to, uint256 deadline)
        external
        ensure(deadline)
    {
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        require(allowance >= amountInMax, ERR_INVALID_ALLOWANCE);
        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);
        //amountIn 이 구해졌자나.
        //amountOut에 fee 를 더해서 구해야함.
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        uint256 fee = NadsPumpLibrary.getFeeAmount(amountOut, denominator, numerator);
        uint256 adjustedAmountOut = amountOut + fee;

        uint256 amountIn = getAmountIn(adjustedAmountOut, k, virtualToken, virtualNad);
        require(amountIn <= amountInMax, ERR_INVALID_AMOUNT_IN_MAX);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(token).safeTransferERC20(curve, amountIn);
        IBondingCurve(curve).sell(to, fee, amountOut);
        emit Sell(msg.sender, amountIn, adjustedAmountOut, token, curve);
    }
    // //유저용

    function sellExactAmountOutwithPermit(
        uint256 amountOut,
        uint256 amountInMax,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external ensure(deadline) {
        IERC20Permit(token).permit(from, address(this), amountInMax, deadline, v, r, s);

        // 먼저 amountIn 을구함
        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        uint256 fee = NadsPumpLibrary.getFeeAmount(amountOut, denominator, numerator);
        uint256 adjustedAmountOut = amountOut + fee;
        uint256 amountIn = getAmountIn(adjustedAmountOut, k, virtualToken, virtualNad);

        require(amountIn <= amountInMax, ERR_INVALID_AMOUNT_IN_MAX);
        IERC20(token).safeTransferFrom(from, address(this), amountIn);
        IERC20(token).safeTransferERC20(curve, amountIn);
        IBondingCurve(curve).sell(to, fee, amountOut);

        emit Sell(msg.sender, amountIn, adjustedAmountOut, token, curve);
    }
    //----------------------------Common Functions ---------------------------------------------------

    function getCurveData(address _factory, address token)
        internal
        view
        returns (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k)
    {
        (curve, virtualNad, virtualToken, k) = NadsPumpLibrary.getCurveData(_factory, token);
    }

    function getAmountOut(uint256 amountIn, uint256 k, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        amountOut = NadsPumpLibrary.getAmountOut(amountIn, k, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, uint256 k, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        amountIn = NadsPumpLibrary.getAmountIn(amountOut, k, reserveIn, reserveOut);
    }
}
