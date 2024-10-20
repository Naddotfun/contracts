// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SetUp} from "../SetUp.sol";
import {QuestPool} from "../../src/quest_pool/QuestPool.sol";
import "../../src/quest_pool/errors/Error.sol";

contract QuestPoolFactoryTest is Test, SetUp {
    QuestPool QUEST_POOL;

    function CreateQuestPool() public {
        CurveCreate(CREATOR);
        BuyAmountOut(CREATOR, QUEST_POOL_MINIMUM_REWARD);
        vm.startPrank(CREATOR);
        vm.deal(CREATOR, QUEST_POOL_CREATE_FEE);

        MEME_TOKEN.approve(address(QUEST_POOL_FACTORY), QUEST_POOL_MINIMUM_REWARD);
        QUEST_POOL = QuestPool(QUEST_POOL_FACTORY.create{value: QUEST_POOL_CREATE_FEE}(CREATOR, address(MEME_TOKEN)));
        assertEq(QUEST_POOL_FACTORY.getQuestPool(address(MEME_TOKEN), CREATOR), address(QUEST_POOL));
        vm.stopPrank();
    }

    function testCreateQuestPoolWithInvalidToken() public {
        // CurveCreate(CREATOR);
        BuyAmountOut(CREATOR, QUEST_POOL_MINIMUM_REWARD);

        vm.startPrank(CREATOR);
        vm.deal(CREATOR, QUEST_POOL_CREATE_FEE);
        // wNAD.deposit{value: QUEST_POOL_CREATE_FEE}();
        // wNAD.transfer(address(QUEST_POOL_FACTORY), QUEST_POOL_CREATE_FEE);
        MEME_TOKEN.transfer(address(QUEST_POOL_FACTORY), QUEST_POOL_MINIMUM_REWARD);
        vm.expectRevert(bytes(ERR_INVALID_TOKEN));
        QUEST_POOL_FACTORY.create{value: QUEST_POOL_CREATE_FEE}(CREATOR, address(0));
    }

    function testCreateQuestPoolWithInsufficientCreateFee() public {
        // CurveCreate(CREATOR);
        BuyAmountOut(CREATOR, QUEST_POOL_MINIMUM_REWARD);
        vm.startPrank(CREATOR);
        vm.deal(CREATOR, QUEST_POOL_CREATE_FEE - 1);
        // wNAD.deposit{value: QUEST_POOL_CREATE_FEE - 1}();
        // wNAD.transfer(address(QUEST_POOL_FACTORY), QUEST_POOL_CREATE_FEE - 1);
        MEME_TOKEN.transfer(address(QUEST_POOL_FACTORY), QUEST_POOL_MINIMUM_REWARD);
        vm.expectRevert(bytes(ERR_INVALID_CREATE_FEE));
        QUEST_POOL_FACTORY.create{value: QUEST_POOL_CREATE_FEE - 1}(CREATOR, address(MEME_TOKEN));
    }

    function testCreateQuestPoolWithInsufficientMinimumReward() public {
        // CurveCreate(CREATOR);
        BuyAmountOut(CREATOR, QUEST_POOL_MINIMUM_REWARD);
        vm.startPrank(CREATOR);
        vm.deal(CREATOR, QUEST_POOL_CREATE_FEE);
        // wNAD.deposit{value: QUEST_POOL_CREATE_FEE}();
        // wNAD.transfer(address(QUEST_POOL_FACTORY), QUEST_POOL_CREATE_FEE);
        MEME_TOKEN.transfer(address(QUEST_POOL_FACTORY), QUEST_POOL_MINIMUM_REWARD - 1);
        vm.expectRevert(bytes(ERR_INVALID_MINIMUM_REWARD));
        QUEST_POOL_FACTORY.create{value: QUEST_POOL_CREATE_FEE}(CREATOR, address(MEME_TOKEN));
    }
}
