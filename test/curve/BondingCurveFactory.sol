// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BondingCurveFactory} from "../../src/curve/BondingCurveFactory.sol";
import {SetUp} from "../SetUp.sol";
import {ERR_ONLY_OWNER} from "../../src/curve/errors/Error.sol";

contract BondingCurveFactoryTest is Test, SetUp {
    function testBondingCurveCreate() public {
        CurveCreate(OWNER);
    }

    function testInitialize() public {
        vm.startPrank(OWNER);

        uint256 deployFee = 0;
        uint256 listingFee = 0;
        uint256 tokenTotalSupply = 1 ether;
        uint256 virtualNad = 1 ether;
        uint256 virtualToken = 1 ether;
        uint256 targetToken = 1 ether;
        uint16 feeNumerator = 1;
        uint8 feeDenominator = 1;
        address dexFactoryAddr = makeAddr("DEX_FACTORY");
        address vaultAddr = makeAddr("VAULT");
        address wnadAddr = makeAddr("WNAD");

        BONDING_CURVE_FACTORY.initialize(
            BondingCurveFactory.InitializeParams({
                deployFee: deployFee,
                listingFee: listingFee,
                tokenTotalSupply: tokenTotalSupply,
                virtualNad: virtualNad,
                virtualToken: virtualToken,
                targetToken: targetToken,
                feeNumerator: feeNumerator,
                feeDenominator: feeDenominator,
                dexFactory: dexFactoryAddr,
                vault: vaultAddr,
                wnad: wnadAddr
            })
        );

        // 초기화 후 값들을 확인
        BondingCurveFactory.Config memory config = BONDING_CURVE_FACTORY.getConfig();

        assertEq(config.deployFee, deployFee, "Deploy fee mismatch");
        assertEq(config.listingFee, listingFee, "Listing fee mismatch");
        assertEq(config.tokenTotalSupply, tokenTotalSupply, "Token total supply mismatch");
        assertEq(config.virtualNad, virtualNad, "Virtual NAD mismatch");
        assertEq(config.virtualToken, virtualToken, "Virtual token mismatch");
        assertEq(config.k, virtualNad * virtualToken, "K value mismatch");
        assertEq(config.targetToken, targetToken, "Target token mismatch");
        assertEq(config.feeNumerator, feeNumerator, "Fee numerator mismatch");
        assertEq(config.feeDenominator, feeDenominator, "Fee denominator mismatch");

        assertEq(BONDING_CURVE_FACTORY.getDexFactory(), dexFactoryAddr, "DEX factory address mismatch");
        assertEq(BONDING_CURVE_FACTORY.getVault(), vaultAddr, "Vault address mismatch");

        vm.stopPrank();
    }

    function testInitializeFailNotOwner() public {
        vm.startPrank(TRADER_A);
        vm.expectRevert(bytes(ERR_ONLY_OWNER));
        uint256 deployFee = 0;
        uint256 listingFee = 0;
        uint256 tokenTotalSupply = 1 ether;
        uint256 virtualNad = 1 ether;
        uint256 virtualToken = 1 ether;
        uint256 targetToken = 1 ether;
        uint16 feeNumerator = 1;
        uint8 feeDenominator = 1;
        address dexFactoryAddr = makeAddr("DEX_FACTORY");
        address vaultAddr = makeAddr("VAULT");

        address wnadAddr = makeAddr("WNAD");
        BONDING_CURVE_FACTORY.initialize(
            BondingCurveFactory.InitializeParams({
                deployFee: deployFee,
                listingFee: listingFee,
                tokenTotalSupply: tokenTotalSupply,
                virtualNad: virtualNad,
                virtualToken: virtualToken,
                targetToken: targetToken,
                feeNumerator: feeNumerator,
                feeDenominator: feeDenominator,
                dexFactory: dexFactoryAddr,
                vault: vaultAddr,
                wnad: wnadAddr
            })
        );
        vm.stopPrank();
    }

    function testSetOwner() public {
        vm.startPrank(OWNER);
        BONDING_CURVE_FACTORY.setOwner(makeAddr("NEW_OWNER"));
        vm.stopPrank();
        assertEq(BONDING_CURVE_FACTORY.getOwner(), makeAddr("NEW_OWNER"), "Owner mismatch");
    }
}
