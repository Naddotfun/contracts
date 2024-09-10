// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {QuestPool} from "./QuestPool.sol";
import {IQuestPool} from "./interfaces/IQuestPool.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IQuestPoolFactory} from "./interfaces/IQuestPoolFactory.sol";
import "./errors/Errors.sol";

contract QuestPoolFactory is IQuestPoolFactory {
    using TransferHelper for IERC20;
    //token => questPool

    mapping(address => address) questPools;
    address private owner;
    address immutable wNad;
    Config config;
    address vault;
    address bondingCurveFactory;

    modifier onlyOwner() {
        require(msg.sender == owner, ERR_ONLY_OWNER);
        _;
    }

    constructor(address _owner, address _vault, address _wNad, address _bondingCurveFactory) {
        owner = _owner;
        vault = _vault;
        wNad = _wNad;
        bondingCurveFactory = _bondingCurveFactory;
    }

    function initialize(uint256 _createFee, uint256 _minimumReward, uint256 _defaultClaimTimestamp)
        external
        onlyOwner
    {
        config = Config(_createFee, _minimumReward, _defaultClaimTimestamp);
        emit SetInitialize(_createFee, _minimumReward, _defaultClaimTimestamp);
    }

    function create(address creator, address _token) external returns (address) {
        address curve = IBondingCurveFactory(bondingCurveFactory).getCurve(_token);

        require(curve != address(0), ERR_INVALID_TOKEN);

        uint256 fee = IERC20(wNad).balanceOf(address(this));
        require(fee >= config.createFee, ERR_INVALID_CREATE_FEE);
        IERC20(wNad).safeTransferERC20(vault, fee);
        uint256 reward = IERC20(_token).balanceOf(address(this));
        require(reward >= config.minimumReward, ERR_INVALID_MINIMUM_REWARD);
        QuestPool questPool = new QuestPool(curve, _token);
        IERC20(_token).safeTransferERC20(address(questPool), reward);
        emit CreateQuestPool(_token, curve, creator, address(questPool), reward);
        return address(questPool);
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
    }

    function setVault(address _vault) external onlyOwner {
        vault = _vault;
    }

    function getConfig() external view returns (Config memory) {
        return config;
    }
}
