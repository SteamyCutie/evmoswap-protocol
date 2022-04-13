import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network, ethers}) => {
  console.log("> (101) Deploy FeeDistributor:");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // EMO-BNB lp
  const emoToken = await ethers.getContract("EMOToken");
  const votingEscrow = await ethers.getContract("VotingEscrow");

  // Deploy Args
  const deployArgs = [
    votingEscrow.address, 
    Date.UTC(2022, 3, 25, 15, 0, 0) / 1000, // year: 2000, month: 0, date: 1, hour: 12, minute: 34, second: 5
    emoToken.address, 
    deployer, 
  ]; 

  const deployResult = await deploy("FeeDistributor", {
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
  return hre.network.name != 'bsctests';
};

func.tags = ["FeeDistributor"];
func.dependencies = ["VotingEscrow"]