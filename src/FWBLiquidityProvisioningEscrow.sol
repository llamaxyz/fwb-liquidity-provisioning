// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.12;

import {IHypervisor} from "./external/IHypervisor.sol";
import {IWETH9} from "./external/IWETH9.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

/// @title Llama escrow contract between FWB and Gamma Strategies
/// @author Llama
contract FWBLiquidityProvisioningEscrow {
    using SafeERC20 for IERC20;

    /********************************
     *   CONSTANTS AND IMMUTABLES   *
     ********************************/

    address public constant LLAMA_MULTISIG = 0xA519a7cE7B24333055781133B13532AEabfAC81b;
    address payable public constant FWB_MULTISIG = payable(0x660F6D6c9BCD08b86B50e8e53B537F2B40f243Bd);

    // Temporarily setting WBTC-ETH Gamma Vault as placeholder -> Set later as FWB-ETH Gamma Vault once available
    IHypervisor public constant GAMMA = IHypervisor(0x35aBccd8e577607275647edAb08C537fa32CC65E);
    IERC20 public constant FWB = IERC20(0x35bD01FC9d6D5D81CA9E055Db88Dc49aa2c699A8);
    IWETH9 public constant WETH = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    /*************************
     *   STORAGE VARIABLES   *
     *************************/

    uint256 public gammaFwbWethSharesBalance;
    uint256 public fwbBalance;
    uint256 public wethBalance;

    /**************
     *   EVENTS   *
     **************/

    event FWBDeposited(uint256 amount);
    event FWBWithdrawn(uint256 amount);
    event ETHDeposited(uint256 amount);
    event ETHWithdrawn(uint256 amount);
    event DepositedToGammaVault(uint256 indexed fwbAmount, uint256 indexed wethAmount, uint256 indexed gammaShares);
    event WithdrawnFromGammaVault(uint256 indexed fwbAmount, uint256 indexed wethAmount, uint256 indexed gammaShares);

    /****************************
     *   ERRORS AND MODIFIERS   *
     ****************************/

    error OnlyFWB();
    modifier onlyFWB() {
        if (msg.sender != FWB_MULTISIG) revert OnlyFWB();
        _;
    }

    error OnlyFWBLlama();
    modifier onlyFWBLlama() {
        if ((msg.sender != FWB_MULTISIG) && (msg.sender != LLAMA_MULTISIG)) revert OnlyFWBLlama();
        _;
    }

    error CheckAmount();
    modifier checkAmount(uint256 amount, uint256 balance) {
        if (amount == 0 || amount > balance) revert CheckAmount();
        _;
    }

    error OnlyNonZeroAmount();

    /*****************
     *   FUNCTIONS   *
     *****************/

    // What other checks are required ??
    function depositFWB(uint256 amount) external onlyFWB {
        if (amount == 0) revert OnlyNonZeroAmount();
        fwbBalance += amount;
        // Transfer token from FWB (sender). FWB (sender) must have first approved them.
        FWB.safeTransferFrom(msg.sender, address(this), amount);
        emit FWBDeposited(amount);
    }

    // What other checks are required ??
    function withdrawFWB(uint256 amount) external onlyFWB checkAmount(amount, fwbBalance) {
        fwbBalance -= amount;
        FWB.safeTransfer(msg.sender, amount);
        emit FWBWithdrawn(amount);
    }

    // What other checks are required ??
    function depositETH() external payable onlyFWB {
        if (msg.value == 0) revert OnlyNonZeroAmount();
        wethBalance += msg.value;
        WETH.deposit();
        emit ETHDeposited(msg.value);
    }

    // What other checks are required ??
    function withdrawETH(uint256 amount) external onlyFWB checkAmount(amount, wethBalance) {
        wethBalance -= amount;
        WETH.withdraw(amount);
        emit ETHWithdrawn(amount);
    }

    // What other checks are required ??
    function depositToGammaVault(uint256 fwbAmount, uint256 wethAmount)
        external
        onlyFWBLlama
        checkAmount(fwbAmount, fwbBalance)
        checkAmount(wethAmount, wethBalance)
    {
        // Should we be setting some values for these ??
        uint256[4] memory minIn = [uint256(0), uint256(0), uint256(0), uint256(0)];

        fwbBalance -= fwbAmount;
        wethBalance -= wethAmount;

        FWB.approve(address(GAMMA), fwbAmount);
        WETH.approve(address(GAMMA), wethAmount);
        uint256 gammaFwbWethShares = GAMMA.deposit(fwbAmount, wethAmount, address(this), address(this), minIn);

        gammaFwbWethSharesBalance += gammaFwbWethShares;

        emit DepositedToGammaVault(fwbAmount, wethAmount, gammaFwbWethShares);
    }

    // What other checks are required ??
    function withdrawFromGammaVault(uint256 gammaFwbWethShares)
        external
        onlyFWBLlama
        checkAmount(gammaFwbWethShares, gammaFwbWethSharesBalance)
    {
        // Should we be setting some values for these ??
        uint256[4] memory minAmounts = [uint256(0), uint256(0), uint256(0), uint256(0)];

        gammaFwbWethSharesBalance -= gammaFwbWethShares;

        GAMMA.approve(address(GAMMA), gammaFwbWethShares);
        (uint256 fwbAmount, uint256 wethAmount) = GAMMA.withdraw(
            gammaFwbWethShares,
            address(this),
            address(this),
            minAmounts
        );

        fwbBalance += fwbAmount;
        wethBalance += wethAmount;

        emit WithdrawnFromGammaVault(fwbAmount, wethAmount, gammaFwbWethShares);
    }
}
