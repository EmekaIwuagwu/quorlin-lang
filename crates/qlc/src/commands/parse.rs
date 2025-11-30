use colored::Colorize;
use quorlin_lexer::Lexer;
use quorlin_parser::parse_module;
use quorlin_semantics::SemanticAnalyzer;
use std::fs;
use std::path::PathBuf;

pub fn run(file: PathBuf, json: bool) -> Result<(), Box<dyn std::error::Error>> {
    // Read source file
    let source = fs::read_to_string(&file)?;

    // Tokenize
    let lexer = Lexer::new(&source);
    let tokens = lexer.tokenize().map_err(|e| format!("Lexer error: {}", e))?;

    // Parse
    let module = parse_module(tokens).map_err(|e| format!("Parse error: {}", e))?;

    // Semantic analysis
    let mut analyzer = SemanticAnalyzer::new();
    analyzer
        .analyze(&module)
        .map_err(|e| format!("Semantic error: {}", e))?;

    if json {
        // Output as JSON
        let json = serde_json::to_string_pretty(&module)?;
        println!("{}", json);
    } else {
        // Pretty-print AST
        println!(
            "{} {}",
            "Parsing".green().bold(),
            file.display().to_string().bold()
        );
        println!();
        println!("✓ Successfully parsed!");
        println!();
        println!("{} items found:\n", module.items.len());

        for (i, item) in module.items.iter().enumerate() {
            print!("{:>3}. ", i + 1);
            match item {
                quorlin_parser::Item::Import(import) => {
                    println!(
                        "{} from {} import {}",
                        "Import".blue().bold(),
                        import.module,
                        import.items.join(", ")
                    );
                }
                quorlin_parser::Item::Event(event) => {
                    println!(
                        "{} {} ({} parameters)",
                        "Event".yellow().bold(),
                        event.name.bold(),
                        event.params.len()
                    );
                }
                quorlin_parser::Item::Error(error) => {
                    println!(
                        "{} {} ({} parameters)",
                        "Error".red().bold(),
                        error.name.bold(),
                        error.params.len()
                    );
                }
                quorlin_parser::Item::Contract(contract) => {
                    println!(
                        "{} {} ({} members)",
                        "Contract".green().bold(),
                        contract.name.bold(),
                        contract.body.len()
                    );
                    for member in &contract.body {
                        match member {
                            quorlin_parser::ContractMember::StateVar(var) => {
                                println!("     ├─ State: {}: {:?}", var.name, var.type_annotation);
                            }
                            quorlin_parser::ContractMember::Function(func) => {
                                println!(
                                    "     ├─ Function: {} ({} params, {} stmts)",
                                    func.name,
                                    func.params.len(),
                                    func.body.len()
                                );
                            }
                            quorlin_parser::ContractMember::Constant(c) => {
                                println!("     ├─ Const: {}: {:?}", c.name, c.type_annotation);
                            }
                        }
                    }
                }
                quorlin_parser::Item::Struct(s) => {
                    println!(
                        "{} {} ({} fields)",
                        "Struct".cyan().bold(),
                        s.name.bold(),
                        s.fields.len()
                    );
                }
                quorlin_parser::Item::Enum(e) => {
                    println!(
                        "{} {} ({} variants)",
                        "Enum".magenta().bold(),
                        e.name.bold(),
                        e.variants.len()
                    );
                }
                quorlin_parser::Item::Interface(i) => {
                    println!(
                        "{} {} ({} functions)",
                        "Interface".blue().bold(),
                        i.name.bold(),
                        i.functions.len()
                    );
                }
            }
        }

        println!();
        println!("{}", "✓ Parse and semantic analysis successful!".green().bold());
    }

    Ok(())
}
