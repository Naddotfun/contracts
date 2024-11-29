// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title FeeVault
 * @dev A tokenized vault contract implementing the ERC4626 standard.
 * Users can deposit ERC20 tokens and receive shares in return.
 * Inherits from OpenZeppelin's ERC4626 implementation.
 */
contract FeeVault is ERC4626 {
    /**
     * @dev Constructor to initialize the vault
     * @param asset The ERC20 token that can be deposited into this vault
     * The constructor also initializes the ERC20 token with name "NAD" and symbol "NAD"
     */
    constructor(IERC20 asset) ERC4626(asset) ERC20("NAD", "NAD") {}

    /**
     * @dev Returns the total amount of underlying assets held by the vault
     * @return uint256 The total amount of assets in the vault
     * This function is overridden from the ERC4626 implementation
     * Currently returns the direct balance of the underlying asset held by this contract
     */
    function totalAssets() public view virtual override returns (uint256) {
        // Here, the logic to calculate the total assets should be implemented
        return IERC20(asset()).balanceOf(address(this));
    }
}
