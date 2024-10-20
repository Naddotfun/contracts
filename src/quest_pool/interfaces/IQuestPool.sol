// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface IQuestPool {
    // Events
    event QuestAdded(address indexed account, uint256 balance);
    event QuestClaimed(address indexed account, uint256 reward, uint256 balance);

    function initialize() external;
    // Functions
    function deposit(address account) external;
    function withdraw(address account) external;

    // View functions
    function getEndQuest() external view returns (bool);
    function getQuestBalances(address account) external view returns (uint256);
    function getTotalDepositAmount() external view returns (uint256);
    function getRewardAmount() external view returns (uint256);

    // You might want to add these if they need to be accessible externally
    function getToken() external view returns (address);
    function getCurve() external view returns (address);
    function getClaimableTimeStamp() external view returns (uint256);
}
