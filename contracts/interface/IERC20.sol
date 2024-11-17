// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.4;

interface IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
