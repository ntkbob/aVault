// SPDX-License-Identifier: MIT

/*
 * This file is part of the Autumn aVault Smart Contract
 */

pragma solidity ^0.7.3;

/**
 * @dev List of popular assets
 */
abstract contract Assets {
    address internal constant HUSD = 0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047;
    address internal constant USDT = 0xa71EdC38d189767582C38A3145b5873052c3e47a;

    address internal constant ETH = 0x64FF637fB478863B7468bc97D30a5bF3A428a1fD;
    address internal constant BTC = 0x66a79D23E58475D2738179Ca52cd0b41d73f0BEa;
    address internal constant DOT = 0xA2c49cEe16a5E5bDEFDe931107dc1fae9f7773E3;
    address internal constant LTC = 0xecb56cf772B5c9A6907FB7d32387Da2fCbfB63b4;
    address internal constant BCH = 0xeF3CEBD77E0C52cb6f60875d9306397B5Caca375;
    address internal constant FIL = 0xae3a768f9aB104c69A7CD6041fE16fFa235d1810;

    address internal constant AAVE = 0x202b4936fE1a82A4965220860aE46d7d3939Bb25;
    address internal constant LINK = 0x9e004545c59D359F6B7BFB06a26390b087717b42;
    address internal constant UNI = 0x22C54cE8321A4015740eE1109D9cBc25815C46E6;
    address internal constant YFI = 0xB4F019bEAc758AbBEe2F906033AAa2f0F6Dacb35;
    address internal constant SNX = 0x777850281719d5a96C29812ab72f822E0e09F3Da;

    address internal constant BAGS = 0x6868D406a125Eb30886A6DD6B651D81677d1F22c;
    address internal constant MDX = 0x25D2e80cB6B86881Fd7e07dd263Fb79f4AbE033c;
    address internal constant HPT = 0xE499Ef4616993730CEd0f31FA2703B92B50bB536;
    address internal constant HT = 0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F; // WHT
}