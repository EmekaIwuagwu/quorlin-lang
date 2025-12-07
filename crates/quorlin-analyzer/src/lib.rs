//! Quorlin Static Analyzer
//!
//! Provides static analysis capabilities including:
//! - Type checking
//! - Security analysis
//! - Gas estimation
//! - Code quality lints

pub mod typeck;
pub mod security;
pub mod gas;
pub mod lints;

use quorlin_parser::ast::Module;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AnalyzerError {
    #[error("Type error: {0}")]
    TypeError(String),
    
    #[error("Security issue: {0}")]
    SecurityIssue(String),
    
    #[error("Lint error: {0}")]
    LintError(String),
}

/// Analysis result containing all findings
#[derive(Debug, Clone)]
pub struct AnalysisResult {
    pub type_errors: Vec<String>,
    pub security_issues: Vec<SecurityIssue>,
    pub gas_estimates: Vec<GasEstimate>,
    pub lint_warnings: Vec<LintWarning>,
}

#[derive(Debug, Clone)]
pub struct SecurityIssue {
    pub severity: Severity,
    pub category: SecurityCategory,
    pub message: String,
    pub location: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Severity {
    Critical,
    High,
    Medium,
    Low,
    Info,
}

#[derive(Debug, Clone)]
pub enum SecurityCategory {
    Reentrancy,
    IntegerOverflow,
    UncheckedCall,
    AccessControl,
    FrontRunning,
    TimestampDependence,
    Other(String),
}

#[derive(Debug, Clone)]
pub struct GasEstimate {
    pub function_name: String,
    pub estimated_gas: u64,
    pub complexity: GasComplexity,
}

#[derive(Debug, Clone)]
pub enum GasComplexity {
    Constant,
    Linear,
    Quadratic,
    Unknown,
}

#[derive(Debug, Clone)]
pub struct LintWarning {
    pub rule: String,
    pub message: String,
    pub location: Option<String>,
}

impl AnalysisResult {
    pub fn new() -> Self {
        Self {
            type_errors: Vec::new(),
            security_issues: Vec::new(),
            gas_estimates: Vec::new(),
            lint_warnings: Vec::new(),
        }
    }
    
    pub fn has_errors(&self) -> bool {
        !self.type_errors.is_empty() ||
        self.security_issues.iter().any(|i| matches!(i.severity, Severity::Critical | Severity::High))
    }
    
    pub fn has_warnings(&self) -> bool {
        !self.lint_warnings.is_empty() ||
        self.security_issues.iter().any(|i| matches!(i.severity, Severity::Medium | Severity::Low))
    }
}

/// Main analyzer struct
pub struct Analyzer {
    type_checker: typeck::TypeChecker,
    security_analyzer: security::SecurityAnalyzer,
    gas_estimator: gas::GasEstimator,
    linter: lints::Linter,
}

impl Analyzer {
    pub fn new() -> Self {
        Self {
            type_checker: typeck::TypeChecker::new(),
            security_analyzer: security::SecurityAnalyzer::new(),
            gas_estimator: gas::GasEstimator::new(),
            linter: lints::Linter::new(),
        }
    }
    
    /// Runs all analysis passes on a module
    pub fn analyze(&mut self, module: &Module) -> Result<AnalysisResult, AnalyzerError> {
        let mut result = AnalysisResult::new();
        
        // Type checking
        if let Err(errors) = self.type_checker.check(module) {
            result.type_errors = errors;
        }
        
        // Security analysis
        result.security_issues = self.security_analyzer.analyze(module);
        
        // Gas estimation
        result.gas_estimates = self.gas_estimator.estimate(module);
        
        // Linting
        result.lint_warnings = self.linter.lint(module);
        
        Ok(result)
    }
    
    /// Runs only type checking
    pub fn type_check(&mut self, module: &Module) -> Result<(), Vec<String>> {
        self.type_checker.check(module)
    }
    
    /// Runs only security analysis
    pub fn security_check(&mut self, module: &Module) -> Vec<SecurityIssue> {
        self.security_analyzer.analyze(module)
    }
    
    /// Runs only gas estimation
    pub fn estimate_gas(&mut self, module: &Module) -> Vec<GasEstimate> {
        self.gas_estimator.estimate(module)
    }
    
    /// Runs only linting
    pub fn lint(&mut self, module: &Module) -> Vec<LintWarning> {
        self.linter.lint(module)
    }
}

impl Default for Analyzer {
    fn default() -> Self {
        Self::new()
    }
}
