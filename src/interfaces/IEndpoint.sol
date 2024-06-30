// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IEndpoint {
    event Buy(address indexed sender, uint256 amountIn, uint256 amountOut, address token, address curve);
    event Sell(address indexed sender, uint256 amountIn, uint256 amountOut, address token, address curve);
    event CreateCurve(
        address indexed sender,
        address indexed curve,
        address indexed token,
        string tokenURI,
        string name,
        string symbol
    );

    function createCurve(
        string memory name,
        string memory symbol,
        string memory tokenURI,
        uint256 amountIn,
        uint256 fee,
        uint256 deployFee
    ) external payable returns (address curve, address token);

    function buy(uint256 amountIn, uint256 fee, address token, address to, uint256 deadline) external payable;

    function buyWNad(uint256 amountIn, uint256 fee, address token, address to, uint256 deadline) external;

    function buyWNadWithPermit(
        uint256 amountIn,
        uint256 fee,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function buyAmountOutMin(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 fee,
        address token,
        address to,
        uint256 deadline
    ) external payable;

    function buyWNadAmountOutMin(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 fee,
        address token,
        address to,
        uint256 deadline
    ) external;

    function buyWNadAmountOutMinPermit(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 fee,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function buyExactAmountOut(uint256 amountOut, uint256 amountInMax, address token, address to, uint256 deadline)
        external
        payable;

    function buyExactAmountOutWNad(uint256 amountOut, uint256 amountInMax, address token, address to, uint256 deadline)
        external;

    function buyExactAmountOutWNadPermit(
        uint256 amountOut,
        uint256 amountInMax,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

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

    function sellAmountOutMin(uint256 amountIn, uint256 amountOutMin, address token, address to, uint256 deadline)
        external;

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

    function sellExactAmountOut(uint256 amountOut, uint256 amountInMax, address token, address to, uint256 deadline)
        external
        payable;

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

    function getCurveData(address _factory, address token)
        external
        view
        returns (address curve, uint256 virtualNad, uint256 virtualToken, uint256 k);

    function getCurveData(address curve) external view returns (uint256 virtualNad, uint256 virtualToken, uint256 k);

    function getAmountOut(uint256 amountIn, uint256 k, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256 amountOut);

    function getAmountIn(uint256 amountOut, uint256 k, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256 amountIn);
}
