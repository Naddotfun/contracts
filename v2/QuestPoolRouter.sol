// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IQuestPoolFactory} from "../quest_pool/interfaces/IQuestPoolFactory.sol";
import {IQuestPool} from "../quest_pool/interfaces/IQuestPool.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IWNAD} from "../wnad/interfaces/IWNAD.sol";

import {TransferHelper} from "../utils/TransferHelper.sol";

contract QuestPoolRouter {
    using TransferHelper for IERC20;

    address private questPoolFactory;
    address private wNad;

    constructor(address _questPoolFactory, address _wNad) {
        questPoolFactory = _questPoolFactory;
        wNad = _wNad;
    }

    receive() external payable {
        assert(msg.sender == wNad); // only accept NAD via fallback from the WNAD contract
    }

    function create(address account, address token) external payable {
        uint256 createFee = IQuestPoolFactory(questPoolFactory).getConfig().createFee;
        require(msg.value >= createFee, "QuestPoolRouter: Invalid create fee");
        IWNAD(wNad).deposit{value: createFee}();

        IERC20(wNad).safeTransferERC20(questPoolFactory, createFee);

        uint256 allowance = IERC20(token).allowance(account, address(this));
        
        IQuestPoolFactory(questPoolFactory).create(account, token);
    }

    function deposit(address account, address questPool, address token, uint256 amount) external {
        uint256 allowance = IERC20(token).allowance(account, address(this));
        require(allowance >= amount, "QuestPoolRouter: Invalid deposit amount");

        IERC20(token).safeTransferERC20(questPool, amount);
        IQuestPool(questPool).deposit(account);
    }

    function withdraw(address account, address questPool) external {
        IQuestPool(questPool).withdraw(account);
    }
}
