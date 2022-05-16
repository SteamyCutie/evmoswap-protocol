import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network, ethers}) => {
  console.log("> (999) Deploy DashboardV2:");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  if (network.name === process.env.DEPLOY_NETWORK) {
    return;
  }

  const emoToken = await ethers.getContract("EMOToken"); // testnet
  const masterChef = await ethers.getContract("MasterChef"); // testnet
  const evmoSwapFactory = await ethers.getContract("EvmoSwapFactory");


  const USDC = "0x51e44FfaD5C2B122C8b635671FCC8139dc636E82";
  const WEVMOS = '0xD4949664cD82660AaE99bEdc034a0deA8A0bd517';

  // address _weth, address _usdc, address _reward, address _master, address _factory
  const dashboardArgs = [WEVMOS, USDC, emoToken.address, masterChef.address, evmoSwapFactory.address];

  const resultMaster = await deploy("Dashboard", {
    log: true,
    from: deployer,
    args: dashboardArgs,
  });

  if(resultMaster.newlyDeployed) {
    if (network.live) {
      await run("verify:verify", {
        address: resultMaster.address,
        constructorArguments: dashboardArgs,
      });
    }
  }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'mainnet';
};

func.tags = ["Dashboard"];
func.dependencies = ["EMOToken", "EvmoSwapFactory"]