// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import "../libraries/SafeMath.sol";
import "../libraries/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EvmosFaucet is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public treasury;

    address public immutable dai;
    address public immutable usdc;
    address public immutable usdt;

    uint256 public constant FAUCET_AMOUNT = 50; // 50 pre address

    constructor(
        address _dai,
        address _usdc,
        address _usdt
    ) public {
        dai = _dai;
        usdc = _usdc;
        usdt = _usdt;
        treasury = msg.sender;
    }

    receive() external payable {}

    function faucetTokenWithETH(address _token) external payable {
        require(msg.value > 0, "No ETH sent");
        uint decimals = IERC20(_token).decimals();
        require(IERC20(_token).balanceOf(address(this)) >= FAUCET_AMOUNT.mul(10 ** decimals), 'Not enough faucet token');

        IERC20(_token).safeTransfer(_msgSender(), FAUCET_AMOUNT.mul(10 ** decimals));
    }

    function adminWithdrawETH() external onlyOwner {
        require(address(this).balance > 0, "No ETH to withdraw");

        (bool success,) = treasury.call{value : address(this).balance}("");
        require(success, "Transfer failed");
    }

    function adminWithdrawERC20(address ERC20token) external onlyOwner {
        uint256 withdrawAmount = IERC20(ERC20token).balanceOf(address(this));
        require(withdrawAmount > 0, "No ERC20 to withdraw");

        IERC20(ERC20token).safeTransfer(treasury, withdrawAmount);
    }
}