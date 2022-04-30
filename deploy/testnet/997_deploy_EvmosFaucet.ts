import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network}) => {
  console.log("> (997) Deploy EvmosFaucet:");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const deployArgs = [
    '0x7c4a1D38A755a7Ce5521260e874C009ad9e4Bf9c', // _dai
    '0xae95d4890bf4471501E0066b6c6244E1CAaEe791', // _usdc
    '0x397F8aBd481B7c00883fb70da2ea5Ae70999c37c', // _usdt
  ]; 

  const deployResult = await deploy("EvmosFaucet", {
    log: true,
    from: deployer,
    args: deployArgs,
  });

  if(deployResult.newlyDeployed) {
    if (network.live) {
      await run("verify:verify", {
        address: deployResult.address,
        constructorArguments: deployArgs
      });
    }
  }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'testnets';
};

func.tags = ["EvmosFaucet"];