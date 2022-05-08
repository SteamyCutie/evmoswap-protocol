import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network, ethers}) => {
  console.log("> (014) Deploy TeamTokenVesting:");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const vestingArgs = [
    deployer, // beneficiary
    Date.UTC(2022, 4, 10, 0, 0, 0) / 1000, // start time
    90 * 24 * 3600,  // cliffDuration 90 days
    31536000 // duration 365 days
  ];
    
  const result = await deploy("TeamTokenVesting", {
    log: true,
    from: deployer,
    args: vestingArgs,
  });

  // Verify contract
  // if(result.newlyDeployed) {
  //   if (network.live) {
  //     await run("verify:verify", {
  //       address: result.address,
  //       constructorArguments: vestingArgs,
  //     });
  //   }
  // }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'mainnets';
};

func.tags = ["TeamTokenVesting"];