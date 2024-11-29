// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;
import {ICore} from "./interfaces/ICore.sol";
import {IWNAD} from "./interfaces/IWNAD.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ILock} from "./interfaces/ILock.sol";
import {IMintParty} from "./interfaces/IMintParty.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {NadsPumpLibrary} from "./utils/NadsPumpLibrary.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import "./errors/Errors.sol";

contract MintParty is IMintParty {
    using TransferHelper for IERC20;

    address private owner;
    address private core;
    address private WNAD;
    address private lock;

    bool private finished;
    Config private config;
    mapping(address => uint256) private balances;
    mapping(address => uint256) private whitelists;
    address[] private whitelistAccounts;

    uint256 totalBalance;

    modifier onlyOwner() {
        require(msg.sender == owner, ERR_MINT_PARTY_ONLY_OWNER);
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == core, ERR_MINT_PARTY_ONLY_FACTORY);
        _;
    }

    constructor(address _owner, address _core, address _wnad, address _lock) {
        owner = _owner;
        core = _core;
        WNAD = _wnad;
        lock = _lock;
    }

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

    function deposit(address account) external payable {
        require(!finished, ERR_MINT_PARTY_FINISHED);
        require(
            balances[account] == 0 && whitelists[account] == 0,
            ERR_MINT_PARTY_ALREADY_DEPOSITED
        );

        require(
            msg.value == config.fundingAmount,
            ERR_MINT_PARTY_INVALID_FUNDING_AMOUNT
        );

        balances[account] += msg.value;

        totalBalance += msg.value;

        emit MintPartyDeposit(account, msg.value);
    }

    //생각해보면 이거는 누구나 맘대로 파티를 종료할 수 있다.
    //msg.sender 만 가능하게
    function withdraw() external {
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
        //whitelistAccounts 에서 삭제
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

        TransferHelper.safeTransferNad(msg.sender, amount);

        emit MintPartyWithdraw(msg.sender, amount);
    }

    function addWhiteList(address[] memory accounts) external onlyOwner {
        require(
            whitelistAccounts.length + accounts.length <= config.whiteListCount,
            ERR_MINT_PARTY_INVALID_PARTICIPANTS
        );
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            uint256 balance = balances[account];
            require(balance > 0, ERR_MINT_PARTY_BALANCE_ZERO);
            require(
                whitelists[account] == 0,
                ERR_MINT_PARTY_WHITELIST_ALREADY_ADDED
            );
            balances[account] = 0;
            whitelists[account] = balance;
            whitelistAccounts.push(account);
            emit MintPartyWhiteListAdded(account, balance);
        }

        if (whitelistAccounts.length == config.whiteListCount) {
            create();
        }
    }

    //TODO : white list 에 있는 사람들로 변경
    //TODO : fee check
    function create() private onlyOwner {
        require(
            whitelistAccounts.length == config.whiteListCount,
            ERR_MINT_PARTY_INVALID_PARTICIPANTS
        );
        uint256 amountIn = calculateSendBalance();
        (uint8 denominator, uint16 numerator) = IBondingCurveFactory(core)
            .getFeeConfig();

        uint256 fee = NadsPumpLibrary.getFeeAmount(
            amountIn,
            denominator,
            numerator
        );

        (address curve, address token, , , uint256 amountOut) = ICore(core)
            .createCurve(
                owner,
                config.name,
                config.symbol,
                config.tokenURI,
                amountIn,
                fee
            );
        distributeTokens(token, amountOut);

        finished = true;
        emit MintPartyFinished(token, curve);
    }

    function calculateSendBalance() private returns (uint256) {
        uint256 sendBalance;
        for (uint256 i = 0; i < whitelistAccounts.length; i++) {
            uint256 amount = whitelists[whitelistAccounts[i]];
            whitelists[whitelistAccounts[i]] = 0;
            sendBalance += amount;
        }
        totalBalance -= sendBalance;
        return sendBalance;
    }

    function distributeTokens(address token, uint tokenBalance) private {
        uint256 whiteListBalance = tokenBalance / whitelistAccounts.length;
        for (uint256 i = 0; i < whitelistAccounts.length; i++) {
            IERC20(token).safeTransferERC20(lock, whiteListBalance);
            ILock(lock).lock(token, whitelistAccounts[i]);
        }
    }

    function getTotalBalance() external view returns (uint256) {
        return totalBalance;
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getBalance(address account) external view returns (uint256) {
        return balances[account];
    }

    function getFinished() external view returns (bool) {
        return finished;
    }

    function getWhitelistAccounts() external view returns (address[] memory) {
        return whitelistAccounts;
    }
}
