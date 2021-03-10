// SPDX-License-Identifier: MIT

/*
 * This file is part of the Autumn aVault Smart Contract
 */

pragma solidity ^0.7.3;
pragma experimental ABIEncoderV2;

import { IProvider } from "./interface/IProvider.sol";
import { IVault, IStrategy } from "./interface/IStrategy.sol";
import { PermissionManager } from "./vendor/PermissionManager.sol";
import { IMdexRouter, IMdexFactory, IMdexPair } from "./vendor/IMdex.sol";
import { SafeERC20Wrapper, SafeERC20, SafeMath, IERC20 } from "./vendor/SafeERC20Wrapper.sol";

/**
 * @title Strategy for the vaults to earn by multiple providers
 */
contract StrategyV1 is IStrategy, PermissionManager {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20Wrapper for IERC20;

    bool public override constant IS_VAULT = true;
    bool public override constant IS_STRATEGY = true;

    IMdexRouter private constant MDEX = IMdexRouter(0xED7d5F38C79115ca12fe6C0041abb22F0A06C300);

    /**
     * @dev The underlying asset of strategy
     */
    IERC20 private immutable _asset;

    address[] public valuePath;

    constructor(address vault, address[] memory valuePath_) {
        _asset = IERC20(IVault(vault).asset());
        valuePath = valuePath_;

        // Prepare permissions
        PermissionManager.addRole("governor", 0);
        PermissionManager.setPermission("governor", _msgSender(), true);
        PermissionManager.addRole("strategist", 0);
        PermissionManager.setPermission("strategist", _msgSender(), true);
        PermissionManager.setSingletonPermission("vault", vault);
    }

    /*
     * Strategy Interface
     */

    // Viewers

    function native() external override view returns (bool) {
        return provider().native();
    }

    function asset() external override view returns (address) {
        return address(_asset);
    }

    function balance() public override view returns (uint256 sum) {
        for (uint256 i = 0; i < providerNames.length; i++) {
            sum = sum.add(getProvider(i).balance());
        }
        return balanceOf().add(sum);
    }

    /**
     * @dev Returns the asset value of vault in stablecoin.
     */
    function value() external override view returns (uint256 sum) {
        return valueBy(balance());
    }

    function valueProvider(string memory name) external view returns (uint256) {
        return valueBy(providers[name].balance());
    }

    /// @dev simulates a swap in Mdex without applying fee
    function valueBy(uint256 assetAmount) public override view returns (uint256) {
        if (valuePath.length <= 1) { // for stablecoin
            return assetAmount;
        }
        IMdexFactory factory = IMdexFactory(MDEX.factory());
        uint256 lastPathAmountOut = assetAmount;
        for (uint256 i = 0; i < valuePath.length; i++) {
            if (i == valuePath.length - 1) {
                break;
            }
            IMdexPair pair = IMdexPair(factory.pairFor(valuePath[i], valuePath[i + 1]));
            (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
            lastPathAmountOut = MDEX.quote(lastPathAmountOut, reserve1, reserve0);
        }
        return lastPathAmountOut;
    }

    // Externals

    function update() requirePermission("vault") external override {
        for (uint256 i = 0; i < providerNames.length; i++) {
            getProvider(i).update();
        }
    }

    function deposit(uint256 amount) requirePermission("vault") external override payable returns (uint256) {
        require(amount != 0, "StrategyV1@deposit: cannot deposit zero");

        amount = _asset.safeReceive(_msgSender(), amount);
        return provider().deposit(amount);
    }

    function withdraw(uint256 amount) requirePermission("vault") public override returns (uint256) {
        require(amount != 0, "StrategyV1@withdraw: cannot withdraw zero");

        uint256 balance_ = balanceOf();
        if (balance_ < amount) {
            uint256 expection = amount.sub(balance_);
            uint256 withdrawn = withdrawFromProviders(expection);
            if (withdrawn < expection) {
                amount = balance_.add(withdrawn);
            }
        }

        _asset.safeTransfer(_msgSender(), amount);
        return amount;
    }

    function withdrawFromProviders(uint256 amount) private returns (uint256 withdrawn) {
        IProvider p = provider();
        if (amount < p.balance()) {
            return p.withdraw(amount);
        }

        uint256 remaining = amount;
        for (uint256 i = 0; i < providerNames.length; i++) {
            p = getProvider(i);

            if (remaining < p.balance()) {
                return withdrawn.add(p.withdraw(remaining));
            } else {
                remaining = remaining.sub(p.balance());
                withdrawn = withdrawn.add(p.withdrawAll());
            }
        }
    }

    function withdrawAll() requirePermission("vault") external override returns (uint256) {
        uint256 balance_ = balance();
        return balance_ == 0 ? 0 : withdraw(balance());
    }

    /*
     * Provider
     */

    /**
     * @notice All providers in strategy by their names
     */
    mapping (string => IProvider) public providers;

    /**
     * @notice Array of all provider names
     */
    string[] public providerNames;

    /**
     * @notice The default provider for deposit
     */
    IProvider public defaultProvider;

    /**
     * @notice List names of all providers
     */
    function listProviders() external view returns (string[] memory) {
        return providerNames;
    }

    /**
     * @notice Suggest a provider by strategy
     */
    function provider() public view returns (IProvider) {
        if (address(defaultProvider) != address(0)) {
            return defaultProvider;
        } else {
            require(providerNames.length != 0, "StrategyV1@provider: no provider yet");
            return getProvider(0);
        }
    }

    /**
     * @notice Get a provider instance by its index
     */
    function getProvider(uint256 index) public view returns (IProvider) {
        require(providerNames.length > index, "StrategyV1@getProvider: provider at index not exists");
        return providers[providerNames[index]];
    }

    /**
     * @notice Query the balance of a provider by its name
     */
    function getProviderBalance(string memory name) public view returns (uint256) {
        return providers[name].balance();
    }

    /**
     * @notice Search for the index of a provider by its name
     */
    function searchProviderIndex(string memory name) public view returns (bool found, uint256 at) {
        for (uint256 i = 0; i < providerNames.length; i++) {
            if (compareString(providerNames[i], name)) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    // Governance functions

    /**
     * @notice Add or replace a provider to strategy
     */
    function addProvider(string memory name, address provider_) requirePermission("governor") external {
        IProvider p = IProvider(provider_);
        require(p.IS_PROVIDER(), "StrategyV1@addProvider: not a provider");
        require(p.asset() == address(_asset), "StrategyV1@addProvider: variant asset");

        (bool exists, uint256 index) = searchProviderIndex(name);
        if (exists) {
            removeProviderByIndex(index, true);
        }
        
        providers[name] = p;
        providerNames.push(name);
        _asset.safeIncreaseAllowance(provider_, uint256(-1));
        emit ProviderAdded(name, provider_);
    }

    /**
     * @notice Withdraw all from and remove a provider by its name
     */
    function removeProvider(string memory name, bool withdraw_) requirePermission("governor") external {
        (bool has, uint256 index) = searchProviderIndex(name);
        require(has, "StrategyV1@removeProvider: provider not exists");
        removeProviderByIndex(index, withdraw_);
    }

    function removeProviderByIndex(uint256 index, bool withdraw_) private {
        string memory name = providerNames[index];
        if (withdraw_) {
            _adjustWithdraw(name, 0);
        }
        emit ProviderRemoved(name, deleteProviderData(name, index));
    }

    /**
     * @dev Delete a provider permanently from storage
     */
    function deleteProviderData(string memory name, uint256 index) private returns (address) {
        address provider_ = address(providers[name]);
        if (address(defaultProvider) == provider_) {
            defaultProvider = IProvider(address(0));
        }
        providerNames[index] = providerNames[providerNames.length - 1];
        providerNames.pop();
        delete providers[name];
        return provider_;
    }

    event ProviderAdded(string indexed providerName, address indexed providerAddress);
    event ProviderRemoved(string indexed providerName, address indexed providerAddress);

    // Strategist functions

    /**
     * @notice Set the default provider for strategy
     */
    function setDefaultProvider(string memory name) requirePermission("strategist") external {
        IProvider p = providers[name];
        require(p.IS_PROVIDER(), "StrategyV1@setDefaultProvider: provider not exists");
        defaultProvider = p;
        emit DefaultProviderUpdated(name, address(p));
    }

    /**
     * @notice Adjust strategy by deposit balance to a provider
     *  Use `0` for deposit all available balance
     */
    function adjustDeposit(string memory name, uint256 amount) requirePermission("strategist") public returns (uint256) {
        IProvider p = providers[name];
        require(p.IS_PROVIDER(), "StrategyV1@adjustDeposit: provider not exists");

        uint256 balance_ = balanceOf();
        amount = amount == 0 ? balance_ : amount;
        require(balance_ >= amount, "StrategyV1@adjustDeposit: amount exceeds balance");
        amount = provider().deposit(amount);

        emit StrategyAdjusted(_msgSender(), address(p), 0, amount);
        return amount;
    }

    /**
     * @notice Adjust strategy by withdraw balance from a provider
     *  Use `0` for withdraw all provider balance
     */
    function adjustWithdraw(string memory name, uint256 amount) requirePermission("strategist") public returns (uint256) {
        return _adjustWithdraw(name, amount);
    }

    /// @dev perform permission check before calling this
    function _adjustWithdraw(string memory name, uint256 amount) private returns (uint256) {
        IProvider p = providers[name];
        require(p.IS_PROVIDER(), "StrategyV1@adjustWithdraw: provider not exists");

        amount = amount == 0 ? p.withdrawAll() : p.withdraw(amount);
        emit StrategyAdjusted(_msgSender(), address(p), 1, amount);
        return amount;
    }

    /**
     * @notice Adjust strategy by move balance from one provider to another
     *  Use `0` for move all provider balance
     */
    function adjustMove(string memory from, string memory to, uint256 amount) requirePermission("strategist") external returns (uint256) {
        return adjustDeposit(to, adjustWithdraw(from, amount));
    }

    event DefaultProviderUpdated(string indexed providerName, address indexed providerAddress);
    event StrategyAdjusted(address indexed strategist, address indexed provider, uint256 opcode, uint256 amount);

    // Misc

    /**
     * @notice Returns asset balance of current contract
     */
    function balanceOf() public view returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    /**
     * @dev Compares the equity of two strings
     */
    function compareString(string memory a, string memory b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}