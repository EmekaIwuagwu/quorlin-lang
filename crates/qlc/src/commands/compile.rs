use colored::Colorize;
use quorlin_codegen_evm::EvmCodegen;
use quorlin_codegen_solana::SolanaCodegen;
use quorlin_codegen_ink::InkCodegen;
use quorlin_codegen_aptos::AptosCodegen;
use quorlin_lexer::Lexer;
use quorlin_parser::parse_module;
use quorlin_semantics::SemanticAnalyzer;
use std::fs;
use std::path::PathBuf;
use std::time::Instant;

fn print_header(file: &PathBuf, target: &str) {
    println!();
    println!("{}", "╔════════════════════════════════════════════════════════════╗".bright_cyan());
    println!("{}", "║                  🚀 QUORLIN COMPILER 🚀                   ║".bright_cyan().bold());
    println!("{}", "╚════════════════════════════════════════════════════════════╝".bright_cyan());
    println!();
    println!("  {} {}", "📄 Source:".bright_white().bold(), file.display().to_string().bright_yellow());
    println!("  {} {}", "🎯 Target:".bright_white().bold(), target.bright_magenta().bold());
    println!();
}

fn print_step_header(step: &str, total: &str, title: &str) {
    println!("  {} {} {}",
        format!("[{}/{}]", step, total).bright_cyan().bold(),
        "→".bright_white(),
        title.bright_white().bold()
    );
}

fn print_success(message: &str) {
    println!("      {} {}", "✓".bright_green().bold(), message.green());
}

fn print_progress_bar(current: usize, total: usize) {
    let percentage = (current as f64 / total as f64 * 100.0) as usize;
    let filled = percentage / 5;
    let empty = 20 - filled;

    let bar = format!(
        "[{}{}] {}%",
        "█".repeat(filled).bright_green(),
        "░".repeat(empty).bright_black(),
        percentage
    );

    println!("      {}", bar);
}

fn format_size(bytes: usize) -> String {
    if bytes < 1024 {
        format!("{} bytes", bytes)
    } else if bytes < 1024 * 1024 {
        format!("{:.2} KB", bytes as f64 / 1024.0)
    } else {
        format!("{:.2} MB", bytes as f64 / (1024.0 * 1024.0))
    }
}

fn print_success_box(output_file: &PathBuf, size: usize, elapsed_ms: u128) {
    let elapsed_str = if elapsed_ms >= 1000 {
        format!("{:.2}s", elapsed_ms as f64 / 1000.0)
    } else {
        format!("{}ms", elapsed_ms)
    };

    println!();
    println!("{}", "╔════════════════════════════════════════════════════════════╗".bright_green());
    println!("{}", "║              ✨ COMPILATION SUCCESSFUL ✨                 ║".bright_green().bold());
    println!("{}", "╚════════════════════════════════════════════════════════════╝".bright_green());
    println!();
    println!("  {} {}", "📦 Output:".bright_white().bold(), output_file.display().to_string().bright_cyan());
    println!("  {} {}", "📊 Size:".bright_white().bold(), format_size(size).bright_yellow());
    println!("  {} {}", "⚡ Time:".bright_white().bold(), elapsed_str.bright_magenta());
    println!();
    println!("{}", "════════════════════════════════════════════════════════════".bright_green());
    println!();
}

pub fn run(
    file: PathBuf,
    target: String,
    output: Option<PathBuf>,
    _emit_ir: bool,
    _optimize: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    let start_time = Instant::now();

    // Print beautiful header
    print_header(&file, &target);

    // Read source file
    let source = fs::read_to_string(&file)?;

    // Step 1: Tokenize
    print_step_header("1", "4", "Tokenizing");
    let lexer = Lexer::new(&source);
    let tokens = lexer.tokenize().map_err(|e| format!("Lexer error: {}", e))?;
    print_success(&format!("{} tokens generated", tokens.len()));
    print_progress_bar(1, 4);
    println!();

    // Step 2: Parse
    print_step_header("2", "4", "Parsing");
    let module = parse_module(tokens).map_err(|e| format!("Parse error: {}", e))?;
    print_success("AST generated successfully");
    print_progress_bar(2, 4);
    println!();

    // Step 3: Semantic analysis
    print_step_header("3", "4", "Semantic Analysis");
    let mut analyzer = SemanticAnalyzer::new();
    analyzer
        .analyze(&module)
        .map_err(|e| format!("Semantic error: {}", e))?;
    print_success("Type checking passed");
    println!();
    print_progress_bar(3, 4);
    println!();

    // Step 4: Code generation
    print_step_header("4", "4", "Code Generation");
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
        "aptos" | "move" => {
            let codegen = AptosCodegen::default();
            let code = codegen.generate(&module).map_err(|e| format!("Codegen error: {}", e))?;
            (code, "move")
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
    print_success(&format!("Generated {}", output_file.display()));
    print_progress_bar(4, 4);

    // Print success summary
    let elapsed = start_time.elapsed().as_millis();
    print_success_box(&output_file, code.len(), elapsed);

    Ok(())
}
