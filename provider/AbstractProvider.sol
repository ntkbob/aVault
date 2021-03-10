// SPDX-License-Identifier: MIT

/*
 * This file is part of the Autumn aVault Smart Contract
 */

pragma solidity ^0.7.3;
pragma experimental ABIEncoderV2;

import "../vendor/SafeMath.sol";
import "../vendor/SafeERC20Wrapper.sol";

import { IWHT } from "../vendor/IWHT.sol";
import { Assets } from "../vendor/Assets.sol";
import { IProvider, IStrategy } from "../interface/IProvider.sol";
import { IMdexRouter, ISwapMining } from "../vendor/IMdex.sol";
import { FeeManager, PermissionManager } from "../vendor/FeeManager.sol";

/**
 * @dev Abstract implementation of provider to handle transfer and permission
 */
abstract contract AbstractProvider is IProvider, FeeManager, Assets {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20Wrapper for IERC20;

    bool public override constant IS_VAULT = true;
    bool public override constant IS_STRATEGY = true;
    bool public override constant IS_PROVIDER = true;

    IMdexRouter internal constant MDEX = IMdexRouter(0xED7d5F38C79115ca12fe6C0041abb22F0A06C300);
    ISwapMining internal constant SWAP_MINING = ISwapMining(0x7373c42502874C88954bDd6D50b53061F018422e);
    IWHT internal constant WHT = IWHT(HT);

    bool public override immutable native;

    constructor(address strategy_, bool native_) {
        native = native_;
        require(
            !native_ || asset() == address(WHT),
            "AbstractProvider@constructor: asset should be WHT for native currency"
        );
        PermissionManager.setSingletonPermission("strategy", strategy_);
    }

    // Viewers

    function asset() public override virtual view returns (address);

    function balance() public override virtual view returns (uint256);

    function value() external override view returns (uint256) {
        return IStrategy(PermissionManager.permissionList["strategy"][0]).value();
    }

    function valueBy(uint256 amount) external override view returns (uint256) {
        return IStrategy(PermissionManager.permissionList["strategy"][0]).valueBy(amount);
    }

    // Externals

    function deposit(uint256 amount) requirePermission("strategy") external override payable returns (uint256) {
        amount = IERC20(asset()).safeReceive(_msgSender(), amount);
        depositAll();
        return amount; // return the `received` amount
    }

    function depositAll() public {
        uint256 amount;
        if (native) {
            uint256 balanceWHT = IERC20(address(WHT)).balanceOf(address(this));
            if (balanceWHT != 0) {
                WHT.withdraw(balanceWHT);
            }

            amount = address(this).balance;
        } else {
            amount = IERC20(asset()).balanceOf(address(this));
        }
        if (amount != 0) {
            _deposit(amount);
        }
    }

    function withdrawAll() requirePermission("strategy") external override returns (uint256) {
        uint256 balance_ = balance();
        return balance_ == 0 ? 0 : withdraw(balance());
    }

    function withdraw(uint256 amount) requirePermission("strategy") public override returns (uint256) {
        require(amount != 0, "AbstractProvider@withdraw: cannot withdraw zero");
        amount = _safeWithdraw(amount);
        require(amount != 0, "AbstractProvider@withdraw: withdraw amount is too small");
        IERC20(asset()).safeTransfer(_msgSender(), amount);
        return amount;
    }

    function takerWithdraw() public {
        SWAP_MINING.takerWithdraw();
        uint256 balanceMDX = IERC20(MDX).balanceOf(address(this));
        if (balanceMDX != 0) {
            IERC20(MDX).safeTransfer(feeRecipient, balanceMDX);
        }
    }

    // Internals

    function _deposit(uint256 tokenAmount) internal virtual;

    function _withdraw(uint256 tokenAmount) internal virtual;

    // Safe Wrappers

    function _safeWithdraw(uint256 amount) private returns (uint256) {
        IERC20 asset_ = IERC20(asset());
        uint256 before = native ? address(this).balance :asset_.balanceOf(address(this));
        _withdraw(amount);
        uint256 actual;
        if (native) {
            actual = address(this).balance.sub(before);
            WHT.deposit{value: actual}();
        } else {
            actual = asset_.balanceOf(address(this)).sub(before);
        }
        return actual;
    }

    receive() payable external {}
}