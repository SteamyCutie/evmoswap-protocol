import { ethers } from "hardhat";

async function main() {

    const whitelist = [
        '0xB82fA569843fA783D7a060498a647DE9F548560A',
    ]

    const tokenPrivateSale = await ethers.getContract("EMOPrivateSale");

    // 1 set whitelist
    await tokenPrivateSale.adminSetWhitelisted(whitelist, true);
    console.log("Set EMOPrivateSale whitelists done!");

    // 2 set verstart time
    // const vestingStartTime = Date.UTC(2021, 10, 6, 6, 0, 0) / 1000;
    // await tokenPrivateSale.adminSetVestingStart(vestingStartTime);
    // console.log("Set EMOPrivateSale vestingStart done!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });