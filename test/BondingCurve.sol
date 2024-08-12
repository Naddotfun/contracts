// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BondingCurve} from "src/BondingCurve.sol";
import {BondingCurveFactory} from "src/BondingCurveFactory.sol";
import {Token} from "src/Token.sol";
import "src/errors/Errors.sol";
import "src/interfaces/IWNAD.sol";
import {WNAD} from "src/WNAD.sol";
import "src/utils/NadsPumpLibrary.sol";
import "src/Endpoint.sol";

contract CurveTest is Test {
    BondingCurve curve;
    Token token;
    BondingCurveFactory factory;
    WNAD wNad;
    Endpoint endpoint;
    address creator = address(0xb);
    address trader = address(0xc);
    address vault = address(0xc);
    uint256 deployFee = 2 * 10 ** 16;
    uint256 tokenTotalSupply = 10 ** 27;
    uint256 virtualNad = 30 * 10 ** 18;
    uint256 virtualToken = 1073000191 * 10 ** 18;
    uint256 k = virtualNad * virtualToken;
    uint256 targetToken = 206900000 * 10 ** 18;

    uint8 feeDominator = 10;
    uint16 feeNumerator = 1000;

    function setUp() public {
        // owner로 시작하는 프랭크 설정
        address owner = address(0xa);
        vm.startPrank(owner);

        // BondingCurveFactory 컨트랙트 배포 및 초기화
        wNad = new WNAD();
        factory = new BondingCurveFactory(owner, address(wNad));
        factory.initialize(
            deployFee, tokenTotalSupply, virtualNad, virtualToken, targetToken, feeNumerator, feeDominator
        );

        endpoint = new Endpoint(address(factory), address(wNad), vault);

        factory.setEndpoint(address(endpoint));
        // owner로의 프랭크 종료
        vm.stopPrank();

        // creator에 충분한 자금을 할당
        vm.deal(creator, 0.02 ether);

        // creator로 새로운 프랭크 설정
        vm.startPrank(creator);

        // createCurve 함수 호출
        (address curveAddress, address tokenAddress, uint256 virtualNad, uint256 virtualToken) =
            endpoint.createCurve{value: 0.02 ether}("test", "test", "testurl", 0, 0, 0.02 ether);
        curve = BondingCurve(curveAddress);
        token = Token(tokenAddress);
        // creator로의 프랭크 종료
        vm.stopPrank();
    }

    /**
     * @dev Curve Status Test
     */
    function testInitFee() public {
        (uint8 dominator, uint16 numerator) = curve.getFee();
        assertEq(dominator, 10);
        assertEq(numerator, 1000);
    }

    function testInitLock() public {
        bool lock = curve.getLock();
        assertEq(lock, false);
    }

    function testGetReserve() public {
        (uint256 reserveBase, uint256 reserveToken) = curve.getReserves();
        assertEq(reserveBase, 0);
        assertEq(reserveToken, 10 ** 27);
    }

    function testGetVirtualReserve() public {
        (uint256 virtualNad, uint256 virtualToken) = curve.getVirtualReserves();
        assertEq(virtualNad, 30 * 10 ** 18);
        assertEq(virtualToken, 1073000191 * 10 ** 18);
    }

    function testGetFeeConfig() public {
        (uint8 dominator, uint16 numerator) = curve.getFee();
        assertEq(dominator, 10);
        assertEq(numerator, 1000);
    }

    function testGetK() public {
        uint256 k = curve.getK();
        assertEq(k, 30 * 10 ** 18 * 1073000191 * 10 ** 18);
    }

    function testGetLock() public {
        bool lock = curve.getLock();
        assertEq(lock, false);
    }
}
