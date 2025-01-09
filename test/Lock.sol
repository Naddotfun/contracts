// // SPDX-License-Identifier: GPL-2.0-or-later
// pragma solidity ^0.8.20;

// import {Test, console} from "forge-std/Test.sol";
// import {SetUp} from "./SetUp.sol";
// import "src/errors/Errors.sol";
// contract LockTest is Test, SetUp {
//     uint256 TOKEN_AMOUNT;
//     function setUp() public override {
//         super.setUp();
//         CreateBondingCurve(CREATOR);
//     }
//     function lock(uint256 amount) internal {
//         // CurveCreate(TRADER_A);
//         Buy(TRADER_A, amount);
//         vm.startPrank(TRADER_A);
//         TOKEN_AMOUNT = MEME_TOKEN.balanceOf(TRADER_A);
//         MEME_TOKEN.transfer(address(LOCK), TOKEN_AMOUNT);
//         LOCK.lock(address(MEME_TOKEN), TRADER_A);
//         vm.stopPrank();
//     }
//     // ============ Lock Tests ============
//     function testLockSuccess() public {
//         lock(1000);
//         assertEq(MEME_TOKEN.balanceOf(address(LOCK)), TOKEN_AMOUNT);
//         assertEq(
//             LOCK.getAvailableUnlockAmount(address(MEME_TOKEN), TRADER_A),
//             0
//         );
//         assertEq(LOCK.getLocked(address(MEME_TOKEN), TRADER_A).length, 1);
//         assertEq(
//             LOCK.getLocked(address(MEME_TOKEN), TRADER_A)[0].amount,
//             TOKEN_AMOUNT
//         );
//         assertEq(LOCK.getTokenLockedBalance(address(MEME_TOKEN)), TOKEN_AMOUNT);
//     }
//     //=================Fail Test====================
//     function testLockFailInvalidAmountIn() public {
//         vm.expectRevert(bytes(ERR_LOCK_INVALID_AMOUNT_IN));
//         LOCK.lock(address(MEME_TOKEN), TRADER_A);
//     }

//     // ============ Unlock Tests ============
//     // ============= TimeLock Unlock Tests ============
//     function testTimeUnlockSuccess() public {
//         lock(1000);
//         vm.warp(block.timestamp + DEFAULT_LOCK_TIME);
//         vm.startPrank(TRADER_A);
//         LOCK.unlock(address(MEME_TOKEN), TRADER_A);
//         assertEq(MEME_TOKEN.balanceOf(TRADER_A), TOKEN_AMOUNT);
//         assertEq(LOCK.getTokenLockedBalance(address(MEME_TOKEN)), 0);
//         assertEq(
//             LOCK.getAvailableUnlockAmount(address(MEME_TOKEN), TRADER_A),
//             0
//         );
//         vm.stopPrank();
//     }

//     // =============  TimeLock Fail Tests ============
//     function testTimeUnlockFailInvalidTime() public {
//         lock(1000);
//         vm.startPrank(TRADER_A);
//         //fail unlock
//         assertEq(MEME_TOKEN.balanceOf(TRADER_A), 0);
//     }

//     // ============= Listing Unlock Tests ============
//     function testListingUnlock() public {
//         lock(1000);
//         CurveListing(TRADER_B);

//         vm.startPrank(TRADER_A);

//         LOCK.unlock(address(MEME_TOKEN), TRADER_A);

//         assertEq(MEME_TOKEN.balanceOf(TRADER_A), TOKEN_AMOUNT);
//         assertEq(LOCK.getTokenLockedBalance(address(MEME_TOKEN)), 0);
//         assertEq(
//             LOCK.getAvailableUnlockAmount(address(MEME_TOKEN), TRADER_A),
//             0
//         );
//         vm.stopPrank();
//     }
// }
