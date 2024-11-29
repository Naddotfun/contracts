// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../errors/errors.sol";

/**
 * @title TransferHelper
 * @dev Helper functions for safely transferring ETH and ERC20 tokens
 * Adapted from https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TransferHelper.sol
 */
library TransferHelper {
    /**
     * @notice Safely transfers ERC20 tokens using a low level call
     * @dev This function handles tokens that don't return a boolean on transfer.
     * It verifies the transfer was successful by checking the call status and return data.
     * @param self The ERC20 token contract
     * @param to Address receiving the tokens
     * @param amount Amount of tokens to transfer
     */
    function safeTransferERC20(
        IERC20 self,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(self).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            ERR_TRANSFER_ERC20_FAILED
        );
    }

    /**
     * @notice Safely transfers native NAD (ETH) to an address
     * @dev Uses a low-level call with a fixed gas stipend of 2300
     * This gas stipend is enough for the receiving contract's fallback function,
     * but not enough to make an external call (preventing reentrancy)
     * @param to Address receiving the NAD
     * @param amount Amount of NAD to transfer in wei
     */
    function safeTransferNad(address to, uint256 amount) internal {
        (bool success, ) = payable(to).call{value: amount, gas: 2300}("");
        require(success, ERR_TRANSFER_NAD_FAILED);
    }

    /**
     * @notice Safely transfers ERC20 tokens using transferFrom
     * @dev Similar to safeTransferERC20, but uses transferFrom to move tokens
     * between any two addresses. Requires proper allowance to be set.
     * @param self The ERC20 token contract
     * @param from Address sending the tokens
     * @param to Address receiving the tokens
     * @param amount Amount of tokens to transfer
     */
    function safeTransferFrom(
        IERC20 self,
        address from,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(self).call(
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                from,
                to,
                amount
            )
        );

        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            ERR_TRANSFER_FROM_ERC20_FAILED
        );
    }
}
