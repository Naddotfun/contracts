// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface IBondingCurveFactory {
    /**
     * @notice Configuration struct for bonding curve parameters
     * @param deployFee Fee required to deploy a new bonding curve
     * @param listingFee Fee required for listing
     * @param tokenTotalSupply Total supply of tokens to be created
     * @param virtualNative Virtual Native reserve amount
     * @param virtualToken Virtual token reserve amount
     * @param k Constant product k = virtualNative * virtualToken
     * @param targetToken Target token amount
     * @param feeNumerator Numerator of the fee fraction
     * @param feeDenominator Denominator of the fee fraction
     */
    struct Config {
        uint256 deployFee;
        uint256 listingFee;
        uint256 tokenTotalSupply;
        uint256 virtualNative;
        uint256 virtualToken;
        uint256 k;
        uint256 targetToken;
        uint16 feeNumerator;
        uint8 feeDenominator;
    }

    struct InitializeParams {
        uint256 deployFee;
        uint256 listingFee;
        uint256 tokenTotalSupply;
        uint256 virtualNative;
        uint256 virtualToken;
        uint256 targetToken;
        uint16 feeNumerator;
        uint8 feeDenominator;
        address dexFactory;
    }

    event Create(
        address indexed owner,
        address indexed curve,
        address indexed token,
        string tokenURI,
        string name,
        string symbol,
        uint256 virtualNative,
        uint256 virtualToken
    );

    event SetInitialize(
        uint256 deployFee,
        uint256 listingFee,
        uint256 tokenTotalSupply,
        uint256 virtualNative,
        uint256 virtualToken,
        uint256 k,
        uint256 targetToken,
        uint16 feeNumerator,
        uint8 feeDominator,
        address dexFactory
    );
    event SetCore(address indexed core);

    event SetDexFactory(address indexed dexFactory);

    function create(address creator, string memory name, string memory symbol, string memory tokenUrl)
        external
        returns (address curve, address token, uint256 virtualNative, uint256 virtualToken);

    function getCurve(address token) external view returns (address curve);

    function getOwner() external view returns (address owner); // `view` 추가

    function getK() external view returns (uint256 k);

    function getCore() external view returns (address core);

    function getDexFactory() external view returns (address dexFactory);

    function getConfig() external view returns (Config memory);

    function getFeeConfig() external view returns (uint8 denominator, uint16 numerator);

    function getDelpyFee() external view returns (uint256 deployFee);

    function getListingFee() external view returns (uint256 listingFee);
}
