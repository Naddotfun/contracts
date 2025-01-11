// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "./SetUp.sol";

import "forge-std/console2.sol";

contract TokenTest is SetUp {
    function setUp() public override {
        super.setUp();
        CreateBondingCurve(CREATOR);
    }

    // ========== Token Transfer Tests ==========

    function testTransferBeforeListing() public {
        // Buy tokens first
        vm.startPrank(TRADER_A);
        uint256 amountIn = 1 ether;
        uint256 fee = BondingCurveLibrary.getFeeAmount(amountIn, FEE_DENOMINATOR, FEE_NUMERATOR);
        vm.deal(TRADER_A, amountIn + fee);

        uint256 deadline = block.timestamp + 1;
        CORE.buy{value: amountIn + fee}(amountIn, fee, address(MEME_TOKEN), TRADER_A, deadline);

        uint256 balance = MEME_TOKEN.balanceOf(TRADER_A);

        // Transfer to Core should succeed
        MEME_TOKEN.transfer(address(CORE), balance / 2);
        assertEq(MEME_TOKEN.balanceOf(address(CORE)), balance / 2);

        // Transfer to random address should fail
        address randomUser = address(0x123);
        vm.expectRevert("Token: transfer not allowed before listing");
        MEME_TOKEN.transfer(randomUser, balance / 2);

        vm.stopPrank();
    }

    function testTransferAfterListing() public {
        // First do listing
        CurveListing(TRADER_A);

        vm.startPrank(TRADER_A);
        uint256 balance = MEME_TOKEN.balanceOf(TRADER_A); // TRADER_A의 잔액을 확인

        // Transfer to any address should succeed after listing
        address randomUser = address(0x123);
        MEME_TOKEN.transfer(randomUser, balance / 2);
        assertEq(MEME_TOKEN.balanceOf(randomUser), balance / 2);
        assertEq(MEME_TOKEN.balanceOf(TRADER_A), balance / 2); // TRADER_A의 잔액 확인

        vm.stopPrank();
    }
}
