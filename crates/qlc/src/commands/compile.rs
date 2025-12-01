use colored::Colorize;
use quorlin_codegen_evm::EvmCodegen;
use quorlin_codegen_solana::SolanaCodegen;
use quorlin_codegen_ink::InkCodegen;
use quorlin_lexer::Lexer;
use quorlin_parser::parse_module;
use quorlin_semantics::SemanticAnalyzer;
use std::fs;
use std::path::PathBuf;
use std::time::Instant;

pub fn run(
    file: PathBuf,
    target: String,
    output: Option<PathBuf>,
    _emit_ir: bool,
    _optimize: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    let start_time = Instant::now();

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
    let (code, extension) = match target.as_str() {
        "evm" | "ethereum" => {
            let mut codegen = EvmCodegen::new();
            let code = codegen.generate(&module).map_err(|e| format!("Codegen error: {}", e))?;
            (code, "yul")
        }
        "solana" => {
            let mut codegen = SolanaCodegen::new();
            let code = codegen.generate(&module).map_err(|e| format!("Codegen error: {}", e))?;
            (code, "rs")
        }
        "polkadot" | "ink" => {
            let mut codegen = InkCodegen::new();
            let code = codegen.generate(&module).map_err(|e| format!("Codegen error: {}", e))?;
            (code, "rs")
        }
        _ => {
            return Err(format!("Unknown target: {}", target).into());
        }
    };

    // Write output
    let output_file = output.unwrap_or_else(|| {
        let mut path = file.clone();
        path.set_extension(extension);
        path
    });

    fs::write(&output_file, &code)?;
    println!("      ✓ Generated {} ({} bytes)", output_file.display(), code.len());

    let elapsed = start_time.elapsed();
    let elapsed_str = if elapsed.as_secs() > 0 {
        format!("{:.2}s", elapsed.as_secs_f64())
    } else {
        format!("{}ms", elapsed.as_millis())
    };

    println!();
    println!("{}", "━".repeat(60).bright_green());
    println!(
        "{} {}",
        "✓".green().bold(),
        "Successful compilation".green().bold()
    );
    println!("{}", "━".repeat(60).bright_green());
    println!("  {} {}", "Output:".bold(), output_file.display().to_string().cyan());
    println!("  {} {}", "Size:".bold(), format!("{} bytes", code.len()).cyan());
    println!("  {} {}", "Time:".bold(), elapsed_str.yellow());
    println!("{}", "━".repeat(60).bright_green());

    Ok(())
}
