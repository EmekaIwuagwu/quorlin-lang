module 0x1::quorlin_contract {
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_std::table::Table;

    /// Contract: SimpleVoting
    struct SimpleVoting has key {
        owner: address,
        proposal_count: u256,
        voting_period: u256,
        proposal_descriptions: Table<u256, String>,
        proposal_yes_votes: Table<u256, u256>,
        proposal_no_votes: Table<u256, u256>,
        proposal_executed: Table<u256, bool>,
        has_voted: Table<u256, Table<address, bool>>,
        voter_weights: Table<address, u256>,
    }

    /// Initialize the SimpleVoting contract
    public entry fun initialize(account: &signer) {
        let contract = SimpleVoting {
            owner: @0x0,
            proposal_count: 0,
            voting_period: 0,
            proposal_descriptions: table::new(),
            proposal_yes_votes: table::new(),
            proposal_no_votes: table::new(),
            proposal_executed: table::new(),
            has_voted: table::new(),
            voter_weights: table::new(),
        };
        move_to(account, contract);
    }

    fun __init__(contract: &mut SimpleVoting, voting_period: u256) {
        contract.owner = msg.sender;
        contract.proposal_count = 0;
        contract.voting_period = voting_period;
        *vector::borrow(&contract.voter_weights, msg.sender) = 100;
    }

    fun get_proposal_count(contract: &mut SimpleVoting): u256 {
        contract.proposal_count
    }

    fun get_proposal_votes(contract: &mut SimpleVoting, proposal_id: u256): (u256, u256) {
        (*vector::borrow(&contract.proposal_yes_votes, proposal_id), *vector::borrow(&contract.proposal_no_votes, proposal_id))
    }

    fun has_voted(contract: &mut SimpleVoting, proposal_id: u256, voter: address): bool {
        *vector::borrow(&*vector::borrow(&contract.has_voted, proposal_id), voter)
    }

    fun get_voter_weight(contract: &mut SimpleVoting, voter: address): u256 {
        *vector::borrow(&contract.voter_weights, voter)
    }

    public entry fun create_proposal(account: &signer, description: String) {
        let contract = borrow_global_mut<SimpleVoting>(signer::address_of(account));
        assert!((*vector::borrow(&contract.voter_weights, msg.sender) > 0), Insufficient balance);
        proposal_id = contract.proposal_count;
        contract.proposal_count = (contract.proposal_count + 1);
        *vector::borrow(&contract.proposal_descriptions, proposal_id) = description;
        *vector::borrow(&contract.proposal_yes_votes, proposal_id) = 0;
        *vector::borrow(&contract.proposal_no_votes, proposal_id) = 0;
        *vector::borrow(&contract.proposal_executed, proposal_id) = false;
        // Unsupported statement
    }

    public entry fun vote(account: &signer, proposal_id: u256, support: bool) {
        let contract = borrow_global_mut<SimpleVoting>(signer::address_of(account));
        assert!((proposal_id < contract.proposal_count), Insufficient balance);
        assert!((*vector::borrow(&*vector::borrow(&contract.has_voted, proposal_id), msg.sender) == false), Insufficient allowance);
        assert!((*vector::borrow(&contract.voter_weights, msg.sender) > 0), Insufficient balance);
        assert!((*vector::borrow(&contract.proposal_executed, proposal_id) == false), Insufficient balance);
        voter_weight = *vector::borrow(&contract.voter_weights, msg.sender);
        *vector::borrow(&*vector::borrow(&contract.has_voted, proposal_id), msg.sender) = true;
        if (support) {
            *vector::borrow(&contract.proposal_yes_votes, proposal_id) = (*vector::borrow(&contract.proposal_yes_votes, proposal_id) + voter_weight);
        } else {
            *vector::borrow(&contract.proposal_no_votes, proposal_id) = (*vector::borrow(&contract.proposal_no_votes, proposal_id) + voter_weight);
        }
        // Unsupported statement
    }

    public entry fun execute_proposal(account: &signer, proposal_id: u256) {
        let contract = borrow_global_mut<SimpleVoting>(signer::address_of(account));
        assert!((msg.sender == contract.owner), Insufficient allowance);
        assert!((proposal_id < contract.proposal_count), Insufficient balance);
        assert!((*vector::borrow(&contract.proposal_executed, proposal_id) == false), Insufficient balance);
        assert!((*vector::borrow(&contract.proposal_yes_votes, proposal_id) > *vector::borrow(&contract.proposal_no_votes, proposal_id)), Insufficient balance);
        *vector::borrow(&contract.proposal_executed, proposal_id) = true;
        // Unsupported statement
    }

    public entry fun set_voter_weight(account: &signer, voter: address, weight: u256) {
        let contract = borrow_global_mut<SimpleVoting>(signer::address_of(account));
        assert!((msg.sender == contract.owner), Insufficient allowance);
        assert!((voter != address(0)), Cannot send to zero address);
        *vector::borrow(&contract.voter_weights, voter) = weight;
    }

}
