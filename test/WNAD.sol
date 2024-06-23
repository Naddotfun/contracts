// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "src/WNAD.sol";

contract WNADTest is Test {
    WNAD wNad;
    address human;

    function setUp() public {
        human = address(0xa);
        wNad = new WNAD();
        vm.deal(human, 100);
        vm.startPrank(human);
        wNad.deposit{value: 100}();
        vm.stopPrank();
    }

    function testDeposit() public {
        assertEq(wNad.balanceOf(human), 100);
        assertEq(wNad.totalSupply(), 100);
        assertEq(human.balance, 0);
    }

    function testWithdraw() public {
        vm.startPrank(human);
        wNad.withdraw(100);
        assertEq(wNad.balanceOf(human), 0);
        assertEq(wNad.totalSupply(), 0);
        assertEq(human.balance, 100);
    }

    function testTotalSupply() public {
        assertEq(wNad.totalSupply(), 100);
    }

    function testApprove() public {
        vm.startPrank(human);
        wNad.approve(address(this), 100);
        assertEq(wNad.allowance(human, address(this)), 100);
    }

    function testTransferFrom() public {
        vm.startPrank(human);
        wNad.approve(address(this), 100);
        vm.startPrank(address(this));
        wNad.transferFrom(human, address(this), 100);
        assertEq(wNad.balanceOf(address(this)), 100);
    }
    // function testApprove() public {
    //     wNad.approve(address(this), 100);
    //     assertEq(wNad.allowance(address(this), address(this)), 100);
    // }

    // function testTransfer() public {
    //     wNad.deposit{value: 100}();
    //     wNad.transfer(address(this), 100);
    //     assertEq(wNad.balanceOf(address(this)), 100);
    // }
}
