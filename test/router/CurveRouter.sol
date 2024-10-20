// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {CurveRouter} from "../../src/router/CurveRouter.sol";
import {SetUp} from "../SetUp.sol";
import {NadsPumpLibrary} from "../../src/utils/NadsPumpLibrary.sol";
import "../../src/router/errors/Error.sol";

contract CurveRouterTest is Test, SetUp {
    CurveRouter public CURVE_ROUTER;

    function setUp() public override {
        super.setUp(); // SetUp의 setUp() 함수를 먼저 호출
        CURVE_ROUTER = new CurveRouter(address(BONDING_CURVE_FACTORY), address(wNAD));
    }

    //CREATE CURVE TEST
    function testCreateCurveNotBuy() public {
        vm.deal(CREATOR, DEPLOY_FEE);
        vm.startPrank(CREATOR);

        (address curve, address token, uint256 virtualNad, uint256 virtualToken, uint256 amountOut) =
            CURVE_ROUTER.createCurve{value: DEPLOY_FEE}("TEST", "TEST", "TEST", 0, 0, DEPLOY_FEE);
        assertEq(curve, BONDING_CURVE_FACTORY.getCurve(token));
        assertNotEq(token, address(0));
        assertEq(virtualNad, VIRTUAL_NAD);
        assertEq(virtualToken, VIRTUAL_TOKEN);
        assertEq(amountOut, 0);

        vm.stopPrank();
    }

    function testCreateCurveInitialBuy() public {
        uint256 amountIn = 1 ether;
        uint256 fee = amountIn * FEE_DENOMINATOR / FEE_NUMERATOR;
        uint256 expectedAmountOut = NadsPumpLibrary.getAmountOut(amountIn, K, VIRTUAL_NAD, VIRTUAL_TOKEN);
        vm.deal(CREATOR, DEPLOY_FEE + amountIn + fee);
        vm.startPrank(CREATOR);

        (address curve, address token, uint256 virtualNad, uint256 virtualToken, uint256 amountOut) = CURVE_ROUTER
            .createCurve{value: DEPLOY_FEE + amountIn + fee}("TEST", "TEST", "TEST", amountIn, fee, DEPLOY_FEE);
        assertEq(curve, BONDING_CURVE_FACTORY.getCurve(token));
        assertNotEq(token, address(0));
        assertEq(virtualNad, VIRTUAL_NAD + amountIn);
        assertEq(virtualToken, VIRTUAL_TOKEN - amountOut);

        assertEq(amountOut, expectedAmountOut);
    }

    function testInvalidDeployFeeCreateCurve() public {
        vm.deal(CREATOR, DEPLOY_FEE - 1);
        vm.startPrank(CREATOR);

        vm.expectRevert(bytes(ERR_INVALID_SEND_NAD));
        CURVE_ROUTER.createCurve{value: DEPLOY_FEE - 1}("TEST", "TEST", "TEST", 0, 0, DEPLOY_FEE);
        vm.stopPrank();
    }

    //BUY TEST
    function testBuy() public {
        vm.startPrank(TRADER_A);
        uint256 amountIn = 1 ether;
        uint256 fee = amountIn * FEE_DENOMINATOR / FEE_NUMERATOR;
        uint256 expectedAmountOut = NadsPumpLibrary.getAmountOut(amountIn, K, VIRTUAL_NAD, VIRTUAL_TOKEN);
        vm.deal(TRADER_A, amountIn + fee);

        CURVE_ROUTER.buy{value: amountIn + fee}(amountIn, fee, address(MEME_TOKEN), block.timestamp);
        assertEq(MEME_TOKEN.balanceOf(TRADER_A), expectedAmountOut);
    }

    function testSell() public {
        BuyAmountOut(TRADER_A, 1 ether);
        vm.startPrank(TRADER_A);
        uint256 amountIn = MEME_TOKEN.balanceOf(TRADER_A);
        (uint256 virtualNad, uint256 virtualToken) = CURVE.getVirtualReserves();
        uint256 expectedAmountOut = NadsPumpLibrary.getAmountOut(amountIn, K, virtualToken, virtualNad);
        uint256 fee = expectedAmountOut * FEE_DENOMINATOR / FEE_NUMERATOR;
        MEME_TOKEN.approve(address(CURVE_ROUTER), amountIn);
        CURVE_ROUTER.sell(amountIn, address(MEME_TOKEN), block.timestamp);

        assertEq(TRADER_A.balance, expectedAmountOut - fee);
    }
}
