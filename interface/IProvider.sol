// SPDX-License-Identifier: MIT

/*
 * This file is part of the Autumn aVault Smart Contract
 */

pragma solidity ^0.7.3;

import { IStrategy } from "./IStrategy.sol";

/**
 * @dev Standard interface for provider
 */
interface IProvider is IStrategy {
    function IS_PROVIDER() external pure returns (bool);
}