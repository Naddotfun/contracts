// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IToken} from "./interfaces/IToken.sol";
import "./errors/Errors.sol";

contract Token is IToken, ERC20 {
    address private _factory;
    bool private _minted;
    string public tokenURI;
    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    mapping(address => uint256) public nonces;

    constructor(
        string memory name,
        string memory symbol,
        string memory _tokenURI
    ) ERC20(name, symbol) {
        tokenURI = _tokenURI;
        _minted = false;
        _factory = msg.sender;
        uint256 chainId = block.chainid;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
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

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.timestamp, ERR_TOKEN_INVALID_EXPIRED);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        nonces[owner]++,
                        deadline
                    )
                )
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(
            recoveredAddress != address(0) && recoveredAddress == owner,
            ERR_TOKEN_INVALID_SIGNATURE
        );
        _approve(owner, spender, value);
    }

    function nonce(address owner) external view returns (uint256) {
        return nonces[owner];
    }
}
