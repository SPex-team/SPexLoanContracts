// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@zondax/filecoin-solidity/contracts/v0.8/MinerAPI.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/types/MinerTypes.sol";

import "@zondax/filecoin-solidity/contracts/v0.8/AccountAPI.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/types/AccountTypes.sol";

import "@zondax/filecoin-solidity/contracts/v0.8/PrecompilesAPI.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/utils/FilAddresses.sol";

import "@zondax/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";

import "fevmate/contracts/utils/FilAddress.sol";

import "./utils/Common.sol";
import "./utils/Validator.sol";


/// @author SPex Team
contract SPexBeneficiary {
    event EventPledgeBeneficiaryToSpex(
        CommonTypes.FilActorId minerId,
        address indexed delegator,
        uint maxDebtAmount,
        uint loanInterestRate,
        address receiveAddress,
        uint8 maxLenderCount,
        uint minLendAmount);
    event EventReleaseBeneficiary(CommonTypes.FilActorId minerId, CommonTypes.FilAddress newBeneficiary);
    event EventLendToMiner(address indexed lender, CommonTypes.FilActorId minerId, uint amount);
    event EventChangeMinerDelegator(CommonTypes.FilActorId minerId, address newDelegator);
    event EventChangeMinerMaxDebtAmount(CommonTypes.FilActorId minerId, uint newMaxDebtAmount);
    event EventChangeMinerDisabled(CommonTypes.FilActorId minerId, bool disabled);
    event EventChangeMinerLoanInterestRate(CommonTypes.FilActorId minerId, uint newLoanInterestRate);
    event EventChangeMinerReceiveAddress(CommonTypes.FilActorId minerId, address newReceiveAddress);
    event EventChangeMinerMaxLenderCount(CommonTypes.FilActorId minerId, uint maxLenderCount);
    event EventChangeMinerMinLendAmount(CommonTypes.FilActorId minerId, uint minLendAmount);
    event EventRepayment(address repayer, address lender, CommonTypes.FilActorId minerId, uint actualRepaymentAmount, uint repaiedInterest);
    event EventWithdrawRepayment(address operator, address lender, CommonTypes.FilActorId minerId, uint actualRepaymentAmount, uint repaiedInterest);
    event EventSellLoan(address seller, CommonTypes.FilActorId minerId, uint ceilingAmount, uint pricePerFil);
    event EventBuyLoan(address buyer, address seller, CommonTypes.FilActorId minerId, uint buyAmount, uint pricePerFil, uint principalChange);
    event EventCancelSellLoan(address operator, CommonTypes.FilActorId minerId);

    struct Miner {
        CommonTypes.FilActorId minerId;
        address delegator;
        uint maxDebtAmount;
        uint loanInterestRate;
        address receiveAddress;
        bool disabled;
        uint principalAmount;
        uint maxLenderCount;
        uint minLendAmount;
        address[] lenders;
    }

    struct Loan {
        uint principalAmount;
        uint lastAmount;
        uint lastUpdateTime;
    }

    struct SellItem {
        uint amountRemaining;
        uint pricePerFil;
    }

    mapping(CommonTypes.FilActorId => Miner) public _miners;
    mapping(address => mapping(CommonTypes.FilActorId => Loan)) public  _loans;
    mapping(address => mapping(CommonTypes.FilActorId => SellItem)) public _sales;
    mapping(address => uint) public _lastTimestampMap;

    address public _foundation;
    uint public _feeRate;
    uint public _maxDebtRate;

    uint constant public MAX_FEE_RATE = 200000;
    uint constant public RATE_BASE = 1000000;

    uint constant public REQUIRED_QUOTA = 1e68 - 1e18;
    int64 constant public REQUIRED_EXPIRATION = type(int64).max;

    constructor() {
        _foundation = msg.sender;
        _maxDebtRate = 400000;
        _feeRate = 100000;
    }

    function _validateTimestamp(uint timestamp) internal {
        require(timestamp < (block.timestamp + 120) && timestamp > (block.timestamp - 1800), "Provided timestamp expired");
        require(timestamp > _lastTimestampMap[msg.sender], "Provided timestamp must be bigger than last one provided");
        _lastTimestampMap[msg.sender] = timestamp;
    }

    modifier onlyMinerDelegator(CommonTypes.FilActorId minerId) {
        require(_miners[minerId].delegator == msg.sender, "Only miner's delegator allowed");
        _;
    }

    function _checkMaxDebtAmount(CommonTypes.FilActorId minerId, uint maxDebtAmount) internal view {
        uint64 minerIdUint64 = CommonTypes.FilActorId.unwrap(minerId);
        uint minerBalance = FilAddress.toAddress(minerIdUint64).balance;
        require(maxDebtAmount <= (minerBalance * _maxDebtRate / RATE_BASE), "Specified max debt amount exceeds max allowed by miner balance");
    }

    function _prePledgeBeneficiaryToSpex(CommonTypes.FilActorId minerId, bytes memory sign, uint timestamp, uint maxDebtAmount, uint minLendAmount) internal {
        uint64 minerIdUint64 = CommonTypes.FilActorId.unwrap(_miners[minerId].minerId);
        require(minerIdUint64 == 0,  "The miner is already in SPex");
        require(maxDebtAmount >= minLendAmount, "maxDebtAmount amount smaller than minLendAmount");

        MinerTypes.GetOwnerReturn memory ownerReturn = MinerAPI.getOwner(minerId);
        uint64 ownerUint64 = PrecompilesAPI.resolveAddress(ownerReturn.owner);
        uint64 senderUint64 = PrecompilesAPI.resolveEthAddress(msg.sender);
        if (senderUint64 != ownerUint64) {
            _validateTimestamp(timestamp);
            Validator.validateOwnerSignForBeneficiary(sign, minerId, ownerUint64, timestamp);
        }

        _checkMaxDebtAmount(minerId, maxDebtAmount);
    }

    function pledgeBeneficiaryToSpex(
        CommonTypes.FilActorId minerId, 
        bytes memory sign, 
        uint timestamp, 
        uint maxDebtAmount, 
        uint loanInterestRate, 
        address receiveAddress, 
        bool disabled,
        uint8 maxLenderCount,
        uint minLendAmount) external {

        _prePledgeBeneficiaryToSpex(minerId, sign, timestamp, maxDebtAmount, minLendAmount);

        MinerTypes.GetBeneficiaryReturn memory beneficiaryRet = MinerAPI.getBeneficiary(minerId);

        // new_quota check
        require(Common.bigInt2Uint(beneficiaryRet.proposed.new_quota) == REQUIRED_QUOTA, "Invalid quota");
        int64 expiration = CommonTypes.ChainEpoch.unwrap(beneficiaryRet.proposed.new_expiration);
        uint64 uExpiration = uint64(expiration);
        require(expiration == REQUIRED_EXPIRATION && uExpiration > block.number, "Invalid expiration time");
        require(uint(keccak256(abi.encode(MinerAPI.getOwner(minerId).owner.data))) == 
        uint(keccak256(abi.encode(beneficiaryRet.active.beneficiary.data))), "Beneficiary is not owner");

        // change beneficiary to contract
        MinerAPI.changeBeneficiary(minerId, MinerTypes.ChangeBeneficiaryParams({
            new_beneficiary: beneficiaryRet.proposed.new_beneficiary,
            new_quota: beneficiaryRet.proposed.new_quota,
            new_expiration: beneficiaryRet.proposed.new_expiration
        }));
        
        Miner memory miner = Miner ({
            minerId: minerId,
            delegator: msg.sender,
            maxDebtAmount: maxDebtAmount,
            loanInterestRate: loanInterestRate,
            receiveAddress: receiveAddress,
            disabled: disabled,
            principalAmount: 0,
            maxLenderCount: maxLenderCount,
            minLendAmount: minLendAmount,
            lenders: new address[](0)
        });
        _miners[minerId] = miner;
        emit EventPledgeBeneficiaryToSpex(minerId, msg.sender, maxDebtAmount, loanInterestRate, receiveAddress, maxLenderCount, minLendAmount);
    }

    function releaseBeneficiary(CommonTypes.FilActorId minerId) external onlyMinerDelegator(minerId) {
        uint64 minerIdUint64 = CommonTypes.FilActorId.unwrap(_miners[minerId].minerId);
        require(minerIdUint64 != 0,  "Beneficiary of miner is not pledged to SPex");
        require(_updateMinerDebtAmounts(minerId) == 0 , "Debt not fully paid off");
        
        CommonTypes.FilAddress memory minerOwner = MinerAPI.getOwner(minerId).owner;        
        MinerAPI.changeBeneficiary(
            minerId,
            MinerTypes.ChangeBeneficiaryParams({
                new_beneficiary: minerOwner,
                new_quota: CommonTypes.BigInt(hex"00", false),
                new_expiration: CommonTypes.ChainEpoch.wrap(0)
            })
        );

        delete _miners[minerId];
        emit EventReleaseBeneficiary(minerId, minerOwner);
    }

    function changeMinerDelegator(CommonTypes.FilActorId minerId, address newDelegator) public onlyMinerDelegator(minerId) {
        _miners[minerId].delegator = newDelegator;
        emit EventChangeMinerDelegator(minerId, newDelegator);
    }

    function changeMinerMaxDebtAmount(CommonTypes.FilActorId minerId, uint newMaxDebtAmount) public onlyMinerDelegator(minerId) {
        Miner storage miner = _miners[minerId];
        uint currentDebtAmount = _updateMinerDebtAmounts(minerId);
        require(newMaxDebtAmount >= currentDebtAmount, "New max debt amount smaller than current amount owed");
        _checkMaxDebtAmount(minerId, newMaxDebtAmount);
        miner.maxDebtAmount = newMaxDebtAmount;
        emit EventChangeMinerMaxDebtAmount(minerId, newMaxDebtAmount);
    }

    function changeMinerLoanInterestRate(CommonTypes.FilActorId minerId, uint newLoanInterestRate) public onlyMinerDelegator(minerId) {
        Miner storage miner = _miners[minerId];
        require(_updateMinerDebtAmounts(minerId) == 0, "Debt not fully paid off");
        miner.loanInterestRate = newLoanInterestRate;
        emit EventChangeMinerLoanInterestRate(minerId, newLoanInterestRate);
    }

    function changeMinerReceiveAddress(CommonTypes.FilActorId minerId, address newReceiveAddress) public onlyMinerDelegator(minerId) {
        _miners[minerId].receiveAddress = newReceiveAddress;
        emit EventChangeMinerReceiveAddress(minerId, newReceiveAddress);
    }

    function changeMinerDisabled(CommonTypes.FilActorId minerId, bool disabled) public onlyMinerDelegator(minerId) {
        _miners[minerId].disabled = disabled;
        emit EventChangeMinerDisabled(minerId, disabled);
    }

    function changeMinerMaxLenderCount(CommonTypes.FilActorId minerId, uint maxLenderCount) public onlyMinerDelegator(minerId) {
        _miners[minerId].maxLenderCount = maxLenderCount;
        emit EventChangeMinerMaxLenderCount(minerId, maxLenderCount);
    }

    function changeMinerMinLendAmount(CommonTypes.FilActorId minerId, uint minLendAmount) public onlyMinerDelegator(minerId) {
        _miners[minerId].minLendAmount = minLendAmount;
        emit EventChangeMinerMinLendAmount(minerId, minLendAmount);
    }

    function changeMinerBorrowParameters(
        CommonTypes.FilActorId minerId,
        address newDelegator,
        uint newMaxDebtAmount,
        uint newLoanInterestRate,
        address newReceiveAddress,
        bool disabled,
        uint maxLenderCount,
        uint minLendAmount
    ) external {    //No onlyMinerDelegator(minerId) modifier because the functions called have this modifier
        changeMinerMaxDebtAmount(minerId, newMaxDebtAmount);
        if (newLoanInterestRate != _miners[minerId].loanInterestRate) {
            changeMinerLoanInterestRate(minerId, newLoanInterestRate);
        }
        changeMinerReceiveAddress(minerId, newReceiveAddress);
        changeMinerDisabled(minerId, disabled);
        changeMinerMaxLenderCount(minerId, maxLenderCount);
        changeMinerMinLendAmount(minerId, minLendAmount);
        changeMinerDelegator(minerId, newDelegator);
    }

    function lendToMiner(CommonTypes.FilActorId minerId, uint expectedInterestRate) external payable {
        Miner storage miner = _miners[minerId];
        require(expectedInterestRate == miner.loanInterestRate, "Interest rate not equal to expected");
        require(miner.disabled == false, "Lending for this miner is disabled");

        require(msg.value >= miner.minLendAmount, "Lend amount smaller than minimum allowed");
        
        uint minerTotalDebtAmount = _updateMinerDebtAmounts(minerId);
        require((miner.principalAmount + msg.value) <= miner.maxDebtAmount, "Debt amount after lend large than allowed by miner");

        uint64 minerIdUint64 = CommonTypes.FilActorId.unwrap(minerId);
        uint minerBalance = FilAddress.toAddress(minerIdUint64).balance;
        require((minerTotalDebtAmount + msg.value) <= (minerBalance * _maxDebtRate / RATE_BASE), "Debt rate of miner after lend larger than allowed");
        _increaseOwedAmounts(msg.sender, minerId, msg.value);
        require(_loans[msg.sender][minerId].principalAmount >= miner.minLendAmount, "Lend amount to small");
        require(miner.lenders.length <= miner.maxLenderCount, "Lenders list too long");
        payable(miner.receiveAddress).transfer(msg.value);
        emit EventLendToMiner(msg.sender, minerId, msg.value);
    }

    function sellLoan(CommonTypes.FilActorId minerId, uint ceilingAmount, uint pricePerFil) public {
        require(_loans[msg.sender][minerId].lastAmount > 0, "Loan does not exist");
        require(_sales[msg.sender][minerId].amountRemaining == 0, "Sale already exists");
        SellItem memory sellItem = SellItem({
            amountRemaining: ceilingAmount,
            pricePerFil: pricePerFil
        });
        _sales[msg.sender][minerId] = sellItem;
        emit EventSellLoan(msg.sender, minerId, ceilingAmount, pricePerFil);
    }

    function modifyLoanSale(CommonTypes.FilActorId minerId, uint amount, uint price) external {
        cancelLoanSale(minerId);
        sellLoan(minerId, amount, price);
    }

    function cancelLoanSale(CommonTypes.FilActorId minerId) public {
        SellItem storage sellItem = _sales[msg.sender][minerId];
        require(sellItem.amountRemaining > 0, "Sale don't exist");
        delete _sales[msg.sender][minerId];
        emit EventCancelSellLoan(msg.sender, minerId);
    }

    function buyLoan(address payable seller, CommonTypes.FilActorId minerId, uint buyAmount, uint expectedPricePerFil) external payable {
        Miner storage miner = _miners[minerId];
        SellItem storage sellItem = _sales[seller][minerId];
        require(sellItem.pricePerFil == expectedPricePerFil, "Price not equal to expected");
        require(sellItem.amountRemaining != 0, "Sale doesn't exist");
        require(buyAmount <= sellItem.amountRemaining, "buyAmount larger than amount on sale");
        uint requiredPayment = sellItem.pricePerFil * buyAmount / 1 ether;
        require(msg.value == requiredPayment, "Paid amount not equal to sale price");

        _updateLenderOwedAmount(msg.sender, minerId);
        uint newAmount = _updateLenderOwedAmount(seller, minerId);
        require(buyAmount <= newAmount, "Insufficient owed amount");

        Loan storage sellerLoan = _loans[seller][minerId];
        Loan storage buyerLoan = _loans[msg.sender][minerId];
        uint principalChange = (sellerLoan.principalAmount * buyAmount + (sellerLoan.lastAmount - 1)) / sellerLoan.lastAmount;  //Round up

        sellerLoan.lastAmount -= buyAmount;
        sellerLoan.principalAmount -= principalChange;

        if(sellerLoan.lastAmount == 0) {
            for (uint i = 0; i < miner.lenders.length; i++) {
                if (miner.lenders[i] == seller) {
                    miner.lenders[i] = miner.lenders[miner.lenders.length - 1];
                    miner.lenders.pop();
                    delete _loans[seller][minerId];
                    break;
                }
            }
        }
        if (buyerLoan.lastAmount == 0) {
            buyerLoan.lastUpdateTime = block.timestamp;
            require(miner.lenders.length < miner.maxLenderCount, "Lenders list too long");
            miner.lenders.push(msg.sender);
        }
        buyerLoan.lastAmount += buyAmount;
        buyerLoan.principalAmount += principalChange;

        require(buyerLoan.lastAmount >= miner.minLendAmount, "buyAmount too small");

        sellItem.amountRemaining -= buyAmount;
        if (sellItem.amountRemaining == 0) {
            delete _sales[seller][minerId];
        }
        
        payable(seller).transfer(requiredPayment);
        emit EventBuyLoan(msg.sender, seller, minerId, buyAmount, sellItem.pricePerFil, principalChange);
    }

    function withdrawRepayment(address payable lender, CommonTypes.FilActorId minerId, uint amount) public returns (uint actualRepaymentAmount) {
        Miner storage miner = _miners[minerId];
        require(msg.sender == lender || msg.sender == miner.delegator, "You are not lender or delegator of the miner");

        uint owedInterest = _updateLenderOwedAmount(lender, minerId) - _loans[lender][minerId].principalAmount;
        actualRepaymentAmount = _reduceOwedAmounts(lender, minerId, amount);
        uint repaiedInterest = actualRepaymentAmount >= owedInterest ? owedInterest : actualRepaymentAmount;

        CommonTypes.BigInt memory amountBigInt = Common.uint2BigInt(actualRepaymentAmount);
        CommonTypes.BigInt memory actuallyAmountBitInt = MinerAPI.withdrawBalance(minerId, amountBigInt);
        require(actuallyAmountBitInt.neg == false, "Failed withdraw balance; actual withdraw amount is negative");
        uint withdrawnAmount = Common.bigInt2Uint(actuallyAmountBitInt);
        require(withdrawnAmount == actualRepaymentAmount, "Withdrawn amount not equal to repaid amount");

        _transferRepayment(lender, actualRepaymentAmount, repaiedInterest);

        emit EventWithdrawRepayment(msg.sender, lender, minerId, actualRepaymentAmount, repaiedInterest);
    }

    function batchWithdrawRepayment(address[] memory lenderList, CommonTypes.FilActorId[] memory minerIdList, uint[] memory amountList) external returns (uint actuallRepaymentAmount) {
        require(lenderList.length == minerIdList.length, "The lengths of lenderList and MinerIdList must be equal");
        require(lenderList.length == amountList.length, "The lengths of lenderList and amountList must be equal");
        for (uint i = 0; i < lenderList.length; i++) {
            actuallRepaymentAmount += withdrawRepayment(payable(lenderList[i]), minerIdList[i], amountList[i]);
        }
    }

    function batchWithdrawRepaymentWithTotalAmount(address[] memory lenderList, CommonTypes.FilActorId[] memory minerIdList, uint totalAmount) external returns (uint actualRepaymentAmount) {
        require(lenderList.length == minerIdList.length, "The lengths of lenderList and MinerIdList must be equal");

        uint amountRemaining = totalAmount;
        for (uint i = 0; i < lenderList.length; i++) {
            uint actualRepaid = withdrawRepayment(payable(lenderList[i]), minerIdList[i], amountRemaining);
            amountRemaining -= actualRepaid;
            actualRepaymentAmount += actualRepaid;
            if (amountRemaining == 0) break;
        }
    }

    function _directRepayment(address lender, CommonTypes.FilActorId minerId, uint amount) internal returns (uint actualRepaymentAmount) {
        uint owedInterest = _updateLenderOwedAmount(lender, minerId) - _loans[lender][minerId].principalAmount;
        actualRepaymentAmount = _reduceOwedAmounts(lender, minerId, amount);
        uint repaiedInterest = actualRepaymentAmount >= owedInterest ? owedInterest : actualRepaymentAmount;
        _transferRepayment(lender, actualRepaymentAmount, repaiedInterest);
        emit EventRepayment(msg.sender, lender, minerId, actualRepaymentAmount, repaiedInterest);
    }

    function directRepayment(address lender, CommonTypes.FilActorId minerId) external payable returns (uint actualRepaymentAmount) {
        uint messageValue = msg.value;
        actualRepaymentAmount = _directRepayment(lender, minerId, messageValue);
        payable(msg.sender).transfer(messageValue - actualRepaymentAmount);
    }

    function batchDirectRepayment(address[] memory lenderList, CommonTypes.FilActorId[] memory minerIdList, uint[] memory amountList) external payable returns (uint[] memory actualRepaymentAmounts) {
        require(lenderList.length == minerIdList.length, "The lengths of lenderList and MinerIdList must be equal");
        require(lenderList.length == amountList.length, "The lengths of lenderList and amountList must be equal");
        
        uint totalRepaid;
        actualRepaymentAmounts = new uint[](lenderList.length);
        for (uint i = 0; i < lenderList.length; i++) {
            uint actualRepaid = _directRepayment(payable(lenderList[i]), minerIdList[i], amountList[i]);
            totalRepaid += actualRepaid;
            actualRepaymentAmounts[i] = actualRepaid;
        }

        require(totalRepaid <= msg.value, "Insufficient funds provided");
        payable(msg.sender).transfer(msg.value - totalRepaid);
    }

    function batchDirectRepaymentWithTotalAmount(address[] memory lenderList, CommonTypes.FilActorId[] memory minerIdList) external payable returns (uint[] memory actualRepaymentAmounts) {
        require(lenderList.length == minerIdList.length, "The lengths of lenderList and MinerIdList must be equal");
        
        uint amountRemaining = msg.value;
        actualRepaymentAmounts = new uint[](lenderList.length);
        for (uint i = 0; i < lenderList.length; i++) {
            uint actualRepaid = _directRepayment(payable(lenderList[i]), minerIdList[i], amountRemaining);
            amountRemaining -= actualRepaid;
            actualRepaymentAmounts[i] = actualRepaid;
            if(amountRemaining == 0) break;
        }

        payable(msg.sender).transfer(amountRemaining);
    }

    function _reduceOwedAmounts(address lender, CommonTypes.FilActorId minerId, uint amount) internal returns (uint amountRepaid) {
        Loan storage loan = _loans[lender][minerId];
        Miner storage miner = _miners[minerId];

        require(loan.lastUpdateTime == block.timestamp, "the loan not update");

        if (amount < loan.lastAmount) { //Payed less than total amount owed to lender
            amountRepaid = amount;
            loan.lastAmount -= amount;
        } else {    //Payed more or equal to total debt
            amountRepaid = loan.lastAmount;
            loan.lastAmount = 0;
            
            //Delete lender from miner's lender list
            for (uint i = 0; i < miner.lenders.length; i++) {
                if (miner.lenders[i] == lender) {
                    miner.lenders[i] = miner.lenders[miner.lenders.length - 1];
                    miner.lenders.pop();
                    break;
                }
            }
        }

        //The user have payed back more than interest in this case, so all remaining debt are principal
        if (loan.lastAmount < loan.principalAmount) {
            miner.principalAmount -= (loan.principalAmount - loan.lastAmount);
            loan.principalAmount = loan.lastAmount;
        }

        if (loan.lastAmount == 0) {
            delete _loans[lender][minerId];
        }

    }

    function _increaseOwedAmounts(address lender, CommonTypes.FilActorId minerId, uint amount) internal {
        if(amount == 0) {
            return;
        }
        Loan storage loan = _loans[lender][minerId];
        Miner storage miner = _miners[minerId];

        if (loan.lastUpdateTime != 0) {
            require(loan.lastUpdateTime == block.timestamp, "loan not update");
        }

        if (loan.lastAmount == 0) {
            miner.lenders.push(lender);
        }

        miner.principalAmount += amount;
        loan.principalAmount += amount;
        loan.lastAmount += amount;
        loan.lastUpdateTime = block.timestamp;

    }

    function _updateMinerDebtAmounts(CommonTypes.FilActorId minerId) internal returns (uint currentDebtAmount) {
        address[] storage lenders = _miners[minerId].lenders;
        for (uint i = 0; i < lenders.length; i++) {
            currentDebtAmount += _updateLenderOwedAmount(lenders[i], minerId);
        }
    }

    function _updateLenderOwedAmount(address lender, CommonTypes.FilActorId minerId) public returns (uint currentOwedAmount) {
        uint blockTimestamp = block.timestamp;
        Loan storage loan = _loans[lender][minerId];
        currentOwedAmount = Common.calculatePrincipalAndInterest(loan.lastAmount, loan.lastUpdateTime, blockTimestamp, _miners[minerId].loanInterestRate, RATE_BASE);
        loan.lastAmount = currentOwedAmount;
        loan.lastUpdateTime = blockTimestamp;
    }

    function _transferRepayment(address to, uint amount, uint interestAmount) internal {
        uint commissionAmount = interestAmount * _feeRate / RATE_BASE;
        uint toUserAmount = amount - commissionAmount;
        payable(to).transfer(toUserAmount);
    }

    function getCurrentMinerOwedAmount(CommonTypes.FilActorId minerId) external view returns(uint totalDebt, uint principal) {
        Miner storage miner = _miners[minerId];
        for (uint i = 0; i < miner.lenders.length; i++) {
            (uint currentAmountOwed,) = getCurrentLenderOwedAmount(miner.lenders[i], minerId);
            totalDebt += currentAmountOwed;
        }
        principal = miner.principalAmount;
    }

    function getCurrentLenderOwedAmount(address lender, CommonTypes.FilActorId minerId) public view returns(uint totalAmountOwed, uint principal) {
        Loan storage loan = _loans[lender][minerId];
        totalAmountOwed = Common.calculatePrincipalAndInterest(loan.lastAmount, loan.lastUpdateTime, block.timestamp, _miners[minerId].loanInterestRate, RATE_BASE);
        principal = loan.principalAmount;
    }

    function getMiner(CommonTypes.FilActorId minerId) public view returns(Miner memory) {
        return _miners[minerId];
    }

    modifier onlyFoundation {
        require(msg.sender == _foundation, "Only foundation allowed");
        _;
    }

    function changeFoundation(address foundation) external onlyFoundation {
        require(foundation != address(0), "Foundation cannot be set to zero address");
        _foundation = foundation;
    }

    function changeMaxDebtRate(uint newMaxDebtRate) external onlyFoundation {
        _maxDebtRate = newMaxDebtRate;
    }

    function changeFeeRate(uint newFeeRate) external onlyFoundation {
        require(newFeeRate <= MAX_FEE_RATE, "Fee rate must less than or equal to MAX_FEE_RATE");
        _feeRate = newFeeRate;
    }

    function withdraw(address payable to, uint amount) external payable onlyFoundation {
        to.transfer(amount);
    }
}