import hre, { ethers } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployOptions } from "hardhat-deploy/dist/types";

import {
  MAXIMUM_WALLET_PENDING_TRANSACTIONS,
  MAXIMUM_WALLET_SIGNERS_COUNT,
} from "../config";

module.exports = async ({
  deployments,
  getNamedAccounts,
}: HardhatRuntimeEnvironment) => {
  const { deployer } = await getNamedAccounts(); //Get the contract deployer
  const { deploy } = deployments;

  const args: DeployOptions["args"] = [
    deployer,
    MAXIMUM_WALLET_PENDING_TRANSACTIONS,
    MAXIMUM_WALLET_SIGNERS_COUNT,
  ]; //Deployment parameters;

  console.log("Deploying MultisignatureWallet........");

  console.log(await hre.artifacts.getArtifactPaths());
  const MultisignatureWallet = await deploy("MultiSignatureWallet", {
    from: deployer,
    args: args,
    waitConfirmations: 1,
  });

  console.log("Deploying MultisignatureWallet completed........");

  console.log(MultisignatureWallet.address, "...Address");
};

module.exports.tags = ["all", "wallet"];
