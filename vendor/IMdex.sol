// SPDX-License-Identifier: MIT

/*
 * This file is part of the Autumn aVault Smart Contract
 */

pragma solidity ^0.7.3;

interface IMdexRouter {
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB) external view returns (uint256 amountB);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function factory() external view returns (address);
}

interface IMdexFactory {
    function getAmountsOut(
        uint amountIn,
        address[] memory path) external view returns (uint[] memory amounts);

    function sortTokens(
        address tokenA,
        address tokenB) external pure returns (address token0_, address token1_);

    function pairFor(address tokenA, address tokenB) external view returns (address pair);
}

interface IMdexPair {
    function token0() external view returns (address);
    function token1() external view returns (address);

    function getReserves() external view returns (
        uint112 _reserve0,
        uint112 _reserve1,
        uint32 _blockTimestampLast);
}

interface ISwapMining {
    function takerWithdraw() external;
}