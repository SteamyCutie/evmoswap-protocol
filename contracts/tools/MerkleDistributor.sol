// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract MerkleDistributor {
    using SafeMath for uint256;

    address public immutable token;
    bytes32 public immutable merkleRoot;

    // time to start claiming
    uint256 public immutable startTime;
    // duration in seconds for 50% penalty after start
    uint256 public immutable penaltyDuration;
    // This is a packed array of booleans.
    mapping(uint256 => uint256) private collectedBitMap;
    // amount of token collected by user
    mapping(address => uint256) public collectedAmount;
    mapping(address => uint256) public collectedTime;
    // amount of token claimed by user
    mapping(address => uint256) public claimedAmount;
    // total unclaimed amount at beginning
    uint256 public totalUnclaimed;
    // total penalty
    uint256 public totalPenalty;

    // This event is triggered whenever a call to #collect succeeds.
    event Collected(uint256 index, address account, uint256 amount, uint256 adjustAmount);

    constructor(address token_, bytes32 merkleRoot_, uint256 _startTime, uint256 _penaltyDuration) public {
        token = token_;
        merkleRoot = merkleRoot_;
        startTime = _startTime;
        penaltyDuration = _penaltyDuration;
    }

    function isCollected(uint256 index) public view returns (bool) {
        uint256 collectedWordIndex = index / 256;
        uint256 collectedBitIndex = index % 256;
        uint256 collectedWord = collectedBitMap[collectedWordIndex];
        uint256 mask = (1 << collectedBitIndex);
        return collectedWord & mask == mask;
    }

    function _setCollected(uint256 index) private {
        uint256 collectedWordIndex = index / 256;
        uint256 collectedBitIndex = index % 256;
        collectedBitMap[collectedWordIndex] = collectedBitMap[collectedWordIndex] | (1 << collectedBitIndex);
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external {
        require(block.timestamp >= startTime, "MerkleDistributor: Not start.");
        require(!isCollected(index), 'MerkleDistributor: Drop already collected.');

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), 'MerkleDistributor: Invalid proof.');

        // Mark it collected and send the token.
        _setCollected(index);

        // calculate penalty
        uint256 adjustAmount;
        if (block.timestamp < startTime.add(penaltyDuration)) {
            adjustAmount = amount / 2;
            totalUnclaimed = totalUnclaimed.sub(amount);
            totalPenalty = totalPenalty.add(amount - adjustAmount);
        } else {
            adjustAmount = adjustAmount.add(totalPenalty.mul(amount).div(totalUnclaimed));
        }

        if (adjustAmount > 0) {
            require(IERC20(token).transfer(msg.sender, adjustAmount), 'MerkleDistributor: Transfer failed.');
        }
        emit Collected(index, account, amount, adjustAmount);
    }
}
