// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/IOnwardIncentivesController.sol";

contract SimpleIncentivesController is IOnwardIncentivesController, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public immutable override rewardToken;
    IERC20 public immutable lpToken;
    bool public immutable isNative;
    // It is who call onReward method
    address public immutable operator;
    // always be masterchef
    address public immutable originUser;

    address private _nextIncentivesController;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 unpaidRewards;
    }

    struct PoolInfo {
        uint256 accTokenPerShare;
        uint256 lastRewardTimestamp;
    }

    PoolInfo public poolInfo;
    /// @notice Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    uint256 public tokenPerSec;

    uint256 private ACC_TOKEN_PRECISION;

    event OnReward(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);

    modifier onlyOperator() {
        require(msg.sender == operator, "onlyOperator: only operator can call this function");
        _;
    }

    constructor(
        IERC20 _rewardToken,
        IERC20 _lpToken,
        uint256 _tokenPerSec,
        address _operator,
        address _originUser,
        bool _isNative
    ) public {
        require(Address.isContract(address(_rewardToken)), "constructor: reward token must be a valid contract");
        require(Address.isContract(address(_lpToken)), "constructor: LP token must be a valid contract");
        require(Address.isContract(_operator), "constructor: operator must be a valid contract");
        require(Address.isContract(_originUser), "constructor: originUser must be a valid contract");
        require(_tokenPerSec <= 1e30, "constructor: token per seconds can't be greater than 1e30");

        rewardToken = _rewardToken;
        lpToken = _lpToken;
        tokenPerSec = _tokenPerSec;
        operator = _operator;
        originUser = _originUser;
        isNative = _isNative;
        poolInfo = PoolInfo({lastRewardTimestamp: block.timestamp, accTokenPerShare: 0});

        // Given the fraction, tokenReward * ACC_TOKEN_PRECISION / lpSupply
        ACC_TOKEN_PRECISION = 1e36;
    }

    /// @notice Update reward variables of the given poolInfo.
    /// @return pool Returns the pool that was updated.
    function updatePool() public returns (PoolInfo memory pool) {
        pool = poolInfo;

        if (block.timestamp > pool.lastRewardTimestamp) {
            uint256 lpSupply = lpToken.balanceOf(originUser);

            if (lpSupply > 0) {
                uint256 timeElapsed = block.timestamp.sub(pool.lastRewardTimestamp);
                uint256 tokenReward = timeElapsed.mul(tokenPerSec);
                pool.accTokenPerShare = pool.accTokenPerShare.add((tokenReward.mul(ACC_TOKEN_PRECISION) / lpSupply));
            }

            pool.lastRewardTimestamp = block.timestamp;
            poolInfo = pool;
        }
    }

    function setNextIncentivesController(address nextIncentivesController) external onlyOwner {
        _nextIncentivesController = nextIncentivesController;
    }

    /// @notice Sets the distribution reward rate. This will also update the poolInfo.
    /// @param _tokenPerSec The number of tokens to distribute per second
    function setRewardRate(uint256 _tokenPerSec) external onlyOwner {
        updatePool();

        uint256 oldRate = tokenPerSec;
        tokenPerSec = _tokenPerSec;

        emit RewardRateUpdated(oldRate, _tokenPerSec);
    }

    /// @notice Function called by operator whenever staker claims harvest. Allows staker to also receive a 2nd reward token.
    /// @param _user Address of user
    /// @param _lpAmount Number of LP tokens the user has
    function onReward(address _user, uint256 _lpAmount) external override onlyOperator nonReentrant {
        updatePool();
        PoolInfo memory pool = poolInfo;
        UserInfo storage user = userInfo[_user];
        uint256 pending;
        if (user.amount > 0) {
            pending = (user.amount.mul(pool.accTokenPerShare) / ACC_TOKEN_PRECISION).sub(user.rewardDebt).add(
                user.unpaidRewards
            );

            if (isNative) {
                uint256 balance = address(this).balance;
                if (pending > balance) {
                    (bool success,) = _user.call{value : balance}("");
                    require(success, "Transfer failed");
                    user.unpaidRewards = pending - balance;
                } else {
                    (bool success,) = _user.call{value : pending}("");
                    require(success, "Transfer failed");
                    user.unpaidRewards = 0;
                }
            } else {
                uint256 balance = rewardToken.balanceOf(address(this));
                if (pending > balance) {
                    rewardToken.safeTransfer(_user, balance);
                    user.unpaidRewards = pending - balance;
                } else {
                    rewardToken.safeTransfer(_user, pending);
                    user.unpaidRewards = 0;
                }
            }
        }

        user.amount = _lpAmount;
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare) / ACC_TOKEN_PRECISION;

        // Interactions
        if (_nextIncentivesController != address(0)) {
            IOnwardIncentivesController(_nextIncentivesController).onReward(_user, _lpAmount);
        }

        emit OnReward(_user, pending - user.unpaidRewards);
    }

    /// @notice View function to see pending tokens
    /// @param _user Address of user.
    /// @return pending reward for a given user.
    function pendingTokens(address _user) external view override returns (uint256 pending) {
        PoolInfo memory pool = poolInfo;
        UserInfo storage user = userInfo[_user];

        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = lpToken.balanceOf(originUser);

        if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
            uint256 timeElapsed = block.timestamp.sub(pool.lastRewardTimestamp);
            uint256 tokenReward = timeElapsed.mul(tokenPerSec);
            accTokenPerShare = accTokenPerShare.add(tokenReward.mul(ACC_TOKEN_PRECISION).div(lpSupply));
        }

        pending = (user.amount.mul(accTokenPerShare) / ACC_TOKEN_PRECISION).sub(user.rewardDebt).add(
            user.unpaidRewards
        );
    }

    /// @notice In case rewarder is stopped before emissions finished, this function allows
    /// withdrawal of remaining tokens.
    function emergencyWithdraw() public onlyOwner {
        if (isNative) {
            (bool success,) = msg.sender.call{value : address(this).balance}("");
            require(success, "Transfer failed");
        } else {
            rewardToken.safeTransfer(address(msg.sender), rewardToken.balanceOf(address(this)));
        }
    }

    /// @notice View function to see balance of reward token.
    function balance() external view returns (uint256) {
        if (isNative) {
            return address(this).balance;
        } else {
            return rewardToken.balanceOf(address(this));
        }
    }

    function getNextIncentivesController() external view override returns (address) {
        return _nextIncentivesController;
    }

    /// @notice payable function needed to receive AVAX
    receive() external payable {}
}