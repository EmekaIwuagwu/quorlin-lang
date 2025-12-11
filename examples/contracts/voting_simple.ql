# Simple Voting Contract
# Basic voting system without stdlib dependencies

event ProposalCreated(proposal_id: uint256, description: str, creator: address)
event Voted(proposal_id: uint256, voter: address, vote: bool)
event ProposalExecuted(proposal_id: uint256)

contract SimpleVoting:
    """
    Simple voting/governance contract.
    Allows creating proposals and voting on them.
    """
    
    # State variables
    _owner: address
    _proposal_count: uint256
    _voting_period: uint256
    
    # Proposal tracking
    _proposal_descriptions: mapping[uint256, str]
    _proposal_yes_votes: mapping[uint256, uint256]
    _proposal_no_votes: mapping[uint256, uint256]
    _proposal_executed: mapping[uint256, bool]
    
    # Voter tracking
    _has_voted: mapping[uint256, mapping[address, bool]]
    _voter_weights: mapping[address, uint256]
    
    @constructor
    fn __init__(voting_period: uint256):
        """Initialize the voting contract."""
        self._owner = msg.sender
        self._proposal_count = 0
        self._voting_period = voting_period
        self._voter_weights[msg.sender] = 100
    
    @view
    fn get_proposal_count() -> uint256:
        """Returns total number of proposals."""
        return self._proposal_count
    
    @view
    fn get_proposal_votes(proposal_id: uint256) -> (uint256, uint256):
        """Returns yes and no votes for a proposal."""
        return (self._proposal_yes_votes[proposal_id], self._proposal_no_votes[proposal_id])
    
    @view
    fn has_voted(proposal_id: uint256, voter: address) -> bool:
        """Check if address has voted on proposal."""
        return self._has_voted[proposal_id][voter]
    
    @view
    fn get_voter_weight(voter: address) -> uint256:
        """Returns voting weight of an address."""
        return self._voter_weights[voter]
    
    @external
    fn create_proposal(description: str):
        """Create a new proposal."""
        require(self._voter_weights[msg.sender] > 0, "Insufficient balance")
        
        proposal_id: uint256 = self._proposal_count
        self._proposal_count = self._proposal_count + 1
        
        self._proposal_descriptions[proposal_id] = description
        self._proposal_yes_votes[proposal_id] = 0
        self._proposal_no_votes[proposal_id] = 0
        self._proposal_executed[proposal_id] = false
        
        emit ProposalCreated(proposal_id, description, msg.sender)
    
    @external
    fn vote(proposal_id: uint256, support: bool):
        """Vote on a proposal."""
        require(proposal_id < self._proposal_count, "Insufficient balance")
        require(self._has_voted[proposal_id][msg.sender] == false, "Insufficient allowance")
        require(self._voter_weights[msg.sender] > 0, "Insufficient balance")
        require(self._proposal_executed[proposal_id] == false, "Insufficient balance")
        
        voter_weight: uint256 = self._voter_weights[msg.sender]
        
        self._has_voted[proposal_id][msg.sender] = true
        
        if support:
            self._proposal_yes_votes[proposal_id] = self._proposal_yes_votes[proposal_id] + voter_weight
        else:
            self._proposal_no_votes[proposal_id] = self._proposal_no_votes[proposal_id] + voter_weight
        
        emit Voted(proposal_id, msg.sender, support)
    
    @external
    fn execute_proposal(proposal_id: uint256):
        """Execute a passed proposal (owner only)."""
        require(msg.sender == self._owner, "Insufficient allowance")
        require(proposal_id < self._proposal_count, "Insufficient balance")
        require(self._proposal_executed[proposal_id] == false, "Insufficient balance")
        require(self._proposal_yes_votes[proposal_id] > self._proposal_no_votes[proposal_id], "Insufficient balance")
        
        self._proposal_executed[proposal_id] = true
        emit ProposalExecuted(proposal_id)
    
    @external
    fn set_voter_weight(voter: address, weight: uint256):
        """Set voting weight for an address (owner only)."""
        require(msg.sender == self._owner, "Insufficient allowance")
        require(voter != address(0), "Cannot send to zero address")
        
        self._voter_weights[voter] = weight
