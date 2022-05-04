// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.12;

import {IHypervisor} from "./external/IHypervisor.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract FWBLiquidityProvisioningEscrow {
    // Temporarily setting WBTC-ETH Gamma Vault as placeholder -> Set later as FWB-ETH Gamma Vault
    IHypervisor private constant GAMMA_FWB_VAULT = IHypervisor(0x35aBccd8e577607275647edAb08C537fa32CC65E);
    IERC20 private constant FWB = IERC20(0x35bD01FC9d6D5D81CA9E055Db88Dc49aa2c699A8);

    address private constant LLAMA_MULTISIG = 0xA519a7cE7B24333055781133B13532AEabfAC81b;
    // Temporarily setting FWB Multisig as 0xbabe -> Set later as actual FWB Multisig
    address private constant FWB_MULTISIG = address(0xbabe);
}
