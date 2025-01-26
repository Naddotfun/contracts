// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import "./interfaces/IWNative.sol";
import "./errors/Errors.sol";

contract WNative is ERC20Permit, IWNative {
    constructor() ERC20("WNative", "WNative") ERC20Permit("WNATIVE") {}

    receive() external payable {
        deposit();
    }

    // 정의되지 않은 함수 호출 시 fallback 함수 호출
    fallback() external payable {
        deposit();
    }

    // 사용자가 컨트랙트에 이더를 송금할 때 `balanceOf`를 업데이트하는 함수
    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    // 사용자가 이더를 출금할 때 호출되는 함수
    function withdraw(uint256 amount) public {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _burn(msg.sender, amount);
        TransferHelper.safeTransferNative(msg.sender, amount);
        emit Withdrawal(msg.sender, amount);
    }

    function nonces(address owner) public view virtual override(ERC20Permit) returns (uint256) {
        return super.nonces(owner);
    }

    function permitTypeHash() public pure virtual returns (bytes32) {
        return keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    }
}
