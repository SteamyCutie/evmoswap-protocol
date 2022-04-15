// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../interfaces/IEvmoSwapIFO.sol";
import "../interfaces/IVotingEscrow.sol";

/**
 * @title IFOInitializable
 */

contract IFOInitializable is IEvmoSwapIFO, ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // The offering token
    IERC20 public override offeringToken;

    // Max time interval (for sanity checks)
    uint256 public MAX_BUFFER_TIME_INTERVAL;

    // Number of pools
    uint8 public constant NUMBER_POOLS = 2;

    // MULTIPLIER
    uint8 public constant VE_RATE = 10;

    uint256 constant public PERCENTAGE_FACTOR = 10000;

    // The address of the smart chef factory
    address public immutable IFO_FACTORY;

    // VotingEscrow contract
    address public votingEscrowAddress;

    // Whether it is initialized
    bool public isInitialized;

    // Allow claim
    bool public allowClaim;

    // The block timestamp when IFO starts
    uint256 public startTime;

    // The block timestamp when IFO ends
    uint256 public endTime;

    // The campaignId for the IFO
    uint256 public campaignId;

    // Total tokens distributed across the pools
    uint256 public totalTokensOffered;

    // Total amount of raising token withdrew
    uint256[NUMBER_POOLS] public totalWithdrawRaisingAmount;

    // The address burns raisingToken
    address public burnAddress;

    // The address receive remaining raisingToken after burning, like PostIFOLauncher
    address public receiverAddress;

    // Total amount of tax(raising token) withdrew
    uint256[NUMBER_POOLS] public totalWithdrawTaxAmount;

    // The address receive tax
    address public taxCollector;

    // Array of PoolCharacteristics of size NUMBER_POOLS
    PoolCharacteristics[NUMBER_POOLS] private _poolInformation;

    // It maps the address to pool id to UserInfo
    mapping(address => mapping(uint8 => UserInfo)) private _userInfo;

    // Struct that contains each pool characteristics
    struct PoolCharacteristics {
        IERC20 raisingToken; // The raising token
        uint256 raisingAmountPool; // amount of tokens raised for the pool (in raising tokens)
        uint256 offeringAmountPool; // amount of tokens offered for the pool (in offeringTokens)
        uint256 limitPerUserInRaisingToken; // limit of tokens per user (if 0, it is ignored)
        uint256 initialReleasePercentage; // percentage releases immediately when ifo ends(if 10000, it is 100%)
        uint256 burnPercentage; // The percentag of raisingToken to burn,multiply by PERCENTAGE_FACTOR (100 means 0.01)
        uint256 vestingEndTime; // block timestamp when 100% of tokens have been released
        bool hasTax; // tax on the overflow (if any, it works with _calculateTaxOverflow)
        uint256 totalAmountPool; // total amount pool deposited (in raising tokens)
        uint256 sumTaxesOverflow; // total taxes collected (starts at 0, increases with each harvest if overflow)
    }

    // Struct that contains each user information for both pools
    struct UserInfo {
        uint256 amountPool; // How many tokens the user has provided for pool
        uint256 offeringTokensClaimed; // How many tokens has been claimed by user
        uint256 lastTimeHarvested; // The time when user claimed recently
        bool hasHarvestedInitial; // If initial is claimed
        bool refunded; // If the user is refunded
    }

    // Admin withdraw events
    event AdminWithdraw(uint256[] amountRaisingTokens, uint256 amountOfferingToken);

    // Admin recovers token
    event AdminTokenRecovery(address tokenAddress, uint256 amountTokens);

    // Deposit event
    event Deposit(address indexed user, uint8 indexed pid, uint256 amount);

    // Harvest event
    event Harvest(address indexed user, uint8 indexed pid, uint256 offeringAmount, uint256 excessAmount);

    // Event for new start & end timestamp
    event NewStartAndEndTimes(uint256 startTime, uint256 endTime);

    // Event with campaignId for IFO
    event CampaignIdSet(uint256 campaignId);

    // Event when parameters are set for one of the pools
    event PoolParametersSet(uint8 pid, uint256 offeringAmountPool, uint256 raisingAmountPool);

    // Modifier to prevent contracts to participate
    modifier notContract() {
        require(!_isContract(msg.sender), "contract not allowed");
        require(msg.sender == tx.origin, "proxy contract not allowed");
        _;
    }

    /**
     * @notice Constructor
     */
    constructor() public {
        IFO_FACTORY = msg.sender;
    }

    /**
     * @notice It initializes the contract
     * @dev It can only be called once.
     * @param _offeringToken: the token that is offered for the IFO
     * @param _startTime: the start timestamp for the IFO
     * @param _endTime: the end timestamp for the IFO
     * @param _adminAddress: the admin address for handling tokens
     * @param _votingEscrowAddress: the address of the VotingEscrow
     */
    function initialize(
        address _offeringToken,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxBufferTimeInterval,
        address _adminAddress,
        address _votingEscrowAddress,
        address _burnAddress,
        address _receiverAddress
    ) public {
        require(!isInitialized, "Operations: Already initialized");
        require(msg.sender == IFO_FACTORY, "Operations: Not factory");
        require(_receiverAddress != address(0), "Operations: Zero address");

        // Make this contract initialized
        isInitialized = true;

        // init not allow claim
        allowClaim = false; 

        offeringToken = IERC20(_offeringToken);
        votingEscrowAddress = _votingEscrowAddress;
        startTime = _startTime;
        endTime = _endTime;
        MAX_BUFFER_TIME_INTERVAL = _maxBufferTimeInterval;

        burnAddress = _burnAddress;
        receiverAddress = _receiverAddress;

        // Transfer ownership to admin
        transferOwnership(_adminAddress);
    }

    /**
     * @notice It allows users to deposit raising tokens to pool
     * @param _amount: the number of raising token used (18 decimals)
     * @param _pid: pool id
     */
    function depositPool(uint256 _amount, uint8 _pid) external override nonReentrant notContract {
        // Checks whether the pool id is valid
        require(_pid < NUMBER_POOLS, "Deposit: Non valid pool id");

        // Checks that pool was set
        require(
            _poolInformation[_pid].offeringAmountPool > 0 && _poolInformation[_pid].raisingAmountPool > 0,
            "Deposit: Pool not set"
        );

        // Checks whether the block timestamp is not too early
        require(block.timestamp > startTime, "Deposit: Too early");

        // Checks whether the block timestamp is not too late
        require(block.timestamp < endTime, "Deposit: Too late");

        // Checks that the amount deposited is not inferior to 0
        require(_amount > 0, "Deposit: Amount must be > 0");

        // Verify tokens were deposited properly
        require(offeringToken.balanceOf(address(this)) >= totalTokensOffered, "Deposit: Tokens not deposited properly");

        // amount of veEmo from votingEscrow, only for base sale
        if (votingEscrowAddress != address(0) && _pid == 0) {
            uint256 veDecimal = IVotingEscrow(votingEscrowAddress).decimals();
            uint256 raisingDecimal = IVotingEscrow(address(_poolInformation[_pid].raisingToken)).decimals();
            require(veDecimal >= raisingDecimal, "Wrong decimal");

            uint256 ifoCredit = IVotingEscrow(votingEscrowAddress).balanceOfT(msg.sender, startTime) * VE_RATE;
            require(_userInfo[msg.sender][_pid].amountPool.add(_amount).mul(10 ** (veDecimal - raisingDecimal)) <= ifoCredit, "Not enough veEmo");
        }

        // Transfers funds to this contract
        _poolInformation[_pid].raisingToken.safeTransferFrom(address(msg.sender), address(this), _amount);

        // Update the user status
        _userInfo[msg.sender][_pid].amountPool = _userInfo[msg.sender][_pid].amountPool.add(_amount);

        // Check if the pool has a limit per user
        if (_poolInformation[_pid].limitPerUserInRaisingToken > 0) {
            // Checks whether the limit has been reached
            require(
                _userInfo[msg.sender][_pid].amountPool <= _poolInformation[_pid].limitPerUserInRaisingToken,
                "Deposit: New amount above user limit"
            );
        }

        // Updates the totalAmount for pool
        _poolInformation[_pid].totalAmountPool = _poolInformation[_pid].totalAmountPool.add(_amount);

        emit Deposit(msg.sender, _pid, _amount);
    }

    /**
     * @notice It allows users to harvest from pool
     * @param _pid: pool id
     */
    function harvestPool(uint8 _pid) external override nonReentrant notContract {
        // Checks whether it is allow to harvest
        require(allowClaim, "Harvest: not allow claim");

        // Checks whether pool id is valid
        require(_pid < NUMBER_POOLS, "Harvest: Non valid pool id");

        UserInfo storage currentUserInfo = _userInfo[msg.sender][_pid];

        // Checks whether the user has participated
        require(currentUserInfo.amountPool > 0, "Harvest: Did not participate");

        // Checks whether the user has already harvested in the same block
        require(currentUserInfo.lastTimeHarvested < block.timestamp, "Harvest: Already harvest in the same block");

        // Initialize the variables for offering, refunding user amounts, and tax amount
        (
        uint256 raisingTokenRefund,
        uint256 userTaxOverflow,
        uint256 offeringTokenTotalHarvest,,,
        ) = userTokenStatus(msg.sender, _pid);

        // Updates the harvest time
        currentUserInfo.lastTimeHarvested = block.timestamp;
        currentUserInfo.hasHarvestedInitial = true;

        // Settle refund
        if (!currentUserInfo.refunded) {
            currentUserInfo.refunded = true;
            if (raisingTokenRefund > 0) {
                _poolInformation[_pid].raisingToken.safeTransfer(msg.sender, raisingTokenRefund);
            }
            // Increment the sumTaxesOverflow
            if (userTaxOverflow > 0) {
                _poolInformation[_pid].sumTaxesOverflow = _poolInformation[_pid].sumTaxesOverflow.add(userTaxOverflow);
            }
        }

        // Final check to verify the user has not gotten more tokens that originally allocated
        (uint256 offeringTokenAmount,,) = _calculateOfferingAndRefundingAmountsPool(msg.sender, _pid);
        uint256 offeringAllocationLeft = offeringTokenAmount - currentUserInfo.offeringTokensClaimed;
        uint256 allocatedTokens = offeringAllocationLeft >= offeringTokenTotalHarvest ? offeringTokenTotalHarvest : offeringAllocationLeft;
        if (allocatedTokens > 0) {
            currentUserInfo.offeringTokensClaimed += allocatedTokens;
            offeringToken.safeTransfer(msg.sender, allocatedTokens);
        }

        emit Harvest(msg.sender, _pid, allocatedTokens, raisingTokenRefund);
    }

    /**
     * @notice It allows the admin to withdraw funds
     * @param _raisingAmounts: the number array of raising token to withdraw
     * @param _offeringAmount: the number of offering amount to withdraw
     * @dev This function is only callable by admin.
     */
    function finalWithdraw(uint256[] memory _raisingAmounts, uint256 _offeringAmount) external override onlyOwner {
        require(_raisingAmounts.length == NUMBER_POOLS, "Operations: Wrong length");
      
        for (uint i; i < NUMBER_POOLS; i++) {
            if(_raisingAmounts[i] > 0) {
                PoolCharacteristics memory poolInfo = _poolInformation[i];
                require(_raisingAmounts[i] <= poolInfo.raisingToken.balanceOf(address(this)), "Operations: Not enough raising tokens");

                totalWithdrawRaisingAmount[i] = totalWithdrawRaisingAmount[i].add(_raisingAmounts[i]);
                require(totalWithdrawRaisingAmount[i] <= poolInfo.raisingAmountPool, "Operations: Maximum allowance exceeds");

                uint burnAmount = 0;
                if (poolInfo.burnPercentage != 0) {
                    burnAmount = _raisingAmounts[i].mul(poolInfo.burnPercentage).div(PERCENTAGE_FACTOR);
                    poolInfo.raisingToken.safeTransfer(burnAddress, burnAmount);
                }
                poolInfo.raisingToken.safeTransfer(receiverAddress, _raisingAmounts[i].sub(burnAmount));
            }
        }

        if (_offeringAmount > 0) {
            require(_offeringAmount <= offeringToken.balanceOf(address(this)), "Operations: Not enough offering tokens");
            offeringToken.safeTransfer(address(msg.sender), _offeringAmount);
        }

        emit AdminWithdraw(_raisingAmounts, _offeringAmount);
    }

    /**
     * @notice It allows the admin or collector to withdraw tax
     * @dev This function is only callable by admin or collector.
     */
    function taxWithdraw() external {
        require(taxCollector != address(0), "Operations: Wrong tax collector");
        require(owner() == msg.sender || taxCollector == msg.sender, "Operations: Permission denied");

        for (uint i; i < NUMBER_POOLS; i++) {
            uint256 sumTaxesOverflow = _poolInformation[i].sumTaxesOverflow;
            _poolInformation[i].raisingToken.safeTransfer(taxCollector, sumTaxesOverflow.sub(totalWithdrawTaxAmount[i]));
            totalWithdrawTaxAmount[i] = sumTaxesOverflow;
        }
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw (18 decimals)
     * @param _tokenAmount: the number of token amount to withdraw
     * @dev This function is only callable by admin.
     */
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(_tokenAddress != address(offeringToken), "Recover: Cannot be offering token");
        for (uint i; i < NUMBER_POOLS; i++) {
            require(_tokenAddress != address(_poolInformation[i].raisingToken), "Recover: Cannot be raising token");
        }

        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /**
     * @notice It sets parameters for pool
     * @param _raisingToken: the raising token used
     * @param _offeringAmountPool: offering amount (in tokens)
     * @param _raisingAmountPool: raising amount (in raising tokens)
     * @param _limitPerUserInRaisingToken: limit per user (in raising tokens)
     * @param _initialReleasePercentage: initial release percentage (if 10000, it is 100%)
     * @param _vestingEndTime: vesting end time
     * @param _hasTax: if the pool has a tax
     * @param _pid: pool id
     * @dev This function is only callable by admin.
     */
    function setPool(
        address _raisingToken,
        uint256 _offeringAmountPool,
        uint256 _raisingAmountPool,
        uint256 _limitPerUserInRaisingToken,
        uint256 _initialReleasePercentage,
        uint256 _burnPercentage,
        uint256 _vestingEndTime,
        bool _hasTax,
        uint8 _pid
    ) external override onlyOwner {
        require(IERC20(_raisingToken).totalSupply() >= 0);
        require(_raisingToken != address(offeringToken), "Operations: Tokens must be be different");
        require(block.timestamp < startTime, "Operations: IFO has started");
        require(_initialReleasePercentage <= PERCENTAGE_FACTOR, "Operations: Wrong initial percentage");
        require(_burnPercentage <= PERCENTAGE_FACTOR, "Operations: Wrong percentage");
        require(_vestingEndTime >= endTime, "Operations: Vesting ends too early");
        require(_pid < NUMBER_POOLS, "Operations: Pool does not exist");

        if (_vestingEndTime == endTime) {
            require(_initialReleasePercentage == PERCENTAGE_FACTOR, "Operations:Initial percentage should be equal to PERCENTAGE_FACTOR");
        }

        _poolInformation[_pid].raisingToken = IERC20(_raisingToken);
        _poolInformation[_pid].offeringAmountPool = _offeringAmountPool;
        _poolInformation[_pid].raisingAmountPool = _raisingAmountPool;
        _poolInformation[_pid].limitPerUserInRaisingToken = _limitPerUserInRaisingToken;
        _poolInformation[_pid].initialReleasePercentage = _initialReleasePercentage;
        _poolInformation[_pid].burnPercentage = _burnPercentage;
        _poolInformation[_pid].vestingEndTime = _vestingEndTime;
        _poolInformation[_pid].hasTax = _hasTax;

        uint256 tokensDistributedAcrossPools;

        for (uint8 i = 0; i < NUMBER_POOLS; i++) {
            tokensDistributedAcrossPools = tokensDistributedAcrossPools.add(_poolInformation[i].offeringAmountPool);
        }

        // Update totalTokensOffered
        totalTokensOffered = tokensDistributedAcrossPools;

        emit PoolParametersSet(_pid, _offeringAmountPool, _raisingAmountPool);
    }

    /**
     * @notice It updates campaignId for the IFO.
     * @param _campaignId: the campaignId for the IFO
     * @dev This function is only callable by admin.
     */
    function updateCampaignId(uint256 _campaignId) external override onlyOwner {
        require(block.timestamp < endTime, "Operations: IFO has ended");
        campaignId = _campaignId;

        emit CampaignIdSet(campaignId);
    }

    /**
     * @notice It allows the admin to update start and end timestamp
     * @param _startTime: the new start timestamp
     * @param _endTime: the new end timestamp
     * @dev This function is only callable by admin.
     */
    function updateStartAndEndTimes(uint256 _startTime, uint256 _endTime) external onlyOwner {
        require(_endTime < (block.timestamp + MAX_BUFFER_TIME_INTERVAL), "Operations: EndTime too far");
        require(block.timestamp < startTime, "Operations: IFO has started");
        require(_startTime < _endTime, "Operations: New startTime must be less than new endTime");
        require(block.timestamp < _startTime, "Operations: New startTime must be greater than current timestamp");

        startTime = _startTime;
        endTime = _endTime;

        emit NewStartAndEndTimes(_startTime, _endTime);
    }

    /**
    * @notice It allows the admin to set
    * @param _allow: claim status
    * @dev This function is only callable by admin.
    */
    function setAllowClaim(bool _allow) external onlyOwner {
        allowClaim = _allow;
    }

    /**
    * @notice It allows the admin to update tax collector
    * @param _taxCollector: the new tax collector
    * @dev This function is only callable by admin.
    */
    function setTaxCollector(address _taxCollector) external onlyOwner {
        taxCollector = _taxCollector;
    }

    /**
     * @notice It returns the pool information
     * @param _pid: poolId
     * @return raisingAmountPool: amount of raising tokens raised (in raising tokens)
     * @return offeringAmountPool: amount of tokens offered for the pool (in offeringTokens)
     * @return limitPerUserInRaisingToken: limit of tokens per user (if 0, it is ignored)
     * @return hasTax: tax on the overflow (if any, it works with _calculateTaxOverflow)
     * @return totalAmountPool: total amount pool deposited (in raising tokens)
     * @return sumTaxesOverflow: total taxes collected (starts at 0, increases with each harvest if overflow)
     */
    function viewPoolInformation(uint256 _pid)
    external
    view
    override
    returns (
        IERC20,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256,
        bool,
        uint256,
        uint256
    )
    {
        PoolCharacteristics memory poolInfo = _poolInformation[_pid];
        return (
        poolInfo.raisingToken,
        poolInfo.raisingAmountPool,
        poolInfo.offeringAmountPool,
        poolInfo.limitPerUserInRaisingToken,
        poolInfo.initialReleasePercentage,
        poolInfo.burnPercentage,
        poolInfo.vestingEndTime,
        poolInfo.hasTax,
        poolInfo.totalAmountPool,
        poolInfo.sumTaxesOverflow
        );
    }

    /**
     * @notice It returns the tax overflow rate calculated for a pool
     * @dev 100,000,000,000 means 0.1 (10%) / 1 means 0.0000000000001 (0.0000001%) / 1,000,000,000,000 means 1 (100%)
     * @param _pid: poolId
     * @return It returns the tax percentage
     */
    function viewPoolTaxRateOverflow(uint256 _pid) external view override returns (uint256) {
        if (!_poolInformation[_pid].hasTax) {
            return 0;
        } else {
            return
            _calculateTaxOverflow(_poolInformation[_pid].totalAmountPool, _poolInformation[_pid].raisingAmountPool);
        }
    }

    /**
     * @notice External view function to see user allocations for both pools
     * @param _user: user address
     * @param _pids[]: array of pids
     * @return
     */
    function viewUserAllocationPools(address _user, uint8[] calldata _pids)
    external
    view
    override
    returns (uint256[] memory)
    {
        uint256[] memory allocationPools = new uint256[](_pids.length);
        for (uint8 i = 0; i < _pids.length; i++) {
            allocationPools[i] = _getUserAllocationPool(_user, _pids[i]);
        }
        return allocationPools;
    }

    /**
     * @notice External view function to see user information
     * @param _user: user address
     * @param _pids[]: array of pids
     */
    function viewUserInfo(address _user, uint8[] calldata _pids)
    external
    view
    override
    returns (uint256[] memory, uint256[] memory, uint256[] memory, bool[] memory, bool[] memory)
    {
        uint256[] memory amountPools = new uint256[](_pids.length);
        uint256[] memory offeringTokensClaimedPools = new uint256[](_pids.length);
        uint256[] memory lastTimeHarvestedPools = new uint256[](_pids.length);
        bool[] memory hasHarvestedInitialPools = new bool[](_pids.length);
        bool[] memory refundedPools = new bool[](_pids.length);

        for (uint8 i = 0; i < NUMBER_POOLS; i++) {
            amountPools[i] = _userInfo[_user][i].amountPool;
            offeringTokensClaimedPools[i] = _userInfo[_user][i].offeringTokensClaimed;
            lastTimeHarvestedPools[i] = _userInfo[_user][i].lastTimeHarvested;
            hasHarvestedInitialPools[i] = _userInfo[_user][i].hasHarvestedInitial;
            refundedPools[i] = _userInfo[_user][i].refunded;
        }
        return (amountPools, offeringTokensClaimedPools, lastTimeHarvestedPools, hasHarvestedInitialPools, refundedPools);
    }

    /**
     * @notice External view function to see user offering and refunding amounts for both pools
     * @param _user: user address
     * @param _pids: array of pids
     */
    function viewUserOfferingAndRefundingAmountsForPools(address _user, uint8[] calldata _pids)
    external
    view
    override
    returns (uint256[3][] memory)
    {
        uint256[3][] memory amountPools = new uint256[3][](_pids.length);

        for (uint8 i = 0; i < _pids.length; i++) {
            uint256 userOfferingAmountPool;
            uint256 userRefundingAmountPool;
            uint256 userTaxAmountPool;

            if (_poolInformation[_pids[i]].raisingAmountPool > 0) {
                (
                userOfferingAmountPool,
                userRefundingAmountPool,
                userTaxAmountPool
                ) = _calculateOfferingAndRefundingAmountsPool(_user, _pids[i]);
            }

            amountPools[i] = [userOfferingAmountPool, userRefundingAmountPool, userTaxAmountPool];
        }
        return amountPools;
    }

    /**
    * @notice Get the amount of tokens a user is eligible to receive based on current state.
    * @param _user: address of user to obtain token status
    * @param _pid: pool id to obtain token status
    * raisingTokenRefund:Amount of raising tokens available to refund
    * userTaxOverflow: Amount of tax
    * offeringTokenTotalHarvest: Total amount of offering tokens that can be harvested (initial + vested)
    * offeringTokenInitialHarvest: Amount of initial harvest offering tokens that can be collected
    * offeringTokenVestedHarvest: Amount offering tokens that can be harvested from the vesting portion of tokens
    * offeringTokensVesting: Amount of offering tokens that are still vested
    */
    function userTokenStatus(address _user, uint8 _pid) public view returns (
        uint256 raisingTokenRefund,
        uint256 userTaxOverflow,
        uint256 offeringTokenTotalHarvest,
        uint256 offeringTokenInitialHarvest,
        uint256 offeringTokenVestedHarvest,
        uint256 offeringTokensVesting
    ){
        uint256 currentTime = block.timestamp;
        if (currentTime < endTime) {
            return (0, 0, 0, 0, 0, 0);
        }

        UserInfo memory currentUserInfo = _userInfo[_user][_pid];
        PoolCharacteristics memory currentPoolInfo = _poolInformation[_pid];

        // Initialize the variables for offering, refunding user amounts
        (uint256 offeringTokenAmount, uint256 refundingTokenAmount, uint256 taxAmount) = _calculateOfferingAndRefundingAmountsPool(_user, _pid);
        uint256 offeringTokenInitialAmount = offeringTokenAmount * currentPoolInfo.initialReleasePercentage / PERCENTAGE_FACTOR;
        uint256 offeringTokenVestedAmount = offeringTokenAmount - offeringTokenInitialAmount;

        // Setup refund amount
        raisingTokenRefund = 0;
        userTaxOverflow = 0;
        if (!currentUserInfo.refunded) {
            raisingTokenRefund = refundingTokenAmount;
            userTaxOverflow = taxAmount;
        }

        // Setup initial harvest amount
        offeringTokenInitialHarvest = 0;
        if (!currentUserInfo.hasHarvestedInitial) {
            offeringTokenInitialHarvest = offeringTokenInitialAmount;
        }

        // Setup harvestable vested token amount
        offeringTokenVestedHarvest = 0;
        offeringTokensVesting = 0;
        // exclude initial
        uint256 offeringTokenUnclaimed = offeringTokenAmount.sub(offeringTokenInitialHarvest).sub(currentUserInfo.offeringTokensClaimed);
        if (currentTime >= currentPoolInfo.vestingEndTime) {
            offeringTokenVestedHarvest = offeringTokenUnclaimed;
        } else {
            uint256 unlockEndTime = currentTime;
            // endTime is the earliest time to harvest
            uint256 lastHarvestTime = currentUserInfo.lastTimeHarvested < endTime ? endTime : currentUserInfo.lastTimeHarvested;
            if (unlockEndTime > lastHarvestTime) {
                uint256 totalVestingTime = currentPoolInfo.vestingEndTime - endTime;
                uint256 unlockTime = unlockEndTime - lastHarvestTime;
                offeringTokenVestedHarvest = (offeringTokenVestedAmount * unlockTime) / totalVestingTime;
            }
            offeringTokensVesting = offeringTokenUnclaimed.sub(offeringTokenVestedHarvest);
        }
        offeringTokenTotalHarvest = offeringTokenInitialHarvest + offeringTokenVestedHarvest;
    }

    /**
     * @notice It calculates the tax overflow given the raisingAmountPool and the totalAmountPool.
     * @dev 100,000,000,000 means 0.1 (10%) / 1 means 0.0000000000001 (0.0000001%) / 1,000,000,000,000 means 1 (100%)
     * @return It returns the tax percentage
     */
    function _calculateTaxOverflow(uint256 _totalAmountPool, uint256 _raisingAmountPool)
    internal
    pure
    returns (uint256)
    {
        uint256 ratioOverflow = _totalAmountPool.div(_raisingAmountPool);

        if (ratioOverflow >= 1500) {
            return 500000000;
            // 0.05%
        } else if (ratioOverflow >= 1000) {
            return 1000000000;
            // 0.1%
        } else if (ratioOverflow >= 500) {
            return 2000000000;
            // 0.2%
        } else if (ratioOverflow >= 250) {
            return 2500000000;
            // 0.25%
        } else if (ratioOverflow >= 100) {
            return 3000000000;
            // 0.3%
        } else if (ratioOverflow >= 50) {
            return 5000000000;
            // 0.5%
        } else {
            return 10000000000;
            // 1%
        }
    }

    /**
     * @notice It calculates the offering amount for a user and the number of raising tokens to transfer back.
     * @param _user: user address
     * @param _pid: pool id
     * @return {uint256, uint256, uint256} It returns the offering amount, the refunding amount (in raising tokens),
     * and the tax (if any, else 0)
     */
    function _calculateOfferingAndRefundingAmountsPool(address _user, uint8 _pid)
    internal
    view
    returns (
        uint256,
        uint256,
        uint256
    )
    {
        uint256 userOfferingAmount;
        uint256 userRefundingAmount;
        uint256 taxAmount;

        if (_poolInformation[_pid].totalAmountPool > _poolInformation[_pid].raisingAmountPool) {
            // Calculate allocation for the user
            uint256 allocation = _getUserAllocationPool(_user, _pid);

            // Calculate the offering amount for the user based on the offeringAmount for the pool
            userOfferingAmount = _poolInformation[_pid].offeringAmountPool.mul(allocation).div(1e12);

            // Calculate the payAmount
            uint256 payAmount = _poolInformation[_pid].raisingAmountPool.mul(allocation).div(1e12);

            // Calculate the pre-tax refunding amount
            userRefundingAmount = _userInfo[_user][_pid].amountPool.sub(payAmount);

            // Retrieve the tax rate
            if (_poolInformation[_pid].hasTax) {
                uint256 taxOverflow = _calculateTaxOverflow(
                    _poolInformation[_pid].totalAmountPool,
                    _poolInformation[_pid].raisingAmountPool
                );

                // Calculate the final taxAmount
                taxAmount = userRefundingAmount.mul(taxOverflow).div(1e12);

                // Adjust the refunding amount
                userRefundingAmount = userRefundingAmount.sub(taxAmount);
            }
        } else {
            userRefundingAmount = 0;
            taxAmount = 0;
            // _userInfo[_user] / (raisingAmount / offeringAmount)
            userOfferingAmount = _userInfo[_user][_pid].amountPool.mul(_poolInformation[_pid].offeringAmountPool).div(
                _poolInformation[_pid].raisingAmountPool
            );
        }
        return (userOfferingAmount, userRefundingAmount, taxAmount);
    }

    /**
     * @notice It returns the user allocation for pool
     * @dev 100,000,000,000 means 0.1 (10%) / 1 means 0.0000000000001 (0.0000001%) / 1,000,000,000,000 means 1 (100%)
     * @param _user: user address
     * @param _pid: pool id
     * @return it returns the user's share of pool
     */
    function _getUserAllocationPool(address _user, uint8 _pid) internal view returns (uint256) {
        if (_poolInformation[_pid].totalAmountPool > 0) {
            return _userInfo[_user][_pid].amountPool.mul(1e18).div(_poolInformation[_pid].totalAmountPool.mul(1e6));
        } else {
            return 0;
        }
    }

    /**
     * @notice Check if an address is a contract
     */
    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}
