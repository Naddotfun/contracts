// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IToken} from "./interfaces/IToken.sol";
import {Token} from "./Token.sol";
import {BondingCurve} from "./BondingCurve.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import "./errors/Errors.sol";

/**
 * @title BondingCurveFactory
 * @notice Factory contract for creating and managing bonding curve pairs
 * @dev This contract handles the creation of new bonding curves and their associated tokens
 */
contract BondingCurveFactory is IBondingCurveFactory {
    address private owner;
    address private core;
    address private dexFactory;
    address public immutable WNAD;
    Config private config;
    mapping(address => address) private curves;

    /**
     * @notice Constructor initializes the factory with essential addresses
     * @param _owner Address of the contract owner
     * @param _core Address of the core contract
     * @param _wnad Address of the WNAD token
     */
    constructor(address _owner, address _core, address _wnad) {
        owner = _owner;
        WNAD = _wnad;
        core = _core;
    }

    /**
     * @notice Configuration struct for bonding curve parameters
     * @param deployFee Fee required to deploy a new bonding curve
     * @param listingFee Fee required for listing
     * @param tokenTotalSupply Total supply of tokens to be created
     * @param virtualNad Virtual NAD reserve amount
     * @param virtualToken Virtual token reserve amount
     * @param k Constant product k = virtualNad * virtualToken
     * @param targetToken Target token amount
     * @param feeNumerator Numerator of the fee fraction
     * @param feeDenominator Denominator of the fee fraction
     */
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

    /**
     * @notice Modifier to restrict function access to owner only
     */
    modifier onlyOwner() {
        require(msg.sender == owner, ERR_BONDING_CURVE_FACTORY_ONLY_OWNER);
        _;
    }

    /**
     * @notice Modifier to restrict function access to core contract only
     */
    modifier onlyCore() {
        require(msg.sender == core, ERR_BONDING_CURVE_FACTORY_ONLY_CORE);
        _;
    }

    /**
     * @notice Initializes the factory with configuration parameters
     * @param params Initialization parameters struct
     */
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

    /**
     * @notice Creates a new bonding curve and associated token
     * @param creator Address of the creator
     * @param name Token name
     * @param symbol Token symbol
     * @param tokenURI Token URI for metadata
     * @return curve Address of the created bonding curve
     * @return token Address of the created token
     * @return virtualNad Initial virtual NAD reserve
     * @return virtualToken Initial virtual token reserve
     */
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

        curve = address(new BondingCurve(core, WNAD));
        token = address(new Token(name, symbol, tokenURI));

        IToken(token).mint(curve);

        IBondingCurve(curve).initialize(
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

    /**
     * @notice Updates the owner address
     * @param _owner New owner address
     */
    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
    }

    /**
     * @notice Updates the core contract address
     * @param _core New core contract address
     */
    function setCore(address _core) external onlyOwner {
        core = _core;
        emit SetCore(_core);
    }

    /**
     * @notice Retrieves the current configuration
     * @return Current configuration struct
     */
    function getConfig() public view returns (Config memory) {
        return config;
    }

    /**
     * @notice Gets the current owner address
     * @return Current owner address
     */
    function getOwner() public view returns (address) {
        return owner;
    }

    /**
     * @notice Gets the bonding curve address for a given token
     * @param token Token address to query
     * @return curve Address of the corresponding bonding curve
     */
    function getCurve(
        address token
    ) public view override returns (address curve) {
        curve = curves[token];
    }

    /**
     * @notice Gets the constant product k value
     * @return k Current k value
     */
    function getK() public view returns (uint256 k) {
        k = config.k;
    }

    /**
     * @notice Gets the core contract address
     * @return _core Current core contract address
     */
    function getCore() public view returns (address _core) {
        _core = core;
    }

    /**
     * @notice Gets the DEX factory address
     * @return Current DEX factory address
     */
    function getDexFactory() public view returns (address) {
        return dexFactory;
    }

    /**
     * @notice Gets the current deploy fee
     * @return deployFee Current deploy fee amount
     */
    function getDelpyFee() public view returns (uint256 deployFee) {
        deployFee = config.deployFee;
    }

    /**
     * @notice Gets the current listing fee
     * @return listingFee Current listing fee amount
     */
    function getListingFee() public view returns (uint256 listingFee) {
        listingFee = config.listingFee;
    }

    /**
     * @notice Gets the current fee configuration
     * @return denominator Fee denominator
     * @return numerator Fee numerator
     */
    function getFeeConfig()
        public
        view
        returns (uint8 denominator, uint16 numerator)
    {
        denominator = config.feeDenominator;
        numerator = config.feeNumerator;
    }
}
