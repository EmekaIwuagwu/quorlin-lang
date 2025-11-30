/// Source code location
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
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

    pub fn merge(start: Span, end: Span) -> Self {
        Self {
            start: start.start,
            end: end.end,
            line: start.line,
            column: start.column,
        }
    }
}
