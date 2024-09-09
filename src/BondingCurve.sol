// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IUniswapV2Factory} from "./uniswap/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "./uniswap/interfaces/IUniswapV2Pair.sol";
import {IEndpoint} from "./interfaces/IEndpoint.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";

import {TransferHelper} from "./utils/TransferHelper.sol";
import "./errors/Errors.sol";
import {Test, console} from "forge-std/Test.sol";

contract BondingCurve is IBondingCurve {
    using TransferHelper for IERC20;

    address public factory;

    address public wnad;
    address public token;

    uint256 private virtualNad;
    uint256 private virtualToken;
    uint256 private k;
    uint256 private targetToken;
    Fee feeConfig;

    struct Fee {
        uint8 denominator;
        uint16 numerator;
    }

    uint256 realNadReserves;
    uint256 realTokenReserves;

    bool public lock;
    bool public isListing;

    modifier islock() {
        require(!lock, ERR_LOCK);
        _;
    }

    modifier onlyEndpoint() {
        require(msg.sender == IBondingCurveFactory(factory).getEndpoint(), ERR_ONLY_ENDPOINT);
        _;
    }

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(
        address _wnad,
        address _token,
        uint256 _virtualNad,
        uint256 _virtualToken,
        uint256 _k,
        uint256 _targetToken,
        uint8 _feeDenominator,
        uint16 _feeNumerator
    ) external {
        require(msg.sender == factory, ERR_ONLY_FACTORY); // sufficient check
        wnad = _wnad;
        token = _token;
        virtualNad = _virtualNad;
        virtualToken = _virtualToken;
        k = _k;
        realNadReserves = IERC20(_wnad).balanceOf(address(this));
        realTokenReserves = IERC20(_token).balanceOf(address(this));
        //this is
        targetToken = _targetToken;
        feeConfig = Fee(_feeDenominator, _feeNumerator);
        isListing = false;
    }

    // this low-level function should be called from a contract which performs important safety checks

    function buy(address to, uint256 amountOut) external islock onlyEndpoint {
        require(amountOut > 0, ERR_INVALID_AMOUNT_OUT);
        address _wnad = wnad; //gas savings
        address _token = token; //gas savings

        (uint256 _realNadReserves, uint256 _realTokenReserves) = getReserves();

        //100 - 50 <= 50
        require(_realTokenReserves - amountOut >= targetToken, ERR_OVERFLOW_TARGET);

        //Current balance of the curve
        uint256 balanceNad;

        {
            require(to != _wnad && to != _token, ERR_INVALID_TO);
            IERC20(_token).safeTransferERC20(to, amountOut);

            balanceNad = IERC20(wnad).balanceOf(address(this));
        }

        uint256 amountNadIn = balanceNad - _realNadReserves;
        require(amountNadIn > 0, INSUFFICIENT_INPUT_AMOUNT);

        _update(amountNadIn, amountOut, true);

        require(virtualNad * virtualToken >= k, ERR_INVALID_K);
    }

    //fee = 1% * amountOut
    function sell(address to, uint256 amountOut) external islock onlyEndpoint {
        require(amountOut > 0, ERR_INVALID_AMOUNT_OUT);

        address _wnad = wnad; //gas savings
        address _token = token; //gas savings
        (uint256 _realNadReserves, uint256 _realTokenReserves) = getReserves();
        require(amountOut <= _realNadReserves, ERR_INSUFFICIENT_RESERVE);

        //유저가 보낸 현재 잔액
        uint256 balanceToken;

        {
            require(to != _wnad && to != _token, ERR_INVALID_TO);

            IERC20(_wnad).safeTransferERC20(to, amountOut);

            balanceToken = IERC20(_token).balanceOf(address(this));
        }

        uint256 amountTokenIn = balanceToken - _realTokenReserves;

        require(amountTokenIn > 0, INSUFFICIENT_INPUT_AMOUNT);

        _update(amountTokenIn, amountOut, false);
        require(virtualNad * virtualToken >= k, ERR_INVALID_K);
    }

    function listing() external returns (address pair) {
        require(lock == true, ERR_LISTING_ONLY_LOCK);
        IBondingCurveFactory _factory = IBondingCurveFactory(factory);
        pair = IUniswapV2Factory(_factory.getDexFactory()).createPair(wnad, token);
        //dexlisting fee -> fee vault
        IERC20(wnad).transfer(IEndpoint(_factory.getEndpoint()).getFeeVault(), _factory.getListingFee());

        //rest token amount -> pair

        uint256 listingWNadAmount = IERC20(wnad).balanceOf(address(this));
        IERC20(wnad).transfer(pair, listingWNadAmount);
        //rest token amount -> pair
        uint256 listingTokenAmount = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(pair, listingTokenAmount);
        realNadReserves = 0;
        realTokenReserves = 0;
        uint256 liquidity = IUniswapV2Pair(pair).mint(address(this));

        IERC20(pair).transfer(address(0), liquidity);
        isListing = true;
        emit Listing(address(this), token, pair, listingWNadAmount, listingTokenAmount, liquidity);
    }

    function _update(uint256 amountIn, uint256 amountOut, bool isBuy) private {
        realNadReserves = IERC20(wnad).balanceOf(address(this));

        realTokenReserves = IERC20(token).balanceOf(address(this));

        if (isBuy) {
            virtualNad += amountIn;

            virtualToken -= amountOut;
        } else {
            virtualNad -= amountOut;
            virtualToken += amountIn;
        }

        if (realTokenReserves == getTargetToken()) {
            lock = true;
            emit Lock(address(this));
        }

        emit Sync(realNadReserves, realTokenReserves, virtualNad, virtualToken);
    }

    function getReserves() public view override returns (uint256 _realNadReserves, uint256 _realTokenReserves) {
        _realNadReserves = realNadReserves;
        _realTokenReserves = realTokenReserves;
    }

    function getVirtualReserves() public view override returns (uint256 _virtualNad, uint256 _virtualToken) {
        _virtualNad = virtualNad;
        _virtualToken = virtualToken;
    }

    function getFee() public view returns (uint8 denominator, uint16 numerator) {
        Fee memory fee = feeConfig;
        denominator = fee.denominator;
        numerator = fee.numerator;
    }

    function getFeeConfig() external view returns (uint8 denominator, uint16 numerator) {
        Fee memory fee = feeConfig;
        denominator = fee.denominator;
        numerator = fee.numerator;
    }

    function getK() external view override returns (uint256) {
        return k;
    }

    function getTargetToken() public view returns (uint256) {
        return targetToken;
    }

    function getLock() public view returns (bool) {
        return lock;
    }

    function getIsListing() public view returns (bool) {
        return isListing;
    }
}
