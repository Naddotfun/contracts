// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {ILock} from "../lock/interfaces/ILock.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {TransferHelper} from "../utils/TransferHelper.sol";

contract LockRouter {
    using TransferHelper for IERC20;

    address private Lock;

    constructor(address _lock) {
        Lock = _lock;
    }

    function lock(address token, address account) external {
        uint256 allowance = IERC20(token).allowance(account, address(this));
        IERC20(token).safeTransferERC20(Lock, allowance);
        ILock(Lock).lock(token, account);
    }

    function unlock(address token, address account) external {
        ILock(Lock).unlock(token, account);
    }

    
}
