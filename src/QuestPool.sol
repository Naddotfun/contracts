// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import {IQuestPool} from "./interfaces/IQuestPool.sol";
import "./errors/Errors.sol";

contract QuestPool is IQuestPool {
    using TransferHelper for IERC20;

    uint256 tokenReserves;
    //총 모인 금액 설정
    uint256 totalAmount;
    uint256 rewardAmount;
    uint256 claimableTimeStamp;
    address token;
    IBondingCurve curve;

    //account => balance
    mapping(address => uint256) questBalance;

    constructor(address _curve, address _token) {
        curve = IBondingCurve(_curve);
        claimableTimeStamp = block.timestamp + 1 hours;
        token = _token;
        rewardAmount = IERC20(token).balanceOf(address(this));
    }

    function add(address account) external {
        require(block.timestamp < claimableTimeStamp, ERR_INVALID_BLOCK_TIMESTAMP);
        //보낸 토큰 확인
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 amountIn = balance - tokenReserves;
        require(amountIn > 0, ERR_INVALID_AMOUNT_IN);
        totalAmount += amountIn;
        questBalance[account] += amountIn;
        tokenReserves = balance;

        emit QuestAdded(account, amountIn);
    }

    function claim(address account) external {
        //본딩커브가 리스팅되었다면 클레임 가능 , 리스팅이 false 라면 block.timestamp 확인
        require(IBondingCurve(curve).getIsListing() || block.timestamp >= claimableTimeStamp, ERR_INVALID_CLAIM);

        require(block.timestamp >= claimableTimeStamp, ERR_INVALID_BLOCK_TIMESTAMP);
        uint256 balance = questBalance[account];
        require(balance > 0, ERR_INVALID_QUEST_BALANCE);

        questBalance[account] = 0;
        uint256 reward = rewardAmount * balance / totalAmount;

        IERC20(token).safeTransferERC20(account, reward + balance);

        emit QuestClaimed(account, reward, balance);
    }

    function getEndQuest() external view returns (bool) {
        return IBondingCurve(curve).getIsListing() || block.timestamp >= claimableTimeStamp;
    }

    function getQuestBalance(address account) external view returns (uint256) {
        return questBalance[account];
    }

    function getTotalAmount() external view returns (uint256) {
        return totalAmount;
    }

    function getRewardAmount() external view returns (uint256) {
        return rewardAmount;
    }

    function getToken() external view returns (address) {
        return token;
    }

    function getCurve() external view returns (address) {
        return address(curve);
    }

    function getClaimableTimeStamp() external view returns (uint256) {
        return claimableTimeStamp;
    }
}
