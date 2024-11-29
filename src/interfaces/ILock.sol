// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface ILock {
    event Locked(
        address token,
        address account,
        uint256 amount,
        uint256 unlockTime
    );
    event Unlocked(address token, address account, uint256 amount);

    struct LockInfo {
        uint256 amount;
        uint256 unlockTime;
    }

    function lock(address token, address account) external;
    function unlock(address token, address account) external;
    function getAvailabeUnlockAmount(
        address token,
        address account
    ) external view returns (uint256);
    function getLocked(
        address token,
        address account
    ) external view returns (LockInfo[] memory);
    function getTokenLockedBalance(
        address token
    ) external view returns (uint256);
}
