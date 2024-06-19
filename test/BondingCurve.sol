// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BondingCurve} from "src/BondingCurve.sol";
import {BondingCurveFactory} from "src/BondingCurveFactory.sol";
import {Token} from "src/Token.sol";
import "src/errors/Errors.sol";
import {WNAD} from "src/WNAD.sol";
import "src/utils/NadsPumpLibrary.sol";

contract CurveTest is Test {
    BondingCurve curve;
    Token token;
    BondingCurveFactory factory;
    WNAD wNAD;
    address creator = address(0xb);
    address trader = address(0xc);
    uint256 deployFee = 2 * 10 ** 16;

    function setUp() public {
        // owner로 시작하는 프랭크 설정
        address owner = address(0xa);
        vm.startPrank(owner);
        uint256 tokenTotalSupply = 10 ** 27;
        uint256 virtualBase = 30 * 10 ** 18;
        uint256 virtualToken = 1073000191 * 10 ** 18;
        uint256 targetToken = 206900000 * 10 ** 18;
        uint8 feeDominator = 10;
        uint16 feeNumerator = 1000;
        // BondingCurveFactory 컨트랙트 배포 및 초기화
        wNAD = new WNAD();
        factory = new BondingCurveFactory(owner, address(wNAD));
        factory.initialize(
            deployFee, tokenTotalSupply, virtualBase, virtualToken, targetToken, feeNumerator, feeDominator
        );

        // owner로의 프랭크 종료
        vm.stopPrank();

        // creator에 충분한 자금을 할당
        vm.deal(creator, 0.02 ether);

        // creator로 새로운 프랭크 설정
        vm.startPrank(creator);

        // createCurve 함수 호출
        (address curveAddress, address tokenAddress) = factory.create{value: 0.02 ether}("test", "test");
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

    /**
     * @dev Curve Utils Test
     */
    // function testValidCheckSlippage() public {
    //     uint256 amountOut = 10 ** 18; // 1 ETH (1e18 Wei)
    //     uint256 slippagePercent = 10; // 1%

    //     // returnAmount는 amountOut의 0.5% 감소된 금액으로 설정 (슬리피지 허용 범위 이내)
    //     uint256 returnAmount = amountOut - (amountOut * 5 / 1000); // 1 ETH - 0.5% => 0.995 ETH

    //     // 슬리피지 허용 범위 이내이므로 오류가 발생하지 않아야 함
    //     curve.checkSlippage(amountOut, returnAmount, slippagePercent);

    //     returnAmount = amountOut + 1;
    //     curve.checkSlippage(amountOut, returnAmount, slippagePercent);
    // }

    // function testInvalidCheckSlippage() public {
    //     uint256 amountOut = 1000; // 1 ETH (1e18 Wei)
    //     uint256 slippagePercent = 10; // 1%

    //     // minReturnAmount = 1000 - (1000 * 10 / 1000) = 1000 - 10 = 990
    //     uint256 returnAmount = 989;

    //     vm.expectRevert("ERR_HIGH_SLIPPAGE");
    //     curve.checkSlippage(amountOut, returnAmount, slippagePercent);
    // }

    // function testCalculateFeeAmount() public {
    //     uint256 amount = 10 ** 18;

    //     //Fee setting dominator = 1, numerator = 1000
    //     (uint8 dominator, uint16 numerator) = curve.getFee();

    //     uint256 feeAmount = calculateFeeAmount(amount, dominator, numerator);

    //     assertEq(feeAmount, 10 ** 16);
    // }

    // function testgetAmountOut() public {
    //     // uint256 virtualNad = 30 * (10 ** 18);
    //     // uint256 virtualToken = 1073000191 * (10 ** 18);
    //     // uint256 amountIn = 85 * (10 ** 18);
    //     // uint256 k = virtualNad * virtualToken;
    //     // uint256 amountOut = NadsPumpLibrary.getAmountOut(k, amountIn, virtualNad, virtualToken);
    //     // console.log("amountOut = ", returnAmount); //357547547817394201932690

    //     uint256 amountIn = 100;
    //     uint256 reserveIn = 100;
    //     uint256 reserveOut = 100000;
    //     uint256 k = reserveIn * reserveOut;
    //     // //reserveOut - (k / (reserveIn + amountIn));
    //     // 100000 - ((100000 * 100) / (100 + 100)) - 1
    //     uint256 amountOut = NadsPumpLibrary.getAmountOut(k, amountIn, reserveIn, reserveOut);
    //     assertEq(amountOut, 49999);
    //     uint256 newK = (amountIn + reserveIn) * (reserveOut - amountOut);

    //     require(k <= newK, ERR_INVALID_K);
    // }

    // function testValidBuy() public {
    //     uint256 initialBalance = address(curve).balance;

    //     //deployFee = 0.02 ether

    //     vm.startPrank(trader);
    //     uint8 allowSlippage = 10;

    //     uint256 amountIn = 85 ether;
    //     uint256 fee = amountIn / 100;
    //     uint256 balanceIn = amountIn + fee;

    //     vm.deal(trader, balanceIn);
    //     wNAD.deposit{value: balanceIn}();
    //     // console.log(wNAD.balanceOf(address(trader)));

    //     // console.log(wNAD.balanceOf(address(trader)));

    //     // console.log(wNAD.balanceOf(address(curve)));
    //     (uint256 virtualBase, uint256 virtualToken) = curve.getVirtualReserves();
    //     uint256 amountOut = NadsPumpLibrary.getAmountOut(curve.getK(), virtualBase, virtualToken, amountIn, true) - 1;

    //     // uint256 amountOut = NadsPumpLibrary.getAmountOut(amountIn, virtualBase, virtualToken);
    //     // console.log("Amount Out = ",amountOut);
    //     // console.log(amountIn);
    //     wNAD.transfer(address(curve), balanceIn);
    //     curve.buy(trader, fee, amountOut);
    //     address owner = factory.getOwner();
    //     // swap fee is 1% = 10**14 + deploy fee 0.02 ether;
    //     assertEq(owner.balance, 20100000000000000);

    //     uint256 balance = token.balanceOf(trader);
    //     // console.log(balance); //353973251856887227215020
    //     //user balance check

    //     uint256 traderBalance = token.balanceOf(trader);
    //     assertEq(357547547817394201932690, traderBalance);
    // }

    // struct BuyTestConfig {
    //     uint256 amountIn;
    //     uint256 fee;
    //     uint256 value;
    //     uint8 allowSlippage;
    //     string errorMessage;
    // }

    // function testInValidBuy() public {
    //     BuyTestConfig[] memory buyTestConfigs = new BuyTestConfig[](8);
    //     vm.prank(trader);

    //     //Invalid Amount Out 0
    //     buyTestConfigs[0] = BuyTestConfig(1 ether, 0.01 ether, 1.01 ether, 10, ERR_INVALID_AMOUNT_OUT);
    //     //Invalid Sufficient Reserve
    //     buyTestConfigs[1] = BuyTestConfig(1 ether, 0.01 ether, 1.01 ether, 10, ERR_INSUFFICIENT_RESERVE);
    //     // //Invalid balancIn
    //     buyTestConfigs[2] = BuyTestConfig(1 ether, 0.01 ether, 0, 10, ERR_INVLIAD_BALANCE_IN);

    //     // //Invalid balanceIn == amoutnIn + fee
    //     buyTestConfigs[3] = BuyTestConfig(1 ether, 0.01 ether, 1 ether, 10, ERR_INVALID_AMOUNT_IN);

    //     // //OverFlow balanceIn
    //     buyTestConfigs[4] = BuyTestConfig(86 ether, 0.86 ether, 86.86 ether, 10, ERR_OVERFLOW_TARGET_BASE);

    //     // //Invalid Fee Test (fee is 0.01 ether)
    //     buyTestConfigs[5] = BuyTestConfig(2 ether, 0.01 ether, 2.01 ether, 10, ERR_INVALID_FEE);
    //     // //Invalid Amount In Test
    //     buyTestConfigs[6] = BuyTestConfig(1 ether, 0.01 ether, 1.02 ether, 10, ERR_INVALID_AMOUNT_IN);
    //     // //Invalid BalanceIn Test FEE + AMOUNTIN != PAY VALUE
    //     buyTestConfigs[7] = BuyTestConfig(1 ether, 0.01 ether, 2 ether, 10, ERR_INVALID_AMOUNT_IN);

    //     // buyTestConfig[4]
    //     for (uint256 i = 0; i < buyTestConfigs.length; i++) {
    //         BuyTestConfig memory config = buyTestConfigs[i];
    //         vm.deal(trader, config.amountIn + config.fee);
    //         // uint256 value = config.amountIn + config.fee;
    //         uint256 k = curve.getK();
    //         (uint256 virtualBase, uint256 virtualToken) = curve.getVirtualReserves();
    //         uint256 amountOut;
    //         if (i == 0) {
    //             amountOut = 0;
    //         } else if (i == 1) {
    //             amountOut = 10 ** 27 + 1;
    //         } else {
    //             amountOut = calculateReturnAmount(k, virtualBase, virtualToken, config.amountIn, true);
    //         }

    //         vm.expectRevert(bytes(config.errorMessage));

    //         curve.buy{value: config.value}(trader, config.amountIn, config.fee, amountOut, config.allowSlippage);
    //     }
    // }

    // function testValidSell() public {
    //     vm.startPrank(trader);
    //     // sellTestCongis[0] = SellTestC
    //     /**
    //      * @dev init trader balance is 1.01 ether
    //      *      amountIn is trade amount
    //      *      fee is 1% fee
    //      *      balanceIn is amoutIn + fee transfer to curve
    //      *      amountOut is expected balanceOut;
    //      */
    //     uint256 amountIn = 1 ether;
    //     uint256 fee = 0.01 ether;
    //     uint256 balanceIn = amountIn + fee;
    //     vm.deal(trader, balanceIn);
    //     uint256 k = curve.getK();
    //     wNAD.deposit{value: balanceIn}();
    //     (uint256 virtualBase, uint256 virtualToken) = curve.getVirtualReserves();
    //     uint256 amountOut = NadsPumpLibrary.calculateReturnAmount(k, virtualBase, virtualToken, amountIn, true);
    //     wNAD.transfer(address(curve), balanceIn);
    //     curve.buy(trader, amountIn, fee, amountOut);

    //     // (virtualBase, virtualToken) = curve.getVirtualReserves();
    //     // console.log("Curve Virtual is = ", virtualBase, virtualToken);
    //     // (uint256 reserveBase, uint256 reserveToken) = curve.getReserves();

    //     // console.log("Curve Reserve is = ", reserveBase, reserveToken);
    //     uint256 traderTokenAmount = token.balanceOf(trader);

    //     assertEq(amountOut, traderTokenAmount);

    //     /**
    //      * @dev amountOut is expected balanceOut;
    //      */
    //     (virtualBase, virtualToken) = curve.getVirtualReserves();
    //     amountIn = traderTokenAmount;
    //     console.log("Amount In = ", amountIn); //34612909387096774193548388
    //     amountOut = NadsPumpLibrary.calculateReturnAmount(k, virtualBase, virtualToken, amountIn, false);
    //     /**
    //      * amoutnOut is expected balanceOut - 1% fee
    //      */
    //     amountOut = (amountOut * 99) / 100;
    //     console.log("Amount Out = ", amountOut); //990000000000000000

    //     token.transfer(address(curve), amountIn);
    //     curve.sell(trader, amountOut);
    //     uint256 afterSellTokenBalance = token.balanceOf(trader); //990000000000000000 ?????
    //     console.log("afterSellTokenBalance = ", afterSellTokenBalance);
    //     //token all sell  -> balance 0
    //     // assertEq(0, afterSellTokenBalance);
    //     //initial balance = 1.01 ether -> buy 1 ehter fee 0.01 ether -> sell 1 ether - 0.01 ether;
    //     assertEq(1 ether - 0.01 ether, wNAD.balanceOf(address(trader)));
    // }

    // struct SellTestConfig {
    //     uint256 amountIn;
    //     uint256 fee;
    //     uint256 value;
    //     uint8 allowSlippage;
    //     string errorMessage;
    // }

    // function testInvalidSell() public {
    //     SellTestConfig[] memory configs = new SellTestConfig[](8);
    //     vm.prank(trader);

    //     //Invalid Amount Out 0
    //     configs[0] = SellTestConfig(1 ether, 0.01 ether, 1.01 ether, 10, ERR_INVALID_AMOUNT_OUT);

    //     for (uint256 i = 0; i < configs.length; i++) {
    //         SellTestConfig memory config = configs[i];
    //         vm.deal(trader, config.amountIn);
    //         uint256 k = curve.getK();
    //         (uint256 virtualBase, uint256 virtualToken) = curve.getVirtualReserves();

    //         uint256 amountOut = calculateReturnAmount(k, virtualBase, virtualToken, config.amountIn, false);

    //         vm.expectRevert(bytes(config.errorMessage));

    //         curve.sell(trader, amountOut, config.allowSlippage);
    //     }
    // }
}
