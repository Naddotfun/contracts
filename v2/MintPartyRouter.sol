// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IMintPartyFactory} from "../mint_party/interfaces/IMintPartyFactory.sol";
import {IMintParty} from "../mint_party/interfaces/IMintParty.sol";
import {IWNAD} from "../wnad/interfaces/IWNAD.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {TransferHelper} from "../utils/TransferHelper.sol";

contract MintPartyRouter {
    using TransferHelper for IERC20;

    address private mintPartyFactory;
    address private wNad;

    constructor(address _mintPartyFactory, address _wNad) {
        mintPartyFactory = _mintPartyFactory;
        wNad = _wNad;
    }

    receive() external payable {
        assert(msg.sender == wNad); // only accept NAD via fallback from the WNAD contract
    }

    function create(
        address account,
        string memory name,
        string memory symbol,
        string memory tokenURI,
        uint256 fundingAmount,
        uint256 maximumParticipants
    ) external payable {
        require(msg.value >= fundingAmount, "Invalid funding amount");
        IWNAD(wNad).deposit{value: fundingAmount}();
        IERC20(wNad).safeTransferERC20(mintPartyFactory, fundingAmount);
        IMintPartyFactory(mintPartyFactory).create(account, name, symbol, tokenURI, fundingAmount, maximumParticipants);
    }

    function deposit(address account, address mintParty, uint256 amount) external payable {
        require(msg.value >= amount, "Invalid deposit amount");
        IWNAD(wNad).deposit{value: amount}();
        IERC20(wNad).safeTransferERC20(mintParty, amount);
        IMintParty(mintParty).deposit(account);
    }
    //MintParty 는 account 로 withdraw 하면 안됨.
}
