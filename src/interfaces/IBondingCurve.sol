// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface IBondingCurve {
    event Lock(address indexed market);
    event Sync(uint256 reserveBase, uint256 reserveToken, uint256 virtualBase, uint256 virtualToken);
    // event Swap(address indexed sender, uint256 amountIn, uint256 amountOut, uint256 fee, bool isBuy);
    event Buy(address indexed sender, uint256 amountIn, uint256 amountOut);
    event Sell(address indexed sender, uint256 amountIn, uint256 amountOut);
    // event Swap(
    //     address indexed sender,
    //     uint256 amount0In,
    //     uint256 amount1In,
    //     uint256 amount0Out,
    //     uint256 amount1Out,
    //     address indexed to
    // );

    function initialize(
        address wnad,
        address token,
        uint256 virtualBase,
        uint256 virtualToken,
        uint256 k,
        uint256 targetBase,
        uint8 feeDenominator,
        uint16 feeNumerator
    ) external;

    function buy(address to, uint256 fee, uint256 amountOut) external;

    function sell(address to, uint256 fee, uint256 amountOut) external;
    function getK() external view returns (uint256);
    function getFeeConfig() external view returns (uint8 denominator, uint16 numerator);
    function getVirtualReserves() external view returns (uint256 virtualBase, uint256 virtualToken);
    function getReserves() external view returns (uint256 reserveBase, uint256 reserveToken);
}
