// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {NadFunLibrary} from "../src/utils/NadFunLibrary.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {BondingCurveFactory} from "../src/BondingCurveFactory.sol";
import {Core} from "../src/Core.sol";
import {SetUp} from "./SetUp.sol";
import "../src/errors/Errors.sol";

contract NadFunLibraryTest is Test, SetUp {
    uint256 constant AMOUNT_IN = 1 ether;
    uint256 constant RESERVE_IN = 10 ether;
    uint256 constant RESERVE_OUT = 100 ether;
    uint256 constant TEST_K = RESERVE_IN * RESERVE_OUT;

    function testGetAmountOut() public {
        uint256 amountOut = NadFunLibrary.getAmountOut(
            AMOUNT_IN,
            RESERVE_IN,
            RESERVE_OUT
        );

        // Manual calculation for verification
        uint256 expectedAmountOut = RESERVE_OUT -
            (TEST_K / (RESERVE_IN + AMOUNT_IN)) -
            1;
        assertEq(
            amountOut,
            expectedAmountOut,
            "Amount out calculation mismatch"
        );

        // Verify the amount out is reasonable
        assertTrue(
            amountOut < RESERVE_OUT,
            "Amount out should be less than reserve out"
        );
        assertTrue(amountOut > 0, "Amount out should be greater than 0");
    }

    function testGetAmountIn() public {
        uint256 desiredAmountOut = 10 ether;
        uint256 amountIn = NadFunLibrary.getAmountIn(
            desiredAmountOut,
            RESERVE_IN,
            RESERVE_OUT
        );

        // Verify the calculated amount in produces the desired amount out
        uint256 resultingAmountOut = NadFunLibrary.getAmountOut(
            amountIn,
            RESERVE_IN,
            RESERVE_OUT
        );

        // Allow for 1 wei difference due to rounding
        assertApproxEqAbs(
            resultingAmountOut,
            desiredAmountOut,
            1,
            "Amount in/out calculation mismatch"
        );
    }

    function testGetAmountInWithInvalidAmountOut() public {
        uint256 invalidAmountOut = RESERVE_OUT + 1;

        vm.expectRevert(bytes(ERR_NAD_FUN_LIBRARY_INVALID_AMOUNT_OUT));
        NadFunLibrary.getAmountIn(invalidAmountOut, RESERVE_IN, RESERVE_OUT);
    }

    function testGetAmountAndFee() public {
        // Create and set up a bonding curve
        CreateBondingCurve(CREATOR);

        uint256 testAmount = 100 ether;
        (uint256 fee, uint256 adjustedAmount) = NadFunLibrary.getAmountAndFee(
            address(CURVE),
            testAmount
        );

        // Verify fee calculation
        (uint8 denominator, uint16 numerator) = CURVE.getFeeConfig();
        uint256 expectedFee = (testAmount * denominator) / numerator;
        assertEq(fee, expectedFee, "Fee calculation mismatch");

        // Verify adjusted amount
        assertEq(
            adjustedAmount,
            testAmount - fee,
            "Adjusted amount calculation mismatch"
        );
    }

    function testGetFeeAmount() public {
        uint256 amount = 100 ether;
        uint8 denominator = 10;
        uint16 numerator = 1000;

        uint256 fee = NadFunLibrary.getFeeAmount(
            amount,
            denominator,
            numerator
        );
        uint256 expectedFee = (amount * denominator) / numerator;

        assertEq(fee, expectedFee, "Fee calculation mismatch");
    }

    function testGetCurveData() public {
        // Create and set up a bonding curve
        CreateBondingCurve(CREATOR);

        // Test getCurveData with factory and token
        (
            address curve,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 k
        ) = NadFunLibrary.getCurveData(
                address(BONDING_CURVE_FACTORY),
                address(MEME_TOKEN)
            );

        // Verify returned data
        assertEq(curve, address(CURVE), "Curve address mismatch");
        (uint256 expectedVNad, uint256 expectedVToken) = CURVE
            .getVirtualReserves();
        assertEq(virtualNad, expectedVNad, "Virtual NAD mismatch");
        assertEq(virtualToken, expectedVToken, "Virtual token mismatch");
        assertEq(k, CURVE.getK(), "K value mismatch");

        // Test getCurveData with curve address directly
        (virtualNad, virtualToken, k) = NadFunLibrary.getCurveData(
            address(CURVE)
        );
        assertEq(virtualNad, expectedVNad, "Virtual NAD mismatch (direct)");
        assertEq(
            virtualToken,
            expectedVToken,
            "Virtual token mismatch (direct)"
        );
        assertEq(k, CURVE.getK(), "K value mismatch (direct)");
    }

    function testGetFeeConfig() public {
        CreateBondingCurve(CREATOR);

        (uint8 denominator, uint16 numerator) = NadFunLibrary.getFeeConfig(
            address(CURVE)
        );

        (uint8 expectedDenom, uint16 expectedNum) = CURVE.getFeeConfig();
        assertEq(denominator, expectedDenom, "Fee denominator mismatch");
        assertEq(numerator, expectedNum, "Fee numerator mismatch");
    }

    function testGetCurve() public {
        CreateBondingCurve(CREATOR);

        address curve = NadFunLibrary.getCurve(
            address(BONDING_CURVE_FACTORY),
            address(MEME_TOKEN)
        );

        assertEq(curve, address(CURVE), "Curve address mismatch");
    }

    function testGetVirtualReserves() public {
        CreateBondingCurve(CREATOR);

        (uint256 virtualNad, uint256 virtualToken) = NadFunLibrary
            .getVirtualReserves(address(CURVE));

        (uint256 expectedVNad, uint256 expectedVToken) = CURVE
            .getVirtualReserves();
        assertEq(virtualNad, expectedVNad, "Virtual NAD mismatch");
        assertEq(virtualToken, expectedVToken, "Virtual token mismatch");
    }

    function testGetK() public {
        CreateBondingCurve(CREATOR);

        uint256 k = NadFunLibrary.getK(address(CURVE));
        uint256 expectedK = CURVE.getK();

        assertEq(k, expectedK, "K value mismatch");
    }

    function testEdgeCases() public {
        // Test with very small amounts
        uint256 smallAmountIn = 1;
        uint256 amountOut = NadFunLibrary.getAmountOut(
            smallAmountIn,
            RESERVE_IN,
            RESERVE_OUT
        );
        assertTrue(amountOut > 0, "Should handle small amounts");

        // Test with very large amounts
        uint256 largeAmountIn = type(uint256).max / 2;
        vm.expectRevert(); // Should revert due to overflow
        NadFunLibrary.getAmountOut(largeAmountIn, RESERVE_IN, RESERVE_OUT);
    }

    function testFuzzGetAmountOut(uint256 amountIn) public {
        vm.assume(amountIn > 0 && amountIn < RESERVE_OUT);
        vm.assume(amountIn < type(uint256).max / RESERVE_OUT); // Prevent overflow

        uint256 amountOut = NadFunLibrary.getAmountOut(
            amountIn,
            RESERVE_IN,
            RESERVE_OUT
        );

        assertTrue(
            amountOut < RESERVE_OUT,
            "Amount out should be less than reserve"
        );
        assertTrue(amountOut > 0, "Amount out should be greater than 0");
    }
}
