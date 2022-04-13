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
    //     '0x33919a080caD90B8E3d7dB7f9f8CAF3C451C1fE2', //bnb-emo
    //     '0x0000000000000000000000000000000000000000', //rewards
    //     true,
    //     true
    // );

    // await masterChef.add(
    //     2000,
    //     '0xF6210A01E8F271862871a80Dbf3fdCD720F8Ef3C', //usdc-emo
    //     '0x0000000000000000000000000000000000000000', //rewards
    //     true,
    //     true
    // );

    // await masterChef.add(
    //     1000,
    //     '0x1658E34386Cc5Ec3B703a34567790d95F1C94cCb', //usdc-usdt
    //     '0x0000000000000000000000000000000000000000', //rewards
    //     true,
    //     true
    // );

    // await masterChef.add(
    //     1000,
    //     '0x87ce4e5bBCE1Ee646Fa28B61CbC7EFac4722680e', //usdc-bnb
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

