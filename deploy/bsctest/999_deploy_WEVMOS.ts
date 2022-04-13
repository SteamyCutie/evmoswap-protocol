import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network}) => {
  console.log("> (999) Deploy WEVMOS:");
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // Multicall
  const resultMulti = await deploy("WEVMOS", {
    log: true,
    from: deployer,
  });

  // Verify contract
  if(resultMulti.newlyDeployed) {
    if (network.live) {
      await run("verify:verify", {
        address: resultMulti.address
      });
    }
  }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'bsctests';
};

func.tags = ["WEVMOS"];