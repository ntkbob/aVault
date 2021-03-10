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

    constructor(address strategy_, bool native_) AbstractProvider(strategy_, native_) {
        IERC20(asset()).safeIncreaseAllowance(compound(), uint256(-1));
        IERC20(miningToken()).safeIncreaseAllowance(address(MDEX), uint256(-1));
    }

    // Abstracts

    function compound() public virtual view returns (address);

    function miningToken() public virtual view returns (address);

    function swapPath() public virtual view returns (address[] memory);

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
        uint256 amountMining = claimMiningToken();
        uint256 balanceMining = IERC20(miningToken()).balanceOf(address(this));
        if (balanceMining == 0) {
            return;
        }
        amountMining = swapMiningForAsset(balanceMining);
        if (amountMining == 0) {
            return;
        }
        FeeManager.chargeFeeWith("yield", asset(), amountMining);
        depositAll();
    }

    function swapMiningForAsset(uint256 amountMining) private returns (uint256) {
        IERC20 asset_ = IERC20(asset());
        uint256 beforeAsset = asset_.balanceOf(address(this));

        // this may result in various errors, just ignore
        try MDEX.swapExactTokensForTokens(
            amountMining, 0, swapPath(), address(this), block.timestamp.add(20 minutes)
        ) {
            return asset_.balanceOf(address(this)).sub(beforeAsset);
        } catch {
            return 0;
        }
    }

    function claimMiningToken() public returns (uint256) {
        IERC20 mining = IERC20(miningToken());
        uint256 beforeMining = mining.balanceOf(address(this));
        address[] memory cTokens = new address[](1);
        cTokens[0] = compound();
        comptroller().claimComp(address(this), cTokens);
        return mining.balanceOf(address(this)).sub(beforeMining);
    }

    function comptroller() private view returns (IComptroller) {
        return IComptroller(ICompound(compound()).comptroller());
    }
}