// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console, Vm} from "forge-std/Test.sol";
import {BondingCurve} from "src/BondingCurve.sol";
import {Token} from "src/Token.sol";
import "src/errors/Errors.sol";
import {IWNative} from "src/interfaces/IWNative.sol";
import {WNative} from "src/WNative.sol";
import {BondingCurveLibrary} from "src/utils/BondingCurveLibrary.sol";
import {Core} from "src/Core.sol";
import {FeeVault} from "src/FeeVault.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IFeeVault} from "src/interfaces/IFeeVault.sol";
import "./SetUp.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract CoreCreateTest is Test, SetUp {
    // ============ Success Tests ============
    function testCreateCurveSuccess() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, DEPLOY_FEE);

        (
            address curveAddress,
            address tokenAddress,
            uint256 virtualNative,
            uint256 virtualToken,
            uint256 amountOut
        ) = CORE.createCurve{value: DEPLOY_FEE}(
                TRADER_A,
                "Test Token",
                "TEST",
                "test.url",
                0,
                0
            );

        // Verify curve and token addresses are valid
        assertTrue(curveAddress != address(0));
        assertTrue(tokenAddress != address(0));

        // Verify token properties
        Token token = Token(tokenAddress);
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.totalSupply(), TOKEN_TOTAL_SUPPLY);

        // Verify initial virtual reserves
        (uint256 vNad, uint256 vToken) = BondingCurve(payable(curveAddress))
            .getVirtualReserves();
        assertEq(vNad, virtualNative);
        assertEq(vToken, virtualToken);

        // Verify fees went to vault
        assertEq(IFeeVault(FEE_VAULT).totalAssets(), DEPLOY_FEE);

        vm.stopPrank();
    }

    function testCreateCurveWithInitialLiquidity() public {
        vm.startPrank(OWNER);
        uint256 initialNad = 1 ether;
        uint256 fee = initialNad / 100; // 1% fee
        vm.deal(OWNER, initialNad + fee + DEPLOY_FEE);

        (
            address curveAddress,
            address tokenAddress,
            uint256 virtualNative,
            uint256 virtualToken,
            uint256 amountOut
        ) = CORE.createCurve{value: initialNad + fee + DEPLOY_FEE}(
                TRADER_A,
                "Test Token",
                "TEST",
                "test.url",
                initialNad,
                fee
            );

        // Verify curve and token creation
        assertTrue(curveAddress != address(0));
        assertTrue(tokenAddress != address(0));

        // Verify initial liquidity
        (uint256 vNad, uint256 vToken) = BondingCurve(payable(curveAddress))
            .getVirtualReserves();
        assertEq(vNad, virtualNative);
        assertTrue(amountOut > 0);

        // Verify fees went to vault
        assertEq(IFeeVault(FEE_VAULT).totalAssets(), fee + DEPLOY_FEE);

        vm.stopPrank();
    }

    // ============ Failure Test ============
    function testCreateCurveInsufficientDeployFee() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, DEPLOY_FEE - 1);

        vm.expectRevert(bytes(ERR_CORE_INVALID_SEND_NATIVE));
        CORE.createCurve{value: DEPLOY_FEE - 1}(
            TRADER_A,
            "Test Token",
            "TEST",
            "test.url",
            0,
            0
        );

        vm.stopPrank();
    }

    function testCreateCurveInvalidInitialAmount() public {
        vm.startPrank(OWNER);
        uint256 initialNative = 1 ether;
        uint256 fee = initialNative / 100; // 1% fee
        vm.deal(OWNER, initialNative + fee + DEPLOY_FEE - 1);

        vm.expectRevert(bytes(ERR_CORE_INVALID_SEND_NATIVE));
        CORE.createCurve{value: initialNative + fee + DEPLOY_FEE - 1}(
            TRADER_A,
            "Test Token",
            "TEST",
            "test.url",
            initialNative,
            fee
        );

        vm.stopPrank();
    }

    function testCreateCurveInvalidFee() public {
        vm.startPrank(OWNER);
        uint256 initialNad = 1 ether;
        uint256 fee = initialNad / 200; // 0.5% fee (less than required 1%)
        vm.deal(OWNER, initialNad + fee + DEPLOY_FEE);

        vm.expectRevert(bytes(ERR_CORE_INVALID_FEE));
        CORE.createCurve{value: initialNad + fee + DEPLOY_FEE}(
            TRADER_A,
            "Test Token",
            "TEST",
            "test.url",
            initialNad,
            fee
        );

        vm.stopPrank();
    }
}

contract CoreBuyTest is Test, SetUp {
    function setUp() public override {
        super.setUp();
        CreateBondingCurve(CREATOR);
    }

    // ============ Buy Tests ============
    // ============ Success Tests ============
    function testBuySuccess() public {
        // Setup
        vm.startPrank(OWNER);
        vm.deal(OWNER, 100 ether);

        uint256 amountIn = 1 ether;
        uint256 fee = amountIn / 100; // 1% fee
        address to = OWNER;
        uint256 deadline = block.timestamp + 1 hours;

        // Execute buy
        CORE.buy{value: amountIn + fee}(
            amountIn,
            fee,
            address(MEME_TOKEN),
            to,
            deadline
        );

        // Assert the results
        assertGt(IERC20(address(MEME_TOKEN)).balanceOf(OWNER), 0);
        vm.stopPrank();
    }

    // ============ Failure Tests ============
    function testBuyFailInvalidNadAmount() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, 100 ether);

        uint256 amountIn = 1 ether;
        uint256 fee = amountIn / 100; // 1% fee
        uint256 deadline = block.timestamp + 1 hours;

        // Should fail because msg.value < amountIn + fee
        vm.expectRevert(bytes(ERR_CORE_INVALID_SEND_NATIVE));
        CORE.buy{value: amountIn}(
            amountIn,
            fee,
            address(MEME_TOKEN),
            OWNER,
            deadline
        );
        vm.stopPrank();
    }

    function testBuyFailZeroAmountIn() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, 100 ether);

        uint256 amountIn = 0; // Invalid amount
        uint256 fee = 0; // fee will be 0 since amountIn is 0
        uint256 deadline = block.timestamp + 1 hours;

        vm.expectRevert(bytes(ERR_CORE_INVALID_AMOUNT_IN));
        CORE.buy{value: fee}(
            amountIn,
            fee,
            address(MEME_TOKEN),
            OWNER,
            deadline
        );
        vm.stopPrank();
    }

    function testBuyFailZeroFee() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, 100 ether);

        uint256 amountIn = 1 ether;
        uint256 fee = 0; // Invalid fee (should be 1% of amountIn)
        uint256 deadline = block.timestamp + 1 hours;

        vm.expectRevert(bytes(ERR_CORE_INVALID_FEE));
        CORE.buy{value: amountIn}(
            amountIn,
            fee,
            address(MEME_TOKEN),
            OWNER,
            deadline
        );
        vm.stopPrank();
    }

    function testBuyFailExpiredDeadline() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, 100 ether);

        uint256 amountIn = 1 ether;
        uint256 fee = amountIn / 100; // 1% fee
        uint256 deadline = block.timestamp - 1; // Expired deadline

        vm.expectRevert(bytes(ERR_CORE_EXPIRED));
        CORE.buy{value: amountIn + fee}(
            amountIn,
            fee,
            address(MEME_TOKEN),
            OWNER,
            deadline
        );
        vm.stopPrank();
    }

    // ============ BuyAmountOunMin Tests ============

    // ============ Success Tests ============
    function testProtectBuySuccess() public {
        // Setup
        vm.startPrank(OWNER);
        vm.deal(OWNER, 100 ether);

        uint256 amountIn = 1 ether;
        uint256 fee = amountIn / 100; // 1% fee

        //AMOUNT Out 계산
        (uint256 virtualNative, uint256 virtualToken) = CURVE
            .getVirtualReserves();
        uint256 amountOutMin = BondingCurveLibrary.getAmountOut(
            amountIn,
            CURVE.getK(),
            virtualNative,
            virtualToken
        );

        address to = OWNER;
        uint256 deadline = block.timestamp + 1 hours;

        // Execute buy with minimum amount out
        CORE.protectBuy{value: amountIn + fee}(
            amountIn,
            amountOutMin - 1,
            fee,
            address(MEME_TOKEN),
            to,
            deadline
        );

        // Assert the results
        uint256 balance = IERC20(address(MEME_TOKEN)).balanceOf(OWNER);
        assertGt(balance, 0);
        assertGe(balance, amountOutMin);
        vm.stopPrank();
    }

    // ============ Failure Tests ============
    function testProtectBuyFailInvalidNadAmount() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, 100 ether);

        uint256 amountIn = 1 ether;
        uint256 fee = amountIn / 100; // 1% fee

        //AMOUNT Out Calculation
        (uint256 virtualNative, uint256 virtualToken) = CURVE
            .getVirtualReserves();
        uint256 amountOut = BondingCurveLibrary.getAmountOut(
            amountIn,
            CURVE.getK(),
            virtualNative,
            virtualToken
        );

        uint amountOutMin = amountOut - 1;

        uint256 deadline = block.timestamp + 1 hours;

        // Should fail because msg.value < amountIn + fee
        vm.expectRevert(bytes(ERR_CORE_INVALID_SEND_NATIVE));
        CORE.protectBuy{value: amountIn}(
            amountIn,
            amountOutMin, //Amount Out Min should be less than amountOut
            fee,
            address(MEME_TOKEN),
            OWNER,
            deadline
        );
        vm.stopPrank();
    }

    function testProtectBuyFailInvalidAmountOut() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, 100 ether);

        uint256 amountIn = 1 ether;
        uint256 fee = amountIn / 100; // 1% fee

        //AMOUNT Out 계산
        (uint256 virtualNative, uint256 virtualToken) = CURVE
            .getVirtualReserves();
        uint256 amountOutMin = BondingCurveLibrary.getAmountOut(
            amountIn,
            CURVE.getK(),
            virtualNative,
            virtualToken
        );
        // Set amountOutMin higher than possible output
        amountOutMin = amountOutMin + 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.expectRevert(bytes(ERR_CORE_INVALID_AMOUNT_OUT));
        CORE.protectBuy{value: amountIn + fee}(
            amountIn,
            amountOutMin,
            fee,
            address(MEME_TOKEN),
            OWNER,
            deadline
        );
        vm.stopPrank();
    }

    function testProtectBuyFailExpiredDeadline() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, 100 ether);

        uint256 amountIn = 1 ether;
        uint256 fee = amountIn / 100; // 1% fee

        //AMOUNT Out 계산
        (uint256 virtualNative, uint256 virtualToken) = CURVE
            .getVirtualReserves();
        uint256 amountOutMin = BondingCurveLibrary.getAmountOut(
            amountIn,
            CURVE.getK(),
            virtualNative,
            virtualToken
        );
        uint256 deadline = block.timestamp - 1; // Expired deadline

        vm.expectRevert(bytes(ERR_CORE_EXPIRED));
        CORE.protectBuy{value: amountIn + fee}(
            amountIn,
            amountOutMin,
            fee,
            address(MEME_TOKEN),
            OWNER,
            deadline
        );
        vm.stopPrank();
    }

    //=========== Buy Exact Amount Out Tests ============
    // ============ Success Tests ============
    function testExactOutBuySuccess() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, 100 ether);

        uint256 amountOut = 1 ether;

        // Calculate required amountIn
        (uint256 virtualNative, uint256 virtualToken) = CURVE
            .getVirtualReserves();
        uint256 amountIn = BondingCurveLibrary.getAmountIn(
            amountOut,
            CURVE.getK(),
            virtualNative,
            virtualToken
        );

        // Calculate fee
        (uint8 denominator, uint16 numerator) = CURVE.getFeeConfig();
        uint256 fee = BondingCurveLibrary.getFeeAmount(
            amountIn,
            denominator,
            numerator
        );

        uint256 amountInMax = amountIn + fee + 1; // Add some buffer
        uint256 deadline = block.timestamp + 1 hours;

        // Execute buy exact amount out
        CORE.exactOutBuy{value: amountInMax}(
            amountOut,
            amountInMax,
            address(MEME_TOKEN),
            OWNER,
            deadline
        );

        // Assert the results
        assertEq(MEME_TOKEN.balanceOf(OWNER), amountOut);
        vm.stopPrank();
    }

    // ============ Failure Tests ============
    function testExactOutBuyFailInvalidNadAmount() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, 100 ether);

        uint256 amountOut = 1 ether;

        // Calculate required amountIn
        (uint256 virtualNative, uint256 virtualToken) = CURVE
            .getVirtualReserves();
        uint256 amountIn = BondingCurveLibrary.getAmountIn(
            amountOut,
            CURVE.getK(),
            virtualNative,
            virtualToken
        );

        // Calculate fee
        (uint8 denominator, uint16 numerator) = CURVE.getFeeConfig();
        uint256 fee = BondingCurveLibrary.getFeeAmount(
            amountIn,
            denominator,
            numerator
        );

        uint256 amountInMax = amountIn + fee + 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        // Should fail because msg.value < amountInMax
        vm.expectRevert(bytes(ERR_CORE_INVALID_SEND_NATIVE));
        CORE.exactOutBuy{value: amountInMax - 1}(
            amountOut,
            amountInMax,
            address(MEME_TOKEN),
            OWNER,
            deadline
        );
        vm.stopPrank();
    }

    function testExactOutBuyFailInvalidAmountInMax() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, 100 ether);

        uint256 amountOut = 1 ether;

        // Calculate required amountIn
        (uint256 virtualNative, uint256 virtualToken) = CURVE
            .getVirtualReserves();
        uint256 amountIn = BondingCurveLibrary.getAmountIn(
            amountOut,
            CURVE.getK(),
            virtualNative,
            virtualToken
        );

        // Calculate fee
        (uint8 denominator, uint16 numerator) = CURVE.getFeeConfig();
        uint256 fee = BondingCurveLibrary.getFeeAmount(
            amountIn,
            denominator,
            numerator
        );

        // Set amountInMax less than required amountIn + fee
        uint256 amountInMax = amountIn + fee - 1;
        uint256 deadline = block.timestamp + 1 hours;

        vm.expectRevert(bytes(ERR_CORE_INVALID_AMOUNT_IN_MAX));
        CORE.exactOutBuy{value: amountInMax}(
            amountOut,
            amountInMax,
            address(MEME_TOKEN),
            OWNER,
            deadline
        );
        vm.stopPrank();
    }

    function testExactOutBuyFailExpiredDeadline() public {
        vm.startPrank(OWNER);
        vm.deal(OWNER, 100 ether);

        uint256 amountOut = 1 ether;

        // Calculate required amountIn
        (uint256 virtualNative, uint256 virtualToken) = CURVE
            .getVirtualReserves();
        uint256 amountIn = BondingCurveLibrary.getAmountIn(
            amountOut,
            CURVE.getK(),
            virtualNative,
            virtualToken
        );

        // Calculate fee
        (uint8 denominator, uint16 numerator) = CURVE.getFeeConfig();
        uint256 fee = BondingCurveLibrary.getFeeAmount(
            amountIn,
            denominator,
            numerator
        );

        uint256 amountInMax = amountIn + fee + 1 ether;
        uint256 deadline = block.timestamp - 1; // Expired deadline

        vm.expectRevert(bytes(ERR_CORE_EXPIRED));
        CORE.exactOutBuy{value: amountInMax}(
            amountOut,
            amountInMax,
            address(MEME_TOKEN),
            OWNER,
            deadline
        );
        vm.stopPrank();
    }
}

contract CoreSellTest is Test, SetUp {
    function setUp() public override {
        super.setUp();
        CreateBondingCurve(CREATOR);
    }

    function testSellSuccess() public {
        uint256 amountIn = 1e18;

        // TRADER_A가 토큰을 구매
        Buy(TRADER_A, amountIn);
        vm.startPrank(TRADER_A);
        uint256 deadline = block.timestamp + 1;

        // 초기 잔액 저장
        uint256 initialNadBalance = TRADER_A.balance;
        uint256 initialTokenBalance = MEME_TOKEN.balanceOf(TRADER_A);

        // 본딩 커브의 가상 준비금 가져오기
        (uint256 virtualNative, uint256 virtualToken) = CURVE
            .getVirtualReserves();
        uint256 k = CURVE.getK();

        // 예상 출력값 계산
        uint256 expectedAmountOut = BondingCurveLibrary.getAmountOut(
            amountIn,
            k,
            virtualToken,
            virtualNative
        );
        (uint8 denominator, uint16 numerator) = CURVE.getFeeConfig();
        uint256 expectedFee = BondingCurveLibrary.getFeeAmount(
            expectedAmountOut,
            denominator,
            numerator
        );

        // TRADER_A가 Core 컨트랙트에 토큰 사용을 승인
        MEME_TOKEN.approve(address(CORE), amountIn);

        // sell 함수 실행
        CORE.sell(amountIn, address(MEME_TOKEN), TRADER_A, deadline);
        vm.stopPrank();

        // 결과 검증
        assertEq(
            MEME_TOKEN.balanceOf(TRADER_A),
            initialTokenBalance - amountIn,
            "Invalid token balance after sell"
        );
        assertEq(
            TRADER_A.balance,
            initialNadBalance + expectedAmountOut - expectedFee,
            "Invalid NAD balance after sell"
        );
    }

    function testSellFailInvalidAllowance() public {
        uint256 amountIn = 1e18;
        uint256 deadline = block.timestamp + 1;

        // 토큰만 발행하고 승인은 하지 않음
        deal(address(MEME_TOKEN), address(this), amountIn);

        vm.expectRevert(bytes(ERR_CORE_INVALID_ALLOWANCE));
        CORE.sell(amountIn, address(MEME_TOKEN), address(this), deadline);
    }

    function testSellFailInvalidAmountIn() public {
        uint256 amountIn = 0;
        uint256 deadline = block.timestamp + 1;

        vm.expectRevert(bytes(ERR_CORE_INVALID_AMOUNT_IN));
        CORE.sell(amountIn, address(MEME_TOKEN), address(this), deadline);
    }

    function testSellFailExpiredDeadline() public {
        uint currentTime = block.timestamp;
        uint256 amountIn = 1e18;
        uint256 deadline = currentTime - 1;

        vm.expectRevert(bytes(ERR_CORE_EXPIRED));
        CORE.sell(amountIn, address(MEME_TOKEN), address(this), deadline);
    }

    //=========== ProtectSell Tests ============
    function testProtectSellSuccess() public {
        uint256 amountIn = 1e18;

        // TRADER_A가 토큰을 구매
        Buy(TRADER_A, amountIn);
        vm.startPrank(TRADER_A);
        uint256 deadline = block.timestamp + 1;

        // 초기 잔액 저장
        uint256 initialNadBalance = TRADER_A.balance;
        uint256 initialTokenBalance = MEME_TOKEN.balanceOf(TRADER_A);

        // 본딩 커브의 가상 준비금 가져오기
        (uint256 virtualNative, uint256 virtualToken) = CURVE
            .getVirtualReserves();
        uint256 k = CURVE.getK();

        // 예상 출력값 계산
        uint256 expectedAmountOut = BondingCurveLibrary.getAmountOut(
            amountIn,
            k,
            virtualToken,
            virtualNative
        );
        (uint8 denominator, uint16 numerator) = CURVE.getFeeConfig();
        uint256 expectedFee = BondingCurveLibrary.getFeeAmount(
            expectedAmountOut,
            denominator,
            numerator
        );

        // amountOutMin을 예상 출력값보다 약간 낮게 설정
        console.log(expectedAmountOut, expectedFee);
        uint256 amountOutMin = expectedAmountOut - expectedFee - 1;

        // TRADER_A가 Core 컨트랙트에 토큰 사용을 승인
        MEME_TOKEN.approve(address(CORE), amountIn);

        // protectSell 함수 실행
        CORE.protectSell(
            amountIn,
            amountOutMin,
            address(MEME_TOKEN),
            TRADER_A,
            deadline
        );
        vm.stopPrank();

        // 결과 검증
        assertEq(
            MEME_TOKEN.balanceOf(TRADER_A),
            initialTokenBalance - amountIn,
            "Invalid token balance after sell"
        );
        assertEq(
            TRADER_A.balance,
            initialNadBalance + expectedAmountOut - expectedFee,
            "Invalid NAD balance after sell"
        );
    }

    function testProtectSellFailInsufficientOutput() public {
        uint256 amountIn = 1e18;

        // TRADER_A가 토큰을 구매
        Buy(TRADER_A, amountIn);
        vm.startPrank(TRADER_A);
        uint256 deadline = block.timestamp + 1;

        // 본딩 커브의 가상 준비금 가져오기
        (uint256 virtualNative, uint256 virtualToken) = CURVE
            .getVirtualReserves();
        uint256 k = CURVE.getK();

        // 예상 출력값 계산
        uint256 expectedAmountOut = BondingCurveLibrary.getAmountOut(
            amountIn,
            k,
            virtualToken,
            virtualNative
        );

        // amountOutMin을 예상 출력값보다 높게 설정
        uint256 amountOutMin = expectedAmountOut + 1e18;

        // TRADER_A가 Core 컨트랙트에 토큰 사용을 승인
        MEME_TOKEN.approve(address(CORE), amountIn);

        vm.expectRevert(bytes(ERR_CORE_INVALID_AMOUNT_OUT));
        CORE.protectSell(
            amountIn,
            amountOutMin,
            address(MEME_TOKEN),
            TRADER_A,
            deadline
        );
        vm.stopPrank();
    }

    function testProtectSellFailExpiredDeadline() public {
        uint256 amountIn = 1e18;
        uint256 deadline = block.timestamp - 1;

        vm.expectRevert(bytes(ERR_CORE_EXPIRED));
        CORE.protectSell(
            amountIn,
            0,
            address(MEME_TOKEN),
            address(this),
            deadline
        );
    }

    //=========== SellPermit Tests ============
    function testSellPermitSuccess() public {
        uint256 amountIn = 1e18;
        uint256 deadline = block.timestamp + 1;

        // TRADER_A가 토큰을 구매
        Buy(TRADER_A, amountIn);

        // TRADER_A의 private key 가져오기
        uint256 privateKey = uint256(keccak256(abi.encodePacked("TRADER_A")));
        address signer = vm.addr(privateKey);

        vm.startPrank(signer);
        // 초기 잔액 저장
        uint256 initialNadBalance = signer.balance;
        uint256 initialTokenBalance = MEME_TOKEN.balanceOf(signer);

        // EIP-712 도메인 분리자 및 구조화된 데이터 준비
        bytes32 DOMAIN_SEPARATOR = MEME_TOKEN.DOMAIN_SEPARATOR();
        bytes32 PERMIT_TYPEHASH = MEME_TOKEN.permitTypeHash();
        uint256 nonce = MEME_TOKEN.nonces(signer);

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                signer,
                address(CORE),
                amountIn,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // sellPermit 함수 실행
        CORE.sellPermit(
            amountIn,
            address(MEME_TOKEN),
            signer,
            signer,
            deadline,
            v,
            r,
            s
        );
        vm.stopPrank();

        // 결과 검증
        assertEq(
            MEME_TOKEN.balanceOf(signer),
            initialTokenBalance - amountIn,
            "Invalid token balance after sell"
        );
        assertTrue(
            signer.balance > initialNadBalance,
            "NAD balance should increase after sell"
        );
    }

    function testSellPermitFailExpiredPermitDeadline() public {
        uint256 amountIn = 1e18;

        // EIP-712 도메인 분리자 및 구조화된 데이터 준비
        bytes32 DOMAIN_SEPARATOR = MEME_TOKEN.DOMAIN_SEPARATOR();
        bytes32 PERMIT_TYPEHASH = MEME_TOKEN.permitTypeHash();
        uint256 nonce = MEME_TOKEN.nonces(TRADER_A);

        uint256 deadline = block.timestamp - 1;

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                TRADER_A,
                address(CORE),
                amountIn,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Permit.ERC2612ExpiredSignature.selector,
                deadline
            )
        );
        CORE.sellPermit(
            amountIn,
            address(MEME_TOKEN),
            TRADER_A,
            TRADER_A,
            deadline,
            v,
            r,
            s
        );
    }

    //=========== ProtectSellPermit Tests ============
    function testProtectSellPermitSuccess() public {
        uint256 amountIn = 1e18;
        uint256 amountOutMin = 0;
        uint256 deadline = block.timestamp + 1;

        // TRADER_A가 토큰을 구매
        Buy(TRADER_A, amountIn);

        // TRADER_A의 private key 가져오기
        uint256 privateKey = uint256(keccak256(abi.encodePacked("TRADER_A")));
        address signer = vm.addr(privateKey);

        vm.startPrank(signer);
        // 초기 잔액 저장
        uint256 initialNadBalance = signer.balance;
        uint256 initialTokenBalance = MEME_TOKEN.balanceOf(signer);

        // EIP-712 도메인 분리자 및 구조화된 데이터 준비
        bytes32 DOMAIN_SEPARATOR = MEME_TOKEN.DOMAIN_SEPARATOR();
        bytes32 PERMIT_TYPEHASH = MEME_TOKEN.permitTypeHash();
        uint256 nonce = MEME_TOKEN.nonces(signer);

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                signer,
                address(CORE),
                amountIn,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // protectSellPermit 함수 실행
        CORE.protectSellPermit(
            amountIn,
            amountOutMin,
            address(MEME_TOKEN),
            signer,
            signer,
            deadline,
            v,
            r,
            s
        );
        vm.stopPrank();

        // 결과 검증
        assertEq(
            MEME_TOKEN.balanceOf(signer),
            initialTokenBalance - amountIn,
            "Invalid token balance after sell"
        );
        assertTrue(
            signer.balance > initialNadBalance,
            "NAD balance should increase after sell"
        );
    }

    function testProtectSellPermitFailInsufficientOutput() public {
        uint256 amountIn = 1 ether;
        Buy(TRADER_A, amountIn);

        uint256 tokenAmount = MEME_TOKEN.balanceOf(TRADER_A);
        uint256 deadline = block.timestamp + 1;
        (uint256 virtualNative, uint256 virtualToken) = CURVE
            .getVirtualReserves();
        uint256 k = CURVE.getK();

        // 예상 출력값 계산
        uint256 expectedAmountOut = BondingCurveLibrary.getAmountOut(
            amountIn,
            k,
            virtualToken,
            virtualNative
        );

        uint amountOutMin = expectedAmountOut + 1 ether;
        // TRADER_A의 private key 가져오기
        uint256 privateKey = uint256(keccak256(abi.encodePacked("TRADER_A")));
        address signer = vm.addr(privateKey);

        // EIP-712 도메인 분리자 및 구조화된 데이터 준비
        bytes32 DOMAIN_SEPARATOR = MEME_TOKEN.DOMAIN_SEPARATOR();
        bytes32 PERMIT_TYPEHASH = MEME_TOKEN.permitTypeHash();
        uint256 nonce = MEME_TOKEN.nonces(signer);

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                signer,
                address(CORE),
                tokenAmount,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.expectRevert(bytes(ERR_CORE_INVALID_AMOUNT_OUT));
        CORE.protectSellPermit(
            tokenAmount,
            amountOutMin,
            address(MEME_TOKEN),
            signer,
            signer,
            deadline,
            v,
            r,
            s
        );
    }

    //=========== ExactOutSell Tests ============
    function testExactOutSellSuccess() public {
        // TRADER_A가 토큰을 구매
        Buy(TRADER_A, 1 ether);
        vm.startPrank(TRADER_A);

        // 초기 잔액 저장
        uint256 initialNadBalance = TRADER_A.balance;
        uint256 initialTokenBalance = MEME_TOKEN.balanceOf(TRADER_A);

        MEME_TOKEN.approve(address(CORE), initialTokenBalance);

        // 본딩 커브의 가상 준비금 가져오기
        (uint256 virtualNative, uint256 virtualToken) = CURVE
            .getVirtualReserves();
        uint256 k = CURVE.getK();

        // 예상 출력값 계산
        uint256 amountOut = BondingCurveLibrary.getAmountOut(
            initialTokenBalance,
            k,
            virtualToken,
            virtualNative
        ) - 100;

        uint fee = amountOut / 100;

        vm.deal(TRADER_A, fee);
        // exactOutSell 함수 실행
        CORE.exactOutSell{value: fee}(
            amountOut,
            initialTokenBalance,
            address(MEME_TOKEN),
            TRADER_A,
            block.timestamp + 1
        );

        // 결과 검증
        assertTrue(
            MEME_TOKEN.balanceOf(TRADER_A) < initialTokenBalance,
            "Token balance should decrease after sell"
        );
        assertEq(
            TRADER_A.balance - initialNadBalance,
            amountOut,
            "NAD balance should increase by exact amount"
        );
        vm.stopPrank();
    }

    function testExactOutSellFailExcessiveInput() public {
        Buy(TRADER_A, 1 ether);

        (uint256 virtualNative, uint256 virtualToken) = CURVE
            .getVirtualReserves();
        uint256 k = CURVE.getK();
        uint tokenAmount = MEME_TOKEN.balanceOf(TRADER_A);

        uint expectedAmountOut = BondingCurveLibrary.getAmountOut(
            1 ether,
            k,
            virtualToken,
            virtualNative
        );

        uint wantedAmountOut = expectedAmountOut + 1 ether;

        uint fee = wantedAmountOut / 100;
        vm.deal(TRADER_A, fee);
        vm.startPrank(TRADER_A);
        MEME_TOKEN.approve(address(CORE), tokenAmount);

        vm.expectRevert(bytes(ERR_CORE_INVALID_AMOUNT_IN_MAX));
        CORE.exactOutSell{value: fee}(
            wantedAmountOut,
            tokenAmount,
            address(MEME_TOKEN),
            TRADER_A,
            block.timestamp + 1
        );
        vm.stopPrank();
    }

    //=========== ExactOutSellPermit Tests ============
    function testExactOutSellPermitSuccess() public {
        uint256 deadline = block.timestamp + 1;

        // TRADER_A가 토큰을 구매
        Buy(TRADER_A, 1 ether);
        uint tokenAmount = MEME_TOKEN.balanceOf(TRADER_A);
        // TRADER_A의 private key 가져오기
        uint256 privateKey = uint256(keccak256(abi.encodePacked("TRADER_A")));
        address signer = vm.addr(privateKey);

        vm.startPrank(signer);
        // 초기 잔액 저장
        uint256 initialNadBalance = signer.balance;
        uint256 initialTokenBalance = MEME_TOKEN.balanceOf(signer);

        // EIP-712 도메인 분리자 및 구조화된 데이터 준비
        bytes32 DOMAIN_SEPARATOR = MEME_TOKEN.DOMAIN_SEPARATOR();
        bytes32 PERMIT_TYPEHASH = MEME_TOKEN.permitTypeHash();
        uint256 nonce = MEME_TOKEN.nonces(signer);

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                signer,
                address(CORE),
                tokenAmount,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        (uint virtualNative, uint virtualToken) = CURVE.getVirtualReserves();
        //amountOut 을 계산하기
        uint amountOut = BondingCurveLibrary.getAmountOut(
            tokenAmount,
            CURVE.getK(),
            virtualToken,
            virtualNative
        ) - 1;

        uint fee = (amountOut) / 100;
        vm.deal(signer, fee);
        // exactOutSellPermit 함수 실행
        CORE.exactOutSellPermit{value: fee}(
            amountOut,
            tokenAmount,
            address(MEME_TOKEN),
            signer,
            signer,
            deadline,
            v,
            r,
            s
        );
        vm.stopPrank();

        // 결과 검증
        assertTrue(
            MEME_TOKEN.balanceOf(signer) < initialTokenBalance,
            "Token balance should decrease after sell"
        );
        assertEq(
            signer.balance,
            amountOut,
            "NAD balance should exact amountOut"
        );
    }

    function testExactOutSellPermitFailExcessiveInput() public {
        Buy(TRADER_A, 1 ether);

        uint tokenAmount = MEME_TOKEN.balanceOf(TRADER_A);

        uint256 deadline = block.timestamp + 1;

        // TRADER_A의 private key 가져오기
        uint256 privateKey = uint256(keccak256(abi.encodePacked("TRADER_A")));
        address signer = vm.addr(privateKey);

        // EIP-712 도메인 분리자 및 구조화된 데이터 준비
        bytes32 DOMAIN_SEPARATOR = MEME_TOKEN.DOMAIN_SEPARATOR();
        bytes32 PERMIT_TYPEHASH = MEME_TOKEN.permitTypeHash();
        uint256 nonce = MEME_TOKEN.nonces(signer);

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                signer,
                address(CORE),
                tokenAmount,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        (uint virtualNative, uint virtualToken) = CURVE.getVirtualReserves();

        uint amountOut = BondingCurveLibrary.getAmountOut(
            tokenAmount,
            CURVE.getK(),
            virtualToken,
            virtualNative
        );

        uint wantedAmountOut = amountOut + 1 ether;
        uint fee = (wantedAmountOut) / 100;
        vm.deal(signer, fee);

        vm.expectRevert(bytes(ERR_CORE_INVALID_AMOUNT_IN_MAX));
        CORE.exactOutSellPermit{value: fee}(
            wantedAmountOut,
            tokenAmount,
            address(MEME_TOKEN),
            signer,
            signer,
            deadline,
            v,
            r,
            s
        );
    }
}
