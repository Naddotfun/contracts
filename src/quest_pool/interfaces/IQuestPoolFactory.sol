// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface IQuestPoolFactory {
    struct Config {
        uint256 createFee;
        uint256 minimumReward;
        uint256 defaultClaimTimestamp;
    }

    event SetInitialize(
        address vault,
        address bondingCurveFactory,
        address wNad,
        uint256 createFee,
        uint256 minimumReward,
        uint256 defaultClaimTimestamp
    );
    event CreateQuestPool(address token, address curve, address creator, address questPool, uint256 reward);

    function initialize(
        address _vault,
        address _bondingCurveFactory,
        address _wNad,
        uint256 _createFee,
        uint256 _minimumReward,
        uint256 _defaultClaimTimestamp
    ) external;
    function create(address account, address _token) external payable returns (address);
    function setOwner(address _owner) external;

    function getConfig() external view returns (Config memory);
    function getQuestPool(address _token, address _creator) external view returns (address);
    function getVault() external view returns (address);
}
