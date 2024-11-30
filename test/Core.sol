// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console, Vm} from "forge-std/Test.sol";
import {BondingCurve} from "src/BondingCurve.sol";
import {Token} from "src/Token.sol";
import "src/errors/Errors.sol";
import {IWNAD} from "src/interfaces/IWNAD.sol";
import {WNAD} from "src/WNAD.sol";
import {NadFunLibrary} from "src/utils/NadFunLibrary.sol";
import {Core} from "src/Core.sol";
import {FeeVault} from "src/FeeVault.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "./SetUp.sol";

contract CoreCreateTest is Test, SetUp {
    // ============ Success Tests ============
    function testCreateCurveSuccess() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, DEPLOY_FEE);

        (
            address curveAddress,
            address tokenAddress,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 amountOut
        ) = CORE.createCurve{value: DEPLOY_FEE}(
                TRADER_A,
                "Test Token",
                "TEST",
                "test.url",
                0,
                0
            );

        // Verify curve and token addresses are valid
        assertTrue(curveAddress != address(0));
        assertTrue(tokenAddress != address(0));

        // Verify token properties
        Token token = Token(tokenAddress);
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.totalSupply(), TOKEN_TOTAL_SUPPLY);

        // Verify initial virtual reserves
        (uint256 vNad, uint256 vToken) = BondingCurve(payable(curveAddress))
            .getVirtualReserves();
        assertEq(vNad, virtualNad);
        assertEq(vToken, virtualToken);

        // Verify fees went to vault
        assertEq(IERC4626(FEE_VAULT).totalAssets(), DEPLOY_FEE);

        vm.stopPrank();
    }

    function testCreateCurveWithInitialLiquidity() public {
        vm.startPrank(OWNER);
        uint256 initialNad = 1 ether;
        uint256 fee = initialNad / 100; // 1% fee
        vm.deal(OWNER, initialNad + fee + DEPLOY_FEE);

        (
            address curveAddress,
            address tokenAddress,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 amountOut
        ) = CORE.createCurve{value: initialNad + fee + DEPLOY_FEE}(
                TRADER_A,
                "Test Token",
                "TEST",
                "test.url",
                initialNad,
                fee
            );

        // Verify curve and token creation
        assertTrue(curveAddress != address(0));
        assertTrue(tokenAddress != address(0));

        // Verify initial liquidity
        (uint256 vNad, uint256 vToken) = BondingCurve(payable(curveAddress))
            .getVirtualReserves();
        assertEq(vNad, virtualNad);
        assertTrue(amountOut > 0);

        // Verify fees went to vault
        assertEq(IERC4626(FEE_VAULT).totalAssets(), fee + DEPLOY_FEE);

        vm.stopPrank();
    }

    // ============ Failure Test ============
    function testCreateCurveInsufficientDeployFee() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, DEPLOY_FEE - 1);

        vm.expectRevert(bytes(ERR_CORE_INVALID_SEND_NAD));
        CORE.createCurve{value: DEPLOY_FEE - 1}(
            TRADER_A,
            "Test Token",
            "TEST",
            "test.url",
            0,
            0
        );

        vm.stopPrank();
    }

    function testCreateCurveInvalidInitialAmount() public {
        vm.startPrank(OWNER);
        uint256 initialNad = 1 ether;
        uint256 fee = initialNad / 100; // 1% fee
        vm.deal(OWNER, initialNad + fee + DEPLOY_FEE - 1);

        vm.expectRevert(bytes(ERR_CORE_INVALID_SEND_NAD));
        CORE.createCurve{value: initialNad + fee + DEPLOY_FEE - 1}(
            TRADER_A,
            "Test Token",
            "TEST",
            "test.url",
            initialNad,
            fee
        );

        vm.stopPrank();
    }

    function testCreateCurveInvalidFee() public {
        vm.startPrank(OWNER);
        uint256 initialNad = 1 ether;
        uint256 fee = initialNad / 200; // 0.5% fee (less than required 1%)
        vm.deal(OWNER, initialNad + fee + DEPLOY_FEE);

        vm.expectRevert(bytes(ERR_CORE_INVALID_FEE));
        CORE.createCurve{value: initialNad + fee + DEPLOY_FEE}(
            TRADER_A,
            "Test Token",
            "TEST",
            "test.url",
            initialNad,
            fee
        );

        vm.stopPrank();
    }
}

contract CoreBuyTest is Test, SetUp {}

contract CoreSellTest is Test, SetUp {}
