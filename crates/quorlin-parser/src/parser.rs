// Hand-written recursive descent parser for Quorlin
// LALRPOP struggles with Python-style indentation, so we use a custom parser

use crate::ast::*;
use crate::ParseError;
use quorlin_lexer::{Token, TokenType};

pub struct Parser {
    tokens: Vec<Token>,
    current: usize,
}

impl Parser {
    pub fn new(tokens: Vec<Token>) -> Self {
        Parser { tokens, current: 0 }
    }

    pub fn parse_module(&mut self) -> Result<Module, ParseError> {
        let mut items = Vec::new();

        // Skip leading newlines
        self.skip_newlines();

        while !self.is_at_end() && !self.check(&TokenType::Eof) {
            items.push(self.parse_item()?);
            self.skip_newlines();
        }

        Ok(Module { items })
    }

    fn parse_item(&mut self) -> Result<Item, ParseError> {
        self.skip_newlines();

        if self.check(&TokenType::From) {
            self.parse_import()
        } else if self.check(&TokenType::Event) {
            self.parse_event()
        } else if self.check(&TokenType::Contract) {
            self.parse_contract()
        } else {
            Err(ParseError::UnexpectedToken(
                self.current,
                format!("Expected item (from, contract, or event), found {:?}", self.peek()),
            ))
        }
    }

    fn parse_import(&mut self) -> Result<Item, ParseError> {
        self.consume(&TokenType::From, "Expected 'from'")?;

        // Parse module path (e.g., std.math)
        let mut module_path = Vec::new();
        module_path.push(self.consume_ident("Expected module name")?);

        while self.match_token(&TokenType::Dot) {
            module_path.push(self.consume_ident("Expected module component")?);
        }

        let module = module_path.join(".");

        self.consume(&TokenType::Import, "Expected 'import'")?;

        // Parse imported names
        let mut items = Vec::new();
        loop {
            items.push(self.consume_ident("Expected import name")?);
            if !self.match_token(&TokenType::Comma) {
                break;
            }
        }

        self.skip_newlines();

        Ok(Item::Import(ImportStmt { module, items }))
    }

    fn parse_event(&mut self) -> Result<Item, ParseError> {
        self.consume(&TokenType::Event, "Expected 'event'")?;
        let name = self.consume_ident("Expected event name")?;
        self.consume(&TokenType::LParen, "Expected '('")?;

        let mut params = Vec::new();
        if !self.check(&TokenType::RParen) {
            loop {
                let param_name = self.consume_ident("Expected parameter name")?;
                self.consume(&TokenType::Colon, "Expected ':'")?;
                let type_annotation = self.parse_type()?;

                params.push(EventParam {
                    name: param_name,
                    type_annotation,
                    indexed: false, // TODO: Handle indexed keyword
                });

                if !self.match_token(&TokenType::Comma) {
                    break;
                }
            }
        }

        self.consume(&TokenType::RParen, "Expected ')'")?;
        self.skip_newlines();

        Ok(Item::Event(EventDecl { name, params }))
    }

    fn parse_contract(&mut self) -> Result<Item, ParseError> {
        self.consume(&TokenType::Contract, "Expected 'contract'")?;
        let name = self.consume_ident("Expected contract name")?;
        self.consume(&TokenType::Colon, "Expected ':'")?;
        self.skip_newlines();
        self.consume(&TokenType::Indent, "Expected indented block")?;

        let mut body = Vec::new();
        while !self.check(&TokenType::Dedent) && !self.is_at_end() {
            body.push(self.parse_contract_member()?);
            self.skip_newlines();
        }

        self.consume(&TokenType::Dedent, "Expected dedent")?;

        Ok(Item::Contract(ContractDecl {
            name,
            bases: vec![],
            body,
            docstring: None,
        }))
    }

    fn parse_contract_member(&mut self) -> Result<ContractMember, ParseError> {
        self.skip_newlines();

        // Skip docstrings at the module/contract level
        while let Some(token) = self.peek() {
            if let TokenType::DocString(_) = token.token_type {
                self.advance(); // Skip docstring
                self.skip_newlines();
            } else {
                break;
            }
        }

        // Check for decorator
        let has_decorator = self.check(&TokenType::At);
        let mut decorators = Vec::new();

        if has_decorator {
            self.advance(); // consume @
            decorators.push(self.consume_ident("Expected decorator name")?);
            self.skip_newlines();
        }

        if self.check(&TokenType::Def) {
            self.parse_function(decorators)
        } else {
            // State variable: name: type = value
            let name = self.consume_ident("Expected state variable or function")?;
            self.consume(&TokenType::Colon, "Expected ':'")?;
            let type_annotation = self.parse_type()?;

            let initial_value = if self.match_token(&TokenType::Eq) {
                Some(self.parse_expr()?)
            } else {
                None
            };

            self.skip_newlines();

            Ok(ContractMember::StateVar(StateVar {
                name,
                type_annotation,
                initial_value,
            }))
        }
    }

    fn parse_function(&mut self, decorators: Vec<String>) -> Result<ContractMember, ParseError> {
        self.consume(&TokenType::Def, "Expected 'def'")?;
        let name = self.consume_ident("Expected function name")?;
        self.consume(&TokenType::LParen, "Expected '('")?;

        let mut params = Vec::new();
        if !self.check(&TokenType::RParen) {
            loop {
                let param_name = self.consume_ident("Expected parameter name")?;
                self.consume(&TokenType::Colon, "Expected ':'")?;
                let type_annotation = self.parse_type()?;

                params.push(Param {
                    name: param_name,
                    type_annotation,
                    default: None,
                });

                if !self.match_token(&TokenType::Comma) {
                    break;
                }
            }
        }

        self.consume(&TokenType::RParen, "Expected ')'")?;

        let return_type = if self.match_token(&TokenType::Arrow) {
            Some(self.parse_type()?)
        } else {
            None
        };

        self.consume(&TokenType::Colon, "Expected ':'")?;
        self.skip_newlines();
        self.consume(&TokenType::Indent, "Expected indented function body")?;

        let mut body = Vec::new();
        while !self.check(&TokenType::Dedent) && !self.is_at_end() {
            body.push(self.parse_stmt()?);
            self.skip_newlines();
        }

        self.consume(&TokenType::Dedent, "Expected dedent")?;

        Ok(ContractMember::Function(Function {
            name,
            decorators,
            params,
            return_type,
            body,
            docstring: None,
        }))
    }

    fn parse_stmt(&mut self) -> Result<Stmt, ParseError> {
        self.skip_newlines();

        // Skip docstrings at statement level
        while let Some(token) = self.peek() {
            if let TokenType::DocString(_) = token.token_type {
                self.advance(); // Skip docstring
                self.skip_newlines();
            } else {
                break;
            }
        }

        if self.match_token(&TokenType::Return) {
            let value = if self.check(&TokenType::Newline) {
                None
            } else {
                Some(self.parse_expr()?)
            };
            self.skip_newlines();
            Ok(Stmt::Return(value))
        } else if self.match_token(&TokenType::Pass) {
            self.skip_newlines();
            Ok(Stmt::Pass)
        } else if self.match_token(&TokenType::Emit) {
            // emit EventName(args)
            let event = self.consume_ident("Expected event name")?;
            self.consume(&TokenType::LParen, "Expected '('")?;

            let mut args = Vec::new();
            if !self.check(&TokenType::RParen) {
                loop {
                    args.push(self.parse_expr()?);
                    if !self.match_token(&TokenType::Comma) {
                        break;
                    }
                }
            }

            self.consume(&TokenType::RParen, "Expected ')'")?;
            self.skip_newlines();

            Ok(Stmt::Emit(EmitStmt { event, args }))
        } else if self.match_token(&TokenType::Require) {
            // require(condition, error_message)
            self.consume(&TokenType::LParen, "Expected '('")?;
            let condition = self.parse_expr()?;

            let message = if self.match_token(&TokenType::Comma) {
                let msg_expr = self.parse_expr()?;
                // Extract string from string literal expression
                match msg_expr {
                    Expr::StringLiteral(s) => Some(s),
                    _ => Some("Requirement failed".to_string()), // Default message
                }
            } else {
                None
            };

            self.consume(&TokenType::RParen, "Expected ')'")?;
            self.skip_newlines();

            Ok(Stmt::Require(RequireStmt { condition, message }))
        } else if self.check(&TokenType::SelfKw) || self.check_ident() {
            // Parse assignment: target = value
            // Target could be: name, self.attr, self.attr[index], self.attr[i][j], etc.
            // For now, we'll parse it as an expression and extract the identifier

            // Start with identifier or self
            let target_start = if self.match_token(&TokenType::SelfKw) {
                self.consume(&TokenType::Dot, "Expected '.' after 'self'")?;
                self.consume_ident("Expected attribute name")?
            } else {
                self.consume_ident("Expected identifier")?
            };

            // Handle any number of index operations: [expr], [expr][expr], etc.
            while self.match_token(&TokenType::LBracket) {
                self.parse_expr()?; // Parse and discard index expression
                self.consume(&TokenType::RBracket, "Expected ']'")?;
            }

            // Check for assignment operator: =, +=, -=, *=, /=
            let op = if self.match_token(&TokenType::Eq) {
                None // Simple assignment
            } else if self.match_token(&TokenType::PlusEq) {
                Some(BinOp::Add)
            } else if self.match_token(&TokenType::MinusEq) {
                Some(BinOp::Sub)
            } else if self.match_token(&TokenType::StarEq) {
                Some(BinOp::Mul)
            } else if self.match_token(&TokenType::SlashEq) {
                Some(BinOp::Div)
            } else {
                return Err(ParseError::UnexpectedToken(
                    self.current,
                    format!("Expected assignment operator, found {:?}", self.peek()),
                ));
            };

            let mut value = self.parse_expr()?;
            self.skip_newlines();

            // For augmented assignments (+=, -=, etc.), convert to: target = target op value
            if let Some(binop) = op {
                value = Expr::BinOp(
                    Box::new(Expr::Ident(target_start.clone())),
                    binop,
                    Box::new(value),
                );
            }

            Ok(Stmt::Assign(AssignStmt {
                target: target_start,
                type_annotation: None,
                value,
            }))
        } else {
            Err(ParseError::UnexpectedToken(
                self.current,
                format!("Expected statement, found {:?}", self.peek()),
            ))
        }
    }

    fn parse_expr(&mut self) -> Result<Expr, ParseError> {
        self.parse_comparison()
    }

    fn parse_comparison(&mut self) -> Result<Expr, ParseError> {
        let mut expr = self.parse_postfix()?;

        // Handle binary operators: ==, !=, <, >, <=, >=, +, -, *, /, etc.
        while let Some(token) = self.peek() {
            let op = match &token.token_type {
                TokenType::EqEq => BinOp::Eq,
                TokenType::NotEq => BinOp::NotEq,
                TokenType::Lt => BinOp::Lt,
                TokenType::Gt => BinOp::Gt,
                TokenType::LtEq => BinOp::LtEq,
                TokenType::GtEq => BinOp::GtEq,
                TokenType::Plus => BinOp::Add,
                TokenType::Minus => BinOp::Sub,
                TokenType::Star => BinOp::Mul,
                TokenType::Slash => BinOp::Div,
                _ => break,
            };

            self.advance();
            let right = self.parse_postfix()?;
            expr = Expr::BinOp(Box::new(expr), op, Box::new(right));
        }

        Ok(expr)
    }

    fn parse_postfix(&mut self) -> Result<Expr, ParseError> {
        // Parse primary expression
        let mut expr = self.parse_primary()?;

        // Handle postfix operations: ., (), and []
        loop {
            if self.match_token(&TokenType::Dot) {
                let attr = self.consume_ident("Expected attribute name")?;
                expr = Expr::Attribute(Box::new(expr), attr);
            } else if self.check(&TokenType::LParen) {
                self.advance();
                let mut args = Vec::new();

                if !self.check(&TokenType::RParen) {
                    loop {
                        args.push(self.parse_expr()?);
                        if !self.match_token(&TokenType::Comma) {
                            break;
                        }
                    }
                }

                self.consume(&TokenType::RParen, "Expected ')'")?;
                expr = Expr::Call(Box::new(expr), args);
            } else if self.match_token(&TokenType::LBracket) {
                let index = self.parse_expr()?;
                self.consume(&TokenType::RBracket, "Expected ']'")?;
                expr = Expr::Index(Box::new(expr), Box::new(index));
            } else {
                break;
            }
        }

        Ok(expr)
    }

    fn parse_primary(&mut self) -> Result<Expr, ParseError> {
        if let Some(token) = self.peek() {
            match &token.token_type {
                TokenType::IntLiteral(n) => {
                    let val = n.clone();
                    self.advance();
                    Ok(Expr::IntLiteral(val))
                }
                TokenType::StringLiteral(s) => {
                    let val = s.clone();
                    self.advance();
                    Ok(Expr::StringLiteral(val))
                }
                TokenType::True => {
                    self.advance();
                    Ok(Expr::BoolLiteral(true))
                }
                TokenType::False => {
                    self.advance();
                    Ok(Expr::BoolLiteral(false))
                }
                TokenType::None => {
                    self.advance();
                    Ok(Expr::NoneLiteral)
                }
                TokenType::Ident(name) => {
                    let name = name.clone();
                    self.advance();
                    Ok(Expr::Ident(name))
                }
                TokenType::SelfKw => {
                    self.advance();
                    Ok(Expr::Ident("self".to_string()))
                }
                // Handle type names used as constructors: address(0), uint256(x)
                TokenType::Address => {
                    self.advance();
                    Ok(Expr::Ident("address".to_string()))
                }
                TokenType::Bool => {
                    self.advance();
                    Ok(Expr::Ident("bool".to_string()))
                }
                TokenType::Str => {
                    self.advance();
                    Ok(Expr::Ident("str".to_string()))
                }
                TokenType::Uint(size) => {
                    let size = size.clone();
                    self.advance();
                    Ok(Expr::Ident(size))
                }
                _ => Err(ParseError::UnexpectedToken(
                    self.current,
                    format!("Expected expression, found {:?}", token.token_type),
                )),
            }
        } else {
            Err(ParseError::UnexpectedEof)
        }
    }

    fn parse_type(&mut self) -> Result<Type, ParseError> {
        if let Some(token) = self.peek() {
            match &token.token_type {
                TokenType::Bool => {
                    self.advance();
                    Ok(Type::Simple("bool".to_string()))
                }
                TokenType::Address => {
                    self.advance();
                    Ok(Type::Simple("address".to_string()))
                }
                TokenType::Str => {
                    self.advance();
                    Ok(Type::Simple("str".to_string()))
                }
                TokenType::Uint(size) => {
                    let size = size.clone();
                    self.advance();
                    Ok(Type::Simple(size))
                }
                TokenType::Mapping => {
                    self.advance();
                    self.consume(&TokenType::LBracket, "Expected '['")?;
                    let key = self.parse_type()?;
                    self.consume(&TokenType::Comma, "Expected ','")?;
                    let value = self.parse_type()?;
                    self.consume(&TokenType::RBracket, "Expected ']'")?;
                    Ok(Type::Mapping(Box::new(key), Box::new(value)))
                }
                TokenType::List => {
                    self.advance();
                    self.consume(&TokenType::LBracket, "Expected '['")?;
                    let elem_type = self.parse_type()?;
                    self.consume(&TokenType::RBracket, "Expected ']'")?;
                    Ok(Type::List(Box::new(elem_type)))
                }
                TokenType::Ident(name) => {
                    let name = name.clone();
                    self.advance();
                    Ok(Type::Simple(name))
                }
                _ => Err(ParseError::UnexpectedToken(
                    self.current,
                    format!("Expected type, found {:?}", token.token_type),
                )),
            }
        } else {
            Err(ParseError::UnexpectedEof)
        }
    }

    // Helper methods
    fn skip_newlines(&mut self) {
        while self.match_token(&TokenType::Newline) {
            // consumed
        }
    }

    fn match_token(&mut self, token_type: &TokenType) -> bool {
        if self.check(token_type) {
            self.advance();
            true
        } else {
            false
        }
    }

    fn check(&self, token_type: &TokenType) -> bool {
        if let Some(token) = self.peek() {
            std::mem::discriminant(&token.token_type) == std::mem::discriminant(token_type)
        } else {
            false
        }
    }

    fn check_ident(&self) -> bool {
        if let Some(token) = self.peek() {
            matches!(token.token_type, TokenType::Ident(_))
        } else {
            false
        }
    }

    fn advance(&mut self) -> Option<&Token> {
        if !self.is_at_end() {
            self.current += 1;
        }
        self.previous()
    }

    fn is_at_end(&self) -> bool {
        self.current >= self.tokens.len()
    }

    fn peek(&self) -> Option<&Token> {
        self.tokens.get(self.current)
    }

    fn previous(&self) -> Option<&Token> {
        if self.current > 0 {
            self.tokens.get(self.current - 1)
        } else {
            None
        }
    }

    fn consume(&mut self, token_type: &TokenType, message: &str) -> Result<(), ParseError> {
        if self.check(token_type) {
            self.advance();
            Ok(())
        } else {
            Err(ParseError::UnexpectedToken(
                self.current,
                format!("{}, found {:?}", message, self.peek()),
            ))
        }
    }

    fn consume_ident(&mut self, message: &str) -> Result<String, ParseError> {
        if let Some(token) = self.peek() {
            if let TokenType::Ident(name) = &token.token_type {
                let name = name.clone();
                self.advance();
                Ok(name)
            } else {
                Err(ParseError::UnexpectedToken(
                    self.current,
                    format!("{}, found {:?}", message, token.token_type),
                ))
            }
        } else {
            Err(ParseError::UnexpectedEof)
        }
    }
}
