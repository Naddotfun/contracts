// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BondingCurve} from "src/BondingCurve.sol";
import {BondingCurveFactory} from "src/BondingCurveFactory.sol";
import {Token} from "src/Token.sol";
import "src/errors/Errors.sol";
import {IWNative} from "src/interfaces/IWNative.sol";
import {WNative} from "src/WNative.sol";
import {BondingCurveLibrary} from "src/utils/BondingCurveLibrary.sol";
import {Core} from "src/Core.sol";
import {FeeVault} from "src/FeeVault.sol";
import {UniswapV2Factory} from "src/uniswap/UniswapV2Factory.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "./SetUp.sol";

contract BondingCurveFactoryTest is Test, SetUp {
    // ========== Success Cases ==========

    function testInitialization() public {
        // Check initial configuration
        BondingCurveFactory.Config memory config = BONDING_CURVE_FACTORY.getConfig();
        assertEq(config.deployFee, DEPLOY_FEE);
        assertEq(config.listingFee, LISTING_FEE);
        assertEq(config.tokenTotalSupply, TOKEN_TOTAL_SUPPLY);
        assertEq(config.virtualNative, VIRTUAL_NATIVE);
        assertEq(config.virtualToken, VIRTUAL_TOKEN);
        assertEq(config.k, K);
        assertEq(config.targetToken, TARGET_TOKEN);
        assertEq(config.feeNumerator, FEE_NUMERATOR);
        assertEq(config.feeDenominator, FEE_DENOMINATOR);

        // Check owner and WNative
        assertEq(BONDING_CURVE_FACTORY.getOwner(), OWNER);
        assertEq(address(BONDING_CURVE_FACTORY.wNative()), address(WNATIVE));
    }

    function testCreateCurve() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, DEPLOY_FEE);
        // Create new curve through Core
        (address curveAddress, address tokenAddress, uint256 virtualNative, uint256 virtualToken, uint256 amountOut) =
            CORE.createCurve{value: DEPLOY_FEE}(TRADER_A, "Test Token", "TEST", "test.url", 0, 0);

        // Verify curve creation
        assertTrue(curveAddress != address(0));
        assertTrue(tokenAddress != address(0));

        // Check curve mapping
        assertEq(BONDING_CURVE_FACTORY.getCurve(tokenAddress), curveAddress);

        // Verify curve initialization
        BondingCurve curve = BondingCurve(curveAddress);
        Token token = Token(tokenAddress);

        // Check token properties
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.totalSupply(), TOKEN_TOTAL_SUPPLY);

        // Check curve properties
        (uint256 vNad, uint256 vToken) = curve.getVirtualReserves();
        assertEq(vNad, VIRTUAL_NATIVE);
        assertEq(vToken, VIRTUAL_TOKEN);

        vm.stopPrank();
    }

    function testSetOwner() public {
        vm.startPrank(OWNER);
        address newOwner = address(0xdead);
        BONDING_CURVE_FACTORY.setOwner(newOwner);
        assertEq(BONDING_CURVE_FACTORY.getOwner(), newOwner);
        vm.stopPrank();
    }

    function testUpdateConfig() public {
        vm.startPrank(OWNER);

        uint256 newDeployFee = 0.03 ether;
        uint256 newListingFee = 2 ether;
        uint256 newTokenTotalSupply = 2 * 10 ** 27;
        uint256 newVirtualNative = 40 * 10 ** 18;
        uint256 newVirtualToken = 2_073_000_191 * 10 ** 18;
        uint256 newTargetToken = 306_900_000 * 10 ** 18;
        uint16 newFeeNumerator = 2000;
        uint8 newFeeDenominator = 20;

        IBondingCurveFactory.InitializeParams memory params = IBondingCurveFactory.InitializeParams({
            deployFee: newDeployFee,
            listingFee: newListingFee,
            tokenTotalSupply: newTokenTotalSupply,
            virtualNative: newVirtualNative,
            virtualToken: newVirtualToken,
            targetToken: newTargetToken,
            feeNumerator: newFeeNumerator,
            feeDenominator: newFeeDenominator,
            dexFactory: address(DEX_FACTORY)
        });

        BONDING_CURVE_FACTORY.initialize(params);

        // Verify updated config
        BondingCurveFactory.Config memory config = BONDING_CURVE_FACTORY.getConfig();
        assertEq(config.deployFee, newDeployFee);
        assertEq(config.listingFee, newListingFee);
        assertEq(config.tokenTotalSupply, newTokenTotalSupply);
        assertEq(config.virtualNative, newVirtualNative);
        assertEq(config.virtualToken, newVirtualToken);
        assertEq(config.k, newVirtualNative * newVirtualToken);
        assertEq(config.targetToken, newTargetToken);
        assertEq(config.feeNumerator, newFeeNumerator);
        assertEq(config.feeDenominator, newFeeDenominator);

        vm.stopPrank();
    }

    // ========== Failure Cases ==========

    function testRevertNonOwnerSetOwner() public {
        vm.startPrank(TRADER_A);
        vm.expectRevert(bytes(ERR_BONDING_CURVE_FACTORY_ONLY_OWNER));
        BONDING_CURVE_FACTORY.setOwner(TRADER_A);
        vm.stopPrank();
    }

    function testRevertNonOwnerInitialize() public {
        vm.startPrank(TRADER_A);

        IBondingCurveFactory.InitializeParams memory params = IBondingCurveFactory.InitializeParams({
            deployFee: 0.03 ether,
            listingFee: 2 ether,
            tokenTotalSupply: 2 * 10 ** 27,
            virtualNative: 40 * 10 ** 18,
            virtualToken: 2_073_000_191 * 10 ** 18,
            targetToken: 306_900_000 * 10 ** 18,
            feeNumerator: 2000,
            feeDenominator: 20,
            dexFactory: address(DEX_FACTORY)
        });

        vm.expectRevert(bytes(ERR_BONDING_CURVE_FACTORY_ONLY_OWNER));
        BONDING_CURVE_FACTORY.initialize(params);
        vm.stopPrank();
    }

    function testRevertNonCoreCreateCurve() public {
        vm.startPrank(TRADER_A);
        vm.expectRevert(bytes(ERR_BONDING_CURVE_FACTORY_ONLY_CORE));
        BONDING_CURVE_FACTORY.create(TRADER_A, "Test", "TEST", "test.url");
        vm.stopPrank();
    }

    function testRevertInvalidDeployFee() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, DEPLOY_FEE - 1);
        vm.expectRevert(bytes(ERR_CORE_INVALID_SEND_NATIVE));
        CORE.createCurve{value: DEPLOY_FEE - 1}(TRADER_A, "Test", "TEST", "test.url", 0, 0);
        vm.stopPrank();
    }
}
