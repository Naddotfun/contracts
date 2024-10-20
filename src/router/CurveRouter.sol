// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IBondingCurve} from "../curve/interfaces/IBondingCurve.sol";
import {IBondingCurveFactory} from "../curve/interfaces/IBondingCurveFactory.sol";
import {IWNAD} from "../WNAD/interfaces/IWNAD.sol";

import {ICurveRouter} from "./interfaces/ICurveRouter.sol";
import {NadsPumpLibrary} from "../utils/NadsPumpLibrary.sol";
import {TransferHelper} from "../utils/TransferHelper.sol";
import "./errors/Error.sol";

contract CurveRouter is ICurveRouter {
    using TransferHelper for IERC20;

    address private owner;
    address public immutable factory;
    address public immutable WNAD;

    constructor(address _factory, address _WNAD) {
        factory = _factory;
        WNAD = _WNAD;
        owner = msg.sender;
    }

    receive() external payable {
        assert(msg.sender == WNAD); // only accept NAD via fallback from the WNAD contract
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, ERR_EXPIRED);
        _;
    }

    function checkFee(address curve, uint256 amount, uint256 fee) internal view {
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        require(fee >= amount * denominator / numerator, ERR_INVALID_FEE);
    }

    function createCurve(
        string memory name,
        string memory symbol,
        string memory tokenURI,
        uint256 amountIn,
        uint256 fee,
        uint256 deployFee
    )
        external
        payable
        returns (address curve, address token, uint256 virtualNad, uint256 virtualToken, uint256 amountOut)
    {
        require(msg.value >= amountIn + fee + deployFee, ERR_INVALID_SEND_NAD);
        uint256 _deployFee = IBondingCurveFactory(factory).getDelpyFee();
        require(deployFee >= _deployFee, ERR_INVALID_DEPLOY_FEE);

        IWNAD(WNAD).deposit{value: amountIn + fee + deployFee}();
        IERC20(WNAD).safeTransferERC20(factory, deployFee);
        (curve, token, virtualNad, virtualToken) = IBondingCurveFactory(factory).create(name, symbol, tokenURI);

        if (amountIn > 0 && fee > 0) {
            checkFee(curve, amountIn, fee);
            uint256 k = virtualNad * virtualToken;
            amountOut = getAmountOut(amountIn, k, virtualNad, virtualToken);
            IERC20(WNAD).safeTransferERC20(curve, amountIn + fee);
            IBondingCurve(curve).buy(msg.sender, amountOut, fee);
        }

        return (curve, token, virtualNad + amountIn, virtualToken - amountOut, amountOut);
    }

    //----------------------------Buy Functions ---------------------------------------------------
    function buy(uint256 amountIn, uint256 fee, address token, uint256 deadline) external payable ensure(deadline) {
        require(msg.value >= amountIn + fee, ERR_INVALID_SEND_NAD);
        require(amountIn > 0, ERR_INVALID_AMOUNT_IN);
        require(fee > 0, ERR_INVALID_FEE);

        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);
        checkFee(curve, amountIn, fee);

        // Get curve and reserves

        // Calculate and verify amountOut
        uint256 amountOut = getAmountOut(amountIn, k, virtualNad, virtualToken);
        uint256 totalAmountIn = amountIn + fee;
        IWNAD(WNAD).deposit{value: totalAmountIn}();
        IERC20(WNAD).safeTransferERC20(curve, totalAmountIn);
        IBondingCurve(curve).buy(msg.sender, amountOut, fee);
        // emit Buy(msg.sender, amountIn, amountOut, token, curve);
    }

    function buyWNad(uint256 amountIn, uint256 fee, address token, address to, uint256 deadline)
        external
        ensure(deadline)
    {
        uint256 allowance = IERC20(WNAD).allowance(msg.sender, address(this));
        require(allowance >= amountIn + fee, ERR_INVALID_ALLOWANCE);

        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);
        checkFee(curve, amountIn, fee);

        IERC20(WNAD).safeTransferFrom(msg.sender, address(this), amountIn + fee);

        uint256 amountOut = getAmountOut(amountIn, k, virtualNad, virtualToken);
        uint256 totalAmountIn = amountIn + fee;
        IERC20(WNAD).safeTransferERC20(curve, totalAmountIn);
        IBondingCurve(curve).buy(to, amountOut, fee);
        // emit Buy(msg.sender, amountIn, amountOut, token, curve);
    }

    function buyWNadWithPermit(
        uint256 amountIn,
        uint256 fee,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external ensure(deadline) {
        require(amountIn > 0, ERR_INVALID_AMOUNT_IN);

        //Not Check allowance because of permit
        IWNAD(WNAD).permit(from, address(this), amountIn + fee, deadline, v, r, s);

        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);
        checkFee(curve, amountIn, fee);
        uint256 totalAmountIn = amountIn + fee;
        IERC20(WNAD).safeTransferFrom(msg.sender, address(this), totalAmountIn);

        uint256 amountOut = getAmountOut(amountIn, k, virtualNad, virtualToken);

        IERC20(WNAD).safeTransferERC20(curve, totalAmountIn);

        IBondingCurve(curve).buy(to, amountOut, fee);
        // emit Buy(msg.sender, amountIn, amountOut, token, curve);
    }

    function buyAmountOutMin(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 fee,
        address token,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) {
        require(msg.value >= amountIn + fee, ERR_INVALID_SEND_NAD);

        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);
        checkFee(curve, amountIn, fee);
        uint256 totalAmountIn = amountIn + fee;
        IWNAD(WNAD).deposit{value: totalAmountIn}();

        uint256 amountOut = getAmountOut(amountIn, k, virtualNad, virtualToken);

        require(amountOut >= amountOutMin, ERR_INVALID_AMOUNT_OUT);

        IERC20(WNAD).safeTransferERC20(curve, totalAmountIn);

        IBondingCurve(curve).buy(to, amountOut, fee);
        // emit Buy(msg.sender, amountIn, amountOut, token, curve);
    }

    function buyWNadAmountOutMin(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 fee,
        address token,
        address to,
        uint256 deadline
    ) external ensure(deadline) {
        uint256 allowance = IERC20(WNAD).allowance(msg.sender, address(this));
        require(allowance >= amountIn + fee, ERR_INVALID_ALLOWANCE);
        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);
        checkFee(curve, amountIn, fee);
        uint256 totalAmountIn = amountIn + fee;
        IERC20(WNAD).safeTransferFrom(msg.sender, address(this), totalAmountIn);

        uint256 amountOut = getAmountOut(amountIn, k, virtualNad, virtualToken);

        require(amountOut >= amountOutMin, ERR_INVALID_AMOUNT_OUT);

        IERC20(WNAD).safeTransferERC20(curve, totalAmountIn);

        IBondingCurve(curve).buy(to, amountOut, fee);
        // emit Buy(msg.sender, amountIn, amountOut, token, curve);
    }

    function buyWNadAmountOutMinPermit(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 fee,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external ensure(deadline) {
        require(amountIn > 0, ERR_INVALID_AMOUNT_IN);
        uint256 totalAmountIn = amountIn + fee;
        IWNAD(WNAD).permit(from, address(this), totalAmountIn, deadline, v, r, s);

        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);
        checkFee(curve, amountIn, fee);

        IERC20(WNAD).safeTransferFrom(from, address(this), totalAmountIn);

        uint256 amountOut = getAmountOut(amountIn, k, virtualNad, virtualToken);

        require(amountOut >= amountOutMin, ERR_INVALID_AMOUNT_OUT);

        IERC20(WNAD).safeTransferERC20(curve, totalAmountIn);

        IBondingCurve(curve).buy(to, amountOut, fee);
        // emit Buy(msg.sender, amountIn, amountOut, token, curve);
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
        uint256 totalAmountIn = amountIn + fee;
        require(totalAmountIn <= amountInMax, ERR_INVALID_AMOUNT_IN_MAX);

        uint256 resetValue = amountInMax - totalAmountIn;
        if (resetValue > 0) {
            TransferHelper.safeTransferNad(msg.sender, resetValue);
        }
        IWNAD(WNAD).deposit{value: totalAmountIn}();
        // sendFeeByVault(fee);
        IERC20(WNAD).safeTransferERC20(curve, totalAmountIn);
        IBondingCurve(curve).buy(to, amountOut, fee);
        // emit Buy(msg.sender, amountIn, amountOut, token, curve);
    }

    function buyExactAmountOutWNad(uint256 amountOut, uint256 amountInMax, address token, address to, uint256 deadline)
        external
        ensure(deadline)
    {
        require(amountOut > 0, ERR_INVALID_AMOUNT_OUT);
        uint256 allowance = IERC20(WNAD).allowance(msg.sender, address(this));
        require(allowance >= amountInMax, ERR_INVALID_ALLOWANCE);

        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);
        uint256 amountIn = getAmountIn(amountOut, k, virtualNad, virtualToken);
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        uint256 fee = NadsPumpLibrary.getFeeAmount(amountIn, denominator, numerator);
        uint256 totalAmountIn = amountIn + fee;
        require(amountInMax >= totalAmountIn, ERR_INVALID_AMOUNT_IN_MAX);
        checkFee(curve, amountIn, fee);

        IERC20(WNAD).safeTransferFrom(msg.sender, address(this), totalAmountIn);

        IERC20(WNAD).safeTransferERC20(curve, totalAmountIn);
        IBondingCurve(curve).buy(to, amountOut, fee);
        // emit Buy(msg.sender, amountIn, amountOut, token, curve);
    }

    function buyExactAmountOutWNadPermit(
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
        require(amountOut > 0, ERR_INVALID_AMOUNT_IN);
        IWNAD(WNAD).permit(from, address(this), amountInMax, deadline, v, r, s);

        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);
        uint256 amountIn = getAmountIn(amountOut, k, virtualNad, virtualToken);
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        uint256 fee = NadsPumpLibrary.getFeeAmount(amountIn, denominator, numerator);
        checkFee(curve, amountIn, fee);
        uint256 totalAmountIn = amountIn + fee;
        require(amountInMax >= totalAmountIn, ERR_INVALID_AMOUNT_IN_MAX);

        IERC20(WNAD).safeTransferFrom(msg.sender, address(this), totalAmountIn);

        IERC20(WNAD).safeTransferERC20(curve, totalAmountIn);
        IBondingCurve(curve).buy(to, amountOut, fee);
        // emit Buy(msg.sender, amountIn, amountOut, token, curve);
    }
    // //-------------Sell Functions ---------------------------------------------

    function sell(uint256 amountIn, address token, uint256 deadline) external ensure(deadline) {
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        require(allowance >= amountIn, ERR_INVALID_ALLOWANCE);
        require(amountIn > 0, ERR_INVALID_AMOUNT_IN);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);

        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);

        uint256 totalAmountOut = getAmountOut(amountIn, k, virtualToken, virtualNad);

        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        uint256 fee = NadsPumpLibrary.getFeeAmount(totalAmountOut, denominator, numerator);

        IERC20(token).safeTransferERC20(curve, amountIn);
        uint256 amountOut = totalAmountOut - fee;

        IBondingCurve(curve).sell(address(this), amountOut, fee);

        IWNAD(WNAD).withdraw(amountOut);

        TransferHelper.safeTransferNad(msg.sender, amountOut);
        // emit Sell(msg.sender, amountIn, amountOut, token, curve);
    }

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
        IERC20Permit(token).permit(from, address(this), amountIn, deadline, v, r, s);
        IERC20(token).safeTransferFrom(from, address(this), amountIn);
        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);

        uint256 totalAmountOut = getAmountOut(amountIn, k, virtualToken, virtualNad);
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        uint256 fee = NadsPumpLibrary.getFeeAmount(totalAmountOut, denominator, numerator);
        uint256 amountOut = totalAmountOut - fee;

        IERC20(token).safeTransferERC20(curve, amountIn);

        IBondingCurve(curve).sell(address(this), amountOut, fee);

        IWNAD(WNAD).withdraw(amountOut);

        TransferHelper.safeTransferNad(to, amountOut);
        // emit Sell(msg.sender, amountIn, amountOut, token, curve);
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

        uint256 totalAmountOut = getAmountOut(amountIn, k, virtualToken, virtualNad);

        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        uint256 fee = NadsPumpLibrary.getFeeAmount(totalAmountOut, denominator, numerator);
        uint256 amountOut = totalAmountOut - fee;
        require(amountOut >= amountOutMin, ERR_INVALID_AMOUNT_OUT);

        IERC20(token).safeTransferERC20(curve, amountIn);

        IBondingCurve(curve).sell(address(this), amountOut, fee);

        IWNAD(WNAD).withdraw(amountOut);

        TransferHelper.safeTransferNad(to, amountOut);
        // emit Sell(msg.sender, amountIn, amountOut, token, curve);
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
        uint256 totalAmountOut = getAmountOut(amountIn, k, virtualToken, virtualNad);
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        uint256 fee = NadsPumpLibrary.getFeeAmount(totalAmountOut, denominator, numerator);
        uint256 amountOut = totalAmountOut - fee;

        require(amountOut >= amountOutMin, ERR_INVALID_AMOUNT_OUT);

        IERC20(token).safeTransferERC20(curve, amountIn);
        IBondingCurve(curve).sell(address(this), amountOut, fee);

        IWNAD(WNAD).withdraw(amountOut);

        TransferHelper.safeTransferNad(to, amountOut);
        // emit Sell(msg.sender, amountIn, amountOut, token, curve);
    }
    //amountOut 은 fee + amountOut 이어야함.

    function sellExactAmountOut(uint256 amountOut, uint256 amountInMax, address token, address to, uint256 deadline)
        external
        ensure(deadline)
    {
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        require(allowance >= amountInMax && amountInMax > 0, ERR_INVALID_ALLOWANCE);

        (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k) = getCurveData(factory, token);

        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        uint256 fee = NadsPumpLibrary.getFeeAmount(amountOut, denominator, numerator);
        uint256 totalAmountOut = amountOut + fee;
        uint256 amountIn = getAmountIn(totalAmountOut, k, virtualToken, virtualNad);

        require(amountIn <= amountInMax, ERR_INVALID_AMOUNT_IN_MAX);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(token).safeTransferERC20(curve, amountIn);

        IBondingCurve(curve).sell(address(this), amountOut, fee);

        IWNAD(WNAD).withdraw(amountOut);

        TransferHelper.safeTransferNad(to, amountOut);
        // emit Sell(msg.sender, amountIn, amountOut, token, curve);
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
        uint256 totalAmountOut = amountOut + fee;
        uint256 amountIn = getAmountIn(totalAmountOut, k, virtualToken, virtualNad);

        require(amountIn <= amountInMax, ERR_INVALID_AMOUNT_IN_MAX);

        IERC20(token).safeTransferFrom(from, address(this), amountIn);
        IERC20(token).safeTransferERC20(curve, amountIn);

        IBondingCurve(curve).sell(address(this), amountOut, fee);

        IWNAD(WNAD).withdraw(amountOut);

        TransferHelper.safeTransferNad(to, amountOut);
        // emit Sell(msg.sender, amountIn, amountOut, token, curve);
    }

    //----------------------------Common Functions ---------------------------------------------------

    function getCurveData(address _factory, address token)
        public
        view
        returns (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k)
    {
        (curve, virtualNad, virtualToken, k) = NadsPumpLibrary.getCurveData(_factory, token);
    }

    function getCurveData(address curve) public view returns (uint256 virtualNad, uint256 virtualToken, uint256 k) {
        (virtualNad, virtualToken, k) = NadsPumpLibrary.getCurveData(curve);
    }

    function getAmountOut(uint256 amountIn, uint256 k, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        amountOut = NadsPumpLibrary.getAmountOut(amountIn, k, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, uint256 k, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountIn)
    {
        amountIn = NadsPumpLibrary.getAmountIn(amountOut, k, reserveIn, reserveOut);
    }
}
