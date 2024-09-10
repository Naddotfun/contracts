// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BondingCurve} from "src/BondingCurve.sol";
import {BondingCurveFactory} from "src/BondingCurveFactory.sol";
import {Token} from "src/Token.sol";
import "src/errors/Errors.sol";
import {IWNAD} from "src/interfaces/IWNAD.sol";
import {WNAD} from "src/WNAD.sol";
import {NadsPumpLibrary} from "src/utils/NadsPumpLibrary.sol";
import {Endpoint} from "src/Endpoint.sol";
import {FeeVault} from "src/FeeVault.sol";
import {UniswapV2Factory} from "src/uniswap/UniswapV2Factory.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "./Constant.sol";

contract CurveTest is Test, TestConstants {
    BondingCurve curve;
    Token token;
    BondingCurveFactory factory;
    WNAD wNad;
    Endpoint endpoint;
    FeeVault vault;
    UniswapV2Factory uniFactory;
    address trader;

    function setUp() public {
        vm.startPrank(OWNER);

        uniFactory = new UniswapV2Factory(OWNER);

        wNad = new WNAD();
        factory = new BondingCurveFactory(OWNER, address(wNad));
        factory.initialize(
            DEPLOY_FEE,
            LISTING_FEE,
            TOKEN_TOTAL_SUPPLY,
            VIRTUAL_NAD,
            VIRTUAL_TOKEN,
            TARGET_TOKEN,
            FEE_NUMERATOR,
            FEE_DENOMINATOR,
            address(uniFactory)
        );
        vault = new FeeVault(IERC20(address(wNad)));

        endpoint = new Endpoint(address(factory), address(wNad), address(vault));

        factory.setEndpoint(address(endpoint));
        vm.stopPrank();

        vm.deal(CREATOR, DEPLOY_FEE);

        vm.startPrank(CREATOR);
        (address curveAddress, address tokenAddress,,,) =
            endpoint.createCurve{value: DEPLOY_FEE}("test", "test", "testurl", 0, 0, DEPLOY_FEE);
        curve = BondingCurve(curveAddress);
        token = Token(tokenAddress);
        vm.stopPrank();

        trader = vm.addr(TRADER_PRIVATE_KEY);
    }

    function testListing() public {
        vm.startPrank(trader);
        (uint256 virtualNadAmount, uint256 virtualTokenAmount) = curve.getVirtualReserves();

        uint256 amountIn =
            endpoint.getAmountIn(TOKEN_TOTAL_SUPPLY - TARGET_TOKEN, curve.getK(), virtualNadAmount, virtualTokenAmount);
        console.log(amountIn);
        uint256 fee = amountIn / 100;
        vm.deal(trader, amountIn + fee);

        uint256 deadline = block.timestamp + 1;

        endpoint.buyExactAmountOut{value: amountIn + fee}(
            TOKEN_TOTAL_SUPPLY - TARGET_TOKEN, amountIn + fee, address(token), trader, deadline
        );

        assertEq(curve.getLock(), true);
        console.log("curve wnad", IERC20(wNad).balanceOf(address(curve)));
        console.log("curve token", IERC20(token).balanceOf(address(curve)));
        address pair = curve.listing();

        assertEq(IERC4626(vault).totalAssets(), LISTING_FEE + DEPLOY_FEE + fee);

        assertEq(IERC20(wNad).balanceOf(pair), amountIn - LISTING_FEE);
        assertEq(IERC20(token).balanceOf(pair), TARGET_TOKEN);

        assert(IERC20(pair).balanceOf(address(0)) >= 131835870639645623191986);
        (uint256 realNadAmount, uint256 realTokenAmount) = curve.getReserves();
        assertEq(realNadAmount, 0);
        assertEq(realTokenAmount, 0);
        assertEq(IERC20(wNad).balanceOf(address(curve)), 0);
        assertEq(IERC20(token).balanceOf(address(curve)), 0);
    }

    function testInitFee() public {
        (uint8 dominator, uint16 numerator) = curve.getFee();
        assertEq(dominator, FEE_DENOMINATOR);
        assertEq(numerator, FEE_NUMERATOR);
    }

    function testInitLock() public {
        bool lock = curve.getLock();
        assertEq(lock, false);
    }

    function testGetReserve() public {
        (uint256 reserveBase, uint256 reserveToken) = curve.getReserves();
        assertEq(reserveBase, 0);
        assertEq(reserveToken, TOKEN_TOTAL_SUPPLY);
    }

    function testGetVirtualReserve() public {
        (uint256 virtualNad, uint256 virtualToken) = curve.getVirtualReserves();
        assertEq(virtualNad, VIRTUAL_NAD);
        assertEq(virtualToken, VIRTUAL_TOKEN);
    }

    function testGetFeeConfig() public {
        (uint8 dominator, uint16 numerator) = curve.getFee();
        assertEq(dominator, FEE_DENOMINATOR);
        assertEq(numerator, FEE_NUMERATOR);
    }

    function testGetK() public {
        uint256 k = curve.getK();
        assertEq(k, K);
    }

    function testGetLock() public {
        bool lock = curve.getLock();
        assertEq(lock, false);
    }
}
