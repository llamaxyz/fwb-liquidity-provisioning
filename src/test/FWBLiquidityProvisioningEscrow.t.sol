// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.12;

// testing libraries
import "@ds/test.sol";
import "@std/console.sol";
import {stdCheats} from "@std/stdlib.sol";
import {Vm} from "@std/Vm.sol";
import {DSTestPlus} from "@solmate/test/utils/DSTestPlus.sol";

import {FWBLiquidityProvisioningEscrow} from "../FWBLiquidityProvisioningEscrow.sol";

contract FWBLiquidityProvisioningEscrowTest is DSTestPlus, stdCheats {
    Vm private vm = Vm(HEVM_ADDRESS);

    FWBLiquidityProvisioningEscrow public fwbLiquidityProvisioningEscrow;

    function setUp() public {
        fwbLiquidityProvisioningEscrow = new FWBLiquidityProvisioningEscrow();
        vm.label(address(fwbLiquidityProvisioningEscrow), "FWBLiquidityProvisioningEscrow");
    }

    // Reminder to check storage balance with ERC20 balance in test suite through asserts
    // Reminder to check 0 values array in minIn and minAmounts parameters while depositing/withdrawing from Gamma vault
}
