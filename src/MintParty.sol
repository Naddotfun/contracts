// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;
import {console} from "forge-std/console.sol";
import {ICore} from "./interfaces/ICore.sol";
import {IWNative} from "./interfaces/IWNative.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ILock} from "./interfaces/ILock.sol";
import {IMintParty} from "./interfaces/IMintParty.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {BondingCurveLibrary} from "./utils/BondingCurveLibrary.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./errors/Errors.sol";

/**
 * @title MintParty Contract
 * @dev Implements a collective token minting mechanism where multiple participants can pool funds
 * to create a new token with a bonding curve. Includes whitelist functionality and equal distribution
 * of newly minted tokens among participants.
 */
contract MintParty is IMintParty, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address private owner;
    address immutable core;
    address immutable wNative;
    address immutable lock;
    address immutable mintPartyFactory;
    address immutable bondingCurveFactory;

    bool private finished;
    Config private config;
    /// @dev Mapping of address to their deposited balance
    mapping(address => uint256) private balances;
    /// @dev Mapping of whitelisted addresses to their contribution amount
    mapping(address => uint256) public whitelists;
    /// @dev Array of whitelisted participant addresses
    address[] public whitelistAccounts;

    /// @dev Total balance of funds in the mint party
    uint256 totalBalance;

    event TokensLocked(address indexed account, uint256 amount);

    /**
     * @dev Modifier to restrict function access to contract owner only
     */
    modifier onlyOwner() {
        require(msg.sender == owner, ERR_MINT_PARTY_ONLY_OWNER);
        _;
    }

    /**
     * @dev Modifier to restrict function access to factory contract only
     */
    modifier onlyFactory() {
        require(msg.sender == mintPartyFactory, ERR_MINT_PARTY_ONLY_FACTORY);
        _;
    }

    /**
     * @dev Constructor initializes the contract with required addresses
     * @param _owner Address of the party owner
     * @param _core Address of the core contract
     * @param _wNative Address of the WNATVIE token
     * @param _lock Address of the lock contract
     * @param _bondingCurveFactory Address of the bonding curve factory
     */
    constructor(
        address _owner,
        address _core,
        address _wNative,
        address _lock,
        address _bondingCurveFactory
    ) {
        owner = _owner;
        core = _core;
        wNative = _wNative;
        lock = _lock;
        bondingCurveFactory = _bondingCurveFactory;
        mintPartyFactory = msg.sender;
    }

    /**
     * @dev Initializes the mint party with configuration parameters
     * @param account Owner account address
     * @param name Token name
     * @param symbol Token symbol
     * @param tokenURI Token URI for metadata
     * @param fundingAmount Required funding amount per participant
     * @param whiteListCount Maximum number of whitelist participants
     */
    function initialize(
        address account,
        string memory name,
        string memory symbol,
        string memory tokenURI,
        uint256 fundingAmount,
        uint256 whiteListCount
    ) external onlyFactory {
        owner = account;
        config = Config(name, symbol, tokenURI, fundingAmount, whiteListCount);
    }

    /**
     * @notice Allows users to deposit funds to participate in the mint party
     * @param account The address that will be credited with the deposit
     * @dev This function handles both regular deposits and whitelisted deposits through the factory
     */
    function deposit(address account) external payable nonReentrant {
        require(!finished, ERR_MINT_PARTY_FINISHED);
        require(
            balances[account] == 0 && whitelists[account] == 0,
            ERR_MINT_PARTY_ALREADY_DEPOSITED
        );
        require(
            msg.value == config.fundingAmount,
            ERR_MINT_PARTY_INVALID_FUNDING_AMOUNT
        );

        totalBalance += msg.value;
        balances[account] += msg.value;
        emit MintPartyDeposit(account, msg.value);

        if (msg.sender == mintPartyFactory) {
            _addToWhitelist(account, msg.value);
        }
    }

    /// @dev Private function to handle whitelist operations
    /// @param account The address to be whitelisted
    /// @param amount The amount to be whitelisted
    function _addToWhitelist(address account, uint256 amount) private {
        whitelists[account] = amount;
        whitelistAccounts.push(account);
        balances[account] = 0;
        emit MintPartyWhiteListAdded(account, amount);
    }

    /**
     * @dev Allows participants to withdraw their funds
     * The party is closed if total balance becomes zero or if owner withdraws
     */
    function withdraw() external nonReentrant {
        uint256 amount;
        amount += balances[msg.sender];
        amount += whitelists[msg.sender];
        require(amount > 0, ERR_MINT_PARTY_WITHDRAW_AMOUNT_IS_ZERO);
        balances[msg.sender] = 0;
        whitelists[msg.sender] = 0;

        totalBalance -= amount;

        if (totalBalance == 0 || msg.sender == owner) {
            finished = true;
            emit MintPartyClosed();
        }

        // Remove account from whitelist if present
        for (uint256 i = 0; i < whitelistAccounts.length; i++) {
            if (whitelistAccounts[i] == msg.sender) {
                whitelistAccounts[i] = whitelistAccounts[
                    whitelistAccounts.length - 1
                ];
                whitelistAccounts.pop();
                emit MintPartyWhiteListRemoved(msg.sender, amount);
                break;
            }
        }

        TransferHelper.safeTransferNative(msg.sender, amount);
        emit MintPartyWithdraw(msg.sender, amount);
    }

    /**
     * @dev Allows owner to add accounts to the whitelist
     * @param accounts Array of addresses to be whitelisted
     * Requirements:
     * - Only owner can call
     * - Total whitelist count must not exceed configured limit
     * - Accounts must have deposited funds
     */
    function addWhiteList(address[] calldata accounts) external onlyOwner {
        // caching whitelist count and current length
        uint256 _whiteListCount = config.whiteListCount;
        uint256 _currentLength = whitelistAccounts.length;
        uint256 accountsLength = accounts.length;

        // validate total whitelist count
        require(
            _currentLength + accountsLength <= _whiteListCount,
            ERR_MINT_PARTY_INVALID_WHITE_LIST
        );

        unchecked {
            for (uint256 i; i < accountsLength; ++i) {
                address account = accounts[i];
                uint256 balance = balances[account];

                // validate balance and whitelist
                require(balance > 0, ERR_MINT_PARTY_BALANCE_ZERO);
                require(
                    whitelists[account] == 0,
                    ERR_MINT_PARTY_WHITELIST_ALREADY_ADDED
                );

                // update whitelist and balance
                _addToWhitelist(account, balance);
            }
        }

        // check if whitelist is full
        if (_currentLength + accountsLength == _whiteListCount) {
            createBondingCurve();
        }
    }

    /**
     * @dev Internal function to create the token and bonding curve
     * Called automatically when whitelist is full
     */
    function createBondingCurve() private {
        require(
            whitelistAccounts.length == config.whiteListCount,
            ERR_MINT_PARTY_INVALID_WHITE_LIST
        );

        uint256 _totalBalance = calculateSendBalance();

        (uint8 denominator, uint16 numerator) = IBondingCurveFactory(
            bondingCurveFactory
        ).getFeeConfig();

        uint256 deployFee = IBondingCurveFactory(bondingCurveFactory)
            .getDelpyFee();

        uint256 amountIn = _totalBalance - deployFee;

        uint256 fee = BondingCurveLibrary.getFeeAmount(
            amountIn,
            denominator,
            numerator
        );

        amountIn = amountIn - fee;
        (address curve, address token, , , uint256 amountOut) = ICore(core)
            .createCurve{value: amountIn + fee + deployFee}(
            address(this),
            config.name,
            config.symbol,
            config.tokenURI,
            amountIn,
            fee
        );
        lockWhiteListTokens(token, amountOut);

        finished = true;
        emit MintPartyFinished(token, curve);
    }

    /**
     * @dev Calculates and collects the total balance from whitelisted accounts
     * @return Total amount collected from whitelisted accounts
     */
    function calculateSendBalance() internal returns (uint256) {
        uint256 sendBalance;
        for (uint256 i = 0; i < whitelistAccounts.length; i++) {
            uint256 amount = whitelists[whitelistAccounts[i]];
            whitelists[whitelistAccounts[i]] = 0;
            sendBalance += amount;
        }
        totalBalance -= sendBalance;
        return sendBalance;
    }

    /**
     * @dev Distributes tokens equally among whitelisted participants
     * @param token Address of the token to distribute
     * @param tokenBalance Total amount of tokens to distribute
     */
    function lockWhiteListTokens(address token, uint256 tokenBalance) internal {
        // 각 계정당 받을 금액 계산
        uint256 amountPerAccount = tokenBalance / whitelistAccounts.length;

        // 각 계정별로 정확한 금액만 전송하고 lock
        for (uint256 i = 0; i < whitelistAccounts.length; i++) {
            IERC20(token).safeTransfer(lock, amountPerAccount);
            ILock(lock).lock(token, whitelistAccounts[i]);

            emit TokensLocked(whitelistAccounts[i], amountPerAccount);
        }
    }

    // View Functions

    /**
     * @dev Returns the total balance in the mint party
     */
    function getTotalBalance() external view returns (uint256) {
        return totalBalance;
    }

    /**
     * @dev Returns the owner address
     */
    function getOwner() external view returns (address) {
        return owner;
    }

    /**
     * @dev Returns the current configuration
     */
    function getConfig() external view returns (Config memory) {
        return config;
    }

    /**
     * @dev Returns the balance of a specific account
     */
    function getBalance(address account) external view returns (uint256) {
        return balances[account];
    }

    /**
     * @dev Returns whether the mint party is finished
     */
    function getFinished() external view returns (bool) {
        return finished;
    }

    /**
     * @dev Returns array of whitelisted accounts
     */
    function getWhitelistAccounts() external view returns (address[] memory) {
        return whitelistAccounts;
    }

    /**
     * @dev Returns whether an account is whitelisted
     */
    function isWhitelisted(address account) external view returns (bool) {
        return whitelists[account] > 0;
    }
}
