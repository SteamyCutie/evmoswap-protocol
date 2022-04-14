import { ethers } from "hardhat";
import { parseUnits } from "ethers/lib/utils";

async function main() {

    const IFODeployer = await ethers.getContract("IFODeployer");

    // MIFO 0xf2C856AB8Ed6f67Fd7D45Fd017c811347bF01a28

    // 0. args
    const offeringToken = "0xf2C856AB8Ed6f67Fd7D45Fd017c811347bF01a28"; // MIFO
    const startTime = Date.UTC(2022, 3, 6, 11, 45, 0) / 1000; // year: 2000, month: 0, date: 1, hour: 12, minute: 34, second: 5
    const endTime = Date.UTC(2022, 3, 7, 12, 0, 0) / 1000; // year: 2000, month: 0, date: 1, hour: 12, minute: 34, second: 5
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
    console.log("IFO set 0 Pool start >>>");
    await evmoSwapIFO.setPool(
        '0x50FbdED2063577995389fd5fa0eB349cCbc7cA67', // raisingToken - EMO
        parseUnits("1350000", 18), // offeringAmountPool
        parseUnits("2025000", 18), // raisingAmountPool (EMO amounts by price calc)
        0, // limitPerUserInRaisingToken
        2500, // initialReleasePercentage - 25%
        0, // burnPercentage
        endTime + (1*3600), //vestingEndTime in 90days, 
        false, 
        0
    )
    console.log("IFO set 0 Pool done <<<");

    // // set 0 pool - base sale
    console.log("IFO set 1 Pool start >>>");
    await evmoSwapIFO.setPool(
        '0x63cE1066c7cA0a028Db94031794bFfe40ceE8b0A', // raisingToken - USDC
        parseUnits("2650000", 18), // offeringAmountPool
        parseUnits("397500", 6), // raisingAmountPool
        0, // limitPerUserInRaisingToken
        2500, // initialReleasePercentage - 25%
        0, // burnPercentage
        endTime + (1*3600), //vestingEndTime in 90days, 
        true, 
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
