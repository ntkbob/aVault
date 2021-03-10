// SPDX-License-Identifier: MIT

/*
 * This file is part of the Autumn aVault Smart Contract
 */

pragma solidity ^0.7.3;

import { IVault } from "./IVault.sol";

/**
 * @dev Standard interface for strategy
 */
interface IStrategy is IVault {
    function IS_STRATEGY() external pure returns (bool);

    /**
     * @dev Withdraw all from strategy. Returns the 'actual' amount.
     */
    function withdrawAll() external returns (uint256);
}