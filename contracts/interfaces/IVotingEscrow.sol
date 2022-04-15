// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IVotingEscrow {
    function balanceOfT(address addr, uint256 _t) external view returns (uint256);

    function decimals() external view returns (uint8);
}
