// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IToken {
    function mint(address to) external;
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
}
