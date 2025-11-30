// integration_test.rs — Integration tests for all Quorlin backends

#[cfg(test)]
mod tests {
    use quorlin_lexer::Lexer;
    use quorlin_parser::parse_module;
    use quorlin_semantics::SemanticAnalyzer;
    use quorlin_codegen_evm::EvmCodegen;
    use quorlin_codegen_solana::SolanaCodegen;
    use quorlin_codegen_ink::InkCodegen;

    const SIMPLE_CONTRACT: &str = r#"
contract SimpleStorage:
    value: uint256

    @constructor
    def __init__(initial_value: uint256):
        self.value = initial_value

    @external
    def set_value(new_value: uint256):
        self.value = new_value

    @view
    def get_value() -> uint256:
        return self.value
"#;

    const TOKEN_CONTRACT: &str = r#"
event Transfer(from_addr: address, to: address, value: uint256)

contract SimpleToken:
    balances: mapping[address, uint256]
    total_supply: uint256

    @constructor
    def __init__(supply: uint256):
        self.total_supply = supply
        self.balances[msg.sender] = supply

    @external
    def transfer(to: address, amount: uint256) -> bool:
        require(self.balances[msg.sender] >= amount, "Insufficient balance")
        self.balances[msg.sender] -= amount
        self.balances[to] += amount
        emit Transfer(msg.sender, to, amount)
        return True

    @view
    def balance_of(account: address) -> uint256:
        return self.balances[account]
"#;

    fn parse_contract(source: &str) -> quorlin_parser::Module {
        let lexer = Lexer::new(source);
        let tokens = lexer.tokenize().expect("Tokenization failed");
        parse_module(tokens).expect("Parsing failed")
    }

    fn analyze_contract(module: &quorlin_parser::Module) {
        let mut analyzer = SemanticAnalyzer::new();
        analyzer.analyze(module).expect("Semantic analysis failed");
    }

    #[test]
    fn test_simple_contract_evm() {
        let module = parse_contract(SIMPLE_CONTRACT);
        analyze_contract(&module);

        let mut codegen = EvmCodegen::new();
        let yul = codegen.generate(&module).expect("EVM codegen failed");

        assert!(yul.contains("object \"Contract\""));
        assert!(yul.contains("set_value"));
        assert!(yul.contains("get_value"));
    }

    #[test]
    fn test_simple_contract_solana() {
        let module = parse_contract(SIMPLE_CONTRACT);
        analyze_contract(&module);

        let mut codegen = SolanaCodegen::new();
        let rust = codegen.generate(&module).expect("Solana codegen failed");

        assert!(rust.contains("use anchor_lang::prelude::*"));
        assert!(rust.contains("pub fn set_value"));
        assert!(rust.contains("pub fn get_value"));
    }

    #[test]
    fn test_simple_contract_ink() {
        let module = parse_contract(SIMPLE_CONTRACT);
        analyze_contract(&module);

        let mut codegen = InkCodegen::new();
        let rust = codegen.generate(&module).expect("ink! codegen failed");

        assert!(rust.contains("#[ink::contract]"));
        assert!(rust.contains("#[ink(storage)]"));
        assert!(rust.contains("pub fn set_value"));
        assert!(rust.contains("pub fn get_value"));
    }

    #[test]
    fn test_token_contract_evm() {
        let module = parse_contract(TOKEN_CONTRACT);
        analyze_contract(&module);

        let mut codegen = EvmCodegen::new();
        let yul = codegen.generate(&module).expect("EVM codegen failed");

        assert!(yul.contains("transfer"));
        assert!(yul.contains("balance_of"));
        assert!(yul.contains("log1")); // Event emission
    }

    #[test]
    fn test_token_contract_solana() {
        let module = parse_contract(TOKEN_CONTRACT);
        analyze_contract(&module);

        let mut codegen = SolanaCodegen::new();
        let rust = codegen.generate(&module).expect("Solana codegen failed");

        assert!(rust.contains("pub fn transfer"));
        assert!(rust.contains("pub fn balance_of"));
        assert!(rust.contains("HashMap<Pubkey, u128>")); // Mapping
    }

    #[test]
    fn test_token_contract_ink() {
        let module = parse_contract(TOKEN_CONTRACT);
        analyze_contract(&module);

        let mut codegen = InkCodegen::new();
        let rust = codegen.generate(&module).expect("ink! codegen failed");

        assert!(rust.contains("pub fn transfer"));
        assert!(rust.contains("pub fn balance_of"));
        assert!(rust.contains("Mapping<AccountId, u128>")); // Mapping
        assert!(rust.contains("#[ink(event)]")); // Event
    }

    #[test]
    fn test_all_backends_produce_output() {
        let module = parse_contract(TOKEN_CONTRACT);
        analyze_contract(&module);

        // EVM
        let mut evm = EvmCodegen::new();
        let evm_code = evm.generate(&module).expect("EVM failed");
        assert!(!evm_code.is_empty());

        // Solana
        let mut solana = SolanaCodegen::new();
        let solana_code = solana.generate(&module).expect("Solana failed");
        assert!(!solana_code.is_empty());

        // ink!
        let mut ink = InkCodegen::new();
        let ink_code = ink.generate(&module).expect("ink! failed");
        assert!(!ink_code.is_empty());

        // All backends should produce different output
        assert_ne!(evm_code, solana_code);
        assert_ne!(evm_code, ink_code);
        assert_ne!(solana_code, ink_code);
    }

    #[test]
    fn test_type_mapping_consistency() {
        let contract = r#"
contract TypeTest:
    u8_val: uint8
    u256_val: uint256
    addr: address
    flag: bool

    @view
    def get_u8() -> uint8:
        return self.u8_val
"#;

        let module = parse_contract(contract);

        let mut solana = SolanaCodegen::new();
        let solana_code = solana.generate(&module).expect("Solana failed");
        assert!(solana_code.contains("u8"));
        assert!(solana_code.contains("u128")); // uint256 -> u128 on Solana
        assert!(solana_code.contains("Pubkey"));

        let mut ink = InkCodegen::new();
        let ink_code = ink.generate(&module).expect("ink! failed");
        assert!(ink_code.contains("u8"));
        assert!(ink_code.contains("U256")); // uint256 -> U256 on ink!
        assert!(ink_code.contains("AccountId"));
    }
}
