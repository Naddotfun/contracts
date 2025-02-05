// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}

interface IDexRouter is IUniswapV3SwapCallback {
    /**
     * @notice NATIVE를 사용하여 token을 구매 (exact input 방식)
     * @param amountIn NATIVE로 사용할 금액 (fee 별도)
     * @param amountOutMin 최소로 받을 token 수량 (슬리피지 보호)
     * @param fee fee 금액 (vault 전송용)
     * @param token 구매할 token 주소
     * @param to token 수령 주소
     * @param deadline 거래 만료 시간
     */
    function buy(uint256 amountIn, uint256 amountOutMin, uint256 fee, address token, address to, uint256 deadline)
        external
        payable;

    /**
     * @notice NATIVE를 사용하여 token을 구매 (exact output 방식)
     * @param amountOut 구매할 token의 정확한 양
     * @param amountInMax 최대 사용 가능한 NATIVE 양 (fee 포함)
     * @param token 구매할 token 주소
     * @param to token 수령 주소
     * @param deadline 거래 만료 시간
     */
    function exactOutBuy(uint256 amountOut, uint256 amountInMax, address token, address to, uint256 deadline)
        external
        payable;

    /**
     * @notice token을 판매하여 NATIVE를 받음 (exact input 방식)
     * @param amountIn 판매할 token 양
     * @param amountOutMin 최소로 받을 NATIVE 양 (슬리피지 보호)
     * @param token 판매할 token 주소
     * @param to NATIVE 수령 주소
     * @param deadline 거래 만료 시간
     */
    function sell(uint256 amountIn, uint256 amountOutMin, address token, address to, uint256 deadline) external;

    /**
     * @notice token을 판매하여 NATIVE를 받음 (exact output 방식)
     * @param amountOut 정확히 받을 NATIVE 양
     * @param amountInMax 최대 판매 가능한 token 양
     * @param token 판매할 token 주소
     * @param to NATIVE 수령 주소
     * @param deadline 거래 만료 시간
     */
    function exactOutSell(uint256 amountOut, uint256 amountInMax, address token, address to, uint256 deadline)
        external
        payable;

    /**
     * @notice fee 수금 vault 주소 반환
     */
    function getFeeVault() external view returns (address);

    /**
     * @notice fee 설정 값(분모, 분자) 반환
     */
    function getFeeConfig() external view returns (uint256, uint256);
}
