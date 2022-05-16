import { run } from "hardhat";
import { parseUnits } from "ethers/lib/utils";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network, ethers}) => {
  console.log("> (800) Deploy SimpleIncentivesController:");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // EMO-BNB lp
  const masterChef = await ethers.getContract("MasterChef");

  // Deploy Args
  const deployArgs = [
    '0x3094A01FC000a38c1996fE6c17E92AADa0e585A5', //_rewardToken - MPAD
    '0xF6210A01E8F271862871a80Dbf3fdCD720F8Ef3C', //_lpToken emo-_usdc
    parseUnits("0.25", 18), //_tokenPerSec
    masterChef.address, //_operator
    masterChef.address, //_originUser
    false, //_isNative
  ]; 

  const deployResult = await deploy("SimpleIncentivesController", {
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
  return hre.network.name != 'bsctest';
};

func.tags = ["SimpleIncentivesController"];
func.dependencies = ["MasterChef"]