import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network}) => {
  console.log("> (001) Deploy TimeLock:");
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // args
  const timelockArgs = [
    deployer,
    24 * 60 * 60,
  ];

  // TimeLock
  const result = await deploy("TimeLock", {
    log: true,
    from: deployer,
    args: timelockArgs
  });

  // Verify contract
  if(result.newlyDeployed) {
    if (network.live) {
      await run("verify:verify", {
        address: result.address,
        constructorArguments: timelockArgs,
      });
    }
  }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'mainnets';
};

func.tags = ["TimeLock"];