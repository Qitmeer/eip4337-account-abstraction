import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Create2Factory } from "../src/Create2Factory";
import { ethers } from "hardhat";
import { assert } from "console";
import { expect } from "chai";

const deployEntryPoint: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const provider = ethers.provider;
  const from = await provider.getSigner().getAddress();
  await new Create2Factory(ethers.provider).deployFactory();

  const ret = await hre.deployments.deploy("EntryPoint", {
    from,
    args: [],
    gasLimit: 6e6,
    deterministicDeployment: true,
  });
  console.log("==entrypoint addr=", ret.address);
  assert(ret.address !== null);
  expect(ret.address).to.eql("0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789");
  /*
  const entryPointAddress = ret.address
  const w = await hre.deployments.deploy(
    'SimpleAccount', {
      from,
      args: [entryPointAddress, from],
      gasLimit: 2e6,
      deterministicDeployment: true
    })

  console.log('== wallet=', w.address)

  const t = await hre.deployments.deploy('TestCounter', {
    from,
    deterministicDeployment: true
  })
  console.log('==testCounter=', t.address)
  */
};

export default deployEntryPoint;
