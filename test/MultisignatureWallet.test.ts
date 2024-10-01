import { describe, beforeEach } from "mocha";
import { deployments, getNamedAccounts } from "hardhat";
import { ethers } from "hardhat";
import { assert, expect } from "chai";

import {
  MAXIMUM_WALLET_PENDING_TRANSACTIONS,
  MAXIMUM_WALLET_SIGNERS_COUNT,
  mockAccounts,
} from "../config";
("=");
import { MultiSignatureWallet } from "../typechain-types";
import { AddressLike } from "ethers";

describe("MultiSignatureWallet", async () => {
  let Contract: MultiSignatureWallet;
  let deployer: AddressLike;
  let signers: {
    singerAddress: AddressLike;
    canInitiateTransaction: boolean;
  }[];

  beforeEach(async () => {
    await deployments.fixture(["all"]);
    const contractAddress = (await deployments.get("MultiSignatureWallet"))
      .address;
    Contract = await ethers.getContractAt(
      "MultiSignatureWallet",
      contractAddress
    );

    deployer = (await getNamedAccounts()).deployer;

    signers = mockAccounts.map((account) => ({
      singerAddress: account.address,
      canInitiateTransaction: false,
    }));
  });

  describe("Contructor", async () => {
    it("should set proper _maximum_pendingTransaction and _maximum_signers", async () => {
      console.log(MAXIMUM_WALLET_PENDING_TRANSACTIONS);

      assert.equal(
        (await Contract.i_maximum_pendingTransaction()).toString(),
        MAXIMUM_WALLET_PENDING_TRANSACTIONS
      );

      //Should avoid having two asserts in one place 😁
      assert.equal(
        (await Contract.i_maximum_signers()).toString(),
        MAXIMUM_WALLET_SIGNERS_COUNT.toString()
      );
    });
  });

  //The approval counts should not be more than signers
  describe("createWallet", async () => {
    const _signers = mockAccounts.map((account) => ({
      singerAddress: account.address,
      canInitiateTransaction: false,
    }));

    const _owner = deployer as AddressLike;

    it("Should not create wallet twice", async () => {
      const approvalCounts = "4";
      await Contract.createWallet(deployer, _signers, approvalCounts);

      expect(
        Contract.createWallet(_owner, _signers, approvalCounts)
      ).to.be.revertedWith("Wallet already created");
    });

    it("Approval count should not exceed the length of signers", async () => {
      const approvalCounts = "6";

      expect(
        Contract.createWallet(_owner, _signers, approvalCounts)
      ).to.be.revertedWithCustomError(
        Contract,
        "ApprovalCountExceedSignersLength"
      );
    });

    it("shoud not exceed _maximum__approvalCount", async () => {
      const approvalCounts = "90";

      expect(
        Contract.createWallet(_owner, _signers, approvalCounts)
      ).to.be.revertedWithCustomError(
        Contract,
        "SignersLenghtExceedMaximumSignersLength"
      );
    });

    it("Should successfully create wallet if all conditions match.", async () => {
      {
        const approvalCounts = "5";
        const _owner = deployer;

        //create wallet.
        const transaction = Contract.createWallet(
          _owner,
          _signers,
          approvalCounts
        );

        //Wait for one block confirmation.
        (await transaction).wait(1);

        assert.equal(
          (await Contract.getWallet(_owner)).signers.length,
          _signers.length + 1
        );
      }
    });
  });

  describe("fundWallet", async () => {
    beforeEach(async () => {
      const approvalCounts = "5";
      const _owner = (await ethers.getSigners())[0];

      const createWallet = await Contract.createWallet(
        _owner.address,
        signers,
        approvalCounts
      );

      createWallet.wait(1);
    });

    it("Should only fund an existing wallet", () => {
      expect(Contract.fundWallet(mockAccounts[3].address)).to.be.revertedWith(
        "Wallet does not exist"
      );
    });

    it("Should revert the transaction if funds are sent to a non-existing wallet", async () => {
      const _owner = (await ethers.getSigners())[0];
      const sender = (await ethers.getSigners())[2];

      const senderBalance = ethers.provider.getBalance(sender);

      try {
        //Send money to a wallet that does not exist
        const fundingTransaction = await Contract.connect(_owner).fundWallet(
          (
            await ethers.getSigners()
          )[3].address,
          {
            value: ethers.parseEther("1"),
          }
        );

        fundingTransaction.wait(1);
      } catch (error) {
        console.log(error);
      }

      const senderNewBalance = ethers.provider.getBalance(sender);

      assert.equal(
        (await senderBalance).toString(),
        (await senderNewBalance).toString()
      );
    });

    it("Should decrease sender's balance after funding the wallet", async () => {
      const _owner = (await ethers.getSigners())[0];
      const sender = (await ethers.getSigners())[2];

      const senderBalance = await ethers.provider.getBalance(sender);

      try {
        //Fund the wallet
        const fundingTransaction = await Contract.connect(sender).fundWallet(
          _owner.address,
          {
            value: ethers.parseEther("500"),
          }
        );

        fundingTransaction.wait(1);
      } catch (error) {
        console.log(error);
      }

      const senderNewBalance = await ethers.provider.getBalance(sender);
      assert.notEqual(senderBalance.toString(), senderNewBalance.toString());
    });

    it("Should increase balance after funding the wallet", async () => {
      const _owner = (await ethers.getSigners())[0];
      const walletBlance = ethers.formatEther(
        (await Contract.getWallet(_owner)).balance.toString()
      );

      const fundingTransaction = await Contract.connect(_owner).fundWallet(
        _owner.address,
        {
          value: ethers.parseEther("1"),
        }
      );

      fundingTransaction.wait(1);

      const updatedWalletBalance = ethers.formatEther(
        (await Contract.getWallet(deployer)).balance.toString()
      );

      assert.equal(Number(updatedWalletBalance), Number(walletBlance) + 1);
    });
  });
});
