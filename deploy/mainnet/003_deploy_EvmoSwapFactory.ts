import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network}) => {
  console.log("> (003) Deploy EvmoSwapFactory:");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // EvmosSwapFactory
  const result = await deploy("EvmoSwapFactory", {
    log: true,
    from: deployer,
    args: [deployer],
  });
  
  // Verify contract
  if(result.newlyDeployed) {
    if (network.live) {
      await run("verify:verify", {
        address: result.address,
        constructorArguments: [deployer],
      });
    }
  }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'mainnets';
};

func.tags = ["EvmoSwapFactory"];