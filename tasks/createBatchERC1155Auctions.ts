/* global ethers hre task */

import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
// @ts-ignore
import { AuctionPreset } from "../types";
import { getSigner } from "../scripts/helperFunctions";

export interface BatchERC1155AuctionsTaskArgs {
  gbmDiamondAddress: string;
  deployer: string;
  tokenContractAddress: string;
  tokenIds: string;
  tokenAmounts: string;
  startTimes: string;
  endTimes: string;
  preset: string;
  categories: string;
  // preset: AuctionPreset;
}

task("createBatchERC1155Auctions", "Create batch ERC1155 in auction")
  .addParam("gbmDiamondAddress")
  .addParam("deployer", "The address of the deployer")
  .addParam("tokenContractAddress", "The contract address of the token")
  .addParam("preset", "Preset id")
  .addParam("tokenIds", "Comma-separated string of tokenIDs")
  .addParam("tokenAmounts", "Comma-separated string of tokenAmounts")
  .addParam("startTimes", "Comma-separated string of startTimes")
  .addParam("endTimes", "Comma-separated string of endTimes")
  .addParam("categories", "Categories of the auctions")
  .setAction(
    async (
      taskArgs: BatchERC1155AuctionsTaskArgs,
      hre: HardhatRuntimeEnvironment
    ) => {
      const gbmDiamondAddress = taskArgs.gbmDiamondAddress;
      const deployer = taskArgs.deployer;
      const tokenContractAddress = taskArgs.tokenContractAddress;
      const preset = taskArgs.preset;
      const tokenIds = taskArgs.tokenIds
        .split(",")
        .filter((str) => str.length > 0);

      console.log("token ids:", tokenIds);
      const startTimes = taskArgs.startTimes
        .split(",")
        .filter((str) => str.length > 0);

      console.log("start times:", startTimes);
      const endTimes = taskArgs.endTimes
        .split(",")
        .filter((str) => str.length > 0);

      const categories = taskArgs.categories
        .split(",")
        .filter((str) => str.length > 0);

      console.log("caterories:", categories);

      const signer = await getSigner(hre, deployer);
      const erc1155 = await hre.ethers.getContractAt(
        "ERC1155Generic",
        tokenContractAddress,
        signer
      );
      await erc1155.setApprovalForAll(gbmDiamondAddress, true);

      const gbm = await hre.ethers.getContractAt(
        "GBMFacet",
        gbmDiamondAddress,
        signer
      );

      for (let i = 0; i < tokenIds.length; i++) {
        const auctionDetails = {
          startTime: startTimes[i],
          endTime: endTimes[i],
          tokenAmount: 1,
          tokenKind: "0x973bb640", //ERC1155
          tokenID: tokenIds[i],
          category: categories[i],
        };

        console.log(`Deploying auction: ${i} of ${tokenIds.length}`);
        //If auction fails, set the < 0 below to i.
        if (i < 0) continue;

        const gasFee = await signer.provider.getFeeData();

        const tx = await gbm.createAuction(
          auctionDetails,
          tokenContractAddress,
          preset,
          {
            maxFeePerGas: gasFee.lastBaseFeePerGas.mul(4),
            maxPriorityFeePerGas: gasFee.maxPriorityFeePerGas,
          }
        );

        const txReceipt = await tx.wait();

        const event = txReceipt.events.find(
          (event) => event.event === "Auction_Initialized"
        );
        console.log(`Auction initialized with ID: ${event.args._auctionID}`);
      }
    }
  );
