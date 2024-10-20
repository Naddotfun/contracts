// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {CurveRouter} from "../../src/router/CurveRouter.sol";
import {SetUp} from "../SetUp.sol";
import {NadsPumpLibrary} from "../../src/utils/NadsPumpLibrary.sol";
import {QuestPoolRouter} from "../../src/router/QuestPoolRouter.sol";
import {QuestPool} from "../../src/quest_pool/QuestPool.sol";
import "../../src/router/errors/Error.sol";

contract QuestPoolRouterTest is Test, SetUp {
    QuestPoolRouter public QUEST_POOL_ROUTER;

    function setUp() public override {
        super.setUp();
        QUEST_POOL_ROUTER = new QuestPoolRouter(address(QUEST_POOL_FACTORY), address(wNAD));
    }

    function testCreateQuestPool() public {
        CurveCreate(CREATOR);
        BuyAmountOut(CREATOR, QUEST_POOL_MINIMUM_REWARD);
        vm.startPrank(CREATOR);
        vm.deal(CREATOR, QUEST_POOL_CREATE_FEE);
        MEME_TOKEN.approve(address(QUEST_POOL_ROUTER), QUEST_POOL_MINIMUM_REWARD);
        QUEST_POOL_ROUTER.create{value: QUEST_POOL_CREATE_FEE}(CREATOR, address(MEME_TOKEN));
        vm.stopPrank();
        address questPool = QUEST_POOL_FACTORY.getQuestPool(address(MEME_TOKEN), CREATOR);
        assertNotEq(questPool, address(0));
    }

    function testDeposit() public {
        CurveCreate(CREATOR);
        BuyAmountOut(CREATOR, QUEST_POOL_MINIMUM_REWARD);
        vm.startPrank(CREATOR);
        vm.deal(CREATOR, QUEST_POOL_CREATE_FEE);
        QUEST_POOL_ROUTER.create{value: QUEST_POOL_CREATE_FEE}(CREATOR, address(MEME_TOKEN));
        vm.stopPrank();
        address questPool = QUEST_POOL_FACTORY.getQuestPool(address(MEME_TOKEN), CREATOR);

        vm.startPrank(TRADER_A);
        BuyAmountOut(TRADER_A, 1 ether);
        MEME_TOKEN.approve(address(QUEST_POOL_ROUTER), 1 ether);
        QUEST_POOL_ROUTER.deposit(TRADER_A, questPool, address(MEME_TOKEN), 1 ether);
        vm.stopPrank();
        assertEq(MEME_TOKEN.balanceOf(TRADER_A), 0);
        assertEq(QuestPool(questPool).getQuestBalances(TRADER_A), 1 ether);
    }
}
