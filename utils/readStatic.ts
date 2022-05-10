const path = require("path")
const fs = require("fs")

const getDeploymentAddresses = (networkName: any) => {
    const PROJECT_ROOT = path.resolve(__dirname, "..")
    const DEPLOYMENT_PATH = path.resolve(PROJECT_ROOT, "build/deployments")

    let folderName = networkName
    if (networkName === "hardhat") {
        folderName = "localhost"
    }

    const networkFolderName = fs.readdirSync(DEPLOYMENT_PATH).filter((f:any) => f === folderName)[0]
    if (networkFolderName === undefined) {
        throw new Error("Missing deployment files for endpoint " + folderName)
    }

    let rtnAddresses:any = {}
    const networkFolderPath = path.resolve(DEPLOYMENT_PATH, folderName)
    const files = fs.readdirSync(networkFolderPath).filter((f:any) => f.includes(".json"))
    files.forEach((file:any) => {
        const filepath = path.resolve(networkFolderPath, file)
        const data = JSON.parse(fs.readFileSync(filepath))
        const contractName = file.split(".")[0]
        rtnAddresses[contractName] = data.address
    })

    return rtnAddresses
}

module.exports = {
    getDeploymentAddresses
}