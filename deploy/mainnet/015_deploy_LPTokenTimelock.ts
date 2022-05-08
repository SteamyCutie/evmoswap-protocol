import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network}) => {
  console.log("> (014) Deploy LPTokenTimelock:");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const vestingArgs = [
    "0xeD75347fFBe08d5cce4858C70Df4dB4Bbe8532a0", // _token LP
    deployer, // _beneficiary
    Date.UTC(2022, 10, 12, 9, 0, 0) / 1000, // _releaseTime after 365 days
  ];
    
  console.log({vestingArgs})

  // LPTokenTimelock
  const result = await deploy("LPTokenTimelock", {
    log: true,
    from: deployer,
    args: vestingArgs,
  });

  // // Verify contract
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

func.tags = ["LPTokenTimelock"];