// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface IQuestPoolFactory {
    struct Config {
        uint256 createFee;
        uint256 minimumReward;
        uint256 defaultClaimTimestamp;
    }

    event SetInitialize(uint256 createFee, uint256 minimumReward, uint256 defaultClaimTimestamp);
    event CreateQuestPool(address token, address curve, address creator, address questPool, uint256 reward);

    function initialize(uint256 _createFee, uint256 _minimumReward, uint256 _defaultClaimTimestamp) external;
    function create(address account, address _token) external returns (address);
    function setOwner(address _owner) external;
    function setVault(address _vault) external;

    function getConfig() external view returns (Config memory);
}
