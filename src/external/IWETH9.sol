// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.12;

interface IWETH9 {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    function deposit() external payable;

    function withdraw(uint256 wad) external;
}
