// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

// interface ILock {
//     event TimeLocked(address token, address account, uint256 amount, uint256 unlockTime);
//     event TimeUnlocked(address token, address account, uint256 amount);

//     function timeLock(address token, address account, uint256 lockTime) external;
//     function timeUnlock(address token, address account) external;
//     function getAvailabeUnlockAmount(address token, address account) external view returns (uint256);
// }

interface ILock {
    struct LockInfo {
        uint256 amount;
        uint256 unlockTime;
        bool isListingLock;
    }

    event Locked(address indexed token, address indexed account, uint256 amount, bool isListingLock);
    event Unlocked(address indexed token, address indexed account, uint256 amount);

    function lock(address token, address account, uint256 amount, uint256 unlockTime, bool isListingLock) external;
    function unlock(address token, address account) external;
    function getLockedInfo(address token, address account) external view returns (LockInfo[] memory);
}
