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
    const lpArgs = ["3EVM", "3EVM-LP", 18]; // name/symbol/decimal
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
        ["0x32B576820de1AD3a14D159aF329fb429dC8f5507", "0xcBF05655E88E0C63321CCBDa971AcE9f35ABF027", "0x3C1188Bf4723D68546c0FedF7Bb27DF99829a789"], // address of stablecoins, dai/usdc/usdt
        [18, 6, 6], // decimal of stablecoins, dai/usdc/usdt
        "3EVM",
        "3EVM-LP",
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