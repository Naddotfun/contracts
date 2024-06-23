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

    //
    function createCurveInitBalance(
        string memory name,
        string memory symbol,
        uint256 amountIn,
        uint256 fee,
        uint256 deployFee
    ) external payable {
        require(msg.value >= amountIn + fee + deployFee, ERR_INVALID_SEND_NAD);
        require(amountIn > 0, ERR_INVALID_AMOUNT_IN);
        require(fee > 0, ERR_INVALID_FEE);

        (, address token) = IBondingCurveFactory(factory).create{value: deployFee}(name, symbol);
        IWNAD(WNAD).deposit{value: amountIn + fee}();

        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);
        uint256 amountOut = getAmountOut(amountIn, k, virtualNad, virtualToken);
        IERC20(WNAD).safeTransferERC20(curve, amountIn + fee);
        IBondingCurve(curve).buy(msg.sender, fee, amountOut);
        emit Buy(msg.sender, amountIn, amountOut, token, curve);
    }

    //----------------------------Buy Functions ---------------------------------------------------
    function buy(uint256 amountIn, uint256 fee, address token, address to, uint256 deadline)
        external
        payable
        ensure(deadline)
    {
        uint256 totalAmountIn = amountIn + fee;
        require(msg.value >= totalAmountIn, ERR_INVALID_SEND_NAD);
        require(amountIn > 0, ERR_INVALID_AMOUNT_IN);
        require(fee > 0, ERR_INVALID_FEE);
        IWNAD(WNAD).deposit{value: totalAmountIn}();

        // Get curve and reserves
        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);

        // Calculate and verify amountOut
        uint256 amountOut = getAmountOut(amountIn, k, virtualNad, virtualToken);

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

        uint256 amountOut = getAmountOut(amountIn, k, virtualNad, virtualToken);

        require(amountOut >= amountOutMin, ERR_INVALID_AMOUNT_OUT);

        IERC20(WNAD).safeTransferERC20(curve, totalAmountIn);

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

        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();

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

    function sell(uint256 amountIn, address token, address to, uint256 deadline) external ensure(deadline) {
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        require(allowance >= amountIn, ERR_INVALID_ALLOWANCE);
        require(amountIn > 0, ERR_INVALID_AMOUNT_IN);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);

        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);

        uint256 amountOut = getAmountOut(amountIn, k, virtualToken, virtualNad);

        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        uint256 fee = NadsPumpLibrary.getFeeAmount(amountOut, denominator, numerator);
        uint256 adjustedAmountOut = amountOut - fee;

        IERC20(token).safeTransferERC20(curve, amountIn);

        IBondingCurve(curve).sell(address(this), fee, adjustedAmountOut);

        IWNAD(WNAD).withdraw(adjustedAmountOut);
        TransferHelper.safeTransferNad(to, adjustedAmountOut);
        emit Sell(msg.sender, amountIn, adjustedAmountOut, token, curve);
    }

    function sellAmountOutMin(uint256 amountIn, uint256 amountOutMin, address token, address to, uint256 deadline)
        external
        ensure(deadline)
    {
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        require(allowance >= amountIn, ERR_INVALID_ALLOWANCE);
        require(amountIn > 0, ERR_INVALID_AMOUNT_IN);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);

        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);

        uint256 amountOut = getAmountOut(amountIn, k, virtualToken, virtualNad);

        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        uint256 fee = NadsPumpLibrary.getFeeAmount(amountOut, denominator, numerator);
        uint256 adjustedAmountOut = amountOut - fee;

        require(adjustedAmountOut >= amountOutMin, ERR_INVALID_AMOUNT_OUT);

        IERC20(token).safeTransferERC20(curve, amountIn);

        IBondingCurve(curve).sell(address(this), fee, adjustedAmountOut);

        IWNAD(WNAD).withdraw(adjustedAmountOut);
        TransferHelper.safeTransferNad(to, adjustedAmountOut);
        emit Sell(msg.sender, amountIn, adjustedAmountOut, token, curve);
    }

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
        require(amountIn > 0, ERR_INVALID_AMOUNT_IN);
        IERC20Permit(token).permit(from, address(this), amountIn, deadline, v, r, s);
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

        IERC20(token).safeTransferERC20(curve, amountIn);
        IBondingCurve(curve).sell(address(this), fee, adjustedAmountOut);

        IWNAD(WNAD).withdraw(adjustedAmountOut);
        TransferHelper.safeTransferNad(to, adjustedAmountOut);
        emit Sell(msg.sender, amountIn, adjustedAmountOut, token, curve);
    }

    function sellExactAmountOut(uint256 amountOut, uint256 amountInMax, address token, address to, uint256 deadline)
        external
        ensure(deadline)
    {
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        require(allowance >= amountInMax && amountInMax > 0, ERR_INVALID_ALLOWANCE);

        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);

        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        uint256 fee = NadsPumpLibrary.getFeeAmount(amountOut, denominator, numerator);
        uint256 adjustedAmountOut = amountOut + fee;

        uint256 amountIn = getAmountIn(adjustedAmountOut, k, virtualToken, virtualNad);
        require(amountIn <= amountInMax, ERR_INVALID_AMOUNT_IN_MAX);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(token).safeTransferERC20(curve, amountIn);
        IBondingCurve(curve).sell(address(this), fee, amountOut);
        IWNAD(WNAD).withdraw(amountOut);
        TransferHelper.safeTransferNad(to, amountOut);
        emit Sell(msg.sender, amountIn, adjustedAmountOut, token, curve);
    }

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
        require(amountInMax > 0, ERR_INVALID_AMOUNT_IN_MAX);

        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        uint256 fee = NadsPumpLibrary.getFeeAmount(amountOut, denominator, numerator);
        uint256 adjustedAmountOut = amountOut + fee;
        uint256 amountIn = getAmountIn(adjustedAmountOut, k, virtualToken, virtualNad);

        require(amountIn <= amountInMax, ERR_INVALID_AMOUNT_IN_MAX);
        IERC20(token).safeTransferFrom(from, address(this), amountIn);
        IERC20(token).safeTransferERC20(curve, amountIn);
        IBondingCurve(curve).sell(address(this), fee, amountOut);
        IWNAD(WNAD).withdraw(amountOut);
        TransferHelper.safeTransferNad(to, amountOut);
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
