// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ILock} from "./interfaces/ILock.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import "./errors/Errors.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import {Test, console} from "forge-std/Test.sol";

// contract Lock is ILock {
//     using TransferHelper for IERC20;

//     uint256 public amount;
//     address public factory;

//     struct TimeLockInfo {
//         uint256 amount;
//         uint256 unlockTime;
//     }

//     constructor(address _factory) {
//         factory = _factory;
//     }

//     mapping(address => mapping(address => TimeLockInfo[])) public timeLocked;

//     mapping(address => uint256) public lockeTokendBalance;

//     function listingLock(address token, address curve, address account) external {}

//     function listingUnlock(address token, address curve, address account) external {}

//     function timeLock(address token, address account, uint256 lockTime) external {
//         uint256 balance = IERC20(token).balanceOf(address(this));

//         require(balance >= lockeTokendBalance[token] + amount, ERR_INVALID_AMOUNT_IN);
//         uint256 amountIn = balance - lockeTokendBalance[token];
//         lockeTokendBalance[token] += amountIn;
//         uint256 unlockTime = block.timestamp + lockTime;
//         // console.log("unlockTime", unlockTime);

//         timeLocked[token][account].push(TimeLockInfo(amountIn, unlockTime));

//         emit TimeLocked(token, account, amountIn, unlockTime);
//     }

//     function timeUnlock(address token, address account) external {
//         uint256 availableAmount;
//         uint256 writeIndex = 0;
//         // console.log("block time stamp", block.timestamp);
//         for (uint256 readIndex = 0; readIndex < timeLocked[token][account].length; readIndex++) {
//             TimeLockInfo storage info = timeLocked[token][account][readIndex];
//             if (info.unlockTime <= block.timestamp) {
//                 availableAmount += info.amount;
//                 // 언락 조건을 만족하는 항목은 건너뜁니다 (실질적으로 삭제)
//             } else {
//                 // 언락 조건을 만족하지 않는 항목은 유지합니다
//                 if (writeIndex != readIndex) {
//                     timeLocked[token][account][writeIndex] = info;
//                 }
//                 writeIndex++;
//             }
//         }

//         // 배열의 크기를 조정합니다
//         while (timeLocked[token][account].length > writeIndex) {
//             timeLocked[token][account].pop();
//         }
//         // console.log("availableAmount", availableAmount);
//         if (availableAmount > 0) {
//             lockeTokendBalance[token] -= availableAmount;
//             IERC20(token).safeTransferERC20(account, availableAmount);
//             emit TimeUnlocked(token, account, availableAmount);
//         }
//     }

//     function getAvailabeUnlockAmount(address token, address account) external view returns (uint256) {
//         uint256 availableAmount;
//         for (uint256 i = 0; i < timeLocked[token][account].length; i++) {
//             TimeLockInfo memory info = timeLocked[token][account][i];
//             // console.log("info ", info.unlockTime);
//             // console.log("block time stamp", block.timestamp);
//             // console.log("amount", info.amount);
//             if (info.unlockTime <= block.timestamp) {
//                 availableAmount += info.amount;
//             }
//         }
//         return availableAmount;
//     }

//     function getLockedAmount(address token, address account) external view returns (TimeLockInfo[] memory) {
//         return timeLocked[token][account];
//     }
// }
// contract Lock is ILock {
//     using TransferHelper for IERC20;

//     struct LockInfo {
//         uint256 amount;
//         uint256 unlockTime;
//         //listingLock 일 경우 true 아니면 false
//         bool listingLock;
//     }

//     mapping(address => mapping(address => LockInfo[])) public locked;
//     mapping(address => uint256) public tokenBalance;

//     function lock(address token, address account, uint256 amount, uint256 unlockTime, bool listingLock) external {
//         uint256 balance = IERC20(token).balanceOf(address(this));
//         uint256 lockedBalance = tokenBalance[token];
//         require(balance > lockedBalance, ERR_INVALID_AMOUNT_IN);

//         uint256 amountIn = balance - lockedBalance;
//         tokenBalance[token] = balance;

//         if (listingLock) {
//             unlockTime = 0; // 리스팅 잠금은 시간 제한이 없음
//         } else {
//             require(unlockTime > block.timestamp, "Unlock time must be in the future");
//         }

//         locked[token][account].push(LockInfo(amount, unlockTime, listingLock));

//         emit Locked(token, account, amount, listingLock);
//     }

//     function unlock(address token, address account) external {
//         uint256 availableAmount;
//         uint256 writeIndex = 0;
//         bool isListing = IBondingCurve(token).getIsListing();
//         for (uint256 readIndex = 0; readIndex < locked[token][account].length; readIndex++) {
//             LockInfo storage info = locked[token][account][readIndex];
//             if (isListing && info.listingLock) {
//                 // 리스팅되었고 리스팅 락인 경우 무조건 해제
//                 availableAmount += info.amount;
//             } else if (!info.listingLock && info.unlockTime <= block.timestamp) {
//                 // 리스팅 락이 아니고 시간이 지난 경우 해제
//                 availableAmount += info.amount;
//             } else {
//                 // 그 외의 경우 락 유지
//                 if (writeIndex != readIndex) {
//                     locked[token][account][writeIndex] = info;
//                 }
//                 writeIndex++;
//             }
//         }

//         while (locked[token][account].length > writeIndex) {
//             locked[token][account].pop();
//         }

//         if (availableAmount > 0) {
//             tokenBalance[token] -= availableAmount;
//             IERC20(token).safeTransferERC20(account, availableAmount);
//             emit Unlocked(token, account, availableAmount);
//         }
//     }

//     function getLockedInfo(address token, address account) external view returns (LockInfo[] memory) {
//         return locked[token][account];
//     }
// }

contract Lock is ILock {
    using TransferHelper for IERC20;

    // struct LockInfo {
    //     uint256 amount;
    //     uint256 unlockTime;
    //     bool isListingLock;
    // }
    address private factory;
    mapping(address => mapping(address => LockInfo[])) private _locked;
    mapping(address => uint256) private _tokenBalance;

    constructor(address _factory) {
        factory = _factory;
    }

    function lock(address token, address account, uint256 amount, uint256 unlockTime, bool isListingLock) external {
        require(amount > 0, "Lock: Amount must be greater than 0");
        uint256 newBalance = _updateTokenBalance(token, amount);

        if (isListingLock) {
            unlockTime = 0;
        } else {
            require(unlockTime > block.timestamp, "Lock: Unlock time must be in the future");
        }

        _locked[token][account].push(LockInfo(amount, unlockTime, isListingLock));

        emit Locked(token, account, amount, isListingLock);
    }

    function unlock(address token, address account) external {
        LockInfo[] storage userLocks = _locked[token][account];
        address curve = IBondingCurveFactory(factory).getCurve(token);
        console.log("curve", curve);
        bool isListing = IBondingCurve(curve).getIsListing();
        console.log("isListing", isListing);
        (uint256 availableAmount, uint256 newLength) = _calculateUnlockAmount(userLocks, isListing);

        require(availableAmount > 0, "Lock: No available amount to unlock");
        if (availableAmount > 0) {
            _tokenBalance[token] -= availableAmount;
            IERC20(token).safeTransferERC20(account, availableAmount);
            emit Unlocked(token, account, availableAmount);
        }

        // Resize the array
        assembly {
            let currentLength := sload(userLocks.slot)
            if iszero(eq(currentLength, newLength)) { sstore(userLocks.slot, newLength) }
        }
    }

    function getLockedInfo(address token, address account) external view override returns (LockInfo[] memory) {
        return _locked[token][account];
    }

    function _updateTokenBalance(address token, uint256 amount) private returns (uint256) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 newBalance = balance + amount;
        require(newBalance >= _tokenBalance[token], "Lock: Invalid amount");
        _tokenBalance[token] = newBalance;
        return newBalance;
    }

    function _calculateUnlockAmount(LockInfo[] storage locks, bool isListing)
        private
        returns (uint256 availableAmount, uint256 newLength)
    {
        uint256 length = locks.length;
        for (uint256 i = 0; i < length; i++) {
            LockInfo storage info = locks[i];
            if (_canUnlock(info, isListing)) {
                availableAmount += info.amount;
            } else {
                locks[newLength] = info;
                newLength++;
            }
        }
    }

    function _canUnlock(LockInfo memory info, bool isListing) private view returns (bool) {
        console.log("info.isListingLock", info.isListingLock);
        console.log("isListing", isListing);
        console.log("info.unlockTime", info.unlockTime);
        console.log("block.timestamp", block.timestamp);
        return (info.isListingLock && isListing) || (!info.isListingLock && info.unlockTime <= block.timestamp);
    }
}
