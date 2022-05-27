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

    address public constant LLAMA_MULTISIG = 0x03C82B63B276c0D3050A49210c31036d3155e705;
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
    event DepositToGammaVault(uint256 gammaShares, uint256 fwbAmount, uint256 wethAmount);
    event WithdrawFromGammaVault(uint256 gammaShares, uint256 fwbAmount, uint256 wethAmount);

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

    error OnlyNonZeroAmount();

    /*****************
     *   FUNCTIONS   *
     *****************/

    receive() external payable {}

    fallback() external payable {}

    function depositFWB(uint256 amount) external onlyFWB {
        fwbBalance += amount;
        // Transfer token from FWB (sender). FWB (sender) must have first approved them.
        FWB.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(address(FWB), msg.sender, amount);
    }

    function withdrawFWB(uint256 amount) external onlyFWB {
        fwbBalance -= amount;
        FWB.safeTransfer(msg.sender, amount);
        emit Withdraw(address(FWB), msg.sender, amount);
    }

    function depositETH() external payable onlyFWB {
        wethBalance += msg.value;
        WETH.deposit{value: msg.value}();
        emit Deposit(address(WETH), msg.sender, msg.value);
    }

    function withdrawETH(uint256 amount) external onlyFWB {
        wethBalance -= amount;
        WETH.withdraw(amount);
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "WITHDRAW_TO_CALL_FAILED");
        emit Withdraw(address(WETH), msg.sender, amount);
    }

    function depositToGammaVault(uint256 fwbAmount, uint256 wethAmount)
        external
        onlyFWBLlama
        returns (uint256 gammaFwbWethShares)
    {
        if ((fwbAmount == 0) && (wethAmount == 0)) revert OnlyNonZeroAmount();
        uint256[4] memory minIn = [uint256(0), uint256(0), uint256(0), uint256(0)];

        fwbBalance -= fwbAmount;
        wethBalance -= wethAmount;

        FWB.approve(address(GAMMA), fwbAmount);
        WETH.approve(address(GAMMA), wethAmount);
        gammaFwbWethShares = GAMMA.deposit(fwbAmount, wethAmount, address(this), address(this), minIn);

        gammaFwbWethSharesBalance += gammaFwbWethShares;

        emit DepositToGammaVault(gammaFwbWethShares, fwbAmount, wethAmount);
    }

    function withdrawFromGammaVault(uint256 gammaFwbWethShares, uint256[4] memory minOut)
        external
        onlyFWBLlama
        returns (uint256 fwbAmount, uint256 wethAmount)
    {
        if (gammaFwbWethShares == 0) revert OnlyNonZeroAmount();

        gammaFwbWethSharesBalance -= gammaFwbWethShares;

        GAMMA.approve(address(GAMMA), gammaFwbWethShares);
        (fwbAmount, wethAmount) = GAMMA.withdraw(gammaFwbWethShares, address(this), address(this), minOut);

        fwbBalance += fwbAmount;
        wethBalance += wethAmount;

        emit WithdrawFromGammaVault(gammaFwbWethShares, fwbAmount, wethAmount);
    }
}
