// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IRewardPool {
    function depositFor(address _user, uint256 _amount) external returns(bool);

    function withdrawFor(address _user, uint256 _principals) external returns(bool);

    function emergencyWithdraw(address _user) external;
}
