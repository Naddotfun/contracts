// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SetUp} from "../SetUp.sol";
import "../../src/quest_pool/errors/Error.sol";
import {QuestPoolFactoryTest} from "./QuestPoolFactory.sol";

contract QuestPoolTest is Test, SetUp, QuestPoolFactoryTest {
    function testCreate() public {
        CreateQuestPool();
        assertEq(QUEST_POOL.getToken(), address(MEME_TOKEN));
        assertEq(QUEST_POOL.getCurve(), address(CURVE));
        assertEq(QUEST_POOL.getClaimableTimeStamp(), block.timestamp + QUEST_POOL_DEFAULT_CLAIM_TIMESTAMP);
        assertEq(QUEST_POOL.getQuestBalances(CREATOR), 0);
        assertEq(QUEST_POOL.getTotalDepositAmount(), 0);
        assertEq(MEME_TOKEN.balanceOf(address(QUEST_POOL)), QUEST_POOL_MINIMUM_REWARD);
        assertEq(QUEST_POOL.getRewardAmount(), QUEST_POOL_MINIMUM_REWARD);
    }

    function testDeposit() public {
        CreateQuestPool();
        uint256 depositAmount = 1 ether;
        BuyAmountOut(TRADER_A, depositAmount);

        vm.startPrank(TRADER_A);

        MEME_TOKEN.approve(address(QUEST_POOL), depositAmount);
        QUEST_POOL.deposit(TRADER_A);
        vm.stopPrank();
        assertEq(QUEST_POOL.getQuestBalances(TRADER_A), depositAmount);
        assertEq(QUEST_POOL.getTotalDepositAmount(), depositAmount);
        assertEq(MEME_TOKEN.balanceOf(address(QUEST_POOL)), QUEST_POOL_MINIMUM_REWARD + depositAmount);
        assertEq(QUEST_POOL.getRewardAmount(), QUEST_POOL_MINIMUM_REWARD);
    }

    function testWithdrawByTimestamp() public {
        CreateQuestPool();
        uint256 depositAmount = 1 ether;
        BuyAmountOut(TRADER_A, depositAmount);

        vm.startPrank(TRADER_A);
        MEME_TOKEN.approve(address(QUEST_POOL), depositAmount);
        QUEST_POOL.deposit(TRADER_A);

        vm.warp(block.timestamp + QUEST_POOL_DEFAULT_CLAIM_TIMESTAMP);
        QUEST_POOL.withdraw(TRADER_A);
        assertEq(QUEST_POOL.getQuestBalances(TRADER_A), 0);
        assertEq(QUEST_POOL.getTotalDepositAmount(), depositAmount);
        assertEq(MEME_TOKEN.balanceOf(address(QUEST_POOL)), 0);
        assertEq(QUEST_POOL.getRewardAmount(), QUEST_POOL_MINIMUM_REWARD);
        assertEq(QUEST_POOL.getEndQuest(), true);
        assertEq(MEME_TOKEN.balanceOf(TRADER_A), depositAmount + QUEST_POOL_MINIMUM_REWARD);
        vm.stopPrank();
    }

    function testWithdrawByCurveListing() public {
        CreateQuestPool();
        uint256 depositAmount = 1 ether;
        BuyAmountOut(TRADER_A, depositAmount);

        vm.startPrank(TRADER_A);
        MEME_TOKEN.approve(address(QUEST_POOL), depositAmount);
        QUEST_POOL.deposit(TRADER_A);

        CurveListing(TRADER_B);
        QUEST_POOL.withdraw(TRADER_A);
        assertEq(QUEST_POOL.getQuestBalances(TRADER_A), 0);
        assertEq(QUEST_POOL.getTotalDepositAmount(), depositAmount);
        assertEq(MEME_TOKEN.balanceOf(address(QUEST_POOL)), 0);
        assertEq(QUEST_POOL.getEndQuest(), true);
        assertEq(QUEST_POOL.getRewardAmount(), QUEST_POOL_MINIMUM_REWARD);
        assertEq(MEME_TOKEN.balanceOf(TRADER_A), depositAmount + QUEST_POOL_MINIMUM_REWARD);
        vm.stopPrank();
    }

    function testWithdrawInvalidRewardShare() public {
        CreateQuestPool();
        uint256 depositAmount = 1 ether;
        //TRADER_A
        {
            BuyAmountOut(TRADER_A, depositAmount);
            vm.startPrank(TRADER_A);
            MEME_TOKEN.approve(address(QUEST_POOL), depositAmount);
            QUEST_POOL.deposit(TRADER_A);
            vm.stopPrank();
        }
        //TRADER_B
        {
            BuyAmountOut(TRADER_B, depositAmount);
            vm.startPrank(TRADER_B);
            MEME_TOKEN.approve(address(QUEST_POOL), depositAmount);
            QUEST_POOL.deposit(TRADER_B);
            vm.stopPrank();
        }
        CurveListing(TRADER_C);
        vm.startPrank(TRADER_A);
        QUEST_POOL.withdraw(TRADER_A);
        vm.stopPrank();

        vm.startPrank(TRADER_B);
        QUEST_POOL.withdraw(TRADER_B);
        vm.stopPrank();

        assertEq(MEME_TOKEN.balanceOf(TRADER_A), depositAmount + (QUEST_POOL_MINIMUM_REWARD / 2));
        assertEq(MEME_TOKEN.balanceOf(TRADER_B), depositAmount + (QUEST_POOL_MINIMUM_REWARD / 2));
    }

    function testWithdrawFail() public {
        CreateQuestPool();
        uint256 depositAmount = 1 ether;
        BuyAmountOut(TRADER_A, depositAmount);

        vm.startPrank(TRADER_A);
        MEME_TOKEN.approve(address(QUEST_POOL), depositAmount);
        QUEST_POOL.deposit(TRADER_A);
        //fail test

        vm.expectRevert(bytes(ERR_INVALID_CLAIM));
        QUEST_POOL.withdraw(TRADER_A);
    }
}
