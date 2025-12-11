# Quorlin Parser - Builds AST from tokens
# Recursive descent parser with operator precedence

from compiler.runtime.stdlib import Vec, HashMap, Option, Result
from compiler.frontend.ast import *
from compiler.frontend.lexer import Token, TokenKind, SourceLocation

# ============================================================================
# Parser Errors
# ============================================================================

enum ParseError:
    """Parser error types."""
    UnexpectedToken(expected: str, found: Token)
    UnexpectedEOF(expected: str)
    InvalidSyntax(message: str, location: SourceLocation)
    
    fn to_string() -> str:
        """Convert error to string."""
        match self:
            ParseError.UnexpectedToken(expected, found):
                return f"Expected {expected}, found {found.lexeme} at {found.location}"
            ParseError.UnexpectedEOF(expected):
                return f"Unexpected end of file, expected {expected}"
            ParseError.InvalidSyntax(msg, loc):
                return f"Invalid syntax: {msg} at {loc}"

# ============================================================================
# Parser
# ============================================================================

contract Parser:
    """Recursive descent parser for Quorlin."""
    
    tokens: Vec[Token]
    current: uint256
    
    @constructor
    fn __init__(tokens: Vec[Token]):
        """Create a new parser."""
        self.tokens = tokens
        self.current = 0
    
    @external
    fn parse() -> Result[Module, ParseError]:
        """Parse tokens into a module."""
        let mut items = Vec[Item]()
        let mut docstring: Option[str] = Option.None
        
        # Check for module docstring
        if self.check_string_literal():
            docstring = Option.Some(self.advance().lexeme)
            self.consume_newline()?
        
        # Parse top-level items
        while not self.is_at_end():
            self.skip_newlines()
            if self.is_at_end():
                break
            
            let item = self.parse_item()?
            items.push(item)
            self.skip_newlines()
        
        return Result.Ok(Module(
            name: "main",  # Will be set by caller
            items: items,
            docstring: docstring
        ))
    
    @internal
    fn parse_item() -> Result[Item, ParseError]:
        """Parse a top-level item."""
        # Import statement
        if self.match_keyword("from") or self.match_keyword("import"):
            return self.parse_import().map(|i| Item.Import(i))
        
        # Contract declaration
        if self.match_keyword("contract"):
            return self.parse_contract().map(|c| Item.Contract(c))
        
        # Struct declaration
        if self.match_keyword("struct"):
            return self.parse_struct().map(|s| Item.Struct(s))
        
        # Enum declaration
        if self.match_keyword("enum"):
            return self.parse_enum().map(|e| Item.Enum(e))
        
        # Interface declaration
        if self.match_keyword("interface"):
            return self.parse_interface().map(|i| Item.Interface(i))
        
        # Event declaration
        if self.match_keyword("event"):
            return self.parse_event().map(|e| Item.Event(e))
        
        # Error declaration
        if self.match_keyword("error"):
            return self.parse_error_decl().map(|e| Item.Error(e))
        
        # Function declaration
        if self.check_decorator() or self.match_keyword("fn"):
            return self.parse_function().map(|f| Item.Function(f))
        
        return Result.Err(ParseError.InvalidSyntax(
            "Expected item declaration",
            self.current_location()
        ))
    
    @internal
    fn parse_import() -> Result[ImportStmt, ParseError]:
        """Parse import statement."""
        let location = self.current_location()
        
        if self.match_keyword("from"):
            # from module import items
            let module = self.consume_identifier()?
            self.consume_keyword("import")?
            
            let mut items = Vec[str]()
            items.push(self.consume_identifier()?)
            
            while self.match_token(TokenKind.Comma):
                items.push(self.consume_identifier()?)
            
            self.consume_newline()?
            
            return Result.Ok(ImportStmt(
                module: module,
                items: items,
                location: location
            ))
        else:
            # import module
            self.consume_keyword("import")?
            let module = self.consume_identifier()?
            self.consume_newline()?
            
            return Result.Ok(ImportStmt(
                module: module,
                items: Vec[str](),
                location: location
            ))
    
    @internal
    fn parse_contract() -> Result[ContractDecl, ParseError]:
        """Parse contract declaration."""
        let location = self.current_location()
        self.consume_keyword("contract")?
        let name = self.consume_identifier()?
        
        # Parse inheritance
        let mut bases = Vec[str]()
        if self.match_token(TokenKind.Colon):
            bases.push(self.consume_identifier()?)
            while self.match_token(TokenKind.Comma):
                bases.push(self.consume_identifier()?)
        
        self.consume_token(TokenKind.Colon)?
        self.consume_newline()?
        self.consume_indent()?
        
        # Parse docstring
        let mut docstring: Option[str] = Option.None
        if self.check_string_literal():
            docstring = Option.Some(self.advance().lexeme)
            self.consume_newline()?
        
        # Parse contract members
        let mut state_vars = Vec[StateVar]()
        let mut functions = Vec[Function]()
        let mut events = Vec[EventDecl]()
        let mut errors = Vec[ErrorDecl]()
        
        while not self.check_dedent() and not self.is_at_end():
            self.skip_newlines()
            
            if self.check_dedent():
                break
            
            # Event
            if self.match_keyword("event"):
                events.push(self.parse_event()?)
            # Error
            elif self.match_keyword("error"):
                errors.push(self.parse_error_decl()?)
            # Function
            elif self.check_decorator() or self.match_keyword("fn"):
                functions.push(self.parse_function()?)
            # State variable
            else:
                state_vars.push(self.parse_state_var()?)
            
            self.skip_newlines()
        
        self.consume_dedent()?
        
        return Result.Ok(ContractDecl(
            name: name,
            bases: bases,
            state_vars: state_vars,
            functions: functions,
            events: events,
            errors: errors,
            docstring: docstring,
            location: location
        ))
    
    @internal
    fn parse_function() -> Result[Function, ParseError]:
        """Parse function declaration."""
        let location = self.current_location()
        
        # Parse decorators
        let mut decorators = Vec[str]()
        while self.check_decorator():
            self.consume_token(TokenKind.Operator("@"))?
            decorators.push(self.consume_identifier()?)
            self.consume_newline()?
        
        self.consume_keyword("fn")?
        let name = self.consume_identifier()?
        
        # Parse parameters
        self.consume_token(TokenKind.LeftParen)?
        let params = self.parse_parameters()?
        self.consume_token(TokenKind.RightParen)?
        
        # Parse return type
        let mut return_type: Option[Type] = Option.None
        if self.match_token(TokenKind.Arrow):
            return_type = Option.Some(self.parse_type()?)
        
        self.consume_token(TokenKind.Colon)?
        self.consume_newline()?
        
        # Parse body
        let body = self.parse_block()?
        
        return Result.Ok(Function(
            name: name,
            params: params,
            return_type: return_type,
            body: body,
            decorators: decorators,
            docstring: Option.None,
            location: location
        ))
    
    @internal
    fn parse_parameters() -> Result[Vec[Parameter], ParseError]:
        """Parse function parameters."""
        let mut params = Vec[Parameter]()
        
        if self.check_token(TokenKind.RightParen):
            return Result.Ok(params)
        
        loop:
            let name = self.consume_identifier()?
            self.consume_token(TokenKind.Colon)?
            let ty = self.parse_type()?
            
            params.push(Parameter(
                name: name,
                ty: ty,
                is_mutable: false,
                default_value: Option.None
            ))
            
            if not self.match_token(TokenKind.Comma):
                break
        
        return Result.Ok(params)
    
    @internal
    fn parse_type() -> Result[Type, ParseError]:
        """Parse type annotation."""
        let name = self.consume_identifier()?
        
        # Check for generic type parameters
        if self.match_token(TokenKind.LeftBracket):
            let mut type_params = Vec[Type]()
            type_params.push(self.parse_type()?)
            
            while self.match_token(TokenKind.Comma):
                type_params.push(self.parse_type()?)
            
            self.consume_token(TokenKind.RightBracket)?
            
            # Special handling for mapping
            if name == "mapping":
                if type_params.len() != 2:
                    return Result.Err(ParseError.InvalidSyntax(
                        "mapping requires exactly 2 type parameters",
                        self.current_location()
                    ))
                return Result.Ok(Type.Mapping(
                    Box.new(type_params.get(0).unwrap()),
                    Box.new(type_params.get(1).unwrap())
                ))
            
            return Result.Ok(Type.Generic(name, type_params))
        
        # Simple type
        return Result.Ok(Type.Simple(name))
    
    @internal
    fn parse_block() -> Result[Vec[Stmt], ParseError]:
        """Parse a block of statements."""
        self.consume_indent()?
        
        let mut stmts = Vec[Stmt]()
        
        while not self.check_dedent() and not self.is_at_end():
            self.skip_newlines()
            if self.check_dedent():
                break
            
            stmts.push(self.parse_statement()?)
            self.skip_newlines()
        
        self.consume_dedent()?
        
        return Result.Ok(stmts)
    
    @internal
    fn parse_statement() -> Result[Stmt, ParseError]:
        """Parse a statement."""
        let location = self.current_location()
        
        # Let statement
        if self.match_keyword("let"):
            return self.parse_let_statement()
        
        # If statement
        if self.match_keyword("if"):
            return self.parse_if_statement()
        
        # While loop
        if self.match_keyword("while"):
            return self.parse_while_statement()
        
        # For loop
        if self.match_keyword("for"):
            return self.parse_for_statement()
        
        # Return statement
        if self.match_keyword("return"):
            return self.parse_return_statement()
        
        # Break statement
        if self.match_keyword("break"):
            self.consume_newline()?
            return Result.Ok(Stmt.Break(location))
        
        # Continue statement
        if self.match_keyword("continue"):
            self.consume_newline()?
            return Result.Ok(Stmt.Continue(location))
        
        # Pass statement
        if self.match_keyword("pass"):
            self.consume_newline()?
            return Result.Ok(Stmt.Pass(location))
        
        # Require statement
        if self.match_keyword("require"):
            return self.parse_require_statement()
        
        # Revert statement
        if self.match_keyword("revert"):
            return self.parse_revert_statement()
        
        # Emit statement
        if self.match_keyword("emit"):
            return self.parse_emit_statement()
        
        # Expression statement or assignment
        let expr = self.parse_expression()?
        
        if self.match_token(TokenKind.Operator("=")):
            let value = self.parse_expression()?
            self.consume_newline()?
            return Result.Ok(Stmt.Assign(expr, value, location))
        
        self.consume_newline()?
        return Result.Ok(Stmt.ExprStmt(expr, location))
    
    @internal
    fn parse_expression() -> Result[Expr, ParseError]:
        """Parse expression with operator precedence."""
        return self.parse_or_expression()
    
    @internal
    fn parse_or_expression() -> Result[Expr, ParseError]:
        """Parse logical OR expression."""
        let mut left = self.parse_and_expression()?
        
        while self.match_keyword("or"):
            let location = self.current_location()
            let right = self.parse_and_expression()?
            left = Expr.BinOp(Box.new(left), BinOp.Or, Box.new(right), location)
        
        return Result.Ok(left)
    
    @internal
    fn parse_and_expression() -> Result[Expr, ParseError]:
        """Parse logical AND expression."""
        let mut left = self.parse_comparison_expression()?
        
        while self.match_keyword("and"):
            let location = self.current_location()
            let right = self.parse_comparison_expression()?
            left = Expr.BinOp(Box.new(left), BinOp.And, Box.new(right), location)
        
        return Result.Ok(left)
    
    @internal
    fn parse_comparison_expression() -> Result[Expr, ParseError]:
        """Parse comparison expression."""
        let mut left = self.parse_additive_expression()?
        
        while true:
            let location = self.current_location()
            let mut op: Option[BinOp] = Option.None
            
            if self.match_operator("=="):
                op = Option.Some(BinOp.Eq)
            elif self.match_operator("!="):
                op = Option.Some(BinOp.Ne)
            elif self.match_operator("<"):
                op = Option.Some(BinOp.Lt)
            elif self.match_operator("<="):
                op = Option.Some(BinOp.Le)
            elif self.match_operator(">"):
                op = Option.Some(BinOp.Gt)
            elif self.match_operator(">="):
                op = Option.Some(BinOp.Ge)
            
            match op:
                Option.Some(operator):
                    let right = self.parse_additive_expression()?
                    left = Expr.BinOp(Box.new(left), operator, Box.new(right), location)
                Option.None:
                    break
        
        return Result.Ok(left)
    
    @internal
    fn parse_additive_expression() -> Result[Expr, ParseError]:
        """Parse addition/subtraction expression."""
        let mut left = self.parse_multiplicative_expression()?
        
        while true:
            let location = self.current_location()
            let mut op: Option[BinOp] = Option.None
            
            if self.match_operator("+"):
                op = Option.Some(BinOp.Add)
            elif self.match_operator("-"):
                op = Option.Some(BinOp.Sub)
            
            match op:
                Option.Some(operator):
                    let right = self.parse_multiplicative_expression()?
                    left = Expr.BinOp(Box.new(left), operator, Box.new(right), location)
                Option.None:
                    break
        
        return Result.Ok(left)
    
    @internal
    fn parse_multiplicative_expression() -> Result[Expr, ParseError]:
        """Parse multiplication/division expression."""
        let mut left = self.parse_power_expression()?
        
        while true:
            let location = self.current_location()
            let mut op: Option[BinOp] = Option.None
            
            if self.match_operator("*"):
                op = Option.Some(BinOp.Mul)
            elif self.match_operator("/"):
                op = Option.Some(BinOp.Div)
            elif self.match_operator("%"):
                op = Option.Some(BinOp.Mod)
            
            match op:
                Option.Some(operator):
                    let right = self.parse_power_expression()?
                    left = Expr.BinOp(Box.new(left), operator, Box.new(right), location)
                Option.None:
                    break
        
        return Result.Ok(left)
    
    @internal
    fn parse_power_expression() -> Result[Expr, ParseError]:
        """Parse power expression."""
        let mut left = self.parse_unary_expression()?
        
        if self.match_operator("**"):
            let location = self.current_location()
            let right = self.parse_power_expression()?  # Right associative
            left = Expr.BinOp(Box.new(left), BinOp.Pow, Box.new(right), location)
        
        return Result.Ok(left)
    
    @internal
    fn parse_unary_expression() -> Result[Expr, ParseError]:
        """Parse unary expression."""
        let location = self.current_location()
        
        if self.match_operator("-"):
            let operand = self.parse_unary_expression()?
            return Result.Ok(Expr.UnaryOp(UnaryOp.Neg, Box.new(operand), location))
        
        if self.match_keyword("not"):
            let operand = self.parse_unary_expression()?
            return Result.Ok(Expr.UnaryOp(UnaryOp.Not, Box.new(operand), location))
        
        return self.parse_postfix_expression()
    
    @internal
    fn parse_postfix_expression() -> Result[Expr, ParseError]:
        """Parse postfix expression (calls, attributes, indexing)."""
        let mut expr = self.parse_primary_expression()?
        
        while true:
            let location = self.current_location()
            
            # Function call
            if self.match_token(TokenKind.LeftParen):
                let args = self.parse_arguments()?
                self.consume_token(TokenKind.RightParen)?
                expr = Expr.Call(Box.new(expr), args, location)
            # Attribute access
            elif self.match_token(TokenKind.Dot):
                let attr = self.consume_identifier()?
                expr = Expr.Attribute(Box.new(expr), attr, location)
            # Index access
            elif self.match_token(TokenKind.LeftBracket):
                let index = self.parse_expression()?
                self.consume_token(TokenKind.RightBracket)?
                expr = Expr.Index(Box.new(expr), Box.new(index), location)
            else:
                break
        
        return Result.Ok(expr)
    
    @internal
    fn parse_primary_expression() -> Result[Expr, ParseError]:
        """Parse primary expression."""
        let location = self.current_location()
        
        # Integer literal
        if self.check_int_literal():
            let token = self.advance()
            match token.kind:
                TokenKind.IntLiteral(value):
                    return Result.Ok(Expr.IntLit(value, location))
                _:
                    pass
        
        # String literal
        if self.check_string_literal():
            let token = self.advance()
            match token.kind:
                TokenKind.StringLiteral(value):
                    return Result.Ok(Expr.StringLit(value, location))
                _:
                    pass
        
        # Boolean literal
        if self.check_bool_literal():
            let token = self.advance()
            match token.kind:
                TokenKind.BoolLiteral(value):
                    return Result.Ok(Expr.BoolLit(value, location))
                _:
                    pass
        
        # None literal
        if self.match_keyword("None"):
            return Result.Ok(Expr.NoneLit(location))
        
        # Identifier
        if self.check_identifier():
            let name = self.advance().lexeme
            return Result.Ok(Expr.Ident(name, location))
        
        # Parenthesized expression
        if self.match_token(TokenKind.LeftParen):
            let expr = self.parse_expression()?
            self.consume_token(TokenKind.RightParen)?
            return Result.Ok(expr)
        
        # List literal
        if self.match_token(TokenKind.LeftBracket):
            let elements = self.parse_expression_list()?
            self.consume_token(TokenKind.RightBracket)?
            return Result.Ok(Expr.List(elements, location))
        
        return Result.Err(ParseError.InvalidSyntax(
            "Expected expression",
            location
        ))
    
    # ... Additional helper methods would continue here ...
    # (Token matching, consumption, error handling, etc.)
    
    @internal
    fn current_location() -> SourceLocation:
        """Get current source location."""
        if self.current < self.tokens.len():
            return self.tokens.get(self.current).unwrap().location
        return SourceLocation(file: "", line: 0, column: 0, offset: 0)
    
    @internal
    fn is_at_end() -> bool:
        """Check if at end of tokens."""
        return self.current >= self.tokens.len() or 
               self.peek().kind == TokenKind.EOF
    
    @internal
    fn peek() -> Token:
        """Peek at current token."""
        return self.tokens.get(self.current).unwrap()
    
    @internal
    fn advance() -> Token:
        """Advance to next token."""
        let token = self.peek()
        if not self.is_at_end():
            self.current = self.current + 1
        return token
    
    @internal
    fn match_keyword(keyword: str) -> bool:
        """Check and consume keyword."""
        if self.check_keyword(keyword):
            self.advance()
            return true
        return false
    
    @internal
    fn check_keyword(keyword: str) -> bool:
        """Check if current token is keyword."""
        if self.is_at_end():
            return false
        match self.peek().kind:
            TokenKind.Keyword(kw):
                return kw == keyword
            _:
                return false

# ============================================================================
# Helper Functions
# ============================================================================

fn parse_source(tokens: Vec[Token]) -> Result[Module, ParseError]:
    """Convenience function to parse tokens."""
    let parser = Parser(tokens)
    return parser.parse()
