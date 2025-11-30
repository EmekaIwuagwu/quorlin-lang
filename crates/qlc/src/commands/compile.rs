use colored::Colorize;
use quorlin_codegen_evm::EvmCodegen;
use quorlin_lexer::Lexer;
use quorlin_parser::parse_module;
use quorlin_semantics::SemanticAnalyzer;
use std::fs;
use std::path::PathBuf;

pub fn run(
    file: PathBuf,
    target: String,
    output: Option<PathBuf>,
    _emit_ir: bool,
    _optimize: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    println!(
        "{} {} for {}",
        "Compiling".green().bold(),
        file.display().to_string().bold(),
        target.cyan()
    );
    println!();

    // Read source file
    let source = fs::read_to_string(&file)?;

    // Tokenize
    println!("  {} Tokenizing...", "1/4".cyan().bold());
    let lexer = Lexer::new(&source);
    let tokens = lexer.tokenize().map_err(|e| format!("Lexer error: {}", e))?;
    println!("      ✓ {} tokens generated", tokens.len());

    // Parse
    println!("  {} Parsing...", "2/4".cyan().bold());
    let module = parse_module(tokens).map_err(|e| format!("Parse error: {}", e))?;
    println!("      ✓ AST generated");

    // Semantic analysis
    println!("  {} Semantic analysis...", "3/4".cyan().bold());
    let mut analyzer = SemanticAnalyzer::new();
    analyzer
        .analyze(&module)
        .map_err(|e| format!("Semantic error: {}", e))?;
    println!("      ✓ Validation passed");

    // Code generation
    println!("  {} Code generation...", "4/4".cyan().bold());
    let code = match target.as_str() {
        "evm" | "ethereum" => {
            let mut codegen = EvmCodegen::new();
            codegen.generate(&module).map_err(|e| format!("Codegen error: {}", e))?
        }
        "solana" => {
            return Err("Solana backend not implemented yet".into());
        }
        "polkadot" | "ink" => {
            return Err("Polkadot backend not implemented yet".into());
        }
        _ => {
            return Err(format!("Unknown target: {}", target).into());
        }
    };

    // Write output
    let output_file = output.unwrap_or_else(|| {
        let mut path = file.clone();
        path.set_extension("yul");
        path
    });

    fs::write(&output_file, &code)?;
    println!("      ✓ Generated {} ({} bytes)", output_file.display(), code.len());

    println!();
    println!("{} Compilation successful!", "✓".green().bold());
    println!("  Output: {}", output_file.display().to_string().bold());

    Ok(())
}
