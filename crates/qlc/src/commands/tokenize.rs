use colored::Colorize;
use quorlin_lexer::Lexer;
use std::fs;
use std::path::PathBuf;

pub fn run(file: PathBuf, json: bool) -> Result<(), Box<dyn std::error::Error>> {
    // Read source file
    let source = fs::read_to_string(&file)?;

    // Tokenize
    let lexer = Lexer::new(&source);
    let tokens = lexer.tokenize().map_err(|e| format!("Lexer error: {}", e))?;

    if json {
        // Output as JSON
        let json = serde_json::to_string_pretty(&tokens)?;
        println!("{}", json);
    } else {
        // Pretty-print tokens
        println!(
            "{} {}",
            "Tokenizing".green().bold(),
            file.display().to_string().bold()
        );
        println!();
        println!("{} tokens found:\n", tokens.len());

        for (i, token) in tokens.iter().enumerate() {
            println!(
                "{:>4} │ {:>3}:{:<3} │ {:?}",
                i.to_string().blue(),
                token.span.line,
                token.span.column,
                token.token_type
            );
        }
    }

    Ok(())
}
