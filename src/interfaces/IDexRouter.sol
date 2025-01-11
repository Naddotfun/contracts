// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IDexRouter {
    function dexFactory() external view returns (address);

    function WNATIVE() external view returns (address);

    function vault() external view returns (address);

    function getFeeConfig() external view returns (uint256 denominator, uint256 numerator);

    function buy(uint256 amountIn, uint256 fee, address token, address to, uint256 deadline) external payable;

    function protectBuy(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 fee,
        address token,
        address to,
        uint256 deadline
    ) external payable;

    function exactOutBuy(uint256 amountOut, uint256 amountInMax, address token, address to, uint256 deadline)
        external
        payable;

    function sell(uint256 amountIn, address token, address to, uint256 deadline) external;

    function sellPermit(
        uint256 amountIn,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function protectSell(uint256 amountIn, uint256 amountOutMin, address token, address to, uint256 deadline)
        external;

    function protectSellPermit(
        uint256 amountIn,
        uint256 amountOutMin,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function exactOutSell(uint256 amountOut, uint256 amountInMax, address token, address to, uint256 deadline)
        external
        payable;

    function exactOutSellPermit(
        uint256 amountOut,
        uint256 amountInMax,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;
}
