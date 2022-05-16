import {ethers} from "hardhat";

async function main() {

    const masterChef = await ethers.getContract("MasterChef");
    const rewardPool = await ethers.getContract("RewardPool");
    const votingEscrow = await ethers.getContract("VotingEscrow");
    const multiFeeDistribution = await ethers.getContract("MultiFeeDistribution");

    // 1 set startTime
    const startTime = Date.UTC(2022, 4, 12, 15, 0, 0) / 1000;
    await masterChef.setStartTime(startTime);
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
    //     '0x33919a080caD90B8E3d7dB7f9f8CAF3C451C1fE2', //wevmos-emo
    //     '0x0000000000000000000000000000000000000000', //rewards
    //     true,
    //     true
    // );

    // await masterChef.add(
    //     2000,
    //     0, // _depositFeePercent
    //     '0x6946d31978E0249950e4Ae67E8A38Aa5d3D4de13', //wevmos-usdc
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

