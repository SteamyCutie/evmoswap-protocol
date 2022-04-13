// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../libraries/SafeDecimal.sol";
import "../interfaces/IMasterChef.sol";
import "../interfaces/IEvmoSwapPair.sol";
import "../interfaces/IEvmoSwapFactory.sol";

contract Dashboard {
    using SafeMath for uint;
    using SafeDecimal for uint;

    uint256 private constant SEC_PER_YEAR = 86400 * 365;

    address private _owner;

    // WETH WFTM WBNB
    IERC20 public weth;
    IERC20 public usdc;
    IMasterChef public master;
    IEvmoSwapFactory public factory;
    IERC20 public reward; 

    mapping(address => address) public pairAddresses;

    constructor(address _weth, address _usdc, address _reward, address _master, address _factory) public {
        weth = IERC20(_weth);
        usdc = IERC20(_usdc);
        reward = IERC20(_reward);
        master = IMasterChef(_master);
        factory = IEvmoSwapFactory(_factory);
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /* ========== Restricted Operation ========== */

    function setPairAddress(address asset, address pair) external onlyOwner {
        pairAddresses[asset] = pair;
    }

    /* ========== Value Calculation ========== */

    function ethPriceInUSD() view public returns (uint) {
        address usdcEthPair = factory.getPair(address(usdc), address(weth));
        uint _decimals = ERC20(address(usdc)).decimals();
        uint _usdcValue = usdc.balanceOf(usdcEthPair).mul(10 ** (18 - uint256(_decimals)));
        return _usdcValue.mul(1e18).div(weth.balanceOf(usdcEthPair));
    }

    function rewardPriceInUSD() view public returns (uint) {
        (, uint _rewardPriceInUSD) = valueOfAsset(address(reward), 1e18);
        return _rewardPriceInUSD;
    }

    function rewardPerYearOfPool(uint pid) view public returns (uint) {
        uint256 multiplier = master.startTime() <= block.timestamp ? 1 : 0;
        (,,,uint allocPoint,,,) = master.poolInfo(pid);
        return master.emoPerSecond().mul(multiplier).mul(SEC_PER_YEAR).mul(allocPoint).div(master.totalAllocPoint());
    }

    function valueOfAsset(address asset, uint amount) public view returns (uint valueInETH, uint valueInUSD) {
        if (asset == address(0) || asset == address(weth)) {
            valueInETH = amount;
            valueInUSD = amount.mul(ethPriceInUSD()).div(1e18);
        } else if (keccak256(abi.encodePacked(IEvmoSwapPair(asset).symbol())) == keccak256("EMO-LP")) {
            if (IEvmoSwapPair(asset).token0() == address(weth) || IEvmoSwapPair(asset).token1() == address(weth)) {
                valueInETH = amount.mul(weth.balanceOf(address(asset))).mul(2).div(IEvmoSwapPair(asset).totalSupply());
                valueInUSD = valueInETH.mul(ethPriceInUSD()).div(1e18);
            } else {
                uint balanceToken0 = IERC20(IEvmoSwapPair(asset).token0()).balanceOf(asset);
                (uint token0PriceInETH,) = valueOfAsset(IEvmoSwapPair(asset).token0(), 1e18);

                valueInETH = amount.mul(balanceToken0).mul(2).mul(token0PriceInETH).div(1e18).div(IEvmoSwapPair(asset).totalSupply());
                valueInUSD = valueInETH.mul(ethPriceInUSD()).div(1e18);
            }
        } else {
            address pairAddress = pairAddresses[asset];
            if (pairAddress == address(0)) {
                pairAddress = address(weth);
            }

            address pair = factory.getPair(asset, pairAddress);
            if (pair == address(0) || IERC20(asset).balanceOf(pair) == 0) {
                valueInETH = 0;
            } else {
                valueInETH = IERC20(pairAddress).balanceOf(pair).mul(amount).div(IERC20(asset).balanceOf(pair));
                if (pairAddress != address(weth)) {
                    (uint pairValueInETH,) = valueOfAsset(pairAddress, 1e18);
                    valueInETH = valueInETH.mul(pairValueInETH).div(1e18);
                }
            }
            valueInUSD = valueInETH.mul(ethPriceInUSD()).div(1e18);
        }
    }

    /* ========== APY Calculation ========== */

    function apyOfPool(uint256 pid) public view returns (uint apyPool) {
        (address token,uint256 workingSupply,,,,,) = master.poolInfo(pid);
        (uint valueInETH,) = valueOfAsset(token, workingSupply);

        (uint rewardPriceInETH,) = valueOfAsset(address(reward), 1e18);
        uint _rewardPerYearOfPool = rewardPerYearOfPool(pid);
        if (_rewardPerYearOfPool == 0) {
            return 0;
        } else if (valueInETH == 0) {
            return 10000 * (10 ** 18);
        } else {
            // 40%
            return (master.TOKENLESS_PRODUCTION()).mul(rewardPriceInETH).mul(_rewardPerYearOfPool).div(valueInETH).div(100);
        }
    }

    function apyOfPools(uint256[] memory pids) public view returns (uint[] memory apyPool) {
        apyPool = new uint[](pids.length);
        for (uint256 i = 0; i < pids.length; i++) {
            apyPool[i] = apyOfPool(pids[i]);
        }
    }

    function boostApyOfPool(uint256 pid, address user) public view returns (uint apyPool) {
        (address token,uint256 workingSupply,,,,,) = master.poolInfo(pid);
        (uint256 amount, uint256 workingAmount,) = master.userInfo(pid, user);
        if (workingAmount == 0) {
            return apyOfPool(pid);
        }

        (uint valueInETH,) = valueOfAsset(token, amount);
        (uint rewardPriceInETH,) = valueOfAsset(address(reward), 1e18);
        uint _rewardPerYearOfPool = rewardPerYearOfPool(pid).mul(workingAmount).div(workingSupply);
        if (_rewardPerYearOfPool == 0) {
            return 0;
        } else if (valueInETH == 0) {
            return 10000 * (10 ** 18);
        } else {
            return rewardPriceInETH.mul(_rewardPerYearOfPool).div(valueInETH);
        }
    }

    function boostApyOfPools(uint256[] memory pids) public view returns (uint[] memory apyPool) {
        apyPool = new uint[](pids.length);
        for (uint256 i = 0; i < pids.length; i++) {
            apyPool[i] = apyOfPool(pids[i]);
        }
    }

    /* ========== TVL Calculation ========== */
    function tvlOfPool(uint256 pid) public view returns (uint256 allocPoint, uint tvl, uint tvlInUSD) {
        (address token,,,uint256 _allocPoint,,,) = master.poolInfo(pid);
        allocPoint = _allocPoint;
        tvl = IERC20(token).balanceOf(address(master));
        (, tvlInUSD) = valueOfAsset(token, tvl);
    }

    function tvlOfPools(uint256[] memory pids) public view returns (uint totalTvl, uint totalTvlInUSD, uint256[] memory allocPoint, uint[] memory tvl, uint[] memory tvlInUSD) {
        totalTvl = 0;
        totalTvlInUSD = 0;
        allocPoint = new uint256[](pids.length);
        tvl = new uint[](pids.length);
        tvlInUSD = new uint[](pids.length);
        for (uint256 i = 0; i < pids.length; i++) {
            (allocPoint[i], tvl[i], tvlInUSD[i]) = tvlOfPool(pids[i]);
            totalTvl = totalTvl.add(tvl[i]);
            totalTvlInUSD = totalTvlInUSD.add(tvlInUSD[i]);
        }
    }

    function infoOfPools(uint256[] memory pids) public view returns (uint tokenPrice, uint totalTvl, uint totalTvlInUSD, uint256[] memory allocPoint, uint[] memory apy, uint[] memory tvl, uint[] memory tvlInUSD) {
        totalTvl = 0;
        totalTvlInUSD = 0;
        allocPoint = new uint256[](pids.length);
        apy = new uint[](pids.length);
        tvl = new uint[](pids.length);
        tvlInUSD = new uint[](pids.length);
        tokenPrice = rewardPriceInUSD();
        for (uint256 i = 0; i < pids.length; i++) {
            apy[i] = apyOfPool(pids[i]);
            (allocPoint[i], tvl[i], tvlInUSD[i]) = tvlOfPool(pids[i]);
            totalTvl = totalTvl.add(tvl[i]);
            totalTvlInUSD = totalTvlInUSD.add(tvlInUSD[i]);
        }
    }

    function boostInfoOfPools(uint256[] memory pids, address user) public view returns (uint tokenPrice, uint totalTvl, uint totalTvlInUSD, uint256[] memory allocPoint, uint[] memory apy, uint[] memory boostApy, uint[] memory tvl, uint[] memory tvlInUSD) {
        totalTvl = 0;
        totalTvlInUSD = 0;
        allocPoint = new uint256[](pids.length);
        apy = new uint[](pids.length);
        boostApy = new uint[](pids.length);
        tvl = new uint[](pids.length);
        tvlInUSD = new uint[](pids.length);
        tokenPrice = rewardPriceInUSD();
        for (uint256 i = 0; i < pids.length; i++) {
            apy[i] = apyOfPool(pids[i]);
            boostApy[i] = boostApyOfPool(pids[i], user);
            (allocPoint[i], tvl[i], tvlInUSD[i]) = tvlOfPool(pids[i]);
            totalTvl = totalTvl.add(tvl[i]);
            totalTvlInUSD = totalTvlInUSD.add(tvlInUSD[i]);
        }
    }
}