// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface IMintPartyFactory {
    event MintPartyCreated(
        address indexed party,
        address account,
        uint256 fundingAmount,
        uint8 whiteListCount,
        string name,
        string symbol,
        string tokenURI
    );

    function create(
        address account,
        string memory name,
        string memory symbol,
        string memory tokenURI,
        uint256 fundingAmount,
        uint8 whiteListCount
    ) external payable returns (address);

    function getParty(address account) external view returns (address);
}
