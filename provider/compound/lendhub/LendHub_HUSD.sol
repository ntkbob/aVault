// SPDX-License-Identifier: MIT

/*
 * This file is part of the Autumn aVault Smart Contract
 */

pragma solidity ^0.7.3;
pragma experimental ABIEncoderV2;

import { LendHubProvider } from "./LendHubProvider.sol";

contract LendHub_HUSD is LendHubProvider {
    bool private constant IS_NATIVE = false;
    address private constant LENDHUB_HUSD = 0x1C478D5d1823D51c4c4b196652912A89D9b46c30;

    address[] private path = [
        LHB,
        HT,
        HUSD
    ];

    constructor(address strategy_) LendHubProvider(strategy_, IS_NATIVE) {}

    function asset() public override pure returns (address) {
        return HUSD;
    }

    // CompoundProvider overrides

    function compound() public override pure returns (address) {
        return LENDHUB_HUSD;
    }

    function swapPath() public override view returns (address[] memory) {
        return path;
    }
}