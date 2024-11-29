// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;
import {ICore} from "./interfaces/ICore.sol";
import {IMintParty} from "./interfaces/IMintParty.sol";
import {IMintPartyFactory} from "./interfaces/IMintPartyFactory.sol";
import {MintParty} from "./MintParty.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import "./errors/Errors.sol";

contract MintPartyFactory is IMintPartyFactory {
    using TransferHelper for IERC20;

    address private owner;
    address core;
    address WNad;
    address lock;
    address vault;

    uint256 maxParticipants;
    //account => party
    mapping(address => address) parties;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, ERR_ONLY_OWNER);
        _;
    }

    function initialize(
        address _core,
        address _wnad,
        address _lock,
        address _vault,
        uint256 _maxParticipants
    ) external onlyOwner {
        core = core;
        WNad = _wnad;
        lock = _lock;
        vault = _vault;
        maxParticipants = _maxParticipants;
    }

    function create(
        address account,
        string memory name,
        string memory symbol,
        string memory tokenURI,
        uint256 fundingAmount,
        uint8 whiteListCount
    ) external payable returns (address) {
        require(
            whiteListCount <= maxParticipants,
            ERR_MINT_PARTY_FACTORY_INVALID_MAXIMUM_WHITELIST
        );
        require(
            msg.value == fundingAmount,
            ERR_MINT_PARTY_FACTORY_INVALID_FUNDING_AMOUNT
        );
        // 기존 파티가 존재하는지 확인
        address existingParty = parties[account];

        // 기존 파티가 없거나 (address(0)), 있다면 종료되었는지 확인
        if (existingParty != address(0)) {
            require(
                IMintParty(existingParty).getFinished(),
                ERR_MINT_PARTY_FACTORY_NOT_FINISHED
            );
        }

        // 새로운 MintParty 생성
        MintParty party = new MintParty(account, address(this), WNad, lock);
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

        IMintParty(party).deposit{value: fundingAmount}(account);
        // uint256 balance = IERC20(WNad).balanceOf(address(this));

        parties[account] = address(party);
        return address(party);
    }

    function getParty(address account) external view returns (address) {
        return parties[account];
    }

    function getVault() external view returns (address) {
        return vault;
    }
}
