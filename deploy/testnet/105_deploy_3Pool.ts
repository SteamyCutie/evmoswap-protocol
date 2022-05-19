import {run} from "hardhat";
import {DeployFunction} from "hardhat-deploy/types";

const func: DeployFunction = async ({getNamedAccounts, deployments, network}) => {
    console.log("> (105) Deploy 3Pool:");
    const {deploy} = deployments;
    const {deployer} = await getNamedAccounts();

    // MathUtils
    const mathUtils = await deploy("MathUtils", {
        log: true,
        from: deployer,
    });

    // Verify contract
    if (mathUtils.newlyDeployed) {
        if (network.live) {
            await run("verify:verify", {
                address: mathUtils.address
            });
        }
    }

    // SwapUtils
    const swapUtils = await deploy("EvmoSwapUtils", {
        log: true,
        from: deployer,
        libraries: {
            MathUtils: mathUtils.address
        }
    });

    // Verify contract
    if (swapUtils.newlyDeployed) {
        if (network.live) {
            await run("verify:verify", {
                address: swapUtils.address
            });
        }
    }

    // LPToken
    const lpArgs = ["3EMO", "3EMO-LP", 18]; // name/symbol/decimal
    const lPToken = await deploy("LPToken", {
        log: true,
        from: deployer,
        args: lpArgs
    });

    // Verify contract
    if (lPToken.newlyDeployed) {
        if (network.live) {
            await run("verify:verify", {
                address: lPToken.address,
                constructorArguments: lpArgs,
            });
        }
    }

    // todo update stablecoins
    const swapArgs = [
        [
            "0x7c4a1D38A755a7Ce5521260e874C009ad9e4Bf9c", 
            "0xae95d4890bf4471501E0066b6c6244E1CAaEe791", 
            "0x397F8aBd481B7c00883fb70da2ea5Ae70999c37c"
        ], // address of stablecoins, dai/usdc/usdt
        [18, 6, 6], // decimal of stablecoins, dai/usdc/usdt
        "3EMO",
        "3EMO-LP",
        800,
        1e6,
        5000000000,
        0,
        0,
        deployer
    ]
    const swap = await deploy("EvmoSwap", {
        log: true,
        from: deployer,
        libraries: {
            EvmoSwapUtils: swapUtils.address
        },
        args: swapArgs
    });

    // Verify contract
    if (swap.newlyDeployed) {
        if (network.live) {
            await run("verify:verify", {
                address: swap.address,
                constructorArguments: swapArgs,
            });
        }
    }
}

export default func;

func.skip = async (hre) => {
    return hre.network.name != 'testnet';
};

func.tags = ["3POOL"];