// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MintPartyFactory} from "../src/MintPartyFactory.sol";
import {MintParty} from "../src/MintParty.sol";
import {BondingCurveFactory} from "../src/BondingCurveFactory.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {WNative} from "../src/WNative.sol";
import {FeeVault} from "../src/FeeVault.sol";
import {Lock} from "../src/Lock.sol";
import {UniswapV2Factory} from "../src/uniswap/UniswapV2Factory.sol";
import {UniswapV2Pair} from "../src/uniswap/UniswapV2Pair.sol";
import {UniswapV2Router} from "../src/uniswap/UniswapV2Router.sol";
// import {UniswapV2Factory} from "@uniswap/v2-core/contracts/UniswapV2Factory.sol";
// import {UniswapV2Pair} from "@uniswap/v2-core/contracts/UniswapV2Pair.sol";
// import {UniswapV2Router02} from "@v2-periphery/contracts/UniswapV2Router02.sol";
import {Token} from "../src/Token.sol";
import {Core} from "../src/Core.sol";
import {BondingCurveLibrary} from "../src/utils/BondingCurveLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IBondingCurveFactory} from "../src/interfaces/IBondingCurveFactory.sol";

contract SetUp is Test {
    MintPartyFactory public MINT_PARTY_FACTORY;
    BondingCurveFactory public BONDING_CURVE_FACTORY;
    BondingCurve public CURVE;
    WNative public WNATIVE;
    UniswapV2Factory public DEX_FACTORY;
    Lock public LOCK;
    FeeVault public FEE_VAULT;
    // MintParty public MINT_PARTY;
    Core public CORE;
    Token public MEME_TOKEN;
    UniswapV2Pair public UNISWAP_PAIR;
    UniswapV2Router public UNISWAP_ROUTER;

    uint256 constant DEPLOY_FEE = 2 * 10 ** 16;
    uint256 constant LISTING_FEE = 1 ether;
    uint256 constant VIRTUAL_NATIVE = 30 * 10 ** 18;
    uint256 constant VIRTUAL_TOKEN = 1_073_000_191 * 10 ** 18;
    uint256 constant K = VIRTUAL_NATIVE * VIRTUAL_TOKEN;
    uint256 constant TARGET_TOKEN = 206_900_000 * 10 ** 18;
    uint256 constant TOKEN_TOTAL_SUPPLY = 10 ** 27;
    uint8 constant FEE_DENOMINATOR = 10;
    uint16 constant FEE_NUMERATOR = 1000;

    //LOCK
    uint256 DEFAULT_LOCK_TIME = 48 hours;

    //MINT PARTY
    // uint256 MINT_PARTY_FUNDING_AMOUNT = 1 ether;
    // uint256 MINT_PARTY_MAXIMUM_WHITE_LIST = 4;

    address constant OWNER = address(0xa);
    address constant CREATOR = address(0xb);
    uint256 constant TRADER_PRIVATE_KEY = 0xA11CE;
    address public TRADER_A;
    address public TRADER_B;
    address public TRADER_C;
    address public TRADER_D;
    address public FEE_VAULT_OWNER_A;
    address public FEE_VAULT_OWNER_B;
    address public FEE_VAULT_OWNER_C;
    address public FEE_VAULT_OWNER_D;
    address public FEE_VAULT_OWNER_E;

    function setUp() public virtual {
        initializeTraders();

        deployContracts();

        initializeContracts();
    }

    function initializeTraders() private {
        // vm.deal(OWNER, DEPLOY_FEE);
        TRADER_A = makeAddr("TRADER_A");
        // vm.deal(TRADER_A, 10 ether);
        TRADER_B = makeAddr("TRADER_B");
        // vm.deal(TRADER_B, 10 ether);
        TRADER_C = makeAddr("TRADER_C");
        // vm.deal(TRADER_C, 10 ether);
        TRADER_D = makeAddr("TRADER_D");
        // vm.deal(TRADER_D, 10 ether);
        FEE_VAULT_OWNER_A = makeAddr("FEE_VAULT_OWNER_A");
        FEE_VAULT_OWNER_B = makeAddr("FEE_VAULT_OWNER_B");
        FEE_VAULT_OWNER_C = makeAddr("FEE_VAULT_OWNER_C");
        FEE_VAULT_OWNER_D = makeAddr("FEE_VAULT_OWNER_D");
        FEE_VAULT_OWNER_E = makeAddr("FEE_VAULT_OWNER_E");
    }

    function deployContracts() private {
        vm.startPrank(OWNER);
        WNATIVE = new WNative();

        address[] memory owners = new address[](5);
        owners[0] = FEE_VAULT_OWNER_A;
        owners[1] = FEE_VAULT_OWNER_B;
        owners[2] = FEE_VAULT_OWNER_C;
        owners[3] = FEE_VAULT_OWNER_D;
        owners[4] = FEE_VAULT_OWNER_E;

        FEE_VAULT = new FeeVault(address(WNATIVE), owners, 3);
        CORE = new Core(address(WNATIVE), address(FEE_VAULT));

        BONDING_CURVE_FACTORY = new BondingCurveFactory(OWNER, address(CORE), address(WNATIVE));

        // LOCK = new Lock(address(BONDING_CURVE_FACTORY), DEFAULT_LOCK_TIME);
        // MINT_PARTY_FACTORY = new MintPartyFactory(
        //     address(CORE),
        //     address(WNATIVE),
        //     address(LOCK),
        //     address(BONDING_CURVE_FACTORY)
        // );
        DEX_FACTORY = new UniswapV2Factory(OWNER);
        UNISWAP_ROUTER = new UniswapV2Router(address(DEX_FACTORY), address(WNATIVE));
        vm.stopPrank();
    }

    function initializeContracts() private {
        vm.startPrank(OWNER);
        CORE.initialize(address(BONDING_CURVE_FACTORY));
        IBondingCurveFactory.InitializeParams memory params = IBondingCurveFactory.InitializeParams({
            deployFee: DEPLOY_FEE,
            listingFee: LISTING_FEE,
            tokenTotalSupply: TOKEN_TOTAL_SUPPLY,
            virtualNative: VIRTUAL_NATIVE,
            virtualToken: VIRTUAL_TOKEN,
            targetToken: TARGET_TOKEN,
            feeNumerator: FEE_NUMERATOR,
            feeDenominator: FEE_DENOMINATOR,
            dexFactory: address(DEX_FACTORY)
        });
        BONDING_CURVE_FACTORY.initialize(params);

        // MINT_PARTY_FACTORY.initialize(MINT_PARTY_MAXIMUM_WHITE_LIST);

        vm.stopPrank();
    }

    function CreateBondingCurve(address account) public {
        vm.startPrank(account);
        vm.deal(account, DEPLOY_FEE);

        (address curveAddress, address tokenAddress,,,) =
            CORE.createCurve{value: DEPLOY_FEE}(account, "test", "test", "testurl", 0, 0);

        CURVE = BondingCurve(payable(curveAddress));
        MEME_TOKEN = Token(tokenAddress);
        vm.stopPrank();
    }

    function Buy(address account, uint256 amountIn) public {
        vm.startPrank(account);
        uint256 fee = amountIn / 100;
        uint256 totalAmount = amountIn + fee;
        vm.deal(account, totalAmount);

        uint256 deadline = block.timestamp + 1;

        CORE.buy{value: totalAmount}(amountIn, fee, address(MEME_TOKEN), account, deadline);
        vm.stopPrank();
    }

    function CurveListing(address account) public {
        vm.startPrank(account);
        (, uint256 realTokenReserves) = CURVE.getReserves();
        //TARGET_TOKEN 만큼 가야함. 현재 남아있는 금액에서
        //만약 1000개가 남아있는데 100개가 남을때까지 사고싶다면?
        //1000 - 100 = 900 만큼 사면됨.
        uint256 amountOut = realTokenReserves - TARGET_TOKEN;
        (uint256 virtualNative, uint256 virtualToken) = CURVE.getVirtualReserves();
        uint256 amountIn = BondingCurveLibrary.getAmountIn(amountOut, K, virtualNative, virtualToken);
        uint256 fee = amountIn / 100;
        uint256 amountInMax = amountIn + fee;
        vm.deal(account, amountInMax);

        CORE.exactOutBuy{value: amountInMax}(amountInMax, amountOut, address(MEME_TOKEN), account, block.timestamp + 1);

        UNISWAP_PAIR = UniswapV2Pair(CURVE.listing());

        assertEq(CURVE.getLock(), true);
        vm.stopPrank();
    }

    // function CreateMintParty(address account) public {
    //     vm.startPrank(account);
    //     vm.deal(account, MINT_PARTY_FUNDING_AMOUNT);

    //     MINT_PARTY = MintParty(
    //         MINT_PARTY_FACTORY.create{value: MINT_PARTY_FUNDING_AMOUNT}(
    //             account,
    //             "TEST",
    //             "TEST",
    //             "TEST",
    //             MINT_PARTY_FUNDING_AMOUNT,
    //             uint8(MINT_PARTY_MAXIMUM_WHITE_LIST)
    //         )
    //     );
    //     vm.stopPrank();
    // }
}
