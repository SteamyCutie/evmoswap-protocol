import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network, ethers}) => {
  console.log("> (002) Deploy EvmoSwapRouter:");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // init code: 0x1a74734eea11bc0ee7528f77a3306d46a0e9015d2eca65dd5651259a4b2eefe1
  const WEVMOS = await ethers.getContract("WEVMOS");
  const evmoSwapV2Factory = await deployments.get("EvmoSwapFactory");

  // EvmosSwapRouter
  const result = await deploy("EvmoSwapRouter", {
    log: true,
    from: deployer,
    args: [evmoSwapV2Factory.address, WEVMOS.address],
  });

  // Verify contract
  if(result.newlyDeployed) {
    if (network.live) {
      await run("verify:verify", {
        address: result.address,
        constructorArguments: [evmoSwapV2Factory.address, WEVMOS.address],
      });
    }
  }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'bsctests';
};

func.tags = ["EvmoSwapRouter"];
func.dependencies = ["EvmoSwapFactory"]