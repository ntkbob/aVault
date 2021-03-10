// SPDX-License-Identifier: MIT

/*
 * This file is part of the Autumn aVault Smart Contract
 */

pragma solidity ^0.7.3;

/**
 * @dev Standard interface for vault
 */
interface IVault {
    function IS_VAULT() external pure returns (bool);

    /**
     * @dev Whether the asset is native currency.
     */
    function native() external view returns (bool);

    /**
     * @dev Returns the underlying asset of vault.
     */
    function asset() external view returns (address);

    /**
     * @dev Returns the vault balance of underlying asset.
     */
    function balance() external view returns (uint256);

    /**
     * @dev Returns the asset value of vault in stablecoin.
     */
    function value() external view returns (uint256);

    /**
     * @dev Returns the asset value of amount in stablecoin.
     */
    function valueBy(uint256 amount) external view returns (uint256);
    
    /**
     * @dev Carry out an update to vault.
     */
    function update() external;

    /**
     * @dev Deposit to vault. Returns the 'actual' amount.
     */
    function deposit(uint256 amount) external payable returns (uint256);

    /**
     * @dev Withdraw from vault. Returns the 'actual' amount.
     */
    function withdraw(uint256 amount) external returns (uint256);
}