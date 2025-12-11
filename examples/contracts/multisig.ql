# multisig.ql — Multi-Signature Wallet Contract
# Requires M-of-N confirmations for executing transactions

from std.math import safe_add, safe_sub
from std.log import require_not_zero_address

# Transaction struct
struct Transaction:
    to: address
    value: uint256
    data: bytes
    executed: bool
    num_confirmations: uint256

# Events
event OwnerAdded(owner: address)
event OwnerRemoved(owner: address)
event RequirementChanged(required_confirmations: uint256)
event TransactionSubmitted(tx_id: uint256, sender: address, to: address, value: uint256, data: bytes)
event TransactionConfirmed(tx_id: uint256, owner: address)
event ConfirmationRevoked(tx_id: uint256, owner: address)
event TransactionExecuted(tx_id: uint256)
event TransactionFailed(tx_id: uint256)
event Deposit(sender: address, amount: uint256, balance: uint256)

contract MultiSigWallet:
    """
    Multi-signature wallet requiring M-of-N owner confirmations.
    
    Features:
    - Multiple owners with configurable confirmation threshold
    - Submit, confirm, revoke, and execute transactions
    - Support for ETH/native token transfers and contract calls
    - Owner management (add/remove owners, change threshold)
    - Cross-chain compatible
    """
    
    # State variables
    _owners: list[address]
    _required_confirmations: uint256
    _transaction_count: uint256
    
    # Mappings
    _is_owner: mapping[address, bool]
    _transactions: mapping[uint256, Transaction]
    _confirmations: mapping[uint256, mapping[address, bool]]
    _confirmation_count: mapping[uint256, uint256]
    
    @constructor
    fn __init__(owners: list[address], required: uint256):
        """
        Initialize the multisig wallet.
        
        Args:
            owners: List of initial owner addresses
            required: Number of required confirmations (M-of-N)
        """
        require(owners.len() > 0, "Owners required")
        require(required > 0, "Invalid required confirmations")
        require(required <= owners.len(), "Required exceeds owner count")
        
        # Validate and add owners
        for owner in owners:
            require_not_zero_address(owner, "Invalid owner address")
            require(not self._is_owner[owner], "Duplicate owner")
            
            self._is_owner[owner] = True
            self._owners.push(owner)
            emit OwnerAdded(owner)
        
        self._required_confirmations = required
        self._transaction_count = 0
    
    # ========== Receive Function ==========
    
    @payable
    @external
    fn receive():
        """Allows the contract to receive native tokens."""
        emit Deposit(msg.sender, msg.value, address(this).balance)
    
    # ========== View Functions ==========
    
    @view
    fn get_owners() -> list[address]:
        """Returns the list of owners."""
        return self._owners
    
    @view
    fn get_required_confirmations() -> uint256:
        """Returns the number of required confirmations."""
        return self._required_confirmations
    
    @view
    fn get_transaction_count() -> uint256:
        """Returns the total number of transactions."""
        return self._transaction_count
    
    @view
    fn get_transaction(tx_id: uint256) -> Transaction:
        """
        Returns transaction details.
        
        Args:
            tx_id: Transaction ID
        
        Returns:
            Transaction struct
        """
        require(tx_id < self._transaction_count, "Transaction does not exist")
        return self._transactions[tx_id]
    
    @view
    fn is_confirmed(tx_id: uint256, owner: address) -> bool:
        """
        Checks if an owner has confirmed a transaction.
        
        Args:
            tx_id: Transaction ID
            owner: Owner address
        
        Returns:
            True if confirmed
        """
        return self._confirmations[tx_id][owner]
    
    @view
    fn get_confirmation_count(tx_id: uint256) -> uint256:
        """
        Returns the number of confirmations for a transaction.
        
        Args:
            tx_id: Transaction ID
        
        Returns:
            Confirmation count
        """
        return self._confirmation_count[tx_id]
    
    @view
    fn is_owner(addr: address) -> bool:
        """
        Checks if an address is an owner.
        
        Args:
            addr: Address to check
        
        Returns:
            True if address is an owner
        """
        return self._is_owner[addr]
    
    # ========== Transaction Management ==========
    
    @external
    fn submit_transaction(to: address, value: uint256, data: bytes) -> uint256:
        """
        Submits a new transaction for confirmation.
        
        Args:
            to: Destination address
            value: Amount of native tokens to send
            data: Transaction data (for contract calls)
        
        Returns:
            Transaction ID
        """
        self._only_owner()
        
        tx_id: uint256 = self._transaction_count
        self._transaction_count = safe_add(self._transaction_count, 1)
        
        self._transactions[tx_id] = Transaction(
            to=to,
            value=value,
            data=data,
            executed=False,
            num_confirmations=0
        )
        
        emit TransactionSubmitted(tx_id, msg.sender, to, value, data)
        
        # Auto-confirm by submitter
        self.confirm_transaction(tx_id)
        
        return tx_id
    
    @external
    fn confirm_transaction(tx_id: uint256):
        """
        Confirms a transaction.
        
        Args:
            tx_id: Transaction ID to confirm
        """
        self._only_owner()
        require(tx_id < self._transaction_count, "Transaction does not exist")
        require(not self._confirmations[tx_id][msg.sender], "Already confirmed")
        
        tx: Transaction = self._transactions[tx_id]
        require(not tx.executed, "Transaction already executed")
        
        self._confirmations[tx_id][msg.sender] = True
        self._confirmation_count[tx_id] = safe_add(self._confirmation_count[tx_id], 1)
        
        emit TransactionConfirmed(tx_id, msg.sender)
        
        # Auto-execute if threshold reached
        if self._confirmation_count[tx_id] >= self._required_confirmations:
            self.execute_transaction(tx_id)
    
    @external
    fn revoke_confirmation(tx_id: uint256):
        """
        Revokes a confirmation.
        
        Args:
            tx_id: Transaction ID
        """
        self._only_owner()
        require(tx_id < self._transaction_count, "Transaction does not exist")
        require(self._confirmations[tx_id][msg.sender], "Not confirmed")
        
        tx: Transaction = self._transactions[tx_id]
        require(not tx.executed, "Transaction already executed")
        
        self._confirmations[tx_id][msg.sender] = False
        self._confirmation_count[tx_id] = safe_sub(self._confirmation_count[tx_id], 1)
        
        emit ConfirmationRevoked(tx_id, msg.sender)
    
    @external
    fn execute_transaction(tx_id: uint256):
        """
        Executes a confirmed transaction.
        
        Args:
            tx_id: Transaction ID to execute
        """
        self._only_owner()
        require(tx_id < self._transaction_count, "Transaction does not exist")
        
        tx: Transaction = self._transactions[tx_id]
        require(not tx.executed, "Transaction already executed")
        require(self._confirmation_count[tx_id] >= self._required_confirmations,
                "Insufficient confirmations")
        
        # Mark as executed
        tx.executed = True
        self._transactions[tx_id] = tx
        
        # Execute the call
        success: bool = self._execute_call(tx.to, tx.value, tx.data)
        
        if success:
            emit TransactionExecuted(tx_id)
        else:
            # Revert execution status on failure
            tx.executed = False
            self._transactions[tx_id] = tx
            emit TransactionFailed(tx_id)
            revert("Transaction execution failed")
    
    # ========== Owner Management ==========
    
    @external
    fn add_owner(owner: address):
        """
        Adds a new owner (requires multisig confirmation via transaction).
        
        Args:
            owner: New owner address
        """
        # This function should only be called via executeTransaction
        # to ensure multisig approval
        require(msg.sender == address(this), "Must be called via multisig")
        require_not_zero_address(owner, "Invalid owner address")
        require(not self._is_owner[owner], "Already an owner")
        
        self._is_owner[owner] = True
        self._owners.push(owner)
        
        emit OwnerAdded(owner)
    
    @external
    fn remove_owner(owner: address):
        """
        Removes an owner (requires multisig confirmation via transaction).
        
        Args:
            owner: Owner address to remove
        """
        require(msg.sender == address(this), "Must be called via multisig")
        require(self._is_owner[owner], "Not an owner")
        require(self._owners.len() - 1 >= self._required_confirmations,
                "Would break required confirmations")
        
        self._is_owner[owner] = False
        
        # Remove from owners list
        new_owners: list[address] = []
        for existing_owner in self._owners:
            if existing_owner != owner:
                new_owners.push(existing_owner)
        self._owners = new_owners
        
        emit OwnerRemoved(owner)
    
    @external
    fn change_requirement(required: uint256):
        """
        Changes the required confirmation count (requires multisig confirmation).
        
        Args:
            required: New required confirmation count
        """
        require(msg.sender == address(this), "Must be called via multisig")
        require(required > 0, "Invalid required confirmations")
        require(required <= self._owners.len(), "Required exceeds owner count")
        
        self._required_confirmations = required
        
        emit RequirementChanged(required)
    
    # ========== Internal Functions ==========
    
    fn _execute_call(to: address, value: uint256, data: bytes) -> bool:
        """
        Executes a low-level call.
        
        Args:
            to: Destination address
            value: Native token amount
            data: Call data
        
        Returns:
            True if call succeeded
        """
        # This is a compiler intrinsic that backends implement
        # EVM: Uses CALL opcode
        # Solana: Uses invoke/invoke_signed
        # Polkadot: Uses env().invoke_contract
        # Others: Backend-specific call mechanism
        pass
    
    fn _only_owner():
        """Modifier: requires caller to be an owner."""
        require(self._is_owner[msg.sender], "Not an owner")
    
    # ========== Utility Functions ==========
    
    @view
    fn get_pending_transactions() -> list[uint256]:
        """
        Returns IDs of pending (unexecuted) transactions.
        
        Returns:
            List of transaction IDs
        """
        pending: list[uint256] = []
        
        for i in range(self._transaction_count):
            tx: Transaction = self._transactions[i]
            if not tx.executed:
                pending.push(i)
        
        return pending
    
    @view
    fn get_executable_transactions() -> list[uint256]:
        """
        Returns IDs of transactions ready to execute.
        
        Returns:
            List of transaction IDs
        """
        executable: list[uint256] = []
        
        for i in range(self._transaction_count):
            tx: Transaction = self._transactions[i]
            if not tx.executed and self._confirmation_count[i] >= self._required_confirmations:
                executable.push(i)
        
        return executable
