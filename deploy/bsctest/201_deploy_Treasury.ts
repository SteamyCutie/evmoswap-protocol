import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import getDeploymentAddresses from "../../utils/readStatic"

const func: DeployFunction = async({getNamedAccounts, deployments, network}) => {
  console.log("> (201) Deploy Treasury:");
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const emoAddr = getDeploymentAddresses(network.name)["EMOToken"]
  const gemoAddr = getDeploymentAddresses(network.name)["GemEMO"]

  // GEMOToken
  const result = await deploy("Treasury", {
    log: true,
    from: deployer,
    args: [emoAddr, gemoAddr] 
  });

  // Verify contract
  if(result.newlyDeployed) {
    if (network.live) {
      await run("verify:verify", {
        address: result.address,
        constructorArguments: [emoAddr, gemoAddr],
        contract: "contracts/gemo/Treasury.sol:Treasury"
      });
    }
  }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'bsctest';
};

func.tags = ["Treasury"];