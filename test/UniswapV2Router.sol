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

    function testSwap() public {
        vm.startPrank(TRADER_A);

        uint tokenAmount = MEME_TOKEN.balanceOf(TRADER_A);
        console.log("tokenAmount=", tokenAmount);
        console.log("UNISWAP_PAIR=", address(UNISWAP_PAIR));
        address[] memory path = new address[](2);
        path[0] = address(MEME_TOKEN);
        path[1] = address(WNATIVE);
        uint[] memory amounts = UNISWAP_ROUTER.getAmountsOut(tokenAmount, path);
        uint amountOut = amounts[1];
        console.log("amountOut = ", amountOut);

        UNISWAP_ROUTER.swapExactTokensForTokens(
            tokenAmount,
            amountOut,
            path,
            TRADER_A,
            block.timestamp + 1
        );

        assertEq(MEME_TOKEN.balanceOf(TRADER_A), 0);
        assertGt(WNATIVE.balanceOf(TRADER_A), amountOut);
        vm.stopPrank();
    }
}
