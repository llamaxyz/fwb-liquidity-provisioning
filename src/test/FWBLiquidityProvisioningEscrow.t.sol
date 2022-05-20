// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.12;

// testing libraries
import "@ds/test.sol";
import "@std/console.sol";
import {stdCheats} from "@std/stdlib.sol";
import {stdError} from "@std/stdlib.sol";
import {Vm} from "@std/Vm.sol";
import {DSTestPlus} from "@solmate/test/utils/DSTestPlus.sol";

import {FWBLiquidityProvisioningEscrow} from "../FWBLiquidityProvisioningEscrow.sol";
import {IHypervisor} from "../external/IHypervisor.sol";
import {IWETH9} from "../external/IWETH9.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract FWBLiquidityProvisioningEscrowTest is DSTestPlus, stdCheats {
    event Deposit(address indexed asset, address indexed from, uint256 amount);
    event Withdraw(address indexed asset, address indexed to, uint256 amount);
    event DepositToGammaVault(uint256 gammaShares, uint256 fwbAmount, uint256 wethAmount);
    event WithdrawFromGammaVault(uint256 gammaShares, uint256 fwbAmount, uint256 wethAmount);

    Vm private vm = Vm(HEVM_ADDRESS);

    FWBLiquidityProvisioningEscrow public fwbLiquidityProvisioningEscrow;

    address public constant LLAMA_MULTISIG = 0xA519a7cE7B24333055781133B13532AEabfAC81b;
    address public constant FWB_MULTISIG_1 = 0x33e626727B9Ecf64E09f600A1E0f5adDe266a0DF;
    address public constant FWB_MULTISIG_2 = 0x660F6D6c9BCD08b86B50e8e53B537F2B40f243Bd;
    address public constant GAMMA_HYPERVISOR_OWNER = 0xADE38bd2E8D5A52E60047AfFe6E595bB5E61923A;

    IHypervisor public constant GAMMA = IHypervisor(0xe14DBB7D054fF1fF5C0cd6AdAc9f8F26Bc7B8945);
    IERC20 public constant FWB = IERC20(0x35bD01FC9d6D5D81CA9E055Db88Dc49aa2c699A8);
    IWETH9 public constant WETH = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function setUp() public {
        fwbLiquidityProvisioningEscrow = new FWBLiquidityProvisioningEscrow();
        vm.label(address(fwbLiquidityProvisioningEscrow), "FWBLiquidityProvisioningEscrow");
        vm.label(LLAMA_MULTISIG, "LLAMA_MULTISIG");
        vm.label(FWB_MULTISIG_1, "FWB_MULTISIG_1");
        vm.label(FWB_MULTISIG_2, "FWB_MULTISIG_2");
    }

    /*************************
     *   Utility functions   *
     *************************/

    function _depositFWBFromFWB(address depositor, uint256 amount) private {
        uint256 initialFWBBalanceDepositor = FWB.balanceOf(depositor);
        uint256 initialFWBBalanceLlamaEscrow = fwbLiquidityProvisioningEscrow.fwbBalance();

        vm.assume(amount > 0 && amount <= initialFWBBalanceDepositor);

        vm.startPrank(depositor);
        FWB.approve(address(fwbLiquidityProvisioningEscrow), amount);

        vm.expectEmit(true, true, false, true);
        emit Deposit(address(FWB), depositor, amount);
        fwbLiquidityProvisioningEscrow.depositFWB(amount);

        assertEq(initialFWBBalanceDepositor - amount, FWB.balanceOf(depositor));
        assertEq(initialFWBBalanceLlamaEscrow + amount, fwbLiquidityProvisioningEscrow.fwbBalance());
        assertEq(initialFWBBalanceLlamaEscrow + amount, FWB.balanceOf(address(fwbLiquidityProvisioningEscrow)));
    }

    function _initializeFWBBalance(address depositor, uint256 amount) private {
        vm.startPrank(depositor);
        FWB.approve(address(fwbLiquidityProvisioningEscrow), amount);
        fwbLiquidityProvisioningEscrow.depositFWB(amount);
        vm.stopPrank();
    }

    function _withdrawFWBFromFWB(address withdrawer, uint256 amount) private {
        uint256 initialFWBBalanceLlamaEscrow = fwbLiquidityProvisioningEscrow.fwbBalance();
        uint256 initialFWBBalanceWithdrawer = FWB.balanceOf(withdrawer);

        vm.assume(amount > 0 && amount <= initialFWBBalanceLlamaEscrow);

        vm.startPrank(withdrawer);

        vm.expectEmit(true, true, false, true);
        emit Withdraw(address(FWB), withdrawer, amount);
        fwbLiquidityProvisioningEscrow.withdrawFWB(amount);

        assertEq(initialFWBBalanceLlamaEscrow - amount, fwbLiquidityProvisioningEscrow.fwbBalance());
        assertEq(initialFWBBalanceLlamaEscrow - amount, FWB.balanceOf(address(fwbLiquidityProvisioningEscrow)));
        assertEq(initialFWBBalanceWithdrawer + amount, FWB.balanceOf(withdrawer));
    }

    function _depositETHFromFWB(address depositor, uint256 amount) private {
        uint256 initialETHBalanceDepositor = depositor.balance;
        uint256 initialWETHBalanceLlamaEscrow = fwbLiquidityProvisioningEscrow.wethBalance();

        vm.assume(amount > 0 && amount <= initialETHBalanceDepositor);

        vm.startPrank(depositor);

        vm.expectEmit(true, true, false, true);
        emit Deposit(address(WETH), depositor, amount);
        fwbLiquidityProvisioningEscrow.depositETH{value: amount}();

        assertEq(initialETHBalanceDepositor - amount, depositor.balance);
        assertEq(initialWETHBalanceLlamaEscrow + amount, fwbLiquidityProvisioningEscrow.wethBalance());
        assertEq(initialWETHBalanceLlamaEscrow + amount, WETH.balanceOf(address(fwbLiquidityProvisioningEscrow)));
    }

    function _initializeWETHBalance(address depositor, uint256 amount) private {
        vm.startPrank(depositor);
        fwbLiquidityProvisioningEscrow.depositETH{value: amount}();
        vm.stopPrank();
    }

    function _withdrawETHFromFWB(address withdrawer, uint256 amount) private {
        uint256 initialWETHBalanceLlamaEscrow = fwbLiquidityProvisioningEscrow.wethBalance();
        uint256 initialETHBalanceWithdrawer = withdrawer.balance;

        vm.assume(amount > 0 && amount <= initialWETHBalanceLlamaEscrow);

        vm.startPrank(withdrawer);

        vm.expectEmit(true, true, false, true);
        emit Withdraw(address(WETH), withdrawer, amount);
        fwbLiquidityProvisioningEscrow.withdrawETH(amount);

        assertEq(initialWETHBalanceLlamaEscrow - amount, fwbLiquidityProvisioningEscrow.wethBalance());
        assertEq(initialWETHBalanceLlamaEscrow - amount, WETH.balanceOf(address(fwbLiquidityProvisioningEscrow)));
        assertEq(initialETHBalanceWithdrawer + amount, withdrawer.balance);
    }

    function _setGammaHypervisorWhitelist() private {
        vm.startPrank(GAMMA_HYPERVISOR_OWNER);
        GAMMA.setWhitelist(address(fwbLiquidityProvisioningEscrow));
        vm.stopPrank();
    }

    function _depositToGammaVault(
        address caller,
        uint256 fwbAmount,
        uint256 wethAmount,
        uint256 expectedGammaShares
    ) private {
        uint256 initialFWBBalanceLlamaEscrow = fwbLiquidityProvisioningEscrow.fwbBalance();
        uint256 initialFWBBalanceGammaHypervisor = FWB.balanceOf(address(GAMMA));
        uint256 initialWETHBalanceLlamaEscrow = fwbLiquidityProvisioningEscrow.wethBalance();
        uint256 initialWETHBalanceGammaHypervisor = WETH.balanceOf(address(GAMMA));
        uint256 initialGammaSharesBalanceLlamaEscrow = fwbLiquidityProvisioningEscrow.gammaFwbWethSharesBalance();

        vm.startPrank(caller);

        vm.expectEmit(false, false, false, true);
        emit DepositToGammaVault(expectedGammaShares, fwbAmount, wethAmount);
        uint256 gammaFwbWethShares = fwbLiquidityProvisioningEscrow.depositToGammaVault(fwbAmount, wethAmount);

        assertEq(initialFWBBalanceLlamaEscrow - fwbAmount, fwbLiquidityProvisioningEscrow.fwbBalance());
        assertEq(initialFWBBalanceGammaHypervisor + fwbAmount, FWB.balanceOf(address(GAMMA)));
        assertEq(initialWETHBalanceLlamaEscrow - wethAmount, fwbLiquidityProvisioningEscrow.wethBalance());
        assertEq(initialWETHBalanceGammaHypervisor + wethAmount, WETH.balanceOf(address(GAMMA)));
        assertEq(
            initialGammaSharesBalanceLlamaEscrow + gammaFwbWethShares,
            fwbLiquidityProvisioningEscrow.gammaFwbWethSharesBalance()
        );
        assertEq(gammaFwbWethShares, expectedGammaShares);
    }

    function _initializeGammaSharesBalance(
        address caller,
        uint256 fwbAmount,
        uint256 wethAmount
    ) private {
        vm.startPrank(caller);
        fwbLiquidityProvisioningEscrow.depositToGammaVault(fwbAmount, wethAmount);
        vm.stopPrank();
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
        _depositFWBFromFWB(FWB_MULTISIG_1, amount);
    }

    function testDepositFWBFromFWB2(uint256 amount) public {
        _depositFWBFromFWB(FWB_MULTISIG_2, amount);
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

        vm.expectRevert(FWBLiquidityProvisioningEscrow.OnlyNonZeroAmount.selector);
        fwbLiquidityProvisioningEscrow.withdrawFWB(amount);
    }

    function testWithdrawFWBAmountGreaterThanBalance(uint256 amount) public {
        _initializeFWBBalance(FWB_MULTISIG_1, 100);
        vm.startPrank(FWB_MULTISIG_1);

        vm.assume(amount > 100);
        vm.expectRevert(stdError.arithmeticError);
        fwbLiquidityProvisioningEscrow.withdrawFWB(amount);
    }

    function testWithdrawFWBFromFWB1(uint256 amount) public {
        _initializeFWBBalance(FWB_MULTISIG_1, 1e18);
        _withdrawFWBFromFWB(FWB_MULTISIG_1, amount);
    }

    function testWithdrawFWBFromFWB2(uint256 amount) public {
        _initializeFWBBalance(FWB_MULTISIG_2, 1e18);
        _withdrawFWBFromFWB(FWB_MULTISIG_2, amount);
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

    function testDepositETHFromFWB1(uint256 amount) public {
        _depositETHFromFWB(FWB_MULTISIG_1, amount);
    }

    function testDepositETHFromFWB2(uint256 amount) public {
        _depositETHFromFWB(FWB_MULTISIG_2, amount);
    }

    /**********************************************
     *   withdrawETH(uint256 amount) Test Cases   *
     **********************************************/

    function testWithdrawETHFromNotFWB() public {
        uint256 amount = 100;
        vm.startPrank(address(0x1337));

        vm.expectRevert(FWBLiquidityProvisioningEscrow.OnlyFWB.selector);
        fwbLiquidityProvisioningEscrow.withdrawETH(amount);
    }

    function testWithdrawETHZeroAmount() public {
        uint256 amount = 0;
        vm.startPrank(FWB_MULTISIG_1);

        vm.expectRevert(FWBLiquidityProvisioningEscrow.OnlyNonZeroAmount.selector);
        fwbLiquidityProvisioningEscrow.withdrawETH(amount);
    }

    function testWithdrawETHAmountGreaterThanBalance(uint256 amount) public {
        _initializeWETHBalance(FWB_MULTISIG_1, 100);
        vm.startPrank(FWB_MULTISIG_1);

        vm.assume(amount > 100);
        vm.expectRevert(stdError.arithmeticError);
        fwbLiquidityProvisioningEscrow.withdrawETH(amount);
    }

    function testWithdrawETHFromFWB1(uint256 amount) public {
        _initializeWETHBalance(FWB_MULTISIG_1, 1e18);
        _withdrawETHFromFWB(FWB_MULTISIG_1, amount);
    }

    function testWithdrawETHFromFWB2(uint256 amount) public {
        _initializeWETHBalance(FWB_MULTISIG_2, 1e18);
        _withdrawETHFromFWB(FWB_MULTISIG_2, amount);
    }

    /*****************************************************************************
     *   depositToGammaVault(uint256 fwbAmount, uint256 wethAmount) Test Cases   *
     *****************************************************************************/

    function testDepositToGammaVaultFromNotFWBLlama() public {
        vm.startPrank(address(0x1337));

        vm.expectRevert(FWBLiquidityProvisioningEscrow.OnlyFWBLlama.selector);
        fwbLiquidityProvisioningEscrow.depositToGammaVault(100, 100);
    }

    function testDepositToGammaVaultZeroFWBAmount() public {
        vm.startPrank(FWB_MULTISIG_1);

        vm.expectRevert(FWBLiquidityProvisioningEscrow.OnlyNonZeroAmount.selector);
        fwbLiquidityProvisioningEscrow.depositToGammaVault(0, 100);
    }

    function testDepositToGammaVaultZeroWETHAmount() public {
        vm.startPrank(FWB_MULTISIG_1);

        vm.expectRevert(FWBLiquidityProvisioningEscrow.OnlyNonZeroAmount.selector);
        fwbLiquidityProvisioningEscrow.depositToGammaVault(100, 0);
    }

    function testDepositToGammaVaultZeroFWBZeroWETHAmount() public {
        vm.startPrank(FWB_MULTISIG_1);

        vm.expectRevert(FWBLiquidityProvisioningEscrow.OnlyNonZeroAmount.selector);
        fwbLiquidityProvisioningEscrow.depositToGammaVault(0, 0);
    }

    function testDepositToGammaVaultFWBAmountGreaterThanBalance(uint256 amount) public {
        _initializeFWBBalance(FWB_MULTISIG_1, 100);
        _initializeWETHBalance(FWB_MULTISIG_1, 100);
        vm.startPrank(FWB_MULTISIG_1);

        vm.assume(amount > 100);
        vm.expectRevert(stdError.arithmeticError);
        fwbLiquidityProvisioningEscrow.depositToGammaVault(amount, 100);
    }

    function testDepositToGammaVaultWETHAmountGreaterThanBalance(uint256 amount) public {
        _initializeFWBBalance(FWB_MULTISIG_1, 100);
        _initializeWETHBalance(FWB_MULTISIG_1, 100);
        vm.startPrank(FWB_MULTISIG_1);

        vm.assume(amount > 100);
        vm.expectRevert(stdError.arithmeticError);
        fwbLiquidityProvisioningEscrow.depositToGammaVault(100, amount);
    }

    function testDepositToGammaVaultCallingFromFWB1() public {
        _setGammaHypervisorWhitelist();
        _initializeFWBBalance(FWB_MULTISIG_1, 100);
        _initializeWETHBalance(FWB_MULTISIG_1, 10);
        _depositToGammaVault(FWB_MULTISIG_1, 100, 1, 2);
    }

    function testDepositToGammaVaultCallingFromFWB2() public {
        _setGammaHypervisorWhitelist();
        _initializeFWBBalance(FWB_MULTISIG_2, 100);
        _initializeWETHBalance(FWB_MULTISIG_2, 10);
        _depositToGammaVault(FWB_MULTISIG_2, 100, 1, 2);
    }

    function testDepositToGammaVaultCallingFromLlama() public {
        _setGammaHypervisorWhitelist();
        _initializeFWBBalance(FWB_MULTISIG_2, 100);
        _initializeWETHBalance(FWB_MULTISIG_2, 10);
        _depositToGammaVault(LLAMA_MULTISIG, 100, 1, 2);
    }

    function testFuzzDepositToGammaVault(uint256 fwbAmount, uint256 wethAmount) public {
        _setGammaHypervisorWhitelist();
        _initializeFWBBalance(FWB_MULTISIG_2, 1e22);
        _initializeWETHBalance(FWB_MULTISIG_1, 1e20);

        uint256 initialFWBBalanceLlamaEscrow = fwbLiquidityProvisioningEscrow.fwbBalance();
        uint256 initialFWBBalanceGammaHypervisor = FWB.balanceOf(address(GAMMA));
        uint256 initialWETHBalanceLlamaEscrow = fwbLiquidityProvisioningEscrow.wethBalance();
        uint256 initialWETHBalanceGammaHypervisor = WETH.balanceOf(address(GAMMA));
        uint256 initialGammaSharesBalanceLlamaEscrow = fwbLiquidityProvisioningEscrow.gammaFwbWethSharesBalance();

        vm.assume(
            fwbAmount > 0 &&
                fwbAmount <= initialFWBBalanceLlamaEscrow &&
                wethAmount > 0 &&
                wethAmount <= initialWETHBalanceLlamaEscrow
        );

        vm.startPrank(FWB_MULTISIG_1);
        uint256 gammaFwbWethShares = fwbLiquidityProvisioningEscrow.depositToGammaVault(fwbAmount, wethAmount);

        assertEq(initialFWBBalanceLlamaEscrow - fwbAmount, fwbLiquidityProvisioningEscrow.fwbBalance());
        assertEq(initialFWBBalanceGammaHypervisor + fwbAmount, FWB.balanceOf(address(GAMMA)));
        assertEq(initialWETHBalanceLlamaEscrow - wethAmount, fwbLiquidityProvisioningEscrow.wethBalance());
        assertEq(initialWETHBalanceGammaHypervisor + wethAmount, WETH.balanceOf(address(GAMMA)));
        assertEq(
            initialGammaSharesBalanceLlamaEscrow + gammaFwbWethShares,
            fwbLiquidityProvisioningEscrow.gammaFwbWethSharesBalance()
        );
    }

    /*********************************************************************
     *   withdrawFromGammaVault(uint256 gammaFwbWethShares) Test Cases   *
     *********************************************************************/

    function testWithdrawFromGammaVaultFromNotFWB() public {
        vm.startPrank(address(0x1337));

        vm.expectRevert(FWBLiquidityProvisioningEscrow.OnlyFWBLlama.selector);
        fwbLiquidityProvisioningEscrow.withdrawFromGammaVault(100);
    }

    function testWithdrawFromGammaVaultZeroGammaSharesAmount() public {
        vm.startPrank(FWB_MULTISIG_1);

        vm.expectRevert(FWBLiquidityProvisioningEscrow.OnlyNonZeroAmount.selector);
        fwbLiquidityProvisioningEscrow.withdrawFromGammaVault(0);
    }

    function testWithdrawFromGammaVaultGammaSharesAmountGreaterThanBalance(uint256 amount) public {
        _setGammaHypervisorWhitelist();
        _initializeFWBBalance(FWB_MULTISIG_1, 1e20);
        _initializeWETHBalance(FWB_MULTISIG_1, 1e18);
        _initializeGammaSharesBalance(FWB_MULTISIG_1, 1e20, 1e18);

        vm.startPrank(FWB_MULTISIG_1);

        vm.assume(amount > fwbLiquidityProvisioningEscrow.gammaFwbWethSharesBalance());
        vm.expectRevert(stdError.arithmeticError);
        fwbLiquidityProvisioningEscrow.withdrawFromGammaVault(amount);
    }
}
