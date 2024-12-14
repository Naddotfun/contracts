// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface IMintParty {
    //Only Test
    // event MintPartyFinished(
    //     address indexed token,
    //     address indexed curve,
    //     uint256 amountOut
    // );
    event MintPartyFinished(address indexed token, address indexed curve);
    event MintPartyClosed();
    event MintPartyDeposit(address account, uint256 amount);
    event MintPartyWithdraw(address account, uint256 amount);
    event MintPartyWhiteListAdded(address account, uint256 amount);
    event MintPartyWhiteListRemoved(address account, uint256 amount);

    struct Config {
        string name;
        string symbol;
        string tokenURI;
        uint256 fundingAmount;
        uint256 whiteListCount;
    }

    function initialize(
        address account,
        string memory name,
        string memory symbol,
        string memory tokenURI,
        uint256 fundingAmount,
        uint256 whiteListCount
    ) external;

    function deposit(address account) external payable;

    function withdraw() external;

    function addWhiteList(address[] memory accounts) external;

    // 읽기 전용 함수들 (view 함수들)
    function getTotalBalance() external view returns (uint256);

    function getOwner() external view returns (address);

    function getConfig() external view returns (Config memory);

    function getBalance(address account) external view returns (uint256);

    function getFinished() external view returns (bool);
}
