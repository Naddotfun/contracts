// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BondingCurve} from "src/BondingCurve.sol";
import {BondingCurveFactory} from "src/BondingCurveFactory.sol";
import {Token} from "src/Token.sol";
import "src/errors/Errors.sol";
import {IWNAD} from "src/interfaces/IWNAD.sol";
import {WNAD} from "src/WNAD.sol";
import {NadsPumpLibrary} from "src/utils/NadsPumpLibrary.sol";
import {Endpoint} from "src/Endpoint.sol";
import {FeeVault} from "src/FeeVault.sol";
import {UniswapV2Factory} from "src/uniswap/UniswapV2Factory.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Lock} from "src/Lock.sol";

contract CurveTest is Test {
    BondingCurve curve;
    Token token;
    BondingCurveFactory factory;
    WNAD wNad;
    Endpoint endpoint;
    FeeVault vault;
    UniswapV2Factory uniFactory;
    address creator = address(0xb);
    address trader = address(0xc);
    uint256 deployFee = 2 * 10 ** 16;
    uint256 listingFee = 1 ether;
    // uint256 listingFee = 1;
    uint256 tokenTotalSupply = 10 ** 27;
    uint256 virtualNad = 30 * 10 ** 18;
    uint256 virtualToken = 1_073_000_191 * 10 ** 18;
    uint256 k = virtualNad * virtualToken;
    uint256 targetToken = 206_900_000 * 10 ** 18;
    // uint256 targetToken = (10 ** 27) - 100000000;

    uint8 feeDominator = 10;
    uint16 feeNumerator = 1000;

    function setUp() public {
        // owner로 시작하는 프랭크 설정
        address owner = address(0xa);
        vm.startPrank(owner);

        uniFactory = new UniswapV2Factory(owner);

        // BondingCurveFactory 컨트랙트 배포 및 초기화
        wNad = new WNAD();
        factory = new BondingCurveFactory(owner, address(wNad));
        factory.initialize(
            deployFee,
            listingFee,
            tokenTotalSupply,
            virtualNad,
            virtualToken,
            targetToken,
            feeNumerator,
            feeDominator,
            address(uniFactory)
        );
        vault = new FeeVault(IERC20(address(wNad)));
        Lock lock = new Lock(address(factory));
        endpoint = new Endpoint(address(factory), address(wNad), address(vault), address(lock));

        factory.setEndpoint(address(endpoint));
        // owner로의 프랭크 종료
        vm.stopPrank();

        // creator에 충분한 자금을 할당
        vm.deal(creator, 0.02 ether);

        // creator로 새로운 프랭크 설정
        vm.startPrank(creator);

        // createCurve 함수 호출
        (address curveAddress, address tokenAddress, uint256 virtualNad, uint256 virtualToken, uint256 amountOut) =
            endpoint.createCurve{value: 0.02 ether}("test", "test", "testurl", 0, 0, 0.02 ether);
        curve = BondingCurve(curveAddress);
        token = Token(tokenAddress);
        // creator로의 프랭크 종료
        vm.stopPrank();
    }

    function testListing() public {
        vm.startPrank(trader);
        (uint256 virtualNadAmount, uint256 virtualTokenAmount) = curve.getVirtualReserves();

        uint256 amountIn =
            endpoint.getAmountIn(1_000_000_000 ether - targetToken, curve.getK(), virtualNadAmount, virtualTokenAmount);
        console.log(amountIn);
        uint256 fee = amountIn / 100;
        vm.deal(trader, amountIn + fee);

        uint256 deadline = block.timestamp + 1;

        endpoint.buyExactAmountOut{value: amountIn + fee}(
            1_000_000_000 ether - targetToken, amountIn + fee, address(token), trader, deadline
        );

        assertEq(curve.getLock(), true);
        console.log("curve wnad", IERC20(wNad).balanceOf(address(curve)));
        console.log("curve token", IERC20(token).balanceOf(address(curve)));
        address pair = curve.listing();

        assertEq(IERC4626(vault).totalAssets(), listingFee + 0.02 ether + fee);

        assertEq(IERC20(wNad).balanceOf(pair), amountIn - listingFee);
        assertEq(IERC20(token).balanceOf(pair), targetToken);
        //sqrt(84005301050330472980 * 206900000000000000000000000)
        // assertEq(IERC20(pair).balanceOf(address(0)),)

        assert(IERC20(pair).balanceOf(address(0)) >= 131835870639645623191986);
        (uint256 realNadAmount, uint256 realTokenAmount) = curve.getReserves();
        assertEq(realNadAmount, 0);
        assertEq(realTokenAmount, 0);
        assertEq(IERC20(wNad).balanceOf(address(curve)), 0);
        assertEq(IERC20(token).balanceOf(address(curve)), 0);
    }

    // function testListing2() public {
    //     vm.startPrank(trader);
    //     (uint256 virtualNadAmount, uint256 virtualTokenAmount) = curve.getVirtualReserves();

    //     uint256 amountIn = endpoint.getAmountIn(100000000, curve.getK(), virtualNadAmount, virtualTokenAmount);
    //     console.log(amountIn);
    //     uint256 fee = amountIn / 100;
    //     vm.deal(trader, amountIn + fee);

    //     uint256 deadline = block.timestamp + 1;

    //     endpoint.buyExactAmountOut{value: amountIn + fee}(100000000, amountIn + fee, address(token), trader, deadline);

    //     assertEq(curve.getLock(), true);
    //     console.log("curve wnad", IERC20(wNad).balanceOf(address(curve)));
    //     console.log("curve token", IERC20(token).balanceOf(address(curve)));
    //     address pair = curve.listing();

    //     assertEq(IERC4626(vault).totalAssets(), listingFee + 0.02 ether + fee);

    //     assertEq(IERC20(wNad).balanceOf(pair), amountIn - listingFee);
    //     assertEq(IERC20(token).balanceOf(pair), targetToken);
    //     //sqrt(84005301050330472980 * 206900000000000000000000000)
    //     // assertEq(IERC20(pair).balanceOf(address(0)),)

    //     assert(IERC20(pair).balanceOf(address(0)) >= 131835870639645623191986);
    //     (uint256 realNadAmount, uint256 realTokenAmount) = curve.getReserves();
    //     assertEq(realNadAmount, 0);
    //     assertEq(realTokenAmount, 0);
    //     assertEq(IERC20(wNad).balanceOf(address(curve)), 0);
    //     assertEq(IERC20(token).balanceOf(address(curve)), 0);
    // }
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
