// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface IVault {
    function totalAssets() external view returns (uint256);
    function sendFeeRevenue() external;
    function setReserves() external;
}
