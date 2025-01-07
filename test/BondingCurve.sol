// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BondingCurve} from "src/BondingCurve.sol";
import {Token} from "src/Token.sol";
import "src/errors/Errors.sol";
import {IWNative} from "src/interfaces/IWNative.sol";
import {WNative} from "src/WNative.sol";
import {BondingCurveLibrary} from "src/utils/BondingCurveLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./SetUp.sol";

contract BondingCurveTest is Test, SetUp {
    function setUp() public override {
        super.setUp();
        CreateBondingCurve(CREATOR);
    }

    // ========== Success Cases ==========

    function testInitialization() public {
        // Check initial state variables
        assertEq(address(CURVE.wNative()), address(WNATIVE));
        assertEq(address(CURVE.token()), address(MEME_TOKEN));

        // Check virtual reserves
        (uint256 virtualNativeAmount, uint256 virtualTokenAmount) = CURVE
            .getVirtualReserves();
        assertEq(virtualNativeAmount, VIRTUAL_NATIVE);
        assertEq(virtualTokenAmount, VIRTUAL_TOKEN);

        // Check fee configuration
        (uint8 denominator, uint16 numerator) = CURVE.getFee();
        assertEq(denominator, FEE_DENOMINATOR);
        assertEq(numerator, FEE_NUMERATOR);

        // Check initial lock state
        assertFalse(CURVE.lock());
        assertFalse(CURVE.isListing());

        // Check constant product K
        assertEq(CURVE.getK(), K);
    }

    function testBuy() public {
        vm.startPrank(TRADER_A);
        uint256 amountIn = 1 ether;
        uint256 fee = amountIn / uint256(FEE_DENOMINATOR);
        vm.deal(TRADER_A, amountIn + fee);

        // Calculate expected amount out
        (uint256 virtualNative, uint256 virtualToken) = CURVE
            .getVirtualReserves();
        uint256 expectedAmountOut = BondingCurveLibrary.getAmountOut(
            amountIn,
            CURVE.getK(),
            virtualNative,
            virtualToken
        );

        // Execute buy through core
        uint256 deadline = block.timestamp + 1;
        CORE.buy{value: amountIn + fee}(
            amountIn,
            fee,
            address(MEME_TOKEN),
            TRADER_A,
            deadline
        );

        // Verify balances and reserves
        assertEq(MEME_TOKEN.balanceOf(TRADER_A), expectedAmountOut);
        (uint256 realNative, uint256 realToken) = CURVE.getReserves();
        assertEq(realNative, amountIn);
        assertEq(realToken, TOKEN_TOTAL_SUPPLY - expectedAmountOut);
        vm.stopPrank();
    }

    function testSell() public {
        // First buy some tokens
        vm.startPrank(TRADER_A);
        uint256 buyAmountIn = 1 ether;
        uint256 buyFee = BondingCurveLibrary.getFeeAmount(
            buyAmountIn,
            FEE_DENOMINATOR,
            FEE_NUMERATOR
        );
        vm.deal(TRADER_A, buyAmountIn + buyFee);

        uint256 deadline = block.timestamp + 1;
        CORE.buy{value: buyAmountIn + buyFee}(
            buyAmountIn,
            buyFee,
            address(MEME_TOKEN),
            TRADER_A,
            deadline
        );

        // Now sell the tokens
        uint256 tokenBalance = MEME_TOKEN.balanceOf(TRADER_A);
        MEME_TOKEN.approve(address(CORE), tokenBalance);

        CORE.sell(tokenBalance, address(MEME_TOKEN), TRADER_A, deadline);

        // Verify the sale
        assertGt(TRADER_A.balance, 0);
        assertEq(MEME_TOKEN.balanceOf(TRADER_A), 0);
        vm.stopPrank();
    }

    function testListing() public {
        // Buy enough tokens to reach target
        vm.startPrank(TRADER_A);
        (uint256 virtualNative, uint256 virtualToken) = CURVE
            .getVirtualReserves();
        (, uint256 realTokenReserves) = CURVE.getReserves();

        console.log(virtualNative, "virtualNative");
        console.log(virtualToken, "virtualToken");
        console.log(realTokenReserves, "realTokenReserves");
        console.log(TARGET_TOKEN, "TARGET_TOKEN");

        // Calculate exact amount needed to reach TARGET_TOKEN
        uint256 amountOutDesired = realTokenReserves - TARGET_TOKEN;
        console.log(amountOutDesired, "amountOutDesired");
        uint256 requiredAmount = BondingCurveLibrary.getAmountIn(
            amountOutDesired,
            CURVE.getK(),
            virtualNative,
            virtualToken
        );
        console.log(requiredAmount, "requiredAmount");

        uint getAmount = BondingCurveLibrary.getAmountOut(
            requiredAmount,
            CURVE.getK(),
            virtualNative,
            virtualToken
        );
        console.log(getAmount, "getAmount");

        uint256 fee = BondingCurveLibrary.getFeeAmount(
            requiredAmount,
            FEE_DENOMINATOR,
            FEE_NUMERATOR
        );
        console.log(fee, "fee");
        vm.deal(TRADER_A, requiredAmount + fee + LISTING_FEE);

        uint256 deadline = block.timestamp + 1;
        CORE.exactOutBuy{value: requiredAmount + fee}(
            amountOutDesired,
            requiredAmount + fee,
            address(MEME_TOKEN),
            TRADER_A,
            deadline
        );

        // Verify token balance is exactly TARGET_TOKEN
        (, uint256 remainingTokens) = CURVE.getReserves();
        console.log(remainingTokens, "remainingTokens");
        assertEq(
            remainingTokens,
            TARGET_TOKEN,
            "Token balance should be exactly TARGET_TOKEN"
        );

        // Verify lock is activated
        assertTrue(CURVE.lock(), "Curve should be locked");

        // Try listing
        // Try listing
        vm.deal(TRADER_A, LISTING_FEE);
        address pair = CURVE.listing{gas: 5000000}();

        assertTrue(pair != address(0), "Pair should be created");
        assertTrue(CURVE.isListing(), "Should be listed");

        // LP 토큰 소각 테스트 추가
        uint256 liquidity = CURVE._burnLPTokens(pair);

        // LP 토큰이 DEAD 주소로 전송되었는지 확인
        address DEAD = 0x000000000000000000000000000000000000dEaD;
        assertEq(
            IERC20(pair).balanceOf(DEAD),
            liquidity,
            "LP tokens should be transferred to DEAD address"
        );

        // 본딩 커브 컨트랙트의 LP 토큰 잔액이 0인지 확인
        assertEq(
            IERC20(pair).balanceOf(address(CURVE)),
            0,
            "Bonding curve should have no LP tokens"
        );

        // LpBurned 이벤트 확인
        vm.expectEmit(true, true, true, true);

        vm.stopPrank();
    }

    // ========== Failure Cases ==========

    function testRevertBuyWhenLocked() public {
        // First reach target to lock
        CurveListing(TRADER_A);

        vm.expectRevert(bytes(ERR_BONDING_CURVE_ALREADY_LISTED));
        CURVE.listing();
        vm.stopPrank();
    }

    function testRevertBuyInvalidAmount() public {
        vm.startPrank(TRADER_A);
        uint256 fee = 0.1 ether;
        vm.deal(TRADER_A, fee);

        uint256 deadline = block.timestamp + 1;
        vm.expectRevert(bytes(ERR_CORE_INVALID_AMOUNT_IN));
        CORE.buy{value: fee}(0, fee, address(MEME_TOKEN), TRADER_A, deadline);
        vm.stopPrank();
    }

    function testRevertSellInvalidAmount() public {
        vm.startPrank(TRADER_A);
        uint256 deadline = block.timestamp + 1;

        vm.expectRevert(bytes(ERR_CORE_INVALID_AMOUNT_IN));
        CORE.sell(0, address(MEME_TOKEN), TRADER_A, deadline);
        vm.stopPrank();
    }

    function testRevertListingNotEnoughTokens() public {
        vm.startPrank(TRADER_A);
        uint256 amountIn = 1 ether;
        uint256 fee = BondingCurveLibrary.getFeeAmount(
            amountIn,
            FEE_DENOMINATOR,
            FEE_NUMERATOR
        );
        vm.deal(TRADER_A, amountIn + fee);

        uint256 deadline = block.timestamp + 1;
        CORE.buy{value: amountIn + fee}(
            amountIn,
            fee,
            address(MEME_TOKEN),
            TRADER_A,
            deadline
        );

        vm.expectRevert(bytes(ERR_BONDING_CURVE_ONLY_LOCK));
        CURVE.listing();
        vm.stopPrank();
    }

    function testRevertDoubleList() public {
        // First listing
        CurveListing(TRADER_A);

        // Try to list again
        vm.expectRevert(bytes(ERR_BONDING_CURVE_ALREADY_LISTED));
        CURVE.listing();
    }
}
