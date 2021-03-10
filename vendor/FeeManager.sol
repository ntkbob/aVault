// SPDX-License-Identifier: MIT

/*
 * This file is part of the Autumn aVault Smart Contract
 */

pragma solidity ^0.7.3;
pragma experimental ABIEncoderV2;

import { SafeERC20, SafeMath, IERC20 } from "./SafeERC20.sol";
import { PermissionManager } from "./PermissionManager.sol";

abstract contract FeeManager is PermissionManager {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 private constant FEE_DENOMINATOR = 1e8;

    mapping (string => uint256) public fees;

    address public feeRecipient;

    constructor() {
        feeRecipient = _msgSender();
        PermissionManager.addRole("fee", 0);
    }

    /**
     * @dev Charges fee on the amount and allocated for the associated token (and transfer if exceeds household)
     */
    function chargeFeeWith(string memory name, address token, uint256 amount) internal returns (uint256 afterAmount) {
        uint256 fee = fees[name];
        if (fee == 0) {
            return amount;
        }

        uint256 fee_ = amount.mul(fee).div(FEE_DENOMINATOR);
        IERC20(token).safeTransfer(feeRecipient, fee_);
        return amount.sub(fee_);
    }

    // Governance

    function setFeeFor(string memory name, uint256 fee) requirePermission("fee") external {
        fees[name] = fee;
    }

    function setFeeRecipient(address recipient) onlyOwner() external {
        feeRecipient = recipient;
    }
}