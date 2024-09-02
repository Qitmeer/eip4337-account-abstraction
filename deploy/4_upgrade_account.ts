import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const upgradeAccount: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // deployer is the owner of AA,EOA account
  // config with hardhat.config.ts
  const [deployer] = await ethers.getSigners();
  const ownerAddress = await deployer.getAddress();
  const SimpleAccountFactory = await ethers.getContractFactory(
    "SimpleAccountFactory"
  );
  const factory = await hre.deployments.get("SimpleAccountFactory");
  const SampleAccount = await ethers.getContractFactory("SimpleAccountV2");

  const factoryInstance = await SimpleAccountFactory.attach(factory.address);
  const salt = 0;
  // salt = 0
  let tx = await factoryInstance.createAccount(ownerAddress, salt);
  await tx.wait();
  const account = await factoryInstance.getAddress(ownerAddress, salt);
  console.log("AA acount:", account);
  // test
  // add  function version() method
  // use create2factory to deploy
  const newImplementationAddress = await hre.deployments.deploy(
    "SimpleAccountV2",
    {
      from: ownerAddress,
      args: [ownerAddress],
      gasLimit: 8e6,
      deterministicDeployment: process.env.SALT ?? true,
      log: true,
    }
  );
  console.log(
    "newImplementationAddress deployed to:",
    newImplementationAddress.address
  );

  const proxyAbi = ["function upgradeTo(address newImplementation) external"];
  //
  const proxyContract = new ethers.Contract(account, proxyAbi, deployer);
  //
  tx = await proxyContract.upgradeTo(newImplementationAddress.address);
  await tx.wait();
  console.log(
    "Proxy upgraded to new implementation at:",
    newImplementationAddress.address
  );
  const instance = await SampleAccount.attach(account);
  console.log("AA acount version:", await instance.version()); //V2
};

export default upgradeAccount;
