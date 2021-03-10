// SPDX-License-Identifier: MIT

/*
 * This file is part of the Autumn aVault Smart Contract
 */

pragma solidity ^0.7.3;

interface ICompound {
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256, uint256);
    function balanceOfUnderlying(address owner) external returns (uint256);
    function comptroller() external view returns (address);
}

interface ICToken is ICompound {
    function mint(uint256 mintAmount) external returns (uint256);
}

interface ICHT is ICompound {
    function mint() external payable;
}

interface IComptroller {
    function claimComp(address holder, address[] memory cTokens) external;
}