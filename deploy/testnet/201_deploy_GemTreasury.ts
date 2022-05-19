import { run, ethers } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async ({ getNamedAccounts, deployments, network }) => {
  console.log("> (201) Deploy GemTreasury:");
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const emoToken = await ethers.getContract("EMOToken");
  const gemoToken = await ethers.getContract("GemEMO");


  // GEMOToken
  const result = await deploy("GemTreasury", {
    log: true,
    from: deployer,
    args: [emoToken.address, gemoToken.address]
  });

  // Verify & Initial Setting contract
  if (result.newlyDeployed) {
    if (network.live) {
      await gemoToken.excludeAccount(result.address)

      await run("verify:verify", {
        address: result.address,
        constructorArguments: [emoToken.address, gemoToken.address],
      });
    }
  }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'testnets';
};

func.tags = ["GemTreasury"];