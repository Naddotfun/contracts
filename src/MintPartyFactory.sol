// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {ICore} from "./interfaces/ICore.sol";
import {IMintParty} from "./interfaces/IMintParty.sol";
import {IMintPartyFactory} from "./interfaces/IMintPartyFactory.sol";
import {MintParty} from "./MintParty.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import "./errors/Errors.sol";

/**
 * @title MintPartyFactory Contract
 * @dev Factory contract for creating and managing MintParty instances
 * Handles the deployment and initialization of new MintParty contracts
 * and maintains a registry of parties created by accounts
 */
contract MintPartyFactory is IMintPartyFactory {
    using TransferHelper for IERC20;

    address private owner;
    address immutable core;
    address immutable WNad;
    address immutable lock;
    address immutable bondingCurveFactory;
    /// @dev Maximum number of participants allowed in a mint party
    uint256 maxWhiteList;
    /// @dev Mapping of account address to their mint party contract address
    mapping(address => address) parties;

    /**
     * @dev Constructor sets the deployer as the owner
     * @param _core Address of the core contract
     * @param _wnad Address of the WNAD token
     * @param _lock Address of the lock contract
     */
    constructor(
        address _core,
        address _wnad,
        address _lock,
        address _bondingCurveFactory
    ) {
        owner = msg.sender;
        core = _core;
        WNad = _wnad;
        lock = _lock;
        bondingCurveFactory = _bondingCurveFactory;
    }

    /**
     * @dev Modifier to restrict function access to contract owner only
     */
    modifier onlyOwner() {
        require(msg.sender == owner, ERR_MINT_PARTY_FACTORY_ONLY_OWNER);
        _;
    }

    /**
     * @dev Initializes the factory with required contract addresses and configurations
  
     * @param _maxWhiteList Maximum number of participants allowed in a party
     */
    function initialize(uint256 _maxWhiteList) external onlyOwner {
        maxWhiteList = _maxWhiteList;
    }

    /**
     * @dev Creates a new MintParty instance
     * @param account Address of the party creator
     * @param name Token name
     * @param symbol Token symbol
     * @param tokenURI Token URI for metadata
     * @param fundingAmount Required funding amount per participant
     * @param whiteListCount Maximum number of whitelist participants
     * @return Address of the newly created MintParty contract
     * Requirements:
     * - Whitelist count must not exceed maximum participants
     * - Sent value must match funding amount
     * - Previous party (if exists) must be finished
     */
    function create(
        address account,
        string memory name,
        string memory symbol,
        string memory tokenURI,
        uint256 fundingAmount,
        uint8 whiteListCount
    ) external payable returns (address) {
        require(
            whiteListCount <= maxWhiteList,
            ERR_MINT_PARTY_FACTORY_INVALID_MAXIMUM_WHITELIST
        );
        require(
            msg.value == fundingAmount,
            ERR_MINT_PARTY_FACTORY_INVALID_FUNDING_AMOUNT
        );

        // Check if account has an existing party
        address existingParty = parties[account];

        // Verify existing party is finished or doesn't exist
        if (existingParty != address(0)) {
            require(
                IMintParty(existingParty).getFinished(),
                ERR_MINT_PARTY_FACTORY_NOT_FINISHED
            );
        }

        // Create new MintParty instance
        MintParty party = new MintParty(
            account,
            core,
            WNad,
            lock,
            bondingCurveFactory
        );
        party.initialize(
            account,
            name,
            symbol,
            tokenURI,
            fundingAmount,
            whiteListCount
        );
        emit MintPartyCreated(
            address(party),
            account,
            fundingAmount,
            whiteListCount,
            name,
            symbol,
            tokenURI
        );

        // Make initial deposit for party creator
        IMintParty(party).deposit{value: fundingAmount}(account);
        parties[account] = address(party);
        return address(party);
    }

    /**
     * @dev Returns the MintParty contract address for a given account
     * @param account Address of the account
     * @return Address of the associated MintParty contract
     */
    function getParty(address account) external view returns (address) {
        return parties[account];
    }
}
