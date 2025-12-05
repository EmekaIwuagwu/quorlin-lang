fn main() {
    println!("Hello from Rust! 🦀");
    
    // A simple function call
    let result = add(5, 3);
    println!("5 + 3 = {}", result);
}

/// A simple addition function
fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_add() {
        assert_eq!(add(2, 2), 4);
        assert_eq!(add(-1, 1), 0);
    }
}