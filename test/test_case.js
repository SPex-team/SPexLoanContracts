const hre = require("hardhat");
const { ethers } = require("hardhat");

const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

const { BigNumber, BigNumberish } = require("@ethersproject/bignumber");
const {
  BN, // Big Number support
  constants, // Common constants, like the zero address and largest integers
  expectEvent, // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");
const { Contract, utils, ZERO_ADDRESS } = require("ethers");
const { assert } = require("console");
const { transaction } = require("@openzeppelin/test-helpers/src/send");
const { duration } = require("@openzeppelin/test-helpers/src/time");

const case_1 = require("./cases/case_4");

const ONE_ETHER = BigInt(1e18);

const INIT_FEE_RATE = 100;
const INIT_MANAGER = "0xa293B3d8EF9F2318F7E316BF448e869e8833ec63";
const FEE_RATE_TOTAL = 10000;
const MAX_COMMISSION = 500e18;

// const [owner] = await ethers.getSigners()

// const INIT_FOUNDATION_ADDRESS = owner.address
const INIT_MAX_DEBT_RATE = 400000;

// const SPex = artifacts.require('SPex')

describe("Contracts", function () {
  async function deployContracts() {
    const [owner] = await ethers.getSigners();

    const LibCommon = await ethers.getContractFactory("Common");
    const libCommon = await LibCommon.deploy();

    const LibValidator = await ethers.getContractFactory("Validator");
    const libValidator = await LibValidator.deploy();

    console.log("libCommon.target: ", libCommon.target);
    console.log("libValidator.target: ", libValidator.target);

    const SPexBeneficiary = await hre.ethers.getContractFactory(
      "SPexBeneficiary",
      {
        libraries: {
          Common: libCommon.target,
        },
      }
    );
    const spexBeneficiary = await SPexBeneficiary.deploy(
    );

    return { spexBeneficiary };
  }

  function getProcessedParams(params, signers) {
    if (Array.isArray(params)) {
      let newParams = [];
      for (let item of params) {
        if (Array.isArray(item) || typeof item == "object") {
          newChildren = getProcessedParams(item, signers);
          newParams.push(newChildren);
          continue;
        } else if (typeof item === "string") {
          if (item.startsWith("__signer")) {
            signerIndex = Number(item.split("__signer")[1]);
            signer = signers[signerIndex];
            newParams.push(signer.address);
            continue;
          }
        }
        newParams.push(item);
      }
      return newParams;
    }
    if (typeof params == "object") {
      let newParams = {};
      for (key in params) {
        value = params[key];
        if (typeof value === "string" && value.startsWith("__signer")) {
          signerIndex = Number(value.split("__signer")[1]);
          signer = signers[signerIndex];
          newParams[key] = signer.address;
          continue;
        } else if (typeof value == "object") {
          r = getProcessedParams(value, signers);
          newParams[key] = r;

          continue;
        }
        newParams[key] = value;
      }
      return newParams;
    }

    if (typeof params === "string" && params.startsWith("__signer")) {
      signerIndex = Number(value.split("__signer")[1]);
      signer = signers[signerIndex];
      return signer.address;
    }
    return params;
  }

  //   if (typeOfStepResults === "object") {
  //     for (let key of Object.keys(processedResults)) {
  //       targetValue = processedResults[key];
  //       resultValue = results[key];
  //       if (BigNumber.isBigNumber(resultValue)) {
  //         resultValue = resultValue.toBigInt();
  //       }
  //       if (resultValue !== targetValue) {
  //         console.log(typeof resultValue, typeof targetValue);
  //         throw `return value is not match expected key: ${key} targetValue: ${targetValue} resultValue: ${resultValue}`;
  //       }
  //     }
  //   } else if (typeOfStepResults === "bigint") {
  //     resultValue = results.toBigInt();
  //     if (resultValue !== processedResults) {
  //       throw `return value is not match expected step.results: ${processedResults} resultValue: ${resultValue}`;
  //     }
  //   } else {
  //     // if (BigNumber.isBigNumber(results)) {
  //     //   resultValue = results.toBigInt()
  //     //   if (resultValue !== targetValue) {
  //     //     throw(`return value is not match expected targetValue: ${targetValue} resultValue: ${resultValue}`)
  //     //   }
  //     // }
  //     throw `Unknown type of step.results ${typeOfStepResults}`;
  //   }

  function checkParams(expectParams, chainParams) {
    console.log("expectParams: ", expectParams);
    if (Array.isArray(expectParams)) {
      if (expectParams.length != chainParams.length) {
        throw `expectParams.length != chainParams.length ${expectParams.length} != ${chainParams.length}`;
      }
      for (index in expectParams) {
        checkParams(expectParams[index], chainParams[index]);
      }
      return;
    }
    let typeOfExpectParams = typeof expectParams;
    if (typeOfExpectParams === "object") {
      if (Object.keys(expectParams).length != Object.keys(chainParams).length) {
        throw `Object.keys(expectParams).length != Object.keys(chainParams).length expectParams: ${expectParams} chainParams: ${chainParams}`;
      }
      for (let key of Object.keys(expectParams)) {
        expectValue = expectParams[key];
        chainValue = chainParams[key];
        if (chainValue === undefined) {
          throw `the key ${key} not in chainParams ${chainParams}`;
        }
        checkParams(expectValue, chainValue);
      }
      return;
    }
    // if (typeOfExpectParams === "bigint") {
    //   console.log("typeof chainParams: ", typeof chainParams, chainParams);
    //   let chainValue = chainParams.toBigInt();
    //   if (chainValue !== expectParams) {
    //     throw `return chainParams is not match expected expectParams: ${expectParams} chainValue: ${chainValue}`;
    //   }
    // }
    if (expectParams != chainParams) {
      throw `return chainParams is not match expected expectParams: ${expectParams} chainParams: ${chainParams}`;
    }
  }

  describe("Test flow", function () {
    it("Test all", async function () {
      let lastTimestamp2 = (await ethers.provider.getBlock()).timestamp;
      console.log("lastTimestamp2: ", lastTimestamp2);

      defaultSigners = await ethers.getSigners();
      sender = defaultSigners[0];
      signers = [sender];

      for (let i = 0; i < 100; i++) {
        wallet = ethers.Wallet.createRandom();
        signer = wallet.connect(ethers.provider);
        amount = 100000000000000000000000000000n;
        sendTransaction = {
          to: signer.address,
          value: amount,
        };
        await sender.sendTransaction(sendTransaction);
        signers.push(signer);
      }

      const contracts = await loadFixture(deployContracts);
      // const signers = await ethers.getSigners()

      let stepList = case_1.CASE.stepList;

      let finalStateCheckList = case_1.CASE.finalStateCheckList;

      let blockNumber = await ethers.provider.getBlockNumber();

      let lastTimestamp = 5000000000 - (1000 - blockNumber) + 1;
      await hre.network.provider.send("evm_setNextBlockTimestamp", [
        `0x${lastTimestamp.toString(16)}`,
      ]);

      let mineBlockNumberHex = `0x${(1000 - blockNumber).toString(16)}`;
      await hre.network.provider.send("hardhat_mine", [
        mineBlockNumberHex,
        "0x1",
      ]);

      blockNumber = await ethers.provider.getBlockNumber();
      console.log("blockNumber: ", blockNumber);

      lastTimestamp = (await ethers.provider.getBlock()).timestamp;
      console.log("lastTimestamp3: ", lastTimestamp);

    //   let loan = await contracts["spexBeneficiary"]._loans(signers[1].address, 10323231);
    //   console.log(
    //     "signer address: ",
    //     signer.address,
    //     "loan: ",
    //     loan
    //   );

      for (stepIndex in stepList) {
        step = stepList[stepIndex];
        console.log(
          `stepIndex: ${stepIndex} step.contractName: ${step.contractName} step.functionName: ${step.functionName} signerIndex: ${step.signerIndex}`
        );

        if (step.mineBlockNumber < 2) {
          throw "step.mineBlockNumber < 2";
        }
        mineBlockNumberHex = `0x${(step.increaseBlockNumber - 2).toString(16)}`;
        await hre.network.provider.send("hardhat_mine", [
          mineBlockNumberHex,
          "0x1",
        ]);

        lastTimestamp += step.increaseBlockNumber * 30;
        await hre.network.provider.send("evm_setNextBlockTimestamp", [
          `0x${lastTimestamp.toString(16)}`,
        ]);

        let contract = contracts[step.contractName];
        let signer = signers[step.signerIndex];
        let newParams = getProcessedParams(step.params, signers);

        let tx = await contract
          .connect(signer)
          [step.functionName](...newParams, { value: step.value });
        let result = await tx.wait();

        // await contract._updateLenderOwedAmount(signer.address, 10323231);
        // let miner = await contract._miners(10323231);
        // let loan = await contract._loans(signers[1].address, 10323231);
        // console.log(
        //   "miner: ",
        //   miner,
        //   "signer address: ",
        //   signer.address,
        //   "loan: ",
        //   loan,
        //   "signers[1].address: ",
        //   signers[1].address
        // );

        let block = await ethers.provider.getBlock();
        let blockTmestamp = (await ethers.provider.getBlock()).timestamp;
        console.log(
          "block.number: ",
          block.number,
          "blockTmestamp: ",
          blockTmestamp,
          "result.cumulativeGasUsed: ",
          result.cumulativeGasUsed
        );

        sendTransaction = {
          to: signer.address,
          value: result.cumulativeGasUsed * result.gasPrice,
        };
        await signers[0].sendTransaction(sendTransaction);

        try {
            // let loan3 = await contracts["spexBeneficiary"]._loans(signers[3].address, 10323231)
            // let loan4 = await contracts["spexBeneficiary"]._loans(signers[4].address, 10323231)

            // let miner = await contract._miners(10323231);
            // console.log("miner: ", miner);

            // console.log("loan3: ", loan3)
            // console.log("loan4: ", loan4)

            console.log("result.logs: ", result.logs)
            let balance = await ethers.provider.getBalance(signers[3].address);
            console.log("balance: ", balance)



        } catch (error) {}
      }

      for (stepIndex in finalStateCheckList) {
        step = finalStateCheckList[stepIndex];
        console.log(
          `checkStepIndex: ${stepIndex} step.contractName: ${step.contractName} step.functionName: ${step.functionName}`
        );

        let contract = contracts[step.contractName];
        let signer = signers[step.signerIndex];

        let newParams = getProcessedParams(step.params, signers);

        let results = await contract
          .connect(signer)
          [step.functionName](...newParams, { value: step.value });

        // console.log("results: ", results);
        // console.log("results.lenders: ", results.lenders);

        // let miner = await contract._miners(10323231);
        // console.log("miner: ", miner);

        const processedResults = getProcessedParams(step.results, signers);

        checkParams(processedResults, results);
      }

      let finalBalanceCheckList = case_1.CASE.finalBalanceCheckList;

      for (let index in finalBalanceCheckList) {
        let accountInfo = finalBalanceCheckList[index]
        console.log("check account balance, index:", index, "accountInfo: ", accountInfo);
        let address = "";
        if (accountInfo.accountType == "contract") {
          address = contracts[accountInfo.contractName].target;
        } else if (accountInfo.accountType == "owned") {
          address = signers[accountInfo.accountIndex].address;
        } else {
          throw `unknown accountInfo.accountType: ${accountInfo.accountType}`;
        }

        let balance = await ethers.provider.getBalance(address);

        if (accountInfo.tolaranceRange !== undefined && accountInfo.tolaranceRange != null) {
            let diff = balance - accountInfo.expectBalance
            diff = Number(diff)
            balance = Number(balance)
            expectBalance = Number(accountInfo.expectBalance)
            let tolaranceRange = Math.abs(diff) / Math.min(balance, expectBalance)
            if (tolaranceRange > accountInfo.tolaranceRange) {
                throw `balance is not equal accountInfo.contractName: ${accountInfo.contractName} accountInfo.accountIndex: ${accountInfo.accountIndex} chain balance: ${balance} expect balance: ${accountInfo.expectBalance} Actual tolaranceRange: ${tolaranceRange}`;     
            }
        }
        else if (balance != accountInfo.expectBalance) {
          throw `balance is not equal accountInfo.contractName: ${accountInfo.contractName} accountInfo.accountIndex: ${accountInfo.accountIndex} chain balance: ${balance} expect balance: ${accountInfo.expectBalance}`;
        }

        // let accountAddress = "";
        // if (typeof accountName == "string") {
        //   console.log("contracts[accountName]: ", contracts[accountName]);
        //   accountAddress = contracts[accountName].target;
        // } else {
        //   accountAddress = signers[accountName].address;
        // }
        // let balance = await ethers.provider.getBalance(accountAddress);
        // if (balance != finalBalanceCheckList[accountName]) {
        //   throw `balance is not equal accountName: ${accountName} chain balance: ${balance} expect balance: ${finalBalanceCheckList[accountName]}`;
        // }
      }
    });
  });
});
