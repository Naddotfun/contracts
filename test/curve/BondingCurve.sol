// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BondingCurve} from "../../src/curve/BondingCurve.sol";
import {Token} from "../../src/token/Token.sol";
import {NadsPumpLibrary} from "../../src/utils/NadsPumpLibrary.sol";
import {SetUp} from "../SetUp.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract BondingCurveTest is Test, SetUp {
    uint256 AMOUNT_IN = 1000;
    uint256 FEE = AMOUNT_IN / 100;

    function createCurve() internal {
        vm.startPrank(OWNER);
        wNAD.deposit{value: DEPLOY_FEE}();
        wNAD.transfer(address(BONDING_CURVE_FACTORY), DEPLOY_FEE);
        (address curveAddress, address tokenAddress,,) = BONDING_CURVE_FACTORY.create("test", "test", "testurl");
        CURVE = BondingCurve(curveAddress);
        MEME_TOKEN = Token(tokenAddress);
        vm.stopPrank();
    }

    function testBuy() public {
        // CurveCreate(OWNER);
        vm.startPrank(TRADER_A);
        (uint256 virtualNadAmount, uint256 virtualTokenAmount) = CURVE.getVirtualReserves();
        uint256 totalAmount = AMOUNT_IN + FEE;
        vm.deal(TRADER_A, totalAmount);
        wNAD.deposit{value: totalAmount}();
        wNAD.transfer(address(CURVE), totalAmount);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(AMOUNT_IN, CURVE.getK(), virtualNadAmount, virtualTokenAmount);
        CURVE.buy(TRADER_A, amountOut, FEE);
        assertEq(wNAD.balanceOf(address(CURVE)), AMOUNT_IN);
        assertEq(MEME_TOKEN.balanceOf(address(CURVE)), 1000000000 ether - amountOut);
        assertEq(MEME_TOKEN.balanceOf(TRADER_A), amountOut);
        //total Asset 은 (DEPLOY_FEE + fee)이여야하나, revenucore 에 10%를 줌.
        assertEq(VAULT.totalAssets(), DEPLOY_FEE + FEE);
        vm.stopPrank();
    }

    function testSell() public {
        // CurveCreate(OWNER);

        vm.startPrank(TRADER_A);
        (uint256 virtualNadAmount, uint256 virtualTokenAmount) = CURVE.getVirtualReserves();

        uint256 totalAmount = AMOUNT_IN + FEE;
        vm.deal(TRADER_A, totalAmount);
        wNAD.deposit{value: totalAmount}();
        wNAD.transfer(address(CURVE), totalAmount);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(AMOUNT_IN, CURVE.getK(), virtualNadAmount, virtualTokenAmount);
        CURVE.buy(TRADER_A, amountOut, FEE);
        vm.stopPrank();

        vm.startPrank(TRADER_A);
        // vm.deal(TRADER_A, FEE);
        // wNAD.deposit{value: FEE}();
        // wNAD.transfer(address(CURVE), FEE);

        uint256 sellAmount = MEME_TOKEN.balanceOf(TRADER_A);
        MEME_TOKEN.transfer(address(CURVE), sellAmount);
        CURVE.sell(TRADER_A, AMOUNT_IN - FEE, FEE);

        assertEq(MEME_TOKEN.balanceOf(TRADER_A), 0);

        assertEq(VAULT.totalAssets(), DEPLOY_FEE + FEE + FEE);

        vm.stopPrank();
    }

    function testListing() public {
        // CurveCreate(OWNER);
        vm.startPrank(TRADER_A);
        // (uint256 virtualNadAmount, uint256 virtualTokenAmount) = curve.getVirtualReserves();
        //amount Out 을 얻기위해선 amountIn 이 필요
        uint256 amountOut = TOKEN_TOTAL_SUPPLY - TARGET_TOKEN;

        uint256 amountIn = NadsPumpLibrary.getAmountIn(amountOut, CURVE.getK(), VIRTUAL_NAD, VIRTUAL_TOKEN);
        uint256 fee = amountIn / 100;
        uint256 totalAmount = amountIn + fee;

        vm.deal(TRADER_A, totalAmount);

        wNAD.deposit{value: totalAmount}();
        wNAD.transfer(address(CURVE), totalAmount);
        CURVE.buy(TRADER_A, amountOut, fee);

        assertEq(CURVE.getLock(), true);

        address pair = CURVE.listing();

        // assertEq(VAULT.totalAssets(), (((DEPLOY_FEE + fee + LISTING_FEE) / 10) * 9) + 9); //+9 은 deciaml 조정
        assertEq(VAULT.totalAssets(), DEPLOY_FEE + fee + LISTING_FEE);
        assertEq(wNAD.balanceOf(pair), amountIn - LISTING_FEE);
        assertEq(MEME_TOKEN.balanceOf(pair), TARGET_TOKEN);

        assertEq(IERC20(pair).balanceOf(address(CURVE)), 0);
        (uint256 realNadAmount, uint256 realTokenAmount) = CURVE.getReserves();
        assertEq(realNadAmount, 0);
        assertEq(realTokenAmount, 0);
        assertEq(wNAD.balanceOf(address(CURVE)), 0);
        assertEq(MEME_TOKEN.balanceOf(address(CURVE)), 0);
    }
}
