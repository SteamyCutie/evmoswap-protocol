import {ethers} from "hardhat";

async function main() {

    const masterChef = await ethers.getContract("MasterChef");
    const multiFeeDistribution = await ethers.getContract("MultiFeeDistribution");

    // 1 set startTime
    // const startTime = Date.UTC(2022, 2, 21, 3, 31, 0) / 1000;
    // await masterChef.setStartTime(startTime);
    // console.log('setStartTime done!', startTime)

    // 2 console.log("Add Masterchef as minter of MultiFeeDistribution, masterChef=", masterChef.address);
    // await multiFeeDistribution.setMinters([masterChef.address]);

    // 02 add pool uint256 _allocPoint, IERC20 _lpToken, IOnwardIncentivesController _incentivesController, bool _boost, bool _withUpdate
    // await masterChef.add(
    //     3000,
    //     '0x9B28773f2B6c81Eb1818Ae4475C1A61cAaAD73EE', //evmos-emo
    //     '0x0000000000000000000000000000000000000000', //rewards
    //     true,
    //     true
    // );

    await masterChef.add(
        2000,
        '0x1B7E27cf4984D69745cB9C65030c0e123Ee57054', //usdc-emo
        '0x0000000000000000000000000000000000000000', //rewards
        true,
        true
    );

    // await masterChef.add(
    //     1000,
    //     '0x34ae15A977761BB07aCd7E09354802F26a5F7C1D', //usdc-usdt
    //     '0x0000000000000000000000000000000000000000', //rewards
    //     true,
    //     true
    // );

    // await masterChef.add(
    //     1000,
    //     '0x6320CFBEBbE1f18160DA60eA06ACc87F82dBCf36', //usdc-evmos
    //     '0x0000000000000000000000000000000000000000', //rewards
    //     true,
    //     true
    // );

    // console.log('Add pool done!')
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

