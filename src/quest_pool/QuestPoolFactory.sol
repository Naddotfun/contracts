// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {QuestPool} from "./QuestPool.sol";
import {IQuestPool} from "./interfaces/IQuestPool.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {TransferHelper} from "../utils/TransferHelper.sol";
import {IBondingCurveFactory} from "../curve/interfaces/IBondingCurveFactory.sol";
import {IQuestPoolFactory} from "./interfaces/IQuestPoolFactory.sol";
import {IWNAD} from "../wnad/interfaces/IWNAD.sol";
import "./errors/Error.sol";

contract QuestPoolFactory is IQuestPoolFactory {
    using TransferHelper for IERC20;
    //token => questPool

    address private owner;
    address private wNad;
    Config config;
    address vault;
    address bondingCurveFactory;

    //token => address => questPool
    mapping(address => mapping(address => address)) questPools;

    modifier onlyOwner() {
        require(msg.sender == owner, ERR_ONLY_OWNER);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function initialize(
        address _vault,
        address _bondingCurveFactory,
        address _wNad,
        uint256 _createFee,
        uint256 _minimumReward,
        uint256 _defaultClaimTimestamp
    ) external onlyOwner {
        config = Config(_createFee, _minimumReward, _defaultClaimTimestamp);
        vault = _vault;
        bondingCurveFactory = _bondingCurveFactory;
        wNad = _wNad;
        emit SetInitialize(_vault, _bondingCurveFactory, _wNad, _createFee, _minimumReward, _defaultClaimTimestamp);
    }

    function create(address creator, address _token) external payable returns (address) {
        address curve = IBondingCurveFactory(bondingCurveFactory).getCurve(_token);

        require(curve != address(0), ERR_INVALID_TOKEN);

        // uint256 fee = IERC20(wNad).balanceOf(address(this));
        require(msg.value >= config.createFee, ERR_INVALID_CREATE_FEE);
        //fee send
        {
            IWNAD(wNad).deposit{value: msg.value}();
            IERC20(wNad).safeTransferERC20(vault, msg.value);
        }

        uint256 reward = IERC20(_token).allowance(msg.sender, address(this));
        require(reward >= config.minimumReward, ERR_INVALID_MINIMUM_REWARD);
        IERC20(_token).safeTransferFrom(msg.sender, address(this), reward);
        QuestPool questPool = new QuestPool(curve, _token, config.defaultClaimTimestamp);

        //QuestPool initialize
        {
            IERC20(_token).transfer(address(questPool), reward);
            questPool.initialize();
        }

        questPools[_token][creator] = address(questPool);
        emit CreateQuestPool(_token, curve, creator, address(questPool), reward);
        return address(questPool);
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
    }

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getQuestPool(address _token, address _creator) external view returns (address) {
        return questPools[_token][_creator];
    }

    function getVault() external view returns (address) {
        return vault;
    }
}
