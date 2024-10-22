// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../curve/interfaces/IBondingCurve.sol";
import "../curve/interfaces/IBondingCurveFactory.sol";
import "./errors/Error.sol";

library NadsPumpLibrary {
    function getAmountOut(uint256 amountIn, uint256 k, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        /**
         * @dev : - 1 Floating point issues
         */
        amountOut = reserveOut - (k / (reserveIn + amountIn)) - 1;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset

    function getAmountIn(uint256 amountOut, uint256 k, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        require(amountOut <= reserveOut, ERR_INVALID_AMOUNT_OUT);

        uint256 newReserveOut = reserveOut - amountOut;

        // Using a higher precision multiplier to avoid precision loss
        uint256 numerator = k / newReserveOut;
        amountIn = numerator - reserveIn;

        return amountIn + 1;
    }

    // function getBuyFeeAmount(uint256 amount, uint8 denominator, uint16 numerator) internal pure returns (uint256 fee) {
    //     fee = amount * denominator / numerator;
    //     // fee = amount * denominator / (numerator + denominator);
    // }

    // function getFeeAmount(uint256 amount, uint8 denominator, uint16 numerator) internal pure returns (uint256 fee) {
    //     fee = amount * denominator / (numerator + denominator);
    // }

    function getFeeAmount(uint256 amount, uint8 denominator, uint16 numerator) internal pure returns (uint256 fee) {
        fee = amount * denominator / numerator;
    }

    function getCurveData(address factory, address token)
        internal
        view
        returns (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k)
    {
        curve = getCurve(factory, token);
        (virtualNad, virtualToken) = getVirtualReserves(curve);
        k = NadsPumpLibrary.getK(curve);
    }

    function getCurveData(address curve) internal view returns (uint256 virtualNad, uint256 virtualToken, uint256 k) {
        (virtualNad, virtualToken) = getVirtualReserves(curve);
        k = NadsPumpLibrary.getK(curve);
    }

    function getFeeConfig(address curve) internal view returns (uint8, uint16) {
        return IBondingCurve(curve).getFeeConfig();
    }

    function getCurve(address factory, address token) internal view returns (address curve) {
        curve = IBondingCurveFactory(factory).getCurve(token);
        return curve;
    }
    // fetches and sorts the reserves for a pair

    function getVirtualReserves(address curve) internal view returns (uint256 virtualNad, uint256 virtualToken) {
        (virtualNad, virtualToken) = IBondingCurve(curve).getVirtualReserves();
    }

    function getK(address curve) internal view returns (uint256 k) {
        k = IBondingCurve(curve).getK();
    }
}
