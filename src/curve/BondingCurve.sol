// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IUniswapV2Factory} from "../dex/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "../dex/interfaces/IUniswapV2Pair.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import {IVault} from "../vault/interfaces/IVault.sol";
import {TransferHelper} from "../utils/TransferHelper.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./errors/Error.sol";

contract BondingCurve is IBondingCurve, ReentrancyGuard {
    //nonReentrant 설정해놓기
    using TransferHelper for IERC20;

    address public factory;

    address immutable wnad;
    address immutable token;

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
        require(!lock, ERR_CURVE_IS_LOCKED);
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, ERR_ONLY_FACTORY);
        _;
    }

    constructor(address _wnad, address _token) {
        factory = msg.sender;
        wnad = _wnad;
        token = _token;
    }

    // called once by the factory at time of deployment
    function initialize(
        uint256 _virtualNad,
        uint256 _virtualToken,
        uint256 _k,
        uint256 _targetToken,
        uint8 _feeDenominator,
        uint16 _feeNumerator
    ) external onlyFactory {
        require(msg.sender == factory, ERR_ONLY_FACTORY); // sufficient check
        virtualNad = _virtualNad;
        virtualToken = _virtualToken;
        k = _k;
        realNadReserves = IERC20(wnad).balanceOf(address(this));
        realTokenReserves = IERC20(token).balanceOf(address(this));
        //this is
        targetToken = _targetToken;
        feeConfig = Fee(_feeDenominator, _feeNumerator);
        isListing = false;
    }

    //TODO :pointToken mint 해줘야함.
    function buy(address to, uint256 amountOut, uint256 fee) external islock nonReentrant {
        require(amountOut > 0, ERR_INVALID_AMOUNT_OUT);
        require(to != wnad && to != token, ERR_INVALID_TO);
        require(fee > 0, ERR_INVALID_FEE);
        (uint256 _realNadReserves, uint256 _realTokenReserves) = getReserves();
        require(_realTokenReserves - amountOut >= targetToken, ERR_OVERFLOW_TARGET);

        //send fee to vault
        {
            address vault = IBondingCurveFactory(factory).getVault();
            IERC20(wnad).safeTransferERC20(vault, fee);
        }

        //Current balance of the curve
        uint256 balanceNad;

        {
            require(to != wnad && to != token, ERR_INVALID_TO);
            IERC20(token).safeTransferERC20(to, amountOut);
            balanceNad = IERC20(wnad).balanceOf(address(this));
        }

        uint256 amountNadIn = balanceNad - _realNadReserves;
        require(amountNadIn > 0, ERR_INSUFFICIENT_INPUT_AMOUNT);

        require(amountNadIn * feeConfig.denominator / feeConfig.numerator == fee, ERR_INVALID_FEE);

        _update(amountNadIn, amountOut, true);

        emit Buy(to, token, amountNadIn, amountOut);
    }

    //! AmountOut 은 fee 를 제외한 금액
    //만약 100을 원하면 amountOut 은 100 , fee 는 10
    function sell(address to, uint256 amountOut, uint256 fee) external islock nonReentrant {
        require(amountOut > 0, ERR_INVALID_AMOUNT_OUT);
        require(to != wnad && to != token, ERR_INVALID_TO);
        require(fee > 0, ERR_INVALID_FEE);

        (uint256 _realNadReserves, uint256 _realTokenReserves) = getReserves();

        uint256 _fee = amountOut * feeConfig.denominator / feeConfig.numerator;
        require(fee >= _fee, ERR_INVALID_FEE);
        //send fee to vault
        {
            address vault = IBondingCurveFactory(factory).getVault();
            IERC20(wnad).safeTransferERC20(vault, fee);
        }

        require(amountOut <= _realNadReserves, ERR_INSUFFICIENT_RESERVE);

        uint256 balanceToken;

        {
            require(to != wnad && to != token, ERR_INVALID_TO);

            IERC20(wnad).safeTransferERC20(to, amountOut);

            balanceToken = IERC20(token).balanceOf(address(this));
        }

        uint256 amountTokenIn = balanceToken - _realTokenReserves;
        require(amountTokenIn > 0, ERR_INSUFFICIENT_INPUT_AMOUNT);

        _update(amountTokenIn, amountOut, false);

        emit Sell(to, token, amountTokenIn, amountOut);
    }

    function listing() external returns (address pair) {
        require(lock == true, ERR_LISTING_ONLY_LOCK);
        IBondingCurveFactory _factory = IBondingCurveFactory(factory);
        pair = IUniswapV2Factory(_factory.getDexFactory()).createPair(wnad, token);
        //dexlisting fee -> fee vault
        address vault = IBondingCurveFactory(factory).getVault();
        IERC20(wnad).safeTransferERC20(vault, _factory.getListingFee());

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
        require(virtualNad * virtualToken >= k, ERR_INVALID_K);
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
