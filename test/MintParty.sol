// // SPDX-License-Identifier: GPL-2.0-or-later
// pragma solidity ^0.8.20;

// import "./SetUp.sol";
// import {IMintParty} from "../src/interfaces/IMintParty.sol";
// import {ILock} from "../src/interfaces/ILock.sol";
// import "forge-std/console2.sol";

// //@notice if you want to test this, you need to add amountOut to the event MintPartyFinished
// contract MintPartyTest is SetUp {
//     //Only Test
//     // emit MintPartyFinished(token, curve, amountOut);
//     event MintPartyFinished(address indexed token, address indexed curve);
//     event MintPartyDeposit(address indexed account, uint256 amount);
//     event MintPartyWhiteListAdded(address indexed account, uint256 amount);
//     event MintPartyClosed();
//     event MintPartyWithdraw(address indexed account, uint256 amount);

//     function setUp() public override {
//         super.setUp();
//         CreateMintParty(CREATOR);
//     }

//     function testDeposit() public {
//         // Factory를 통해 생성된 MintParty에 예치
//         vm.deal(TRADER_A, MINT_PARTY_FUNDING_AMOUNT);
//         vm.prank(TRADER_A);
//         MINT_PARTY.deposit{value: MINT_PARTY_FUNDING_AMOUNT}(TRADER_A);

//         assertEq(MINT_PARTY.getBalance(TRADER_A), MINT_PARTY_FUNDING_AMOUNT);
//         //OWNER BALANCE + TRADER_A BALANCE
//         assertEq(MINT_PARTY.getTotalBalance(), MINT_PARTY_FUNDING_AMOUNT * 2);
//     }

//     function testWithdraw() public {
//         // TRADER_A 예치
//         vm.deal(TRADER_A, MINT_PARTY_FUNDING_AMOUNT);
//         vm.prank(TRADER_A);
//         MINT_PARTY.deposit{value: MINT_PARTY_FUNDING_AMOUNT}(TRADER_A);

//         // 출금
//         vm.prank(TRADER_A);
//         MINT_PARTY.withdraw();

//         assertEq(MINT_PARTY.getBalance(TRADER_A), 0);
//         //OWNER BALANCE
//         assertEq(MINT_PARTY.getTotalBalance(), MINT_PARTY_FUNDING_AMOUNT);
//         assertEq(MINT_PARTY.getFinished(), false);
//     }

//     function test_AddWhiteList() public {
//         // 1. 트레이더들 입금
//         vm.deal(TRADER_A, MINT_PARTY_FUNDING_AMOUNT);
//         vm.prank(TRADER_A);
//         MINT_PARTY.deposit{value: MINT_PARTY_FUNDING_AMOUNT}(TRADER_A);

//         vm.deal(TRADER_B, MINT_PARTY_FUNDING_AMOUNT);
//         vm.prank(TRADER_B);
//         MINT_PARTY.deposit{value: MINT_PARTY_FUNDING_AMOUNT}(TRADER_B);

//         vm.deal(TRADER_C, MINT_PARTY_FUNDING_AMOUNT);
//         vm.prank(TRADER_C);
//         MINT_PARTY.deposit{value: MINT_PARTY_FUNDING_AMOUNT}(TRADER_C);

//         // 2. 화이트리스트 추가 전 상태 확인
//         uint256 initialTotalBalance = MINT_PARTY.getTotalBalance();
//         console.log("Initial Total Balance:", initialTotalBalance);

//         // 3. 이벤트 로깅 시작
//         vm.recordLogs();

//         // 4. 화이트리스트 추가
//         vm.startPrank(CREATOR);
//         address[] memory accounts = new address[](3);
//         accounts[0] = TRADER_A;
//         accounts[1] = TRADER_B;
//         accounts[2] = TRADER_C;

//         MINT_PARTY.addWhiteList(accounts);
//         vm.stopPrank();

//         // 5. 화이트리스트 추가 후 상태 확인
//         address[] memory whitelistAccounts = MINT_PARTY.getWhitelistAccounts();
//         assertEq(whitelistAccounts.length, 4, "Whitelist length should be 4");

//         // 6. 토큰과 커브 생성 확인
//         (
//             address token,
//             address curve,
//             uint256 amountOut
//         ) = getCreatedTokenInfo();
//         console.log("Token Address:", token);
//         console.log("Curve Address:", curve);
//         console.log("Total Token Amount:", amountOut);

//         // 7. Lock된 토큰 검증
//         verifyLockedTokens(token, amountOut);
//     }

//     // Helper Functions
//     function getCreatedTokenInfo()
//         internal
//         returns (address token, address curve, uint256 amountOut)
//     {
//         Vm.Log[] memory entries = vm.getRecordedLogs();

//         bytes32 finishEventSignature = keccak256(
//             "MintPartyFinished(address,address,uint256)"
//         );

//         for (uint i = 0; i < entries.length; i++) {
//             if (entries[i].topics[0] == finishEventSignature) {
//                 token = address(uint160(uint256(entries[i].topics[1])));
//                 curve = address(uint160(uint256(entries[i].topics[2])));
//                 amountOut = abi.decode(entries[i].data, (uint256));
//                 break;
//             }
//         }
//     }

//     function verifyLockedTokens(
//         address token,
//         uint256 totalAmount
//     ) internal view {
//         address[] memory accounts = MINT_PARTY.getWhitelistAccounts();
//         uint256 numberOfAccounts = accounts.length;
//         uint256 amountPerAccount = totalAmount / numberOfAccounts;
//         uint256 remainder = totalAmount % numberOfAccounts;
//         uint256 totalLocked;

//         for (uint i = 0; i < accounts.length; i++) {
//             ILock.LockInfo[] memory lockInfo = LOCK.getLocked(
//                 token,
//                 accounts[i]
//             );
//             uint256 expectedAmount = amountPerAccount;
//             if (i < remainder) {
//                 expectedAmount += 1;
//             }
//             uint256 lockedAmount = lockInfo[0].amount;
//             assertApproxEqRel(lockedAmount, expectedAmount, 0.01e18);

//             totalLocked += lockedAmount;
//         }
//         console.log("Total Locked:", totalLocked);
//         console.log("Total Amount:", totalAmount);

//         assertApproxEqRel(totalLocked, totalAmount, 0.01e18);
//     }

//     function test_AddWhiteList_RevertIfNotOwner() public {
//         vm.deal(TRADER_A, MINT_PARTY_FUNDING_AMOUNT);
//         vm.prank(TRADER_A);
//         MINT_PARTY.deposit{value: MINT_PARTY_FUNDING_AMOUNT}(TRADER_A);

//         vm.prank(TRADER_B);
//         address[] memory accounts = new address[](1);
//         accounts[0] = TRADER_A;

//         vm.expectRevert("MintParty : ERR_MINT_PARTY_ONLY_OWNER");
//         MINT_PARTY.addWhiteList(accounts);
//     }

//     function test_AddWhiteList_RevertIfExceedMaxCount() public {
//         address[] memory accounts = new address[](
//             MINT_PARTY_MAXIMUM_WHITE_LIST + 1
//         );
//         for (uint i = 0; i < accounts.length; i++) {
//             accounts[i] = address(uint160(i + 1));
//         }

//         vm.prank(CREATOR);
//         vm.expectRevert("MintParty : ERR_MINT_PARTY_INVALID_WHITE_LIST");
//         MINT_PARTY.addWhiteList(accounts);
//     }

//     function test_AddWhiteList_RevertIfBalanceZero() public {
//         address[] memory accounts = new address[](1);
//         accounts[0] = TRADER_A; // TRADER_A has no balance

//         vm.prank(CREATOR);
//         vm.expectRevert("MintParty : ERR_MINT_PARTY_BALANCE_ZERO");
//         MINT_PARTY.addWhiteList(accounts);
//     }

//     function test_Deposit_RevertIfAlreadyDeposited() public {
//         vm.deal(TRADER_A, MINT_PARTY_FUNDING_AMOUNT * 2);
//         vm.startPrank(TRADER_A);

//         MINT_PARTY.deposit{value: MINT_PARTY_FUNDING_AMOUNT}(TRADER_A);

//         vm.expectRevert("MintParty : ERR_MINT_PARTY_ALREADY_DEPOSITED");
//         MINT_PARTY.deposit{value: MINT_PARTY_FUNDING_AMOUNT}(TRADER_A);

//         vm.stopPrank();
//     }

//     function test_Deposit_RevertIfInvalidAmount() public {
//         vm.deal(TRADER_A, MINT_PARTY_FUNDING_AMOUNT * 2);
//         vm.prank(TRADER_A);

//         vm.expectRevert("MintParty : ERR_MINT_PARTY_INVALID_FUNDING_AMOUNT");
//         MINT_PARTY.deposit{value: MINT_PARTY_FUNDING_AMOUNT * 2}(TRADER_A);
//     }

//     function test_Withdraw_RevertIfNoBalance() public {
//         vm.prank(TRADER_A);
//         vm.expectRevert("MintParty : ERR_MINT_PARTY_WITHDRAW_AMOUNT_IS_ZERO");
//         MINT_PARTY.withdraw();
//     }
// }
