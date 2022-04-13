// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IMultiFeeDistribution.sol";

interface IMintableToken is IERC20 {
    function mint(address _receiver, uint256 _amount) external;

    function addMinter(address _minter) external returns (bool);
}

contract MultiFeeDistribution is IMultiFeeDistribution, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IMintableToken;

    /* ========== STATE VARIABLES ========== */
    struct Balances {
        uint256 total;
        uint256 unlocked;
        uint256 earned;
    }

    struct LockedBalance {
        uint256 amount;
        uint256 unlockTime;
    }

    IMintableToken public immutable stakingToken;
    // Address receive penalty
    address public penaltyReceiver;
 
    // Duration that rewards are streamed over
    uint256 public constant WEEK = 86400 * 7;

    // Duration of lock/earned penalty period
    uint256 public constant lockDuration = WEEK * 13;

    // Addresses approved to call mint
    mapping(address => bool) public minters;
    bool public mintersAreSet;

    uint256 public totalSupply;

    // Private mappings for balance data
    mapping(address => Balances) private balances;
    mapping(address => LockedBalance[]) private userEarnings;

    /* ========== CONSTRUCTOR ========== */

    constructor(address _stakingToken, address _penaltyReceiver) public {
        stakingToken = IMintableToken(_stakingToken);
        penaltyReceiver = _penaltyReceiver;
    }

    /* ========== ADMIN CONFIGURATION ========== */

    function setMinters(address[] memory _minters) external onlyOwner {
        require(!mintersAreSet);
        for (uint i; i < _minters.length; i++) {
            minters[_minters[i]] = true;
        }
        mintersAreSet = true;
    }

    /* ========== VIEWS ========== */

    // Total balance of an account, including unlocked, locked and earned tokens
    function totalBalance(address user) view external returns (uint256 amount) {
        return balances[user].total;
    }

    // Information on the "earned" balances of a user
    // Earned balances may be withdrawn immediately for a 50% penalty
    function earnedBalances(
        address user
    ) view external returns (
        uint256 total,
        LockedBalance[] memory earningsData
    ) {
        LockedBalance[] storage earnings = userEarnings[user];
        uint256 idx;
        for (uint i = 0; i < earnings.length; i++) {
            if (earnings[i].unlockTime > block.timestamp) {
                if (idx == 0) {
                    earningsData = new LockedBalance[](earnings.length - i);
                }
                earningsData[idx] = earnings[i];
                idx++;
                total = total.add(earnings[i].amount);
            }
        }
        return (total, earningsData);
    }

    // Final balance received and penalty balance paid by user upon calling exit
    function withdrawableBalance(
        address user
    ) view public returns (
        uint256 amount,
        uint256 amountWithoutPenalty,
        uint256 penaltyAmount
    ) {
        Balances storage bal = balances[user];
        uint256 earned = bal.earned;
        if (earned > 0) {
            uint256 length = userEarnings[user].length;
            for (uint i = 0; i < length; i++) {
                uint256 earnedAmount = userEarnings[user][i].amount;
                if (earnedAmount == 0) continue;
                if (userEarnings[user][i].unlockTime > block.timestamp) {
                    break;
                }
                amountWithoutPenalty = amountWithoutPenalty.add(earnedAmount);
            }

            penaltyAmount = earned.sub(amountWithoutPenalty).div(2);
        }
        amount = bal.unlocked.add(earned).sub(penaltyAmount);
        return (amount, amountWithoutPenalty, penaltyAmount);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    // Mint new tokens
    // Minted tokens receive rewards normally but incur a 50% penalty when
    // withdrawn before lockDuration has passed.
    function mint(address user, uint256 amount, bool withPenalty) external override {
        require(minters[msg.sender], "!minter");
        require(user != address(this), "self");

        if (amount == 0) {
            return;
        }

        stakingToken.mint(address(this), amount);
        totalSupply = totalSupply.add(amount);
        Balances storage bal = balances[user];
        bal.total = bal.total.add(amount);
        if (withPenalty) {
            bal.earned = bal.earned.add(amount);
            uint256 unlockTime = block.timestamp.div(WEEK).mul(WEEK).add(lockDuration);
            LockedBalance[] storage earnings = userEarnings[user];
            uint256 idx = earnings.length;
            if (idx == 0 || earnings[idx - 1].unlockTime < unlockTime) {
                earnings.push(LockedBalance({amount : amount, unlockTime : unlockTime}));
            } else {
                earnings[idx - 1].amount = earnings[idx - 1].amount.add(amount);
            }
        } else {
            bal.unlocked = bal.unlocked.add(amount);
        }
        emit Mint(user, amount, withPenalty);
    }

    // Withdraw earned tokens
    // First withdraws unlocked tokens, then earned tokens
    // incurs a 50% penalty which is distributed based on locked balances.
    function withdraw(uint256 amount) public {
        require(amount > 0, "Cannot withdraw 0");
        Balances storage bal = balances[msg.sender];
        uint256 penaltyAmount;

        if (amount <= bal.unlocked) {
            bal.unlocked = bal.unlocked.sub(amount);
        } else {
            uint256 remaining = amount.sub(bal.unlocked);
            require(bal.earned >= remaining, "Insufficient unlocked balance");
            bal.unlocked = 0;
            bal.earned = bal.earned.sub(remaining);
            for (uint i = 0;; i++) {
                uint256 earnedAmount = userEarnings[msg.sender][i].amount;
                if (earnedAmount == 0) continue;
                if (penaltyAmount == 0 && userEarnings[msg.sender][i].unlockTime > block.timestamp) {
                    penaltyAmount = remaining;
                    require(bal.earned >= remaining, "Insufficient balance after penalty");
                    bal.earned = bal.earned.sub(remaining);
                    if (bal.earned == 0) {
                        delete userEarnings[msg.sender];
                        break;
                    }
                    remaining = remaining.mul(2);
                }
                if (remaining <= earnedAmount) {
                    userEarnings[msg.sender][i].amount = earnedAmount.sub(remaining);
                    break;
                } else {
                    delete userEarnings[msg.sender][i];
                    remaining = remaining.sub(earnedAmount);
                }
            }
        }

        uint256 adjustedAmount = amount.add(penaltyAmount);
        bal.total = bal.total.sub(adjustedAmount);
        totalSupply = totalSupply.sub(adjustedAmount);
        stakingToken.safeTransfer(msg.sender, amount);
        if (penaltyAmount > 0) {
            stakingToken.safeTransfer(penaltyReceiver, penaltyAmount);
        }
        emit Withdrawn(msg.sender, amount, penaltyAmount);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(tokenAddress != address(stakingToken), "Cannot withdraw staking token");
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    /* ========== EVENTS ========== */

    event Mint(address indexed user, uint256 amount, bool withPenalty);
    event Withdrawn(address indexed user, uint256 receivedAmount, uint256 penaltyPaid);
    event Recovered(address token, uint256 amount);
}
