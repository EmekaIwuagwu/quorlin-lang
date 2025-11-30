use clap::{Parser, Subcommand};
use colored::Colorize;
use std::fs;
use std::path::PathBuf;

mod commands;

#[derive(Parser)]
#[command(name = "qlc")]
#[command(about = "The Quorlin smart contract language compiler", long_about = None)]
#[command(version)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Compile a Quorlin contract
    Compile {
        /// Input .ql file
        file: PathBuf,

        /// Target platform (evm, solana, ink)
        #[arg(short, long)]
        target: String,

        /// Output file or directory
        #[arg(short, long)]
        output: Option<PathBuf>,

        /// Emit intermediate representation
        #[arg(long)]
        emit_ir: bool,

        /// Enable optimizations
        #[arg(long)]
        optimize: bool,
    },

    /// Type-check without generating code
    Check {
        /// Input .ql file
        file: PathBuf,
    },

    /// Tokenize a file and display tokens (for debugging)
    Tokenize {
        /// Input .ql file
        file: PathBuf,

        /// Output as JSON
        #[arg(long)]
        json: bool,
    },

    /// Parse a file and display AST (for debugging)
    Parse {
        /// Input .ql file
        file: PathBuf,

        /// Output as JSON
        #[arg(long)]
        json: bool,
    },

    /// Format Quorlin source code
    Fmt {
        /// Input .ql file
        file: PathBuf,
    },

    /// Create a new Quorlin project
    Init {
        /// Project name
        name: String,
    },
}

fn main() {
    let cli = Cli::parse();

    let result = match cli.command {
        Commands::Compile {
            file,
            target,
            output,
            emit_ir,
            optimize,
        } => commands::compile::run(file, target, output, emit_ir, optimize),

        Commands::Check { file } => commands::check::run(file),

        Commands::Tokenize { file, json } => commands::tokenize::run(file, json),

        Commands::Parse { file, json } => commands::parse::run(file, json),

        Commands::Fmt { file } => commands::fmt::run(file),

        Commands::Init { name } => commands::init::run(name),
    };

    if let Err(e) = result {
        eprintln!("{}: {}", "error".red().bold(), e);
        std::process::exit(1);
    }
}
