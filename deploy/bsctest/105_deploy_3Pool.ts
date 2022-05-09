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
            "0x6456d6f7B224283f8B22F03347B58D8B6d975677", 
            "0x9b5bb7F5BE680843Bcd3B54D4E5C6eE889c124Df", 
            "0x648D3d969760FDabc71ea9d59c020AD899237b32"
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
    return hre.network.name != 'bsctests';
};

func.tags = ["3POOL"];