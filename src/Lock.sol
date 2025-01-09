// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ILock} from "./interfaces/ILock.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./errors/Errors.sol";

/**
 * @title Lock Contract
 * @dev Implements token locking mechanism with time-based and listing-based unlock conditions
 * Allows users to lock their tokens and unlock them based on either time elapsed or token listing status
 */
contract Lock is ILock, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IBondingCurveFactory public immutable bondingCurveFactory;

    uint256 public reserves;
    uint256 public defaultLockTime;
    /// @dev Minimum lock time that can be set
    uint256 public constant MIN_LOCK_TIME = 1 days;

    /// @dev Maximum lock time that can be set
    uint256 public constant MAX_LOCK_TIME = 365 days;
    /// @dev Mapping of token address => user address => array of lock information
    mapping(address => mapping(address => LockInfo[])) public locked;

    /// @dev Mapping of token address => total locked balance
    mapping(address => uint256) public lockedTokenBalance;

    /**
     * @dev Constructor sets the initial parameters
     * @param _bondingCurveFactory Address of the bonding curve factory
     * @param _defaultLockTime Initial default lock time
     */
    constructor(
        address _bondingCurveFactory,
        uint256 _defaultLockTime
    ) Ownable(msg.sender) {
        require(_bondingCurveFactory != address(0), "Invalid factory address");
        require(
            _defaultLockTime >= MIN_LOCK_TIME &&
                _defaultLockTime <= MAX_LOCK_TIME,
            "Invalid lock time"
        );

        bondingCurveFactory = IBondingCurveFactory(_bondingCurveFactory);
        defaultLockTime = _defaultLockTime;
    }

    /**
     * @dev Locks tokens for a specified account
     * @param token Address of the token to be locked
     * @param account Address of the account for which tokens are being locked
     */
    function lock(address token, address account) external nonReentrant {
        require(token != address(0), ERR_INVALID_TOKEN_ADDRESS);
        require(account != address(0), ERR_INVALID_ACCOUNT);

        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 amountIn = balance - lockedTokenBalance[token];

        require(amountIn > 0, ERR_LOCK_INVALID_AMOUNT_IN);

        lockedTokenBalance[token] += amountIn;
        uint256 unlockTime = block.timestamp + defaultLockTime;

        locked[token][account].push(LockInfo(amountIn, unlockTime));

        emit Locked(token, account, amountIn, unlockTime);
    }

    /**
     * @dev Unlocks tokens for a specified account
     * @param token Address of the token to be unlocked
     * @param account Address of the account for which tokens are being unlocked
     */
    function unlock(address token, address account) external nonReentrant {
        require(token != address(0), ERR_INVALID_TOKEN_ADDRESS);
        require(account != address(0), ERR_INVALID_ACCOUNT);
        require(lockedTokenBalance[token] > 0, ERR_TOKEN_NOT_LOCKED);
        uint256 availableAmount = _processUnlock(token, account);

        if (availableAmount > 0) {
            lockedTokenBalance[token] -= availableAmount;
            IERC20(token).safeTransfer(account, availableAmount);
            emit Unlocked(token, account, availableAmount);
        }
    }

    /**
     * @dev Processes the unlock operation
     * @param token Token address
     * @param account Account address
     * @return Amount available for unlock
     */
    function _processUnlock(
        address token,
        address account
    ) internal returns (uint256) {
        if (_isTokenListed(token)) {
            return _processListingUnlock(token, account);
        }
        return _processTimeBasedUnlock(token, account);
    }

    /**
     * @dev Processes unlock when token is listed
     */
    function _processListingUnlock(
        address token,
        address account
    ) internal returns (uint256 availableAmount) {
        for (uint256 i = 0; i < locked[token][account].length; i++) {
            availableAmount += locked[token][account][i].amount;
        }
        if (availableAmount > 0) {
            delete locked[token][account];
        }
        return availableAmount;
    }

    /**
     * @dev Processes time-based unlock
     */
    function _processTimeBasedUnlock(
        address token,
        address account
    ) internal returns (uint256 availableAmount) {
        uint256 writeIndex = 0;

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

        return availableAmount;
    }

    /**
     * @dev Returns the amount of tokens that can be unlocked
     * @param token Address of the token
     * @param account Address of the account to check
     * @return Amount of tokens that can be unlocked
     */
    function getAvailableUnlockAmount(
        address token,
        address account
    ) external view returns (uint256) {
        uint256 availableAmount;
        bool isListing = _isTokenListed(token);

        if (isListing) {
            for (uint256 i = 0; i < locked[token][account].length; i++) {
                availableAmount += locked[token][account][i].amount;
            }
        } else {
            for (uint256 i = 0; i < locked[token][account].length; i++) {
                if (locked[token][account][i].unlockTime <= block.timestamp) {
                    availableAmount += locked[token][account][i].amount;
                }
            }
        }

        return availableAmount;
    }

    /**
     * @notice Function to retrieve all lock information for a specific token and account
     * @param token The address of the token to query
     * @param account The address of the account to query
     * @return Array of lock information for the specified token and account
     */
    function getLocked(
        address token,
        address account
    ) external view returns (LockInfo[] memory) {
        return locked[token][account];
    }

    /**
     * @notice Function to get the total locked balance of a specific token
     * @param token The address of the token to query
     * @return The total locked balance of the specified token
     */
    function getTokenLockedBalance(
        address token
    ) external view returns (uint256) {
        return lockedTokenBalance[token];
    }

    /**
     * @notice Internal function to check if a token is listed on the bonding curve
     * @param token The address of the token to check
     * @return True if the token is listed, false otherwise
     */
    function _isTokenListed(address token) internal view returns (bool) {
        address curve = bondingCurveFactory.getCurve(token);
        return IBondingCurve(curve).getIsListing();
    }

    /* ========== OWNER FUNCTIONS ========== */

    /**
     * @dev Updates the default lock time
     * @param _newLockTime New lock time duration
     */
    function updateDefaultLockTime(uint256 _newLockTime) external onlyOwner {
        require(
            _newLockTime >= MIN_LOCK_TIME && _newLockTime <= MAX_LOCK_TIME,
            "Invalid lock time"
        );

        uint256 oldTime = defaultLockTime;
        defaultLockTime = _newLockTime;
        emit DefaultLockTimeUpdated(oldTime, _newLockTime);
    }
}
