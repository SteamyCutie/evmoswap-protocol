import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network}) => {
  console.log("> (001) Deploy EMOToken:");
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // EMOToken
  const result = await deploy("EMOToken", {
    log: true,
    from: deployer,
  });

  // Verify contract
  if(result.newlyDeployed) {
    if (network.live) {
      await run("verify:verify", {
        address: result.address
      });
    }
  }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'bsctests';
};

func.tags = ["EMOToken"];