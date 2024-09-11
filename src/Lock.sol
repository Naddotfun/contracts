// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ILock} from "./interfaces/ILock.sol";
import "./errors/Errors.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import {Test, console} from "forge-std/Test.sol";

contract Lock is ILock {
    using TransferHelper for IERC20;

    uint256 public amount;

    struct LockInfo {
        uint256 amount;
        uint256 unlockTime;
    }

    mapping(address => mapping(address => LockInfo[])) public locked;
    mapping(address => uint256) public lockeTokendBalance;

    function lock(address token, address account, uint256 lockTime) external {
        uint256 balance = IERC20(token).balanceOf(address(this));

        require(balance >= lockeTokendBalance[token] + amount, ERR_INVALID_AMOUNT_IN);
        uint256 amountIn = balance - lockeTokendBalance[token];
        lockeTokendBalance[token] += amountIn;
        uint256 unlockTime = block.timestamp + lockTime;
        // console.log("unlockTime", unlockTime);

        locked[token][account].push(LockInfo(amountIn, unlockTime));

        emit Locked(token, account, amountIn, unlockTime);
    }

    function unlock(address token, address account) external {
        uint256 availableAmount;
        uint256 writeIndex = 0;
        // console.log("block time stamp", block.timestamp);
        for (uint256 readIndex = 0; readIndex < locked[token][account].length; readIndex++) {
            LockInfo storage info = locked[token][account][readIndex];
            if (info.unlockTime <= block.timestamp) {
                availableAmount += info.amount;
                // 언락 조건을 만족하는 항목은 건너뜁니다 (실질적으로 삭제)
            } else {
                // 언락 조건을 만족하지 않는 항목은 유지합니다
                if (writeIndex != readIndex) {
                    locked[token][account][writeIndex] = info;
                }
                writeIndex++;
            }
        }

        // 배열의 크기를 조정합니다
        while (locked[token][account].length > writeIndex) {
            locked[token][account].pop();
        }
        // console.log("availableAmount", availableAmount);
        if (availableAmount > 0) {
            lockeTokendBalance[token] -= availableAmount;
            IERC20(token).safeTransferERC20(account, availableAmount);
            emit Unlocked(token, account, availableAmount);
        }
    }

    function getAvailabeUnlockAmount(address token, address account) external view returns (uint256) {
        uint256 availableAmount;
        for (uint256 i = 0; i < locked[token][account].length; i++) {
            LockInfo memory info = locked[token][account][i];
            // console.log("info ", info.unlockTime);
            // console.log("block time stamp", block.timestamp);
            // console.log("amount", info.amount);
            if (info.unlockTime <= block.timestamp) {
                availableAmount += info.amount;
            }
        }
        return availableAmount;
    }

    function getLockedAmount(address token, address account) external view returns (LockInfo[] memory) {
        return locked[token][account];
    }
}
