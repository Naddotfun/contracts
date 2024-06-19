// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../interfaces/IBondingCurve.sol";
import "../interfaces/IBondingCurveFactory.sol";
import "../errors/Errors.sol";

library NadsPumpLibrary {
    // //  일정 금액의 자산과 페어 준비금이 주어지면 다른 자산의 동등한 금액을 반환합니다.
    // function quote(uint256 amount, uint256 virtualBase, uint256 virtualToken) internal pure returns (uint256 amountB) {
    //     require(amount > 0, "DragonswapLibrary: INSUFFICIENT_AMOUNT");
    //     require(virtualBase > 0 && virtualToken > 0, "DragonswapLibrary: INSUFFICIENT_LIQUIDITY");
    //     amountB = (amount * virtualToken) / virtualBase;
    // }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(address curve, uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        view
        returns (uint256 amountIn)
    {
        require(amountOut > 0, ERR_INSUFFICIENT_INPUT_AMOUNT);
        require(reserveIn > 0 && reserveOut > 0, ERR_INSUFFICIENT_RESERVE);
        //4 999 900 000
        (uint8 feeDenominator, uint16 feeNumerator) = IBondingCurve(curve).getFeeConfig();
        uint256 _numerator = reserveIn * amountOut * feeNumerator;
        //49 500 990
        uint256 _denominator = (reserveOut - amountOut) * feeDenominator;
        amountIn = (_numerator / _denominator);
    }

    function getAmountInAndFee(address curve, uint256 amountIn)
        internal
        view
        returns (uint256 fee, uint256 adjustedAmountIn)
    {
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        fee = getFeeAmount(amountIn, denominator, numerator);
        adjustedAmountIn = amountIn - fee;
    }

    function getAmountOut(uint256 k, uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        /**
         * @dev : - 1 Floating point issues
         */
        return reserveOut - (k / (reserveIn + amountIn)) - 1;
    }

    function getAmountAndFee(address curve, uint256 amountOut)
        internal
        view
        returns (uint256 fee, uint256 adjustedAmountOut)
    {
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        fee = getFeeAmount(amountOut, denominator, numerator);
        adjustedAmountOut = amountOut - fee;
    }

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
    // 공통 로직: Fee Config 가져오기

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
