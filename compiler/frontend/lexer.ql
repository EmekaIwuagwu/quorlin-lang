# Quorlin Lexer - Tokenizes Quorlin source code
# Handles Python-style indentation and all Quorlin syntax

from compiler.runtime.stdlib import Vec, HashMap, Option, Result
from compiler.runtime.stdlib import is_digit, is_alpha, is_alphanumeric, is_whitespace
from compiler.runtime.stdlib import str_len, str_char_at, str_substring
from compiler.frontend.ast import Token, TokenKind, SourceLocation

# ============================================================================
# Lexer Errors
# ============================================================================

enum LexerError:
    """Lexer error types."""
    UnexpectedCharacter(ch: str, location: SourceLocation)
    UnterminatedString(location: SourceLocation)
    InvalidNumber(lexeme: str, location: SourceLocation)
    IndentationError(message: str, location: SourceLocation)
    UnexpectedEOF(location: SourceLocation)
    
    fn to_string() -> str:
        """Convert error to string."""
        match self:
            LexerError.UnexpectedCharacter(ch, loc):
                return f"Unexpected character '{ch}' at {loc}"
            LexerError.UnterminatedString(loc):
                return f"Unterminated string at {loc}"
            LexerError.InvalidNumber(lexeme, loc):
                return f"Invalid number '{lexeme}' at {loc}"
            LexerError.IndentationError(msg, loc):
                return f"Indentation error: {msg} at {loc}"
            LexerError.UnexpectedEOF(loc):
                return f"Unexpected end of file at {loc}"

# ============================================================================
# Keywords
# ============================================================================

fn is_keyword(word: str) -> bool:
    """Check if word is a keyword."""
    let keywords = [
        "fn", "contract", "struct", "enum", "interface", "trait",
        "if", "elif", "else", "while", "for", "in", "range",
        "return", "break", "continue", "pass",
        "let", "mut", "const",
        "true", "false", "None",
        "and", "or", "not",
        "import", "from", "as",
        "event", "error", "emit", "raise",
        "require", "revert", "assert",
        "match", "case", "when",
        "self", "Self",
        "pub", "private", "internal", "external",
        "view", "pure", "payable",
        "constructor", "modifier"
    ]
    
    for kw in keywords:
        if word == kw:
            return true
    return false

# ============================================================================
# Lexer
# ============================================================================

contract Lexer:
    """Tokenizes Quorlin source code with Python-style indentation."""
    
    source: str
    filename: str
    position: uint256
    line: uint256
    column: uint256
    indent_stack: Vec[uint256]
    tokens: Vec[Token]
    at_line_start: bool
    
    @constructor
    fn __init__(source: str, filename: str):
        """Create a new lexer."""
        self.source = source
        self.filename = filename
        self.position = 0
        self.line = 1
        self.column = 1
        self.indent_stack = Vec[uint256]()
        self.indent_stack.push(0)  # Base indentation level
        self.tokens = Vec[Token]()
        self.at_line_start = true
    
    @external
    fn tokenize() -> Result[Vec[Token], LexerError]:
        """Tokenize the entire source."""
        while not self.is_at_end():
            # Handle indentation at start of line
            if self.at_line_start:
                self.handle_indentation()?
                self.at_line_start = false
            
            # Skip whitespace (except newlines)
            self.skip_whitespace()
            
            if self.is_at_end():
                break
            
            # Get next token
            let token = self.next_token()?
            self.tokens.push(token)
        
        # Emit dedents for remaining indentation levels
        while self.indent_stack.len() > 1:
            self.indent_stack.pop()
            self.emit_token(TokenKind.Dedent, "")
        
        # Add EOF token
        self.emit_token(TokenKind.EOF, "")
        
        return Result.Ok(self.tokens)
    
    @internal
    fn next_token() -> Result[Token, LexerError]:
        """Get the next token."""
        let ch = self.current_char()
        
        # Comments
        if ch == "#":
            self.skip_comment()
            return self.next_token()
        
        # Newline
        if ch == "\n":
            self.advance()
            self.at_line_start = true
            return Result.Ok(self.make_token(TokenKind.Newline, "\n"))
        
        # Numbers
        if is_digit(ch):
            return self.tokenize_number()
        
        # Identifiers and keywords
        if is_alpha(ch) or ch == "_":
            return self.tokenize_identifier()
        
        # Strings
        if ch == '"' or ch == "'":
            return self.tokenize_string()
        
        # Operators and delimiters
        return self.tokenize_operator()
    
    @internal
    fn tokenize_number() -> Result[Token, LexerError]:
        """Tokenize a number literal."""
        let start = self.position
        let start_location = self.current_location()
        
        # Hex literal
        if self.current_char() == "0" and self.peek() == "x":
            self.advance()  # 0
            self.advance()  # x
            
            while not self.is_at_end():
                let ch = self.current_char()
                if is_digit(ch) or (ch >= "a" and ch <= "f") or (ch >= "A" and ch <= "F"):
                    self.advance()
                else:
                    break
        else:
            # Decimal literal
            while not self.is_at_end() and is_digit(self.current_char()):
                self.advance()
        
        let lexeme = str_substring(self.source, start, self.position)
        
        # Parse the number
        let value = parse_uint(lexeme)
        match value:
            Result.Ok(num):
                return Result.Ok(self.make_token(TokenKind.IntLiteral(num), lexeme))
            Result.Err(err):
                return Result.Err(LexerError.InvalidNumber(lexeme, start_location))
    
    @internal
    fn tokenize_identifier() -> Result[Token, LexerError]:
        """Tokenize an identifier or keyword."""
        let start = self.position
        
        while not self.is_at_end():
            let ch = self.current_char()
            if is_alphanumeric(ch) or ch == "_":
                self.advance()
            else:
                break
        
        let lexeme = str_substring(self.source, start, self.position)
        
        # Check for boolean literals
        if lexeme == "true":
            return Result.Ok(self.make_token(TokenKind.BoolLiteral(true), lexeme))
        elif lexeme == "false":
            return Result.Ok(self.make_token(TokenKind.BoolLiteral(false), lexeme))
        
        # Check if keyword
        if is_keyword(lexeme):
            return Result.Ok(self.make_token(TokenKind.Keyword(lexeme), lexeme))
        
        # Otherwise it's an identifier
        return Result.Ok(self.make_token(TokenKind.Identifier, lexeme))
    
    @internal
    fn tokenize_string() -> Result[Token, LexerError]:
        """Tokenize a string literal."""
        let start_location = self.current_location()
        let quote = self.current_char()
        self.advance()  # Opening quote
        
        let mut value = ""
        
        while not self.is_at_end():
            let ch = self.current_char()
            
            if ch == quote:
                self.advance()  # Closing quote
                return Result.Ok(self.make_token(TokenKind.StringLiteral(value), value))
            
            if ch == "\\":
                # Escape sequence
                self.advance()
                if self.is_at_end():
                    return Result.Err(LexerError.UnterminatedString(start_location))
                
                let escaped = self.current_char()
                match escaped:
                    "n":
                        value = value + "\n"
                    "t":
                        value = value + "\t"
                    "r":
                        value = value + "\r"
                    "\\":
                        value = value + "\\"
                    '"':
                        value = value + '"'
                    "'":
                        value = value + "'"
                    _:
                        value = value + escaped
                
                self.advance()
            else:
                value = value + ch
                self.advance()
        
        return Result.Err(LexerError.UnterminatedString(start_location))
    
    @internal
    fn tokenize_operator() -> Result[Token, LexerError]:
        """Tokenize operators and delimiters."""
        let ch = self.current_char()
        let next_ch = self.peek()
        
        # Two-character operators
        if ch == "-" and next_ch == ">":
            self.advance()
            self.advance()
            return Result.Ok(self.make_token(TokenKind.Arrow, "->"))
        
        if ch == "=" and next_ch == "=":
            self.advance()
            self.advance()
            return Result.Ok(self.make_token(TokenKind.Operator("=="), "=="))
        
        if ch == "!" and next_ch == "=":
            self.advance()
            self.advance()
            return Result.Ok(self.make_token(TokenKind.Operator("!="), "!="))
        
        if ch == "<" and next_ch == "=":
            self.advance()
            self.advance()
            return Result.Ok(self.make_token(TokenKind.Operator("<="), "<="))
        
        if ch == ">" and next_ch == "=":
            self.advance()
            self.advance()
            return Result.Ok(self.make_token(TokenKind.Operator(">="), ">="))
        
        if ch == "*" and next_ch == "*":
            self.advance()
            self.advance()
            return Result.Ok(self.make_token(TokenKind.Operator("**"), "**"))
        
        if ch == "/" and next_ch == "/":
            self.advance()
            self.advance()
            return Result.Ok(self.make_token(TokenKind.Operator("//"), "//"))
        
        if ch == "<" and next_ch == "<":
            self.advance()
            self.advance()
            return Result.Ok(self.make_token(TokenKind.Operator("<<"), "<<"))
        
        if ch == ">" and next_ch == ">":
            self.advance()
            self.advance()
            return Result.Ok(self.make_token(TokenKind.Operator(">>"), ">>"))
        
        # Single-character tokens
        self.advance()
        
        match ch:
            "(":
                return Result.Ok(self.make_token(TokenKind.LeftParen, "("))
            ")":
                return Result.Ok(self.make_token(TokenKind.RightParen, ")"))
            "[":
                return Result.Ok(self.make_token(TokenKind.LeftBracket, "["))
            "]":
                return Result.Ok(self.make_token(TokenKind.RightBracket, "]"))
            "{":
                return Result.Ok(self.make_token(TokenKind.LeftBrace, "{"))
            "}":
                return Result.Ok(self.make_token(TokenKind.RightBrace, "}"))
            ":":
                return Result.Ok(self.make_token(TokenKind.Colon, ":"))
            ",":
                return Result.Ok(self.make_token(TokenKind.Comma, ","))
            ".":
                return Result.Ok(self.make_token(TokenKind.Dot, "."))
            "+":
                return Result.Ok(self.make_token(TokenKind.Operator("+"), "+"))
            "-":
                return Result.Ok(self.make_token(TokenKind.Operator("-"), "-"))
            "*":
                return Result.Ok(self.make_token(TokenKind.Operator("*"), "*"))
            "/":
                return Result.Ok(self.make_token(TokenKind.Operator("/"), "/"))
            "%":
                return Result.Ok(self.make_token(TokenKind.Operator("%"), "%"))
            "=":
                return Result.Ok(self.make_token(TokenKind.Operator("="), "="))
            "<":
                return Result.Ok(self.make_token(TokenKind.Operator("<"), "<"))
            ">":
                return Result.Ok(self.make_token(TokenKind.Operator(">"), ">"))
            "!":
                return Result.Ok(self.make_token(TokenKind.Operator("!"), "!"))
            "&":
                return Result.Ok(self.make_token(TokenKind.Operator("&"), "&"))
            "|":
                return Result.Ok(self.make_token(TokenKind.Operator("|"), "|"))
            "^":
                return Result.Ok(self.make_token(TokenKind.Operator("^"), "^"))
            "~":
                return Result.Ok(self.make_token(TokenKind.Operator("~"), "~"))
            "@":
                return Result.Ok(self.make_token(TokenKind.Operator("@"), "@"))
            _:
                return Result.Err(LexerError.UnexpectedCharacter(ch, self.current_location()))
    
    @internal
    fn handle_indentation() -> Result[(), LexerError]:
        """Handle Python-style indentation."""
        let mut indent_level: uint256 = 0
        
        # Count spaces at start of line
        while not self.is_at_end():
            let ch = self.current_char()
            if ch == " ":
                indent_level = indent_level + 1
                self.advance()
            elif ch == "\t":
                indent_level = indent_level + 4  # Tab = 4 spaces
                self.advance()
            else:
                break
        
        # Skip empty lines and comments
        if self.is_at_end() or self.current_char() == "\n" or self.current_char() == "#":
            return Result.Ok(())
        
        # Get current indentation level
        let current_indent = self.indent_stack.last().unwrap()
        
        if indent_level > current_indent:
            # Indent
            self.indent_stack.push(indent_level)
            self.emit_token(TokenKind.Indent(indent_level), "")
        elif indent_level < current_indent:
            # Dedent (possibly multiple levels)
            while self.indent_stack.len() > 1 and self.indent_stack.last().unwrap() > indent_level:
                self.indent_stack.pop()
                self.emit_token(TokenKind.Dedent, "")
            
            # Check for indentation error
            if self.indent_stack.last().unwrap() != indent_level:
                return Result.Err(LexerError.IndentationError(
                    "Inconsistent indentation",
                    self.current_location()
                ))
        
        return Result.Ok(())
    
    @internal
    fn skip_whitespace():
        """Skip whitespace characters (except newlines)."""
        while not self.is_at_end():
            let ch = self.current_char()
            if ch == " " or ch == "\t" or ch == "\r":
                self.advance()
            else:
                break
    
    @internal
    fn skip_comment():
        """Skip comment until end of line."""
        while not self.is_at_end() and self.current_char() != "\n":
            self.advance()
    
    @internal
    fn current_char() -> str:
        """Get current character."""
        if self.is_at_end():
            return "\0"
        return str_char_at(self.source, self.position).unwrap_or("\0")
    
    @internal
    fn peek() -> str:
        """Peek at next character."""
        if self.position + 1 >= str_len(self.source):
            return "\0"
        return str_char_at(self.source, self.position + 1).unwrap_or("\0")
    
    @internal
    fn advance() -> str:
        """Advance position and return current character."""
        let ch = self.current_char()
        self.position = self.position + 1
        
        if ch == "\n":
            self.line = self.line + 1
            self.column = 1
        else:
            self.column = self.column + 1
        
        return ch
    
    @internal
    fn is_at_end() -> bool:
        """Check if at end of source."""
        return self.position >= str_len(self.source)
    
    @internal
    fn current_location() -> SourceLocation:
        """Get current source location."""
        return SourceLocation(
            file: self.filename,
            line: self.line,
            column: self.column,
            offset: self.position
        )
    
    @internal
    fn make_token(kind: TokenKind, lexeme: str) -> Token:
        """Create a token."""
        return Token(
            kind: kind,
            lexeme: lexeme,
            location: self.current_location()
        )
    
    @internal
    fn emit_token(kind: TokenKind, lexeme: str):
        """Emit a token to the token list."""
        self.tokens.push(self.make_token(kind, lexeme))

# ============================================================================
# Helper Functions
# ============================================================================

fn tokenize_source(source: str, filename: str) -> Result[Vec[Token], LexerError]:
    """Convenience function to tokenize source code."""
    let lexer = Lexer(source, filename)
    return lexer.tokenize()

fn print_tokens(tokens: Vec[Token]):
    """Print tokens for debugging."""
    for i in range(tokens.len()):
        let token = tokens.get(i).unwrap()
        println(token.to_string())
