// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../errors/errors.sol";

/**
 * @title TransferHelper
 * @dev Helper functions for safely transferring Native
 */
library TransferHelper {
    /**
     * @notice Safely transfers native NATIVE (ETH) to an address
     * @dev Uses a low-level call with a fixed gas stipend of 2300
     * This gas stipend is enough for the receiving contract's fallback function,
     * but not enough to make an external call (preventing reentrancy)
     * @param to Address receiving the NATIVE
     * @param amount Amount of NATIVE to transfer in wei
     */
    function safeTransferNative(address to, uint256 amount) internal {
        (bool success, ) = payable(to).call{value: amount, gas: 2300}("");
        require(success, ERR_TRANSFER_NATIVE_FAILED);
    }
}
