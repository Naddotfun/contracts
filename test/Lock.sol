// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Lock} from "src/Lock.sol";
import {Token} from "src/Token.sol";

contract LockTest is Test {
    address public alice = address(0x1);
    Lock public lockContract;
    Token public token;
    uint256 tokenInitBalance = 10 ** 27;

    function setUp() public {
        lockContract = new Lock();
        token = new Token("Test Token", "TEST", "IMAGE_URI");

        token.mint(alice);
    }

    function testLock() public {
        vm.startPrank(alice);
        token.transfer(address(lockContract), 10 ether);
        lockContract.lock(address(token), alice, 100);

        vm.stopPrank();

        assertEq(token.balanceOf(address(lockContract)), 10 ether);
        assertEq(lockContract.getAvailabeUnlockAmount(address(token), alice), 0);

        //현재 블록을 100 이후로 변경
        vm.warp(101);

        uint256 availabeAmount = lockContract.getAvailabeUnlockAmount(address(token), alice);
        assertEq(availabeAmount, 10 ether);
        assertEq(token.balanceOf(alice), tokenInitBalance - 10 ether);
    }

    function testUnlock() public {
        vm.startPrank(alice);
        token.transfer(address(lockContract), 10 ether);
        lockContract.lock(address(token), alice, 100);
        vm.stopPrank();

        vm.warp(101);
        vm.startPrank(alice);
        lockContract.unlock(address(token), alice);
        vm.stopPrank();

        // assertEq(token.balanceOf(alice), 10 ether);
        assertEq(token.balanceOf(alice), tokenInitBalance);
        assertEq(token.balanceOf(address(lockContract)), 0);
        assertEq(lockContract.getAvailabeUnlockAmount(address(token), alice), 0);
    }

    function testMultipleLocks() public {
        vm.startPrank(alice);

        // First lock
        token.transfer(address(lockContract), 5 ether);
        lockContract.lock(address(token), alice, 100);

        // Second lock
        token.transfer(address(lockContract), 3 ether);
        lockContract.lock(address(token), alice, 200);

        // Third lock
        token.transfer(address(lockContract), 2 ether);
        lockContract.lock(address(token), alice, 300);

        vm.stopPrank();

        assertEq(token.balanceOf(address(lockContract)), 10 ether);
        assertEq(lockContract.getAvailabeUnlockAmount(address(token), alice), 0);

        // 첫 번째 lock 해제 시점
        vm.warp(101);
        assertEq(lockContract.getAvailabeUnlockAmount(address(token), alice), 5 ether);

        // 두 번째 lock 해제 시점
        vm.warp(201);
        assertEq(lockContract.getAvailabeUnlockAmount(address(token), alice), 8 ether);

        // 세 번째 lock 해제 시점
        vm.warp(301);
        assertEq(lockContract.getAvailabeUnlockAmount(address(token), alice), 10 ether);

        // Unlock all
        vm.prank(alice);
        lockContract.unlock(address(token), alice);

        assertEq(token.balanceOf(alice), tokenInitBalance);
        assertEq(token.balanceOf(address(lockContract)), 0);
        assertEq(lockContract.getAvailabeUnlockAmount(address(token), alice), 0);
    }

    function testPartialUnlock() public {
        vm.startPrank(alice);

        // First lock
        token.transfer(address(lockContract), 5 ether);
        lockContract.lock(address(token), alice, 100);

        // Second lock
        token.transfer(address(lockContract), 5 ether);
        lockContract.lock(address(token), alice, 200);

        vm.stopPrank();

        // 첫 번째 lock 해제 시점
        vm.warp(101);
        assertEq(lockContract.getAvailabeUnlockAmount(address(token), alice), 5 ether);

        // Partial unlock
        vm.prank(alice);
        lockContract.unlock(address(token), alice);

        assertEq(token.balanceOf(alice), tokenInitBalance - 5 ether);
        assertEq(token.balanceOf(address(lockContract)), 5 ether);

        // 두 번째 lock 해제 시점
        vm.warp(201);
        assertEq(lockContract.getAvailabeUnlockAmount(address(token), alice), 5 ether);

        // Final unlock
        vm.prank(alice);
        lockContract.unlock(address(token), alice);

        assertEq(token.balanceOf(alice), tokenInitBalance);
        assertEq(token.balanceOf(address(lockContract)), 0);
        assertEq(lockContract.getAvailabeUnlockAmount(address(token), alice), 0);
    }
}
