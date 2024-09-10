// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {QuestPool} from "src/QuestPool.sol";
import {WNAD} from "src/WNAD.sol";
import {BondingCurveFactory} from "src/BondingCurveFactory.sol";
import {Endpoint} from "src/Endpoint.sol";
import {FeeVault} from "src/FeeVault.sol";
import {UniswapV2Factory} from "src/uniswap/UniswapV2Factory.sol";
import {Token} from "src/Token.sol";
import {BondingCurve} from "src/BondingCurve.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IWNAD} from "src/interfaces/IWNAD.sol";
import {QuestPoolFactory} from "src/QuestPoolFactory.sol";
import {QuestPool} from "src/QuestPool.sol";
import "./Constant.sol";

contract QuestPoolTest is Test, TestConstants {
    BondingCurve curve;
    Token token;
    BondingCurveFactory factory;
    WNAD wNad;
    Endpoint endpoint;
    FeeVault vault;
    UniswapV2Factory uniFactory;
    QuestPoolFactory questFactory;
    QuestPool questPool;
    address trader;
    uint256 CREATE_FEE = 0.1 ether;
    uint256 MINIMUM_REWARD = 20_000_000 ether;
    uint256 DEFAULT_CLAIM_TIMESTAMP = 1 hours;

    function setUp() public {
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

        vault = new FeeVault(wNad);
        endpoint = new Endpoint(address(factory), address(wNad), address(vault));

        factory.setEndpoint(address(endpoint));
        questFactory = new QuestPoolFactory(OWNER, address(vault), address(wNad), address(factory));
        questFactory.initialize(CREATE_FEE, MINIMUM_REWARD, DEFAULT_CLAIM_TIMESTAMP);
        vm.stopPrank();

        vm.deal(CREATOR, DEPLOY_FEE);

        vm.startPrank(CREATOR);
        (address curveAddress, address tokenAddress,,,) =
            endpoint.createCurve{value: DEPLOY_FEE}("test", "test", "testurl", 0, 0, DEPLOY_FEE);
        curve = BondingCurve(curveAddress);
        token = Token(tokenAddress);
        vm.stopPrank();

        trader = vm.addr(TRADER_PRIVATE_KEY);

        uint256 amountIn = endpoint.getAmountIn(MINIMUM_REWARD, K, VIRTUAL_NAD, VIRTUAL_TOKEN);
        uint256 fee = amountIn / 100;
        vm.deal(CREATOR, amountIn + fee);
        uint256 deadline = block.timestamp + 1;
        endpoint.buy{value: amountIn + fee}(amountIn, fee, address(token), CREATOR, deadline);

        vm.startPrank(CREATOR);
        IWNAD(wNad).deposit{value: CREATE_FEE}();
        IERC20(wNad).transfer(address(questFactory), CREATE_FEE);
        IERC20(token).transfer(address(questFactory), MINIMUM_REWARD);
        questPool = QuestPool(questFactory.create(CREATOR, address(token)));
        vm.stopPrank();
    }

    function testAdd() public {
        vm.startPrank(trader);

        vm.stopPrank();
    }
}
