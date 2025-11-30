use crate::token::{Span, Token, TokenType};

/// Indentation processor that converts raw tokens into Python-style
/// INDENT/DEDENT token streams
///
/// This is the magic that makes whitespace-based syntax work!
pub struct IndentProcessor {
    /// Stack of indentation levels (in spaces)
    indent_stack: Vec<usize>,
    /// Pending tokens to emit
    pending: Vec<Token>,
    /// Whether we're at the start of a line
    at_line_start: bool,
    /// Current line number
    line: usize,
    /// Current column
    column: usize,
}

impl IndentProcessor {
    pub fn new() -> Self {
        Self {
            indent_stack: vec![0], // Start with base indentation of 0
            pending: Vec::new(),
            at_line_start: true,
            line: 1,
            column: 1,
        }
    }

    /// Process a raw token stream and insert INDENT/DEDENT tokens
    pub fn process(&mut self, raw_tokens: Vec<Token>) -> Result<Vec<Token>, String> {
        let mut result = Vec::new();

        for token in raw_tokens {
            match token.token_type {
                TokenType::Newline => {
                    // Emit newline
                    result.push(token.clone());
                    self.at_line_start = true;
                    self.line += 1;
                    self.column = 1;
                }
                _ => {
                    // If we're at the start of a line, check indentation
                    if self.at_line_start {
                        self.at_line_start = false;

                        // Calculate indentation level
                        let indent_level = token.span.column - 1;

                        // Compare with current indentation
                        let current_indent = *self.indent_stack.last().unwrap();

                        if indent_level > current_indent {
                            // INDENT
                            self.indent_stack.push(indent_level);
                            result.push(Token::new(
                                TokenType::Indent,
                                Span::new(token.span.start, token.span.start, token.span.line, 1),
                            ));
                        } else if indent_level < current_indent {
                            // DEDENT (possibly multiple)
                            while let Some(&level) = self.indent_stack.last() {
                                if level <= indent_level {
                                    break;
                                }
                                self.indent_stack.pop();
                                result.push(Token::new(
                                    TokenType::Dedent,
                                    Span::new(token.span.start, token.span.start, token.span.line, 1),
                                ));
                            }

                            // Check for indentation error
                            if self.indent_stack.last() != Some(&indent_level) {
                                return Err(format!(
                                    "Indentation error at line {}: inconsistent indentation",
                                    token.span.line
                                ));
                            }
                        }
                    }

                    // Emit the actual token
                    self.column = token.span.column + (token.span.end - token.span.start);
                    result.push(token);
                }
            }
        }

        // At EOF, emit DEDENT for each remaining indentation level
        while self.indent_stack.len() > 1 {
            self.indent_stack.pop();
            result.push(Token::new(
                TokenType::Dedent,
                Span::new(0, 0, self.line, 1),
            ));
        }

        // Emit EOF token
        result.push(Token::new(
            TokenType::Eof,
            Span::new(0, 0, self.line, self.column),
        ));

        Ok(result)
    }
}

impl Default for IndentProcessor {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_simple_indentation() {
        let raw_tokens = vec![
            Token::new(TokenType::Def, Span::new(0, 3, 1, 1)),
            Token::new(TokenType::Ident("foo".to_string()), Span::new(4, 7, 1, 5)),
            Token::new(TokenType::Colon, Span::new(7, 8, 1, 8)),
            Token::new(TokenType::Newline, Span::new(8, 9, 1, 9)),
            Token::new(TokenType::Pass, Span::new(9, 13, 2, 5)), // Indented by 4
            Token::new(TokenType::Newline, Span::new(13, 14, 2, 9)),
        ];

        let mut processor = IndentProcessor::new();
        let result = processor.process(raw_tokens).unwrap();

        // Should have: def, foo, :, newline, INDENT, pass, newline, DEDENT, EOF
        assert_eq!(result.len(), 9);
        assert_eq!(result[4].token_type, TokenType::Indent);
        assert_eq!(result[7].token_type, TokenType::Dedent);
    }
}
