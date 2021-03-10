// SPDX-License-Identifier: MIT

/*
 * This file is part of the Autumn aVault Smart Contract
 */

pragma solidity ^0.7.3;
pragma experimental ABIEncoderV2;

import { CompoundProvider } from "../CompoundProvider.sol";

abstract contract LendHubProvider is CompoundProvider {
    address internal constant LHB = 0x8F67854497218043E1f72908FFE38D0Ed7F24721;

    constructor(address strategy_, bool native_) CompoundProvider(strategy_, native_) {}

    // CompoundProvider overrides

    function miningToken() public override pure returns (address) {
        return LHB;
    }
}