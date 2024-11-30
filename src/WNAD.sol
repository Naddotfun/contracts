// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import "./interfaces/IWNAD.sol";
import "./errors/Errors.sol";

contract WNAD is IERC20, IWNAD {
    string public name = "Wrapped NAD Token";
    string public symbol = "WNAD";
    uint8 public decimals = 18;

    event Deposit(address indexed to, uint256 amount);
    event Withdrawal(address indexed from, uint256 amount);

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
    // 이더를 직접 받을 때 호출되는 receive 함수
    mapping(address => uint256) public nonces;

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    constructor() {
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

    receive() external payable {
        deposit();
    }

    // 정의되지 않은 함수 호출 시 fallback 함수 호출
    fallback() external payable {
        deposit();
    }

    // 사용자가 컨트랙트에 이더를 송금할 때 `balanceOf`를 업데이트하는 함수
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    // 사용자가 이더를 출금할 때 호출되는 함수
    function withdraw(uint256 amount) public {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        TransferHelper.safeTransferNad(msg.sender, amount);
        emit Withdrawal(msg.sender, amount);
    }

    // 컨트랙트의 전체 이더 잔액을 반환하는 함수
    function totalSupply() public view returns (uint256) {
        return address(this).balance;
    }

    // 사용자가 다른 주소에게 이더 전송을 허락하는 함수
    function approve(address spender, uint256 amount) public returns (bool) {
        bool ok = _approve(msg.sender, spender, amount);
        return ok;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private returns (bool) {
        allowance[owner][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    // 사용자가 자신의 주소에서 다른 주소로 이더를 전송하는 함수

    function transfer(address to, uint256 amount) public returns (bool) {
        return transferFrom(msg.sender, to, amount);
    }

    // 사용자가 다른 주소로 이더를 전송하는 함수
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");

        if (
            from != msg.sender &&
            allowance[from][msg.sender] != type(uint256).max
        ) {
            require(
                allowance[from][msg.sender] >= amount,
                "Allowance exceeded"
            );
            allowance[from][msg.sender] -= amount;
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);

        return true;
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
}
