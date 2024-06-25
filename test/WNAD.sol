// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "src/WNAD.sol";

contract WNADTest is Test {
    WNAD wNad;
    address human;
    uint256 humanPrivateKey;
    address human2;

    function setUp() public {
        humanPrivateKey = 0xA11CE;
        human = vm.addr(humanPrivateKey);
        human2 = address(0xb);
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

    function testPermit() public {
        address owner = human;
        address spender = address(this);
        uint256 value = 100;
        uint256 nonce = wNad.nonces(owner);
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 DOMAIN_SEPARATOR = wNad.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(wNad.PERMIT_TYPEHASH(), owner, spender, value, nonce, deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(humanPrivateKey, digest);

        vm.startPrank(owner);
        wNad.permit(owner, spender, value, deadline, v, r, s);
        vm.stopPrank();

        assertEq(wNad.allowance(owner, spender), value);
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
