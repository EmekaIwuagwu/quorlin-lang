# Voting Contract
# Demonstrates mappings, events, and access control

# Struct definition at top level
struct Proposal:
    """A proposal that can be voted on."""
    description: str
    vote_count: uint256
    deadline: uint256
    executed: bool

# Events at top level
event ProposalCreated:
    proposal_id: uint256
    description: str
    deadline: uint256

event Voted:
    proposal_id: uint256
    voter: address

event ProposalExecuted:
    proposal_id: uint256

contract Voting:
    """A simple voting contract for proposals."""
    
    proposals: mapping[uint256, Proposal]
    has_voted: mapping[uint256, mapping[address, bool]]
    proposal_count: uint256
    owner: address
    
    @constructor
    fn __init__():
        """Initialize voting contract."""
        self.proposal_count = 0
        self.owner = msg.sender
    
    @external
    fn create_proposal(description: str, duration: uint256) -> uint256:
        """Create a new proposal."""
        require(msg.sender == self.owner, "Only owner can create proposals")
        
        let proposal_id: uint256 = self.proposal_count
        self.proposal_count = self.proposal_count + 1
        
        let deadline: uint256 = block.timestamp + duration
        
        self.proposals[proposal_id] = Proposal(
            description: description,
            vote_count: 0,
            deadline: deadline,
            executed: false
        )
        
        emit ProposalCreated(proposal_id, description, deadline)
        
        return proposal_id
    
    @external
    fn vote(proposal_id: uint256):
        """Vote for a proposal."""
        require(proposal_id < self.proposal_count, "Invalid proposal ID")
        require(not self.has_voted[proposal_id][msg.sender], "Already voted")
        
        let proposal: Proposal = self.proposals[proposal_id]
        require(block.timestamp < proposal.deadline, "Voting period ended")
        require(not proposal.executed, "Proposal already executed")
        
        self.has_voted[proposal_id][msg.sender] = true
        proposal.vote_count = proposal.vote_count + 1
        self.proposals[proposal_id] = proposal
        
        emit Voted(proposal_id, msg.sender)
    
    @external
    fn execute_proposal(proposal_id: uint256):
        """Execute a proposal if it has enough votes."""
        require(proposal_id < self.proposal_count, "Invalid proposal ID")
        require(msg.sender == self.owner, "Only owner can execute")
        
        let proposal: Proposal = self.proposals[proposal_id]
        require(block.timestamp >= proposal.deadline, "Voting still ongoing")
        require(not proposal.executed, "Already executed")
        require(proposal.vote_count > 0, "No votes")
        
        proposal.executed = true
        self.proposals[proposal_id] = proposal
        
        emit ProposalExecuted(proposal_id)
    
    @view
    fn get_proposal(proposal_id: uint256) -> Proposal:
        """Get proposal details."""
        require(proposal_id < self.proposal_count, "Invalid proposal ID")
        return self.proposals[proposal_id]
    
    @view
    fn has_user_voted(proposal_id: uint256, user: address) -> bool:
        """Check if user has voted."""
        return self.has_voted[proposal_id][user]
