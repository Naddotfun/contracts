// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

contract TestConstants {
    uint256 constant DEPLOY_FEE = 2 * 10 ** 16;
    uint256 constant LISTING_FEE = 1 ether;
    uint256 constant VIRTUAL_NAD = 30 * 10 ** 18;
    uint256 constant VIRTUAL_TOKEN = 1_073_000_191 * 10 ** 18;
    uint256 constant K = VIRTUAL_NAD * VIRTUAL_TOKEN;
    uint256 constant TARGET_TOKEN = 206_900_000 * 10 ** 18;
    uint256 constant TOKEN_TOTAL_SUPPLY = 10 ** 27;

    uint8 constant FEE_DENOMINATOR = 10;
    uint16 constant FEE_NUMERATOR = 1000;

    address constant OWNER = address(0xa);
    address constant CREATOR = address(0xb);
    uint256 constant TRADER_PRIVATE_KEY = 0xA11CE;
}
