// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/*
 * EvmoSwap
 * App:             https://app.evmoswap.org/
 * Medium:          https://evmoswap.medium.com/
 * GitHub:          https://github.com/evmoswap/
 */

import "./RBEP20.sol";

contract GemEMO is RBEP20 {

    constructor (uint256 initialSupply) public RBEP20(initialSupply, "Gem EMO Token", "GEMO", 18, 200) {}

}