//! Diagnostic error reporting

use crate::Span;
use colored::Colorize;

#[derive(Debug)]
pub struct Diagnostic {
    pub severity: Severity,
    pub message: String,
    pub span: Option<Span>,
    pub help: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Severity {
    Error,
    Warning,
    Info,
}

impl Diagnostic {
    pub fn error(message: impl Into<String>) -> Self {
        Self {
            severity: Severity::Error,
            message: message.into(),
            span: None,
            help: None,
        }
    }

    pub fn with_span(mut self, span: Span) -> Self {
        self.span = Some(span);
        self
    }

    pub fn with_help(mut self, help: impl Into<String>) -> Self {
        self.help = Some(help.into());
        self
    }

    pub fn display(&self, source: &str, filename: &str) {
        let prefix = match self.severity {
            Severity::Error => "error".red().bold(),
            Severity::Warning => "warning".yellow().bold(),
            Severity::Info => "info".blue().bold(),
        };

        eprintln!("{}: {}", prefix, self.message.bold());

        if let Some(span) = self.span {
            eprintln!(
                "  {} {}:{}:{}",
                "-->".blue().bold(),
                filename,
                span.line,
                span.column
            );

            // Extract the relevant line
            let lines: Vec<&str> = source.lines().collect();
            if span.line > 0 && span.line <= lines.len() {
                let line = lines[span.line - 1];
                eprintln!("   {}", "|".blue().bold());
                eprintln!(
                    "{:>3} {} {}",
                    span.line.to_string().blue().bold(),
                    "|".blue().bold(),
                    line
                );

                // Add underline
                let column_offset = span.column.saturating_sub(1);
                let length = (span.end - span.start).max(1);
                eprintln!(
                    "   {} {}{}",
                    "|".blue().bold(),
                    " ".repeat(column_offset),
                    "^".repeat(length).red().bold()
                );
            }
        }

        if let Some(help) = &self.help {
            eprintln!("   {} {}", "help:".green().bold(), help);
        }

        eprintln!();
    }
}
