// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./EMOToken.sol";
import "../interfaces/IOnwardIncentivesController.sol";
import "../interfaces/IMultiFeeDistribution.sol";

contract MasterChef is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 workingAmount; // Take voting power into consideration
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 workingSupply;      // Take voting power into consideration
        bool boost;
        uint256 allocPoint;       // How many allocation points assigned to this pool. EMOs to distribute per second.
        uint256 lastRewardTime;  // Last second number that EMOs distribution occurs.
        uint256 accEmoPerShare; // Accumulated EMOs per share, times 1e12. See below.
        uint256 depositFeePercent;      // Deposit fee in basis points
        IOnwardIncentivesController incentivesController; // bonus reward
    }

    // 40/100=2.5X
    uint256 public constant TOKENLESS_PRODUCTION = 40;

    // The EMO TOKEN!
    EMOToken public emo;
    //Pools, Farms, DAO, Refs percent decimals
    uint256 public percentDec = 1000000;
    //Pools and Farms percent from token per block
    uint256 public stakingPercent;
    //DAO percent from token per block
    uint256 public daoPercent;
    //Safu fund percent from token per block
    uint256 public safuPercent;
    //Referrals percent from token per block
    uint256 public refPercent;
    // DAO address.
    address public daoAddr;
    // Safu fund.
    address public safuAddr;
    // Refferals commision address.
    address public refAddr;
    // Deposit Fee address
    address public feeAddr;
    // Last block then deployer withdraw dao and ref fee
    uint256 public lastTimeDaoWithdraw;
    // The Reward Minter!
    IMultiFeeDistribution public rewardMinter;
    // Voting power
    address public votingEscrow;
    // EMO tokens created per second.
    uint256 public emoPerSecond;
    // Bonus muliplier for early emo makers.
    uint256 public BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(IERC20 => bool) public poolExistence;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The second number when EMO mining starts.
    uint256 public startTime;
    // Only EOA or contract whitelisted is allowed to deposit
    bool public whitelistable;
    mapping(address => bool) public whitelist;
    // Only user whitelisted is allowed to deposit pool 0
    mapping(address => bool) pool0Staker;

    event Add(uint256 indexed pid, uint256 allocPoint, IERC20 indexed lpToken, IOnwardIncentivesController indexed incentivesController, bool boost);
    event Set(uint256 indexed pid, uint256 allocPoint, IOnwardIncentivesController indexed incentivesController);
    event Deposit(address indexed from, address indexed to, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    modifier nonDuplicated(IERC20 _lpToken) {
        require(poolExistence[_lpToken] == false, "nonDuplicated: duplicated");
        _;
    }

    constructor(
        EMOToken _emo,
        uint256 _stakingPercent,
        uint256 _daoPercent,
        uint256 _safuPercent,
        uint256 _refPercent,
        address _daoAddr,
        address _safuAddr,
        address _refAddr,
        address _feeAddr,
        IMultiFeeDistribution _rewardMinter,
        uint256 _emoPerSecond,
        address _votingEscrow
    ) public {
        emo = _emo;
        stakingPercent = _stakingPercent;
        daoPercent = _daoPercent;
        safuPercent = _safuPercent;
        refPercent = _refPercent;
        daoAddr = _daoAddr;
        safuAddr = _safuAddr;
        refAddr = _refAddr;
        feeAddr = _feeAddr;
        rewardMinter = _rewardMinter;
        emoPerSecond = _emoPerSecond;
        votingEscrow = _votingEscrow;
        whitelistable = true;
    }

    function setStartTime(uint256 _startTime) public onlyOwner {
        require(startTime == 0, "startTime has been set");
        startTime = _startTime;

        // staking pool
        poolInfo.push(PoolInfo({
            lpToken : emo,
            workingSupply : 0,
            boost : false,
            allocPoint : 100,
            lastRewardTime : startTime,
            accEmoPerShare : 0,
            depositFeePercent : 0,
            incentivesController : IOnwardIncentivesController(address(0))
        }));

        poolExistence[emo] = true;
        totalAllocPoint = 100;

    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function toggleWhitelistable() external onlyOwner {
        whitelistable = !whitelistable;
    }

    function setWhitelist(address [] memory _users, bool _flag) external onlyOwner {
        for (uint i = 0; i < _users.length; i++) {
            whitelist[_users[i]] = _flag;
        }
    }

    function setPool0Staker(address [] memory _users, bool _flag) external onlyOwner {
        for (uint i = 0; i < _users.length; i++) {
            pool0Staker[_users[i]] = _flag;
        }
    }

    function withdrawDevAndRefFee() public {
        require(lastTimeDaoWithdraw < block.timestamp, 'wait for new block');
        uint256 multiplier = getMultiplier(lastTimeDaoWithdraw, block.timestamp);
        uint256 emoReward = multiplier.mul(emoPerSecond);
        emo.mint(daoAddr, emoReward.mul(daoPercent).div(percentDec));
        emo.mint(safuAddr, emoReward.mul(safuPercent).div(percentDec));
        emo.mint(refAddr, emoReward.mul(refPercent).div(percentDec));
        lastTimeDaoWithdraw = block.timestamp;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, uint256 _depositFeePercent, IERC20 _lpToken, IOnwardIncentivesController _incentivesController, bool _boost, bool _withUpdate) public onlyOwner nonDuplicated(_lpToken) {
        require(_depositFeePercent <= percentDec, "set: invalid deposit fee basis points");
        require(startTime != 0, "!startTime");
        if (_withUpdate) {
            massUpdatePools();
        }

        uint256 lastRewardTime = block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolExistence[_lpToken] = true;
        poolInfo.push(PoolInfo({
            lpToken : _lpToken,
            workingSupply : 0,
            boost : _boost,
            allocPoint : _allocPoint,
            lastRewardTime : lastRewardTime,
            accEmoPerShare : 0,
            depositFeePercent : _depositFeePercent,
            incentivesController : _incentivesController
        }));
        emit Add(poolInfo.length.sub(1), _allocPoint, _lpToken, _incentivesController, _boost);
    }

    // Update the given pool's EMO allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint256 _depositFeePercent, IOnwardIncentivesController _incentivesController, bool _withUpdate) public onlyOwner {
        require(_depositFeePercent <= percentDec, "set: invalid deposit fee basis points");
        require(startTime != 0, "!startTime");
        require(_pid != 0 || address(_incentivesController) == address(0), "!incentive");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeePercent = _depositFeePercent;
        poolInfo[_pid].incentivesController = _incentivesController;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(_allocPoint);
        }
        emit Set(_pid, _allocPoint, _incentivesController);
    }

    // Return reward multiplier over the given _from to _to second.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    function pendingTokens(uint256 _pid, address _user) external view returns (address[] memory tokens, uint[] memory amounts) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint incentives = 0;
        address _incentivesControllerAddr = address(pool.incentivesController);
        while (_incentivesControllerAddr != address(0)) {
            incentives++;
            _incentivesControllerAddr = IOnwardIncentivesController(_incentivesControllerAddr).getNextIncentivesController();
        }

        tokens = new address[](incentives + 1);
        amounts = new uint[](incentives + 1);

        uint256 accEmoPerShare = pool.accEmoPerShare;
        uint256 lpSupply = pool.workingSupply;
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
            uint256 emoReward = multiplier.mul(emoPerSecond).mul(pool.allocPoint).div(totalAllocPoint).mul(stakingPercent).div(percentDec);
            accEmoPerShare = accEmoPerShare.add(emoReward.mul(1e12).div(lpSupply));
        }
        tokens[0] = address(emo);
        amounts[0] = user.workingAmount.mul(accEmoPerShare).div(1e12).sub(user.rewardDebt);

        // bonus
        uint i = 1;
        IOnwardIncentivesController _incentivesController = pool.incentivesController;
        while (address(_incentivesController) != address(0)) {
            tokens[i] = address(_incentivesController.rewardToken());
            amounts[i] = _incentivesController.pendingTokens(_user);
            _incentivesController = IOnwardIncentivesController(_incentivesController.getNextIncentivesController());
            i++;
        }
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        uint256 lpSupply = pool.workingSupply;
        if (lpSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
        uint256 emoReward = multiplier.mul(emoPerSecond).mul(pool.allocPoint).div(totalAllocPoint).mul(stakingPercent).div(percentDec);
        pool.accEmoPerShare = pool.accEmoPerShare.add(emoReward.mul(1e12).div(lpSupply));
        pool.lastRewardTime = block.timestamp;
    }

    // Deposit LP tokens to MasterChef for EMO allocation for _user
    function depositFor(address _user, uint256 _pid, uint256 _amount) public nonReentrant {
        require(!whitelistable || !_isContract(_user) || whitelist[_user], "Contract is not in the whitelist");
        require(_pid != 0, 'deposit EMO by staking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        updatePool(_pid);
        if (user.workingAmount > 0) {
            uint256 pending = user.workingAmount.mul(pool.accEmoPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                rewardMinter.mint(_user, pending, true);
            }
        }
        if (_amount > 0) {
            uint256 balanceBefore = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            _amount = pool.lpToken.balanceOf(address(this)).sub(balanceBefore);
            if (pool.depositFeePercent > 0) {
                uint256 depositFee = _amount.mul(pool.depositFeePercent).div(percentDec);
                pool.lpToken.safeTransfer(feeAddr, depositFee);
                _amount = _amount.sub(depositFee);
            }
            user.amount = user.amount.add(_amount);
        }

        if (pool.boost) {
            uint256 votingBalance = IERC20(votingEscrow).balanceOf(_user);
            uint256 votingTotal = IERC20(votingEscrow).totalSupply();
            uint256 lim = user.amount * TOKENLESS_PRODUCTION / 100;
            if (votingTotal > 0) {
                lim += pool.lpToken.balanceOf(address(this)) * votingBalance / votingTotal * (100 - TOKENLESS_PRODUCTION) / 100;
            }
            lim = user.amount < lim ? user.amount : lim;
            pool.workingSupply = pool.workingSupply + lim - user.workingAmount;
            user.workingAmount = lim;
        } else {
            pool.workingSupply = pool.workingSupply + user.amount - user.workingAmount;
            user.workingAmount = user.amount;
        }

        user.rewardDebt = user.workingAmount.mul(pool.accEmoPerShare).div(1e12);

        // Interactions
        IOnwardIncentivesController _incentivesController = pool.incentivesController;
        if (address(_incentivesController) != address(0)) {
            _incentivesController.onReward(_user, user.amount);
        }

        emit Deposit(msg.sender, _user, _pid, _amount);
    }

    // Deposit LP tokens to MasterChef for EMO allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        depositFor(msg.sender, _pid, _amount);
    }

    function harvestAllRewards(address _user) public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            if (userInfo[pid][_user].amount > 0) {
                _withdraw(pid, _user, 0);
            }
        }
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        _withdraw(_pid, msg.sender, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function _withdraw(uint256 _pid, address _user, uint256 _amount) internal nonReentrant {
        require(_pid != 0, 'withdraw EMO by unstaking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);
        if (user.workingAmount > 0) {
            uint256 pending = user.workingAmount.mul(pool.accEmoPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                rewardMinter.mint(_user, pending, true);
            }
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(_user), _amount);
        }

        if (pool.boost) {
            uint256 votingBalance = IERC20(votingEscrow).balanceOf(_user);
            uint256 votingTotal = IERC20(votingEscrow).totalSupply();
            uint256 lim = user.amount * TOKENLESS_PRODUCTION / 100;
            if (votingTotal > 0) {
                lim += pool.lpToken.balanceOf(address(this)) * votingBalance / votingTotal * (100 - TOKENLESS_PRODUCTION) / 100;
            }
            lim = user.amount < lim ? user.amount : lim;
            pool.workingSupply = pool.workingSupply + lim - user.workingAmount;
            user.workingAmount = lim;
        } else {
            pool.workingSupply = pool.workingSupply + user.amount - user.workingAmount;
            user.workingAmount = user.amount;
        }

        user.rewardDebt = user.workingAmount.mul(pool.accEmoPerShare).div(1e12);

        // Interactions
        IOnwardIncentivesController _incentivesController = pool.incentivesController;
        if (address(_incentivesController) != address(0)) {
            _incentivesController.onReward(_user, user.amount);
        }

        emit Withdraw(_user, _pid, _amount);
    }

    // Stake EMO tokens to MasterChef
    function enterStaking(uint256 _amount) public nonReentrant {
        require(pool0Staker[msg.sender], "Not allow to enterStaking");

        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
        if (user.workingAmount > 0) {
            uint256 pending = user.workingAmount.mul(pool.accEmoPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                emo.mint(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        pool.workingSupply = pool.workingSupply + user.amount - user.workingAmount;
        user.workingAmount = user.amount;
        user.rewardDebt = user.workingAmount.mul(pool.accEmoPerShare).div(1e12);

        emit Deposit(msg.sender, msg.sender, 0, _amount);
    }

    // Withdraw EMO tokens from STAKING.
    function leaveStaking(uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(0);
        if (user.workingAmount > 0) {
            uint256 pending = user.workingAmount.mul(pool.accEmoPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                emo.mint(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        pool.workingSupply = pool.workingSupply + user.amount - user.workingAmount;
        user.workingAmount = user.amount;
        user.rewardDebt = user.workingAmount.mul(pool.accEmoPerShare).div(1e12);

        emit Withdraw(msg.sender, 0, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;

        // working amount
        if (pool.workingSupply >= user.workingAmount) {
            pool.workingSupply = pool.workingSupply - user.workingAmount;
        } else {
            pool.workingSupply = 0;
        }
        user.workingAmount = 0;

        // Interactions
        IOnwardIncentivesController _incentivesController = pool.incentivesController;
        if (address(_incentivesController) != address(0)) {
            _incentivesController.onReward(msg.sender, 0);
        }
    }

    function setEmoPerSecond(uint256 _emoPerSecond) public onlyOwner {
        require(_emoPerSecond <= 12 * 1e18, "Max per second 12 EMO");
        massUpdatePools();
        emoPerSecond = _emoPerSecond;
    }

    function setDaoAddress(address _daoAddr) public onlyOwner {
        daoAddr = _daoAddr;
    }

    function setRefAddress(address _refAddr) public onlyOwner {
        refAddr = _refAddr;
    }

    function setSafuAddress(address _safuAddr) public onlyOwner {
        safuAddr = _safuAddr;
    }

    function setFeeAddress(address _feeAddr) public onlyOwner {
        require(_feeAddr != address(0), "setFeeAddress: ZERO");
        feeAddr = _feeAddr;
    }

    function _isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}