// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ILock} from "./interfaces/ILock.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";

import "./errors/Errors.sol";

/**
 * @title Lock Contract
 * @dev Implements token locking mechanism with time-based and listing-based unlock conditions
 * Allows users to lock their tokens and unlock them based on either time elapsed or token listing status
 */
contract Lock is ILock {
    using TransferHelper for IERC20;

    address private bondingCurveFactory;
    address private owner;
    uint256 public reserves;
    uint256 public defaultLockTime;

    /// @dev Mapping of token address => user address => array of lock information
    mapping(address => mapping(address => LockInfo[])) public locked;

    /// @dev Mapping of token address => total locked balance
    mapping(address => uint256) public lockeTokendBalance;

    /**
     * @dev Constructor sets the deployer as the owner
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Modifier to restrict function access to contract owner only
     */
    modifier onlyOwner() {
        require(msg.sender == owner, ERR_LOCK_ONLY_OWNER);
        _;
    }

    /**
     * @dev Initializes the contract with bonding curve factory address and default lock time
     * @param _bondingCurveFactory Address of the bonding curve factory contract
     * @param _defaultLockTime Default duration for which tokens will be locked
     */
    function initialize(
        address _bondingCurveFactory,
        uint256 _defaultLockTime
    ) external onlyOwner {
        bondingCurveFactory = _bondingCurveFactory;
        defaultLockTime = _defaultLockTime;
    }

    /**
     * @dev Locks tokens for a specified account
     * @param token Address of the token to be locked
     * @param account Address of the account for which tokens are being locked
     * Calculates the amount to lock based on the contract's current balance
     */
    function lock(address token, address account) external {
        uint256 balance = IERC20(token).balanceOf(address(this));

        uint256 amountIn = balance - lockeTokendBalance[token];
        require(amountIn > 0, ERR_LOCK_INVALID_AMOUNT_IN);
        lockeTokendBalance[token] += amountIn;
        uint256 unlockTime = block.timestamp + defaultLockTime;

        locked[token][account].push(LockInfo(amountIn, unlockTime));

        emit Locked(token, account, amountIn, unlockTime);
    }

    /**
     * @dev Unlocks tokens for a specified account
     * Unlock conditions:
     * 1. When the token is listed on Bonding Curve
     * 2. When the lock time has expired
     * @param token Address of the token to be unlocked
     * @param account Address of the account for which tokens are being unlocked
     */
    function unlock(address token, address account) external {
        uint256 availableAmount;
        uint256 writeIndex = 0;

        address curve = IBondingCurveFactory(bondingCurveFactory).getCurve(
            token
        );
        bool isListing = IBondingCurve(curve).getIsListing();

        if (isListing) {
            // If token is listed, unlock all tokens
            availableAmount = 0;
            for (uint256 i = 0; i < locked[token][account].length; i++) {
                availableAmount += locked[token][account][i].amount;
            }
            delete locked[token][account];
        } else {
            // If token is not listed, unlock based on time
            for (
                uint256 readIndex = 0;
                readIndex < locked[token][account].length;
                readIndex++
            ) {
                LockInfo storage info = locked[token][account][readIndex];
                if (info.unlockTime <= block.timestamp) {
                    availableAmount += info.amount;
                } else {
                    if (writeIndex != readIndex) {
                        locked[token][account][writeIndex] = info;
                    }
                    writeIndex++;
                }
            }

            while (locked[token][account].length > writeIndex) {
                locked[token][account].pop();
            }
        }

        if (availableAmount > 0) {
            lockeTokendBalance[token] -= availableAmount;
            IERC20(token).safeTransferERC20(account, availableAmount);
            emit Unlocked(token, account, availableAmount);
        }
    }

    /**
     * @dev Returns the amount of tokens that can be unlocked for a specific account
     * @param token Address of the token
     * @param account Address of the account to check
     * @return Amount of tokens that can be unlocked
     */
    function getAvailabeUnlockAmount(
        address token,
        address account
    ) external view returns (uint256) {
        uint256 availableAmount;
        for (uint256 i = 0; i < locked[token][account].length; i++) {
            LockInfo memory info = locked[token][account][i];

            if (info.unlockTime <= block.timestamp) {
                availableAmount += info.amount;
            }
        }
        return availableAmount;
    }

    /**
     * @dev Returns all lock information for a specific token and account
     * @param token Address of the token
     * @param account Address of the account
     * @return Array of LockInfo structs containing lock details
     */
    function getLocked(
        address token,
        address account
    ) external view returns (LockInfo[] memory) {
        return locked[token][account];
    }

    /**
     * @dev Returns the total amount of tokens locked for a specific token
     * @param token Address of the token
     * @return Total amount of tokens locked
     */
    function getTokenLockedBalance(
        address token
    ) external view returns (uint256) {
        return lockeTokendBalance[token];
    }
}
