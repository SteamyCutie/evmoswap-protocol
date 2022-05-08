import { ethers } from "hardhat";
import { parseUnits } from "ethers/lib/utils";

async function main() {

    const IFODeployer = await ethers.getContract("IFODeployer");

    // 0. args
    const offeringToken = "0x3094A01FC000a38c1996fE6c17E92AADa0e585A5"; // MPAD
    const startTime = Date.UTC(2022, 4, 6, 8, 0, 0) / 1000; // year: 2000, month: 0, date: 1, hour: 12, minute: 34, second: 5
    const endTime = Date.UTC(2022, 4, 7, 3, 0, 0) / 1000; // year: 2000, month: 0, date: 1, hour: 12, minute: 34, second: 5
    const adminAddress = process.env.TESTNET_DEPLOYER;
    // const votingEscrow = await ethers.getContract("VotingEscrow");
    const votingEscrow = '0x0000000000000000000000000000000000000000'; // don't use veEmo
    const burnAddress = process.env.TESTNET_DEPLOYER;
    const receiverAddress = process.env.TESTNET_DEPLOYER; //  project funds receiverAddress

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
    //     '0xab0D0540b724D7A1BCF64A651fc245BEDb11C091', // raisingToken - USDC
    //     parseUnits("1", 18), // offeringAmountPool
    //     parseUnits("1", 18), // raisingAmountPool
    //     0, // limitPerUserInRaisingToken
    //     2000, // initialReleasePercentage - 20%
    //     0, // burnPercentage
    //     endTime + (3*3600), //vestingEndTime in 90days, 
    //     false, 
    //     0
    // )
    // console.log("IFO set 0 Pool done <<<");

    // set 0 pool - base sale
    console.log("IFO set 1 Pool start >>>");
    await evmoSwapIFO.setPool(
        '0x9b5bb7F5BE680843Bcd3B54D4E5C6eE889c124Df', // raisingToken - USDC
        parseUnits("8000000", 18), // offeringAmountPool
        parseUnits("720000", 6), // raisingAmountPool
        0, // limitPerUserInRaisingToken
        2000, // initialReleasePercentage - 20%
        0, // burnPercentage
        endTime + (1*3600), //vestingEndTime in 90days, 
        false, 
        1
    )
    console.log("IFO set 1 Pool done <<<");

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
