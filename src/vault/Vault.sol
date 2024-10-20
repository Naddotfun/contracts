// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Vault is ERC4626 {
    address private revenueCore;
    uint256 reserves;
    address owner;

    constructor(IERC20 asset) ERC4626(asset) ERC20("Nad Token", "MVT") {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function totalAssets() public view virtual override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    // function sendFeeRevenue() external {
    //     uint256 fee = totalAssets() - reserves;

    //     require(fee > 0, "No fee to send");
    //     address prizePool = IRevenueCore(revenueCore).getPrizePool();

    //     uint256 revenueFee = fee / 10;

    //     IERC20(asset()).transfer(prizePool, revenueFee);
    //     reserves = totalAssets();
    // }

    // function setReserves() external {
    //     reserves = totalAssets();
    // }
}
