// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SetUp} from "./SetUp.sol";
import "../src/errors/Errors.sol";

contract MintPartyTest is Test, SetUp {
    function testCreate() public {
        CreateMintParty(CREATOR);
        assertEq(MINT_PARTY.getFinished(), false);
        assertEq(MINT_PARTY.getOwner(), CREATOR);
        assertEq(MINT_PARTY.getBalance(CREATOR), MINT_PARTY_FUNDING_AMOUNT);
    }

    function testCloseOnlyOwner() public {
        CreateMintParty(CREATOR);
        // vm.startPrank(TRADER_A);
        // vm.expectRevert(bytes(ERR_MINT_PARTY_ONLY_OWNER));
        // MINT_PARTY.withdraw();
        // vm.stopPrank();

        vm.startPrank(CREATOR);
        MINT_PARTY.withdraw();
        vm.stopPrank();
        assertEq(MINT_PARTY.getFinished(), true);
    }

    function testCloseWithFailDeposit() public {
        CreateMintParty(CREATOR);
        vm.startPrank(CREATOR);
        MINT_PARTY.withdraw();
        vm.stopPrank();

        vm.startPrank(TRADER_A);
        vm.deal(TRADER_A, MINT_PARTY_FUNDING_AMOUNT);
        // wNAD.deposit{value: MINT_PARTY_FUNDING_AMOUNT}();
        // wNAD.transfer(address(MINT_PARTY), MINT_PARTY_FUNDING_AMOUNT);
        vm.expectRevert(bytes(ERR_MINT_PARTY_FINISHED));
        MINT_PARTY.deposit{value: MINT_PARTY_FUNDING_AMOUNT}(TRADER_A);
        vm.stopPrank();
    }

    function testDeposit() public {
        CreateMintParty(CREATOR);
        vm.startPrank(TRADER_A);
        vm.deal(TRADER_A, MINT_PARTY_FUNDING_AMOUNT);
        // wNAD.deposit{value: MINT_PARTY_FUNDING_AMOUNT}();
        // wNAD.transfer(address(MINT_PARTY), MINT_PARTY_FUNDING_AMOUNT);
        MINT_PARTY.deposit{value: MINT_PARTY_FUNDING_AMOUNT}(TRADER_A);
        vm.stopPrank();
        assertEq(MINT_PARTY.getBalance(TRADER_A), MINT_PARTY_FUNDING_AMOUNT);
    }

    function testAlreadyDeposit() public {
        CreateMintParty(CREATOR);
        //init deposit
        vm.startPrank(TRADER_B);
        vm.deal(TRADER_B, MINT_PARTY_FUNDING_AMOUNT);
        // wNAD.deposit{value: MINT_PARTY_FUNDING_AMOUNT}();
        // wNAD.transfer(address(MINT_PARTY), MINT_PARTY_FUNDING_AMOUNT);
        MINT_PARTY.deposit{value: MINT_PARTY_FUNDING_AMOUNT}(TRADER_B);

        //invalid deposit
        vm.deal(TRADER_B, MINT_PARTY_FUNDING_AMOUNT);
        // wNAD.deposit{value: MINT_PARTY_FUNDING_AMOUNT}();
        // wNAD.transfer(address(MINT_PARTY), MINT_PARTY_FUNDING_AMOUNT);
        vm.expectRevert(bytes(ERR_MINT_PARTY_ALREADY_DEPOSITED));
        MINT_PARTY.deposit{value: MINT_PARTY_FUNDING_AMOUNT}(TRADER_B);
        vm.stopPrank();
    }

    function testFundingAmountMoreThanDeposit() public {
        CreateMintParty(CREATOR);
        //Invalid Funding AMount
        vm.startPrank(TRADER_A);
        uint256 fundingAmount = MINT_PARTY_FUNDING_AMOUNT + 100;
        vm.deal(TRADER_A, fundingAmount);
        // wNAD.deposit{value: fundingAmount}();
        // wNAD.transfer(address(MINT_PARTY), fundingAmount);
        vm.expectRevert(bytes(ERR_MINT_PARTY_INVALID_FUNDING_AMOUNT));
        MINT_PARTY.deposit{value: fundingAmount}(TRADER_A);
        assertEq(MINT_PARTY.getBalance(TRADER_A), 0);
        vm.stopPrank();
    }

    function testWithdraw() public {
        CreateMintParty(CREATOR);
        vm.startPrank(TRADER_A);
        vm.deal(TRADER_A, MINT_PARTY_FUNDING_AMOUNT);
        // wNAD.deposit{value: MINT_PARTY_FUNDING_AMOUNT}();
        // wNAD.transfer(address(MINT_PARTY), MINT_PARTY_FUNDING_AMOUNT);
        MINT_PARTY.deposit{value: MINT_PARTY_FUNDING_AMOUNT}(TRADER_A);
        vm.stopPrank();

        vm.startPrank(TRADER_A);
        MINT_PARTY.withdraw();
        vm.stopPrank();
        assertEq(MINT_PARTY.getBalance(TRADER_A), 0);
        assertEq(TRADER_A.balance, MINT_PARTY_FUNDING_AMOUNT);
    }

    function testAddWhiteList() public {
        CreateMintParty(CREATOR);
        vm.startPrank(TRADER_A);
        vm.deal(TRADER_A, MINT_PARTY_FUNDING_AMOUNT);
        // wNAD.deposit{value: MINT_PARTY_FUNDING_AMOUNT}();
        // wNAD.transfer(address(MINT_PARTY), MINT_PARTY_FUNDING_AMOUNT);
        MINT_PARTY.deposit{value: MINT_PARTY_FUNDING_AMOUNT}(TRADER_A);
        vm.stopPrank();

        vm.startPrank(CREATOR);
        vm.expectRevert(bytes(ERR_MINT_PARTY_BALANCE_ZERO));
        address[] memory whitelist = new address[](2);
        whitelist[0] = TRADER_A;
        whitelist[1] = TRADER_B;
        MINT_PARTY.addWhiteList(whitelist);

        address[] memory whitelistAccounts = MINT_PARTY.getWhitelistAccounts();
        assertEq(whitelistAccounts.length, 0);
        assertEq(MINT_PARTY.getBalance(TRADER_A), MINT_PARTY_FUNDING_AMOUNT);
    }

    function testAddWhiteListWithdraw() public {
        CreateMintParty(CREATOR);
        vm.startPrank(TRADER_A);
        vm.deal(TRADER_A, MINT_PARTY_FUNDING_AMOUNT);
        // wNAD.deposit{value: MINT_PARTY_FUNDING_AMOUNT}();
        // wNAD.transfer(address(MINT_PARTY), MINT_PARTY_FUNDING_AMOUNT);
        MINT_PARTY.deposit{value: MINT_PARTY_FUNDING_AMOUNT}(TRADER_A);
        vm.stopPrank();
        vm.startPrank(CREATOR);
        address[] memory whitelist = new address[](1);
        whitelist[0] = TRADER_A;
        MINT_PARTY.addWhiteList(whitelist);
        vm.stopPrank();

        vm.startPrank(TRADER_A);
        MINT_PARTY.withdraw();
        vm.stopPrank();
        assertEq(MINT_PARTY.getBalance(TRADER_A), 0);
        assertEq(TRADER_A.balance, MINT_PARTY_FUNDING_AMOUNT);
    }

    function testOwnerWithdraw() public {
        CreateMintParty(CREATOR);
        vm.startPrank(CREATOR);
        MINT_PARTY.withdraw();
        vm.stopPrank();
        assertEq(MINT_PARTY.getFinished(), true);
        assertEq(CREATOR.balance, MINT_PARTY_FUNDING_AMOUNT);
    }

    function testCreateBondingCurve() public {
        CreateMintParty(CREATOR);
        for (uint256 i = 0; i < MINT_PARTY_MAXIMUM_PARTICIPANTS; i++) {}
    }
}
