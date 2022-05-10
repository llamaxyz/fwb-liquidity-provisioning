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

    address public constant LLAMA_MULTISIG = 0xA519a7cE7B24333055781133B13532AEabfAC81b;
    address payable public constant FWB_MULTISIG = payable(0x660F6D6c9BCD08b86B50e8e53B537F2B40f243Bd);

    // Temporarily setting WBTC-ETH Gamma Vault as placeholder -> Set later as FWB-ETH Gamma Vault once available
    IHypervisor public constant GAMMA = IHypervisor(0x35aBccd8e577607275647edAb08C537fa32CC65E);
    IERC20 public constant FWB = IERC20(0x35bD01FC9d6D5D81CA9E055Db88Dc49aa2c699A8);
    IWETH9 public constant WETH = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    uint256 public gammaFwbWethSharesBalance;
    uint256 public fwbBalance;
    uint256 public wethBalance;

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

    error OnlyNonZeroAmount();
    modifier onlyNonZeroAmount(uint256 amount) {
        if (amount == 0) revert OnlyNonZeroAmount();
        _;
    }

    error CheckAmount();
    modifier checkAmount(uint256 amount, uint256 balance) {
        if (amount == 0 || amount > balance) revert CheckAmount();
        _;
    }

    // What other checks are required ??
    function depositFWBToEscrow(uint256 _fwbAmount) external onlyFWB onlyNonZeroAmount(_fwbAmount) {
        fwbBalance += _fwbAmount;
        // Transfer token from FWB (sender). FWB (sender) must have first approved them.
        FWB.safeTransferFrom(msg.sender, address(this), _fwbAmount);
        assert(fwbBalance == FWB.balanceOf(address(this)));
    }

    // What other checks are required ??
    function withdrawFWBFromEscrow(uint256 _fwbAmount) external onlyFWB checkAmount(_fwbAmount, fwbBalance) {
        fwbBalance -= _fwbAmount;
        FWB.safeTransfer(msg.sender, _fwbAmount);
        assert(fwbBalance == FWB.balanceOf(address(this)));
    }

    // What other checks are required ??
    function depositETHToEscrow() external payable onlyFWB onlyNonZeroAmount(msg.value) {
        wethBalance += msg.value;
        WETH.deposit();
        assert(wethBalance == WETH.balanceOf(address(this)));
    }

    // What other checks are required ??
    function withdrawETHFromEscrow(uint256 _wethAmount) external onlyFWB checkAmount(_wethAmount, wethBalance) {
        wethBalance -= _wethAmount;
        WETH.withdraw(_wethAmount);
        assert(wethBalance == WETH.balanceOf(address(this)));
    }

    // What other checks are required ??
    function depositToGammaVault(uint256 _fwbAmount, uint256 _wethAmount)
        external
        onlyFWBLlama
        checkAmount(_fwbAmount, fwbBalance)
        checkAmount(_wethAmount, wethBalance)
    {
        // Should we be setting some values for these ??
        uint256[4] memory minIn = [uint256(0), uint256(0), uint256(0), uint256(0)];

        fwbBalance -= _fwbAmount;
        wethBalance -= _wethAmount;

        FWB.approve(address(GAMMA), _fwbAmount);
        WETH.approve(address(GAMMA), _wethAmount);
        uint256 gammaFwbWethShares = GAMMA.deposit(_fwbAmount, _wethAmount, address(this), address(this), minIn);

        gammaFwbWethSharesBalance += gammaFwbWethShares;

        assert(fwbBalance == FWB.balanceOf(address(this)));
        assert(wethBalance == WETH.balanceOf(address(this)));
        assert(gammaFwbWethSharesBalance == GAMMA.balanceOf(address(this)));
    }

    // What other checks are required ??
    function withdrawFromGammaVault(uint256 _gammaFwbWethShares)
        external
        onlyFWBLlama
        checkAmount(_gammaFwbWethShares, gammaFwbWethSharesBalance)
    {
        // Should we be setting some values for these ??
        uint256[4] memory minAmounts = [uint256(0), uint256(0), uint256(0), uint256(0)];

        gammaFwbWethSharesBalance -= _gammaFwbWethShares;

        GAMMA.approve(address(GAMMA), _gammaFwbWethShares);
        (uint256 _fwbAmount, uint256 _wethAmount) = GAMMA.withdraw(
            _gammaFwbWethShares,
            address(this),
            address(this),
            minAmounts
        );

        fwbBalance += _fwbAmount;
        wethBalance += _wethAmount;

        assert(fwbBalance == FWB.balanceOf(address(this)));
        assert(wethBalance == WETH.balanceOf(address(this)));
        assert(gammaFwbWethSharesBalance == GAMMA.balanceOf(address(this)));
    }
}
