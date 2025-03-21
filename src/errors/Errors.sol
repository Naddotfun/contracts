// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;
// BondingCurveLibrary

string constant ERR_BONDING_CURVE_LIBRARY_INVALID_AMOUNT_OUT =
    "BondingCurveLibrary : ERR_BONDING_CURVE_LIBRARY_INVALID_AMOUNT_OUT";
string constant ERR_BONDING_CURVE_LIBRARY_INVALID_AMOUNT_IN =
    "BondingCurveLibrary : ERR_BONDING_CURVE_LIBRARY_INVALID_AMOUNT_IN";
string constant ERR_BONDING_CURVE_LIBRARY_INSUFFICIENT_LIQUIDITY =
    "BondingCurveLibrary : ERR_BONDING_CURVE_LIBRARY_INSUFFICIENT_LIQUIDITY";
string constant ERR_BONDING_CURVE_LIBRARY_INVALID_INPUTS =
    "BondingCurveLibrary : ERR_BONDING_CURVE_LIBRARY_INVALID_INPUTS";
//Transfer Helper
string constant ERR_TRANSFER_NATIVE_FAILED = "ERR_TRANSFER_NATIVE_FAILED";

//BondingCurve
string constant ERR_BONDING_CURVE_ONLY_OWNER = "BondingCurve : ERR_BONDING_CURVE_ONLY_OWNER";
string constant ERR_BONDING_CURVE_ONLY_FACTORY = "BondingCurve : ERR_BONDING_CURVE_ONLY_FACTORY";
string constant ERR_BONDING_CURVE_FINISHED = "BondingCurve : ERR_BONDING_CURVE_FINISHED";
string constant ERR_BONDING_CURVE_INVALID_AMOUNT_OUT = "BondingCurve : ERR_BONDING_CURVE_INVALID_AMOUNT_OUT";
string constant ERR_BONDING_CURVE_INVALID_AMOUNT_IN = "BondingCurve : ERR_BONDING_CURVE_INVALID_AMOUNT_IN";
string constant ERR_BONDING_CURVE_OVERFLOW_TARGET = "BondingCurve : ERR_BONDING_CURVE_OVERFLOW_TARGET";
string constant ERR_BONDING_CURVE_INVALID_TO = "BondingCurve : ERR_BONDING_CURVE_INVALID_TO";
string constant ERR_BONDING_CURVE_INVALID_K = "BondingCurve : ERR_BONDING_CURVE_INVALID_K";
string constant ERR_BONDING_CURVE_INSUFFICIENT_RESERVE = "BondingCurve : ERR_BONDING_CURVE_INSUFFICIENT_RESERVE";
string constant ERR_BONDING_CURVE_ONLY_LOCK = "BondingCurve : ERR_LISTING_ONLY_LOCK";
string constant ERR_BONDING_CURVE_LOCKED = "BondingCurve : ERR_BONDING_CURVE_LOCKED";
string constant ERR_BONDING_CURVE_ALREADY_LISTED = "BondingCurve : ERR_BONDING_CURVE_ALREADY_LISTED";
string constant ERR_BONDING_CURVE_MUST_LISTING = "BondingCurve : ERR_BONDING_CURVE_MUST_LISTING";
//BondingCurveFactory
string constant ERR_BONDING_CURVE_FACTORY_ONLY_OWNER = "BondingCurveFactory : ERR_BONDING_CURVE_FACTORY_ONLY_OWNER";
string constant ERR_BONDING_CURVE_FACTORY_ONLY_CORE = "BondingCurveFactory : ERR_BONDING_CURVE_FACTORY_ONLY_CORE";

//CORE
string constant ERR_CORE_EXPIRED = "Core : ERR_CORE_EXPIRED";
string constant ERR_CORE_INVALID_FEE = "Core : ERR_CORE_INVALID_FEE";
string constant ERR_CORE_INVALID_SEND_NATIVE = "Core : ERR_CORE_INVALID_SEND_NATIVE";
string constant ERR_CORE_INVALID_AMOUNT_IN = "Core : ERR_CORE_INVALID_AMOUNT_IN";
string constant ERR_CORE_INVALID_AMOUNT_OUT = "Core : ERR_CORE_INVALID_AMOUNT_OUT";
string constant ERR_CORE_INVALID_ALLOWANCE = "Core : ERR_CORE_INVALID_ALLOWANCE";
string constant ERR_CORE_INVALID_AMOUNT_IN_MAX = "Core : ERR_CORE_INVALID_AMOUNT_IN_MAX";
string constant ERR_CORE_ALREADY_INITIALIZED = "Core : ERR_CORE_ALREADY_INITIALIZED";

//LOCK
string constant ERR_LOCK_ONLY_OWNER = "Lock : ERR_LOCK_ONLY_OWNER";
string constant ERR_LOCK_INVALID_AMOUNT_IN = "Lock : ERR_LOCK_INVALID_AMOUNT_IN";
string constant ERR_TOKEN_NOT_LOCKED = "Lock : ERR_TOKEN_NOT_LOCKED";
string constant ERR_INVALID_ACCOUNT = "Lock : ERR_INVALID_ACCOUNT";
string constant ERR_INVALID_TOKEN_ADDRESS = "Lock : ERR_INVALID_TOKEN_ADDRESS";
// MINT PARTY
string constant ERR_MINT_PARTY_ONLY_OWNER = "MintParty : ERR_MINT_PARTY_ONLY_OWNER";
string constant ERR_MINT_PARTY_ONLY_FACTORY = "MintParty : ERR_MINT_PARTY_ONLY_FACTORY";
string constant ERR_MINT_PARTY_FINISHED = "MintParty : ERR_MINT_PARTY_FINISHED";
string constant ERR_MINT_PARTY_INVALID_FUNDING_AMOUNT = "MintParty : ERR_MINT_PARTY_INVALID_FUNDING_AMOUNT";
string constant ERR_MINT_PARTY_INVALID_WHITE_LIST = "MintParty : ERR_MINT_PARTY_INVALID_WHITE_LIST";
string constant ERR_MINT_PARTY_INVALID_WHITELIST = "MintParty : ERR_MINT_PARTY_INVALID_WHITELIST";
string constant ERR_MINT_PARTY_WITHDRAW_AMOUNT_IS_ZERO = "MintParty : ERR_MINT_PARTY_WITHDRAW_AMOUNT_IS_ZERO";
string constant ERR_MINT_PARTY_ALREADY_DEPOSITED = "MintParty : ERR_MINT_PARTY_ALREADY_DEPOSITED";
string constant ERR_MINT_PARTY_BALANCE_ZERO = "MintParty : ERR_MINT_PARTY_BALANCE_ZERO";
string constant ERR_MINT_PARTY_WHITELIST_ALREADY_ADDED = "MintParty : ERR_MINT_PARTY_WHITELIST_ALREADY_ADDED";

//MINT_PARTY Factory
string constant ERR_MINT_PARTY_FACTORY_NOT_FINISHED = "MintPartyFactory : ERR_MINT_PARTY_FACTORY_NOT_FINISHED";
string constant ERR_MINT_PARTY_FACTORY_INVALID_FUNDING_AMOUNT =
    "MintPartyFactory : ERR_MINT_PARTY_FACTORY_INVALID_FUNDING_AMOUNT";
string constant ERR_MINT_PARTY_FACTORY_INVALID_MAXIMUM_WHITELIST =
    "MintPartyFactory : ERR_MINT_PARTY_FACTORY_INVALID_MAXIMUM_WHITELIST";
string constant ERR_MINT_PARTY_FACTORY_ONLY_OWNER = "MintPartyFactory : ERR_MINT_PARTY_FACTORY_ONLY_OWNER";

//Token
string constant ERR_TOKEN_ONLY_FACTORY = "Token : ERR_TOKEN_ONLY_FACTORY";
string constant ERR_TOKEN_ONLY_ONCE_MINT = "Token : ERR_TOKEN_ONLY_ONCE_MINT";
string constant ERR_TOKEN_INVALID_EXPIRED = "Token : ERR_TOKEN_INVALID_EXPIRED";
string constant ERR_TOKEN_INVALID_SIGNATURE = "Token : ERR_TOKEN_INVALID_SIGNATURE";

//FeeVault
string constant ERR_FEE_VAULT_INVALID_WNATIVE_ADDRESS = "FeeVault : ERR_FEE_VAULT_INVALID_WNATIVE_ADDRESS";
string constant ERR_FEE_VAULT_NO_OWNERS = "FeeVault : ERR_FEE_VAULT_NO_OWNERS";
string constant ERR_FEE_VAULT_INVALID_SIGNATURES_REQUIRED = "FeeVault : ERR_FEE_VAULT_INVALID_SIGNATURES_REQUIRED";
string constant ERR_FEE_VAULT_INVALID_OWNER = "FeeVault : ERR_FEE_VAULT_INVALID_OWNER";
string constant ERR_FEE_VAULT_DUPLICATE_OWNER = "FeeVault : ERR_FEE_VAULT_DUPLICATE_OWNER";
string constant ERR_FEE_VAULT_NOT_OWNER = "FeeVault : ERR_FEE_VAULT_NOT_OWNER";
string constant ERR_FEE_VAULT_INVALID_RECEIVER = "FeeVault : ERR_FEE_VAULT_INVALID_RECEIVER";
string constant ERR_FEE_VAULT_INVALID_AMOUNT = "FeeVault : ERR_FEE_VAULT_INVALID_AMOUNT";
string constant ERR_FEE_VAULT_INSUFFICIENT_BALANCE = "FeeVault : ERR_FEE_VAULT_INSUFFICIENT_BALANCE";
string constant ERR_FEE_VAULT_INVALID_PROPOSAL = "FeeVault : ERR_FEE_VAULT_INVALID_PROPOSAL";
string constant ERR_FEE_VAULT_ALREADY_EXECUTED = "FeeVault : ERR_FEE_VAULT_ALREADY_EXECUTED";
string constant ERR_FEE_VAULT_ALREADY_SIGNED = "FeeVault : ERR_FEE_VAULT_ALREADY_SIGNED";
string constant ERR_FEE_VAULT_INSUFFICIENT_SIGNATURES = "FeeVault : ERR_FEE_VAULT_INSUFFICIENT_SIGNATURES";
string constant ERR_FEE_VAULT_TRANSFER_FAILED = "FeeVault : ERR_FEE_VAULT_TRANSFER_FAILED";

//DexRouter

string constant ERR_DEX_ROUTER_EXPIRED = "DexRouter : ERR_DEX_ROUTER_EXPIRED";
string constant ERR_DEX_ROUTER_INVALID_SEND_NATIVE = "DexRouter : ERR_DEX_ROUTER_INVALID_SEND_NATIVE";
string constant ERR_DEX_ROUTER_INVALID_AMOUNT_IN = "DexRouter : ERR_DEX_ROUTER_INVALID_AMOUNT_IN";
string constant ERR_DEX_ROUTER_INVALID_FEE = "DexRouter : ERR_DEX_ROUTER_INVALID_FEE";
string constant ERR_DEX_ROUTER_INVALID_ALLOWANCE = "DexRouter : ERR_DEX_ROUTER_INVALID_ALLOWANCE";
string constant ERR_DEX_ROUTER_INVALID_AMOUNT_OUT_MIN = "DexRouter : ERR_DEX_ROUTER_INVALID_AMOUNT_OUT_MIN";
string constant ERR_DEX_ROUTER_INVALID_AMOUNT_IN_MAX = "DexRouter : ERR_DEX_ROUTER_INVALID_AMOUNT_IN_MAX";
