import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network, ethers}) => {
  console.log("> (104) Deploy RewardPool:");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const emoToken = await ethers.getContract("EMOToken");
  const masterChef = await ethers.getContract("MasterChef");
  const votingEscrow = await ethers.getContract("VotingEscrow");

  // Deploy Args
  const deployArgs = [
    emoToken.address, 
    emoToken.address, 
    masterChef.address, 
    votingEscrow.address, 
  ]; 

  const deployResult = await deploy("RewardPool", {
    log: true,
    from: deployer,
    args: deployArgs,
  });

  if(deployResult.newlyDeployed) {
    // set reward pool for votingEscrow
    console.log("Set RewardPool Starting, votingEscrow=", deployResult.address);
    await votingEscrow.setRewardPool(deployResult.address);
    console.log("Set RewardPool Done, votingEscrow=", deployResult.address);

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
  return hre.network.name != 'mainnets';
};

func.tags = ["RewardPool"];
func.dependencies = ["VotingEscrow"]