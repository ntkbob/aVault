// SPDX-License-Identifier: MIT

/*
 * This file is part of the Autumn aVault Smart Contract
 */

pragma solidity ^0.7.3;
pragma experimental ABIEncoderV2;

import "../../vendor/SafeERC20.sol";

import { IMdexRouter, ISwapMining } from "../../vendor/IMdex.sol";
import { AbstractProvider, FeeManager } from "../AbstractProvider.sol";
import { ICompound, ICToken, ICHT, IComptroller } from "./ICompound.sol";

/**
 * @dev Abstract implementation for compound backed providers
 */
abstract contract CompoundProvider is AbstractProvider {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    constructor(address strategy_, bool native_) AbstractProvider(strategy_, native_) {}

    // Abstracts

    function compound() public virtual view returns (address);

    function token() public virtual view returns (address);

    function swapPath() public virtual view returns (address[] memory);

    function _claim() internal virtual { // could be override
        address[] memory cTokens = new address[](1);
        cTokens[0] = compound();
        IComptroller(comptroller()).claimComp(address(this), cTokens);
    }

    // Impls

    function balance() public override view returns (uint256) {
        (, uint256 cTokenBalance_, , uint256 exchangeRate) =
            ICompound(compound()).getAccountSnapshot(address(this));
        return cTokenBalance_.mul(exchangeRate).div(1e18);
    }

    function _deposit(uint256 amount) internal override {
        if (native) {
            ICHT(compound()).mint{ value: amount }();
        } else {
            IERC20(asset()).safeIncreaseAllowance(compound(), amount);
            require(ICToken(compound()).mint(amount) == 0, "CompoundProvider@_deposit: deposit was unsuccessful");
        }
    }

    function _withdraw(uint256 amount) internal override {
        require(
            ICompound(compound()).redeemUnderlying(amount) == 0,
            "CompoundProvider@_withdraw: reedem was unsuccessful"
        );
    }

    function update() external override {
        uint256 claimed = claim();
        // use balance value because that claim is public
        claimed = IERC20(token()).balanceOf(address(this));
        if (claimed == 0) {
            return;
        }
        claimed = FeeManager.chargeFeeWith("yield", token(), claimed);
        if (claimed == 0) {
            return;
        }
        uint256 asset = swapForAssetByPath(claimed);
        if (asset == 0) {
            return;
        }
        depositAll();
    }

    function swapForAssetByPath(uint256 inputAmount) private returns (uint256) {
        IERC20 asset_ = IERC20(asset());
        uint256 beforeAsset = asset_.balanceOf(address(this));

        IERC20(token()).safeIncreaseAllowance(address(MDEX), inputAmount);
        // this may result in various errors, just ignore
        try MDEX.swapExactTokensForTokens(
            inputAmount, 0, swapPath(), address(this), block.timestamp.add(20 minutes)
        ) {
            return asset_.balanceOf(address(this)).sub(beforeAsset);
        } catch {
            return 0;
        }
    }

    function claim() public returns (uint256) {
        IERC20 reward = IERC20(token());
        uint256 before = reward.balanceOf(address(this));
        _claim();
        return reward.balanceOf(address(this)).sub(before);
    }

    function comptroller() internal view returns (address) {
        return ICompound(compound()).comptroller();
    }
}