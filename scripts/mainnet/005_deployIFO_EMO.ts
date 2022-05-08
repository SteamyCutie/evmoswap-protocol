import { ethers } from "hardhat";
import { parseUnits } from "ethers/lib/utils";

async function main() {

    const emoToken = await ethers.getContract("EMOToken");
    const IFODeployer = await ethers.getContract("IFODeployer");

    // 0. args
    const offeringToken = emoToken.address; // EMO
    const startTime = Date.UTC(2022, 4, 8, 15, 0, 0) / 1000; // year: 2000, month: 0, date: 1, hour: 12, minute: 34, second: 5
    const endTime = Date.UTC(2022, 4, 10, 15, 0, 0) / 1000; // year: 2000, month: 0, date: 1, hour: 12, minute: 34, second: 5
    const adminAddress = process.env.MAINNET_DEPLOYER;
    // const votingEscrow = await ethers.getContract("VotingEscrow");
    const votingEscrow = '0x0000000000000000000000000000000000000000'; // don't use veEmo
    const burnAddress = process.env.MAINNET_DEPLOYER;
    const receiverAddress = process.env.MAINNET_DEPLOYER; //  project funds receiverAddress

    // 1. Deploy IFO
    console.log("IFODeployer deployIFO starting >>>", [offeringToken, startTime, endTime, adminAddress, votingEscrow, burnAddress, receiverAddress])
    // await IFODeployer.deployIFO(offeringToken, startTime, endTime, adminAddress, votingEscrow, burnAddress, receiverAddress);
    console.log("IFODeployer deployIFO done <<<")

    // 2. Get IFOV2 Address 
    const salt = ethers.utils.solidityKeccak256(["address", "uint256", "uint256"], [offeringToken, startTime, endTime]);
    console.log("salt: ", salt);

    const ifov2 = await ethers.getContractFactory("IFOInitializable");
    const ifov2Address = ethers.utils.getCreate2Address(IFODeployer.address, salt, ethers.utils.keccak256(ifov2.bytecode));
    console.log("IFO address: ", ifov2Address)
    
    // 3. Set IFO parameters
    const evmoSwapIFO = await ethers.getContractAt("IEvmoSwapIFO", ifov2Address);

    // set 0 pool - base sale
    // console.log("IFO set 0 Pool start >>>");
    // await evmoSwapIFO.setPool(
    //     '0xD4949664cD82660AaE99bEdc034a0deA8A0bd517', // raisingToken - WEVMOS
    //     parseUnits("1", 18), // offeringAmountPool
    //     parseUnits("1", 18), // raisingAmountPool
    //     0, // limitPerUserInRaisingToken
    //     2000, // initialReleasePercentage - 20%
    //     0, // burnPercentage
    //     endTime + (90*24*3600), //vestingEndTime in 90days, 
    //     false, 
    //     0
    // )
    // console.log("IFO set 0 Pool done <<<");

    // set 0 pool - base sale
    // console.log("IFO set 1 Pool start >>>");
    // await evmoSwapIFO.setPool(
    //     '0x51e44FfaD5C2B122C8b635671FCC8139dc636E82', // raisingToken - USDC
    //     parseUnits("8000000", 18), // offeringAmountPool
    //     parseUnits("720000", 6), // raisingAmountPool
    //     0, // limitPerUserInRaisingToken
    //     2000, // initialReleasePercentage - 20%
    //     0, // burnPercentage
    //     endTime + (90*24*3600), //vestingEndTime in 90days, 
    //     false, 
    //     1
    // )
    // console.log("IFO set 1 Pool done <<<");

    // ===========================================================================
    // console.log("IFO finalWithdraw start >>>");
    // await evmoSwapIFO.finalWithdraw([parseUnits("2024999", 18), parseUnits("397500", 6)], 0)
    // console.log("IFO finalWithdraw done <<<");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
