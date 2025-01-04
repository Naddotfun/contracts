# Nad.Pump Smart Contract

## Table of Contents

- [System Overview](#system-overview)
- [Contract Architecture](#contract-architecture)
- [Key Components](#key-components)
- [Main Functions](#main-functions)
- [Events](#events)
- [Usage Notes](#usage-notes)
- [Development Information](#development-information)

## System Overview

Nad.Pump is a smart contract system for creating and managing bonding curve-based tokens. It enables creators to mint new tokens with associated bonding curves and allows traders to buy and sell these tokens through a centralized endpoint. The system uses a combination of bonding curves and automated market makers to provide liquidity and price discovery for newly created tokens.

## Contract Architecture

### Bonding Curve

<img width="898" alt="스크린샷 2024-12-02 오후 8 27 59" src="https://github.com/user-attachments/assets/d32f33fa-293d-42da-9fc1-0294c5a7ea28">

### Mint Party

<img width="760" alt="스크린샷 2024-12-02 오후 8 27 41" src="https://github.com/user-attachments/assets/eb52e84c-cc51-4d8b-8478-1a0979d61271">

### Core Contracts

1. **Core.sol**

   - Central contract that coordinates all system operations
   - Handles token creation, buying, and selling operations
   - Manages interactions with WNative and fee collection
   - Implements various safety checks and slippage protection

2. **BondingCurve.sol**

   - Implements the bonding curve logic
   - Calculates token prices based on supply
   - Manages token reserves and liquidity

3. **BondingCurveFactory.sol**

   - Deploys new bonding curve contracts
   - Maintains registry of created curves
   - Ensures standardization of curve parameters

4. **WNative.sol**
   - Wrapped Native token implementation
   - Provides ERC20 interface for Native
   - Enables advanced trading features

### Supporting Contracts

5. **FeeVault.sol**

   - Collects and manages trading fees
   - Implements ERC4626 for fee distribution
   - Provides revenue sharing mechanism

6. **Token.sol**

   - Standard ERC20 implementation for created tokens
   - Includes additional features for bonding curve integration

7. **MintParty.sol & MintPartyFactory.sol**
   - Manages collective minting operations
   - Coordinates group participation in token creation

### Utility Contracts

- **Utils/**

  - Contains helper functions and libraries
  - Implements common mathematical operations
  - Provides security utilities

- **Interfaces/**

  - Defines contract interfaces
  - Ensures proper contract interaction
  - Facilitates upgradability

- **Errors/**
  - Centralizes error definitions
  - Provides clear error messages
  - Improves debugging experience

## Key Components

| Component           | Description                                                                            |
| ------------------- | -------------------------------------------------------------------------------------- |
| Creator             | Initiates the creation of new coins and curves                                         |
| Trader              | Interacts with the system to buy and sell tokens                                       |
| Core                | Main contract handling Bonding Curve creation, buying, and selling;                    |
| WNative             | Wrapped NAD token used for transactions                                                |
| BondingCurveFactory | Deploys new Bonding Curve contracts                                                    |
| BondingCurve        | Manages token supply and price calculations                                            |
| ERC20               | Standard token contract deployed for each new coin                                     |
| CPMM DEX            | External decentralized exchange for token trading                                      |
| Vault               | Repository for accumulated trading fees; facilitates revenue sharing for token holders |

## Main Functions

### Create Functions

- `createCurve`: Creates a new token and its associated bonding curve

### Buy Functions

| Function      | Description                                           |
| ------------- | ----------------------------------------------------- |
| `buy`         | Market Buy tokens at the current bonding curve price. |
| `protectBuy`  | Buys tokens with slippage protection                  |
| `exactOutBuy` | Buys an exact amount of tokens from a bonding curve   |

### Sell Functions

| Function                 | Description                                                                 |
| ------------------------ | --------------------------------------------------------------------------- |
| `sell`                   | Market sells tokens at the current bonding curve price                      |
| `sellPermit`             | Market sells tokens at the current bonding curve price with permit          |
| `protectSell`            | Sells tokens with slippage protection                                       |
| `protectSellWithPermit`  | Sells tokens with slippage protection with permit                           |
| `exactOutSell`           | Sells tokens for an exact amount of Native on the bonding curve             |
| `exactOutSellWithPermit` | Sells tokens for an exact amount of Native on the bonding curve with permit |

### Utility Functions

- `getCurveData`: Retrieves data about a specific curve
- `getAmountOut`: Calculates the output amount for a given input
- `getAmountIn`: Calculates the input amount required for a desired output

## Events

### Buy

```solidity
event Buy(
    address indexed sender,
    address indexed token,
    uint256 amountIn,
    uint256 amountOut
);
```

### Sell

```solidity
event Sell(
    address indexed sender,
    address indexed token,
    uint256 amountIn,
    uint256 amountOut
);
```

### CreateCurve

```solidity
event Create(
    address indexed owner,
    address indexed curve,
    address indexed token,
    string tokenURI,
    string name,
    string symbol,
    uint256 virtualNative,
    uint256 virtualToken
);
```

## Usage Notes

- ⏰ Deadline parameter ensures transaction freshness
- 🔐 Some functions require pre-approval of token spending
- 💱 Supports both NAD and WNative for transactions
- 📝 EIP-2612 permit functionality available for gasless approvals
- 🛡️ Slippage protection implemented in various functions

## Development Information

This smart contract is part of the Nad.Pump system, designed to create and manage bonding curve-based tokens. For more detailed information about the implementation and usage, please refer to the full contract code and additional documentation.

## document comming soon!

📌 For questions or support, please open an issue in the GitHub repository.
