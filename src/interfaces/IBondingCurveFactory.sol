// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface IBondingCurveFactory {
    event Create(address indexed market, address indexed token, address indexed creator);

    function create(string memory name, string memory symbol)
        external
        payable
        returns (address market, address token); // `payable` 추가
    function getCurve(address token) external view returns (address market);
    function getOwner() external view returns (address owner); // `view` 추가
    function getK() external view returns (uint256 k);
    function getEndpoint() external view returns (address endpoint);
}
