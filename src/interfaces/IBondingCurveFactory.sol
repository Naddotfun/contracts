// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface IBondingCurveFactory {
    event Create(address indexed market, address indexed token, address indexed creator);
    event SetInitialize(
        uint256 deployFee,
        uint256 tokenTotalSupply,
        uint256 virtualNad,
        uint256 virtualToken,
        uint256 k,
        uint256 targetToken,
        uint16 feeNumerator,
        uint8 feeDominator
    );
    event SetEndpoint(address indexed endpoint);

    function create(string memory name, string memory symbol, string memory tokenUrl)
        external
        returns (address curve, address token);
    function getCurve(address token) external view returns (address market);
    function getOwner() external view returns (address owner); // `view` 추가
    function getK() external view returns (uint256 k);
    function getEndpoint() external view returns (address endpoint);
    function getDelpyFee() external view returns (uint256 deployFee);
}
