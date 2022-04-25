import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network}) => {
  console.log("> (997) Deploy EvmosFaucet:");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const deployArgs = [
    '0x6456d6f7B224283f8B22F03347B58D8B6d975677', // _dai
    '0x9b5bb7F5BE680843Bcd3B54D4E5C6eE889c124Df', // _usdc
    '0x648D3d969760FDabc71ea9d59c020AD899237b32', // _usdt
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
  return hre.network.name != 'bsctests';
};

func.tags = ["EvmosFaucet"];