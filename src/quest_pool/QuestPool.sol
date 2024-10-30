// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IBondingCurve} from "../curve/interfaces/IBondingCurve.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TransferHelper} from "../utils/TransferHelper.sol";
import {IQuestPool} from "./interfaces/IQuestPool.sol";
import "./errors/Error.sol";

import {TransferHelper} from "../utils/TransferHelper.sol";

contract QuestPool is IQuestPool {
    using TransferHelper for IERC20;
    // 상태 변수

    uint256 private totalDepositAmount;
    uint256 private rewardAmount;
    uint256 private totalDeposit;
    uint256 public immutable claimableTimeStamp;
    IERC20 public immutable token;
    IBondingCurve public immutable curve;
    mapping(address => uint256) public questBalances;
    bool private initialized;

    constructor(address _curve, address _token, uint256 _claimableTimeStamp) {
        curve = IBondingCurve(_curve);
        claimableTimeStamp = block.timestamp + _claimableTimeStamp;
        token = IERC20(_token);
    }

    function initialize() external {
        require(!initialized, ERR_INVALID_INITIALIZE);
        rewardAmount = token.balanceOf(address(this));

        initialized = true;
    }

    function deposit(address account) external {
        require(block.timestamp < claimableTimeStamp, ERR_INVALID_BLOCK_TIMESTAMP);

        uint256 balance = token.allowance(account, address(this));
        require(balance > 0, ERR_INVALID_QUEST_BALANCE);
        token.safeTransferFrom(account, address(this), balance);

        questBalances[account] += balance;

        totalDeposit += balance;

        emit QuestAdded(account, balance);
    }

    function withdraw(address account) external {
        //본딩커브가 리스팅되었다면 클레임 가능 , 리스팅이 false 라면 block.timestamp 확인
        require(IBondingCurve(curve).getIsListing() || block.timestamp >= claimableTimeStamp, ERR_INVALID_CLAIM);

        uint256 balance = questBalances[account];

        require(balance > 0, ERR_INVALID_QUEST_BALANCE);

        questBalances[account] = 0;
        uint256 reward = rewardAmount * balance / (totalDeposit);

        token.safeTransferERC20(account, reward + balance);
        emit QuestClaimed(account, reward, balance);
    }

    function getEndQuest() external view returns (bool) {
        return IBondingCurve(curve).getIsListing() || block.timestamp >= claimableTimeStamp;
    }

    function getQuestBalances(address account) external view returns (uint256) {
        return questBalances[account];
    }

    function getTotalDepositAmount() external view returns (uint256) {
        return totalDeposit;
    }

    function getRewardAmount() external view returns (uint256) {
        return rewardAmount;
    }

    function getToken() external view returns (address) {
        return address(token);
    }

    function getCurve() external view returns (address) {
        return address(curve);
    }

    function getClaimableTimeStamp() external view returns (uint256) {
        return claimableTimeStamp;
    }
}
