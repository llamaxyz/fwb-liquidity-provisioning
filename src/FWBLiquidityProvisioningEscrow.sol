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
    address public constant FWB_MULTISIG_1 = 0x33e626727B9Ecf64E09f600A1E0f5adDe266a0DF;
    address public constant FWB_MULTISIG_2 = 0x660F6D6c9BCD08b86B50e8e53B537F2B40f243Bd;

    IHypervisor public constant GAMMA = IHypervisor(0xe14DBB7D054fF1fF5C0cd6AdAc9f8F26Bc7B8945);
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

    event Deposit(address indexed asset, address indexed from, uint256 amount);
    event Withdraw(address indexed asset, address indexed to, uint256 amount);
    event DepositToGammaVault(uint256 fwbAmount, uint256 wethAmount, uint256 gammaShares);
    event WithdrawFromGammaVault(uint256 fwbAmount, uint256 wethAmount, uint256 gammaShares);

    /****************************
     *   ERRORS AND MODIFIERS   *
     ****************************/

    error OnlyFWB();
    modifier onlyFWB() {
        if ((msg.sender != FWB_MULTISIG_1) && (msg.sender != FWB_MULTISIG_2)) revert OnlyFWB();
        _;
    }

    error OnlyFWBLlama();
    modifier onlyFWBLlama() {
        if ((msg.sender != FWB_MULTISIG_1) && (msg.sender != FWB_MULTISIG_2) && (msg.sender != LLAMA_MULTISIG))
            revert OnlyFWBLlama();
        _;
    }

    error CheckAmount();
    modifier checkAmount(uint256 amount, uint256 balance) {
        if (amount == 0 || amount > balance) revert CheckAmount();
        _;
    }

    error OnlyNonZeroAmount();
    modifier onlyNonZeroAmount(uint256 amount) {
        if (amount == 0) revert OnlyNonZeroAmount();
        _;
    }

    /*****************
     *   FUNCTIONS   *
     *****************/

    receive() external payable {}

    fallback() external payable {}

    function depositFWB(uint256 amount) external onlyFWB onlyNonZeroAmount(amount) {
        fwbBalance += amount;
        // Transfer token from FWB (sender). FWB (sender) must have first approved them.
        FWB.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(address(FWB), msg.sender, amount);
    }

    function withdrawFWB(uint256 amount) external onlyFWB checkAmount(amount, fwbBalance) {
        fwbBalance -= amount;
        FWB.safeTransfer(msg.sender, amount);
        emit Withdraw(address(FWB), msg.sender, amount);
    }

    function depositETH() external payable onlyFWB onlyNonZeroAmount(msg.value) {
        wethBalance += msg.value;
        WETH.deposit{value: msg.value}();
        emit Deposit(address(WETH), msg.sender, msg.value);
    }

    function withdrawETH(uint256 amount) external onlyFWB checkAmount(amount, wethBalance) {
        wethBalance -= amount;
        WETH.withdraw(amount);
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "WITHDRAW_TO_CALL_FAILED");
        emit Withdraw(address(WETH), msg.sender, amount);
    }

    function depositToGammaVault(uint256 fwbAmount, uint256 wethAmount)
        external
        onlyFWBLlama
        checkAmount(fwbAmount, fwbBalance)
        checkAmount(wethAmount, wethBalance)
    {
        uint256[4] memory minIn = [uint256(0), uint256(0), uint256(0), uint256(0)];

        fwbBalance -= fwbAmount;
        wethBalance -= wethAmount;

        FWB.approve(address(GAMMA), fwbAmount);
        WETH.approve(address(GAMMA), wethAmount);
        uint256 gammaFwbWethShares = GAMMA.deposit(fwbAmount, wethAmount, address(this), address(this), minIn);

        gammaFwbWethSharesBalance += gammaFwbWethShares;

        emit DepositToGammaVault(fwbAmount, wethAmount, gammaFwbWethShares);
    }

    function withdrawFromGammaVault(uint256 gammaFwbWethShares)
        external
        onlyFWBLlama
        checkAmount(gammaFwbWethShares, gammaFwbWethSharesBalance)
    {
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

        emit WithdrawFromGammaVault(fwbAmount, wethAmount, gammaFwbWethShares);
    }
}
