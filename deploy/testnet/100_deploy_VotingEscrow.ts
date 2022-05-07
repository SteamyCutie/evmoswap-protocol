import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network, ethers}) => {
  console.log("> (100) Deploy VotingEscrow:");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const emosToken = await ethers.getContract("EMOToken");

  // Deploy Args
  const deployArgs = [
    emosToken.address, 
    'Vote Escrowed EMO', 
    'veEMO', 
    'veEMO_1.0.0', 
  ]; 

  const deployResult = await deploy("VotingEscrow", {
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
  return hre.network.name != 'testnet';
};

func.tags = ["VotingEscrow"];