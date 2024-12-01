// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICore {
    function createCurve(
        address creator,
        string memory name,
        string memory symbol,
        string memory tokenURI,
        uint256 amountIn,
        uint256 fee
    )
        external
        payable
        returns (
            address curve,
            address token,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 amountOut
        );

    function buy(
        uint256 amountIn,
        uint256 fee,
        address token,
        address to,
        uint256 deadline
    ) external payable;

    function buyAmountOutMin(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 fee,
        address token,
        address to,
        uint256 deadline
    ) external payable;

    function buyExactAmountOut(
        uint256 amountOut,
        uint256 amountInMax,
        address token,
        address to,
        uint256 deadline
    ) external payable;

    function sell(
        uint256 amountIn,
        address token,
        address to,
        uint256 deadline
    ) external;

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

    function sellAmountOutMin(
        uint256 amountIn,
        uint256 amountOutMin,
        address token,
        address to,
        uint256 deadline
    ) external;

    function sellAmountOutMinWithPermit(
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

    function sellExactAmountOut(
        uint256 amountOut,
        uint256 amountInMax,
        address token,
        address to,
        uint256 deadline
    ) external payable;

    function sellExactAmountOutwithPermit(
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

    function getCurveData(
        address _factory,
        address token
    )
        external
        view
        returns (
            address curve,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 k
        );

    function getCurveData(
        address curve
    )
        external
        view
        returns (uint256 virtualNad, uint256 virtualToken, uint256 k);

    function getAmountOut(
        uint256 amountIn,
        uint256 k,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 k,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getFeeVault() external view returns (address feeVault);
}
