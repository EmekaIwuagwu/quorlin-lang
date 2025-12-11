use logos::Logos;
use serde::{Deserialize, Serialize};

/// Token types for the Quorlin language
///
/// Designed to be as Python-compatible as possible, with minimal additions
/// for smart contract development.
#[derive(Logos, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[logos(skip r"[ \t]+")] // Skip horizontal whitespace (but NOT newlines)
pub enum TokenType {
    // ═══════════════════════════════════════════════════════════
    // QUORLIN KEYWORDS
    // ═══════════════════════════════════════════════════════════
    #[token("fn")]
    Fn,

    #[token("class")]
    Class,

    #[token("if")]
    If,

    #[token("elif")]
    Elif,

    #[token("else")]
    Else,

    #[token("for")]
    For,

    #[token("while")]
    While,

    #[token("in")]
    In,

    #[token("return")]
    Return,

    #[token("pass")]
    Pass,

    #[token("break")]
    Break,

    #[token("continue")]
    Continue,

    #[token("and")]
    And,

    #[token("or")]
    Or,

    #[token("not")]
    Not,

    #[token("True")]
    True,

    #[token("False")]
    False,

    #[token("None")]
    None,

    #[token("let")]
    Let,

    #[token("self")]
    SelfKw,

    #[token("from")]
    From,

    #[token("import")]
    Import,

    #[token("as")]
    As,

    #[token("raise")]
    Raise,

    // ═══════════════════════════════════════════════════════════
    // QUORLIN-SPECIFIC KEYWORDS (Minimal additions)
    // ═══════════════════════════════════════════════════════════
    #[token("contract")]
    Contract,

    #[token("interface")]
    Interface,

    #[token("struct")]
    Struct,

    #[token("enum")]
    Enum,

    #[token("event")]
    Event,

    #[token("error")]
    Error,

    #[token("const")]
    Const,

    #[token("emit")]
    Emit,

    #[token("require")]
    Require,

    #[token("revert")]
    Revert,

    #[token("indexed")]
    Indexed,

    #[token("this")]
    This,

    // ═══════════════════════════════════════════════════════════
    // TYPE KEYWORDS
    // ═══════════════════════════════════════════════════════════
    #[token("bool")]
    Bool,

    #[token("address")]
    Address,

    #[token("str")]
    Str,

    #[token("bytes")]
    Bytes,

    #[token("mapping")]
    Mapping,

    #[token("list")]
    List,

    #[token("Optional")]
    Optional,

    // Integer types (uint8, uint16, ..., uint256)
    #[regex(r"uint(8|16|32|64|128|256)", |lex| lex.slice().to_string())]
    Uint(String),

    // Signed integer types (int8, int16, ..., int256)
    #[regex(r"int(8|16|32|64|128|256)", |lex| lex.slice().to_string())]
    Int(String),

    // Fixed-size byte arrays (bytes1, bytes2, ..., bytes32)
    #[regex(r"bytes([1-9]|[12][0-9]|3[0-2])", |lex| lex.slice().to_string())]
    BytesN(String),

    // ═══════════════════════════════════════════════════════════
    // LITERALS
    // ═══════════════════════════════════════════════════════════

    // Identifier (variable/function names)
    #[regex(r"[a-zA-Z_][a-zA-Z0-9_]*", |lex| lex.slice().to_string())]
    Ident(String),

    // Integer literals (supports underscores: 1_000_000)
    #[regex(r"[0-9][0-9_]*", |lex| lex.slice().replace("_", ""))]
    IntLiteral(String),

    // Hexadecimal literals (0x1234abcd)
    #[regex(r"0x[0-9a-fA-F_]+", |lex| lex.slice().to_string())]
    HexLiteral(String),

    // Docstrings (triple-quoted strings) - Skip them
    #[regex(r#""""(?:[^"]|"[^"]|""[^"])*""""#, logos::skip)]
    #[regex(r"'''(?:[^']|'[^']|''[^'])*'''", logos::skip)]
    DocStringSkip,

    // String literals with double quotes
    #[regex(r#""([^"\\]|\\.)*""#, |lex| {
        let s = lex.slice();
        s[1..s.len()-1].to_string()
    })]
    StringLiteral(String),

    // String literals with single quotes
    #[regex(r#"'([^'\\]|\\.)*'"#, |lex| {
        let s = lex.slice();
        s[1..s.len()-1].to_string()
    })]
    StringLiteralSingle(String),

    // ═══════════════════════════════════════════════════════════
    // OPERATORS & PUNCTUATION (Python-compatible)
    // ═══════════════════════════════════════════════════════════

    // Arithmetic operators
    #[token("+")]
    Plus,

    #[token("-")]
    Minus,

    #[token("*")]
    Star,

    #[token("/")]
    Slash,

    // Note: // is used for comments, not floor division
    // For floor division, use explicit div() function
    // #[token("//")]
    // FloorDiv,

    #[token("%")]
    Percent,

    #[token("**")]
    DoubleStar,

    // Comparison operators
    #[token("==")]
    EqEq,

    #[token("!=")]
    NotEq,

    #[token("<")]
    Lt,

    #[token("<=")]
    LtEq,

    #[token(">")]
    Gt,

    #[token(">=")]
    GtEq,

    // Assignment operators
    #[token("=")]
    Eq,

    #[token("+=")]
    PlusEq,

    #[token("-=")]
    MinusEq,

    #[token("*=")]
    StarEq,

    #[token("/=")]
    SlashEq,

    // Delimiters
    #[token("(")]
    LParen,

    #[token(")")]
    RParen,

    #[token("[")]
    LBracket,

    #[token("]")]
    RBracket,

    #[token("{")]
    LBrace,

    #[token("}")]
    RBrace,

    // Punctuation
    #[token(":")]
    Colon,

    #[token(",")]
    Comma,

    #[token(".")]
    Dot,

    #[token("->")]
    Arrow,

    #[token("@")]
    At,

    // ═══════════════════════════════════════════════════════════
    // WHITESPACE & INDENTATION
    // ═══════════════════════════════════════════════════════════

    // Newline (significant in Python-style syntax)
    #[regex(r"\r?\n")]
    Newline,

    // Comments (skip) - supports both # and //
    #[regex(r"#[^\n]*", logos::skip)]
    #[regex(r"//[^\n]*", logos::skip)]
    Comment,

    // Indentation tokens (generated by preprocessor, not by lexer)
    Indent,
    Dedent,

    // End of file
    Eof,
}

/// A token with location information
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Token {
    pub token_type: TokenType,
    pub span: Span,
}

/// Source code location
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct Span {
    pub start: usize,
    pub end: usize,
    pub line: usize,
    pub column: usize,
}

impl Span {
    pub fn new(start: usize, end: usize, line: usize, column: usize) -> Self {
        Self {
            start,
            end,
            line,
            column,
        }
    }

    /// Create a span covering two spans
    pub fn merge(start: Span, end: Span) -> Self {
        Self {
            start: start.start,
            end: end.end,
            line: start.line,
            column: start.column,
        }
    }
}

impl Token {
    pub fn new(token_type: TokenType, span: Span) -> Self {
        Self { token_type, span }
    }
}
