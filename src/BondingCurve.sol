// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import "./errors/Errors.sol";
import {Test, console} from "forge-std/Test.sol";

contract BondingCurve is IBondingCurve, ReentrancyGuard {
    using TransferHelper for IERC20;

    address public factory;

    address public wnad;
    address public token;

    uint256 private virtualNad;
    uint256 private virtualToken;
    uint256 private k;
    uint256 private targetToken; //targetToken = 2_069_000_000
    Fee feeConfig;

    struct Fee {
        uint8 denominator;
        uint16 numerator;
    }

    uint256 realNadReserves; //realNadReserves = 30
    uint256 realTokenReserves; //realTokenReserves = 1073000191
    //계산에 필요한것
    bool lock;

    modifier islock() {
        require(!lock, ERR_LOCK);
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
    }

    function _update(uint256 amountIn, uint256 amountOut, bool isBuy) private {
        realNadReserves = IERC20(wnad).balanceOf(address(this));
        realTokenReserves = IERC20(token).balanceOf(address(this));
        console.log("Init VirtualNad = ", virtualNad);
        console.log("Init VirtualToken= ", virtualToken);
        if (isBuy) {
            virtualNad += amountIn;

            virtualToken -= amountOut;
            // console.log("Amount In =", amountIn);
            // console.log("AfterVirutalBase =", virtualNad);
            // console.log("Amount Out = ", amountOut);
            // console.log("AfterVirtualToken = ", virtualToken);
        } else {
            virtualNad -= amountOut;
            virtualToken += amountIn;
            // console.log("Amount In =", amountIn);
            // console.log("AfterVirutalBase =", virtualNad);
            // console.log("Amount Out = ", amountOut);
            // console.log("AfterVirtualToken = ", virtualToken);
        }

        if (realTokenReserves == getTargetToken()) {
            lock = true;
        }
        //emit Event Lock

        console.log("After K = ", virtualNad * virtualToken);
        console.log("After VirtualNad = ", virtualNad);
        console.log("After VirtualToken = ", virtualToken);

        // console.log("TargetBase = ", targetBase);

        emit Lock(address(this));
        emit Sync(realNadReserves, realTokenReserves, virtualNad, virtualToken);
        //emit Sync(balanceBase,balanceToken)asdf
    }
    // this low-level function should be called from a contract which performs important safety checks

    function buy(address to, uint256 fee, uint256 amountOut) external islock nonReentrant {
        require(amountOut > 0, ERR_INVALID_AMOUNT_OUT);
        address _wnad = wnad; //gas savings
        address _token = token; //gas savings

        // console.log(amountIn, fee);
        // require(amountIn >= numerator, ERR_LOW_AMOUNT_IN);
        // require(fee == calculateFeeAmount(amountIn, denominator, numerator), ERR_INVALID_FEE);

        (uint256 _realNadReserves, uint256 _realTokenReserves) = getReserves();

        require(_realTokenReserves - amountOut >= targetToken, ERR_OVERFLOW_TARGET);

        // require(amountOut <= _realTokenReserves, ERR_INSUFFICIENT_RESERVE);

        //풀의 현재 잔액
        uint256 balanceNad;

        {
            require(to != _wnad && to != _token, ERR_INVALID_TO);
            IERC20(_token).safeTransferERC20(to, amountOut);

            balanceNad = IERC20(wnad).balanceOf(address(this));
        }

        // console.log("BalanceBase = ", balanceBase);
        //realNadReserves = 0
        //balanceBase = amountIn

        uint256 amountNadIn = balanceNad - _realNadReserves;
        require(amountNadIn > 0, INSUFFICIENT_INPUT_AMOUNT);
        (uint8 denominator, uint16 numerator) = getFee();
        require(fee >= amountOut * denominator / numerator, ERR_INVALID_FEE);
        IERC20(_wnad).safeTransferERC20(IBondingCurveFactory(factory).getOwner(), fee);
        amountNadIn -= fee;
        // console.log("AmountNadIn = ", amountNadIn);

        //TargetOverFlow Check
        // require(amountNadIn + _realNadReserves <= _targetBase, ERR_OVERFLOW_TARGET_WNAD);

        _update(amountNadIn, amountOut, true);
        //k 값을 맞출수가없음.
        console.log("RealNadReserves = ", realNadReserves);
        console.log("RealTokenReserves = ", realTokenReserves);
        require(virtualNad * virtualToken >= k, ERR_INVALID_K);
        emit Buy(to, amountNadIn, amountOut);
    }

    //fee는 amountOut 의 1 % 가 되어야함.
    //fee = 1% * amountOut
    function sell(address to, uint256 fee, uint256 amountOut) external islock nonReentrant {
        require(amountOut > 0, ERR_INVALID_AMOUNT_OUT);

        address _wnad = wnad; //gas savings
        address _token = token; //gas savings
        (uint256 _realNadReserves, uint256 _realTokenReserves) = getReserves();
        require(amountOut <= _realNadReserves, ERR_INSUFFICIENT_RESERVE);

        //유저가 보낸 현재 잔액
        uint256 balanceToken;

        //amountOut is fee 계산된 금액
        {
            require(to != _wnad && to != _token, ERR_INVALID_TO);
            (uint8 denominator, uint16 numerator) = getFee();
            require(fee >= amountOut * denominator / numerator, ERR_INVALID_FEE);
            // checkFee(amountOut, fee);
            IERC20(_wnad).safeTransferERC20(IBondingCurveFactory(factory).getOwner(), fee);
            IERC20(_wnad).safeTransferERC20(to, amountOut - fee);

            balanceToken = IERC20(_token).balanceOf(address(this));
        }
        // console.log("RealTokenReserves = ", _realTokenReserves);
        // console.log("BalanceToken = ", balanceToken);
        uint256 amountTokenIn = balanceToken - _realTokenReserves;
        // console.log("AmountTokenIn = ", amountTokenIn);
        require(amountTokenIn > 0, INSUFFICIENT_INPUT_AMOUNT);

        _update(amountTokenIn, amountOut, false);
        require(virtualNad * virtualToken >= k, ERR_INVALID_K);
        emit Sell(to, amountTokenIn, amountOut);
    }

    // // TODO : Target Dex Factory 가 정재지면 그때 작성
    // function dexListing() external {
    //     //
    // }
    // //fee is 1%
    // //

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
}
