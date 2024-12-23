// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface IBondingCurve {
    event Lock(address indexed curve);
    event Sync(
        uint256 reserveWNad,
        uint256 reserveToken,
        uint256 virtualWNative,
        uint256 virtualToken
    );

    event Buy(
        address indexed sender,
        address indexed token,
        uint256 amountIn,
        uint256 amountOut
    );
    event Sell(
        address indexed sender,
        address indexed token,
        uint256 amountIn,
        uint256 amountOut
    );
    event Listing(
        address indexed curve,
        address indexed token,
        address indexed pair,
        uint256 listingWNadAamount,
        uint256 listingTokenAmount,
        uint256 burnLiquidity
    );

    function initialize(
        address token,
        uint256 virtualWNative,
        uint256 virtualToken,
        uint256 k,
        uint256 targetWNad,
        uint8 feeDenominator,
        uint16 feeNumerator
    ) external;

    function buy(address to, uint256 amountOut) external;

    function sell(address to, uint256 amountOut) external;

    function listing() external returns (address pair);

    function getLock() external view returns (bool);

    function getK() external view returns (uint256);

    function getFeeConfig()
        external
        view
        returns (uint8 denominator, uint16 numerator);

    function getVirtualReserves()
        external
        view
        returns (uint256 virtualWNative, uint256 virtualToken);

    function getReserves()
        external
        view
        returns (uint256 reserveWNad, uint256 reserveToken);

    function getIsListing() external view returns (bool);
}
