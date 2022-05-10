import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { parseUnits } from "ethers/lib/utils";

const func: DeployFunction = async({getNamedAccounts, deployments, network, ethers}) => {
  console.log("> (995) Deploy EMOPrivateSale:");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const emoToken = await ethers.getContract("EMOToken");

  // 0 modify USDC address
  // 1 deploy contract
  // 2 set adminSetVestingStart:  need > _preSaleEnd

  const args = [
    process.env.TESTNET_TREASURY, //_treasury
    process.env.TESTNET_TREASURY, //_keeper
    '0x9b5bb7F5BE680843Bcd3B54D4E5C6eE889c124Df', // _usdc - when mainnet need to modify it.
    emoToken.address, // _emo
    parseUnits("0.045", 6), // _tokenPrice * 1000000,
    parseUnits("4.3", 6), // _basePrice * 1000000, the price of CRO in usd multiply by PRECISION
    parseUnits("26000", 18), // _minTokensAmount -> $2000 / 0.075 = 26666
    parseUnits("133500", 18), // _maxTokensAmount -> $10000 / 0.075 = 133333
    parseUnits("14000000", 18), // _privateSaleTokenPool -> 14,000,000
    Date.UTC(2022, 4, 6, 4, 10, 0) / 1000, // _privateSaleStart year: 2000, month: 0, date: 1, hour: 12, minute: 34, second: 5
    Date.UTC(2022, 4, 6, 4, 30, 0) / 1000, // _privateSaleEnd year: 2000, month: 0, date: 1, hour: 12, minute: 34, second: 5
    1 * 24 * 3600, // _vestingDuration 365 （for testnet）
  ];

  const resultMaster = await deploy("EMOPrivateSale", {
    log: true,
    from: deployer,
    args: args,
  });

  if(resultMaster.newlyDeployed) {
    if (network.live) {
      await run("verify:verify", {
        address: resultMaster.address,
        constructorArguments: args,
      });
    }
  }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'bsctests';
};

func.tags = ["EMOPrivateSale"];