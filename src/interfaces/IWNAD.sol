// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface IWNAD {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function withdraw(uint256) external;
}
