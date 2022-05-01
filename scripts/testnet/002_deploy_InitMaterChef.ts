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

    ////////////////////////////////////////////////////////
    // 02 uint256 _allocPoint, uint256 _depositFeePercent, IERC20 _lpToken, IOnwardIncentivesController _incentivesController, bool _boost, bool _withUpdate
    // await masterChef.add(
    //     3000,
    //     0, // _depositFeePercent
    //     '0x9B28773f2B6c81Eb1818Ae4475C1A61cAaAD73EE', //evmos-emo
    //     '0x0000000000000000000000000000000000000000', //rewards
    //     true,
    //     true
    // );

    // await masterChef.add(
    //     2000,
    //     0, // _depositFeePercent
    //     '0x1B7E27cf4984D69745cB9C65030c0e123Ee57054', //usdc-emo
    //     '0x0000000000000000000000000000000000000000', //rewards
    //     true,
    //     true
    // );

    // await masterChef.add(
    //     1000,
    //     0, // _depositFeePercent
    //     '0x34ae15A977761BB07aCd7E09354802F26a5F7C1D', //usdc-usdt
    //     '0x0000000000000000000000000000000000000000', //rewards
    //     true,
    //     true
    // );

    // await masterChef.add(
    //     1000,
    //     0, // _depositFeePercent
    //     '0x6320CFBEBbE1f18160DA60eA06ACc87F82dBCf36', //usdc-evmos
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

