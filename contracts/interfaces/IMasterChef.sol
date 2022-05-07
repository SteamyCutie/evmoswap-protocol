// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IOnwardIncentivesController.sol";

interface IMasterChef {
    function owner() external view returns (address);

    function emo() external view returns (address);

    function startTime() external view returns (uint256);

    function emoPerSecond() external view returns (uint256);

    function poolLength() external view returns (uint256);

    function totalAllocPoint() external view returns (uint256);

    function TOKENLESS_PRODUCTION() external view returns (uint256);

    function poolInfo(uint _pid) external view returns (
        address lpToken,
        uint256 workingSupply,
        bool boost,
        uint256 allocPoint,
        uint256 lastRewardTime,
        uint256 accEmoPerShare,
        address incentivesController);

    function userInfo(uint _pid, address _user) external view returns (
        uint256 amount,
        uint256 workingAmount,
        uint256 rewardDebt);

    // emo + bonus reward
    function pendingTokens(uint256 _pid, address _user) external view returns (address[] memory tokens, uint[] memory amounts);

    // Transfers ownership of the contract to a new account (`newOwner`)
    function transferOwnership(address newOwner) external;

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, uint256 _depositFeePercent, IERC20 _lpToken, IOnwardIncentivesController _incentivesController, bool _boost, bool _withUpdate) external;

    // Update the given pool's EMO allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint256 _depositFeePercent, IOnwardIncentivesController _incentivesController, bool _withUpdate) external;

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) external;

    // Stake EMO tokens to MasterChef
    function enterStaking(uint256 _amount) external;

    // Withdraw EMO tokens from STAKING.
    function leaveStaking(uint256 _amount) external;

    // Deposit LP tokens to MasterChef for EMO allocation.
    function depositFor(address _user, uint256 _pid, uint256 _amount) external;

    // Deposit LP tokens to MasterChef for EMO allocation.
    function deposit(uint _pid, uint _amount) external;

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint _pid, uint _amount) external;

    function harvestAllRewards(address _user) external;

    function emergencyWithdraw(uint256 _pid) external;

    function setEmoPerSecond(uint256 _emoPerSecond) external;
}