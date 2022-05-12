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
        vm.label(LLAMA_MULTISIG, "LLAMA_MULTISIG");
        vm.label(FWB_MULTISIG_1, "FWB_MULTISIG_1");
        vm.label(FWB_MULTISIG_2, "FWB_MULTISIG_2");
    }

    /*********************************************
     *   depositFWB(uint256 amount) Test Cases   *
     *********************************************/

    function testDepositFWBFromNotFWB() public {
        uint256 amount = 100;
        vm.startPrank(address(0x1337));
        FWB.approve(address(fwbLiquidityProvisioningEscrow), amount);

        vm.expectRevert(FWBLiquidityProvisioningEscrow.OnlyFWB.selector);
        fwbLiquidityProvisioningEscrow.depositFWB(amount);
    }

    function testDepositFWBZeroAmount() public {
        uint256 amount = 0;
        vm.startPrank(FWB_MULTISIG_1);
        FWB.approve(address(fwbLiquidityProvisioningEscrow), amount);

        vm.expectRevert(FWBLiquidityProvisioningEscrow.OnlyNonZeroAmount.selector);
        fwbLiquidityProvisioningEscrow.depositFWB(amount);
    }

    function testDepositFWBFromFWB1(uint256 amount) public {
        depositFWBFromFWB(FWB_MULTISIG_1, amount);
    }

    function testDepositFWBFromFWB2(uint256 amount) public {
        depositFWBFromFWB(FWB_MULTISIG_2, amount);
    }

    function depositFWBFromFWB(address depositor, uint256 amount) private {
        uint256 initialFWBBalanceDepositor = FWB.balanceOf(depositor);
        uint256 initialFWBBalanceLlamaEscrow = fwbLiquidityProvisioningEscrow.fwbBalance();

        vm.assume(amount > 0 && amount <= initialFWBBalanceDepositor);

        vm.startPrank(depositor);
        FWB.approve(address(fwbLiquidityProvisioningEscrow), amount);

        vm.expectEmit(true, false, false, true);
        emit FWBDeposited(depositor, amount);
        fwbLiquidityProvisioningEscrow.depositFWB(amount);

        assertEq(initialFWBBalanceDepositor - amount, FWB.balanceOf(depositor));
        assertEq(initialFWBBalanceLlamaEscrow + amount, fwbLiquidityProvisioningEscrow.fwbBalance());
    }

    /**********************************************
     *   withdrawFWB(uint256 amount) Test Cases   *
     **********************************************/

    function testWithdrawFWBFromNotFWB() public {
        uint256 amount = 100;
        vm.startPrank(address(0x1337));

        vm.expectRevert(FWBLiquidityProvisioningEscrow.OnlyFWB.selector);
        fwbLiquidityProvisioningEscrow.withdrawFWB(amount);
    }

    function testWithdrawFWBZeroAmount() public {
        uint256 amount = 0;
        vm.startPrank(FWB_MULTISIG_1);

        vm.expectRevert(FWBLiquidityProvisioningEscrow.CheckAmount.selector);
        fwbLiquidityProvisioningEscrow.withdrawFWB(amount);
    }

    function testWithdrawFWBAmountGreaterThanBalance(uint256 amount) public {
        initializeFWBBalance(FWB_MULTISIG_1, 100);
        vm.startPrank(FWB_MULTISIG_1);

        vm.assume(amount > 100);
        vm.expectRevert(FWBLiquidityProvisioningEscrow.CheckAmount.selector);
        fwbLiquidityProvisioningEscrow.withdrawFWB(amount);
    }

    function testWithdrawFWBFromFWB1(uint256 amount) public {
        initializeFWBBalance(FWB_MULTISIG_1, 1e18);
        withdrawFWBFromFWB(FWB_MULTISIG_1, amount);
    }

    function testWithdrawFWBFromFWB2(uint256 amount) public {
        initializeFWBBalance(FWB_MULTISIG_2, 1e18);
        withdrawFWBFromFWB(FWB_MULTISIG_2, amount);
    }

    function initializeFWBBalance(address depositor, uint256 amount) private {
        vm.startPrank(depositor);
        FWB.approve(address(fwbLiquidityProvisioningEscrow), amount);
        fwbLiquidityProvisioningEscrow.depositFWB(amount);
        vm.stopPrank();
    }

    function withdrawFWBFromFWB(address withdrawer, uint256 amount) private {
        uint256 initialFWBBalanceLlamaEscrow = fwbLiquidityProvisioningEscrow.fwbBalance();
        uint256 initialFWBBalanceWithdrawer = FWB.balanceOf(withdrawer);

        vm.assume(amount > 0 && amount <= initialFWBBalanceLlamaEscrow);

        vm.startPrank(withdrawer);

        vm.expectEmit(true, false, false, true);
        emit FWBWithdrawn(withdrawer, amount);
        fwbLiquidityProvisioningEscrow.withdrawFWB(amount);

        assertEq(initialFWBBalanceLlamaEscrow - amount, fwbLiquidityProvisioningEscrow.fwbBalance());
        assertEq(initialFWBBalanceWithdrawer + amount, FWB.balanceOf(withdrawer));
    }

    /*******************************
     *   depositETH() Test Cases   *
     *******************************/

    function testDepositETHFromNotFWB() public {
        vm.startPrank(address(0x1337));

        vm.expectRevert(FWBLiquidityProvisioningEscrow.OnlyFWB.selector);
        fwbLiquidityProvisioningEscrow.depositETH{value: 100}();
    }

    function testDepositETHZeroAmount() public {
        vm.startPrank(FWB_MULTISIG_1);

        vm.expectRevert(FWBLiquidityProvisioningEscrow.OnlyNonZeroAmount.selector);
        fwbLiquidityProvisioningEscrow.depositETH{value: 0}();
    }

    // Reminder to check 0 values array in minIn and minAmounts parameters while depositing/withdrawing from Gamma vault
}
