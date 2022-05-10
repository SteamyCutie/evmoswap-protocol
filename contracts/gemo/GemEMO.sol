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

    constructor () public RBEP20(500000000 * 1e18, "Gem EMO Token", "GEMO", 18, 200) {}

}