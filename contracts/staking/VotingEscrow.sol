// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IRewardPool.sol";
import "../interfaces/IMasterChef.sol";

contract VotingEscrow is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    enum ActionType {DEPOSIT_FOR, CREATE_LOCK, INCREASE_LOCK_AMOUNT, INCREASE_UNLOCK_TIME}

    uint256 public constant WEEK = 7 * 86400;
    uint256 public constant MAXTIME = 4 * 365 * 86400;  // 4 years
    uint256 public constant MULTIPLIER = 1e18;

    struct Point {
        int128 bias;
        int128 slope;   // - dweight / dt
        uint256 ts;
        uint256 blk;    // block
    }

    struct LockedBalance {
        int128 amount;
        uint256 end;
    }

    string public name;
    string public symbol;
    string public version;
    uint8 public immutable decimals;

    address public token;
    IRewardPool public rewardPool;
    uint256 public supply; // total amount of emo token

    IMasterChef public masterchef;

    mapping(address => LockedBalance) public locked;

    bool public emergency;

    uint256 public epoch;
    Point[100000000000000000000000000000] public pointHistory; // epoch -> point
    mapping(address => Point[1000000000]) public userPointHistory; // user -> Point[user_epoch]
    mapping(address => uint256) public userPointEpoch;
    mapping(uint256 => int128) public slopeChanges; // time -> slope change

    mapping(address => bool) public whitelist; // Only EOA or contract whitelisted is allowed to deposit

    event Deposit(address indexed provider, uint256 indexed locktime, uint256 value, uint actionType, uint256 ts);
    event Withdraw(address indexed provider, uint256 value, uint256 ts);
    event Supply(uint256 prevSupply, uint256 supply);
    event Error(bytes error);

    modifier onlyEoaOrWhitelist(address addr) {
        require(tx.origin == msg.sender || whitelist[addr], "Contract is not in the whitelist");
        _;
    }

    modifier notEmergency() {
        require(!emergency, "In an emergency");
        _;
    }

    constructor(address _token, string memory _name, string memory _symbol, string memory _version) public {
        token = _token;
        pointHistory[0].blk = block.number;
        pointHistory[0].ts = block.timestamp;

        decimals = ERC20(_token).decimals();
        name = _name;
        symbol = _symbol;
        version = _version;
    }

    /**
    * @notice Sets a list of users who are allowed/denied to deposit
    * @param _users A list of address
    * @param _flag True to allow or false to disallow
    */
    function setWhitelist(address [] memory _users, bool _flag) external onlyOwner {
        for (uint i = 0; i < _users.length; i++) {
            whitelist[_users[i]] = _flag;
        }
    }

    /**
    * @notice Only set once
    * @param _rewardPool Address of reward pool
    */
    function setRewardPool(IRewardPool _rewardPool) external onlyOwner {
        require(address(rewardPool) == address(0), "RewardPool has been set");
        rewardPool = _rewardPool;
        IERC20(token).approve(address(_rewardPool), uint256(~0));
    }

    /**
    * @notice Only set once
    * @param _masterchef Address of masterchef
    */
    function setMasterchef(IMasterChef _masterchef) external onlyOwner {
        masterchef = _masterchef;
    }

    /**
    * @notice Only set once
    */
    function setEmergency() external onlyOwner {
        emergency = true;
    }

    /**
    * @notice Get the most recently recorded rate of voting power decrease for `addr`
    * @param addr Address of the user wallet
    * @return Value of the slope
    **/
    function getLastUserSlope(address addr) external view returns (int128) {
        uint256 uepoch = userPointEpoch[addr];
        return userPointHistory[addr][uepoch].slope;
    }

    /**
    * @notice Get the timestamp for checkpoint `_idx` for `_addr`
    * @param _addr User wallet address
    * @param _idx User epoch number
    * @return Epoch time of the checkpoint
    **/
    function userPointHistoryTs(address _addr, uint256 _idx) external view returns (uint256) {
        return userPointHistory[_addr][_idx].ts;
    }

    /**
    * @notice Get timestamp when `_addr`'s lock finishes
    * @param _addr User wallet
    * @return Epoch time of the lock end
    **/
    function lockedEnd(address _addr) external view returns (uint256) {
        return locked[_addr].end;
    }

    /**
    * @notice Record global and per-user data to checkpoint
    * @param addr User's wallet address. No user checkpoint if 0x0
    * @param oldLocked Pevious locked amount / end lock time for the user
    * @param newLocked New locked amount / end lock time for the user
    **/
    function _checkpoint(address addr, LockedBalance memory oldLocked, LockedBalance memory newLocked) internal {
        Point memory uOld;
        Point memory uNew;
        int128 oldDslope = 0;
        int128 newDslope = 0;
        uint256 _epoch = epoch;

        if (addr != address(0)) {
            if (oldLocked.end > block.timestamp && oldLocked.amount > 0) {
                uOld.slope = oldLocked.amount / int128(MAXTIME);
                uOld.bias = uOld.slope * (int128(oldLocked.end - block.timestamp));
            }
            if (newLocked.end > block.timestamp && newLocked.amount > 0) {
                uNew.slope = newLocked.amount / int128(MAXTIME);
                uNew.bias = uNew.slope * (int128(newLocked.end - block.timestamp));
            }

            oldDslope = slopeChanges[oldLocked.end];
            if (newLocked.end != 0) {
                if (newLocked.end == oldLocked.end) {
                    newDslope = oldDslope;
                } else {
                    newDslope = slopeChanges[newLocked.end];
                }
            }
        }

        Point memory lastPoint = Point({bias : 0, slope : 0, ts : block.timestamp, blk : block.number});
        if (_epoch > 0) {
            lastPoint = pointHistory[_epoch];
        }
        uint256 lastCheckpoint = lastPoint.ts;

        Point memory initialLastPoint = Point({bias : lastPoint.bias, slope : lastPoint.slope, ts : lastPoint.ts, blk : lastPoint.blk});
        // dblock/dt
        uint256 blockSlope = 0;
        if (block.timestamp > lastPoint.ts) {
            blockSlope = MULTIPLIER * (block.number - lastPoint.blk) / (block.timestamp - lastPoint.ts);
        }

        // Go over weeks to fill history and calculate what the current point is
        uint256 t_i = (lastCheckpoint / WEEK) * WEEK;
        for (uint i; i < 255; i++) {
            t_i += WEEK;
            int128 dSlope = 0;
            if (t_i > block.timestamp) {
                t_i = block.timestamp;
            } else {
                dSlope = slopeChanges[t_i];
            }
            lastPoint.bias -= (lastPoint.slope * (int128(t_i - lastCheckpoint)));
            lastPoint.slope += dSlope;
            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }
            // It will never happen,just in case
            if (lastPoint.slope < 0) {
                lastPoint.slope = 0;
            }
            lastCheckpoint = t_i;
            lastPoint.ts = t_i;
            lastPoint.blk = initialLastPoint.blk.add(blockSlope.mul(t_i.sub(initialLastPoint.ts)).div(MULTIPLIER));
            _epoch += 1;
            if (t_i == block.timestamp) {
                lastPoint.blk = block.number;
                break;
            } else {
                pointHistory[_epoch] = lastPoint;
            }
        }

        epoch = _epoch;

        if (addr != address(0)) {
            // If last point was in this block, the slope change has been applied already
            lastPoint.slope += (uNew.slope - uOld.slope);
            lastPoint.bias += (uNew.bias - uOld.bias);
            if (lastPoint.slope < 0) {
                lastPoint.slope = 0;
            }
            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }
        }

        // Record the changed point into history
        pointHistory[_epoch] = lastPoint;

        // avoid stack too deep
        address _addr = addr;
        if (_addr != address(0)) {
            // Schedule the slope changes (slope is going down)
            // We subtract new_user_slope from [newLocked.end]
            // and add old_user_slope to [oldLocked.end]
            if (oldLocked.end > block.timestamp) {
                oldDslope += uOld.slope;
                if (newLocked.end == oldLocked.end) {
                    oldDslope -= uNew.slope;
                }
                slopeChanges[oldLocked.end] = oldDslope;
            }

            if (newLocked.end > block.timestamp) {
                if (newLocked.end > oldLocked.end) {
                    // old slope disappeared at this point
                    newDslope -= uNew.slope;
                    slopeChanges[newLocked.end] = newDslope;
                }
            }

            // Now handle user history
            uint256 userEpoch = userPointEpoch[_addr] + 1;

            userPointEpoch[_addr] = userEpoch;
            uNew.ts = block.timestamp;
            uNew.blk = block.number;
            userPointHistory[_addr][userEpoch] = uNew;
        }
    }

    /**
    * @notice Deposit and lock tokens for a user
    * @param _addr User's wallet address
    * @param _value Amount to deposit
    * @param unlockTime New time when to unlock the tokens, or 0 if unchanged
    * @param lockedBalance Previous locked amount / timestamp
    **/
    function _depositFor(address _addr, uint256 _value, uint256 unlockTime, LockedBalance memory lockedBalance, ActionType actionType) internal {
        LockedBalance memory _locked = lockedBalance;
        uint256 supplyBefore = supply;

        supply = supplyBefore.add(_value);
        LockedBalance memory oldLocked = LockedBalance({amount : _locked.amount, end : _locked.end});
        _locked.amount += int128(_value);
        if (unlockTime != 0) {
            _locked.end = unlockTime;
        }
        locked[_addr] = _locked;

        // Possibilities:
        // Both old_locked.end could be current or expired (>/< block.timestamp)
        // value == 0 (extend lock) or value > 0 (add to lock or extend lock)
        // _locked.end > block.timestamp (always)
        _checkpoint(_addr, oldLocked, _locked);

        if (_value != 0) {
            require(ERC20(token).transferFrom(_addr, address(this), _value), "Transfer failed!");
            require(rewardPool.depositFor(_addr, _value), "Deposit into reward pool failed.");
        }

        emit Deposit(_addr, _locked.end, _value, uint(actionType), block.timestamp);
        emit Supply(supplyBefore, supplyBefore + _value);
    }

    /**
    * @notice Record global data to checkpoint
    **/
    function checkpoint() external notEmergency {
        _checkpoint(address(0), LockedBalance({amount : 0, end : 0}), LockedBalance({amount : 0, end : 0}));
    }

    /**
    * @notice Deposit `_value` tokens for `_addr` and add to the lock
    * @dev Anyone (even a smart contract) can deposit for someone else, but
    * cannot extend their locktime and deposit for a brand new user
    * @param _addr User's wallet address
    * @param _value Amount to add to user's lock
    **/
    function depositFor(address _addr, uint256 _value) public nonReentrant notEmergency {
        require(_value > 0, "Need non-zero value");
        LockedBalance memory _locked = locked[_addr];
        require(_locked.amount > 0, "No existing lock found");
        require(_locked.end > block.timestamp, "Cannot add to expired lock. Withdraw");

        _depositFor(_addr, _value, 0, _locked, ActionType.DEPOSIT_FOR);
    }

    function depositForWithMc(address _addr, uint256 _value) external {
        depositFor(_addr, _value);
        masterchef.harvestAllRewards(_addr);
    }

    /**
    * @notice Deposit `_value` tokens for `msg.sender` and lock until `_unlock_time`
    * @param _value Amount to deposit
    * @param _unlockTime Epoch time when tokens unlock, rounded down to whole weeks
    **/
    function createLock(uint256 _value, uint256 _unlockTime) public nonReentrant notEmergency onlyEoaOrWhitelist(msg.sender) {
        require(_value > 0, "Need non-zero value");

        // Locktime is rounded down to weeks
        uint256 unlockTime = (_unlockTime / WEEK) * WEEK;
        LockedBalance memory _locked = locked[msg.sender];
        require(_locked.amount == 0, "Withdraw old tokens first");
        require(unlockTime > block.timestamp, "Can only lock until time in the future");
        require(unlockTime <= block.timestamp + MAXTIME, "Voting lock can be 4 years max");

        _depositFor(msg.sender, _value, unlockTime, _locked, ActionType.CREATE_LOCK);
    }

    function createLockWithMc(uint256 _value, uint256 _unlockTime) external {
        createLock(_value, _unlockTime);
        masterchef.harvestAllRewards(msg.sender);
    }

    /**
    * @notice Deposit `_value` additional tokens for `msg.sender`
    * without modifying the unlock time
    * @param _value Amount of tokens to deposit and add to the lock
    **/
    function increaseAmount(uint256 _value) public nonReentrant notEmergency onlyEoaOrWhitelist(msg.sender) {
        require(_value > 0, "Need non-zero value");
        LockedBalance memory _locked = locked[msg.sender];
        require(_locked.amount > 0, "No existing lock found");
        require(_locked.end > block.timestamp, "Cannot add to expired lock. Withdraw");

        _depositFor(msg.sender, _value, 0, _locked, ActionType.INCREASE_LOCK_AMOUNT);
    }

    function increaseAmountWithMc(uint256 _value) external {
        increaseAmount(_value);
        masterchef.harvestAllRewards(msg.sender);
    }

    /**
    * @notice Extend the unlock time for `msg.sender` to `_unlock_time`
    * @param _unlockTime New epoch time for unlocking
    **/
    function increaseUnlockTime(uint256 _unlockTime) public nonReentrant notEmergency onlyEoaOrWhitelist(msg.sender) {
        LockedBalance memory _locked = locked[msg.sender];
        uint256 unlockTime = (_unlockTime / WEEK) * WEEK;

        require(_locked.end > block.timestamp, "Lock expired");
        require(_locked.amount > 0, "Nothing is locked");
        require(unlockTime > _locked.end, "Can only increase lock duration");
        require(unlockTime <= block.timestamp + MAXTIME, "Voting lock can be 4 years max");

        _depositFor(msg.sender, 0, unlockTime, _locked, ActionType.INCREASE_UNLOCK_TIME);
    }

    function increaseUnlockTimeWithMc(uint256 _unlockTime) external {
        increaseUnlockTime(_unlockTime);
        masterchef.harvestAllRewards(msg.sender);
    }

    /**
    * @notice Withdraw all tokens for `msg.sender`
    * @dev Only possible if the lock has expired
    **/
    function withdraw() public nonReentrant notEmergency {
        LockedBalance memory _locked = locked[msg.sender];
        require(block.timestamp >= _locked.end, "The lock didn't expire");

        uint256 value = uint256(_locked.amount);
        LockedBalance memory oldLocked = locked[msg.sender];
        _locked.end = 0;
        _locked.amount = 0;
        locked[msg.sender] = _locked;

        uint256 supplyBefore = supply;
        supply = supplyBefore.sub(value);

        // oldLocked can have either expired <= timestamp or zero end
        // _locked has only 0 end
        // Both can have >= 0 amount
        _checkpoint(msg.sender, oldLocked, _locked);
        require(rewardPool.withdrawFor(msg.sender, value), "Withdraw from reward pool failed.");
        require(ERC20(token).transfer(msg.sender, value), "Transfer failed!");

        emit Withdraw(msg.sender, value, block.timestamp);
        emit Supply(supplyBefore, supplyBefore - value);
    }

    /**
    * @notice Withdraw during emergency
    **/
    function emergencyWithdraw() external {
        require(emergency, "Only can be called in an emergency");

        LockedBalance storage _locked = locked[msg.sender];
        uint256 value = uint256(_locked.amount);
        try rewardPool.emergencyWithdraw(msg.sender) {
        } catch (bytes memory error) {
            emit Error(error);
        }

        _locked.end = 0;
        _locked.amount = 0;
        if (supply >= value) {
            supply = supply - value;
        } else {
            supply = 0;
        }
        ERC20(token).transfer(msg.sender, value);
    }

    function withdrawWithMc() external {
        withdraw();
        masterchef.harvestAllRewards(msg.sender);
    }

    /**
    * The following ERC20/minime-compatible methods are not real balanceOf and supply!
    * They measure the weights for the purpose of voting, so they don't represent
    * real coins.
    **/

    /**
    * @notice Binary search to estimate timestamp for block number
    * @param _block Block to find
    * @param maxEpoch Don't go beyond this epoch
    * @return Approximate timestamp for block
    **/
    function findBlockEpoch(uint256 _block, uint256 maxEpoch) internal view returns (uint256){
        // binary search
        uint256 _min = 0;
        uint256 _max = maxEpoch;
        for (uint i; i < 128; i++) {
            if (_min >= _max) {
                break;
            }
            uint256 _mid = (_min + _max + 1) / 2;
            if (pointHistory[_mid].blk <= _block) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }
        return _min;
    }

    /**
    * @notice Get the voting power for `msg.sender`
    * @param addr User wallet address
    * @param _t Epoch time to return voting power at
    * @return User voting power
    **/
    function balanceOfT(address addr, uint256 _t) public view returns (uint256) {
        uint256 _epoch = userPointEpoch[addr];
        if (_epoch == 0) {
            return 0;
        } else {
            Point memory lastPoint = userPointHistory[addr][_epoch];
            lastPoint.bias -= lastPoint.slope * (int128(_t - lastPoint.ts));
            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }
            return uint256(lastPoint.bias);
        }
    }

    /**
    * @notice Get the current voting power for `msg.sender`
    * @param addr User wallet address
    * @return User voting power
    **/
    function balanceOf(address addr) external view returns (uint256) {
        return balanceOfT(addr, block.timestamp);
    }

    /**
    * @notice Measure voting power of `addr` at block height `_block`
    * @param addr User's wallet address
    * @param _block Block to calculate the voting power at
    * @return Voting power
    **/
    function balanceOfB(address addr, uint256 _block) external view returns (uint256) {
        require(_block <= block.number, "Block should not be greater than current block!");

        uint256 _min = 0;
        uint256 _max = userPointEpoch[addr];
        for (uint i; i < 128; i++) {
            if (_min >= _max) {
                break;
            }
            uint256 _mid = (_min + _max + 1) / 2;
            if (userPointHistory[addr][_mid].blk <= _block) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }

        Point memory upoint = userPointHistory[addr][_min];

        uint256 maxEpoch = epoch;
        uint256 _epoch = findBlockEpoch(_block, maxEpoch);
        Point memory point0 = pointHistory[_epoch];
        uint256 dBlock = 0;
        uint256 dT = 0;
        if (_epoch < maxEpoch) {
            Point memory point1 = pointHistory[_epoch + 1];
            dBlock = point1.blk.sub(point0.blk);
            dT = point1.ts.sub(point0.ts);
        } else {
            dBlock = block.number.sub(point0.blk);
            dT = block.timestamp.sub(point0.ts);
        }
        uint256 blockTime = point0.ts;
        if (dBlock != 0) {
            blockTime += dT * (_block.sub(point0.blk)) / dBlock;
        }

        upoint.bias -= upoint.slope * int128(blockTime - upoint.ts);
        if (upoint.bias >= 0) {
            return uint256(upoint.bias);
        } else {
            return 0;
        }
    }

    /**
    * @notice Calculate total voting power at some point in the past
    * @param point The point (bias/slope) to start search from
    * @param t Time to calculate the total voting power at
    * @return Total voting power at that time
    **/
    function supplyAt(Point memory point, uint256 t) internal view returns (uint256) {
        Point memory lastPoint = point;
        uint256 t_i = (lastPoint.ts / WEEK) * WEEK;
        for (uint i; i < 255; i++) {
            t_i += WEEK;
            int128 dSlope = 0;
            if (t_i > t) {
                t_i = t;
            } else {
                dSlope = slopeChanges[t_i];
            }
            lastPoint.bias -= lastPoint.slope * int128(t_i - lastPoint.ts);
            if (t_i == t) {
                break;
            }
            lastPoint.slope += dSlope;
            lastPoint.ts = t_i;
        }

        if (lastPoint.bias < 0) {
            lastPoint.bias = 0;
        }
        return uint256(lastPoint.bias);
    }

    /**
    * @notice Calculate total voting power
    * @param t Time to calculate the total voting power at
    * @return Total voting power
    **/
    function totalSupplyT(uint256 t) public view returns (uint256) {
        Point memory lastPoint = pointHistory[epoch];
        return supplyAt(lastPoint, t);
    }

    /**
    * @notice Calculate current total voting power
    * @return Total voting power
    **/
    function totalSupply() external view returns (uint256) {
        return totalSupplyT(block.timestamp);
    }

    /**
    * @notice Calculate total voting power at some point in the past
    * @param _block Block to calculate the total voting power at
    * @return Total voting power at `_block`
    **/
    function totalSupplyB(uint256 _block) external view returns (uint256) {
        require(_block <= block.number, "Block should not be greater than current block!");
        uint256 _epoch = epoch;
        uint256 targetEpoch = findBlockEpoch(_block, _epoch);

        Point memory point = pointHistory[targetEpoch];
        uint256 dt = 0;
        if (targetEpoch < _epoch) {
            Point memory nextPoint = pointHistory[targetEpoch + 1];
            if (point.blk != nextPoint.blk) {
                dt = (_block - point.blk) * (nextPoint.ts - point.ts) / (nextPoint.blk - point.blk);
            }
        } else {
            if (point.blk != block.number) {
                dt = (_block - point.blk) * (block.timestamp - point.ts) / (block.number - point.blk);
            }
        }

        // Now dt contains info on how far are we beyond point
        return supplyAt(point, point.ts + dt);
    }
}