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
    '0xae95d4890bf4471501E0066b6c6244E1CAaEe791', // _usdc - when mainnet need to modify it.
    emoToken.address, // _emo
    parseUnits("0.10", 6), // _tokenPrice * 1000000,
    parseUnits("0.3756", 6), // _basePrice * 1000000, the price of CRO in usd multiply by PRECISION
    parseUnits("100000", 18), // _minTokensAmount -> $10000 / 0.1 = 100000
    parseUnits("500000", 18), // _maxTokensAmount -> $50000 / 0.1 = 500000
    parseUnits("3750000", 18), // _privateSaleTokenPool -> 375 0000
    Date.UTC(2022, 3, 26, 0, 0, 0) / 1000, // _privateSaleStart year: 2000, month: 0, date: 1, hour: 12, minute: 34, second: 5
    Date.UTC(2022, 4, 5, 0, 0, 0) / 1000, // _privateSaleEnd year: 2000, month: 0, date: 1, hour: 12, minute: 34, second: 5
    365 * 24 * 3600, // _vestingDuration
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
  return hre.network.name != 'testnets';
};

func.tags = ["EMOPrivateSale"];