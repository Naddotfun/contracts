// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IToken} from "./interfaces/IToken.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import "./errors/Errors.sol";

/**
 * @title Token Contract
 * @notice Implements ERC20 token with permit functionality
 */
contract Token is IToken, ERC20Permit {
    address private _factory;
    bool private _minted;
    string public tokenURI;
    IBondingCurve curve;
    address private core;

    modifier beforeListed(address from, address to) {
        if (!curve.getIsListing()) {
            // Static array access is more gas efficient
            bool isFromAllowed = from == address(curve) || from == core;

            bool isToAllowed = to == address(curve) || to == core;

            require(isFromAllowed || isToAllowed, "Token: transfer not allowed before listing");
        }
        _;
    }

    constructor(string memory name, string memory symbol, string memory _tokenURI, address _core)
        ERC20(name, symbol)
        ERC20Permit(name)
    {
        tokenURI = _tokenURI;
        _minted = false;
        _factory = msg.sender;
        core = _core;
    }

    function mint(address _curve) external {
        require(msg.sender == _factory, ERR_TOKEN_ONLY_FACTORY);
        require(!_minted, ERR_TOKEN_ONLY_ONCE_MINT);
        require(totalSupply() == 0, ERR_TOKEN_ONLY_ONCE_MINT);
        _mint(_curve, 10 ** 27);
        _minted = true;
        curve = IBondingCurve(_curve);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function nonces(address owner) public view virtual override(ERC20Permit, IERC20Permit) returns (uint256) {
        return super.nonces(owner);
    }

    function permitTypeHash() public pure virtual returns (bytes32) {
        return keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    }

    function transfer(address to, uint256 value)
        public
        virtual
        override(ERC20, IERC20)
        beforeListed(msg.sender, to)
        returns (bool)
    {
        // _transfer는 void 함수이므로 별도로 실행
        _transfer(msg.sender, to, value);

        // ERC20 표준에 따라 true 반환
        return true;
    }
}
