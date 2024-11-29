// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {BondingCurve} from "src/BondingCurve.sol";
import {BondingCurveFactory} from "src/BondingCurveFactory.sol";
import {IWNAD} from "src/interfaces/IWNAD.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {FeeVault} from "src/FeeVault.sol";
import {Token} from "src/Token.sol";
import {UniswapV2Factory} from "src/uniswap/UniswapV2Factory.sol";
import "src/errors/Errors.sol";
import "src/WNAD.sol";
import "src/utils/NadsPumpLibrary.sol";
import "src/Core.sol";
import "./SetUp.sol";
contract CoreTest is Test,SetUp {
  
   

    function testCreateCurve() public {
        vm.startPrank(creator);
        (address curveAddress, address tokenAddress, uint256 _virtualNad, uint256 _virtualToken, uint256 initAmountOut)
        = core.createCurve{value: 1.03 ether}("Test", "Test", "testurl", 1 ether, 0.01 ether, 0.02 ether);

        vm.stopPrank();

        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, _virtualNad, _virtualToken);
        assertEq(IERC20(tokenAddress).balanceOf(creator), amountOut);

        assertEq(IERC4626(vault).totalAssets(), 0.05 ether); // setup 0.02 + 0.03
        assertEq(creator.balance, 0);
    }

    function testInvalidFeeCreateCurve() public {
        vm.deal(creator, 1.025 ether);
        vm.expectRevert(bytes(ERR_INVALID_FEE));
        vm.startPrank(creator);
        //amountIn = 0;
        core.createCurve{value: 1.025 ether}("TEST", "TEST", "testurl", 1 ether, 0.005 ether, 0.02 ether);
        vm.stopPrank();
    }
    /**
     * @dev Buy Test
     */

    function testInvalidDeployFeeCreateCurve() public {
        vm.deal(creator, 1.02 ether);
        vm.expectRevert(bytes(ERR_INVALID_DEPLOY_FEE));
        vm.startPrank(creator);
        //amountIn = 0;
        core.createCurve{value: 1.02 ether}("TEST", "TEST", "testurl", 1 ether, 0.01 ether, 0.01 ether);
        vm.stopPrank();
    }

    function testBuy() public {
        vm.startPrank(trader);
        uint256 vaultBalance = IERC4626(vault).totalAssets();
        vm.deal(trader, 1.01 ether);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);

        uint256 deadline = block.timestamp + 1;

        core.buy{value: 1.01 ether}(1 ether, 0.01 ether, address(token), trader, deadline);
        vm.stopPrank();

        assertEq(token.balanceOf(trader), amountOut);
        assertEq(trader.balance, 0);
        //fee 로 받은 0.01 ether 는 owner 에게 전송됨.

        assertEq(IERC4626(vault).totalAssets(), vaultBalance + 0.01 ether);
    }

    function InvalidValueBuy() public {
        vm.startPrank(trader);

        vm.deal(trader, 1.01 ether);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);

        uint256 deadline = block.timestamp + 1;
        //1.01 ether 보내야함
        vm.expectRevert(bytes(ERR_INVALID_SEND_NAD));
        core.buy{value: 1 ether}(1 ether, 0.01 ether, address(token), trader, deadline);
        assertEq(IERC4626(vault).totalAssets(), 0.01 ether);
    }

    function InvalidAmountInAndFeeBuy() public {
        vm.startPrank(trader);

        vm.deal(trader, 1.01 ether);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);

        uint256 deadline = block.timestamp + 1;
        //1.01 ether 보내야함
        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_IN));
        core.buy{value: 1.01 ether}(0, 0.01 ether, address(token), trader, deadline);
        vm.expectRevert(bytes(ERR_INVALID_FEE));
        core.buy{value: 1.01 ether}(1, 0, address(token), trader, deadline);
    }

    /**
     * @dev BuyWNad Test
     */
    function testBuyWNad() public {
        vm.startPrank(trader);
        uint256 ownerBalance = IERC4626(vault).totalAssets();
        uint256 traderWNad = 1.01 ether;
        vm.deal(trader, traderWNad);
        wNad.deposit{value: traderWNad}();
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 deadline = block.timestamp + 1;
        wNad.approve(address(core), traderWNad);
        core.buyWNad(1 ether, 0.01 ether, address(token), trader, deadline);
        vm.stopPrank();
        assertEq(token.balanceOf(trader), amountOut);
        assertEq(wNad.balanceOf(trader), 0);
        assertEq(IERC4626(vault).totalAssets(), ownerBalance + 0.01 ether);
    }

    function testInvalidAmountInBuyWNad() public {
        vm.startPrank(trader);
        uint256 traderWNad = 1.01 ether;
        vm.deal(trader, traderWNad);
        wNad.deposit{value: traderWNad}();
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 deadline = block.timestamp + 1;

        wNad.approve(address(core), traderWNad);

        uint256 amountIn = 2 ether;
        uint256 fee = 0.02 ether;

        vm.expectRevert(bytes(ERR_INVALID_ALLOWANCE));
        core.buyWNad(amountIn, fee, address(token), trader, deadline);
    }

    function testInvalidFeeBuyWNad() public {
        vm.startPrank(trader);

        uint256 traderWNad = 1.01 ether;
        vm.deal(trader, traderWNad);
        wNad.deposit{value: traderWNad}();
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 deadline = block.timestamp + 1;
        wNad.approve(address(core), traderWNad);
        uint256 amountIn = 1 ether;
        uint256 fee = 0.009 ether;
        vm.expectRevert(bytes(ERR_INVALID_FEE));
        core.buyWNad(amountIn, fee, address(token), trader, deadline);
    }

    /**
     * @dev buyNadWNadPermit Test
     */
    function testbuyWNadWithPermit() public {
        vm.startPrank(trader);
        uint256 ownerBalance = IERC4626(vault).totalAssets();
        uint256 traderWNad = 1.01 ether;
        vm.deal(trader, traderWNad);
        wNad.deposit{value: traderWNad}();
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 deadline = block.timestamp + 1;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                wNad.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(wNad.PERMIT_TYPEHASH(), trader, address(core), traderWNad, 0, deadline))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);
        core.buyWNadWithPermit(1 ether, 0.01 ether, address(token), trader, trader, deadline, v, r, s);
        vm.stopPrank();
        assertEq(token.balanceOf(trader), amountOut);
        assertEq(wNad.balanceOf(trader), 0);
        assertEq(IERC4626(vault).totalAssets(), ownerBalance + 0.01 ether);
    }

    function testInvalidPermitBuyWNadWithPermit() public {
        vm.startPrank(trader);
        uint256 traderWNad = 1.01 ether;
        vm.deal(trader, traderWNad);
        wNad.deposit{value: traderWNad}();
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 deadline = block.timestamp + 1;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                wNad.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(wNad.PERMIT_TYPEHASH(), trader, address(core), traderWNad + 1, 0, deadline))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);

        vm.expectRevert(bytes(ERR_INVALID_SIGNATURE));

        core.buyWNadWithPermit(1 ether, 0.01 ether, address(token), trader, trader, deadline, v, r, s);
    }

    function testInvalidFeeBuyWNadWithPermit() public {
        vm.startPrank(trader);
        uint256 traderWNad = 2.01 ether;
        vm.deal(trader, traderWNad);
        wNad.deposit{value: traderWNad}();
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 deadline = block.timestamp + 1;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                wNad.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(wNad.PERMIT_TYPEHASH(), trader, address(core), traderWNad, 0, deadline))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);
        vm.expectRevert(bytes(ERR_INVALID_FEE));
        core.buyWNadWithPermit(2 ether, 0.01 ether, address(token), trader, trader, deadline, v, r, s);
    }

    /**
     * @dev BuyAmountOutMin Test
     */
    function testBuyAmountOutMin() public {
        vm.startPrank(trader);
        vm.deal(trader, 1.01 ether);
        uint256 owerBalance = IERC4626(vault).totalAssets();
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        // console.log("Calculated amountOut: ", amountOut);
        uint256 deadline = block.timestamp + 1;

        core.buyAmountOutMin{value: 1.01 ether}(1 ether, 10, 0.01 ether, address(token), trader, deadline);
        vm.stopPrank();

        assertEq(token.balanceOf(trader), amountOut);
        assertEq(trader.balance, 0);
        assertEq(IERC4626(vault).totalAssets(), owerBalance + 0.01 ether);
    }

    function testInvalidValueBuyAmountOutMin() public {
        vm.startPrank(trader);
        vm.deal(trader, 1.01 ether);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        // console.log("Calculated amountOut: ", amountOut);
        uint256 deadline = block.timestamp + 1;

        vm.expectRevert(bytes(ERR_INVALID_SEND_NAD));
        core.buyAmountOutMin{value: 1 ether}(1 ether, amountOut - 1, 0.01 ether, address(token), trader, deadline);
    }

    function testInvalidAmountOutMinBuyAmountOutMin() public {
        vm.startPrank(trader);
        vm.deal(trader, 1.01 ether);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        // console.log("Calculated amountOut: ", amountOut);
        uint256 deadline = block.timestamp + 1;

        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_OUT));
        core.buyAmountOutMin{value: 1.01 ether}(
            1 ether, amountOut + 1, 0.01 ether, address(token), trader, deadline
        );
    }

    /**
     * @dev Buy AmountOutMinWNad Test
     */
    function testBuyWNadAmountOutMin() public {
        vm.startPrank(trader);
        uint256 ownerBalance = IERC4626(vault).totalAssets();
        uint256 traderWNad = 1.01 ether;
        vm.deal(trader, traderWNad);
        wNad.deposit{value: traderWNad}();
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 deadline = block.timestamp + 1;
        wNad.approve(address(core), traderWNad);
        uint256 amountOutMin = 10;
        core.buyWNadAmountOutMin(1 ether, amountOutMin, 0.01 ether, address(token), trader, deadline);
        vm.stopPrank();
        assertEq(token.balanceOf(trader), amountOut);
        assertEq(wNad.balanceOf(trader), 0);
        assertEq(IERC4626(vault).totalAssets(), ownerBalance + 0.01 ether);
    }

    function testInvalidAllowanceBuyWNadAmountOutMin() public {
        vm.startPrank(trader);
        uint256 traderWNad = 1.01 ether;
        vm.deal(trader, traderWNad);
        wNad.deposit{value: traderWNad}();
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 deadline = block.timestamp + 1;
        uint256 amountOutMin = 10;
        wNad.approve(address(core), traderWNad - 1);
        vm.expectRevert(bytes(ERR_INVALID_ALLOWANCE));
        core.buyWNadAmountOutMin(1 ether, amountOutMin, 0.01 ether, address(token), trader, deadline);
    }

    function testInvalidFeeBuyWNadAmountOutMin() public {
        vm.startPrank(trader);
        uint256 traderWNad = 2.01 ether;
        vm.deal(trader, traderWNad);
        wNad.deposit{value: traderWNad}();
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 deadline = block.timestamp + 1;
        uint256 amountOutMin = 10;
        wNad.approve(address(core), traderWNad);
        vm.expectRevert(bytes(ERR_INVALID_FEE));
        core.buyWNadAmountOutMin(2 ether, amountOutMin, 0.01 ether, address(token), trader, deadline);
    }

    /**
     * @dev BuyAmountOutMinWithPermit Test
     */
    function testBuyAmountOutMinNadPermit() public {
        vm.startPrank(trader);
        uint256 ownerBalance = IERC4626(vault).totalAssets();
        uint256 traderNad = 1.01 ether;
        vm.deal(trader, traderNad);
        wNad.deposit{value: traderNad}();
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 deadline = block.timestamp + 1;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                wNad.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(wNad.PERMIT_TYPEHASH(), trader, address(core), traderNad, 0, deadline))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);

        core.buyWNadAmountOutMinPermit(1 ether, 10, 0.01 ether, address(token), trader, trader, deadline, v, r, s);

        vm.stopPrank();

        assertEq(token.balanceOf(trader), amountOut);
        assertEq(wNad.balanceOf(trader), 0);
        assertEq(IERC4626(vault).totalAssets(), ownerBalance + 0.01 ether);
    }

    function testInvalidPermitBuyAmountOutMinNadPermit() public {
        vm.startPrank(trader);
        uint256 traderNad = 1.01 ether;
        vm.deal(trader, traderNad);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 deadline = block.timestamp + 1;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                wNad.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(wNad.PERMIT_TYPEHASH(), trader, address(core), traderNad + 1, 0, deadline))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);
        vm.expectRevert(bytes(ERR_INVALID_SIGNATURE));
        core.buyWNadAmountOutMinPermit(1 ether, 10, 0.01 ether, address(token), trader, trader, deadline, v, r, s);
    }

    function testInvalidFeeBuyAmountOutMinNadPermit() public {
        vm.startPrank(trader);
        uint256 traderNad = 2.01 ether;
        vm.deal(trader, traderNad);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 deadline = block.timestamp + 1;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                wNad.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(wNad.PERMIT_TYPEHASH(), trader, address(core), traderNad + 1, 0, deadline))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);
        vm.expectRevert(bytes(ERR_INVALID_SIGNATURE));
        core.buyWNadAmountOutMinPermit(2 ether, 10, 0.01 ether, address(token), trader, trader, deadline, v, r, s);
    }

    /**
     * @dev Buy ExactAmountOut Test
     */
    function testBuyExactAmountOut() public {
        vm.startPrank(trader);
        uint256 ownerBalance = IERC4626(vault).totalAssets();
        //1 ether 로 살 수 있는 토큰의 양 계산
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);

        uint256 amountIn = NadsPumpLibrary.getAmountIn(amountOut, k, virtualNad, virtualToken); //1 ether
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(amountIn, feeDenominator, feeNumerator); //0.01 ether;

        uint256 totalAmountIn = amountIn + feeAmount;
        uint256 traderBalance = 2 ether;

        vm.deal(trader, traderBalance);

        uint256 deadline = block.timestamp + 1;

        core.buyExactAmountOut{value: traderBalance}(amountOut, traderBalance, address(token), trader, deadline);
        vm.stopPrank();

        assertEq(token.balanceOf(trader), amountOut);
        //2ether 를 보냈지만 1.01 만썻으므로 trader.balance = 990000000000000000
        assertEq(trader.balance, traderBalance - totalAmountIn);
        assertEq(IERC4626(vault).totalAssets(), ownerBalance + feeAmount);
    }

    function testInvalidValuebuyExactAmountOut() public {
        vm.startPrank(trader);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 amountIn = NadsPumpLibrary.getAmountIn(amountOut, k, virtualNad, virtualToken);
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(amountIn, feeDenominator, feeNumerator);
        uint256 totalAmountIn = amountIn + feeAmount;
        uint256 traderBalance = 2 ether;
        vm.deal(trader, traderBalance);

        uint256 deadline = block.timestamp + 1;

        vm.expectRevert(bytes(ERR_INVALID_SEND_NAD));
        core.buyExactAmountOut{value: traderBalance - 1}(amountOut, traderBalance, address(token), trader, deadline);
    }

    function testOverflowAmountInMaxBuyExactAmountOut() public {
        vm.startPrank(trader);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 amountIn = NadsPumpLibrary.getAmountIn(amountOut, k, virtualNad, virtualToken);
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(amountIn, feeDenominator, feeNumerator);
        uint256 totalAmountIn = amountIn + feeAmount;
        uint256 traderBalance = 1.01 ether;
        vm.deal(trader, traderBalance);

        uint256 deadline = block.timestamp + 1;
        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_IN_MAX));
        core.buyExactAmountOut{value: traderBalance}(
            amountOut + 100, traderBalance, address(token), trader, deadline
        );
    }

    /**
     * @dev buy ExactAmountOut Nad  Test
     */
    function testBuyExactAmountOutWNad() public {
        vm.startPrank(trader);
        uint256 ownerBalance = IERC4626(vault).totalAssets();
        //1 ether 로 살 수 있는 토큰의 양 계산
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);

        uint256 amountIn = NadsPumpLibrary.getAmountIn(amountOut, k, virtualNad, virtualToken); //1 ether
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(amountIn, feeDenominator, feeNumerator); //0.01 ether;

        uint256 totalAmountIn = amountIn + feeAmount;
        uint256 traderBalance = 2 ether;

        vm.deal(trader, traderBalance);

        uint256 deadline = block.timestamp + 1;
        wNad.deposit{value: traderBalance}();

        wNad.approve(address(core), traderBalance);
        core.buyExactAmountOutWNad(amountOut, traderBalance, address(token), trader, deadline);
        vm.stopPrank();

        assertEq(token.balanceOf(trader), amountOut);
        //2ether 를 보냈지만 1.01 만썻으므로 trader.balance = 990000000000000000
        assertEq(wNad.balanceOf(trader), traderBalance - totalAmountIn);
        assertEq(IERC4626(vault).totalAssets(), ownerBalance + feeAmount);
    }

    function testInvalidAmountOutBuyExactAmountOutWNad() public {
        vm.startPrank(trader);
        uint256 ownerBalance = IERC4626(vault).totalAssets();
        //1 ether 로 살 수 있는 토큰의 양 계산
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);

        uint256 amountIn = NadsPumpLibrary.getAmountIn(amountOut, k, virtualNad, virtualToken); //1 ether
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(amountIn, feeDenominator, feeNumerator); //0.01 ether;

        uint256 totalAmountIn = amountIn + feeAmount;
        uint256 traderBalance = 1.01 ether;

        vm.deal(trader, traderBalance);

        uint256 deadline = block.timestamp + 1;
        wNad.deposit{value: traderBalance}();
        wNad.approve(address(core), traderBalance);
        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_OUT));
        core.buyExactAmountOutWNad(0, traderBalance, address(token), trader, deadline);
    }

    function testInvalidAmountInMaxBuyExactAmountOutWNad() public {
        vm.startPrank(trader);
        uint256 ownerBalance = IERC4626(vault).totalAssets();
        //1 ether 로 살 수 있는 토큰의 양 계산
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);

        uint256 amountIn = NadsPumpLibrary.getAmountIn(amountOut, k, virtualNad, virtualToken); //1 ether
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(amountIn, feeDenominator, feeNumerator); //0.01 ether;

        uint256 totalAmountIn = amountIn + feeAmount;
        uint256 traderBalance = 1.01 ether;

        vm.deal(trader, traderBalance);

        uint256 deadline = block.timestamp + 1;
        wNad.deposit{value: traderBalance}();
        wNad.approve(address(core), traderBalance);
        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_IN_MAX));
        uint256 amountInMax = traderBalance - 1;
        core.buyExactAmountOutWNad(amountOut, amountInMax, address(token), trader, deadline);
    }
    /**
     * @dev Buy ExactAmountOut Permit Test
     */

    function testBuyExactAmountOutWNadPermit() public {
        vm.startPrank(trader);
        uint256 ownerBalance = IERC4626(vault).totalAssets();
        //1 ether 로 살 수 있는 토큰의 양 계산
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);

        uint256 amountIn = NadsPumpLibrary.getAmountIn(amountOut, k, virtualNad, virtualToken); //1 ether
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(amountIn, feeDenominator, feeNumerator); //0.01 ether;

        uint256 totalAmountIn = amountIn + feeAmount;
        uint256 traderBalance = 2 ether;

        vm.deal(trader, traderBalance);

        uint256 deadline = block.timestamp + 1;
        wNad.deposit{value: traderBalance}();
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                wNad.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(wNad.PERMIT_TYPEHASH(), trader, address(core), traderBalance, 0, deadline))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);

        core.buyExactAmountOutWNadPermit(
            amountOut, traderBalance, address(token), trader, trader, deadline, v, r, s
        );
        vm.stopPrank();

        assertEq(token.balanceOf(trader), amountOut);

        assertEq(wNad.balanceOf(trader), traderBalance - totalAmountIn);
        assertEq(IERC4626(vault).totalAssets(), ownerBalance + feeAmount);
    }

    function testInvalidPermitBuyExactAmountOutWNadPermit() public {
        vm.startPrank(trader);
        uint256 ownerBalance = IERC4626(vault).totalAssets();
        //1 ether 로 살 수 있는 토큰의 양 계산
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);

        uint256 amountIn = NadsPumpLibrary.getAmountIn(amountOut, k, virtualNad, virtualToken); //1 ether
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(amountIn, feeDenominator, feeNumerator); //0.01 ether;

        uint256 totalAmountIn = amountIn + feeAmount;
        uint256 traderBalance = 2 ether;

        vm.deal(trader, traderBalance);
        wNad.deposit{value: traderBalance}();

        uint256 deadline = block.timestamp + 1;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                wNad.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(wNad.PERMIT_TYPEHASH(), trader, address(core), traderBalance, 0, deadline))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);
        vm.expectRevert(bytes(ERR_INVALID_SIGNATURE));
        core.buyExactAmountOutWNadPermit(
            amountOut, traderBalance - 1, address(token), trader, trader, deadline, v, r, s
        );
        vm.stopPrank();
    }

    /**
     * @dev Sell Test
     */
    function testSell() public {
        testBuy();
        vm.startPrank(trader);
        uint256 ownerBalance = IERC4626(vault).totalAssets();
        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        uint256 nadAmount = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(nadAmount, feeDenominator, feeNumerator);

        uint256 deadline = block.timestamp + 1;
        token.approve(address(core), traderTokenBalance);
        core.sell(traderTokenBalance, address(token), trader, deadline);
        vm.stopPrank();

        assertEq(token.balanceOf(trader), 0);
        assertEq(trader.balance, nadAmount - feeAmount);
        assertEq(IERC4626(vault).totalAssets(), ownerBalance + feeAmount);
    }

    function testInvalidAllowanceSell() public {
        testBuy();

        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        uint256 nadAmount = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(nadAmount, feeDenominator, feeNumerator);

        uint256 deadline = block.timestamp + 1;
        vm.startPrank(trader);
        token.approve(address(core), traderTokenBalance);
        vm.expectRevert(bytes(ERR_INVALID_ALLOWANCE));

        core.sell(traderTokenBalance + 1, address(token), trader, deadline);
        vm.stopPrank();
    }

    /**
     * @dev Sell Permit Test
     */
    function testSellPermit() public {
        testBuy();
        vm.startPrank(trader);
        uint256 ownerBalance = IERC4626(vault).totalAssets();
        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        uint256 nadAmount = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(nadAmount, feeDenominator, feeNumerator);

        uint256 deadline = block.timestamp + 1;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(token.PERMIT_TYPEHASH(), trader, address(core), traderTokenBalance, 0, deadline)
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);

        token.approve(address(core), traderTokenBalance);
        core.sellPermit(traderTokenBalance, address(token), trader, trader, deadline, v, r, s);
        vm.stopPrank();

        assertEq(token.balanceOf(trader), 0);
        assertEq(trader.balance, nadAmount - feeAmount);
        assertEq(IERC4626(vault).totalAssets(), ownerBalance + feeAmount);
    }

    function testInvalidSignatureSellPermit() public {
        testBuy();
        vm.startPrank(trader);
        uint256 ownerBalance = IERC4626(vault).totalAssets();
        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        uint256 nadAmount = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(nadAmount, feeDenominator, feeNumerator);

        uint256 deadline = block.timestamp + 1;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(token.PERMIT_TYPEHASH(), trader, address(core), traderTokenBalance - 1, 0, deadline)
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);

        token.approve(address(core), traderTokenBalance);
        vm.expectRevert(bytes(ERR_INVALID_SIGNATURE));
        core.sellPermit(traderTokenBalance, address(token), trader, trader, deadline, v, r, s);
        vm.stopPrank();
    }

    function testSellAmountOutMin() public {
        testBuy();
        vm.startPrank(trader);
        uint256 ownerBalance = IERC4626(vault).totalAssets();
        uint256 traderTokenBalance = token.balanceOf(trader);
        console.log(traderTokenBalance);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        uint256 nadAmountOut = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);

        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(nadAmountOut, feeDenominator, feeNumerator);

        nadAmountOut -= feeAmount;
        uint256 deadline = block.timestamp + 1;
        token.approve(address(core), traderTokenBalance);
        core.sellAmountOutMin(traderTokenBalance, 10, address(token), trader, deadline);
        vm.stopPrank();

        assertEq(token.balanceOf(trader), 0);
        assertEq(trader.balance, nadAmountOut);
        assertEq(IERC4626(vault).totalAssets(), ownerBalance + feeAmount);
    }

    function testInvalidAllonwaceSellAmountOutMin() public {
        testBuy();

        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        uint256 nadAmount = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(nadAmount, feeDenominator, feeNumerator);

        uint256 deadline = block.timestamp + 1;
        vm.startPrank(trader);
        token.approve(address(core), traderTokenBalance - 1);
        vm.expectRevert(bytes(ERR_INVALID_ALLOWANCE));
        core.sellAmountOutMin(traderTokenBalance, nadAmount, address(token), trader, deadline);
        vm.stopPrank();
    }

    function testOverflowAmountOutSellAmountOutMin() public {
        testBuy();

        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        uint256 nadAmount = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(nadAmount, feeDenominator, feeNumerator);

        uint256 deadline = block.timestamp + 1;
        vm.startPrank(trader);
        token.approve(address(core), traderTokenBalance);
        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_OUT));
        core.sellAmountOutMin(traderTokenBalance, nadAmount + 1, address(token), trader, deadline);
        vm.stopPrank();
    }

    /**
     * @dev SellAmountOutMinWithPermit Test
     */
    function testSellAmountOutMinWithPermit() public {
        testBuy();
        //---------Buy End----------------------
        vm.startPrank(trader);
        uint256 traderTokenBalance = token.balanceOf(trader);
        uint256 ownerBalance = IERC4626(vault).totalAssets();
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        uint256 nadAmountOut = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);

        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(nadAmountOut, feeDenominator, feeNumerator);

        nadAmountOut -= feeAmount;
        uint256 deadline = block.timestamp + 1;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(token.PERMIT_TYPEHASH(), trader, address(core), traderTokenBalance, 0, deadline)
                )
            )
        );
        // console.logBytes32(digest);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);

        core.sellAmountOutMinWithPermit(traderTokenBalance, 10, address(token), trader, trader, deadline, v, r, s);

        assertEq(token.balanceOf(trader), 0);
        assertEq(trader.balance, nadAmountOut);
        assertEq(IERC4626(vault).totalAssets(), ownerBalance + feeAmount);
    }

    function testInvalidAmountOutSellAmountOutMinWithPermit() public {
        testBuy();
        //---------Buy End----------------------
        vm.startPrank(trader);
        uint256 traderTokenBalance = token.balanceOf(trader);

        (virtualNad, virtualToken) = curve.getVirtualReserves();
        uint256 nadAmountOut = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);

        uint256 feeAmountOut = NadsPumpLibrary.getFeeAmount(nadAmountOut, feeDenominator, feeNumerator);

        nadAmountOut -= feeAmountOut;
        uint256 deadline = block.timestamp + 1;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(token.PERMIT_TYPEHASH(), trader, address(core), traderTokenBalance, 0, deadline)
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);
        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_OUT));
        core.sellAmountOutMinWithPermit(
            traderTokenBalance, nadAmountOut + 1, address(token), trader, trader, deadline, v, r, s
        );
    }

    /**
     * @dev SellExactAmountOut Test
     */
    function testSellExactAmountOut() public {
        testBuy();
        vm.startPrank(trader);

        uint256 ownerBalance = IERC4626(vault).totalAssets();
        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        //nadAmount
        uint256 amountOut = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);

        uint256 wantedAmountOut = 500_000_000_000_000_000;
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(wantedAmountOut, feeDenominator, feeNumerator);
        vm.deal(trader, feeAmount);
        console.log("wanted Amount = ", 500_000_000_000_000_000);
        // console.log("wanted Amount = ", amountOut / 2);
        uint256 deadline = block.timestamp + 1;
        token.approve(address(core), traderTokenBalance);
        core.sellExactAmountOut{value: feeAmount}(
            wantedAmountOut, traderTokenBalance, address(token), trader, deadline
        );
        // console.log("Recieved Nad", trader.balance);
        vm.stopPrank();

        //Sell 일경우 amountOut 에 1%를 더한 금액을 인출할 amountIn 을 해야 함.
        uint256 amountIn = NadsPumpLibrary.getAmountIn(wantedAmountOut, k, virtualToken, virtualNad);

        vm.stopPrank();
        // console.log("totalAmountIn = ", totalAmountIn);
        assertEq(token.balanceOf(trader), traderTokenBalance - amountIn);
        assertEq(trader.balance, wantedAmountOut);
        assertEq(IERC4626(vault).totalAssets(), ownerBalance + feeAmount);
    }

    function testInvalidAllowacneSellExactAmountOut() public {
        testBuy();
        vm.startPrank(trader);
        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        //nadAmount
        uint256 amountOut = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);

        uint256 wantedAmountOut = amountOut / 2;
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(wantedAmountOut, feeDenominator, feeNumerator);
        vm.deal(trader, feeAmount);
        uint256 deadline = block.timestamp + 1;
        token.approve(address(core), traderTokenBalance - 1);
        vm.expectRevert(bytes(ERR_INVALID_ALLOWANCE));
        core.sellExactAmountOut{value: feeAmount}(
            wantedAmountOut, traderTokenBalance, address(token), trader, deadline
        );
        // console.log("Recieved Nad", trader.balance);
        vm.stopPrank();
    }

    function testOverflowAmountInMaxsellExactAmountOut() public {
        testBuy();
        vm.startPrank(trader);
        uint256 traderTokenBalance = token.balanceOf(trader);
        console.log("Trader Token Balance =", traderTokenBalance);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        //Nad
        uint256 maxAmountOut = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad) + 1;
        console.log("Max AmountOut = ", maxAmountOut);
        //Nad
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(maxAmountOut, feeDenominator, feeNumerator);
        vm.deal(trader, feeAmount);
        uint256 deadline = block.timestamp + 1;
        token.approve(address(core), traderTokenBalance);
        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_IN_MAX));
        core.sellExactAmountOut{value: feeAmount}(
            maxAmountOut, traderTokenBalance, address(token), trader, deadline
        );
        // console.log("Recieved Nad", trader.balance);
        vm.stopPrank();
    }

    /**
     * @dev SellExactAmountOutWithPermit Test
     */
    function testSellExactAmountOutWithPermit() public {
        testBuy();
        vm.startPrank(trader);
        uint256 ownerBalance = IERC4626(vault).totalAssets();
        uint256 traderTokenBalance = token.balanceOf(trader);
        // console.log("TraderTokenBalance = ", traderTokenBalance);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        //nadAmount

        // uint256 amountOut = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);
        uint256 wantedAmountOut = 500_000_000_000_000_000;
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(wantedAmountOut, feeDenominator, feeNumerator);
        // console.log("wanted Amount = ", amountOut / 2);
        vm.deal(trader, feeAmount);
        uint256 deadline = block.timestamp + 1;

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(token.PERMIT_TYPEHASH(), trader, address(core), traderTokenBalance, 0, deadline)
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);

        core.sellExactAmountOutwithPermit{value: feeAmount}(
            wantedAmountOut, traderTokenBalance, address(token), trader, trader, deadline, v, r, s
        );

        vm.stopPrank();

        //Sell 일경우 amountOut 에 1%를 더한 금액을 인출할 amountIn 을 해야 함.

        uint256 amountIn = NadsPumpLibrary.getAmountIn(wantedAmountOut, k, virtualToken, virtualNad);

        assertEq(token.balanceOf(trader), traderTokenBalance - amountIn);
        assertEq(trader.balance, wantedAmountOut);
        //buy 1 ether -> 0.01 protocol fee
        assertEq(IERC4626(vault).totalAssets(), ownerBalance + feeAmount);
        // (uint256 virtualNad, uint256 virtualToken) = curve.getVirtualReserves();
        // console.log(virtualNad);
        // console.log(virtualToken);
        // console.log(trader.balance);
        // console.log(token.balanceOf(trader));
        // console.log(IERC4626(vault).totalAssets());
    }

    function testOverflowAmountInMaxSellExactAmountOutWithPermit() public {
        testBuy();
        vm.startPrank(trader);
        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        //nadAmount
        uint256 amountOut = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(amountOut + 1, feeDenominator, feeNumerator);
        vm.deal(trader, feeAmount);
        // console.log("wanted Amount = ", amountOut / 2);
        uint256 deadline = block.timestamp + 1;
        // token.approve(address(core), traderTokenBalance);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(token.PERMIT_TYPEHASH(), trader, address(core), traderTokenBalance, 0, deadline)
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);
        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_IN_MAX));
        core.sellExactAmountOutwithPermit{value: feeAmount}(
            amountOut + 1, traderTokenBalance, address(token), trader, trader, deadline, v, r, s
        );

        vm.stopPrank();
    }
    /**
     * TestCase for BondingCurve
     */

    function testOverflowTrargetBondingCurveBuy() public {
        vm.startPrank(trader);

        uint256 maximalAmountOut = tokenTotalSupply - targetToken;
        uint256 amountIn = NadsPumpLibrary.getAmountIn(maximalAmountOut, k, virtualNad, virtualToken) + 1;
        uint256 fee = amountIn / 100;
        console.log("Amount In = ", amountIn);
        vm.deal(trader, amountIn + fee);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(amountIn, k, virtualNad, virtualToken);
        uint256 deadline = block.timestamp + 1;
        vm.expectRevert(bytes(ERR_OVERFLOW_TARGET));
        core.buy{value: amountIn + fee}(amountIn, fee, address(token), trader, deadline);
        vm.stopPrank();
    }

    function testBondingCurveBuyInvalidFee() public {
        vm.startPrank(trader);
        uint256 amountIn = 1 ether;
        uint256 fee = (amountIn / 100) - 1;
        vm.deal(trader, amountIn + fee);

        uint256 amountOut = NadsPumpLibrary.getAmountOut(amountIn, k, virtualNad, virtualToken);
        uint256 deadline = block.timestamp + 1;
        vm.expectRevert(bytes(ERR_INVALID_FEE));
        core.buy{value: amountIn + fee}(amountIn, fee, address(token), trader, deadline);
        vm.stopPrank();
    }

    function testBondingCurveSellInvalidAmountIn() public {
        testBuy();
        vm.startPrank(trader);
        uint256 amountIn = 0 ether;
        uint256 traderTokenBalance = token.balanceOf(trader);
        token.approve(address(core), traderTokenBalance);
        uint256 deadline = block.timestamp + 1;
        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_IN));
        core.sell(0, address(token), trader, deadline);
    }
}
