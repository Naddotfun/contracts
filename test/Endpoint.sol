// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {BondingCurve} from "src/BondingCurve.sol";
import {BondingCurveFactory} from "src/BondingCurveFactory.sol";
import {Token} from "src/Token.sol";
import "src/errors/Errors.sol";
import {WNAD} from "src/WNAD.sol";
import "src/utils/NadsPumpLibrary.sol";
import "src/Endpoint.sol";

contract EndpointTest is Test {
    BondingCurve curve;
    Token token;
    BondingCurveFactory factory;
    WNAD wNad;
    Endpoint endpoint;
    address owner = address(0xa);
    address creator = address(0xb);
    uint256 traderPrivateKey = 0xA11CE;
    address trader = vm.addr(traderPrivateKey);
    uint256 deployFee = 2 * 10 ** 16;
    uint256 virtualNad = 30 * 10 ** 18;
    uint256 virtualToken = 1_073_000_191 * 10 ** 18;
    uint256 k = virtualNad * virtualToken;
    uint256 targetToken = 206_900_000 * 10 ** 18;
    uint256 tokenTotalSupply = 10 ** 27;

    uint8 feeDominator = 10;
    uint16 feeNumerator = 1000;

    function setUp() public {
        // owner로 시작하는 프랭크 설정

        vm.startPrank(owner);

        // BondingCurveFactory 컨트랙트 배포 및 초기화
        wNad = new WNAD();
        factory = new BondingCurveFactory(owner, address(wNad));
        factory.initialize(
            deployFee, tokenTotalSupply, virtualNad, virtualToken, targetToken, feeNumerator, feeDominator
        );

        endpoint = new Endpoint(address(factory), address(wNad));

        factory.setEndpoint(address(endpoint));
        // owner로의 프랭크 종료
        vm.stopPrank();

        // creator에 충분한 자금을 할당
        vm.deal(creator, 0.02 ether);

        // creator로 새로운 프랭크 설정
        vm.startPrank(creator);

        // createCurve 함수 호출
        (address curveAddress, address tokenAddress) =
            endpoint.createCurve{value: 0.02 ether}("test", "test", 0, 0, 0.02 ether);
        curve = BondingCurve(curveAddress);
        token = Token(tokenAddress);
        // creator로의 프랭크 종료
        vm.stopPrank();
    }

    function testCreateCurve() public {
        // address creator = address(0xb);
        vm.deal(creator, 1.03 ether);
        // vm.recordLogs();
        vm.startPrank(creator);
        (address curve, address token) =
            endpoint.createCurve{value: 1.03 ether}("Test", "Test", 1 ether, 0.01 ether, 0.02 ether);

        vm.stopPrank();
        assertEq(owner.balance, 0.04 ether);
        assertEq(creator.balance, 0);
        // 기록된 이벤트 로그 수집
        // Vm.Log[] memory logs = vm.getRecordedLogs();

        // address tokenAddress;

        // // Create 이벤트 로그 분석 및 token 주소 출력
        // for (uint256 i = 0; i < logs.length; i++) {
        //     Vm.Log memory log = logs[i];

        //     // Create 이벤트의 토픽 확인 (토픽이 최소 4개 있는지 확인)
        //     if (log.topics.length == 4 && log.topics[0] == keccak256("Create(address,address,address)")) {
        //         tokenAddress = address(uint160(uint256(log.topics[2])));

        //         // token 주소 로그 출력
        //         console.log("Token Address from Create Event:", tokenAddress);
        //         break; // 이벤트를 찾았으므로 더 이상 반복할 필요 없음
        //     }
        // }

        // require(tokenAddress != address(0), "Create event not found or token address not found");
        // console.log(IERC20(tokenAddress).balanceOf(creator));
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        assertEq(IERC20(token).balanceOf(creator), amountOut);
    }

    function testInvalidValueCreateCurve() public {
        vm.deal(creator, 1.01 ether);
        vm.expectRevert(bytes(ERR_INVALID_SEND_NAD));
        vm.startPrank(creator);
        //보내야할 이더 양은 = 1.03 ether
        endpoint.createCurve{value: 1.01 ether}("TEST", "TEST", 1 ether, 0.01 ether, 0.02 ether);
        vm.stopPrank();
    }

    // function testInvalidAmountInCreateCurve() public {
    //     vm.deal(creator, 1.01 ether);
    //     vm.expectRevert(bytes(ERR_INVALID_AMOUNT_IN));
    //     vm.startPrank(creator);
    //     //amountIn = 0;
    //     endpoint.createCurve{value: 1.01 ether}("TEST", "TEST", 0, 0.01 ether, 0.02 ether);
    //     vm.stopPrank();
    // }

    // function testInvalidFeeCreateCurve() public {
    //     vm.deal(creator, 1.02 ether);
    //     vm.expectRevert(bytes(ERR_INVALID_FEE));
    //     vm.startPrank(creator);
    //     //amountIn = 0;
    //     endpoint.createCurve{value: 1.02 ether}("TEST", "TEST", 1 ether, 0, 0.02 ether);
    //     vm.stopPrank();
    // }
    /**
     * @dev Buy Test
     */
    function testInvalidDeployFeeCreateCurve() public {
        vm.deal(creator, 1.02 ether);
        vm.expectRevert(bytes(ERR_INSUFFICIENT_FEE));
        vm.startPrank(creator);
        //amountIn = 0;
        endpoint.createCurve{value: 1.02 ether}("TEST", "TEST", 1 ether, 0.01 ether, 0.01 ether);
        vm.stopPrank();
    }

    function testBuy() public {
        vm.startPrank(trader);

        vm.deal(trader, 1.01 ether);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);

        uint256 deadline = block.timestamp + 1;
        endpoint.buy{value: 1.01 ether}(1 ether, 0.01 ether, address(token), trader, deadline);
        vm.stopPrank();
        assertEq(token.balanceOf(trader), amountOut);
        assertEq(trader.balance, 0);
        //fee 로 받은 0.01 ether 는 owner 에게 전송됨.
        //wrap 상태로 받음
        assertEq(IERC20(address(wNad)).balanceOf(owner), 0.01 ether);
    }

    function InvalidValueBuy() public {
        vm.startPrank(trader);

        vm.deal(trader, 1.01 ether);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);

        uint256 deadline = block.timestamp + 1;
        //1.01 ether 보내야함
        vm.expectRevert(bytes(ERR_INVALID_SEND_NAD));
        endpoint.buy{value: 1 ether}(1 ether, 0.01 ether, address(token), trader, deadline);
        assertEq(wNad.balanceOf(owner), 0.01 ether);
    }

    function InvalidAmountInAndFeeBuy() public {
        vm.startPrank(trader);

        vm.deal(trader, 1.01 ether);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);

        uint256 deadline = block.timestamp + 1;
        //1.01 ether 보내야함
        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_IN));
        endpoint.buy{value: 1.01 ether}(0, 0.01 ether, address(token), trader, deadline);
        vm.expectRevert(bytes(ERR_INVALID_FEE));
        endpoint.buy{value: 1.01 ether}(1, 0, address(token), trader, deadline);
    }
    /**
     * @dev BuyAmountOutMin Test
     */

    function testBuyAmountOutMin() public {
        vm.startPrank(trader);
        vm.deal(trader, 1.01 ether);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        // console.log("Calculated amountOut: ", amountOut);
        uint256 deadline = block.timestamp + 1;

        endpoint.buyAmountOutMin{value: 1.01 ether}(
            1 ether, amountOut - 1, 0.01 ether, address(token), trader, deadline
        );
        vm.stopPrank();

        assertEq(token.balanceOf(trader), amountOut);
        assertEq(trader.balance, 0);
        assertEq(wNad.balanceOf(owner), 0.01 ether);
    }

    function testInvalidValueBuyAmountOutMin() public {
        vm.startPrank(trader);
        vm.deal(trader, 1.01 ether);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        // console.log("Calculated amountOut: ", amountOut);
        uint256 deadline = block.timestamp + 1;

        vm.expectRevert(bytes(ERR_INVALID_SEND_NAD));
        endpoint.buyAmountOutMin{value: 1 ether}(1 ether, amountOut - 1, 0.01 ether, address(token), trader, deadline);
    }

    function testInvalidAmountOutMinBuyAmountOutMin() public {
        vm.startPrank(trader);
        vm.deal(trader, 1.01 ether);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        // console.log("Calculated amountOut: ", amountOut);
        uint256 deadline = block.timestamp + 1;

        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_OUT));
        endpoint.buyAmountOutMin{value: 1.01 ether}(
            1 ether, amountOut + 1, 0.01 ether, address(token), trader, deadline
        );
    }

    /**
     * @dev Buy ExactAmountOut Test
     */
    function testBuyExactAmountOut() public {
        vm.startPrank(trader);
        //1 ether 로 살 수 있는 토큰의 양 계산
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 amountIn = NadsPumpLibrary.getAmountIn(amountOut, k, virtualNad, virtualToken); //1 ether
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(amountIn, feeDominator, feeNumerator); //0.01 ether;

        uint256 totalAmountIn = amountIn + feeAmount;
        uint256 traderBalance = 2 ether;
        vm.deal(trader, traderBalance);

        uint256 deadline = block.timestamp + 1;

        endpoint.buyExactAmountOut{value: traderBalance}(amountOut, traderBalance, address(token), trader, deadline);
        vm.stopPrank();
        assertEq(token.balanceOf(trader), amountOut);
        //2ether 를 보냈지만 1.01 만썻으므로 trader.balance = 990000000000000000
        assertEq(trader.balance, traderBalance - totalAmountIn);
        assertEq(wNad.balanceOf(owner), feeAmount);
    }

    function testInvalidValuebuyExactAmountOut() public {
        vm.startPrank(trader);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 amountIn = NadsPumpLibrary.getAmountIn(amountOut, k, virtualNad, virtualToken);
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(amountIn, feeDominator, feeNumerator);
        uint256 totalAmountIn = amountIn + feeAmount;
        uint256 traderBalance = 2 ether;
        vm.deal(trader, traderBalance);

        uint256 deadline = block.timestamp + 1;

        vm.expectRevert(bytes(ERR_INVALID_SEND_NAD));
        endpoint.buyExactAmountOut{value: traderBalance - 1}(amountOut, traderBalance, address(token), trader, deadline);
    }

    function testOverflowAmountInMaxBuyExactAmountOut() public {
        vm.startPrank(trader);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(1 ether, k, virtualNad, virtualToken);
        uint256 amountIn = NadsPumpLibrary.getAmountIn(amountOut, k, virtualNad, virtualToken);
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(amountIn, feeDominator, feeNumerator);
        uint256 totalAmountIn = amountIn + feeAmount;
        uint256 traderBalance = 1.01 ether;
        vm.deal(trader, traderBalance);

        uint256 deadline = block.timestamp + 1;
        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_IN_MAX));
        endpoint.buyExactAmountOut{value: traderBalance}(
            amountOut + 100, traderBalance, address(token), trader, deadline
        );
    }

    /**
     * @dev Sell Test
     */
    function testSell() public {
        testBuy();
        vm.startPrank(trader);
        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        uint256 nadAmount = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(nadAmount, feeDominator, feeNumerator);

        uint256 deadline = block.timestamp + 1;
        token.approve(address(endpoint), traderTokenBalance);
        endpoint.sell(traderTokenBalance, address(token), trader, deadline);
        vm.stopPrank();
        assertEq(token.balanceOf(trader), 0);
        assertEq(trader.balance, nadAmount - feeAmount);
        assertEq(wNad.balanceOf(owner), feeAmount + 0.01 ether);
    }

    function testInvalidAllowanceSell() public {
        testBuy();

        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        uint256 nadAmount = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(nadAmount, feeDominator, feeNumerator);

        uint256 deadline = block.timestamp + 1;
        vm.startPrank(trader);
        token.approve(address(endpoint), traderTokenBalance);
        vm.expectRevert(bytes(ERR_INVALID_ALLOWANCE));

        endpoint.sell(traderTokenBalance + 1, address(token), trader, deadline);
        vm.stopPrank();
    }

    function testSellAmountOutMin() public {
        testBuy();
        vm.startPrank(trader);
        uint256 traderTokenBalance = token.balanceOf(trader);
        console.log(traderTokenBalance);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        uint256 nadAmountOut = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);
        console.log("NadAmountOut = ", nadAmountOut);
        uint256 feeAmountOut = NadsPumpLibrary.getFeeAmount(nadAmountOut, feeDominator, feeNumerator);
        console.log("FeeAmountOut = ", feeAmountOut);
        nadAmountOut -= feeAmountOut;
        uint256 deadline = block.timestamp + 1;
        token.approve(address(endpoint), traderTokenBalance);
        endpoint.sellAmountOutMin(traderTokenBalance, nadAmountOut - 1, address(token), trader, deadline);
        vm.stopPrank();
        assertEq(token.balanceOf(trader), 0);
        assertEq(trader.balance, nadAmountOut);
        assertEq(wNad.balanceOf(owner), feeAmountOut + 0.01 ether);
    }

    function testInvalidAllonwaceSellAmountOutMin() public {
        testBuy();

        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        uint256 nadAmount = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(nadAmount, feeDominator, feeNumerator);

        uint256 deadline = block.timestamp + 1;
        vm.startPrank(trader);
        token.approve(address(endpoint), traderTokenBalance - 1);
        vm.expectRevert(bytes(ERR_INVALID_ALLOWANCE));
        endpoint.sellAmountOutMin(traderTokenBalance, nadAmount, address(token), trader, deadline);
        vm.stopPrank();
    }

    function testOverflowAmountOutSellAmountOutMin() public {
        testBuy();

        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        uint256 nadAmount = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(nadAmount, feeDominator, feeNumerator);

        uint256 deadline = block.timestamp + 1;
        vm.startPrank(trader);
        token.approve(address(endpoint), traderTokenBalance);
        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_OUT));
        endpoint.sellAmountOutMin(traderTokenBalance, nadAmount + 1, address(token), trader, deadline);
        vm.stopPrank();
    }

    /**
     * @dev SellAmountOutMinWithPermit Test
     */
    function testSellAmountOutMinWithPermit() public {
        testBuy();
        //---------Buy End----------------------
        vm.startPrank(trader);
        uint256 traderTokenBalance = token.balanceOf(trader);

        (virtualNad, virtualToken) = curve.getVirtualReserves();
        uint256 nadAmountOut = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);

        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(nadAmountOut, feeDominator, feeNumerator);

        nadAmountOut -= feeAmount;
        uint256 deadline = block.timestamp + 1;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(token.PERMIT_TYPEHASH(), trader, address(endpoint), traderTokenBalance, 0, deadline)
                )
            )
        );
        // console.logBytes32(digest);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);

        endpoint.sellAmountOutMinWithPermit(
            traderTokenBalance, nadAmountOut - 1, address(token), trader, trader, deadline, v, r, s
        );
        vm.stopPrank();
        assertEq(token.balanceOf(trader), 0);
        assertEq(trader.balance, nadAmountOut);
        assertEq(wNad.balanceOf(owner), feeAmount + 0.01 ether);
    }

    function testInvalidAmountOutSellAmountOutMinWithPermit() public {
        testBuy();
        //---------Buy End----------------------
        vm.startPrank(trader);
        uint256 traderTokenBalance = token.balanceOf(trader);

        (virtualNad, virtualToken) = curve.getVirtualReserves();
        uint256 nadAmountOut = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);

        uint256 feeAmountOut = NadsPumpLibrary.getFeeAmount(nadAmountOut, feeDominator, feeNumerator);

        nadAmountOut -= feeAmountOut;
        uint256 deadline = block.timestamp + 1;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(token.PERMIT_TYPEHASH(), trader, address(endpoint), traderTokenBalance, 0, deadline)
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);
        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_OUT));
        endpoint.sellAmountOutMinWithPermit(
            traderTokenBalance, nadAmountOut + 1, address(token), trader, trader, deadline, v, r, s
        );
    }

    /**
     * @dev SellExactAmountOut Test
     */
    function testSellExactAmountOut() public {
        testBuy();
        vm.startPrank(trader);
        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        //nadAmount
        uint256 amountOut = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);

        uint256 wantedAmountOut = amountOut / 2;
        // console.log("wanted Amount = ", amountOut / 2);
        uint256 deadline = block.timestamp + 1;
        token.approve(address(endpoint), traderTokenBalance);
        endpoint.sellExactAmountOut(wantedAmountOut, traderTokenBalance, address(token), trader, deadline);
        // console.log("Recieved Nad", trader.balance);
        vm.stopPrank();

        //Sell 일경우 amountOut 에 1%를 더한 금액을 인출할 amountIn 을 해야 함.
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(wantedAmountOut, feeDominator, feeNumerator);
        uint256 totalAmountIn = NadsPumpLibrary.getAmountIn(wantedAmountOut + feeAmount, k, virtualToken, virtualNad);

        // console.log("totalAmountIn = ", totalAmountIn);
        assertEq(token.balanceOf(trader), traderTokenBalance - totalAmountIn);
        assertEq(trader.balance, wantedAmountOut);
        assertEq(wNad.balanceOf(owner), feeAmount + 0.01 ether);
    }

    function testInvalidAllowacneSellExactAmountOut() public {
        testBuy();
        vm.startPrank(trader);
        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        //nadAmount
        uint256 amountOut = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);

        uint256 wantedAmountOut = amountOut / 2;

        uint256 deadline = block.timestamp + 1;
        token.approve(address(endpoint), traderTokenBalance - 1);
        vm.expectRevert(bytes(ERR_INVALID_ALLOWANCE));
        endpoint.sellExactAmountOut(wantedAmountOut, traderTokenBalance, address(token), trader, deadline);
        // console.log("Recieved Nad", trader.balance);
        vm.stopPrank();
    }

    function testOverflowAmountInMaxsellExactAmountOut() public {
        testBuy();
        vm.startPrank(trader);
        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();

        uint256 amountOut = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);

        uint256 wantedAmountOut = amountOut;

        uint256 deadline = block.timestamp + 1;
        token.approve(address(endpoint), traderTokenBalance);
        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_IN_MAX));
        endpoint.sellExactAmountOut(amountOut + 1, traderTokenBalance, address(token), trader, deadline);
        // console.log("Recieved Nad", trader.balance);
        vm.stopPrank();
    }

    /**
     * @dev SellExactAmountOutWithPermit Test
     */
    function testSellExactAmountOutWithPermit() public {
        testBuy();
        vm.startPrank(trader);
        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        //nadAmount

        uint256 amountOut = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);
        uint256 wantedAmountOut = amountOut / 2;
        // console.log("wanted Amount = ", amountOut / 2);
        uint256 deadline = block.timestamp + 1;

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(token.PERMIT_TYPEHASH(), trader, address(endpoint), traderTokenBalance, 0, deadline)
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);

        endpoint.sellExactAmountOutwithPermit(
            wantedAmountOut, traderTokenBalance, address(token), trader, trader, deadline, v, r, s
        );

        vm.stopPrank();

        //Sell 일경우 amountOut 에 1%를 더한 금액을 인출할 amountIn 을 해야 함.
        uint256 feeAmount = NadsPumpLibrary.getFeeAmount(wantedAmountOut, feeDominator, feeNumerator);
        uint256 totalAmountIn = NadsPumpLibrary.getAmountIn(wantedAmountOut + feeAmount, k, virtualToken, virtualNad);

        assertEq(token.balanceOf(trader), traderTokenBalance - totalAmountIn);
        assertEq(trader.balance, wantedAmountOut);
        //buy 1 ether -> 0.01 protocol fee
        assertEq(wNad.balanceOf(owner), feeAmount + 0.01 ether);
    }

    function testOverflowAmountInMaxSellExactAmountOutWithPermit() public {
        testBuy();
        vm.startPrank(trader);
        uint256 traderTokenBalance = token.balanceOf(trader);
        (virtualNad, virtualToken) = curve.getVirtualReserves();
        //nadAmount
        uint256 amountOut = NadsPumpLibrary.getAmountOut(traderTokenBalance, k, virtualToken, virtualNad);

        // console.log("wanted Amount = ", amountOut / 2);
        uint256 deadline = block.timestamp + 1;
        // token.approve(address(endpoint), traderTokenBalance);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(token.PERMIT_TYPEHASH(), trader, address(endpoint), traderTokenBalance, 0, deadline)
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(traderPrivateKey, digest);
        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_IN_MAX));
        endpoint.sellExactAmountOutwithPermit(
            amountOut + 1, traderTokenBalance, address(token), trader, trader, deadline, v, r, s
        );

        vm.stopPrank();
    }
    /**
     * TestCase for BondingCurve
     */

    function testOverflowTrargetBondingCurveBuy() public {
        vm.startPrank(trader);
        // uint256 amountIn = 86 ether;
        // uint256 fee = amountIn / 100;
        uint256 maximalAmountOut = tokenTotalSupply - targetToken;
        uint256 amountIn = NadsPumpLibrary.getAmountIn(maximalAmountOut, k, virtualNad, virtualToken) + 1;
        uint256 fee = amountIn / 100;
        console.log("Amount In = ", amountIn);
        vm.deal(trader, amountIn + fee);
        uint256 amountOut = NadsPumpLibrary.getAmountOut(amountIn, k, virtualNad, virtualToken);
        uint256 deadline = block.timestamp + 1;
        vm.expectRevert(bytes(ERR_OVERFLOW_TARGET));
        endpoint.buy{value: amountIn + fee}(amountIn, fee, address(token), trader, deadline);
        vm.stopPrank();
    }

    function testBondingCurveBuyInvalidFee() public {
        vm.startPrank(trader);
        uint256 amountIn = 1 ether;
        uint256 fee = (amountIn / 100) - 1;
        vm.deal(trader, amountIn + fee);

        uint256 amountOut = NadsPumpLibrary.getAmountOut(amountIn, k, virtualNad, virtualToken);
        uint256 deadline = block.timestamp + 1;
        vm.expectRevert(bytes(ERR_INVALID_FEE));
        endpoint.buy{value: amountIn + fee}(amountIn, fee, address(token), trader, deadline);
        vm.stopPrank();
    }

    function testBondingCurveSellInvalidAmountIn() public {
        testBuy();
        vm.startPrank(trader);
        uint256 amountIn = 0 ether;
        uint256 traderTokenBalance = token.balanceOf(trader);
        token.approve(address(endpoint), traderTokenBalance);
        uint256 deadline = block.timestamp + 1;
        vm.expectRevert(bytes(ERR_INVALID_AMOUNT_IN));
        endpoint.sell(0, address(token), trader, deadline);
    }
}
