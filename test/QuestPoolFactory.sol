// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {QuestPoolFactory} from "src/QuestPoolFactory.sol";
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
import "./Constant.sol";
import "src/errors/Errors.sol";

contract QuestFactoryTest is Test, TestConstants {
    BondingCurve curve;
    Token token;
    BondingCurveFactory factory;
    WNAD wNad;
    Endpoint endpoint;
    FeeVault vault;
    UniswapV2Factory uniFactory;
    QuestPoolFactory questFactory;

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
        vm.stopPrank();

        vm.deal(CREATOR, DEPLOY_FEE);

        vm.startPrank(CREATOR);
        (address curveAddress, address tokenAddress,,,) =
            endpoint.createCurve{value: DEPLOY_FEE}("test", "test", "testurl", 0, 0, DEPLOY_FEE);
        curve = BondingCurve(curveAddress);
        token = Token(tokenAddress);
        vm.stopPrank();
        vm.startPrank(OWNER);
        questFactory = new QuestPoolFactory(OWNER, address(vault), address(wNad), address(factory));
        questFactory.initialize(CREATE_FEE, MINIMUM_REWARD, DEFAULT_CLAIM_TIMESTAMP);
        vm.stopPrank();
    }

    function testBuy() public {
        vm.startPrank(CREATOR);
        uint256 amountIn = endpoint.getAmountIn(MINIMUM_REWARD, K, VIRTUAL_NAD, VIRTUAL_TOKEN);
        uint256 fee = amountIn / 100;
        vm.deal(CREATOR, amountIn + fee);
        uint256 deadline = block.timestamp + 1;
        endpoint.buy{value: amountIn + fee}(amountIn, fee, address(token), CREATOR, deadline);
        vm.stopPrank();
    }

    function testCreateQuestPool() public {
        testBuy();
        vm.startPrank(CREATOR);

        vm.deal(CREATOR, CREATE_FEE);
        IWNAD(wNad).deposit{value: CREATE_FEE}();
        IERC20(wNad).transfer(address(questFactory), CREATE_FEE);
        IERC20(token).transfer(address(questFactory), MINIMUM_REWARD);
        questFactory.create(CREATOR, address(token));
        vm.stopPrank();
    }
    // Test creation of quest pool with insufficient create fee

    function testCreateQuestPoolInsufficientFee() public {
        testBuy();
        vm.startPrank(CREATOR);
        uint256 insufficientFee = CREATE_FEE - 0.01 ether;
        vm.deal(CREATOR, insufficientFee);
        IWNAD(wNad).deposit{value: insufficientFee}();
        IERC20(wNad).transfer(address(questFactory), insufficientFee);
        IERC20(token).transfer(address(questFactory), MINIMUM_REWARD);

        vm.expectRevert(bytes(ERR_INVALID_CREATE_FEE));
        questFactory.create(CREATOR, address(token));
        vm.stopPrank();
    }

    // Test creation of quest pool with insufficient reward
    function testCreateQuestPoolInsufficientReward() public {
        testBuy();
        vm.startPrank(CREATOR);
        uint256 insufficientReward = MINIMUM_REWARD - 1 ether;
        vm.deal(CREATOR, CREATE_FEE);
        IWNAD(wNad).deposit{value: CREATE_FEE}();
        IERC20(wNad).transfer(address(questFactory), CREATE_FEE);
        IERC20(token).transfer(address(questFactory), insufficientReward);

        vm.expectRevert(bytes(ERR_INVALID_MINIMUM_REWARD));
        questFactory.create(CREATOR, address(token));
        vm.stopPrank();
    }

    // Test creation of quest pool with invalid token
    function testCreateQuestPoolInvalidToken() public {
        vm.startPrank(CREATOR);
        address invalidToken = address(0x1234);
        vm.deal(CREATOR, CREATE_FEE);
        IWNAD(wNad).deposit{value: CREATE_FEE}();
        IERC20(wNad).transfer(address(questFactory), CREATE_FEE);

        vm.expectRevert(bytes(ERR_INVALID_TOKEN));
        questFactory.create(CREATOR, invalidToken);
        vm.stopPrank();
    }

    // Test initialization of QuestPoolFactory
    function testInitialize() public {
        vm.startPrank(OWNER);
        uint256 newCreateFee = 0.2 ether;
        uint256 newMinimumReward = 30_000_000 ether;
        uint256 newDefaultClaimTimestamp = 2 hours;

        questFactory.initialize(newCreateFee, newMinimumReward, newDefaultClaimTimestamp);

        QuestPoolFactory.Config memory config = questFactory.getConfig();
        assertEq(config.createFee, newCreateFee, "Create fee should be updated");
        assertEq(config.minimumReward, newMinimumReward, "Minimum reward should be updated");
        assertEq(config.defaultClaimTimestamp, newDefaultClaimTimestamp, "Default claim timestamp should be updated");
        vm.stopPrank();
    }

    // Test that only owner can initialize QuestPoolFactory
    function testInitializeOnlyOwner() public {
        vm.startPrank(CREATOR);
        vm.expectRevert(bytes(ERR_ONLY_OWNER));
        questFactory.initialize(0.2 ether, 30_000_000 ether, 2 hours);
        vm.stopPrank();
    }

    // Test setting a new owner
    function testSetOwner() public {
        address newOwner = address(0x1234);
        vm.prank(OWNER);
        questFactory.setOwner(newOwner);

        vm.prank(newOwner);
        questFactory.initialize(0.2 ether, 30_000_000 ether, 2 hours);
    }

    // Test that only owner can set a new owner
    function testSetOwnerOnlyOwner() public {
        address newOwner = address(0x1234);
        vm.prank(CREATOR);
        vm.expectRevert(bytes(ERR_ONLY_OWNER));
        questFactory.setOwner(newOwner);
    }

    // Test setting a new vault
    function testSetVault() public {
        testBuy();
        address newVault = address(0x5678);
        vm.prank(OWNER);
        questFactory.setVault(newVault);

        // Verify the new vault is being used
        vm.startPrank(CREATOR);
        vm.deal(CREATOR, CREATE_FEE);
        IWNAD(wNad).deposit{value: CREATE_FEE}();
        IERC20(wNad).transfer(address(questFactory), CREATE_FEE);
        IERC20(token).transfer(address(questFactory), MINIMUM_REWARD);
        questFactory.create(CREATOR, address(token));
        vm.stopPrank();

        assertEq(IERC20(wNad).balanceOf(newVault), CREATE_FEE, "New vault should receive the create fee");
    }

    // Test that only owner can set a new vault
    function testSetVaultOnlyOwner() public {
        address newVault = address(0x5678);
        vm.prank(CREATOR);
        vm.expectRevert(bytes(ERR_ONLY_OWNER));
        questFactory.setVault(newVault);
    }
}
