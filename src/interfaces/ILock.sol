// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface ILock {
    event Locked(address token, address account, uint256 amount, uint256 unlockTime);
    event Unlocked(address token, address account, uint256 amount);

    function lock(address token, address account, uint256 lockTime) external;
    function unlock(address token, address account) external;
    function getAvailabeUnlockAmount(address token, address account) external view returns (uint256);
}
