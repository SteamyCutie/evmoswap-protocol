import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network, ethers}) => {
  console.log("> (999) Deploy Dashboard:");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  if (network.name === process.env.DEPLOY_NETWORK) {
    return;
  }

  const emoToken = await ethers.getContract("EMOToken"); // testnet
  const masterChef = await ethers.getContract("MasterChef"); // testnet
  const evmoSwapFactory = await ethers.getContract("EvmoSwapFactory");


  const WEVMOS = await ethers.getContract("WEVMOS");
  const USDC = "0x36dD1fb6DA561AddCaa66b909eF571b92Dffc594";

  // address _weth, address _usdc, address _reward, address _master, address _factory
  const dashboardArgs = [WEVMOS.address, USDC, emoToken.address, masterChef.address, evmoSwapFactory.address];

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
  return hre.network.name != 'testnet';
};

func.tags = ["Dashboard"];
func.dependencies = ["EMOToken", "EvmoSwapFactory"]