import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { expect } from "chai";

const deployMeerChangePaymaster: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const provider = ethers.provider;
  const from = await provider.getSigner().getAddress();
  const entrypoint = await hre.deployments.get("EntryPoint");
  const MeerChangeAddr = "0x7D698C4E800dBc1E9B7e915BefeDdB59Aa9E8BB6";

  // use create2factory to deploy
  const ret = await hre.deployments.deploy("QngPaymaster", {
    from,
    args: [entrypoint.address, MeerChangeAddr],
    gasLimit: 8e6,
    deterministicDeployment: process.env.SALT ?? true,
    log: true,
  });
  console.log("==MeerChangePaymaster addr=", ret.address);
  expect(ret.address).to.eql("0xa9E0107cE8340D7E025885be51ce53F467dCebC1");
};

export default deployMeerChangePaymaster;
