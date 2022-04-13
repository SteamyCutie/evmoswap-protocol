// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/IMasterChef.sol";
import "../interfaces/IOnwardIncentivesController.sol";

contract RewardPool is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    IMasterChef public immutable masterchef;

    // Staking token
    IERC20 public immutable stakingToken;
    // Reward token
    IERC20 public immutable rewardToken;
    uint256 public rewardPerTokenStored;
    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;
    // address of votingEscrow
    address public immutable operator;
    // bonus reward
    IOnwardIncentivesController incentivesController;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event Harvest(address indexed from, address indexed to, uint256 t);

    /**
     * @notice Constructor
     * @param _stakingToken: Staking token contract
     * @param _rewardToken: Rewarding token contract
     * @param _masterchef: MasterChef contract
     * @param _operator: address of the operator
     */
    constructor(
        IERC20 _stakingToken,
        IERC20 _rewardToken,
        IMasterChef _masterchef,
        address _operator
    ) public {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        masterchef = _masterchef;
        operator = _operator;

        // Infinite approve
        IERC20(_stakingToken).safeApprove(address(_masterchef), uint256(~0));
    }

    // only votingEscrow
    modifier onlyOperator() {
        require(msg.sender == operator, "!operator");
        _;
    }

    function setIncentivesController(IOnwardIncentivesController _incentivesController) external onlyOwner {
        incentivesController = _incentivesController;
    }

    function depositFor(address _user, uint256 _amount) external onlyOperator returns (bool) {
        UserInfo storage user = userInfo[_user];

        // reward balance before deposit
        uint256 rewardBalanceBefore = rewardToken.balanceOf(address(this));

        // deposit
        (uint256 poolAmountBeforeDeposit,,) = masterchef.userInfo(0, address(this));
        uint _userAmountBeforeDeposit = user.amount;
        if (_amount > 0) {
            stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
            user.amount = _userAmountBeforeDeposit.add(_amount);
        }
        masterchef.enterStaking(_amount);

        // reward token received
        uint256 rewardTokenReceived = rewardToken.balanceOf(address(this)).sub(rewardBalanceBefore);

        // update reward info
        uint _rewardPerTokenStored = rewardPerTokenStored;
        if (rewardTokenReceived != 0 && poolAmountBeforeDeposit != 0) {
            _rewardPerTokenStored = _rewardPerTokenStored.add(rewardTokenReceived.mul(1e12).div(poolAmountBeforeDeposit));
        }

        // send reward
        uint _rewardAmount = _rewardPerTokenStored * _userAmountBeforeDeposit / 1e12 - user.rewardDebt;
        if (_rewardAmount > 0) {
            rewardToken.safeTransfer(_user, _rewardAmount);
        }
        user.rewardDebt = _rewardPerTokenStored * (_userAmountBeforeDeposit + _amount) / 1e12;
        rewardPerTokenStored = _rewardPerTokenStored;

        // bonus
        if (address(incentivesController) != address(0)) {
            incentivesController.onReward(_user, user.amount);
        }

        emit Deposit(_user, _amount);
        return true;
    }

    function withdrawFor(address _user, uint256 _amount) external onlyOperator returns (bool) {
        return _withdraw(_user, msg.sender, _amount);
    }

    function harvest(address _user) external {
        _withdraw(_user, operator, 0);
        emit Harvest(msg.sender, _user, block.timestamp);
    }

    function emergencyWithdraw(address _user) external onlyOperator {
        masterchef.emergencyWithdraw(0);
        UserInfo storage user = userInfo[_user];
        stakingToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(_user, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    function _withdraw(address from, address to, uint256 _amount) internal returns (bool) {
        require(to != address(this), "!To");
        UserInfo storage user = userInfo[from];

        // reward balance before deposit
        uint256 rewardBalanceBefore = rewardToken.balanceOf(address(this));

        // withdraw
        (uint256 poolAmountBeforeWithdraw,,) = masterchef.userInfo(0, address(this));
        uint _userAmountBeforeWithdraw = user.amount;
        // adjust amount
        _amount = _amount > _userAmountBeforeWithdraw ? _userAmountBeforeWithdraw : _amount;
        masterchef.enterStaking(_amount);
        if (_amount > 0) {
            stakingToken.safeTransfer(to, _amount);
            user.amount = _userAmountBeforeWithdraw - _amount;
        }

        // reward token received
        uint256 rewardTokenReceived = rewardToken.balanceOf(address(this)).sub(rewardBalanceBefore);

        // update reward info
        uint _rewardPerTokenStored = rewardPerTokenStored;
        if (rewardTokenReceived != 0 && poolAmountBeforeWithdraw != 0) {
            _rewardPerTokenStored = _rewardPerTokenStored.add(rewardTokenReceived.mul(1e12).div(poolAmountBeforeWithdraw));
        }

        // send reward
        uint _rewardAmount = _rewardPerTokenStored * _userAmountBeforeWithdraw / 1e12 - user.rewardDebt;
        if (_rewardAmount > 0) {
            rewardToken.safeTransfer(from, _rewardAmount);
        }
        user.rewardDebt = _rewardPerTokenStored * (_userAmountBeforeWithdraw - _amount) / 1e12;
        rewardPerTokenStored = _rewardPerTokenStored;

        // bonus
        if (address(incentivesController) != address(0)) {
            incentivesController.onReward(from, user.amount);
        }

        emit Withdraw(from, _amount);
        return true;
    }

    function pendingTokens(address _user) external view returns (address[] memory tokens, uint[] memory amounts) {
        uint incentives = 0;
        address _incentivesControllerAddr = address(incentivesController);
        while (_incentivesControllerAddr != address(0)) {
            incentives++;
            _incentivesControllerAddr = IOnwardIncentivesController(_incentivesControllerAddr).getNextIncentivesController();
        }

        tokens = new address[](incentives + 1);
        amounts = new uint[](incentives + 1);

        // 0 -> rewardToken
        (uint256 poolAmount,,) = masterchef.userInfo(0, address(this));
        (, uint[] memory _amounts) = masterchef.pendingTokens(0, address(this));
        uint _rewardPerTokenStored = rewardPerTokenStored;
        if (_amounts[0] != 0 && poolAmount != 0) {
            _rewardPerTokenStored = _rewardPerTokenStored.add(_amounts[0].mul(1e12).div(poolAmount));
        }
        tokens[0] = address(rewardToken);
        amounts[0] = _rewardPerTokenStored * userInfo[_user].amount / 1e12 - userInfo[_user].rewardDebt;

        // bonus
        uint i = 1;
        IOnwardIncentivesController _incentivesController = incentivesController;
        while (address(_incentivesController) != address(0)) {
            tokens[i] = address(_incentivesController.rewardToken());
            amounts[i] = _incentivesController.pendingTokens(_user);
            _incentivesController = IOnwardIncentivesController(_incentivesController.getNextIncentivesController());
            i++;
        }
    }
}