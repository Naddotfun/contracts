// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {MintPartyRouter} from "../../src/router/MintPartyRouter.sol";
import {MintPartyFactory} from "../../src/mint_party/MintPartyFactory.sol";
import {MintParty} from "../../src/mint_party/MintParty.sol";
import {Test, console2} from "forge-std/Test.sol";
import {SetUp} from "../SetUp.sol";

contract MintPartyRouterTest is Test, SetUp {
    MintPartyRouter public MINT_PARTY_ROUTER;

    function setUp() public override {
        super.setUp();
        MINT_PARTY_ROUTER = new MintPartyRouter(address(MINT_PARTY_FACTORY), address(wNAD));
    }

    function testCreateMintParty() public {
        vm.deal(CREATOR, MINT_PARTY_FUNDING_AMOUNT);
        vm.startPrank(CREATOR);
        MINT_PARTY_ROUTER.create{value: MINT_PARTY_FUNDING_AMOUNT}(
            CREATOR, "TEST", "TEST", "TEST", MINT_PARTY_FUNDING_AMOUNT, 4
        );
        MintParty mintParty = MintParty(payable(MINT_PARTY_FACTORY.getParty(CREATOR)));
        assertNotEq(address(mintParty), address(0));

        assertEq(mintParty.getBalance(CREATOR), MINT_PARTY_FUNDING_AMOUNT);
        assertEq(mintParty.getConfig().maximumParticipants, 4);
        assertEq(mintParty.getConfig().name, "TEST");
        assertEq(mintParty.getConfig().symbol, "TEST");
        assertEq(mintParty.getConfig().tokenURI, "TEST");
    }

    function testDeposit() public {
        CreateMintParty(CREATOR);

        vm.deal(TRADER_A, 1 ether);
        vm.startPrank(TRADER_A);
        MINT_PARTY_ROUTER.deposit{value: 1 ether}(TRADER_A, address(MINT_PARTY), 1 ether);
        vm.stopPrank();
        assertEq(MintParty(payable(MINT_PARTY)).getBalance(TRADER_A), 1 ether);
    }
}
