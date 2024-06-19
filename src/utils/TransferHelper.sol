// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../errors/errors.sol";
// @dev Adapted from https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TransferHelper.sol

library TransferHelper {
    function safeTransferERC20(IERC20 self, address to, uint256 amount) internal {
        (bool success, bytes memory data) =
            address(self).call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), ERR_TRANSFER_FAILED);
    }

    function safeTransferNad(address to, uint256 amount) internal {
        (bool success,) = payable(to).call{value: amount, gas: 2300}("");
        require(success, ERR_TRANSFER_FAILED);
    }

    function safeTransferFrom(IERC20 self, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) =
            address(self).call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));

        require(success && (data.length == 0 || abi.decode(data, (bool))), ERR_TRANSFER_FAILED);
    }
}
