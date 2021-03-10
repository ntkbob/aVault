// SPDX-License-Identifier: MIT

/*
 * This file is part of the Autumn aVault Smart Contract
 */

pragma solidity ^0.7.3;

import "./SafeERC20.sol";

library SafeERC20Wrapper {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    function safeReceive(IERC20 token, address from, uint256 amount) internal returns (uint256 actualAmount) {
        uint256 before = token.balanceOf(address(this));
        token.safeTransferFrom(from, address(this), amount);
        uint256 received = token.balanceOf(address(this)).sub(before);
        require(received != 0, "SafeERC20Wrapper@safeReceive: received amount is zero");
        return received;
    }
}