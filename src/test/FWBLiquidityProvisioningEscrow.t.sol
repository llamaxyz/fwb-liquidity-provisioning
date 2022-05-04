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

    // function testSetNum(uint256 x) public {
    //     assertEq(numContract.num(), originalNumber);
    //     numContract.changeNum(x);
    //     assertEq(numContract.num(), x);
    // }
}