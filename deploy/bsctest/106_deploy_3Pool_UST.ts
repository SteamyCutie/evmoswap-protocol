import {run} from "hardhat";
import {DeployFunction} from "hardhat-deploy/types";

const func: DeployFunction = async ({getNamedAccounts, deployments, network, ethers}) => {
    console.log("> (106) Deploy 3Pool_UST:");

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
    const metaLpArgs = ["3EMO-UST", "3EMO-UST-LP", 18]; // name/symbol/decimal
    const metaLPToken = await deploy("MetaLPToken-UST", {
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
    // 0xf8e00573a7e669e42F4bF022497bAfca527c403F - UST
    const metaSwapArgs = [
        ["0xf8e00573a7e669e42F4bF022497bAfca527c403F", lPToken.address], // address of stablecoins, ust/3EMO
        [18, 18], // decimal of stablecoins, ust/3EMO
        "3EMO-UST",
        "3EMO-UST-LP",
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