import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const deployQngAccountFactory: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const provider = ethers.provider;
  const from = await provider.getSigner().getAddress();
  const network = await provider.getNetwork();
  // only deploy on qng testnet and privnet network.
  if (network.chainId !== 8131 && network.chainId !== 8133) {
    return;
  }

  const MeerChangeAddr = "0x09654c5D28b462BA219038e534e685f703B2EE5f";
  const entrypoint = await hre.deployments.get("EntryPoint");
  const ret = await hre.deployments.deploy("QngAccountFactory", {
    from,
    args: [entrypoint.address, MeerChangeAddr],
    gasLimit: 6e6,
    log: true,
    deterministicDeployment: true,
  });
  console.log("==QngAccountFactory addr=", ret.address);
};

export default deployQngAccountFactory;
