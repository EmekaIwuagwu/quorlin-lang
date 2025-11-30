# governance.ql — A DAO governance contract in Quorlin

from std.math import safe_add, safe_sub
from std.access import AccessControl

# Events
event ProposalCreated(proposal_id: uint256, proposer: address, description: str)
event VoteCast(voter: address, proposal_id: uint256, support: bool, votes: uint256)
event ProposalExecuted(proposal_id: uint256)

contract Governance(AccessControl):
    """
    Decentralized Autonomous Organization (DAO) governance contract.
    Allows token holders to create and vote on proposals.
    """

    # Constants
    PROPOSER_ROLE: bytes32 = 0x01
    EXECUTOR_ROLE: bytes32 = 0x02

    # Proposal states
    PENDING: uint8 = 0
    ACTIVE: uint8 = 1
    DEFEATED: uint8 = 2
    SUCCEEDED: uint8 = 3
    EXECUTED: uint8 = 4

    # Governance parameters
    voting_delay: uint256 = 1  # blocks
    voting_period: uint256 = 100  # blocks
    quorum_votes: uint256 = 1000  # minimum votes needed

    # State
    proposal_count: uint256
    proposals: mapping[uint256, Proposal]
    votes: mapping[uint256, mapping[address, Receipt]]
    voting_power: mapping[address, uint256]

    struct Proposal:
        id: uint256
        proposer: address
        description: str
        start_block: uint256
        end_block: uint256
        for_votes: uint256
        against_votes: uint256
        executed: bool
        state: uint8

    struct Receipt:
        has_voted: bool
        support: bool
        votes: uint256

    @constructor
    fn __init__():
        """Initialize governance contract."""
        AccessControl.__init__()
        self.proposal_count = 0

    # View functions
    @view
    fn get_proposal(proposal_id: uint256) -> Proposal:
        """Get proposal details."""
        require(proposal_id < self.proposal_count, "Governance: invalid proposal")
        return self.proposals[proposal_id]

    @view
    fn get_voting_power(account: address) -> uint256:
        """Get voting power of an account."""
        return self.voting_power[account]

    @view
    fn has_voted(proposal_id: uint256, voter: address) -> bool:
        """Check if address has voted on proposal."""
        return self.votes[proposal_id][voter].has_voted

    @view
    fn proposal_state(proposal_id: uint256) -> uint8:
        """Get current state of a proposal."""
        require(proposal_id < self.proposal_count, "Governance: invalid proposal")

        proposal: Proposal = self.proposals[proposal_id]

        if proposal.executed:
            return self.EXECUTED

        current_block: uint256 = block.number

        if current_block <= proposal.start_block:
            return self.PENDING
        elif current_block <= proposal.end_block:
            return self.ACTIVE
        elif proposal.for_votes <= proposal.against_votes or proposal.for_votes < self.quorum_votes:
            return self.DEFEATED
        else:
            return self.SUCCEEDED

    # External functions
    @external
    fn propose(description: str) -> uint256:
        """Create a new proposal."""
        self._check_role(self.PROPOSER_ROLE)

        proposal_id: uint256 = self.proposal_count
        current_block: uint256 = block.number

        self.proposals[proposal_id] = Proposal(
            id=proposal_id,
            proposer=msg.sender,
            description=description,
            start_block=current_block + self.voting_delay,
            end_block=current_block + self.voting_delay + self.voting_period,
            for_votes=0,
            against_votes=0,
            executed=False,
            state=self.PENDING
        )

        self.proposal_count = safe_add(self.proposal_count, 1)

        emit ProposalCreated(proposal_id, msg.sender, description)
        return proposal_id

    @external
    fn cast_vote(proposal_id: uint256, support: bool):
        """Cast a vote on a proposal."""
        require(proposal_id < self.proposal_count, "Governance: invalid proposal")
        require(self.proposal_state(proposal_id) == self.ACTIVE, "Governance: voting is closed")

        receipt: Receipt = self.votes[proposal_id][msg.sender]
        require(not receipt.has_voted, "Governance: already voted")

        votes: uint256 = self.voting_power[msg.sender]
        require(votes > 0, "Governance: no voting power")

        proposal: Proposal = self.proposals[proposal_id]

        if support:
            proposal.for_votes = safe_add(proposal.for_votes, votes)
        else:
            proposal.against_votes = safe_add(proposal.against_votes, votes)

        self.proposals[proposal_id] = proposal

        self.votes[proposal_id][msg.sender] = Receipt(
            has_voted=True,
            support=support,
            votes=votes
        )

        emit VoteCast(msg.sender, proposal_id, support, votes)

    @external
    fn execute(proposal_id: uint256):
        """Execute a successful proposal."""
        self._check_role(self.EXECUTOR_ROLE)
        require(proposal_id < self.proposal_count, "Governance: invalid proposal")
        require(self.proposal_state(proposal_id) == self.SUCCEEDED, "Governance: proposal not succeeded")

        proposal: Proposal = self.proposals[proposal_id]
        require(not proposal.executed, "Governance: already executed")

        proposal.executed = True
        proposal.state = self.EXECUTED
        self.proposals[proposal_id] = proposal

        # Execute proposal logic here
        # ...

        emit ProposalExecuted(proposal_id)

    @external
    fn delegate_votes(delegatee: address, amount: uint256):
        """Delegate voting power to another address."""
        require(self.voting_power[msg.sender] >= amount, "Governance: insufficient voting power")

        self.voting_power[msg.sender] = safe_sub(self.voting_power[msg.sender], amount)
        self.voting_power[delegatee] = safe_add(self.voting_power[delegatee], amount)

    @external
    fn set_voting_period(new_period: uint256):
        """Update voting period (admin only)."""
        self._check_role(self.DEFAULT_ADMIN_ROLE)
        self.voting_period = new_period

    @external
    fn set_quorum(new_quorum: uint256):
        """Update quorum requirement (admin only)."""
        self._check_role(self.DEFAULT_ADMIN_ROLE)
        self.quorum_votes = new_quorum
