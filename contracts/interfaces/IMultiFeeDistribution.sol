// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IMultiFeeDistribution {
    function mint(address user, uint256 amount, bool withPenalty) external;
}
