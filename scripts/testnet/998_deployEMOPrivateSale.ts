import { ethers } from "hardhat";

async function main() {

    const whitelist = [
        '0xE871fF8D355A351C21c5C4423874b141DA23ee43',
        '0x0aA282136b3924ca6767C4D5B9aad6f83bD40A9c'
    ]

    const tokenPrivateSale = await ethers.getContract("EMOPrivateSale");

    // 1 set whitelist
    await tokenPrivateSale.adminSetWhitelisted(whitelist, true);
    console.log("Set EMOPrivateSale whitelists done!");

    // 2 set verstart time
    // const vestingStartTime = Date.UTC(2022, 4, 5, 0, 0, 0) / 1000;
    // await tokenPrivateSale.adminSetVestingStart(vestingStartTime);
    // console.log("Set EMOPrivateSale vestingStart done!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
