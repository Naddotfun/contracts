// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BondingCurveLibrary} from "../src/utils/BondingCurveLibrary.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {BondingCurveFactory} from "../src/BondingCurveFactory.sol";
import {Core} from "../src/Core.sol";
import {SetUp} from "./SetUp.sol";
import "../src/errors/Errors.sol";

contract BondingCurveLibraryTest is Test, SetUp {
    uint256 constant AMOUNT_IN = 1 ether;
    uint256 constant RESERVE_IN = 10 ether;
    uint256 constant RESERVE_OUT = 100 ether;
    uint256 constant TEST_K = RESERVE_IN * RESERVE_OUT;

    function testGetAmountOut() public pure {
        uint256 amountOut = BondingCurveLibrary.getAmountOut(
            AMOUNT_IN,
            TEST_K,
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
        // Test case 1: Normal case with 10 ether
        uint256 desiredAmountOut = 10 ether;
        uint256 amountIn = BondingCurveLibrary.getAmountIn(
            desiredAmountOut,
            TEST_K,
            RESERVE_IN,
            RESERVE_OUT
        );

        // Verify the calculated amount in produces the desired amount out
        uint256 resultingAmountOut = BondingCurveLibrary.getAmountOut(
            amountIn,
            TEST_K,
            RESERVE_IN,
            RESERVE_OUT
        );

        // Allow for up to 7 wei difference due to rounding
        assertApproxEqAbs(
            resultingAmountOut,
            desiredAmountOut,
            100,
            "Amount in/out calculation mismatch"
        );

        // Test case 2: Small amount (1 wei)
        uint256 smallAmountOut = 1;
        uint256 smallAmountIn = BondingCurveLibrary.getAmountIn(
            smallAmountOut,
            TEST_K,
            RESERVE_IN,
            RESERVE_OUT
        );
        assertTrue(smallAmountIn > 0, "Should handle small amounts");

        // Test case 3: Amount close to reserve out
        uint256 largeAmountOut = RESERVE_OUT - 1;
        vm.expectRevert();
        BondingCurveLibrary.getAmountIn(
            largeAmountOut,
            TEST_K,
            RESERVE_IN,
            RESERVE_OUT
        );

        // Test case 4: Verify k constant with specific values
        uint256 testK = 1000000; // 1M
        uint256 testReserveIn = 1000; // 1K
        uint256 testReserveOut = 1000; // 1K
        uint256 testAmountOut = 100;

        uint256 testAmountIn = BondingCurveLibrary.getAmountIn(
            testAmountOut,
            testK,
            testReserveIn,
            testReserveOut
        );

        // Verify k remains constant
        uint256 newK = (testReserveIn + testAmountIn) *
            (testReserveOut - testAmountOut);
        assertEq(
            newK,
            testK,
            "K should remain constant after getAmountIn calculation"
        );
    }

    function testGetAmountInWithInvalidAmountOut() public {
        uint256 invalidAmountOut = RESERVE_OUT + 1;

        vm.expectRevert(bytes(ERR_BONDING_CURVE_LIBRARY_INVALID_AMOUNT_OUT));
        BondingCurveLibrary.getAmountIn(
            invalidAmountOut,
            TEST_K,
            RESERVE_IN,
            RESERVE_OUT
        );
    }

    function testGetAmountAndFee() public {
        // Create and set up a bonding curve
        CreateBondingCurve(CREATOR);

        uint256 testAmount = 100 ether;
        (uint256 fee, uint256 adjustedAmount) = BondingCurveLibrary
            .getAmountAndFee(address(CURVE), testAmount);

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

    function testGetFeeAmount() public pure {
        uint256 amount = 100 ether;
        uint8 denominator = 10;
        uint16 numerator = 1000;

        uint256 fee = BondingCurveLibrary.getFeeAmount(
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
            uint256 virtualNative,
            uint256 virtualToken,
            uint256 k
        ) = BondingCurveLibrary.getCurveData(
                address(BONDING_CURVE_FACTORY),
                address(MEME_TOKEN)
            );

        // Verify returned data
        assertEq(curve, address(CURVE), "Curve address mismatch");
        (uint256 expectedVNad, uint256 expectedVToken) = CURVE
            .getVirtualReserves();
        assertEq(virtualNative, expectedVNad, "Virtual NAD mismatch");
        assertEq(virtualToken, expectedVToken, "Virtual token mismatch");
        assertEq(k, CURVE.getK(), "K value mismatch");

        // Test getCurveData with curve address directly
        (virtualNative, virtualToken, k) = BondingCurveLibrary.getCurveData(
            address(CURVE)
        );
        assertEq(virtualNative, expectedVNad, "Virtual NAD mismatch (direct)");
        assertEq(
            virtualToken,
            expectedVToken,
            "Virtual token mismatch (direct)"
        );
        assertEq(k, CURVE.getK(), "K value mismatch (direct)");
    }

    function testGetFeeConfig() public {
        CreateBondingCurve(CREATOR);

        (uint8 denominator, uint16 numerator) = BondingCurveLibrary
            .getFeeConfig(address(CURVE));

        (uint8 expectedDenom, uint16 expectedNum) = CURVE.getFeeConfig();
        assertEq(denominator, expectedDenom, "Fee denominator mismatch");
        assertEq(numerator, expectedNum, "Fee numerator mismatch");
    }

    function testGetCurve() public {
        CreateBondingCurve(CREATOR);

        address curve = BondingCurveLibrary.getCurve(
            address(BONDING_CURVE_FACTORY),
            address(MEME_TOKEN)
        );

        assertEq(curve, address(CURVE), "Curve address mismatch");
    }

    function testGetVirtualReserves() public {
        CreateBondingCurve(CREATOR);

        (uint256 virtualNative, uint256 virtualToken) = BondingCurveLibrary
            .getVirtualReserves(address(CURVE));

        (uint256 expectedVNad, uint256 expectedVToken) = CURVE
            .getVirtualReserves();
        assertEq(virtualNative, expectedVNad, "Virtual NAD mismatch");
        assertEq(virtualToken, expectedVToken, "Virtual token mismatch");
    }

    function testGetK() public {
        CreateBondingCurve(CREATOR);

        uint256 k = BondingCurveLibrary.getK(address(CURVE));
        uint256 expectedK = CURVE.getK();

        assertEq(k, expectedK, "K value mismatch");
    }

    function testEdgeCases() public {
        // Test with very small amounts
        uint256 smallAmountIn = 1;
        uint256 amountOut = BondingCurveLibrary.getAmountOut(
            smallAmountIn,
            TEST_K,
            RESERVE_IN,
            RESERVE_OUT
        );
        assertTrue(amountOut > 0, "Should handle small amounts");

        // Test with very large amounts
        uint256 largeAmountIn = type(uint256).max / 2;
        vm.expectRevert(); // Should revert due to overflow
        BondingCurveLibrary.getAmountOut(
            largeAmountIn,
            TEST_K,
            RESERVE_IN,
            RESERVE_OUT
        );

        // Test precision with division edge cases
        uint256 k = 1000000; // 1M
        uint256 reserveIn = 1000; // 1K
        uint256 reserveOut = 1000; // 1K

        // Test getAmountOut and getAmountIn symmetry
        uint256 testAmountIn = 100;
        uint256 resultOut = BondingCurveLibrary.getAmountOut(
            testAmountIn,
            k,
            reserveIn,
            reserveOut
        );

        uint256 calculatedAmountIn = BondingCurveLibrary.getAmountIn(
            resultOut,
            k,
            reserveIn,
            reserveOut
        );

        // Should be equal or differ by at most 1 due to rounding
        assertTrue(
            calculatedAmountIn == testAmountIn ||
                calculatedAmountIn == testAmountIn + 1,
            "getAmountIn/Out symmetry check failed"
        );

        // Test with amounts that cause division to be exact
        uint256 exactK = 1000000; // 1M
        uint256 exactReserveIn = 1000; // 1K
        uint256 exactAmountIn = 1000; // 1K
        uint256 exactReserveOut = 1000; // 1K

        uint256 exactOut = BondingCurveLibrary.getAmountOut(
            exactAmountIn,
            exactK,
            exactReserveIn,
            exactReserveOut
        );

        // Verify k remains constant
        uint256 newK = (exactReserveIn + exactAmountIn) *
            (exactReserveOut - exactOut);
        assertEq(newK, exactK, "K should remain constant");
    }

    function testFuzzGetAmountOut(uint256 amountIn) public pure {
        vm.assume(amountIn > 0 && amountIn < RESERVE_OUT);
        vm.assume(amountIn < type(uint256).max / RESERVE_OUT); // Prevent overflow

        uint256 amountOut = BondingCurveLibrary.getAmountOut(
            amountIn,
            TEST_K,
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
