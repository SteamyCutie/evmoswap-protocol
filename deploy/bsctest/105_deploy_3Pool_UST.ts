import {run} from "hardhat";
import {DeployFunction} from "hardhat-deploy/types";

const func: DeployFunction = async ({getNamedAccounts, deployments, network, ethers}) => {
    console.log("> (105) Deploy 3Pool_UST:");

    const {deploy} = deployments;
    const {deployer} = await getNamedAccounts();

    const mathUtils = await ethers.getContract("MathUtils");
    const swapUtils = await ethers.getContract("EvmoSwapUtils");
    const lPToken = await ethers.getContract("LPToken");
    const swap = await ethers.getContract("EvmoSwap");

    // MetaSwapUtils
    const metaSwapUtils = await deploy("MetaSwapUtils", {
        log: true,
        from: deployer,
        libraries: {
            MathUtils: mathUtils.address,
            EvmoSwapUtils: swapUtils.address
        }
    });

    // Verify contract
    if (metaSwapUtils.newlyDeployed) {
        if (network.live) {
            await run("verify:verify", {
                address: metaSwapUtils.address
            });
        }
    }

    // MetaLPToken
    const metaLpArgs = ["3EVM-UST", "3EVM-UST-LP", 18]; // name/symbol/decimal
    const metaLPToken = await deploy("MetaLPToken", {
        log: true,
        from: deployer,
        contract: "LPToken",
        args: metaLpArgs
    });

    // Verify contract
    if (metaLPToken.newlyDeployed) {
        if (network.live) {
            await run("verify:verify", {
                address: metaLPToken.address,
                constructorArguments: metaLpArgs,
            });
        }
    }

    // todo update stablecoins && a && fee
    const metaSwapArgs = [
        ["0xA1f171347C02A688327Aa2fa4141a1c8BE8fc789", lPToken.address], // address of stablecoins, ust/3evm
        [18, 18], // decimal of stablecoins, ust/3evm
        "3EVM-UST",
        "3EVM-UST-LP",
        100,
        4000000,
        5000000000,
        0,
        0,
        deployer,
        swap.address
    ]
    const metaSwap = await deploy("MetaSwap", {
        log: true,
        from: deployer,
        libraries: {
            MetaSwapUtils: metaSwapUtils.address,
            EvmoSwapUtils: swapUtils.address
        },
        args: metaSwapArgs
    });

    // Verify contract
    if (metaSwap.newlyDeployed) {
        if (network.live) {
            await run("verify:verify", {
                address: metaSwap.address,
                constructorArguments: metaSwapArgs,
            });
        }
    }

    // MetaSwapDeposit
    const metaSwapDepositArgs = [swap.address, metaSwap.address, metaLPToken.address]; // name/symbol/decimal
    const metaSwapDeposit = await deploy("MetaSwapDeposit", {
        log: true,
        from: deployer,
        args: metaSwapDepositArgs
    });

    // Verify contract
    if (metaSwapDeposit.newlyDeployed) {
        if (network.live) {
            await run("verify:verify", {
                address: metaSwapDeposit.address,
                constructorArguments: metaSwapDepositArgs,
            });
        }
    }
}

export default func;

func.skip = async (hre) => {
    return hre.network.name != 'bsctests';
};

func.tags = ["3POOL-UST"];
func.dependencies = ["3POOL"]