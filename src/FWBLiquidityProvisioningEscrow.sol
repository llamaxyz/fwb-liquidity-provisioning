// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.12;

import {IHypervisor} from "./external/IHypervisor.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract FWBLiquidityProvisioningEscrow {
    // Temporarily setting WBTC-ETH Gamma Vault as placeholder -> Set later as FWB-ETH Gamma Vault
    IHypervisor private constant GAMMA_FWB_VAULT = IHypervisor(0x35aBccd8e577607275647edAb08C537fa32CC65E);
    IERC20 private constant FWB = IERC20(0x35bD01FC9d6D5D81CA9E055Db88Dc49aa2c699A8);
    IERC20 private constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    address private constant LLAMA_MULTISIG = 0xA519a7cE7B24333055781133B13532AEabfAC81b;
    address private constant FWB_MULTISIG = 0x660F6D6c9BCD08b86B50e8e53B537F2B40f243Bd;

    uint256 private gammaFwbWethSharesBalance;
    uint256 private fwbBalance;
    uint256 private wethBalance;

    error OnlyFWB();
    modifier onlyFWB() {
        if (msg.sender != FWB_MULTISIG) revert OnlyFWB();
        _;
    }

    error OnlyLlama();
    modifier onlyLlama() {
        if (msg.sender != LLAMA_MULTISIG) revert OnlyLlama();
        _;
    }

    // What other checks are required ??
    function depositToEscrow() external onlyFWB {}

    // What other checks are required ??
    function withdrawFromEscrow() external onlyFWB {}

    // What other checks are required ??
    // Check on can't deposit with no fwb or weth tokens in existence in escrow.
    function depositToGammaVault(uint256 _fwbBalance, uint256 _wethBalance) external onlyFWB onlyLlama {
        // Should we be setting some values for these ??
        uint256[4] memory minIn = [uint256(0), uint256(0), uint256(0), uint256(0)];

        fwbBalance -= _fwbBalance;
        wethBalance -= _wethBalance;

        gammaFwbWethSharesBalance = GAMMA_FWB_VAULT.deposit(
            _fwbBalance,
            _wethBalance,
            address(this),
            address(this),
            minIn
        );
    }

    // What other checks are required ??
    // Should there be a check/assert on tokenBalance == token.balanceOf() ??
    // Check on can't withdraw with no gamma shares in existince in escrow
    function withdrawFromGammaVault(uint256 _gammaFwbWethShares) external onlyFWB onlyLlama {
        // Should we be setting some values for these ??
        uint256[4] memory minAmounts = [uint256(0), uint256(0), uint256(0), uint256(0)];

        gammaFwbWethSharesBalance -= _gammaFwbWethShares;

        (uint256 _fwbBalance, uint256 _wethBalance) = GAMMA_FWB_VAULT.withdraw(
            gammaFwbWethSharesBalance,
            address(this),
            address(this),
            minAmounts
        );

        fwbBalance += _fwbBalance;
        wethBalance += _wethBalance;
    }
}
