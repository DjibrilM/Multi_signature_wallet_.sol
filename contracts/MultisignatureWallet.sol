// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

//Errors
error InvalidApprovalCount();
error ExceedSignersCount();
error MiliciousInitiator();
error NoEnoughMoneyInWallet();

contract MultiSignatureWallet {
    //STRUCTS👇
    /**
     * @dev This struct describes a pending transaction within a given wallet,
     *  and one wallet can have many pending transactions
     * @param repcipient The recipient of the transaction;
     * @param from The address that initiated the transaction
     * @param amount The transaction amount
     * @param approvalCount the number of validations that have been declared
     * @param param The previous signers parameter keep track of all the people
     *              Who have contributed to the signing process, this prevent
     *              single signing loop, which consists of one signer having to
     *              sign for all the others .
     */
    struct PendingTransaction {
        address recipient;
        address from;
        uint256 amount;
        uint256 approvalCount;
        address[] previousSigners;
    }

    /**
     * @dev Signers are people that can validate a transaction.
     *       Signers within a wallet don't hold the same permission some can initiate
     *       transactions and other can't.
     * @param canInitiateTransaction This indicates the whether this singer can initiate a transaction or not.
     */
    struct Signer {
        address singerAddress;
        bool canInitiateTransaction;
    }

    /**
     * @dev This struct describes all the available parameters of a wallet.
     * @param amount The total amount of funds in the wallet.
     * @param the The locked parameter is used to lock the wallet when a withdraw
     *            is initiated, this prevents things like Reentrancy Attack
     * @param signers The list of validators allowed to sign transactions.
     * @param pendingTransaction A list of transaction IDs that haven't been validated yet.
     *        A wallet can have multiple pending transactions
     */
    struct Wallet {
        uint256 balance;
        Signer[] signers;
        PendingTransaction[] pendingTransactions;
        uint16 approvalCount;
        bool locked;
    }

    //STATE VARIABLES AND MAPPINGS👇
    address public immutable i_owner;
    uint256 public immutable i_maximum_pendingTransaction;
    uint256 public immutable i_maximum_signers;

    mapping(address => Wallet) internal s_wallets;

    //EVENTS👇

    //Event fired when a transaction is initiated
    event PendingTransactionInitiation(
        address indexed recipient,
        address indexed walletAddress,
        uint256 amount
    );
    //Fired when pending counts reached and when the funds are sent to the recipient;
    event PendingTransactionClose(
        address indexed recipient,
        address indexed walletAddress,
        address finalValidator,
        uint256 amount,
        uint256 approvalCount
    );

    //MODIFIERS
    modifier WalletAlreadyCreated(address walletAddress) {
        require(
            s_wallets[walletAddress].signers.length > 1,
            "Wallet already created"
        );
        _;
    }
    /**
     * @dev Check if the wallet exists
     * @param walletAddress  Wallet address
     */
    modifier WalletDoesNotExist(address walletAddress) {
        require(
            s_wallets[walletAddress].signers.length < 1,
            "Wllet does not exist"
        );
        _;
    }

    modifier NoReentrancy(address _walletAddress) {
        require(!s_wallets[_walletAddress].locked, "No re-entrency");
        s_wallets[_walletAddress].locked = true;
        _;
        s_wallets[_walletAddress].locked = false;
    }

    /**
     * @dev The bellow modifier checkes the the initiror is legit and if they can initiate a transaction
     * @param _signers  List of signers withing the given wallet
     * @param _inititor The transaction initiator
     */
    modifier CanInitiateTransaction(
        Signer[] memory _signers,
        address _inititor
    ) {
        Signer memory signer;
        for (uint i = 0; i < _signers.length; i++) {
            if (_signers[i].singerAddress == _inititor) {
                signer = _signers[i];
            }
        }
        if (!signer.canInitiateTransaction) {
            revert MiliciousInitiator();
        }
        _;
    }

    modifier IsValidSigner(address _walletAddress, address _signer) {
        bool isSigner;
        uint256 signersLength = s_wallets[_walletAddress].signers.length;
        for (uint i = 0; i < signersLength; i++) {
            if (s_wallets[_walletAddress].signers[i].singerAddress == _signer) {
                isSigner = true;
            }
        }

        require(isSigner, "Invalid signer");
        _;
    }

    //Constructor
    constructor(
        address _owner,
        uint256 _maximum_pendingTransaction,
        uint256 _maximum_signers
    ) {
        i_owner = _owner;
        i_maximum_pendingTransaction = _maximum_pendingTransaction;
        i_maximum_signers = _maximum_signers;
    }

    /**
     * The receive function will send back the fund to the send if they don't have a wallet yet
     */
    receive() external payable {
        require(
            s_wallets[msg.sender].signers.length < 1,
            "Don't have a wallet yet"
        );

        //Increament the balance of the sender
        s_wallets[msg.sender].balance += msg.value;
    }

    /**
     * The given function update the approval count of a pending transaction, and send
     * the funds if the count has reach the maximum number of approvals need to sign and
     * send send the funds.
     * @param _walletAddress Sender's wallet address.
     * @param _transactionIndex The transaction's index based on the given wallet.
     */
    function updateApprovalCount(
        address _walletAddress,
        uint256 _transactionIndex
    )
        external
        payable
        NoReentrancy(_walletAddress)
        IsValidSigner(_walletAddress, msg.sender)
        returns (bool suc)
    {
        PreventDoubleSigning(_walletAddress, _transactionIndex, msg.sender);

        s_wallets[_walletAddress]
            .pendingTransactions[_transactionIndex]
            .approvalCount += 1;

        s_wallets[_walletAddress]
            .pendingTransactions[_transactionIndex]
            .previousSigners
            .push(msg.sender);

        if (
            s_wallets[_walletAddress]
                .pendingTransactions[_transactionIndex]
                .approvalCount >= s_wallets[_walletAddress].approvalCount
        ) {
            address payable recipient = payable(
                s_wallets[_walletAddress]
                    .pendingTransactions[_transactionIndex]
                    .recipient
            );

            uint256 amount = s_wallets[_walletAddress]
                .pendingTransactions[_transactionIndex]
                .amount;

            (bool succ, ) = recipient.call{value: amount}("");

            require(succ, "Failed to transfer funds");

            s_wallets[_walletAddress].balance -= amount;

            //Delete the pending transaction from pending transactions list
            uint256 pendingTransactionsLength = s_wallets[_walletAddress]
                .pendingTransactions
                .length;

            if (pendingTransactionsLength == 1) {
                s_wallets[_walletAddress].pendingTransactions.pop();

                return true;
            }

            //Array Remove An Element By Shifting.
            // Resource about the implementation => https://www.youtube.com/watch?v=szv2zJcy_Xs&t=140s
            for (
                uint index = _transactionIndex;
                index < pendingTransactionsLength - 1;
                index++
            ) {
                s_wallets[_walletAddress].pendingTransactions[
                    index
                ] = s_wallets[_walletAddress].pendingTransactions[index + 1];
            }

            //Remove the last duplicate
            s_wallets[_walletAddress].pendingTransactions.pop();

            return succ;
        }

        return true;
    }

    function getWallet(
        address walletAddress
    ) public view returns (Wallet memory) {
        return s_wallets[walletAddress];
    }

    function getAmout(address walletAddress) public view returns (uint256) {
        return s_wallets[walletAddress].balance;
    }

    /**
     * @dev  The bellow function is in charge of creating a wallet
     * @param _owner Owner of the wallet or master user
     * @param _signers All the memembers that can approve a transaction
     * @param _approvalCount The total number of approval that can initiate a transaction
     */
    function createWallet(
        address _owner,
        Signer[] memory _signers,
        uint16 _approvalCount
    ) public WalletAlreadyCreated(_owner) {
        //Check if the approval counts is greater than the signers or if
        // singners are greater that the maximum singners limit.
        if (_approvalCount > _signers.length) {
            revert InvalidApprovalCount();
        } else if (_signers.length > i_maximum_signers) {
            revert ExceedSignersCount();
        }

        uint256 signersLength = _signers.length;

        s_wallets[_owner].balance = 0;
        s_wallets[_owner].approvalCount = _approvalCount;

        for (uint i = 0; i < signersLength; i++) {
            Signer memory newSigner = Signer(
                _signers[i].singerAddress,
                _signers[i].canInitiateTransaction
            );
            s_wallets[_owner].signers.push(newSigner);
        }

        //Wallet owner must also be a signer
        s_wallets[_owner].signers.push(Signer(i_owner, true));
    }

    /**
     * @param _initiator Initiator of the transaction.
     * @param _walletAddrss The given wallet address.
     * @param _amount The amount of money to be sent.
     * @param _recipient the recipient address.
     */
    function initiateTransaction(
        address _initiator,
        address _walletAddrss,
        uint256 _amount,
        address _recipient
    )
        public
        CanInitiateTransaction(s_wallets[_walletAddrss].signers, _initiator)
        WalletDoesNotExist(_walletAddrss)
        returns (bool)
    {
        if (_amount > s_wallets[_walletAddrss].balance) {
            revert NoEnoughMoneyInWallet();
        }

        PendingTransaction memory newPendingTransaction = PendingTransaction({
            amount: _amount,
            recipient: _recipient,
            from: _initiator,
            approvalCount: 0,
            previousSigners: new address[](0)
        });

        s_wallets[_walletAddrss].pendingTransactions.push(
            newPendingTransaction
        );

        return true;
    }

    function PreventDoubleSigning(
        address _wallet_address,
        uint256 _transactionIndex,
        address _signer
    ) internal view {
        address[] memory signers = s_wallets[_wallet_address]
            .pendingTransactions[_transactionIndex]
            .previousSigners;

        for (uint i = 0; i < signers.length; i++) {
            require(signers[i] != _signer, "Double signing not allowed");
        }
    }
}
