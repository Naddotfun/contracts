// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IWNAD} from "./interfaces/IWNAD.sol";
import {IFeeVault} from "./interfaces/IFeeVault.sol";
import "./errors/Errors.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";

/**
 * @title FeeVault
 * @dev A simple multisig vault contract for managing WNAD token withdrawals.
 * Only authorized owners can propose and sign withdrawal requests.
 */
contract FeeVault is IFeeVault {
    // WNAD token interface
    IWNAD public immutable wnad;

    // Multisig related state variables
    mapping(address => bool) public isOwner;
    uint256 public requiredSignatures;
    uint256 public ownerCount;

    // Withdrawal proposal structure
    struct WithdrawalProposal {
        address receiver;
        uint256 amount;
        uint256 signatureCount;
        mapping(address => bool) hasSignedWithdrawal;
        bool executed;
    }

    // Mapping to store withdrawal proposals
    mapping(uint256 => WithdrawalProposal) public withdrawalProposals;
    uint256 public proposalCount;

    /**
     * @notice Fallback function to receive NAD
     * @dev Only accepts NAD from the WNAD contract
     */
    receive() external payable {
        assert(msg.sender == address(wnad)); // only accept NAD via fallback from the WNAD contract
    }

    /**
     * @dev Constructor to initialize the vault with initial owners
     * @param _wnad WNAD token address
     * @param _owners Initial list of owner addresses
     * @param _requiredSignatures Number of signatures required for withdrawal
     */
    constructor(
        address _wnad,
        address[] memory _owners,
        uint256 _requiredSignatures
    ) {
        require(_wnad != address(0), ERR_FEE_VAULT_INVALID_WNAD_ADDRESS);
        require(_owners.length > 0, ERR_FEE_VAULT_NO_OWNERS);
        require(
            _requiredSignatures > 0 && _requiredSignatures <= _owners.length,
            ERR_FEE_VAULT_INVALID_SIGNATURES_REQUIRED
        );

        wnad = IWNAD(_wnad);

        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), ERR_FEE_VAULT_INVALID_OWNER);
            require(!isOwner[_owners[i]], ERR_FEE_VAULT_DUPLICATE_OWNER);

            isOwner[_owners[i]] = true;
            ownerCount++;
        }

        requiredSignatures = _requiredSignatures;
    }

    /**
     * @dev Returns the total balance of WNAD in the vault
     */
    function totalAssets() public view returns (uint256) {
        return wnad.balanceOf(address(this));
    }

    /**
     * @dev Modifier to restrict function access to owners only
     */
    modifier onlyOwner() {
        require(isOwner[msg.sender], ERR_FEE_VAULT_NOT_OWNER);
        _;
    }

    /**
     * @dev Proposes a new withdrawal
     * @param receiver Address to receive the withdrawn assets
     * @param amount Amount of WNAD to withdraw
     */
    function proposeWithdrawal(
        address receiver,
        uint256 amount
    ) external onlyOwner {
        require(receiver != address(0), ERR_FEE_VAULT_INVALID_RECEIVER);
        require(amount > 0, ERR_FEE_VAULT_INVALID_AMOUNT);
        require(amount <= totalAssets(), ERR_FEE_VAULT_INSUFFICIENT_BALANCE);

        uint256 proposalId = proposalCount++;
        WithdrawalProposal storage proposal = withdrawalProposals[proposalId];
        proposal.receiver = receiver;
        proposal.amount = amount;
        proposal.signatureCount = 1;
        proposal.hasSignedWithdrawal[msg.sender] = true;

        emit WithdrawalProposed(proposalId, receiver, amount);
        emit WithdrawalSigned(proposalId, msg.sender);
    }

    /**
     * @dev Signs an existing withdrawal proposal
     * @param proposalId ID of the withdrawal proposal
     */
    function signWithdrawal(uint256 proposalId) external onlyOwner {
        WithdrawalProposal storage proposal = withdrawalProposals[proposalId];
        require(
            proposal.receiver != address(0),
            ERR_FEE_VAULT_INVALID_PROPOSAL
        );
        require(!proposal.executed, ERR_FEE_VAULT_ALREADY_EXECUTED);
        require(
            !proposal.hasSignedWithdrawal[msg.sender],
            ERR_FEE_VAULT_ALREADY_SIGNED
        );

        proposal.hasSignedWithdrawal[msg.sender] = true;
        proposal.signatureCount++;

        emit WithdrawalSigned(proposalId, msg.sender);

        if (proposal.signatureCount >= requiredSignatures) {
            proposal.executed = true;
            _executeWithdrawal(proposal.receiver, proposalId, proposal.amount);
        }
    }

    /**
     * @dev Internal function to execute a withdrawal proposal
     * @param receiver Address to receive the withdrawn assets
     * @param proposalId ID of the withdrawal proposal
     * @param amount Amount of WNAD to withdraw
     */
    function _executeWithdrawal(
        address receiver,
        uint proposalId,
        uint amount
    ) private {
        IWNAD(wnad).withdraw(amount);
        TransferHelper.safeTransferNad(receiver, amount);

        emit WithdrawalExecuted(proposalId, receiver, amount);
    }
}
