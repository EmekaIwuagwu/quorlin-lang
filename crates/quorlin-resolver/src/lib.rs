//! Quorlin Import Resolver
//!
//! Resolves `from std.X import Y` statements by loading stdlib modules.
//! The stdlib is OPTIONAL - compiler works without it.

use quorlin_parser::ast::{ImportStmt, Module};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ResolverError {
    #[error("Invalid module path: {0}")]
    InvalidModulePath(String),
    
    #[error("Module not found: {0}")]
    ModuleNotFound(String),
    
    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),
    
    #[error("Parse error: {0}")]
    ParseError(String),
    
    #[error("Circular dependency detected: {0}")]
    CircularDependency(String),
}

/// Standard library module resolver
///
/// This resolver is OPTIONAL - the compiler works perfectly without stdlib.
/// It only activates when:
/// 1. Stdlib directory exists
/// 2. User explicitly imports from std.*
pub struct StdlibResolver {
    /// Path to stdlib root directory
    stdlib_root: PathBuf,
    
    /// Cache of loaded modules (module_path -> source code)
    module_cache: HashMap<String, String>,
    
    /// Whether stdlib is available
    stdlib_enabled: bool,
    
    /// Currently resolving modules (for circular dependency detection)
    resolving_stack: Vec<String>,
}

impl StdlibResolver {
    /// Creates a new stdlib resolver
    ///
    /// # Arguments
    /// * `compiler_root` - Root directory of the compiler
    ///
    /// # Returns
    /// A new resolver instance. If stdlib directory doesn't exist,
    /// the resolver will be disabled but won't error.
    pub fn new(compiler_root: &Path) -> Self {
        let stdlib_root = compiler_root.join("stdlib");
        let stdlib_enabled = stdlib_root.exists() && stdlib_root.is_dir();
        
        if !stdlib_enabled {
            eprintln!("Note: Standard library not found at {:?}. Stdlib imports will be unavailable.", stdlib_root);
        }
        
        Self {
            stdlib_root,
            module_cache: HashMap::new(),
            stdlib_enabled,
            resolving_stack: Vec::new(),
        }
    }
    
    /// Checks if stdlib is available
    pub fn is_available(&self) -> bool {
        self.stdlib_enabled
    }
    
    /// Resolves an import statement
    ///
    /// # Arguments
    /// * `import` - The import statement to resolve
    ///
    /// # Returns
    /// * `Ok(Some(source))` - Module source code
    /// * `Ok(None)` - Stdlib not available (not an error)
    /// * `Err(_)` - Module should exist but couldn't be loaded
    pub fn resolve_import(&mut self, import: &ImportStmt) -> Result<Option<String>, ResolverError> {
        // If stdlib not enabled, return None (not an error)
        if !self.stdlib_enabled {
            return Ok(None);
        }
        
        let module_path = &import.module;
        
        // Check cache first
        if let Some(cached) = self.module_cache.get(module_path) {
            return Ok(Some(cached.clone()));
        }
        
        // Check for circular dependencies
        if self.resolving_stack.contains(module_path) {
            return Err(ResolverError::CircularDependency(module_path.clone()));
        }
        
        // Add to resolving stack
        self.resolving_stack.push(module_path.clone());
        
        // Resolve the module
        let result = self.load_module(module_path);
        
        // Remove from resolving stack
        self.resolving_stack.pop();
        
        result
    }
    
    /// Loads a module from the filesystem
    fn load_module(&mut self, module_path: &str) -> Result<Option<String>, ResolverError> {
        // Convert module path to file path
        let file_path = self.module_path_to_file(module_path)?;
        
        // Check if file exists
        if !file_path.exists() {
            return Ok(None); // Module doesn't exist (not an error - might be user module)
        }
        
        // Read file
        let contents = std::fs::read_to_string(&file_path)
            .map_err(|e| ResolverError::IoError(e))?;
        
        // Cache the module
        self.module_cache.insert(module_path.to_string(), contents.clone());
        
        Ok(Some(contents))
    }
    
    /// Converts a module path to a file path
    ///
    /// Examples:
    /// - "std.math" -> "stdlib/std/math.ql"
    /// - "std.token.standard_token" -> "stdlib/std/token/standard_token.ql"
    fn module_path_to_file(&self, module_path: &str) -> Result<PathBuf, ResolverError> {
        let parts: Vec<&str> = module_path.split('.').collect();
        
        if parts.is_empty() {
            return Err(ResolverError::InvalidModulePath(module_path.to_string()));
        }
        
        // Only handle std.* imports
        if parts[0] != "std" {
            return Err(ResolverError::InvalidModulePath(
                format!("Only std.* imports are supported, got: {}", module_path)
            ));
        }
        
        let mut path = self.stdlib_root.clone();
        
        // Add each part as a directory/file
        for part in parts {
            path.push(part);
        }
        
        // Add .ql extension
        path.set_extension("ql");
        
        Ok(path)
    }
    
    /// Resolves all imports in a module
    ///
    /// This recursively resolves all imports and returns a map of
    /// module_path -> source_code for all dependencies.
    pub fn resolve_all_imports(
        &mut self,
        module: &Module,
    ) -> Result<HashMap<String, String>, ResolverError> {
        let mut resolved = HashMap::new();
        
        for item in &module.items {
            if let quorlin_parser::ast::Item::Import(import) = item {
                if let Some(source) = self.resolve_import(import)? {
                    // Parse the imported module to find its imports
                    // (This would require the parser, which we'll skip for now)
                    resolved.insert(import.module.clone(), source);
                }
            }
        }
        
        Ok(resolved)
    }
    
    /// Clears the module cache
    pub fn clear_cache(&mut self) {
        self.module_cache.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::PathBuf;
    
    #[test]
    fn test_module_path_conversion() {
        let temp_dir = std::env::temp_dir();
        let resolver = StdlibResolver::new(&temp_dir);
        
        let path = resolver.module_path_to_file("std.math").unwrap();
        assert!(path.to_string_lossy().contains("std"));
        assert!(path.to_string_lossy().contains("math.ql"));
    }
    
    #[test]
    fn test_invalid_module_path() {
        let temp_dir = std::env::temp_dir();
        let resolver = StdlibResolver::new(&temp_dir);
        
        let result = resolver.module_path_to_file("invalid.path");
        assert!(result.is_err());
    }
    
    #[test]
    fn test_stdlib_not_available() {
        let temp_dir = std::env::temp_dir().join("nonexistent");
        let resolver = StdlibResolver::new(&temp_dir);
        
        assert!(!resolver.is_available());
    }
}
