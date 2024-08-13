// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IToken} from "./interfaces/IToken.sol";
import {Token} from "./Token.sol";
import {BondingCurve} from "./BondingCurve.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import "./errors/Errors.sol";

contract BondingCurveFactory is IBondingCurveFactory, ReentrancyGuard {
    address private owner;
    address private endpoint;
    address private dexFactory;
    address public immutable WNAD;
    Config private config;
    mapping(address => address) private curves;

    struct Config {
        uint256 deployFee;
        uint256 listingFee;
        uint256 tokenTotalSupply;
        uint256 virtualNad;
        uint256 virtualToken;
        uint256 k;
        uint256 targetToken;
        uint16 feeNumerator;
        uint8 feeDenominator;
    }

    constructor(address _owner, address _wnad) {
        owner = _owner;
        WNAD = _wnad;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, ERR_ONLY_OWNER);
        _;
    }

    modifier onlyEndpoint() {
        require(msg.sender == endpoint, ERR_ONLY_ENDPOINT);
        _;
    }

    function initialize(
        uint256 deployFee,
        uint256 listingFee,
        uint256 tokenTotalSupply,
        uint256 virtualNad,
        uint256 virtualToken,
        uint256 targetToken,
        uint16 feeNumerator,
        uint8 feeDenominator,
        address _dexFactory
    ) external onlyOwner {
        uint256 k = virtualNad * virtualToken;
        config = Config(
            deployFee,
            listingFee,
            tokenTotalSupply,
            virtualNad,
            virtualToken,
            k,
            targetToken,
            feeNumerator,
            feeDenominator
        );
        dexFactory = _dexFactory;
        emit SetInitialize(
            deployFee,
            listingFee,
            tokenTotalSupply,
            virtualNad,
            virtualToken,
            k,
            targetToken,
            feeNumerator,
            feeDenominator,
            dexFactory
        );
    }

    function create(string memory name, string memory symbol, string memory tokenURI)
        external
        onlyEndpoint
        returns (address curve, address token, uint256 virtualNad, uint256 virtualToken)
    {
        Config memory _config = getConfig();

        curve = address(new BondingCurve());
        token = address(new Token(name, symbol, tokenURI));

        IToken(token).mint(curve);

        IBondingCurve(curve).initialize(
            WNAD,
            token,
            _config.virtualNad,
            _config.virtualToken,
            _config.k,
            _config.targetToken,
            _config.feeDenominator,
            _config.feeNumerator
        );

        curves[token] = curve;
        virtualNad = _config.virtualNad;
        virtualToken = _config.virtualToken;
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
    }

    function setEndpoint(address _endpoint) external onlyOwner {
        endpoint = _endpoint;
        emit SetEndpoint(_endpoint);
    }

    function getConfig() public view returns (Config memory) {
        return config;
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function getCurve(address token) public view override returns (address curve) {
        curve = curves[token];
    }

    function getK() public view returns (uint256 k) {
        k = config.k;
    }

    function getEndpoint() public view returns (address _endpoint) {
        _endpoint = endpoint;
    }

    function getDexFactory() public view returns (address) {
        return dexFactory;
    }

    function getDelpyFee() public view returns (uint256 deployFee) {
        deployFee = config.deployFee;
    }

    function getListingFee() public view returns (uint256 listingFee) {
        listingFee = config.listingFee;
    }
}
