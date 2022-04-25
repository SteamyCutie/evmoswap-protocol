import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network}) => {
  console.log("> (996) Deploy StakingPoolFactory:");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // StakingPoolFactory
  const result = await deploy("StakingPoolFactory", {
    log: true,
    from: deployer
  });
  
  // Verify contract
  if(result.newlyDeployed) {
    if (network.live) {
      await run("verify:verify", {
        address: result.address,
      });
    }
  }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'bsctest';
};

func.tags = ["StakingPoolFactory"];