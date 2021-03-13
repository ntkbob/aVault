// SPDX-License-Identifier: MIT

/*
 * This file is part of the Autumn aVault Smart Contract
 */

pragma solidity ^0.7.3;
pragma experimental ABIEncoderV2;

import { FeeManager, PermissionManager } from "./vendor/FeeManager.sol";
import { ERC20, IERC20, SafeMath } from "./vendor/ERC20.sol";
import { SafeERC20Wrapper, SafeERC20 } from "./vendor/SafeERC20Wrapper.sol";
import { IStrategy, IVault } from "./interface/IStrategy.sol";
import { Rescuable } from "./vendor/Rescuable.sol";
import { IWHT } from "./vendor/IWHT.sol";

/**
 * @dev The user interface for deposit and earn by the strategy
 */
contract aVault is IVault, ERC20, FeeManager, Rescuable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20Wrapper for IERC20;

    bool public override constant IS_VAULT = true;
    IWHT private constant WHT = IWHT(0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F);

    /**
     * @dev The underlying asset of vault
     */
    IERC20 private immutable _asset;

    bool public override immutable native;

    constructor (
        address underlyingAsset,
        string memory aAssetName, string memory aAssetSymbol, uint8 aAssetDecimals,
        bool nativeCurrency
    ) ERC20(
        aAssetName, aAssetSymbol, aAssetDecimals
    ) {
        native = nativeCurrency;
        try ERC20(underlyingAsset).decimals() {
            require(
                ERC20(underlyingAsset).decimals() == aAssetDecimals,
                "aVault@constructor: inconsistent asset decimals");
        } catch {}
        
        require(
            !nativeCurrency || underlyingAsset == address(WHT),
            "aVault@constructor: asset should be WHT for native currency"
        );
        _asset = IERC20(underlyingAsset);
    }

    function balanceOf() public view returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    // Yield

    uint256 public shareToAssetRecord;
    uint256 public interestInitialTime;

    uint256 private yieldRecord;

    /// @dev should be called only when balance is updated to the actual (latest) value
    function updateAssetYield() private {
        if (totalSupply() == 0) { // initialize
            shareToAssetRecord = 1e18;
            interestInitialTime = block.timestamp;
            return;
        }

        uint256 shareToAsset_ = shareToAsset(1e18);
        if (shareToAsset_ > shareToAssetRecord) {
            // shareToAsset will only increase by time in the scenario
            shareToAssetRecord = shareToAsset_;
            yieldRecord = getSecondYieldBy(shareToAsset_);
        }
    }

    function getSecondYieldBy(uint256 shareToAsset_) public view returns (uint256) {
        uint256 past = block.timestamp.sub(interestInitialTime);
        return shareToAsset_.sub(1e18).div(past);
    }

    /**
     * @notice Returns the asset yield per second in the share of 1e18
     */
    function getSecondYield() external view returns (uint256) {
        // directly use the recorded value
        // in case yield drop by time with an outdated balance
        return yieldRecord;
    }

    // Strategy

    IStrategy public strategy;

    function setStrategy(address strategy_, bool update_) onlyOwner() external {
        require(strategy_ != address(0), "aVault@setStrategy: invalid address");
        require(strategy_ != address(strategy), "aVault@setStrategy: already set");

        IStrategy newStrategy = IStrategy(strategy_);
        require(newStrategy.IS_STRATEGY(), "aVault@setStrategy: not a strategy");
        require(newStrategy.asset() == address(_asset), "aVault@setStrategy: variant asset");

        if (address(strategy) != address(0)) {
            if (update_) {
                strategy.update();
            }
            strategy.withdrawAll();
        }

        strategy = newStrategy;
        if (balanceOf() != 0) {
            _approveAndDeposit(balanceOf());
        }
    }

    modifier requireStrategy() {
        require(address(strategy) != address(0), "aVault@requireStrategy: no strategy");
        _;
    }

    // Share

    /**
     * @dev Share value formula:
     *
     * share per token = total share / total supply
     * share = token * share per token
     *
     * token per share = total supply / total share
     * token = share * token per share
     */

    function assetToShare(uint256 amount) external view returns (uint256) {
        return assetToShareBy(balance(), amount);
    }

    function assetToShareBy(uint256 balance_, uint256 amount) public view returns (uint256) {
        if (totalSupply() == 0) {
            return amount;
        }
        return (amount.mul(totalSupply())).div(balance_);
    }

    function shareToAsset(uint256 share) public view returns (uint256) {
        require(totalSupply() != 0, "aVault@shareToAsset: no share minted");
        return (share.mul(balance())).div(totalSupply());
    }

    // Vault Interface

    /**
     * @dev Returns the underlying asset of vault.
     */
    function asset() external override view returns (address) {
        return address(_asset);
    }

    /**
     * @dev Returns the vault balance of underlying asset.
     */
    function balance() requireStrategy() public override view returns (uint256) {
        return strategy.balance().add(balanceOf());
    }

    /**
     * @dev Returns the asset value of vault in stablecoin.
     */
    function value() requireStrategy() external override view returns (uint256) {
        return valueBy(balance());
    }

    function valueBy(uint256 amount) requireStrategy() public override view returns (uint256) {
        return strategy.valueBy(amount); // delegate to strategy
    }

    /**
     * @dev Carry out an update to vault.
     */
    function update() requireStrategy() public override {
        // restrict to off-chain in case price manipulation
        require(_msgSender() == tx.origin, "aVault@update: only callable from off-chain");
        _update();
    }

    function _update() private {
        strategy.update();
        updateAssetYield();
    }

    /**
     * @dev Deposit asset to vault. Returns the share amount.
     */
    function deposit(uint256 amount) requireStrategy() external override payable returns (uint256) {
        require(amount != 0, "aVault@deposit: cannot deposit zero");
        uint256 before = balance(); // use 'current' state to mint share
        if (before == 0) {
            updateAssetYield();
        } else {
            _update();
        }

        if (native) {
            require(msg.value == amount, "aVault@deposit: deposit was inconsistent with amount");
            WHT.deposit{ value: msg.value }();
        } else {
            require(msg.value == 0, "aVault@deposit: deposit was incorrect");
            amount = _asset.safeReceive(_msgSender(), amount);
        }

        amount = _approveAndDeposit(amount);
        uint256 share = assetToShareBy(before, amount);
        _mint(_msgSender(), share);

        if (before == 0) {
            _update();
        }
        return share;
    }

    function _approveAndDeposit(uint256 amount) private returns (uint256) {
        _asset.safeIncreaseAllowance(address(strategy), amount);
        return strategy.deposit(amount);
    }

    /**
     * @dev Withdraw share from vault. Returns the asset amount.
     */
    function withdraw(uint256 share) external override returns (uint256) {
        _update();
        return _withdraw(share);
    }

    /// @dev alternative in case update fails
    function _withdraw(uint256 share) requireStrategy() public returns (uint256) {
        require(share != 0, "aVault@withdraw: cannot withdraw zero");

        uint256 amount = shareToAsset(share);
        _burn(_msgSender(), share);
        require(amount != 0, "aVault@withdraw: withdraw amount is too small");

        uint256 balance_ = balanceOf();
        if (balance_ < amount) {
            uint256 expection = amount.sub(balance_);
            uint256 withdrawn = strategy.withdraw(expection);
            if (withdrawn < expection) {
                amount = balance_.add(withdrawn);
            }
        }

        amount = FeeManager.chargeFeeWith("withdraw", address(_asset), amount);

        if (native) {
            WHT.withdraw(amount);
            _msgSender().transfer(amount);
        } else {
            _asset.safeTransfer(_msgSender(), amount);
        }

        return amount;
    }

    receive() payable external {}
}