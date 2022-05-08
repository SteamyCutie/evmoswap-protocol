import { run } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async({getNamedAccounts, deployments, network}) => {
  console.log("> (016) Deploy VCTokenVesting:");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const teamVestPools = {
    "VC-JACK": "0x1980Be49E30585D6ba946a9790F93b36Adb1A277", // 2,000,000
    "VC-MIKE": "0x5E6b3F619a41A3165F81e72623d050c07b62b9eE", // FROM #5 - 2,000.000
    "VC-HEX": "0xbD126b1dC4314e4153856C486f6A1E3ca5302b56", //  FROM #6 - 2,000,000
    "VC-ANT": "0x87888CDC0C2a34148f17B6cc1d100706D9792CcB", // 1,000,000 EMO
    "VC-ZF": "0x508e7934863B50506442bb7942B28a2928Ae5C11", // 1,000,000 EMO
  };

  const startTime = Date.UTC(2022, 4, 10, 0, 0, 0) / 1000; 
  const cliffDuration = 30 * 86400;  // cliffDuration 30 days
  const duration = 31536000; // 365 days
  for (const [tokenName, beneficiary] of Object.entries(teamVestPools)) {
    const args = [
      beneficiary,
      startTime,
      cliffDuration,
      duration,
      true
    ];

    console.log({args})
    // address beneficiary, uint256 start, uint256 cliffDuration, uint256 duration, bool revocable
    await deploy(`${tokenName}TokenVesting`, {
      from: deployer,
      contract: "VCTokenVesting",
      args: args,
      log: true,
    });
  }
}

export default func;

func.skip = async (hre) => {
  return hre.network.name != 'mainnets';
};

func.tags = ["VCTokenVesting"];