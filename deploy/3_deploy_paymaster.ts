import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const deployMeerChangePaymaster: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const provider = ethers.provider;
  const from = await provider.getSigner().getAddress();
  const entrypoint = await hre.deployments.get("EntryPoint");
  const MeerChangeAddr = "0x422f6F90B35D91D7D4F03aC791c6C07b1c14af1f";

  // use create2factory to deploy
  const ret = await hre.deployments.deploy("QngPaymaster", {
    from,
    args: [entrypoint.address, MeerChangeAddr],
    gasLimit: 8e6,
    deterministicDeployment: process.env.SALT ?? true,
    log: true,
  });
  console.log("==MeerChangePaymaster addr=", ret.address);
};

export default deployMeerChangePaymaster;
