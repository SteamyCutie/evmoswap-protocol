import {ethers} from "hardhat";
import { parseUnits } from "ethers/lib/utils";

async function main() {

    const emosToken = await ethers.getContract("EMOToken");
    const masterChef = await ethers.getContract("MasterChef");
    const multiFeeDistribution = await ethers.getContract("MultiFeeDistribution");

    // await emosToken.addMinter(process.env.TESTNET_DEPLOYER);
    // console.log('Set minter done!')

    // set minter
    // await emosToken.addMinter(multiFeeDistribution.address);

    // add Masterchef as minter of EmosToken
    // console.log("Add Masterchef as minter of EmosToken, masterChef=", masterChef.address);
    // await emosToken.addMinter(masterChef.address);

    // init mint tokens
    // await emosToken.mint(process.env.TESTNET_DEPLOYER, parseUnits("50000000", 18));
    // console.log('Mint token done!')
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

