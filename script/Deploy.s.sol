// EndpointDeployment.s.sol
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {BondingCurveFactory} from "../src/BondingCurveFactory.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {Token} from "../src/Token.sol";
import {WNAD} from "../src/WNAD.sol";
import {Endpoint} from "../src/Endpoint.sol";
import {Test, console} from "forge-std/Test.sol";

contract EndpointDeploymentScript is Script {
    // 변수 정의
    // address public owner = address(0xa);
    address public creator = address(0xb);
    uint256 public deployFee = 2 * 10 ** 14; //TODO : 2 * 10 ** 16
    uint256 public virtualNad = 30 * 10 ** 18;
    uint256 public virtualToken = 1_073_000_191 * 10 ** 18;
    uint256 public k = virtualNad * virtualToken;
    uint256 public targetToken = 206_900_000 * 10 ** 18;
    uint256 public tokenTotalSupply = 10 ** 27;
    uint8 public feeDenominator = 10;
    uint16 public feeNumerator = 1000;

    function run() external {
        // 스크립트 실행 전 브로드캐스트 시작
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        // vm.startPrank(owner);
        // 1. WNAD 배포
        WNAD wNad = new WNAD();

        // 2. BondingCurveFactory 배포 및 초기화
        BondingCurveFactory factory = new BondingCurveFactory(owner, address(wNad));
        factory.initialize(
            deployFee, tokenTotalSupply, virtualNad, virtualToken, targetToken, feeNumerator, feeDenominator
        );

        // 3. Endpoint 배포
        Endpoint endpoint = new Endpoint(address(factory), address(wNad));
        factory.setEndpoint(address(endpoint));

        // // 4. creator에 자금 할당 및 새로운 Curve와 Token 생성
        // vm.deal(creator, 0.02 ether);
        // vm.startPrank(creator);
        // (address curveAddress, address tokenAddress) = factory.create{value: 0.02 ether}("test", "test");

        // 스크립트 실행 후 브로드캐스트 종료
        vm.stopBroadcast();

        // 결과 로그 출력
        console.log("WNAD :", address(wNad));
        console.log("BondingCurveFactory :", address(factory));
        console.log("Endpoint :", address(endpoint));
        // console.log("BondingCurve deployed at:", curveAddress);
        // console.log("Token deployed at:", tokenAddress);
    }
}
