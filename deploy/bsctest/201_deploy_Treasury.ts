import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
const { getDeploymentAddresses } = require("../utils/readStatic")

const func: DeployFunction = async({getNamedAccounts, deployments, network}) => {
  console.log("> (201) Deploy Treasury:");
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const emoAddr = getDeploymentAddresses(network)["EmoToken"]
  const gemoAddr = getDeploymentAddresses(network)["GemEMO"]

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
        constructorArgs: [],
        contract: "contracts/gemo/Treasury.sol:Treasury"
      });
    }
  }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'bsctests';
};

func.tags = ["Treasury"];