// SPDX-License-Identifier: MIT

/*
 * This file is part of the Autumn aVault Smart Contract
 */

pragma solidity ^0.7.3;
pragma experimental ABIEncoderV2;

import { LendHubProvider } from "./LendHubProvider.sol";

contract LendHub_HT is LendHubProvider {
    bool private constant IS_NATIVE = true;
    address private constant LENDHUB_HT = 0x99a2114B282acC9dd25804782ACb4D3a2b1Ad215;

    address[] private path = [
        LHB,
        HT
    ];

    constructor(address strategy_) LendHubProvider(strategy_, IS_NATIVE) {}

    function asset() public override pure returns (address) {
        return HT;
    }

    // CompoundProvider overrides

    function compound() public override pure returns (address) {
        return LENDHUB_HT;
    }

    function swapPath() public override view returns (address[] memory) {
        return path;
    }
}