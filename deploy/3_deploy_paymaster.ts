import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const deployMeerChangePaymaster: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const provider = ethers.provider;
  const from = await provider.getSigner().getAddress();
  const entrypoint = await hre.deployments.get("EntryPoint");
  const MeerChangeAddr = "0x09654c5D28b462BA219038e534e685f703B2EE5f";

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
