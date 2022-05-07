// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

interface IVotingEscrow {
    struct Point {
        int128 bias;
        int128 slope;
        uint256 ts;
        uint256 blk;
    }

    function userPointEpoch(address addr) external view returns (uint256);

    function epoch() external view returns (uint256);

    function userPointHistory(address addr, uint256 loc) external view returns (Point memory point);

    function pointHistory(uint256 loc) external view returns (Point memory point);

    function checkpoint() external;
}

/**
 * Independent of votingescrow's reward contract
 * As a tool for distributing rewards!
 */
contract FeeDistributor is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant WEEK = 7 * 86400;
    uint256 public constant TOKEN_CHECKPOINT_DEADLINE = 86400;


    uint256 public startTime;
    uint256 public timeCursor;
    mapping(address => uint256) public timeCursorOf;
    mapping(address => uint256) public userEpochOf;

    uint256 public lastTokenTime;
    uint256[1000000000000000] public tokensPerWeek;

    address public votingEscrow;
    address public token;
    uint256 public tokenLastBalance;

    // VE total supply at week bounds
    uint256[1000000000000000] public veSupply;

    bool public canCheckpointToken;
    address public emergencyReturn;
    bool public isKilled;

    event ToggleAllowCheckpointToken(bool toggleFlag);
    event CheckpointToken(uint256 time, uint256 tokens);
    event Claimed(address indexed recipient, uint256 amount, uint256 claimEpoch, uint256 maxEpoch);

    /***
    * @notice Contract constructor
    * @param _votingEscrow VotingEscrow contract address
    * @param _startTime Epoch time for fee distribution to start
    * @param _token Fee token address
    * @param _emergencyReturn Address to transfer `_token` balance to,if this contract is killed
    ***/
    constructor(address _votingEscrow, uint256 _startTime, address _token, address _emergencyReturn) public {
        uint256 t = _startTime / WEEK * WEEK;
        startTime = t;
        lastTokenTime = t;
        timeCursor = t;
        token = _token;
        votingEscrow = _votingEscrow;
        emergencyReturn = _emergencyReturn;
    }

    function max(int128 x, int128 y) internal pure returns (int128 z) {
        z = x < y ? y : x;
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    function _checkpointToken() internal {
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        uint256 toDistribute = tokenBalance.sub(tokenLastBalance);
        tokenLastBalance = tokenBalance;

        uint256 t = lastTokenTime;
        uint256 sinceLast = block.timestamp.sub(t);
        lastTokenTime = block.timestamp;
        uint256 thisWeek = t / WEEK * WEEK;
        uint256 nextWeek = 0;

        for (uint i; i < 20; i++) {
            nextWeek = thisWeek + WEEK;
            if (block.timestamp < nextWeek) {
                if (sinceLast == 0 && block.timestamp == t) {
                    tokensPerWeek[thisWeek] = tokensPerWeek[thisWeek].add(toDistribute);
                } else {
                    tokensPerWeek[thisWeek] = tokensPerWeek[thisWeek].add(toDistribute.mul(block.timestamp.sub(t)).div(sinceLast));
                }
                break;
            } else {
                if (sinceLast == 0 && nextWeek == t) {
                    tokensPerWeek[thisWeek] = tokensPerWeek[thisWeek].add(toDistribute);
                } else {
                    tokensPerWeek[thisWeek] = tokensPerWeek[thisWeek].add(toDistribute.mul(nextWeek.sub(t)).div(sinceLast));
                }
            }
            t = nextWeek;
            thisWeek = nextWeek;
        }

        emit CheckpointToken(block.timestamp, toDistribute);
    }

    /***
    * @notice Update the token checkpoint
    * @dev Calculates the total number of tokens to be distributed in a given week.
    * During setup for the initial distribution this function is only callable
    * by the contract owner. Beyond initial distro, it can be enabled for anyone
    * to call.
    ***/
    function checkpointToken() external {
        require(msg.sender == owner()
            || (canCheckpointToken && (block.timestamp > lastTokenTime + TOKEN_CHECKPOINT_DEADLINE)), "Wrong user!");
        _checkpointToken();
    }

    function _findTimestampEpoch(address ve, uint256 _timestamp) internal view returns (uint256) {
        uint256 _min = 0;
        uint256 _max = IVotingEscrow(ve).epoch();
        for (uint i; i < 128; i++) {
            if (_min >= _max) {
                break;
            }
            uint256 _mid = (_min + _max + 2) / 2;
            IVotingEscrow.Point memory pt = IVotingEscrow(ve).pointHistory(_mid);
            if (pt.ts <= _timestamp) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }
        return _min;
    }

    function _findTimestampUserEpoch(address ve, address user, uint256 _timestamp, uint256 maxUserEpoch) internal view returns (uint256) {
        uint256 _min = 0;
        uint256 _max = maxUserEpoch;
        for (uint i; i < 128; i++) {
            if (_min >= _max) {
                break;
            }
            uint256 _mid = (_min + _max + 2) / 2;
            IVotingEscrow.Point memory pt = IVotingEscrow(ve).userPointHistory(user, _mid);
            if (pt.ts <= _timestamp) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }
        return _min;
    }

    /***
    * @notice Get the veCRV balance for `_user` at `_timestamp`
    * @param _user Address to query balance for
    * @param _timestamp Epoch time
    * @return uint256 veCRV balance
    ***/
    function veForAt(address _user, uint256 _timestamp) external view returns (uint256) {
        address ve = votingEscrow; // gas savings
        uint256 maxUserEpoch = IVotingEscrow(ve).userPointEpoch(_user);
        uint256 epoch = _findTimestampUserEpoch(ve, _user, _timestamp, maxUserEpoch);
        IVotingEscrow.Point memory pt = IVotingEscrow(ve).userPointHistory(_user, epoch);
        return uint256(max(pt.bias - pt.slope * int128(_timestamp - pt.ts), 0));
    }

    function _checkpointTotalSupply() internal {
        address ve = votingEscrow;
        uint256 t = timeCursor;
        uint256 roundedTimestamp = block.timestamp / WEEK * WEEK;
        IVotingEscrow(ve).checkpoint();

        for (uint i; i < 20; i++) {
            if (t > roundedTimestamp) {
                break;
            } else {
                uint256 epoch = _findTimestampEpoch(ve, t);
                IVotingEscrow.Point memory pt = IVotingEscrow(ve).pointHistory(epoch);
                int128 dt = 0;
                if (t > pt.ts) {
                    dt = int128(t - pt.ts);
                }
                veSupply[t] = uint256(max(pt.bias - pt.slope * dt, 0));
            }
            t += WEEK;
        }

        timeCursor = t;
    }

    /***
    * @notice Update the veCRV total supply checkpoint
    * @dev The checkpoint is also updated by the first claimant each
    *   new epoch week. This function may be called independently
    *   of a claim, to reduce claiming gas costs.
    ***/
    function checkpointTotalSupply() external {
        _checkpointTotalSupply();
    }

    function _claim(address addr, address ve, uint256 _lastTokenTime) internal returns (uint256) {
        uint256 userEpoch = 0;
        uint256 toDistribute = 0;

        uint256 maxUserEpoch = IVotingEscrow(ve).userPointEpoch(addr);
        uint256 _startTime = startTime; // gas savings

        // No lock = no fees
        if (maxUserEpoch == 0) {
            return 0;
        }

        uint256 weekCursor = timeCursorOf[addr];
        if (weekCursor == 0) {
            userEpoch = _findTimestampUserEpoch(ve, addr, _startTime, maxUserEpoch);
        } else {
            userEpoch = userEpochOf[addr];
        }

        if (userEpoch == 0) {
            userEpoch = 1;
        }

        IVotingEscrow.Point memory userPoint = IVotingEscrow(ve).userPointHistory(addr, userEpoch);

        if (weekCursor == 0) {
            weekCursor = (userPoint.ts + WEEK - 1) / WEEK * WEEK;
        }

        if (weekCursor >= _lastTokenTime) {
            return 0;
        }

        if (weekCursor < _startTime) {
            weekCursor = _startTime;
        }
        // empty
        IVotingEscrow.Point memory oldUserPoint;


        for (uint i; i < 50; i++) {
            if (weekCursor >= _lastTokenTime) {
                break;
            }

            if (weekCursor >= userPoint.ts && userEpoch <= maxUserEpoch) {
                userEpoch += 1;
                oldUserPoint = IVotingEscrow.Point({bias : userPoint.bias, slope : userPoint.slope, ts : userPoint.ts, blk : userPoint.blk});
                if (userEpoch > maxUserEpoch) {
                    userPoint = IVotingEscrow.Point({bias : 0, slope : 0, ts : 0, blk : 0});
                } else {
                    userPoint = IVotingEscrow(ve).userPointHistory(addr, userEpoch);
                }
            } else {
                int128 dt = int128(weekCursor - oldUserPoint.ts);
                uint256 balanceOf = uint256(max(oldUserPoint.bias - dt * oldUserPoint.slope, 0));
                if (balanceOf == 0 && userEpoch > maxUserEpoch) {
                    break;
                }
                if (balanceOf > 0) {
                    toDistribute = toDistribute.add(balanceOf.mul(tokensPerWeek[weekCursor]).div(veSupply[weekCursor]));
                }

                weekCursor += WEEK;
            }
        }

        userEpoch = min(maxUserEpoch, userEpoch - 1);
        userEpochOf[addr] = userEpoch;
        timeCursorOf[addr] = weekCursor;

        emit Claimed(addr, toDistribute, userEpoch, maxUserEpoch);

        return toDistribute;
    }

    /***
    * @notice Claim fees for `_addr`
    * @dev Each call to claim look at a maximum of 50 user veCRV points.
    *    For accounts with many veCRV related actions, this function
    *    may need to be called more than once to claim all available
    *    fees. In the `Claimed` event that fires, if `claim_epoch` is
    *    less than `max_epoch`, the account may claim again.
    * @param _addr Address to claim fees for
    * @return uint256 Amount of fees claimed in the call
    ***/
    function claim(address _addr) public nonReentrant returns (uint256) {
        require(!isKilled, "Killed");

        if (block.timestamp >= timeCursor) {
            _checkpointTotalSupply();
        }

        uint256 _lastTokenTime = lastTokenTime;

        if (canCheckpointToken && (block.timestamp > _lastTokenTime + TOKEN_CHECKPOINT_DEADLINE)) {
            _checkpointToken();
            _lastTokenTime = block.timestamp;
        }

        _lastTokenTime = _lastTokenTime / WEEK * WEEK;

        uint256 amount = _claim(_addr, votingEscrow, _lastTokenTime);
        if (amount != 0) {
            IERC20(token).safeTransfer(_addr, amount);
            tokenLastBalance = tokenLastBalance.sub(amount);
        }

        return amount;
    }

    function claim() external returns (uint256) {
        return claim(msg.sender);
    }

    /***
    * @notice Make multiple fee claims in a single call
    * @dev Used to claim for many accounts at once, or to make
    *   multiple claims for the same address when that address
    *   has significant veCRV history
    * @param _receivers List of addresses to claim for. Claiming
    *   terminates at the first `ZERO_ADDRESS`.
    * @return bool success
    ***/
    function claimMany(address[] memory _receivers) external nonReentrant returns (bool) {
        require(!isKilled, "Killed");

        if (block.timestamp >= timeCursor) {
            _checkpointTotalSupply();
        }

        uint256 _lastTokenTime = lastTokenTime;

        if (canCheckpointToken && (block.timestamp > _lastTokenTime + TOKEN_CHECKPOINT_DEADLINE)) {
            _checkpointToken();
            _lastTokenTime = block.timestamp;
        }

        _lastTokenTime = _lastTokenTime / WEEK * WEEK;
        address ve = votingEscrow;
        address _token = token;
        uint256 total = 0;

        for (uint i; i < _receivers.length; i++) {
            address addr = _receivers[i];
            if (addr == address(0)) {
                break;
            }
            uint256 amount = _claim(addr, ve, _lastTokenTime);
            if (amount != 0) {
                require(IERC20(_token).transfer(addr, amount), "Transfer failed!");
                total = total.add(amount);
            }
        }

        if (total != 0) {
            tokenLastBalance = tokenLastBalance.sub(total);
        }

        return true;
    }

    /***
    * @notice Receive fee token into the contract and trigger a token checkpoint
    * @param _coin Address of the coin being received (must be fee token),just for preventing misoperation
    * @return bool success
    ***/
    function distribute(address _coin) external returns (bool) {
        require(_coin == token, "Wrong coin!");
        require(!isKilled, "Killed");

        uint256 amount = IERC20(_coin).balanceOf(msg.sender);
        if (amount != 0) {
            IERC20(_coin).transferFrom(msg.sender, address(this), amount);
            if (canCheckpointToken && (block.timestamp > lastTokenTime + TOKEN_CHECKPOINT_DEADLINE)) {
                _checkpointToken();
            }
        }

        return true;
    }

    /***
    * @notice Toggle permission for checkpointing by any account
    ***/
    function toggleAllowCheckpointToken() external onlyOwner {
        bool flag = !canCheckpointToken;
        canCheckpointToken = flag;
        emit ToggleAllowCheckpointToken(flag);
    }

    /***
    * @notice Kill the contract
    * @dev Killing transfers the entire fee token balance to the emergency return address
    *   and blocks the ability to claim or burn. The contract cannot be unkilled.
    ***/
    function killMe() external onlyOwner {
        isKilled = true;
        require(IERC20(token).transfer(emergencyReturn, IERC20(token).balanceOf(address(this))), "Transfer failed!");
    }

    /***
    * @notice Recover ERC20 tokens from this contract
    * @dev Tokens are sent to the emergency return address.
    * @param _coin Token address
    * @return bool success
    ***/
    function recoverBalance(address _coin) external onlyOwner returns (bool) {
        require(_coin != token, "Wrong coin!");
        IERC20(_coin).safeTransfer(emergencyReturn, IERC20(_coin).balanceOf(address(this)));
        return true;
    }
}