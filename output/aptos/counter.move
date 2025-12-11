module 0x1::quorlin_contract {
    use std::signer;
    use std::vector;
    use aptos_framework::account;

    /// Contract: Counter
    struct Counter has key {
        count: u256,
        owner: address,
    }

    /// Initialize the Counter contract
    public entry fun initialize(account: &signer) {
        let contract = Counter {
            count: 0,
            owner: @0x0,
        };
        move_to(account, contract);
    }

    fun __init__(contract: &mut Counter, initial_count: u256) {
        contract.count = initial_count;
        contract.owner = msg.sender;
    }

    fun get_count(contract: &mut Counter): u256 {
        contract.count
    }

    fun get_owner(contract: &mut Counter): address {
        contract.owner
    }

    public entry fun increment(account: &signer) {
        let contract = borrow_global_mut<Counter>(signer::address_of(account));
        contract.count = (contract.count + 1);
        // Unsupported statement
    }

    public entry fun decrement(account: &signer) {
        let contract = borrow_global_mut<Counter>(signer::address_of(account));
        assert!((contract.count > 0), Counter cannot go below zero);
        contract.count = (contract.count - 1);
        // Unsupported statement
    }

    public entry fun add(account: &signer, amount: u256) {
        let contract = borrow_global_mut<Counter>(signer::address_of(account));
        assert!((msg.sender == contract.owner), Only owner can add);
        contract.count = (contract.count + amount);
        // Unsupported statement
    }

    public entry fun reset(account: &signer) {
        let contract = borrow_global_mut<Counter>(signer::address_of(account));
        assert!((msg.sender == contract.owner), Only owner can reset);
        contract.count = 0;
    }

}
