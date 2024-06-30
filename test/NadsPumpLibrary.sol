// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "src/utils/NadsPumpLibrary.sol";
import "src/BondingCurve.sol";
import "src/BondingCurveFactory.sol";
import "src/Endpoint.sol";
import "src/WNAD.sol";
import "src/Token.sol";
import "src/errors/Errors.sol";

contract NadsPumpLibraryTest is Test {
    BondingCurve curve;
    Token token;
    BondingCurveFactory factory;
    WNAD wNad;
    Endpoint endpoint;
    address creator = address(0xb);
    address trader = address(0xc);
    // uint256 deployFee = 2 * 10 ** 16;
    uint256 virtualToken = 1_000_000_000 ether;
    uint256 virtualNad = 30 ether;
    uint256 k = virtualToken * virtualNad;
    uint256 targetToken = 200_000_000 ether;

    function setUp() public {
        // owner로 시작하는 프랭크 설정
        address owner = address(0xa);
        vm.startPrank(owner);
        uint256 tokenTotalSupply = 100 ether;

        uint8 feeDominator = 1;
        uint16 feeNumerator = 100;
        uint256 deployFee = 0.02 ether;
        // BondingCurveFactory 컨트랙트 배포 및 초기화
        wNad = new WNAD();
        factory = new BondingCurveFactory(owner, address(wNad));
        factory.initialize(
            deployFee, tokenTotalSupply, virtualNad, virtualToken, targetToken, feeNumerator, feeDominator
        );

        endpoint = new Endpoint(address(factory), address(wNad));

        factory.setEndpoint(address(endpoint));

        vm.stopPrank();

        vm.deal(creator, 0.02 ether);

        vm.startPrank(creator);

        // createCurve 함수 호출
        (address curveAddress, address tokenAddress) =
            endpoint.createCurve{value: 0.02 ether}("test", "test", "testurl", 0, 0, 0.02 ether);
        curve = BondingCurve(curveAddress);
        token = Token(tokenAddress);
        // creator로의 프랭크 종료
        vm.stopPrank();
    }

    function testGetAmountOut() public {
        uint256 amountIn = 1 ether;
        //uint256 virtualToken = 1_000_000_000 ether;
        //uint256 virtualNad = 30 ether;
        //uint256 k = virtualToken * virtualNad;

        //amountOut = virtualToken - (k / (virtualNad + amountIn));
        uint256 amountOut = NadsPumpLibrary.getAmountOut(amountIn, k, virtualNad, virtualToken);
        // console.log("Amount OUT", amountOut);
        assertEq(amountOut, 32258064516129032258064516);
    }

    function testGetAmountIn() public {
        uint256 amountOut = 32_258_064_516_129_032_258_064_516;

        uint256 amountIn = NadsPumpLibrary.getAmountIn(amountOut, k, virtualNad, virtualToken);
        // console.log("Amount IN", amountIn);
        assertEq(amountIn, 1 ether);
    }

    // function testGetFeeAndAdjustedAmount() public {
    //     uint256 amount = 1 ether;
    //     uint8 feeDenominator = 1;
    //     uint16 feeNumerator = 100;
    //     (uint256 fee, uint256 adjustedAmount) =
    //         NadsPumpLibrary.getFeeAndAdjustedAmount(amount, feeDenominator, feeNumerator);
    //     assertEq(fee, 0.01 ether);
    //     assertEq(adjustedAmount, 0.99 ether);
    // }

    function testGetFeeAmount() public {
        uint256 amount = 1 ether;
        uint8 feeDenominator = 1;
        uint16 feeNumerator = 100;
        uint256 fee = NadsPumpLibrary.getFeeAmount(amount, feeDenominator, feeNumerator);
        assertEq(fee, 0.01 ether);
    }

    function testGetCurveData() public {
        (address curveAddress, uint256 virtualNad, uint256 virtualToken, uint256 k_) =
            NadsPumpLibrary.getCurveData(address(factory), address(token));
        assertEq(curveAddress, address(curve));
        assertEq(virtualNad, 30 ether);
        assertEq(virtualToken, 1_000_000_000 ether);
        assertEq(k_, k);
    }

    function testFeeConfig() public {
        (uint8 feeDenominator, uint16 feeNumerator) = NadsPumpLibrary.getFeeConfig(address(curve));
        assertEq(feeDenominator, 1);
        assertEq(feeNumerator, 100);
    }

    function testGetCurve() public {
        address curveAddress = NadsPumpLibrary.getCurve(address(factory), address(token));
        assertEq(curveAddress, address(curve));
    }

    function testGetVirtualReserves() public {
        (uint256 virtualNad_, uint256 virtualToken_) = NadsPumpLibrary.getVirtualReserves(address(curve));
        assertEq(virtualNad_, 30 ether);
        assertEq(virtualToken_, 1_000_000_000 ether);
    }

    function testGetK() public {
        uint256 k_ = NadsPumpLibrary.getK(address(curve));
        assertEq(k_, k);
    }
}
