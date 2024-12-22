// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IToken} from "./interfaces/IToken.sol";
import "./errors/Errors.sol";

/**
 * @title Token Contract
 * @notice Implements ERC20 token with permit functionality
 */
contract Token is IToken, ERC20Permit {
    address private _factory;
    bool private _minted;
    string public tokenURI;

    constructor(
        string memory name,
        string memory symbol,
        string memory _tokenURI
    ) ERC20(name, symbol) ERC20Permit(name) {
        tokenURI = _tokenURI;
        _minted = false;
        _factory = msg.sender;
    }

    function mint(address to) external {
        require(msg.sender == _factory, ERR_TOKEN_ONLY_FACTORY);
        require(!_minted, ERR_TOKEN_ONLY_ONCE_MINT);
        require(totalSupply() == 0, ERR_TOKEN_ONLY_ONCE_MINT);
        _mint(to, 10 ** 27);
        _minted = true;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function nonces(
        address owner
    )
        public
        view
        virtual
        override(ERC20Permit, IERC20Permit)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    function permitTypeHash() public pure virtual returns (bytes32) {
        return
            keccak256(
                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
            );
    }
}
