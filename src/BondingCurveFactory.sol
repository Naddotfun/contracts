// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IToken} from "./interfaces/IToken.sol";
import {Token} from "./Token.sol";
import {BondingCurve} from "./BondingCurve.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import "./errors/Errors.sol";

contract BondingCurveFactory is IBondingCurveFactory {
    address private owner;
    address private core;
    address private dexFactory;
    address public immutable WNAD;
    Config private config;
    mapping(address => address) private curves;

    constructor(address _owner, address _core, address _wnad) {
        owner = _owner;
        WNAD = _wnad;
        core = _core;
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
    modifier onlyOwner() {
        require(msg.sender == owner, ERR_ONLY_OWNER);
        _;
    }

    modifier onlyCore() {
        require(msg.sender == core, ERR_ONLY_CORE);
        _;
    }

    function initialize(InitializeParams memory params) public onlyOwner {
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
            dexFactory
        );
    }

    function create(
        address creator,
        string memory name,
        string memory symbol,
        string memory tokenURI
    )
        external
        onlyCore
        returns (
            address curve,
            address token,
            uint256 virtualNad,
            uint256 virtualToken
        )
    {
        Config memory _config = getConfig();

        curve = address(new BondingCurve(core));
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
        emit Create(
            creator,
            curve,
            token,
            tokenURI,
            name,
            symbol,
            virtualNad,
            virtualToken
        );
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
    }

    function setCore(address _core) external onlyOwner {
        core = _core;
        emit SetCore(_core);
    }

    function getConfig() public view returns (Config memory) {
        return config;
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function getCurve(
        address token
    ) public view override returns (address curve) {
        curve = curves[token];
    }

    function getK() public view returns (uint256 k) {
        k = config.k;
    }

    function getCore() public view returns (address _core) {
        _core = core;
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
    function getFeeConfig()
        public
        view
        returns (uint8 denominator, uint16 numerator)
    {
        denominator = config.feeDenominator;
        numerator = config.feeNumerator;
    }
}
