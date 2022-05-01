import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network, ethers}) => {
  console.log("> (102) Deploy MultiFeeDistribution:");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const emoToken = await ethers.getContract("EMOToken");
  const feeDistributor = await ethers.getContract("FeeDistributor");

  // Deploy Args
  const deployArgs = [
    emoToken.address,
    feeDistributor.address,
  ]; 

  const deployResult = await deploy("MultiFeeDistribution", {
    log: true,
    from: deployer,
    args: deployArgs,
  });


  if(deployResult.newlyDeployed) {
    if (network.live) {
      await run("verify:verify", {
        address: deployResult.address,
        constructorArguments: deployArgs,
      });
    }
  }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'bsctest';
};

func.tags = ["MultiFeeDistribution"];
func.dependencies = ["FeeDistributor", "EMOToken"]