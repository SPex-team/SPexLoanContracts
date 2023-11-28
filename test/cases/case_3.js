const ONE_ETHER = BigInt(1e18);
const RATE_BASE = 1000000n;
const BORROW_FEE_RATE = 10000n;
const REDEEM_FEE_RATE = 5000n;

const ACCOUNT_INIT_BALANCE = 100000000000000000000000000000n;
const HARDHAT_INIT_BLOCK_NUMBER = 1000
const HARDHAT_INIT_TIMESTAMP = 5000000000

const CASE = {
  name: "",
  stepList: [
    {
      increaseBlockNumber: 3,
      contractName: "spexBeneficiary",
      functionName: "pledgeBeneficiaryToSpex",
      params: [
        10323231,
        "0x23",
        423,
        100n * ONE_ETHER,
        100000,
        "__signer10",
        false,
        10,
        ONE_ETHER * 1n,
      ],
      value: BigInt(0),
      signerIndex: 1,
    },
    {
      increaseBlockNumber: 343,
      contractName: "spexBeneficiary",
      functionName: "pledgeBeneficiaryToSpex",
      params: [
        1039992,
        "0x23",
        423,
        20000n * ONE_ETHER,
        120000,
        "__signer11",
        false,
        10,
        ONE_ETHER * 1n,
      ],
      value: BigInt(0),
      signerIndex: 2,
    },
    {
      increaseBlockNumber: 3434,
      contractName: "spexBeneficiary",
      functionName: "lendToMiner",
      params: [10323231, 100000],
      value: BigInt(10n * ONE_ETHER),
      signerIndex: 3,
    },
    {
      increaseBlockNumber: 43812,
      contractName: "spexBeneficiary",
      functionName: "lendToMiner",
      params: [10323231, 100000],
      value: BigInt(20n * ONE_ETHER),
      signerIndex: 4,
    },
    {
      increaseBlockNumber: 184923,
      contractName: "spexBeneficiary",
      functionName: "directRepayment",
      params: ["__signer3", 10323231],
      value: BigInt(7n * ONE_ETHER),
      signerIndex: 1,
    },
    {
      increaseBlockNumber: 43231,
      contractName: "spexBeneficiary",
      functionName: "sellLoan",
      params: [10323231, 8n * ONE_ETHER, BigInt(9e17)],
      value: 0,
      signerIndex: 4,
    },
    {
      increaseBlockNumber: 43231,
      contractName: "spexBeneficiary",
      functionName: "buyLoan",
      params: ["__signer4", 10323231, 6n * ONE_ETHER],
      value: 5400000000000000000n,
      signerIndex: 20,
    },
    {
      increaseBlockNumber: 434521,
      contractName: "spexBeneficiary",
      functionName: "buyLoan",
      params: ["__signer4", 10323231, 2n * ONE_ETHER],
      value: 1800000000000000000n,
      signerIndex: 21,
    },
  ],
  finalStateCheckList: [
    {
      increaseBlockNumber: 1023,
      contractName: "spexBeneficiary",
      functionName: "getMiner",
      params: [10323231],
      value: BigInt(0),
      signerIndex: 0,
      results: {
        minerId: 10323231n,
        delegator: "__signer1",
        maxDebtAmount: 100n * ONE_ETHER,
        loanInterestRate: 100000n,
        receiveAddress: "__signer10",
        disabled: false,
        principalAmount: 23n * ONE_ETHER + 219978804014920227n,
        maxLenderCount: 10n,
        minLendAmount: ONE_ETHER * 1n,
        lenders: ["__signer3", "__signer4", "__signer20", "__signer21"],
      },
    },
    {
      increaseBlockNumber: 1023,
      contractName: "spexBeneficiary",
      functionName: "_loans",
      params: ["__signer3", 10323231],
      value: BigInt(0),
      signerIndex: 0,
      results: {
        principalAmount: 3n * ONE_ETHER + 219978804014920227n,
        lastAmount: 3n * ONE_ETHER + 219978804014920227n,
        lastUpdateTime: HARDHAT_INIT_TIMESTAMP + (184923 + 43812 + 3434 + 343 + 3) * 30
      },
    },
    {
      increaseBlockNumber: 1023,
      contractName: "spexBeneficiary",
      functionName: "_loans",
      params: ["__signer4", 10323231],
      value: BigInt(0),
      signerIndex: 0,
      results: {
        principalAmount: 12282812324724056369n,
        lastAmount: 15135957409481899395n - 2n * ONE_ETHER,
        lastUpdateTime: HARDHAT_INIT_TIMESTAMP + (434521 + 43231 + 43231 + 184923 + 43812 + 3434 + 343 + 3) * 30
      },
    },
    {
      increaseBlockNumber: 1023,
      contractName: "spexBeneficiary",
      functionName: "_loans",
      params: ["__signer3", 1039992],
      value: BigInt(0),
      signerIndex: 0,
      results: {
        principalAmount: 0n,
        lastAmount: 0n,
        lastUpdateTime: 0n
      },
    },
    {
      increaseBlockNumber: 1023,
      contractName: "spexBeneficiary",
      functionName: "_loans",
      params: ["__signer4", 1039992],
      value: BigInt(0),
      signerIndex: 0,
      results: {
        principalAmount: 0n,
        lastAmount: 0n,
        lastUpdateTime: 0n
      },
    },
    {
      increaseBlockNumber: 1023,
      contractName: "spexBeneficiary",
      functionName: "_loans",
      params: ["__signer20", 10323231],
      value: BigInt(0),
      signerIndex: 0,
      results: {
        principalAmount: 20n * ONE_ETHER - 14152917706743334359n,
        lastAmount: 6n * ONE_ETHER,
        lastUpdateTime: HARDHAT_INIT_TIMESTAMP + (43231 + 43231 + 184923 + 43812 + 3434 + 343 + 3) * 30
      },
    },
  ],
  finalBalanceCheckList: [
    {
        accountType: "contract",
        contractName: "spexBeneficiary",
        accountIndex: 0,
        expectBalance: 21997880401492022n
    },
    {
        accountType: "owned",
        contractName: "",
        accountIndex: 1,
        expectBalance: ACCOUNT_INIT_BALANCE - 7n * ONE_ETHER
    },
    {
        accountType: "owned",
        contractName: "",
        accountIndex: 2,
        expectBalance: ACCOUNT_INIT_BALANCE
    },
    {
        accountType: "owned",
        contractName: "",
        accountIndex: 3,
        expectBalance: ACCOUNT_INIT_BALANCE - 10n * ONE_ETHER + 7n * ONE_ETHER - 21997880401492022n 
    },
    {
        accountType: "owned",
        contractName: "",
        accountIndex: 4,
        expectBalance: ACCOUNT_INIT_BALANCE - 20n * ONE_ETHER + (6n * ONE_ETHER * 9n / 10n) + (2n * ONE_ETHER * 9n / 10n)
    },
    {
        accountType: "owned",
        contractName: "",
        accountIndex: 5,
        expectBalance: ACCOUNT_INIT_BALANCE
    },
    {
        accountType: "owned",
        contractName: "",
        accountIndex: 6,
        expectBalance: ACCOUNT_INIT_BALANCE
    },
    {
        accountType: "owned",
        contractName: "",
        accountIndex: 10,
        expectBalance: ACCOUNT_INIT_BALANCE + 30n * ONE_ETHER
    },
    {
        accountType: "owned",
        contractName: "",
        accountIndex: 11,
        expectBalance: ACCOUNT_INIT_BALANCE
    },
    {
        accountType: "owned",
        contractName: "",
        accountIndex: 20,
        expectBalance: ACCOUNT_INIT_BALANCE - 5400000000000000000n
    },
    {
        accountType: "owned",
        contractName: "",
        accountIndex: 21,
        expectBalance: ACCOUNT_INIT_BALANCE - (2n * ONE_ETHER) * 9n / 10n
    },
    {
        accountType: "owned",
        contractName: "",
        accountIndex: 22,
        expectBalance: ACCOUNT_INIT_BALANCE
    }
  ],
};
module.exports.CASE = CASE;
