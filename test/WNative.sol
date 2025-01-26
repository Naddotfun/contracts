// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "src/WNative.sol";

contract WNativeTest is Test {
    WNative wNative;
    address human;
    uint256 humanPrivateKey;
    address human2;

    function setUp() public {
        humanPrivateKey = 0xA11CE;
        human = vm.addr(humanPrivateKey);
        human2 = address(0xb);
        wNative = new WNative();
        vm.deal(human, 100);
        vm.startPrank(human);
        wNative.deposit{value: 100}();
        vm.stopPrank();
    }

    function testDeposit() public view {
        assertEq(wNative.balanceOf(human), 100);
        assertEq(wNative.totalSupply(), 100);
        assertEq(human.balance, 0);
    }

    function testWithdraw() public {
        vm.startPrank(human);
        wNative.withdraw(100);
        assertEq(wNative.balanceOf(human), 0);
        assertEq(wNative.totalSupply(), 0);
        assertEq(human.balance, 100);
    }

    function testTotalSupply() public view {
        assertEq(wNative.totalSupply(), 100);
    }

    function testApprove() public {
        vm.startPrank(human);
        wNative.approve(address(this), 100);
        assertEq(wNative.allowance(human, address(this)), 100);
    }

    function testTransferFrom() public {
        vm.startPrank(human);
        wNative.approve(address(this), 100);
        vm.startPrank(address(this));
        wNative.transferFrom(human, address(this), 100);
        assertEq(wNative.balanceOf(address(this)), 100);
    }

    function testPermit() public {
        address owner = human;
        address spender = address(this);
        uint256 value = 100;
        uint256 nonce = wNative.nonces(owner);
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 DOMAIN_SEPARATOR = wNative.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(wNative.permitTypeHash(), owner, spender, value, nonce, deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(humanPrivateKey, digest);

        vm.startPrank(owner);
        wNative.permit(owner, spender, value, deadline, v, r, s);
        vm.stopPrank();

        assertEq(wNative.allowance(owner, spender), value);
    }
}
