// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MintPartyFactory} from "../src/mint_party/MintPartyFactory.sol";
import {MintParty} from "../src/mint_party/MintParty.sol";
import {BondingCurveFactory} from "../src/curve/BondingCurveFactory.sol";
import {BondingCurve} from "../src/curve/BondingCurve.sol";
import {WNAD} from "../src/wnad/WNAD.sol";
import {Vault} from "../src/vault/Vault.sol";
import {Lock} from "../src/lock/Lock.sol";
import {UniswapV2Factory} from "../src/dex/UniswapV2Factory.sol";

import {Token} from "../src/token/Token.sol";
import {QuestPoolFactory} from "../src/quest_pool/QuestPoolFactory.sol";
import {QuestPool} from "../src/quest_pool/QuestPool.sol";
import {NadsPumpLibrary} from "../src/utils/NadsPumpLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract SetUp is Test {
    MintPartyFactory public MINT_PARTY_FACTORY;
    BondingCurveFactory public BONDING_CURVE_FACTORY;
    BondingCurve public CURVE;
    WNAD public wNAD;
    UniswapV2Factory public DEX_FACTORY;
    Lock public LOCK;
    Vault public VAULT;
    MintParty public MINT_PARTY;

    QuestPoolFactory public QUEST_POOL_FACTORY;

    Token public MEME_TOKEN;
    uint256 constant DEPLOY_FEE = 2 * 10 ** 16;
    uint256 constant LISTING_FEE = 1 ether;
    uint256 constant VIRTUAL_NAD = 30 * 10 ** 18;
    uint256 constant VIRTUAL_TOKEN = 1_073_000_191 * 10 ** 18;
    uint256 constant K = VIRTUAL_NAD * VIRTUAL_TOKEN;
    uint256 constant TARGET_TOKEN = 206_900_000 * 10 ** 18;
    uint256 constant TOKEN_TOTAL_SUPPLY = 10 ** 27;
    uint8 constant FEE_DENOMINATOR = 10;
    uint16 constant FEE_NUMERATOR = 1000;

    //QUEST POOL
    uint256 QUEST_POOL_CREATE_FEE = 2 * 10 ** 16;
    uint256 QUEST_POOL_MINIMUM_REWARD = 10000000 * 1 ether;
    uint256 QUEST_POOL_DEFAULT_CLAIM_TIMESTAMP = 1 hours;

    //LOCK
    uint256 DEFAULT_LOCK_TIME = 48 hours;

    //MINT PARTY
    uint256 MINT_PARTY_FUNDING_AMOUNT = 1 ether;
    uint256 MINT_PARTY_MAXIMUM_PARTICIPANTS = 4;

    address constant OWNER = address(0xa);
    address constant CREATOR = address(0xb);
    uint256 constant TRADER_PRIVATE_KEY = 0xA11CE;
    address public TRADER_A;
    address public TRADER_B;
    address public TRADER_C;
    address public TRADER_D;

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
    }

    function deployContracts() private {
        vm.startPrank(OWNER);
        wNAD = new WNAD();
        VAULT = new Vault(IERC20(address(wNAD)));

        BONDING_CURVE_FACTORY = new BondingCurveFactory();
        MINT_PARTY_FACTORY = new MintPartyFactory();
        LOCK = new Lock();
        DEX_FACTORY = new UniswapV2Factory(OWNER);
        QUEST_POOL_FACTORY = new QuestPoolFactory();

        vm.stopPrank();
    }

    function initializeContracts() private {
        vm.startPrank(OWNER);

        BondingCurveFactory.InitializeParams memory params = BondingCurveFactory.InitializeParams({
            deployFee: DEPLOY_FEE,
            listingFee: LISTING_FEE,
            tokenTotalSupply: TOKEN_TOTAL_SUPPLY,
            virtualNad: VIRTUAL_NAD,
            virtualToken: VIRTUAL_TOKEN,
            targetToken: TARGET_TOKEN,
            feeNumerator: FEE_NUMERATOR,
            feeDenominator: FEE_DENOMINATOR,
            dexFactory: address(DEX_FACTORY),
            vault: address(VAULT),
            wnad: address(wNAD)
        });
        BONDING_CURVE_FACTORY.initialize(params);

        MINT_PARTY_FACTORY.initialize(address(BONDING_CURVE_FACTORY), address(wNAD), address(LOCK), address(VAULT));

        LOCK.initialize(address(BONDING_CURVE_FACTORY), DEFAULT_LOCK_TIME);

        QUEST_POOL_FACTORY.initialize(
            address(VAULT),
            address(BONDING_CURVE_FACTORY),
            address(wNAD),
            QUEST_POOL_CREATE_FEE,
            QUEST_POOL_MINIMUM_REWARD,
            QUEST_POOL_DEFAULT_CLAIM_TIMESTAMP
        );

        vm.stopPrank();
        CurveCreate(CREATOR);
    }

    function CurveCreate(address account) public {
        vm.startPrank(account);
        vm.deal(account, DEPLOY_FEE);

        wNAD.deposit{value: DEPLOY_FEE}();

        wNAD.transfer(address(BONDING_CURVE_FACTORY), DEPLOY_FEE);

        (address curveAddress, address tokenAddress,,) = BONDING_CURVE_FACTORY.create("test", "test", "testurl");

        CURVE = BondingCurve(curveAddress);

        MEME_TOKEN = Token(tokenAddress);
        vm.stopPrank();
    }

    function Buy(address account, uint256 amountIn) public {
        vm.startPrank(account);
        uint256 fee = amountIn / 100;
        uint256 totalAmount = amountIn + fee;
        vm.deal(account, totalAmount);
        wNAD.deposit{value: totalAmount}();
        wNAD.transfer(address(CURVE), totalAmount);
        CURVE.buy(account, amountIn, fee);
        vm.stopPrank();
    }

    function BuyAmountOut(address account, uint256 amountOut) public {
        vm.startPrank(account);
        (uint256 virtualNad, uint256 virtualToken) = CURVE.getVirtualReserves();
        uint256 amountIn = NadsPumpLibrary.getAmountIn(amountOut, K, virtualNad, virtualToken);
        uint256 fee = amountIn / 100;
        uint256 totalAmount = amountIn + fee;

        vm.deal(account, totalAmount);
        wNAD.deposit{value: totalAmount}();
        wNAD.transfer(address(CURVE), totalAmount);
        CURVE.buy(account, amountOut, fee);
        vm.stopPrank();
    }

    function CurveListing(address account) public {
        vm.startPrank(account);
        (, uint256 realTokenReserves) = CURVE.getReserves();
        //TARGET_TOKEN 만큼 가야함. 현재 남아있는 금액에서
        //만약 1000개가 남아있는데 100개가 남을때까지 사고싶다면?
        //1000 - 100 = 900 만큼 사면됨.
        uint256 targetAmount = realTokenReserves - TARGET_TOKEN;
        (uint256 virtualNad, uint256 virtualToken) = CURVE.getVirtualReserves();
        uint256 amountIn = NadsPumpLibrary.getAmountIn(targetAmount, K, virtualNad, virtualToken);
        uint256 fee = amountIn / 100;
        uint256 totalAmount = amountIn + fee;
        vm.deal(account, totalAmount);
        wNAD.deposit{value: totalAmount}();
        wNAD.transfer(address(CURVE), totalAmount);
        CURVE.buy(account, targetAmount, fee);

        CURVE.listing();
        assertEq(CURVE.getLock(), true);
        vm.stopPrank();
    }

    function CreateMintParty(address account) public {
        vm.startPrank(account);
        vm.deal(account, MINT_PARTY_FUNDING_AMOUNT);
        // wNAD.deposit{value: MINT_PARTY_FUNDING_AMOUNT}();
        // wNAD.transfer(address(MINT_PARTY_FACTORY), MINT_PARTY_FUNDING_AMOUNT);
        MINT_PARTY = MintParty(
            MINT_PARTY_FACTORY.create{value: MINT_PARTY_FUNDING_AMOUNT}(
                account, "TEST", "TEST", "TEST", MINT_PARTY_FUNDING_AMOUNT, MINT_PARTY_MAXIMUM_PARTICIPANTS
            )
        );
    }

    // function CreateQuestPool(address account) public {
    //     CurveCreate(account);
    //     BuyAmountOut(account, QUEST_POOL_MINIMUM_REWARD);
    // }
}
