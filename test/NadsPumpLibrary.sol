// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "src/utils/NadsPumpLibrary.sol";
import "src/errors/Errors.sol";

contract NadsPumpLibraryTest is Test {
    function testGetAmountOut() public {
        // uint256 virtualNad = 30 * (10 ** 18);
        // uint256 virtualToken = 1073000191 * (10 ** 18);
        // uint256 amountIn = 85 * (10 ** 18);
        // uint256 k = virtualNad * virtualToken;
        // uint256 amountOut = NadsPumpLibrary.getAmountOut(k, amountIn, virtualNad, virtualToken);
        // console.log("amountOut = ", returnAmount); //357547547817394201932690

        uint256 amountIn = 100;
        uint256 reserveIn = 100;
        uint256 reserveOut = 100000;
        uint256 k = reserveIn * reserveOut;
        // //reserveOut - (k / (reserveIn + amountIn));
        // 100000 - ((100000 * 100) / (100 + 100)) - 1
        uint256 amountOut = NadsPumpLibrary.getAmountOut(k, amountIn, reserveIn, reserveOut);
        assertEq(amountOut, 49999);
        // uint256 newK = (amountIn + reserveIn) * (reserveOut - amountOut);

        // require(k <= newK, ERR_INVALID_K);
    }

    function testGetAmountIn() public {
        // uint256 amountOut = 49999;
        uint256 amountOut = 50000;
        uint256 reserveIn = 100;
        uint256 reserveOut = 100000;
        uint256 k = reserveIn * reserveOut;
        uint256 amountIn = NadsPumpLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
        assertEq(amountIn, 101);
    }
}
