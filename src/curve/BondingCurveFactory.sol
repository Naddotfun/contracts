// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IToken} from "../token/interfaces/IToken.sol";
import {Token} from "../token/Token.sol";
import {BondingCurve} from "./BondingCurve.sol";
import {TransferHelper} from "../utils/TransferHelper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IVault} from "../vault/interfaces/IVault.sol";
import "./errors/Error.sol";

contract BondingCurveFactory is IBondingCurveFactory, ReentrancyGuard {
    using TransferHelper for IERC20;

    address private owner;

    address private dexFactory;
    address private vault;

    address private WNAD;
    Config private config;

    //token => curve
    mapping(address => address) private curves;

    //curve => isCurve
    mapping(address => bool) private isCurves;
    // 초기화에 필요한 모든 매개변수를 포함하는 구조체 정의

    struct InitializeParams {
        uint256 deployFee;
        uint256 listingFee;
        uint256 tokenTotalSupply;
        uint256 virtualNad;
        uint256 virtualToken;
        uint256 targetToken;
        uint16 feeNumerator;
        uint8 feeDenominator;
        address dexFactory;
        address vault;
        address wnad;
    }

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

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, ERR_ONLY_OWNER);
        _;
    }

    function initialize(InitializeParams memory params) external onlyOwner {
        uint256 k = params.virtualNad * params.virtualToken;
        config = Config(
            params.deployFee,
            params.listingFee,
            params.tokenTotalSupply,
            params.virtualNad,
            params.virtualToken,
            k,
            params.targetToken,
            params.feeNumerator,
            params.feeDenominator
        );

        dexFactory = params.dexFactory;
        vault = params.vault;

        WNAD = params.wnad;

        emit SetInitialize(
            params.deployFee,
            params.listingFee,
            params.tokenTotalSupply,
            params.virtualNad,
            params.virtualToken,
            k,
            params.targetToken,
            params.feeNumerator,
            params.feeDenominator,
            params.dexFactory,
            params.vault,
            params.wnad
        );
    }

    function create(string memory name, string memory symbol, string memory tokenURI)
        external
        returns (address curve, address token, uint256 virtualNad, uint256 virtualToken)
    {
        uint256 balance = IERC20(WNAD).balanceOf(address(this));
        require(balance >= config.deployFee, ERR_INVALID_DEPLOY_FEE);

        //send to fee
        IERC20(WNAD).safeTransferERC20(vault, balance);

        Config memory _config = getConfig();

        token = address(new Token(name, symbol, tokenURI));
        curve = address(new BondingCurve(WNAD, token));

        isCurves[curve] = true;

        IToken(token).mint(curve);

        IBondingCurve(curve).initialize(
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
        emit Create(msg.sender, curve, token, tokenURI, name, symbol, virtualNad, virtualToken);
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
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

    function getDexFactory() public view returns (address) {
        return dexFactory;
    }

    function getDelpyFee() public view returns (uint256 deployFee) {
        deployFee = config.deployFee;
    }

    function getListingFee() public view returns (uint256 listingFee) {
        listingFee = config.listingFee;
    }

    function getVault() public view returns (address) {
        return vault;
    }

    function getFeeNumerator() public view returns (uint256 feeNumerator) {
        feeNumerator = config.feeNumerator;
    }

    function getFeeDenominator() public view returns (uint256 feeDenominator) {
        feeDenominator = config.feeDenominator;
    }

    function isCurve(address curve) public view returns (bool) {
        return isCurves[curve];
    }
}
