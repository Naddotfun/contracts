// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MintParty.sol";
import "./SetUp.sol";

contract MintPartyTest is Test, SetUp {
    uint256 constant FUNDING_AMOUNT = 1 ether;
    uint256 constant WHITELIST_COUNT = 4;

    address[] accounts;

    function setUp() public override {
        super.setUp();

        // 테스트용 계정 설정
        accounts = new address[](WHITELIST_COUNT - 1); // owner는 이미 whitelist에 있으므로 3개만 필요
        accounts[0] = TRADER_A;
        accounts[1] = TRADER_B;
        accounts[2] = TRADER_C;

        CreateMintParty(OWNER);
    }

    // ============ Success Cases ============

    function testDeposit() public {
        // Factory를 통해 생성된 MintParty에 예치
        vm.deal(TRADER_A, FUNDING_AMOUNT);
        vm.prank(TRADER_A);
        MINT_PARTY.deposit{value: FUNDING_AMOUNT}(TRADER_A);

        assertEq(MINT_PARTY.getBalance(TRADER_A), FUNDING_AMOUNT);
        //OWNER BALANCE + TRADER_A BALANCE
        assertEq(MINT_PARTY.getTotalBalance(), FUNDING_AMOUNT * 2);
    }

    function testAddWhitelist() public {
        // 예치금 입금
        for (uint i = 0; i < accounts.length; i++) {
            vm.deal(accounts[i], FUNDING_AMOUNT);
            vm.prank(accounts[i]);
            MINT_PARTY.deposit{value: FUNDING_AMOUNT}(accounts[i]);
        }

        // 화이트리스트 추가
        vm.startPrank(OWNER);
        MINT_PARTY.addWhiteList(accounts);
        vm.stopPrank();

        // 자동으로 토큰 생성 및 분배되었는지 확인
        assertTrue(MINT_PARTY.getFinished());
        assertEq(MINT_PARTY.getTotalBalance(), 0);
    }

    function testWithdraw() public {
        // TRADER_A 예치
        vm.deal(TRADER_A, FUNDING_AMOUNT);
        vm.prank(TRADER_A);
        MINT_PARTY.deposit{value: FUNDING_AMOUNT}(TRADER_A);

        // 출금
        vm.prank(TRADER_A);
        MINT_PARTY.withdraw();

        assertEq(MINT_PARTY.getBalance(TRADER_A), 0);
        //OWNER BALANCE
        assertEq(MINT_PARTY.getTotalBalance(), FUNDING_AMOUNT);
        assertEq(MINT_PARTY.getFinished(), false);
    }

    // ============ Failure Cases ============

    function testRevertInvalidDeposit() public {
        // 잘못된 금액으로 예치
        vm.deal(TRADER_A, FUNDING_AMOUNT / 2);
        vm.startPrank(TRADER_A);
        vm.expectRevert(bytes(ERR_MINT_PARTY_INVALID_FUNDING_AMOUNT));
        MINT_PARTY.deposit{value: FUNDING_AMOUNT / 2}(TRADER_A);
        vm.stopPrank();
    }

    function testRevertDoubleDeposit() public {
        // 첫 번째 예치
        vm.deal(TRADER_A, FUNDING_AMOUNT * 2);
        vm.startPrank(TRADER_A);
        MINT_PARTY.deposit{value: FUNDING_AMOUNT}(TRADER_A);

        // 두 번째 예치 시도
        vm.expectRevert(bytes(ERR_MINT_PARTY_ALREADY_DEPOSITED));
        MINT_PARTY.deposit{value: FUNDING_AMOUNT}(TRADER_A);
        vm.stopPrank();
    }

    function testRevertUnauthorizedWhitelist() public {
        vm.startPrank(TRADER_A);
        vm.expectRevert(bytes(ERR_MINT_PARTY_ONLY_OWNER));
        MINT_PARTY.addWhiteList(accounts);
        vm.stopPrank();
    }

    function testRevertWithdrawWithoutBalance() public {
        vm.startPrank(TRADER_A);
        vm.expectRevert(bytes(ERR_MINT_PARTY_WITHDRAW_AMOUNT_IS_ZERO));
        MINT_PARTY.withdraw();
        vm.stopPrank();
    }

    function testRevertExceedWhitelistCount() public {
        // 화이트리스트 한도보다 많은 계정 추가 시도
        address[] memory tooManyAccounts = new address[](WHITELIST_COUNT + 1);
        for (uint i = 0; i < WHITELIST_COUNT + 1; i++) {
            tooManyAccounts[i] = address(uint160(i + 1));
            vm.deal(tooManyAccounts[i], FUNDING_AMOUNT);
            vm.prank(tooManyAccounts[i]);
            MINT_PARTY.deposit{value: FUNDING_AMOUNT}(tooManyAccounts[i]);
        }

        vm.startPrank(OWNER);
        vm.expectRevert(bytes(ERR_MINT_PARTY_INVALID_WHITE_LIST));
        MINT_PARTY.addWhiteList(tooManyAccounts);
        vm.stopPrank();
    }

    function testRevertAddWhitelistWithoutBalance() public {
        // 예치금 없는 계정을 화이트리스트에 추가 시도
        address[] memory noBalanceAccounts = new address[](1);
        noBalanceAccounts[0] = TRADER_A;

        vm.startPrank(OWNER);
        vm.expectRevert(bytes(ERR_MINT_PARTY_BALANCE_ZERO));
        MINT_PARTY.addWhiteList(noBalanceAccounts);
        vm.stopPrank();
    }

    function testRevertDepositAfterFinished() public {
        // 화이트리스트 가득 채우기
        for (uint i = 0; i < accounts.length; i++) {
            vm.deal(accounts[i], FUNDING_AMOUNT);
            vm.prank(accounts[i]);
            MINT_PARTY.deposit{value: FUNDING_AMOUNT}(accounts[i]);
        }

        // 화이트리스트 추가하여 완료 상태로 만들기
        vm.prank(OWNER);
        MINT_PARTY.addWhiteList(accounts);

        // 완료된 상태에서 추가 예치 시도
        vm.deal(address(0x123), FUNDING_AMOUNT);
        vm.startPrank(address(0x123));
        vm.expectRevert(bytes(ERR_MINT_PARTY_FINISHED));
        MINT_PARTY.deposit{value: FUNDING_AMOUNT}(address(0x123));
        vm.stopPrank();
    }
}
