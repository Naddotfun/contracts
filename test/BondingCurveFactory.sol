// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "src/BondingCurve.sol";
import "src/BondingCurveFactory.sol";
import "src/Token.sol";
import "src/errors/Errors.sol";
import "src/WNAD.sol";
import "src/utils/NadsPumpLibrary.sol";
import "src/Endpoint.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {FeeVault} from "src/FeeVault.sol";
import {UniswapV2Factory} from "src/uniswap/UniswapV2Factory.sol";
import "./Constant.sol";

contract BondingCurveFactoryTest is Test {
    Token token;
    BondingCurveFactory factory;
    BondingCurve curve;
    WNAD wNad;
    Endpoint endpoint;
    IERC4626 vault;
    UniswapV2Factory uniFactory;
    address owner;
    address creator;

    uint256 deployFee = 2 * 10 ** 16;
    uint256 listingFee = 1 ether;
    uint256 tokenTotalSupply = 10 ** 27;
    uint256 virtualNad = 30 * 10 ** 18;
    uint256 virtualToken = 1073000191 * 10 ** 18;
    uint256 targetToken = 206900000 * 10 ** 18;
    uint8 feeDenominator = 10;
    uint16 feeNumerator = 1000;

    function setUp() public {
        owner = address(0xa);
        creator = address(0xb);
        vm.startPrank(owner);

        wNad = new WNAD();
        vault = new FeeVault(wNad);
        factory = new BondingCurveFactory(owner, address(wNad));

        factory.initialize(
            deployFee,
            listingFee,
            tokenTotalSupply,
            virtualNad,
            virtualToken,
            targetToken,
            feeNumerator,
            feeDenominator,
            address(uniFactory)
        );

        endpoint = new Endpoint(address(factory), address(wNad), address(vault));
        factory.setEndpoint(address(endpoint));
        vm.stopPrank();
    }

    function testCreate() public {
        // Start Create
        vm.startPrank(creator);
        vm.deal(creator, 0.02 ether);

        (address curveAddress, address tokenAddress, uint256 virtualNad, uint256 virtualToken, uint256 amountOut) =
            endpoint.createCurve{value: 0.02 ether}("test", "test", "testurl", 0, 0, 0.02 ether);
        curve = BondingCurve(curveAddress);
        token = Token(tokenAddress);

        assertEq(IERC4626(vault).totalAssets(), deployFee);
        assertEq(creator.balance, 0);
        // creator로의 프랭크 종료
        vm.stopPrank();
    }

    function testSetOwner() public {
        vm.startPrank(owner);
        factory.setOwner(creator);
        assertEq(factory.getOwner(), creator);
        vm.stopPrank();
    }

    function testSetEndpoint() public {
        vm.startPrank(owner);
        factory.setEndpoint(creator);
        assertEq(factory.getEndpoint(), creator);
        vm.stopPrank();
    }

    function testGetConfig() public {
        BondingCurveFactory.Config memory config = factory.getConfig();
        assertEq(config.deployFee, deployFee);
        assertEq(config.feeDenominator, feeDenominator);
        assertEq(config.feeNumerator, feeNumerator);
        assertEq(config.k, virtualNad * virtualToken);
        assertEq(config.targetToken, targetToken);
        assertEq(config.tokenTotalSupply, tokenTotalSupply);
        assertEq(config.virtualNad, virtualNad);
        assertEq(config.virtualToken, virtualToken);
    }

    function testGetCurve() public {
        address tokenCurve = factory.getCurve(address(token));
        assertEq(tokenCurve, address(curve));
    }
}
