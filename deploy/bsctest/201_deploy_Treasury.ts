import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network}) => {
  console.log("> (201) Deploy Treasury:");
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // GEMOToken
  const result = await deploy("Treasury", {
    log: true,
    from: deployer,
    args:[] 
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

func.tags = ["Treasury"];