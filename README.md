# Nad.Pump Smart Contract

## Table of Contents

- [System Overview](#system-overview)
- [Key Components](#key-components)
- [Main Functions](#main-functions)
- [Events](#events)
- [Usage Notes](#usage-notes)
- [Development Information](#development-information)

## System Overview

Nad.Pump is a smart contract system for creating and managing bonding curve-based tokens. It enables creators to mint new tokens with associated bonding curves and allows traders to buy and sell these tokens through a centralized endpoint.


![스크린샷 2024-08-09 오후 8 41 04](https://github.com/user-attachments/assets/5fca3aa4-787c-4e23-8e17-3e9cfe21408d)




## Key Components
| Component           | Description                                                                                   |
|---------------------|-----------------------------------------------------------------------------------------------|
| Creator             | Initiates the creation of new coins and curves                                                |
| Trader              | Interacts with the system to buy and sell tokens                                              |
| Endpoint            | Main contract handling all interactions                                                       |
| WNAD                | Wrapped NAD token used for transactions                                                       |
| BondingCurveFactory | Deploys new Bonding Curve contracts                                                           |
| BondingCurve        | Manages token supply and price calculations                                                   |
| ERC20               | Standard token contract deployed for each new coin                                            |
| CPMM DEX            | External decentralized exchange for token trading                                             |
| Vault               | Repository for accumulated trading fees that facilitates revenue sharing for token holders    |


## Main Functions    

### Create Functions

- `createCurve`: Creates a new token and its associated bonding curve

### Buy Functions

| Function                      | Description                                                |
| ----------------------------- | ---------------------------------------------------------- |
| `buy`                         | Purchases tokens with NAD                                  |
| `buyWNad`                     | Purchases tokens with WNAD                                 |
| `buyWNadWithPermit`           | Purchases tokens with WNAD using EIP-2612 permit           |
| `buyAmountOutMin`             | Purchases tokens with a minimum output amount              |
| `buyWNadAmountOutMin`         | Purchases tokens with WNAD with a minimum output amount    |
| `buyWNadAmountOutMinPermit`   | Purchases tokens with WNAD using permit and minimum output |
| `buyExactAmountOut`           | Purchases an exact amount of tokens                        |
| `buyExactAmountOutWNad`       | Purchases an exact amount of tokens with WNAD              |
| `buyExactAmountOutWNadPermit` | Purchases an exact amount of tokens with WNAD using permit |

### Sell Functions

| Function                       | Description                                          |
| ------------------------------ | ---------------------------------------------------- |
| `sell`                         | Sells tokens for NAD                                 |
| `sellPermit`                   | Sells tokens using EIP-2612 permit                   |
| `sellAmountOutMin`             | Sells tokens with a minimum output amount            |
| `sellAmountOutMinWithPermit`   | Sells tokens with a minimum output using permit      |
| `sellExactAmountOut`           | Sells tokens for an exact amount of NAD              |
| `sellExactAmountOutwithPermit` | Sells tokens for an exact amount of NAD using permit |

### Utility Functions

- `getCurveData`: Retrieves data about a specific curve
- `getAmountOut`: Calculates the output amount for a given input
- `getAmountIn`: Calculates the input amount required for a desired output

## Events

### Buy

```solidity
event Buy(
    address indexed sender,
    uint256 amountIn,
    uint256 amountOut,
    address token,
    address curve
);
```

### Sell

```solidity
event Sell(
    address indexed sender,
    uint256 amountIn,
    uint256 amountOut,
    address token,
    address curve
);
```

### CreateCurve

```solidity
event CreateCurve(
    address indexed sender,
    address indexed curve,
    address indexed token,
    string tokenURI,
    string name,
    string symbol
);
```

## Usage Notes

- ⏰ Deadline parameter ensures transaction freshness
- 🔐 Some functions require pre-approval of token spending
- 💱 Supports both NAD and WNAD for transactions
- 📝 EIP-2612 permit functionality available for gasless approvals
- 🛡️ Slippage protection implemented in various functions

## Development Information

This smart contract is part of the Nad.Pump system, designed to create and manage bonding curve-based tokens. For more detailed information about the implementation and usage, please refer to the full contract code and additional documentation.

document comming soon!

---

📌 For questions or support, please open an issue in the GitHub repository.
