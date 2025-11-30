fn main() {
    // Generate parser from simplified LALRPOP grammar
    // Using grammar_simple for MVP - will enhance iteratively
    lalrpop::Configuration::new()
        .emit_rerun_directives(true)
        .set_in_dir("src")
        .process_file("src/grammar_simple.lalrpop")
        .unwrap();
}
