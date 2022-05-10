import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network}) => {
  console.log("> (200) Deploy GEMOToken:");
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // GEMOToken
  const result = await deploy("GemEMO", {
    log: true,
    from: deployer,
  });

  // Verify contract
  if(result.newlyDeployed) {
    await run("verify:verify", {
      address: result.address,
      contract: "contracts/GemEMO.sol:GemEMO"
    });
  }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'bsctest';
};

func.tags = ["GemEMO"];