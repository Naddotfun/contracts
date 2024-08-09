// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FeeVault is ERC4626 {
    constructor(IERC20 asset) ERC4626(asset) ERC20("Nad Token", "MVT") {}

    function totalAssets() public view virtual override returns (uint256) {
        // 여기에 총 자산을 계산하는 로직을 구현
        return IERC20(asset()).balanceOf(address(this));
    }
}
