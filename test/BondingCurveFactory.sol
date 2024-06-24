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

contract BondingCurveFactoryTest is Test {
    Token token;
    BondingCurveFactory factory;
    BondingCurve curve;
    WNAD wNad;
    Endpoint endpoint;
    address owner;
    address creator;
    uint256 deployFee = 2 * 10 ** 16;
    uint256 tokenTotalSupply = 10 ** 27;
    uint256 virtualBase = 30 * 10 ** 18;
    uint256 virtualToken = 1073000191 * 10 ** 18;
    uint256 targetToken = 206900000 * 10 ** 18;
    uint8 feeDominator = 10;
    uint16 feeNumerator = 1000;

    function setUp() public {
        owner = address(0xa);
        creator = address(0xb);
        vm.startPrank(owner);

        wNad = new WNAD();
        factory = new BondingCurveFactory(owner, address(wNad));

        factory.initialize(
            deployFee, tokenTotalSupply, virtualBase, virtualToken, targetToken, feeNumerator, feeDominator
        );
        endpoint = new Endpoint(address(factory), address(wNad));
        factory.setEndpoint(address(endpoint));
        vm.stopPrank();
    }

    function testCreate() public {
        // Start Create
        vm.startPrank(creator);
        vm.deal(creator, 0.02 ether);
        // createCurve 함수 호출
        (address curveAddress, address tokenAddress) = factory.create{value: 0.02 ether}("test", "test");
        curve = BondingCurve(curveAddress);
        token = Token(tokenAddress);

        assertEq(owner.balance, deployFee);
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
        assertEq(config.feeDominator, feeDominator);
        assertEq(config.feeNumerator, feeNumerator);
        assertEq(config.k, virtualBase * virtualToken);
        assertEq(config.targetToken, targetToken);
        assertEq(config.tokenTotalSupply, tokenTotalSupply);
        assertEq(config.virtualNad, virtualBase);
        assertEq(config.virtualToken, virtualToken);
    }

    function testGetCurve() public {
        address tokenCurve = factory.getCurve(address(token));
        assertEq(tokenCurve, address(curve));
    }
}