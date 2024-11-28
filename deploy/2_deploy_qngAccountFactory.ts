import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { expect } from "chai";

const deployQngAccountFactory: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const provider = ethers.provider;
  const from = await provider.getSigner().getAddress();
  const network = await provider.getNetwork();
  // only deploy on qng testnet and privnet network.
  if (network.chainId !== 8131 && network.chainId !== 813) {
    return;
  }

  const MeerChangeAddr = "0x7D698C4E800dBc1E9B7e915BefeDdB59Aa9E8BB6";
  const entrypoint = await hre.deployments.get("EntryPoint");
  const ret = await hre.deployments.deploy("QngAccountFactory", {
    from,
    args: [entrypoint.address, MeerChangeAddr],
    gasLimit: 6e6,
    log: true,
    deterministicDeployment: true,
  });
  console.log("==QngAccountFactory addr=", ret.address);

  expect(ret.address).to.eql("0xb979a65B7168FC48284D9afF1A079436761A21EB");
};

export default deployQngAccountFactory;
