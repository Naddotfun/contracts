// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "src/utils/NadsPumpLibrary.sol";
import "src/BondingCurve.sol";
import "src/BondingCurveFactory.sol";
import "src/Core.sol";
import "src/WNAD.sol";
import "src/Token.sol";

import "src/errors/Errors.sol";
import {UniswapV2Factory} from "src/uniswap/UniswapV2Factory.sol";

contract NadsPumpLibraryTest is Test {
    function testGetAmountOut() public {
        uint256 amountIn = 1 ether;

        uint256 amountOut = NadsPumpLibrary.getAmountOut(
            amountIn,
            k,
            virtualNad,
            virtualToken
        );
        // console.log("Amount OUT", amountOut);
        assertEq(amountOut, 32258064516129032258064516);
    }

    function testGetAmountIn() public {
        uint256 amountOut = 32_258_064_516_129_032_258_064_516;

        uint256 amountIn = NadsPumpLibrary.getAmountIn(
            amountOut,
            k,
            virtualNad,
            virtualToken
        );
        // console.log("Amount IN", amountIn);
        assertEq(amountIn, 1 ether);
    }

    function testGetFeeAmount() public {
        uint256 amount = 1 ether;
        uint8 feeDenominator = 1;
        uint16 feeNumerator = 100;
        uint256 fee = NadsPumpLibrary.getFeeAmount(
            amount,
            feeDenominator,
            feeNumerator
        );
        assertEq(fee, 0.01 ether);
    }

    function testGetCurveData() public {
        (
            address curveAddress,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 k_
        ) = NadsPumpLibrary.getCurveData(address(factory), address(token));
        assertEq(curveAddress, address(curve));
        assertEq(virtualNad, 30 ether);
        assertEq(virtualToken, 1_000_000_000 ether);
        assertEq(k_, k);
    }

    function testFeeConfig() public {
        (uint8 feeDenominator, uint16 feeNumerator) = NadsPumpLibrary
            .getFeeConfig(address(curve));
        assertEq(feeDenominator, 1);
        assertEq(feeNumerator, 100);
    }

    function testGetCurve() public {
        address curveAddress = NadsPumpLibrary.getCurve(
            address(factory),
            address(token)
        );
        assertEq(curveAddress, address(curve));
    }

    function testGetVirtualReserves() public {
        (uint256 virtualNad_, uint256 virtualToken_) = NadsPumpLibrary
            .getVirtualReserves(address(curve));
        assertEq(virtualNad_, 30 ether);
        assertEq(virtualToken_, 1_000_000_000 ether);
    }

    function testGetK() public {
        uint256 k_ = NadsPumpLibrary.getK(address(curve));
        assertEq(k_, k);
    }
}
