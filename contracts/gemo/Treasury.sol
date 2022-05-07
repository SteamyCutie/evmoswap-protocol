// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/*
 * EvmoSwap
 * App:             https://app.evmoswap.org/
 * Medium:          https://evmoswap.medium.com/
 * GitHub:          https://github.com/evmoswap/
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * The Treasury contract holds Gem EMO that can be bought with EMO and later
 *  be redeemed for EMO.
 *
 * To buy a Gem EMO, a portion of the EMO used will be burned in the process,
 *  while the remaining EMO will be locked in the contract to be unlocked at any
 *  future time.
 */
contract Treasury is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address constant burnAddress = address(0x000000000000000000000000000000000000dEaD);

    // The TOKEN to buy
    IERC20 public emo;
    // The TOKEN to sell
    IERC20 public gEmo;
    // adminAddress
    address public adminAddress;
    // buyFee, if decimal is not 18, please reset it
    uint256 public buyFee = 2857; // 28.57% or 0.2857 EMO
    // maxBuyFee, if decimal is not 18, please reset it
    uint256 public maxBuyFee = 6000; // 60% or 0.6 EMO

    // =================================

    event Buy(address indexed user, uint256 amount);
    event Sell(address indexed user, uint256 amount);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event EmergencyWithdraw(address indexed receiver, uint256 amount);
    event UpdateBuyFee(uint256 previousBuyFee, uint256 newBuyFee);

    constructor(
        IERC20 _emo,
        IERC20 _gEmo
    ) public {
        emo = _emo;
        gEmo = _gEmo;
        adminAddress = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "admin: wut?");
        _;
    }

    bool private unlocked = true;
    modifier lock() {
        require(unlocked == true, 'EvmoSwap: LOCKED');
        unlocked = false;
        _;
        unlocked = true;
    }

    /// @dev Buy Gem EMO with EMO. A potion of the EMO will be burned in the process.
    /// @param _amount Amount of Gem EMO to sell
    function buy(uint256 _amount) external lock {
        emo.safeTransferFrom(address(msg.sender), address(this), _amount);
        uint256 emoToBurn = _amount.mul(buyFee).div(10000);
        uint256 gEmoToSend = _amount.sub(emoToBurn);
        gEmo.transfer(address(msg.sender), gEmoToSend);
        _burnEMOs(emoToBurn);
        emit Buy(msg.sender, _amount);
    }

    /// @dev Sell Gem EMO to redeem for EMO
    /// @param _amount Amount of Gem EMO to sell
    function sell(uint256 _amount) external lock {
        uint256 preGemEMOReserves = gEmoReserves();
        gEmo.safeTransferFrom(address(msg.sender), address(this), _amount);
        // Because the Gem EMO is a reflect token, we need to find how much
        //  was transferred AFTER the reflect fee.
        uint256 amountIn = gEmoReserves().sub(preGemEMOReserves);
        emo.transfer(address(msg.sender), amountIn);
        emit Sell(msg.sender, _amount);
    }

    /// @dev Burns EMO by sending them to the burn address
    /// @param _amount Amount of EMO to burn
    function _burnEMOs(uint256 _amount) internal {
        emo.transfer(burnAddress, _amount);
    }

    /// @dev Obtain the amount of EMO held by this contract
    function emoReserves() public view returns (uint256) {
        return emo.balanceOf(address(this));
    }

    /// @dev Obtain the amount of Gem EMO held by this contract
    function gEmoReserves() public view returns (uint256) {
        return gEmo.balanceOf(address(this));
    }

    /* Owner Functions */

    /// @dev Use the owner address to update the admin
    function setAdmin(address _adminAddress) external onlyOwner {
        address previousAdmin = adminAddress;
        adminAddress = _adminAddress;
        emit AdminTransferred(previousAdmin, adminAddress);
    }

    /// @dev Incase of a problem with the treasury contract, the Gem EMO can be removed
    ///  and sent to a new treasury contract
    function emergencyWithdraw(uint256 _amount) external onlyOwner {
        gEmo.transferFrom(address(this), address(msg.sender), _amount);
        emit EmergencyWithdraw(msg.sender, _amount);
    }

    /* Admin Functions */

    /// @dev Set the fee that will be used to burn EMO on purchases
    /// @param _fee The fee used for burning. 10000 = 100%
    function setBuyFee(uint256 _fee) external onlyAdmin {
        require(_fee <= maxBuyFee, 'fee must be mess than maxBuyFee');
        uint256 previousBuyFee = buyFee;
        buyFee = _fee;
        emit UpdateBuyFee(previousBuyFee, buyFee);
    }
}