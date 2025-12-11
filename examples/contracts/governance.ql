# governance.ql — DAO Governance Contract
# Decentralized voting and proposal system

from std.math import safe_add, safe_sub, safe_mul, safe_div
from std.time import block_timestamp, block_number, add_days
from std.log import require_not_zero_address
from std.crypto import keccak256

# Structs
struct Proposal:
    id: uint256
    proposer: address
    eta: uint64  # Execution timestamp
    targets: list[address]
    values: list[uint256]
    signatures: list[str]
    calldatas: list[bytes]
    start_block: uint64
    end_block: uint64
    for_votes: uint256
    against_votes: uint256
    abstain_votes: uint256
    canceled: bool
    executed: bool
    description: str

struct Receipt:
    has_voted: bool
    support: uint8  # 0=against, 1=for, 2=abstain
    votes: uint256

struct Checkpoint:
    from_block: uint64
    votes: uint256

# Proposal states
enum ProposalState:
    Pending
    Active
    Canceled
    Defeated
    Succeeded
    Queued
    Expired
    Executed

# Events
event ProposalCreated(
    proposal_id: uint256,
    proposer: address,
    targets: list[address],
    values: list[uint256],
    signatures: list[str],
    calldatas: list[bytes],
    start_block: uint64,
    end_block: uint64,
    description: str
)
event VoteCast(voter: address, proposal_id: uint256, support: uint8, votes: uint256, reason: str)
event ProposalCanceled(proposal_id: uint256)
event ProposalQueued(proposal_id: uint256, eta: uint64)
event ProposalExecuted(proposal_id: uint256)
event DelegateChanged(delegator: address, from_delegate: address, to_delegate: address)
event DelegateVotesChanged(delegate: address, previous_balance: uint256, new_balance: uint256)

contract DAOGovernance:
    """
    Decentralized Autonomous Organization (DAO) governance contract.
    
    Features:
    - Proposal creation and voting
    - Token-weighted voting
    - Quorum requirements
    - Timelock for execution
    - Delegation support
    - Vote snapshots
    - Proposal states (Pending, Active, Defeated, Succeeded, Executed)
    - Cross-chain compatible
    """
    
    # State variables
    _governance_token: address
    _owner: address
    
    # Governance parameters
    _voting_delay: uint64  # Blocks before voting starts
    _voting_period: uint64  # Blocks for voting
    _proposal_threshold: uint256  # Minimum tokens to create proposal
    _quorum_votes: uint256  # Minimum votes for quorum
    _timelock_delay: uint64  # Seconds before execution
    
    # Proposals
    _proposal_count: uint256
    _proposals: mapping[uint256, Proposal]
    _proposal_votes: mapping[uint256, mapping[address, Receipt]]
    
    # Delegation
    _delegates: mapping[address, address]
    _checkpoints: mapping[address, mapping[uint256, Checkpoint]]
    _num_checkpoints: mapping[address, uint256]
    
    # Vote snapshots
    _vote_snapshots: mapping[uint256, mapping[address, uint256]]
    
    @constructor
    fn __init__(
        governance_token: address,
        voting_delay_blocks: uint64,
        voting_period_blocks: uint64,
        proposal_threshold: uint256,
        quorum_percentage: uint256
    ):
        """
        Initialize the governance contract.
        
        Args:
            governance_token: Token used for voting power
            voting_delay_blocks: Delay before voting starts
            voting_period_blocks: Duration of voting period
            proposal_threshold: Minimum tokens to create proposal
            quorum_percentage: Percentage of total supply for quorum (basis points)
        """
        require_not_zero_address(governance_token, "Invalid token")
        require(voting_period_blocks > 0, "Invalid voting period")
        require(quorum_percentage <= 10000, "Invalid quorum percentage")
        
        self._governance_token = governance_token
        self._owner = msg.sender
        self._voting_delay = voting_delay_blocks
        self._voting_period = voting_period_blocks
        self._proposal_threshold = proposal_threshold
        self._quorum_votes = 0  # Will be calculated based on total supply
        self._timelock_delay = 172800  # 2 days in seconds
        self._proposal_count = 0
    
    # ========== View Functions ==========
    
    @view
    fn get_proposal(proposal_id: uint256) -> Proposal:
        """Returns proposal details."""
        require(proposal_id < self._proposal_count, "Proposal does not exist")
        return self._proposals[proposal_id]
    
    @view
    fn state(proposal_id: uint256) -> ProposalState:
        """
        Returns the current state of a proposal.
        
        Args:
            proposal_id: Proposal ID
        
        Returns:
            Current proposal state
        """
        require(proposal_id < self._proposal_count, "Proposal does not exist")
        proposal: Proposal = self._proposals[proposal_id]
        
        if proposal.canceled:
            return ProposalState.Canceled
        
        if proposal.executed:
            return ProposalState.Executed
        
        current_block: uint64 = block_number()
        
        if current_block <= proposal.start_block:
            return ProposalState.Pending
        
        if current_block <= proposal.end_block:
            return ProposalState.Active
        
        if proposal.for_votes <= proposal.against_votes or proposal.for_votes < self._quorum_votes:
            return ProposalState.Defeated
        
        if proposal.eta == 0:
            return ProposalState.Succeeded
        
        if block_timestamp() >= proposal.eta + 604800:  # 7 days grace period
            return ProposalState.Expired
        
        return ProposalState.Queued
    
    @view
    fn get_votes(account: address) -> uint256:
        """
        Returns current voting power of an account.
        
        Args:
            account: Address to query
        
        Returns:
            Voting power
        """
        num_checkpoints: uint256 = self._num_checkpoints[account]
        if num_checkpoints == 0:
            return 0
        return self._checkpoints[account][num_checkpoints - 1].votes
    
    @view
    fn get_prior_votes(account: address, block_num: uint64) -> uint256:
        """
        Returns voting power at a specific block.
        
        Args:
            account: Address to query
            block_num: Block number
        
        Returns:
            Historical voting power
        """
        require(block_num < block_number(), "Not yet determined")
        
        num_checkpoints: uint256 = self._num_checkpoints[account]
        if num_checkpoints == 0:
            return 0
        
        # Binary search for checkpoint
        if self._checkpoints[account][num_checkpoints - 1].from_block <= block_num:
            return self._checkpoints[account][num_checkpoints - 1].votes
        
        if self._checkpoints[account][0].from_block > block_num:
            return 0
        
        lower: uint256 = 0
        upper: uint256 = num_checkpoints - 1
        
        while upper > lower:
            center: uint256 = upper - (upper - lower) / 2
            checkpoint: Checkpoint = self._checkpoints[account][center]
            
            if checkpoint.from_block == block_num:
                return checkpoint.votes
            elif checkpoint.from_block < block_num:
                lower = center
            else:
                upper = center - 1
        
        return self._checkpoints[account][lower].votes
    
    @view
    fn get_receipt(proposal_id: uint256, voter: address) -> Receipt:
        """Returns vote receipt for a voter."""
        return self._proposal_votes[proposal_id][voter]
    
    # ========== Proposal Functions ==========
    
    @external
    fn propose(
        targets: list[address],
        values: list[uint256],
        signatures: list[str],
        calldatas: list[bytes],
        description: str
    ) -> uint256:
        """
        Creates a new proposal.
        
        Args:
            targets: Target contract addresses
            values: ETH values to send
            signatures: Function signatures
            calldatas: Function call data
            description: Proposal description
        
        Returns:
            Proposal ID
        """
        require(
            self.get_prior_votes(msg.sender, block_number() - 1) >= self._proposal_threshold,
            "Proposer votes below threshold"
        )
        require(
            targets.len() == values.len() and
            targets.len() == signatures.len() and
            targets.len() == calldatas.len(),
            "Proposal function information mismatch"
        )
        require(targets.len() > 0, "Must provide actions")
        require(targets.len() <= 10, "Too many actions")
        
        proposal_id: uint256 = self._proposal_count
        self._proposal_count = safe_add(self._proposal_count, 1)
        
        start_block: uint64 = block_number() + self._voting_delay
        end_block: uint64 = start_block + self._voting_period
        
        self._proposals[proposal_id] = Proposal(
            id=proposal_id,
            proposer=msg.sender,
            eta=0,
            targets=targets,
            values=values,
            signatures=signatures,
            calldatas=calldatas,
            start_block=start_block,
            end_block=end_block,
            for_votes=0,
            against_votes=0,
            abstain_votes=0,
            canceled=False,
            executed=False,
            description=description
        )
        
        emit ProposalCreated(
            proposal_id,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            start_block,
            end_block,
            description
        )
        
        return proposal_id
    
    @external
    fn cast_vote(proposal_id: uint256, support: uint8):
        """
        Casts a vote on a proposal.
        
        Args:
            proposal_id: Proposal ID
            support: 0=against, 1=for, 2=abstain
        """
        self._cast_vote_internal(msg.sender, proposal_id, support, "")
    
    @external
    fn cast_vote_with_reason(proposal_id: uint256, support: uint8, reason: str):
        """
        Casts a vote with a reason.
        
        Args:
            proposal_id: Proposal ID
            support: 0=against, 1=for, 2=abstain
            reason: Reason for vote
        """
        self._cast_vote_internal(msg.sender, proposal_id, support, reason)
    
    @external
    fn queue(proposal_id: uint256):
        """
        Queues a succeeded proposal for execution.
        
        Args:
            proposal_id: Proposal ID
        """
        require(
            self.state(proposal_id) == ProposalState.Succeeded,
            "Proposal can only be queued if succeeded"
        )
        
        proposal: Proposal = self._proposals[proposal_id]
        eta: uint64 = block_timestamp() + self._timelock_delay
        proposal.eta = eta
        self._proposals[proposal_id] = proposal
        
        emit ProposalQueued(proposal_id, eta)
    
    @external
    fn execute(proposal_id: uint256):
        """
        Executes a queued proposal.
        
        Args:
            proposal_id: Proposal ID
        """
        require(
            self.state(proposal_id) == ProposalState.Queued,
            "Proposal can only be executed if queued"
        )
        
        proposal: Proposal = self._proposals[proposal_id]
        require(block_timestamp() >= proposal.eta, "Proposal hasn't surpassed timelock")
        
        proposal.executed = True
        self._proposals[proposal_id] = proposal
        
        # Execute all actions
        for i in range(proposal.targets.len()):
            self._execute_transaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i]
            )
        
        emit ProposalExecuted(proposal_id)
    
    @external
    fn cancel(proposal_id: uint256):
        """
        Cancels a proposal (proposer or owner only).
        
        Args:
            proposal_id: Proposal ID
        """
        proposal: Proposal = self._proposals[proposal_id]
        require(
            msg.sender == proposal.proposer or msg.sender == self._owner,
            "Only proposer or owner can cancel"
        )
        require(
            self.state(proposal_id) != ProposalState.Executed,
            "Cannot cancel executed proposal"
        )
        
        proposal.canceled = True
        self._proposals[proposal_id] = proposal
        
        emit ProposalCanceled(proposal_id)
    
    # ========== Delegation Functions ==========
    
    @external
    fn delegate(delegatee: address):
        """
        Delegates voting power to another address.
        
        Args:
            delegatee: Address to delegate to
        """
        self._delegate(msg.sender, delegatee)
    
    # ========== Admin Functions ==========
    
    @external
    fn set_voting_delay(new_delay: uint64):
        """Updates voting delay (owner only)."""
        self._only_owner()
        self._voting_delay = new_delay
    
    @external
    fn set_voting_period(new_period: uint64):
        """Updates voting period (owner only)."""
        self._only_owner()
        require(new_period > 0, "Invalid voting period")
        self._voting_period = new_period
    
    @external
    fn set_proposal_threshold(new_threshold: uint256):
        """Updates proposal threshold (owner only)."""
        self._only_owner()
        self._proposal_threshold = new_threshold
    
    @external
    fn set_quorum_votes(new_quorum: uint256):
        """Updates quorum requirement (owner only)."""
        self._only_owner()
        self._quorum_votes = new_quorum
    
    # ========== Internal Functions ==========
    
    fn _cast_vote_internal(voter: address, proposal_id: uint256, support: uint8, reason: str):
        """Internal vote casting logic."""
        require(self.state(proposal_id) == ProposalState.Active, "Voting is closed")
        require(support <= 2, "Invalid vote type")
        
        receipt: Receipt = self._proposal_votes[proposal_id][voter]
        require(not receipt.has_voted, "Already voted")
        
        proposal: Proposal = self._proposals[proposal_id]
        votes: uint256 = self.get_prior_votes(voter, proposal.start_block)
        
        if support == 0:
            proposal.against_votes = safe_add(proposal.against_votes, votes)
        elif support == 1:
            proposal.for_votes = safe_add(proposal.for_votes, votes)
        else:
            proposal.abstain_votes = safe_add(proposal.abstain_votes, votes)
        
        self._proposals[proposal_id] = proposal
        
        self._proposal_votes[proposal_id][voter] = Receipt(
            has_voted=True,
            support=support,
            votes=votes
        )
        
        emit VoteCast(voter, proposal_id, support, votes, reason)
    
    fn _delegate(delegator: address, delegatee: address):
        """Internal delegation logic."""
        current_delegate: address = self._delegates[delegator]
        votes: uint256 = self._balance_of(self._governance_token, delegator)
        
        self._delegates[delegator] = delegatee
        
        emit DelegateChanged(delegator, current_delegate, delegatee)
        
        self._move_delegates(current_delegate, delegatee, votes)
    
    fn _move_delegates(src_rep: address, dst_rep: address, amount: uint256):
        """Moves delegated votes."""
        if src_rep != dst_rep and amount > 0:
            if src_rep != address(0):
                src_old: uint256 = self.get_votes(src_rep)
                src_new: uint256 = safe_sub(src_old, amount)
                self._write_checkpoint(src_rep, src_new)
                emit DelegateVotesChanged(src_rep, src_old, src_new)
            
            if dst_rep != address(0):
                dst_old: uint256 = self.get_votes(dst_rep)
                dst_new: uint256 = safe_add(dst_old, amount)
                self._write_checkpoint(dst_rep, dst_new)
                emit DelegateVotesChanged(dst_rep, dst_old, dst_new)
    
    fn _write_checkpoint(delegatee: address, new_votes: uint256):
        """Writes a new checkpoint."""
        num: uint256 = self._num_checkpoints[delegatee]
        
        if num > 0 and self._checkpoints[delegatee][num - 1].from_block == block_number():
            self._checkpoints[delegatee][num - 1].votes = new_votes
        else:
            self._checkpoints[delegatee][num] = Checkpoint(
                from_block=block_number(),
                votes=new_votes
            )
            self._num_checkpoints[delegatee] = safe_add(num, 1)
    
    fn _execute_transaction(target: address, value: uint256, signature: str, data: bytes):
        """Executes a proposal action."""
        # Compiler intrinsic - backend implements call
        pass
    
    fn _only_owner():
        """Modifier: requires caller to be owner."""
        require(msg.sender == self._owner, "Caller is not the owner")
    
    # Compiler intrinsics
    fn _balance_of(token: address, account: address) -> uint256:
        """Returns token balance."""
        pass
