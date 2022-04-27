import { ethers } from "hardhat";
import { parseUnits } from "ethers/lib/utils";

async function main() {

    const emoToken = await ethers.getContract("EMOToken");
    const stakingPoolFactory = await ethers.getContract("StakingPoolFactory");

    // StakingPoolFactory
    const stakedToken = emoToken.address;
    const rewardToken = "0x9b5bb7F5BE680843Bcd3B54D4E5C6eE889c124Df"; //USDC Tokens.
    const rewardPerBlock =  parseUnits("0.17", 6) ;
    const startBlock = 18757548;
    const bonusEndBlock = 28757548 ;
    const poolLimitPerUser = 0;
    const admin = process.env.TESTNET_DEPLOYER;
    
    console.log("StakingPoolFactory deployPool starting >>>")
    // await stakingPoolFactory.deployPool(stakedToken, rewardToken, rewardPerBlock, startBlock, bonusEndBlock, poolLimitPerUser, admin);
    console.log("StakingPoolFactory deployPool done!")

    // 2. Get the chef address
    const salt = ethers.utils.solidityKeccak256(["address", "address", "uint256"], [stakedToken, rewardToken, startBlock]);
    const chef = await ethers.getContractFactory("StakingPoolInitializable");
    const chefAddress = ethers.utils.getCreate2Address(stakingPoolFactory.address, salt, ethers.utils.keccak256(chef.bytecode));
    console.log("StakingPool address: ", chefAddress)
    
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
