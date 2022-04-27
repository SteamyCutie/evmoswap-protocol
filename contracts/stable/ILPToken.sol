// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./ISwap.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILPToken is IERC20 {
    function swap() external view returns (ISwap);
}
