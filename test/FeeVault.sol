// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {FeeVault} from "src/FeeVault.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IFeeVault} from "src/interfaces/IFeeVault.sol";
import "./SetUpV2.sol";
import "src/errors/Errors.sol";

contract FeeVaultTest is Test, SetUpV2 {
    event WithdrawalProposed(
        uint256 indexed proposalId,
        address receiver,
        uint256 amount
    );
    event WithdrawalSigned(uint256 indexed proposalId, address signer);
    event WithdrawalExecuted(
        uint256 indexed proposalId,
        address receiver,
        uint256 amount
    );

    function setUp() public override {
        super.setUp();
    }

    function testConstructor() public view {
        assertEq(address(FeeVault(FEE_VAULT).wnad()), address(wNAD));

        assertEq(FeeVault(FEE_VAULT).requiredSignatures(), 3);
        assertEq(FeeVault(FEE_VAULT).ownerCount(), 5);

        assertTrue(FeeVault(FEE_VAULT).isOwner(FEE_VAULT_OWNER_A));
        assertTrue(FeeVault(FEE_VAULT).isOwner(FEE_VAULT_OWNER_B));
        assertTrue(FeeVault(FEE_VAULT).isOwner(FEE_VAULT_OWNER_C));
        assertTrue(FeeVault(FEE_VAULT).isOwner(FEE_VAULT_OWNER_D));
        assertTrue(FeeVault(FEE_VAULT).isOwner(FEE_VAULT_OWNER_E));
    }

    function testRevertConstructorInvalidWNAD() public {
        address[] memory owners = new address[](1);
        owners[0] = FEE_VAULT_OWNER_A;

        vm.expectRevert(bytes(ERR_FEE_VAULT_INVALID_WNAD_ADDRESS));
        new FeeVault(address(0), owners, 1);
    }

    function testRevertConstructorNoOwners() public {
        address[] memory owners = new address[](0);

        vm.expectRevert(bytes(ERR_FEE_VAULT_NO_OWNERS));
        new FeeVault(address(wNAD), owners, 1);
    }

    function testRevertConstructorInvalidSignaturesRequired() public {
        address[] memory owners = new address[](2);
        owners[0] = FEE_VAULT_OWNER_A;
        owners[1] = FEE_VAULT_OWNER_B;

        vm.expectRevert(bytes(ERR_FEE_VAULT_INVALID_SIGNATURES_REQUIRED));
        new FeeVault(address(wNAD), owners, 3);
    }

    function testRevertConstructorInvalidOwner() public {
        address[] memory owners = new address[](2);
        owners[0] = FEE_VAULT_OWNER_A;
        owners[1] = address(0);

        vm.expectRevert(bytes(ERR_FEE_VAULT_INVALID_OWNER));
        new FeeVault(address(wNAD), owners, 1);
    }

    function testRevertConstructorDuplicateOwner() public {
        address[] memory owners = new address[](2);
        owners[0] = FEE_VAULT_OWNER_A;
        owners[1] = FEE_VAULT_OWNER_A;

        vm.expectRevert(bytes(ERR_FEE_VAULT_DUPLICATE_OWNER));
        new FeeVault(address(wNAD), owners, 1);
    }

    function testProposeWithdrawal() public {
        uint256 amount = 1000;
        vm.deal(FEE_VAULT_OWNER_A, amount);

        wNAD.deposit{value: amount}();
        wNAD.transfer(address(FEE_VAULT), amount);

        vm.startPrank(FEE_VAULT_OWNER_A);

        vm.expectEmit(true, true, true, true);
        emit WithdrawalProposed(0, TRADER_A, amount);

        vm.expectEmit(true, true, true, true);
        emit WithdrawalSigned(0, FEE_VAULT_OWNER_A);

        FeeVault(FEE_VAULT).proposeWithdrawal(TRADER_A, amount);

        assertEq(FeeVault(FEE_VAULT).proposalCount(), 1);

        vm.stopPrank();
    }

    function testRevertProposeWithdrawal_NotOwner() public {
        vm.expectRevert(bytes(ERR_FEE_VAULT_NOT_OWNER));
        FeeVault(FEE_VAULT).proposeWithdrawal(TRADER_A, 1000);
    }

    function testRevertProposeWithdrawal_InvalidReceiver() public {
        vm.prank(FEE_VAULT_OWNER_A);
        vm.expectRevert(bytes(ERR_FEE_VAULT_INVALID_RECEIVER));
        FeeVault(FEE_VAULT).proposeWithdrawal(address(0), 1000);
    }

    function testRevertProposeWithdrawal_InvalidAmount() public {
        vm.prank(FEE_VAULT_OWNER_A);
        vm.expectRevert(bytes(ERR_FEE_VAULT_INVALID_AMOUNT));
        FeeVault(FEE_VAULT).proposeWithdrawal(TRADER_A, 0);
    }

    function testRevertProposeWithdrawal_InsufficientBalance() public {
        vm.prank(FEE_VAULT_OWNER_A);
        vm.expectRevert(bytes(ERR_FEE_VAULT_INSUFFICIENT_BALANCE));
        FeeVault(FEE_VAULT).proposeWithdrawal(TRADER_A, 1000);
    }

    function testSignWithdrawal() public {
        uint256 amount = 1000;
        vm.deal(FEE_VAULT_OWNER_A, amount);

        wNAD.deposit{value: amount}();
        wNAD.transfer(address(FEE_VAULT), amount);

        // First signature (proposal)
        vm.prank(FEE_VAULT_OWNER_A);
        FeeVault(FEE_VAULT).proposeWithdrawal(TRADER_A, amount);

        // Second signature
        vm.prank(FEE_VAULT_OWNER_B);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalSigned(0, FEE_VAULT_OWNER_B);
        FeeVault(FEE_VAULT).signWithdrawal(0);

        // Third signature (this will execute the withdrawal)
        vm.startPrank(FEE_VAULT_OWNER_C);

        vm.expectEmit(true, true, true, true);
        emit WithdrawalSigned(0, FEE_VAULT_OWNER_C);

        vm.expectEmit(true, true, true, true);
        emit WithdrawalExecuted(0, TRADER_A, amount);

        FeeVault(FEE_VAULT).signWithdrawal(0);
        assertEq(TRADER_A.balance, amount);
        vm.stopPrank();
    }

    function testRevertSignWithdrawal_NotOwner() public {
        uint256 amount = 1000;
        vm.deal(FEE_VAULT_OWNER_A, amount);

        wNAD.deposit{value: amount}();
        wNAD.transfer(address(FEE_VAULT), amount);
        vm.prank(FEE_VAULT_OWNER_A);
        FeeVault(FEE_VAULT).proposeWithdrawal(TRADER_A, amount);

        vm.expectRevert(bytes(ERR_FEE_VAULT_NOT_OWNER));
        FeeVault(FEE_VAULT).signWithdrawal(0);
    }

    function testRevertSignWithdrawal_InvalidProposal() public {
        vm.prank(FEE_VAULT_OWNER_A);
        vm.expectRevert(bytes(ERR_FEE_VAULT_INVALID_PROPOSAL));
        FeeVault(FEE_VAULT).signWithdrawal(0);
    }

    function testRevertSignWithdrawal_AlreadyExecuted() public {
        uint256 amount = 1000;
        vm.deal(FEE_VAULT_OWNER_A, amount);

        wNAD.deposit{value: amount}();
        wNAD.transfer(address(FEE_VAULT), amount);

        // Create and execute a proposal
        vm.prank(FEE_VAULT_OWNER_A);
        FeeVault(FEE_VAULT).proposeWithdrawal(TRADER_A, amount);

        vm.prank(FEE_VAULT_OWNER_B);
        FeeVault(FEE_VAULT).signWithdrawal(0);

        vm.prank(FEE_VAULT_OWNER_C);
        FeeVault(FEE_VAULT).signWithdrawal(0);

        // Try to sign again
        vm.prank(FEE_VAULT_OWNER_D);
        vm.expectRevert(bytes(ERR_FEE_VAULT_ALREADY_EXECUTED));
        FeeVault(FEE_VAULT).signWithdrawal(0);
    }

    function testRevertSignWithdrawal_AlreadySigned() public {
        uint256 amount = 1000;
        vm.deal(FEE_VAULT_OWNER_A, amount);

        wNAD.deposit{value: amount}();
        wNAD.transfer(address(FEE_VAULT), amount);

        vm.prank(FEE_VAULT_OWNER_A);
        FeeVault(FEE_VAULT).proposeWithdrawal(TRADER_A, amount);

        vm.prank(FEE_VAULT_OWNER_A);
        vm.expectRevert(bytes(ERR_FEE_VAULT_ALREADY_SIGNED));
        FeeVault(FEE_VAULT).signWithdrawal(0);
    }
}
