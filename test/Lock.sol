// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Lock} from "src/Lock.sol";
import {Token} from "src/Token.sol";
import {TestConstants} from "./Constant.sol";
import {BondingCurveFactory} from "src/BondingCurveFactory.sol";
import {Endpoint} from "src/Endpoint.sol";
import {FeeVault} from "src/FeeVault.sol";
import {WNAD} from "src/WNAD.sol";
import {BondingCurve} from "src/BondingCurve.sol";
import {UniswapV2Factory} from "src/uniswap/UniswapV2Factory.sol";
import {ILock} from "src/interfaces/ILock.sol";

contract LockTest is Test, TestConstants {
    BondingCurve curve;
    Token token;
    BondingCurveFactory factory;
    WNAD wNad;
    Endpoint endpoint;
    FeeVault vault;
    UniswapV2Factory uniFactory;
    Lock lock;
    address trader;

    function setUp() public {
        trader = vm.addr(TRADER_PRIVATE_KEY);

        vm.startPrank(OWNER);

        wNad = new WNAD();
        factory = new BondingCurveFactory(OWNER, address(wNad));
        uniFactory = new UniswapV2Factory(OWNER);
        factory.initialize(
            DEPLOY_FEE,
            LISTING_FEE,
            TOKEN_TOTAL_SUPPLY,
            VIRTUAL_NAD,
            VIRTUAL_TOKEN,
            TARGET_TOKEN,
            FEE_NUMERATOR,
            FEE_DENOMINATOR,
            address(uniFactory)
        );
        lock = new Lock(address(factory));
        vault = new FeeVault(wNad);
        endpoint = new Endpoint(address(factory), address(wNad), address(vault), address(lock));

        factory.setEndpoint(address(endpoint));

        vm.stopPrank();

        vm.deal(CREATOR, DEPLOY_FEE);

        vm.startPrank(CREATOR);

        (address curveAddress, address tokenAddress, uint256 _virtualNad, uint256 _virtualToken, uint256 initAmountOut)
        = endpoint.createCurve{value: DEPLOY_FEE}("test", "test", "testurl", 0, 0, DEPLOY_FEE);
        curve = BondingCurve(curveAddress);
        token = Token(tokenAddress);

        vm.stopPrank();
    }

    function testTimeLock() public {
        vm.startPrank(trader);
        vm.deal(trader, 1.01 ether);
        uint256 deadline = block.timestamp + 1;
        endpoint.buy{value: 1.01 ether}(1 ether, 0.01 ether, address(token), trader, deadline);

        uint256 tokenBalance = token.balanceOf(trader);
        token.transfer(address(lock), tokenBalance);
        ILock(lock).lock(address(token), trader, tokenBalance, block.timestamp + 100, false);

        vm.stopPrank();

        assertEq(token.balanceOf(address(lock)), tokenBalance);
        assertEq(ILock(lock).getLockedInfo(address(token), trader).length, 1);

        // 시간이 지나기 전 언락 시도
        vm.expectRevert();
        ILock(lock).unlock(address(token), trader);

        // 시간이 지난 후 언락
        vm.warp(block.timestamp + 101);
        ILock(lock).unlock(address(token), trader);

        assertEq(token.balanceOf(trader), tokenBalance);
    }

    function testListingLock() public {
        vm.startPrank(trader);
        (uint256 virtualNadAmount, uint256 virtualTokenAmount) = curve.getVirtualReserves();

        uint256 amountIn =
            endpoint.getAmountIn(1_000_000_000 ether - TARGET_TOKEN, curve.getK(), virtualNadAmount, virtualTokenAmount);
        console.log(amountIn);
        uint256 fee = amountIn / 100;
        vm.deal(trader, amountIn + fee);

        uint256 deadline = block.timestamp + 1;

        endpoint.buyExactAmountOut{value: amountIn + fee}(
            1_000_000_000 ether - TARGET_TOKEN, amountIn + fee, address(token), trader, deadline
        );
        assertEq(curve.getLock(), true);
        uint256 tokenBalance = token.balanceOf(trader);
        token.transfer(address(lock), tokenBalance);
        ILock(lock).lock(address(token), trader, tokenBalance, 0, true);

        vm.stopPrank();

        assertEq(token.balanceOf(address(lock)), tokenBalance);
        assertEq(ILock(lock).getLockedInfo(address(token), trader).length, 1);

        // 리스팅 전 언락 시도
        vm.expectRevert();
        ILock(lock).unlock(address(token), trader);

        // 리스팅 후 언락
        vm.prank(OWNER);
        curve.listing();

        ILock(lock).unlock(address(token), trader);

        assertEq(token.balanceOf(trader), tokenBalance);
    }

    function testMultipleLocks() public {
        vm.startPrank(trader);
        (uint256 virtualNadAmount, uint256 virtualTokenAmount) = curve.getVirtualReserves();

        uint256 amountIn =
            endpoint.getAmountIn(1_000_000_000 ether - TARGET_TOKEN, curve.getK(), virtualNadAmount, virtualTokenAmount);
        uint256 fee = amountIn / 100;
        vm.deal(trader, amountIn + fee);

        uint256 deadline = block.timestamp + 1;

        endpoint.buyExactAmountOut{value: amountIn + fee}(
            1_000_000_000 ether - TARGET_TOKEN, amountIn + fee, address(token), trader, deadline
        );

        uint256 tokenBalance = token.balanceOf(trader);
        uint256 quarterBalance = tokenBalance / 4;
        token.transfer(address(lock), quarterBalance);
        ILock(lock).lock(address(token), trader, quarterBalance, block.timestamp + 100, false); // Time lock 1
        token.transfer(address(lock), quarterBalance);
        ILock(lock).lock(address(token), trader, quarterBalance, block.timestamp + 200, false); // Time lock 2
        token.transfer(address(lock), quarterBalance);
        ILock(lock).lock(address(token), trader, quarterBalance, 0, true); // Listing lock 1
        token.transfer(address(lock), quarterBalance);
        ILock(lock).lock(address(token), trader, quarterBalance, 0, true); // Listing
        vm.stopPrank();

        assertEq(token.balanceOf(address(lock)), tokenBalance);
        assertEq(ILock(lock).getLockedInfo(address(token), trader).length, 4);

        // 첫 번째 time lock 해제
        vm.warp(block.timestamp + 101);
        ILock(lock).unlock(address(token), trader);
        assertEq(token.balanceOf(trader), quarterBalance);

        // 두 번째 time lock 해제
        vm.warp(block.timestamp + 100);
        ILock(lock).unlock(address(token), trader);
        assertEq(token.balanceOf(trader), quarterBalance * 2);

        // Listing lock 해제 시도 (아직 listing 되지 않음)
        vm.expectRevert();
        ILock(lock).unlock(address(token), trader);

        // Listing 실행
        vm.prank(OWNER);
        curve.listing();

        // 남은 두 개의 listing lock 해제
        ILock(lock).unlock(address(token), trader);
        assertEq(token.balanceOf(trader), tokenBalance);

        // 모든 lock이 해제되었으므로, 다시 unlock 시도하면 실패해야 함
        vm.expectRevert();
        ILock(lock).unlock(address(token), trader);

        assertEq(token.balanceOf(address(lock)), 0);
        assertEq(token.balanceOf(trader), tokenBalance);
    }
}
