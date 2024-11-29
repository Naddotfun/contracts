// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SetUp} from "./SetUp.sol";

contract LockTest is Test, SetUp {
    uint256 TOKEN_AMOUNT;

    function lock(uint256 amount) internal {
        // CurveCreate(TRADER_A);
        Buy(TRADER_A, amount);
        vm.startPrank(TRADER_A);
        TOKEN_AMOUNT = MEME_TOKEN.balanceOf(TRADER_A);
        MEME_TOKEN.transfer(address(LOCK), TOKEN_AMOUNT);
        LOCK.lock(address(MEME_TOKEN), TRADER_A);
        vm.stopPrank();
    }

    function testLock() public {
        lock(1000);
        assertEq(MEME_TOKEN.balanceOf(address(LOCK)), TOKEN_AMOUNT);
        assertEq(
            LOCK.getAvailabeUnlockAmount(address(MEME_TOKEN), TRADER_A),
            0
        );
        assertEq(LOCK.getLocked(address(MEME_TOKEN), TRADER_A).length, 1);
        assertEq(
            LOCK.getLocked(address(MEME_TOKEN), TRADER_A)[0].amount,
            TOKEN_AMOUNT
        );
        assertEq(LOCK.getTokenLockedBalance(address(MEME_TOKEN)), TOKEN_AMOUNT);
    }

    function testTimeUnlock() public {
        lock(1000);
        vm.warp(block.timestamp + DEFAULT_LOCK_TIME);
        vm.startPrank(TRADER_A);
        LOCK.unlock(address(MEME_TOKEN), TRADER_A);
        assertEq(MEME_TOKEN.balanceOf(TRADER_A), TOKEN_AMOUNT);
        assertEq(LOCK.getTokenLockedBalance(address(MEME_TOKEN)), 0);
        assertEq(
            LOCK.getAvailabeUnlockAmount(address(MEME_TOKEN), TRADER_A),
            0
        );
        vm.stopPrank();
    }

    function testListingUnlock() public {
        uint256 listingAmount = TOKEN_TOTAL_SUPPLY - TARGET_TOKEN;
        lock(listingAmount);
        vm.startPrank(TRADER_A);
        CURVE.listing();
        LOCK.unlock(address(MEME_TOKEN), TRADER_A);
        assertEq(MEME_TOKEN.balanceOf(TRADER_A), TOKEN_AMOUNT);
        assertEq(LOCK.getTokenLockedBalance(address(MEME_TOKEN)), 0);
        assertEq(
            LOCK.getAvailabeUnlockAmount(address(MEME_TOKEN), TRADER_A),
            0
        );
        vm.stopPrank();
    }
}
