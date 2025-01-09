// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "./SetUp.sol";

import {Test, console} from "forge-std/Test.sol";

contract UniswapV2RouterTest is SetUp {
    function setUp() public override {
        super.setUp();
        CreateBondingCurve(CREATOR);
        CurveListing(TRADER_A);
    }

    function testSell() public {
        vm.startPrank(TRADER_A);
        uint tokenAmount = MEME_TOKEN.balanceOf(TRADER_A);
        console.log("TRADER_A_BALANCE", TRADER_A.balance);
        console.log("tokenAmount = ", tokenAmount);
        address[] memory path = new address[](2);
        path[0] = address(MEME_TOKEN);
        path[1] = address(WNATIVE);
        uint[] memory amounts = UNISWAP_ROUTER.getAmountsOut(tokenAmount, path);
        uint amountOut = amounts[1];
        MEME_TOKEN.approve(address(UNISWAP_ROUTER), tokenAmount);
        UNISWAP_ROUTER.swapExactTokensForNative(
            tokenAmount,
            amountOut,
            path,
            TRADER_A,
            block.timestamp + 1
        );
        assertEq(MEME_TOKEN.balanceOf(TRADER_A), 0);
        console.log("WNATIVE.balanceOf(TRADER_A)", WNATIVE.balanceOf(TRADER_A));
        assertApproxEqAbs(TRADER_A.balance, amountOut, 1e1);
        vm.stopPrank();
    }

    function testBuy() public {
        vm.startPrank(TRADER_B);
        vm.deal(TRADER_B, 1 ether);
        console.log(
            "TRADER_B TOKEN BALANCE = ",
            MEME_TOKEN.balanceOf(TRADER_B)
        );
        address[] memory path = new address[](2);
        path[0] = address(WNATIVE);
        path[1] = address(MEME_TOKEN);
        uint[] memory amounts = UNISWAP_ROUTER.getAmountsOut(1 ether, path);
        uint amountOut = amounts[1];

        UNISWAP_ROUTER.swapExactNativeForTokens{value: 1 ether}(
            1 ether,
            path,
            TRADER_B,
            block.timestamp + 1
        );
        console.log("AFTER TOKEN_BALANCE =", MEME_TOKEN.balanceOf(TRADER_B));
        assertEq(MEME_TOKEN.balanceOf(TRADER_B), amountOut);

        assertEq(TRADER_B.balance, 0);
        vm.stopPrank();
    }
}
