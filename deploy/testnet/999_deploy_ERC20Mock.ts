import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { parseUnits } from "ethers/lib/utils";

const func: DeployFunction = async({getNamedAccounts, deployments, network}) => {
  console.log("> (999) Deploy ERC20Mock:");
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // Multicall
  const resultMulti = await deploy("ERC20Mock", {
    log: true,
    from: deployer,
    args: ['LaunchPad Mock', 'MPAD', parseUnits("50000000", 18)],
  });

  // Verify contract
  if(resultMulti.newlyDeployed) {
    if (network.live) {
      await run("verify:verify", {
        address: resultMulti.address
      });
    }
  }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'testnets';
};

func.tags = ["ERC20Mock"];