// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.12;

interface IWETH9 {
    function balanceOf(address) external view returns (uint256);

    function allowance(address, address) external view returns (uint256);

    function deposit() external payable;

    function withdraw(uint256 wad) external;

    function approve(address guy, uint256 wad) external returns (bool);

    function transfer(address dst, uint256 wad) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);
}
