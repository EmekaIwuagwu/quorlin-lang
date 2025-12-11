use crate::indent::IndentProcessor;
use crate::token::{Span, Token, TokenType};
use logos::Logos;

/// Errors that can occur during lexical analysis
#[derive(Debug, thiserror::Error)]
pub enum LexerError {
    #[error("Invalid token at line {line}, column {column}")]
    InvalidToken { line: usize, column: usize },

    #[error("Indentation error: {0}")]
    IndentationError(String),

    #[error("Unterminated string at line {line}, column {column}")]
    UnterminatedString { line: usize, column: usize },
}

/// The main lexer for Quorlin source code
pub struct Lexer<'source> {
    source: &'source str,
}

impl<'source> Lexer<'source> {
    pub fn new(source: &'source str) -> Self {
        Self { source }
    }

    /// Tokenize the source code into a token stream with INDENT/DEDENT tokens
    pub fn tokenize(&self) -> Result<Vec<Token>, LexerError> {
        let raw_tokens = self.raw_tokenize()?;
        let mut processor = IndentProcessor::new();
        processor
            .process(raw_tokens)
            .map_err(LexerError::IndentationError)
    }

    /// Perform raw tokenization (without indentation processing)
    fn raw_tokenize(&self) -> Result<Vec<Token>, LexerError> {
        let mut tokens = Vec::new();
        let mut lexer = TokenType::lexer(self.source);
        let mut line = 1;
        let mut line_start = 0;
        let mut nesting_level = 0;

        while let Some(token_result) = lexer.next() {
            let span = lexer.span();
            let start = span.start;
            let end = span.end;

            // Calculate line and column
            let source_before = &self.source[line_start..start];
            let newlines_before = source_before.matches('\n').count();
            if newlines_before > 0 {
                line += newlines_before;
                line_start = self.source[..start]
                    .rfind('\n')
                    .map(|pos| pos + 1)
                    .unwrap_or(0);
            }
            let column = start - line_start + 1;

            let token_span = Span::new(start, end, line, column);

            match token_result {
                Ok(token_type) => {
                    // Update nesting level for Python-style implicit line continuation
                    match token_type {
                        TokenType::LParen | TokenType::LBracket | TokenType::LBrace => {
                            nesting_level += 1;
                        }
                        TokenType::RParen | TokenType::RBracket | TokenType::RBrace => {
                            if nesting_level > 0 {
                                nesting_level -= 1;
                            }
                        }
                        TokenType::Newline => {
                            if nesting_level > 0 {
                                // Skip newlines inside brackets/parentheses
                                continue;
                            }
                        }
                        _ => {}
                    }

                    // Filter out certain tokens or process them
                    match &token_type {
                        TokenType::Ident(name) => {
                            // Check if identifier is a keyword that logos missed
                            let actual_type = match name.as_str() {
                                // This is a fallback in case logos doesn't catch everything
                                _ => token_type,
                            };
                            tokens.push(Token::new(actual_type, token_span));
                        }
                        _ => {
                            tokens.push(Token::new(token_type, token_span));
                        }
                    }
                }
                Err(_) => {
                    return Err(LexerError::InvalidToken { line, column });
                }
            }
        }

        Ok(tokens)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_simple_keywords() {
        let source = "fn foo";
        let lexer = Lexer::new(source);
        let tokens = lexer.raw_tokenize().unwrap();

        assert_eq!(tokens.len(), 2);
        assert_eq!(tokens[0].token_type, TokenType::Fn);
        assert!(matches!(tokens[1].token_type, TokenType::Ident(_)));
    }

    #[test]
    fn test_contract_declaration() {
        let source = "contract Token:";
        let lexer = Lexer::new(source);
        let tokens = lexer.raw_tokenize().unwrap();

        assert_eq!(tokens.len(), 3);
        assert_eq!(tokens[0].token_type, TokenType::Contract);
        assert_eq!(tokens[2].token_type, TokenType::Colon);
    }

    #[test]
    fn test_integer_literals() {
        let source = "123 1_000_000 0xff";
        let lexer = Lexer::new(source);
        let tokens = lexer.raw_tokenize().unwrap();

        assert_eq!(tokens.len(), 3);
        assert!(matches!(tokens[0].token_type, TokenType::IntLiteral(_)));
        assert!(matches!(tokens[1].token_type, TokenType::IntLiteral(_)));
        assert!(matches!(tokens[2].token_type, TokenType::HexLiteral(_)));
    }

    #[test]
    fn test_string_literals() {
        let source = r#""hello" 'world'"#;
        let lexer = Lexer::new(source);
        let tokens = lexer.raw_tokenize().unwrap();

        assert_eq!(tokens.len(), 2);
        assert!(matches!(
            tokens[0].token_type,
            TokenType::StringLiteral(_)
        ));
        assert!(matches!(
            tokens[1].token_type,
            TokenType::StringLiteralSingle(_)
        ));
    }

    #[test]
    fn test_type_annotations() {
        let source = "amount: uint256";
        let lexer = Lexer::new(source);
        let tokens = lexer.raw_tokenize().unwrap();

        assert_eq!(tokens.len(), 3);
        assert!(matches!(tokens[0].token_type, TokenType::Ident(_)));
        assert_eq!(tokens[1].token_type, TokenType::Colon);
        assert!(matches!(tokens[2].token_type, TokenType::Uint(_)));
    }

    #[test]
    fn test_operators() {
        let source = "+ - * / == != <= >= and or not";
        let lexer = Lexer::new(source);
        let tokens = lexer.raw_tokenize().unwrap();

        assert_eq!(tokens[0].token_type, TokenType::Plus);
        assert_eq!(tokens[1].token_type, TokenType::Minus);
        assert_eq!(tokens[2].token_type, TokenType::Star);
        assert_eq!(tokens[3].token_type, TokenType::Slash);
        assert_eq!(tokens[4].token_type, TokenType::EqEq);
        assert_eq!(tokens[5].token_type, TokenType::NotEq);
        assert_eq!(tokens[6].token_type, TokenType::LtEq);
        assert_eq!(tokens[7].token_type, TokenType::GtEq);
        assert_eq!(tokens[8].token_type, TokenType::And);
        assert_eq!(tokens[9].token_type, TokenType::Or);
        assert_eq!(tokens[10].token_type, TokenType::Not);
    }

    #[test]
    fn test_full_function() {
        let source = r#"
def transfer(to: address, amount: uint256) -> bool:
    return True
"#;
        let lexer = Lexer::new(source);
        let tokens = lexer.tokenize().unwrap();

        // Should include: newline, def, transfer, (, to, :, address, ,, amount, :, uint256, ), ->, bool, :,
        //                 newline, INDENT, return, True, newline, DEDENT, EOF
        assert!(tokens.len() > 15);

        // Check for INDENT and DEDENT
        let has_indent = tokens.iter().any(|t| t.token_type == TokenType::Indent);
        let has_dedent = tokens.iter().any(|t| t.token_type == TokenType::Dedent);
        assert!(has_indent, "Should have INDENT token");
        assert!(has_dedent, "Should have DEDENT token");
    }
}
