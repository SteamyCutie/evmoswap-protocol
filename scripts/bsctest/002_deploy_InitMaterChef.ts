import {ethers} from "hardhat";

async function main() {

    const masterChef = await ethers.getContract("MasterChef");
    const rewardPool = await ethers.getContract("RewardPool");
    const votingEscrow = await ethers.getContract("VotingEscrow");
    const multiFeeDistribution = await ethers.getContract("MultiFeeDistribution");

    // 1 set startTime
    // const startTime = Date.UTC(2022, 3, 20, 0, 0, 0) / 1000;
    // await masterChef.setStartTime(startTime);
    // console.log('setStartTime done!', startTime)

    // 2 set pool0Staker
    // const pool0Staker = [
    //     rewardPool.address
    // ]
    // await masterChef.setPool0Staker(pool0Staker, true);
    // console.log('pool0Staker done!')

    // 3 set masterChef
    // await votingEscrow.setMasterchef(masterChef.address);
    // console.log('setMasterchef done!', masterChef.address)

    // 4 Add Masterchef as minter of MultiFeeDistribution
    // await multiFeeDistribution.setMinters([masterChef.address]);
    // console.log("Add Masterchef as minter of MultiFeeDistribution, masterChef=", masterChef.address);

    ///////////////////////////////////////////////////////////////////////////////////
    // 02 add pool uint256 _allocPoint, IERC20 _lpToken, IOnwardIncentivesController _incentivesController, bool _boost, bool _withUpdate
    // await masterChef.add(
    //     3000,
    //     0, // _depositFeePercent
    //     '0x33919a080caD90B8E3d7dB7f9f8CAF3C451C1fE2', //bnb-emo
    //     '0x0000000000000000000000000000000000000000', //rewards
    //     true,
    //     true
    // );

    // await masterChef.add(
    //     2000,
    //     0, // _depositFeePercent
    //     '0xF6210A01E8F271862871a80Dbf3fdCD720F8Ef3C', //usdc-emo
    //     '0x0000000000000000000000000000000000000000', //rewards
    //     true,
    //     true
    // );

    // await masterChef.add(
    //     1000,
    //     0, // _depositFeePercent
    //     '0x1658E34386Cc5Ec3B703a34567790d95F1C94cCb', //usdc-usdt
    //     '0x0000000000000000000000000000000000000000', //rewards
    //     true,
    //     true
    // );

    // await masterChef.add(
    //     1000,
    //     0, // _depositFeePercent
    //     '0x87ce4e5bBCE1Ee646Fa28B61CbC7EFac4722680e', //usdc-bnb
    //     '0x0000000000000000000000000000000000000000', //rewards
    //     true,
    //     true
    // );

    console.log('Add pool done!')
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

