// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IWNAD} from "./interfaces/IWNAD.sol";
import {ICore} from "./interfaces/ICore.sol";
import {NadFunLibrary} from "./utils/NadFunLibrary.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import "./errors/Errors.sol";

/**
 * @title Core
 * @notice Core contract for managing bonding curve operations and NAD token interactions
 * @dev Handles creation of bonding curves, buying and selling operations with various payment methods
 */
contract Core is ICore {
    using TransferHelper for IERC20;

    /// @notice Address of the bonding curve factory contract
    address public factory;
    /// @notice Address of the wrapped NAD token
    address public immutable WNAD;
    /// @notice ERC4626 vault contract for fee collection
    IERC4626 public immutable vault;
    bool isInitialized = false;

    /**
     * @notice Constructor initializes core contract with essential addresses
     
     * @param _WNAD Address of the wrapped NAD token
     * @param _vault Address of the fee collection vault
     */
    constructor(address _WNAD, address _vault) {
        WNAD = _WNAD;
        vault = IERC4626(_vault);
    }

    /**
     * @notice Fallback function to receive NAD
     * @dev Only accepts NAD from the WNAD contract
     */
    receive() external payable {
        assert(msg.sender == WNAD); // only accept NAD via fallback from the WNAD contract
    }

    /**
     * @notice Ensures function is called before deadline
     * @param deadline Timestamp before which the function must be called
     */
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, ERR_CORE_EXPIRED);
        _;
    }

    function initialize(address _factory) external {
        require(!isInitialized, ERR_CORE_ALREADY_INITIALIZED);
        factory = _factory;
        isInitialized = true;
    }

    /**
     * @notice Validates if the fee amount is correct according to curve parameters
     * @param curve Address of the bonding curve
     * @param amount Base amount for fee calculation
     * @param fee Fee amount to validate
     */
    function checkFee(
        address curve,
        uint256 amount,
        uint256 fee
    ) internal view {
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve)
            .getFeeConfig();
        require(
            fee >= (amount * denominator) / numerator,
            ERR_CORE_INVALID_FEE
        );
    }

    /**
     * @notice Sends fee to the vault
     * @param fee Amount of fee to send
     */
    function sendFeeByVault(uint256 fee) internal {
        IERC20(WNAD).safeTransferERC20(address(vault), fee);
    }

    /**
     * @notice Creates a new bonding curve with initial liquidity
     * @param creator Address of the curve creator
     * @param name Name of the token
     * @param symbol Symbol of the token
     * @param tokenURI URI for token metadata
     * @param amountIn Initial NAD amount
     * @param fee Fee amount for the creation
     * @return curve Address of the created bonding curve
     * @return token Address of the created token
     * @return virtualNad Initial virtual NAD reserve
     * @return virtualToken Initial virtual token reserve
     * @return amountOut Amount of tokens received
     */
    function createCurve(
        address creator,
        string memory name,
        string memory symbol,
        string memory tokenURI,
        uint256 amountIn,
        uint256 fee
    )
        external
        payable
        returns (
            address curve,
            address token,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 amountOut
        )
    {
        uint256 _deployFee = IBondingCurveFactory(factory).getDelpyFee();
        require(
            msg.value >= amountIn + fee + _deployFee,
            ERR_CORE_INVALID_SEND_NAD
        );

        (curve, token, virtualNad, virtualToken) = IBondingCurveFactory(factory)
            .create(creator, name, symbol, tokenURI);

        IWNAD(WNAD).deposit{value: amountIn + fee + _deployFee}();

        if (amountIn > 0) {
            checkFee(curve, amountIn, fee);
            sendFeeByVault(fee + _deployFee);
            uint256 k = virtualNad * virtualToken;
            amountOut = getAmountOut(amountIn, k, virtualNad, virtualToken);
            IERC20(WNAD).safeTransferERC20(curve, amountIn);
            IBondingCurve(curve).buy(creator, amountOut);
            IERC20(token).safeTransferERC20(creator, amountOut);
            return (
                curve,
                token,
                virtualNad + amountIn,
                virtualToken - amountOut,
                amountOut
            );
        }
        sendFeeByVault(_deployFee);
        return (curve, token, virtualNad, virtualToken, amountOut);
    }

    //----------------------------Buy Functions ---------------------------------------------------
    /**
     * @notice Buys tokens from a bonding curve
     * @param amountIn NAD amount to spend
     * @param fee Fee amount for the transaction
     * @param token Address of the token to buy
     * @param to Address to receive the bought tokens
     * @param deadline Timestamp before which the transaction must be executed
     */
    function buy(
        uint256 amountIn,
        uint256 fee,
        address token,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) {
        require(msg.value >= amountIn + fee, ERR_CORE_INVALID_SEND_NAD);
        require(amountIn > 0, ERR_CORE_INVALID_AMOUNT_IN);
        require(fee > 0, ERR_CORE_INVALID_FEE);

        (
            address curve,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 k
        ) = getCurveData(factory, token);
        checkFee(curve, amountIn, fee);

        IWNAD(WNAD).deposit{value: amountIn + fee}();
        sendFeeByVault(fee);

        // Calculate and verify amountOut
        uint256 amountOut = getAmountOut(amountIn, k, virtualNad, virtualToken);

        IERC20(WNAD).safeTransferERC20(curve, amountIn);
        IBondingCurve(curve).buy(to, amountOut);
        IERC20(token).safeTransferERC20(to, amountOut);
    }

    /**
     * @notice Buys tokens from a bonding curve with a minimum amount out
     * @param amountIn NAD amount to spend
     * @param amountOutMin Minimum amount of tokens to receive
     * @param fee Fee amount for the transaction
     * @param token Address of the token to buy
     * @param to Address to receive the bought tokens
     * @param deadline Timestamp before which the transaction must be executed
     */
    function buyAmountOutMin(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 fee,
        address token,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) {
        require(msg.value >= amountIn + fee, ERR_CORE_INVALID_SEND_NAD);

        (
            address curve,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 k
        ) = getCurveData(factory, token);
        checkFee(curve, amountIn, fee);
        // TransferHelper.safeTransferNad(owner, fee);

        IWNAD(WNAD).deposit{value: amountIn + fee}();

        sendFeeByVault(fee);
        uint256 amountOut = getAmountOut(amountIn, k, virtualNad, virtualToken);

        require(amountOut >= amountOutMin, ERR_CORE_INVALID_AMOUNT_OUT);

        IERC20(WNAD).safeTransferERC20(curve, amountIn);

        IBondingCurve(curve).buy(to, amountOut);
        IERC20(token).safeTransferERC20(to, amountOut);
    }

    /**
     * @notice Buys an exact amount of tokens from a bonding curve
     * @param amountOut Amount of tokens to buy
     * @param amountInMax Maximum NAD amount to spend
     * @param token Address of the token to buy
     * @param to Address to receive the bought tokens
     * @param deadline Timestamp before which the transaction must be executed
     */
    function buyExactAmountOut(
        uint256 amountOut,
        uint256 amountInMax,
        address token,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) {
        require(msg.value >= amountInMax, ERR_CORE_INVALID_SEND_NAD);

        (
            address curve,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 k
        ) = getCurveData(factory, token);
        uint256 amountIn = getAmountIn(amountOut, k, virtualNad, virtualToken);

        (uint8 denominator, uint16 numerator) = IBondingCurve(curve)
            .getFeeConfig();

        uint256 fee = NadFunLibrary.getFeeAmount(
            amountIn,
            denominator,
            numerator
        );

        require(amountIn + fee <= amountInMax, ERR_CORE_INVALID_AMOUNT_IN_MAX);

        uint256 restValue = amountInMax - (amountIn + fee);
        if (restValue > 0) {
            TransferHelper.safeTransferNad(msg.sender, restValue);
        }
        IWNAD(WNAD).deposit{value: amountIn + fee}();
        sendFeeByVault(fee);
        IERC20(WNAD).safeTransferERC20(curve, amountIn);
        IBondingCurve(curve).buy(to, amountOut);
        IERC20(token).safeTransferERC20(to, amountOut);
    }

    // //-------------Sell Functions ---------------------------------------------

    /**
     * @notice Sells tokens to a bonding curve
     * @param amountIn Token amount to sell
     * @param token Address of the token to sell
     * @param to Address to receive the sold tokens
     * @param deadline Timestamp before which the transaction must be executed
     */
    function sell(
        uint256 amountIn,
        address token,
        address to,
        uint256 deadline
    ) external ensure(deadline) {
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        require(allowance >= amountIn, ERR_CORE_INVALID_ALLOWANCE);
        require(amountIn > 0, ERR_CORE_INVALID_AMOUNT_IN);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);

        (
            address curve,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 k
        ) = getCurveData(factory, token);

        uint256 amountOut = getAmountOut(amountIn, k, virtualToken, virtualNad);

        (uint8 denominator, uint16 numerator) = IBondingCurve(curve)
            .getFeeConfig();

        IERC20(token).safeTransferERC20(curve, amountIn);

        IBondingCurve(curve).sell(to, amountOut);
        uint256 fee = NadFunLibrary.getFeeAmount(
            amountOut,
            denominator,
            numerator
        );

        sendFeeByVault(fee);
        IWNAD(WNAD).withdraw(amountOut - fee);

        TransferHelper.safeTransferNad(to, amountOut - fee);
    }

    /**
     * @notice Sells tokens to a bonding curve with permit
     * @param amountIn Token amount to sell
     * @param token Address of the token to sell
     * @param from Address of the token owner
     * @param to Address to receive the sold tokens
     * @param deadline Timestamp before which the transaction must be executed
     * @param v v parameter of the permit signature
     * @param r r parameter of the permit signature
     * @param s s parameter of the permit signature
     */
    function sellPermit(
        uint256 amountIn,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(token).permit(
            from,
            address(this),
            amountIn,
            deadline,
            v,
            r,
            s
        );
        IERC20(token).safeTransferFrom(from, address(this), amountIn);
        (
            address curve,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 k
        ) = getCurveData(factory, token);

        uint256 amountOut = getAmountOut(amountIn, k, virtualToken, virtualNad);

        (uint8 denominator, uint16 numerator) = IBondingCurve(curve)
            .getFeeConfig();

        IERC20(token).safeTransferERC20(curve, amountIn);

        IBondingCurve(curve).sell(to, amountOut);
        uint256 fee = NadFunLibrary.getFeeAmount(
            amountOut,
            denominator,
            numerator
        );
        sendFeeByVault(fee);
        IWNAD(WNAD).withdraw(amountOut - fee);

        TransferHelper.safeTransferNad(to, amountOut - fee);
    }

    /**
     * @notice Sells tokens to a bonding curve with a minimum amount out
     * @param amountIn Token amount to sell
     * @param amountOutMin Minimum amount of NAD to receive
     * @param token Address of the token to sell
     * @param to Address to receive the sold tokens
     * @param deadline Timestamp before which the transaction must be executed
     */
    function sellAmountOutMin(
        uint256 amountIn,
        uint256 amountOutMin,
        address token,
        address to,
        uint256 deadline
    ) external ensure(deadline) {
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        require(allowance >= amountIn, ERR_CORE_INVALID_ALLOWANCE);
        require(amountIn > 0, ERR_CORE_INVALID_AMOUNT_IN);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);

        (
            address curve,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 k
        ) = getCurveData(factory, token);

        uint256 amountOut = getAmountOut(amountIn, k, virtualToken, virtualNad);

        (uint8 denominator, uint16 numerator) = IBondingCurve(curve)
            .getFeeConfig();
        uint256 fee = NadFunLibrary.getFeeAmount(
            amountOut,
            denominator,
            numerator
        );

        require(amountOut - fee >= amountOutMin, ERR_CORE_INVALID_AMOUNT_OUT);

        IERC20(token).safeTransferERC20(curve, amountIn);

        IBondingCurve(curve).sell(to, amountOut);
        sendFeeByVault(fee);
        IWNAD(WNAD).withdraw(amountOut - fee);

        TransferHelper.safeTransferNad(to, amountOut - fee);
    }

    /**
     * @notice Sells tokens to a bonding curve with permit and a minimum amount out
     * @param amountIn Token amount to sell
     * @param amountOutMin Minimum amount of NAD to receive
     * @param token Address of the token to sell
     * @param from Address of the token owner
     * @param to Address to receive the sold tokens
     * @param deadline Timestamp before which the transaction must be executed
     * @param v v parameter of the permit signature
     * @param r r parameter of the permit signature
     * @param s s parameter of the permit signature
     */
    function sellAmountOutMinWithPermit(
        uint256 amountIn,
        uint256 amountOutMin,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external ensure(deadline) {
        // EIP-2612 permit: approve by signature
        require(amountIn > 0, ERR_CORE_INVALID_AMOUNT_IN);
        IERC20Permit(token).permit(
            from,
            address(this),
            amountIn,
            deadline,
            v,
            r,
            s
        );
        // Safe transfer the token from user to this contract
        IERC20(token).safeTransferFrom(from, address(this), amountIn);

        // Get curve and reserves
        (
            address curve,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 k
        ) = getCurveData(factory, token);

        // Calculate and verify amountOut
        uint256 amountOut = getAmountOut(amountIn, k, virtualToken, virtualNad);
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve)
            .getFeeConfig();
        uint256 fee = NadFunLibrary.getFeeAmount(
            amountOut,
            denominator,
            numerator
        );

        require(amountOut - fee >= amountOutMin, ERR_CORE_INVALID_AMOUNT_OUT);

        IERC20(token).safeTransferERC20(curve, amountIn);
        IBondingCurve(curve).sell(to, amountOut);

        sendFeeByVault(fee);
        IWNAD(WNAD).withdraw(amountOut - fee);

        TransferHelper.safeTransferNad(to, amountOut - fee);
    }

    //amountOut 은 fee + amountOut 이어야함.

    /**
     * @notice Sells an exact amount of tokens to a bonding curve
     * @param amountOut Amount of NAD to receive
     * @param amountInMax Maximum token amount to sell
     * @param token Address of the token to sell
     * @param to Address to receive the sold tokens
     * @param deadline Timestamp before which the transaction must be executed
     */
    function sellExactAmountOut(
        uint256 amountOut,
        uint256 amountInMax,
        address token,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) {
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        require(
            allowance >= amountInMax && amountInMax > 0,
            ERR_CORE_INVALID_ALLOWANCE
        );

        (
            address curve,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 k
        ) = getCurveData(factory, token);
        uint256 fee = msg.value;
        checkFee(curve, amountOut, fee);
        IWNAD(WNAD).deposit{value: fee}();
        sendFeeByVault(fee);

        uint256 amountIn = getAmountIn(amountOut, k, virtualToken, virtualNad);

        require(amountIn <= amountInMax, ERR_CORE_INVALID_AMOUNT_IN_MAX);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(token).safeTransferERC20(curve, amountIn);

        IBondingCurve(curve).sell(to, amountOut);

        IWNAD(WNAD).withdraw(amountOut);

        TransferHelper.safeTransferNad(to, amountOut);
    }

    /**
     * @notice Sells an exact amount of tokens to a bonding curve with permit
     * @param amountOut Amount of NAD to receive
     * @param amountInMax Maximum token amount to sell
     * @param token Address of the token to sell
     * @param from Address of the token owner
     * @param to Address to receive the sold tokens
     * @param deadline Timestamp before which the transaction must be executed
     * @param v v parameter of the permit signature
     * @param r r parameter of the permit signature
     * @param s s parameter of the permit signature
     */
    function sellExactAmountOutwithPermit(
        uint256 amountOut,
        uint256 amountInMax,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable ensure(deadline) {
        IERC20Permit(token).permit(
            from,
            address(this),
            amountInMax,
            deadline,
            v,
            r,
            s
        );
        require(amountInMax > 0, ERR_CORE_INVALID_AMOUNT_IN_MAX);

        (
            address curve,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 k
        ) = getCurveData(factory, token);
        uint256 fee = msg.value;
        checkFee(curve, amountOut, fee);
        IWNAD(WNAD).deposit{value: fee}();
        sendFeeByVault(fee);
        uint256 amountIn = getAmountIn(amountOut, k, virtualToken, virtualNad);

        require(amountIn <= amountInMax, ERR_CORE_INVALID_AMOUNT_IN_MAX);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(token).safeTransferERC20(curve, amountIn);
        IBondingCurve(curve).sell(to, amountOut);

        IWNAD(WNAD).withdraw(amountOut);

        TransferHelper.safeTransferNad(to, amountOut);
    }

    //----------------------------Common Functions ---------------------------------------------------

    /**
     * @notice Gets curve data from the factory
     * @param _factory Factory contract address
     * @param token Token address
     * @return curve Bonding curve address
     * @return virtualNad Virtual NAD reserve
     * @return virtualToken Virtual token reserve
     * @return k Constant product value
     */
    function getCurveData(
        address _factory,
        address token
    )
        public
        view
        returns (
            address curve,
            uint256 virtualNad,
            uint256 virtualToken,
            uint256 k
        )
    {
        (curve, virtualNad, virtualToken, k) = NadFunLibrary.getCurveData(
            _factory,
            token
        );
    }

    /**
     * @notice Gets curve data directly from a curve contract
     * @param curve Bonding curve address
     * @return virtualNad Virtual NAD reserve
     * @return virtualToken Virtual token reserve
     * @return k Constant product value
     */
    function getCurveData(
        address curve
    )
        public
        view
        returns (uint256 virtualNad, uint256 virtualToken, uint256 k)
    {
        (virtualNad, virtualToken, k) = NadFunLibrary.getCurveData(curve);
    }

    /**
     * @notice Calculates the output amount for a given input
     * @param amountIn Input amount
     * @param k Constant product value
     * @param reserveIn Input reserve
     * @param reserveOut Output reserve
     * @return amountOut Calculated output amount
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 k,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        amountOut = NadFunLibrary.getAmountOut(
            amountIn,
            k,
            reserveIn,
            reserveOut
        );
    }

    /**
     * @notice Calculates the input amount required for a desired output
     * @param amountOut Desired output amount
     * @param k Constant product value
     * @param reserveIn Input reserve
     * @param reserveOut Output reserve
     * @return amountIn Required input amount
     */
    function getAmountIn(
        uint256 amountOut,
        uint256 k,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountIn) {
        amountIn = NadFunLibrary.getAmountIn(
            amountOut,
            k,
            reserveIn,
            reserveOut
        );
    }

    /**
     * @notice Gets the address of the fee collection vault
     * @return Address of the vault
     */
    function getFeeVault() public view returns (address) {
        return address(vault);
    }
}
