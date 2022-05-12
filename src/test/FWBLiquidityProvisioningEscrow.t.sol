// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.12;

// testing libraries
import "@ds/test.sol";
import "@std/console.sol";
import {stdCheats} from "@std/stdlib.sol";
import {Vm} from "@std/Vm.sol";
import {DSTestPlus} from "@solmate/test/utils/DSTestPlus.sol";

import {FWBLiquidityProvisioningEscrow} from "../FWBLiquidityProvisioningEscrow.sol";
import {IHypervisor} from "../external/IHypervisor.sol";
import {IWETH9} from "../external/IWETH9.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract FWBLiquidityProvisioningEscrowTest is DSTestPlus, stdCheats {
    event FWBDeposited(address indexed from, uint256 amount);
    event FWBWithdrawn(address indexed to, uint256 amount);
    event ETHDeposited(address indexed from, uint256 amount);
    event ETHWithdrawn(address indexed to, uint256 amount);
    event DepositedToGammaVault(uint256 indexed fwbAmount, uint256 indexed wethAmount, uint256 indexed gammaShares);
    event WithdrawnFromGammaVault(uint256 indexed fwbAmount, uint256 indexed wethAmount, uint256 indexed gammaShares);

    Vm private vm = Vm(HEVM_ADDRESS);

    FWBLiquidityProvisioningEscrow public fwbLiquidityProvisioningEscrow;

    address public constant LLAMA_MULTISIG = 0xA519a7cE7B24333055781133B13532AEabfAC81b;
    address public constant FWB_MULTISIG_1 = 0x33e626727B9Ecf64E09f600A1E0f5adDe266a0DF;
    address public constant FWB_MULTISIG_2 = 0x660F6D6c9BCD08b86B50e8e53B537F2B40f243Bd;

    // Temporarily setting WBTC-ETH Gamma Vault as placeholder -> Set later as FWB-ETH Gamma Vault once available
    IHypervisor public constant GAMMA = IHypervisor(0x35aBccd8e577607275647edAb08C537fa32CC65E);
    IERC20 public constant FWB = IERC20(0x35bD01FC9d6D5D81CA9E055Db88Dc49aa2c699A8);
    IWETH9 public constant WETH = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function setUp() public {
        fwbLiquidityProvisioningEscrow = new FWBLiquidityProvisioningEscrow();
        vm.label(address(fwbLiquidityProvisioningEscrow), "FWBLiquidityProvisioningEscrow");
    }

    function depositFWBFromDepositor(address depositor, uint256 amount) private {
        uint256 initialFWBBalanceDepositor = FWB.balanceOf(depositor);
        uint256 initialFWBBalanceLlamaEscrow = FWB.balanceOf(address(fwbLiquidityProvisioningEscrow));

        vm.assume(amount > 0 && amount <= initialFWBBalanceDepositor);

        vm.startPrank(depositor);
        FWB.approve(address(fwbLiquidityProvisioningEscrow), amount);

        vm.expectEmit(true, false, false, true);
        emit FWBDeposited(depositor, amount);
        fwbLiquidityProvisioningEscrow.depositFWB(amount);

        assertEq(initialFWBBalanceDepositor - amount, FWB.balanceOf(depositor));
        assertEq(initialFWBBalanceLlamaEscrow + amount, FWB.balanceOf(address(fwbLiquidityProvisioningEscrow)));
        assertEq(fwbLiquidityProvisioningEscrow.fwbBalance(), FWB.balanceOf(address(fwbLiquidityProvisioningEscrow)));
    }

    function testDepositFWBFromFM1(uint256 amount) public {
        depositFWBFromDepositor(FWB_MULTISIG_1, amount);
    }

    function testDepositFWBFromFM2(uint256 amount) public {
        depositFWBFromDepositor(FWB_MULTISIG_2, amount);
    }

    // Reminder to check storage balance with ERC20 balance in test suite through asserts
    // Reminder to check 0 values array in minIn and minAmounts parameters while depositing/withdrawing from Gamma vault
}
