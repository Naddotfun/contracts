// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ILock} from "./interfaces/ILock.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";

import "./errors/Errors.sol";

contract Lock is ILock {
    using TransferHelper for IERC20;

    address private bondingCurveFactory;
    address private owner;
    // uint256 public amount;
    uint256 public reserves;
    uint256 public defaultLockTime;

    mapping(address => mapping(address => LockInfo[])) public locked;

    //토큰 별로 락 된 잔고
    mapping(address => uint256) public lockeTokendBalance;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, ERR_LOCK_ONLY_OWNER);
        _;
    }

    function initialize(
        address _bondingCurveFactory,
        uint256 _defaultLockTime
    ) external onlyOwner {
        bondingCurveFactory = _bondingCurveFactory;
        defaultLockTime = _defaultLockTime;
    }

    function lock(address token, address account) external {
        uint256 balance = IERC20(token).balanceOf(address(this));

        // require(balance >= lockeTokendBalance[token] + amount, ERR_INVALID_AMOUNT_IN);

        uint256 amountIn = balance - lockeTokendBalance[token];
        require(amountIn > 0, ERR_LOCK_INVALID_AMOUNT_IN);
        lockeTokendBalance[token] += amountIn;
        uint256 unlockTime = block.timestamp + defaultLockTime;

        locked[token][account].push(LockInfo(amountIn, unlockTime));

        emit Locked(token, account, amountIn, unlockTime);
    }
    //unlock 해제 조건
    // 1. Bonding Curve 가 리스팅 되었을때
    // 2. 락 시간이 지났을때

    function unlock(address token, address account) external {
        uint256 availableAmount;
        uint256 writeIndex = 0;

        address curve = IBondingCurveFactory(bondingCurveFactory).getCurve(
            token
        );
        bool isListing = IBondingCurve(curve).getIsListing();

        if (isListing) {
            // 리스팅된 경우 모든 토큰 언락
            availableAmount = 0;
            for (uint256 i = 0; i < locked[token][account].length; i++) {
                availableAmount += locked[token][account][i].amount;
            }
            // 모든 락 정보 삭제
            delete locked[token][account];
        } else {
            // 기존 로직: 시간에 따른 부분 언락
            for (
                uint256 readIndex = 0;
                readIndex < locked[token][account].length;
                readIndex++
            ) {
                LockInfo storage info = locked[token][account][readIndex];
                if (info.unlockTime <= block.timestamp) {
                    availableAmount += info.amount;
                    // 언락 조건을 만족하는 항목은 건너뜀
                } else {
                    // 언락 조건을 만족하지 않는 항목은 유지
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
        }

        if (availableAmount > 0) {
            lockeTokendBalance[token] -= availableAmount;
            IERC20(token).safeTransferERC20(account, availableAmount);
            emit Unlocked(token, account, availableAmount);
        }
    }

    function getAvailabeUnlockAmount(
        address token,
        address account
    ) external view returns (uint256) {
        uint256 availableAmount;
        for (uint256 i = 0; i < locked[token][account].length; i++) {
            LockInfo memory info = locked[token][account][i];

            if (info.unlockTime <= block.timestamp) {
                availableAmount += info.amount;
            }
        }
        return availableAmount;
    }

    function getLocked(
        address token,
        address account
    ) external view returns (LockInfo[] memory) {
        return locked[token][account];
    }

    function getTokenLockedBalance(
        address token
    ) external view returns (uint256) {
        return lockeTokendBalance[token];
    }
}
