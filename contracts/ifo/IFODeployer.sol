// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./IFOInitializable.sol";

/**
 * @title IFODeployer
 */
contract IFODeployer is Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_BUFFER_TIME_INTERVAL = 7 * 86400; // 1 week

    event AdminTokenRecovery(address indexed tokenRecovered, uint256 amount);
    event NewIFOContract(address indexed ifoAddress);

    /**
     * @notice Constructor
     */
    constructor() public {
        //
    }

    /**
     * @notice It deploy the IFO contract and initializes the contract.
     * @param _offeringToken: the token that is offered for the IFO
     * @param _startTime: the start timestamp for the IFO
     * @param _endTime: the end timestamp for the IFO
     * @param _adminAddress: the admin address for handling tokens
     */
    function deployIFO(
        address _offeringToken,
        uint256 _startTime,
        uint256 _endTime,
        address _adminAddress,
        address _votingEscrowAddress,
        address _burnAddress,
        address _receiverAddress
    ) external onlyOwner {
        require(IERC20(_offeringToken).totalSupply() >= 0);
        require(_endTime < (block.timestamp + MAX_BUFFER_TIME_INTERVAL), "Operations: EndTime too far");
        require(_startTime < _endTime, "Operations: StartTime must be inferior to endTime");
        require(_startTime > block.timestamp, "Operations: StartTime must be greater than current timestamp");

        bytes memory bytecode = type(IFOInitializable).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_offeringToken, _startTime, _endTime));
        address ifoAddress;

        assembly {
            ifoAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        IFOInitializable(ifoAddress).initialize(
            _offeringToken,
            _startTime,
            _endTime,
            MAX_BUFFER_TIME_INTERVAL,
            _adminAddress,
            _votingEscrowAddress,
            _burnAddress,
            _receiverAddress
        );

        emit NewIFOContract(ifoAddress);
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @dev This function is only callable by admin.
     */
    function recoverWrongTokens(address _tokenAddress) external onlyOwner {
        uint256 balanceToRecover = IERC20(_tokenAddress).balanceOf(address(this));
        require(balanceToRecover > 0, "Operations: Balance must be > 0");
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), balanceToRecover);

        emit AdminTokenRecovery(_tokenAddress, balanceToRecover);
    }
}