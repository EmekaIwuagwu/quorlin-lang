# Quorlin Runtime Standard Library
# Core data structures and utilities for the self-hosted compiler

# ============================================================================
# Option Type - Represents optional values
# ============================================================================

enum Option[T]:
    """Optional value that may or may not be present."""
    Some(T)
    None
    
    fn is_some() -> bool:
        """Check if option contains a value."""
        match self:
            Option.Some(_):
                return true
            Option.None:
                return false
    
    fn is_none() -> bool:
        """Check if option is None."""
        return not self.is_some()
    
    fn unwrap() -> T:
        """Get the value, panicking if None."""
        match self:
            Option.Some(value):
                return value
            Option.None:
                revert("Called unwrap on None")
    
    fn unwrap_or(default: T) -> T:
        """Get the value or return default."""
        match self:
            Option.Some(value):
                return value
            Option.None:
                return default
    
    fn map[U](f: fn(T) -> U) -> Option[U]:
        """Map a function over the option value."""
        match self:
            Option.Some(value):
                return Option.Some(f(value))
            Option.None:
                return Option.None
    
    fn and_then[U](f: fn(T) -> Option[U]) -> Option[U]:
        """Chain optional operations."""
        match self:
            Option.Some(value):
                return f(value)
            Option.None:
                return Option.None

# ============================================================================
# Result Type - Represents success or error
# ============================================================================

enum Result[T, E]:
    """Result of an operation that may fail."""
    Ok(T)
    Err(E)
    
    fn is_ok() -> bool:
        """Check if result is Ok."""
        match self:
            Result.Ok(_):
                return true
            Result.Err(_):
                return false
    
    fn is_err() -> bool:
        """Check if result is Err."""
        return not self.is_ok()
    
    fn unwrap() -> T:
        """Get the value, panicking if Err."""
        match self:
            Result.Ok(value):
                return value
            Result.Err(err):
                revert(f"Called unwrap on Err: {err}")
    
    fn unwrap_or(default: T) -> T:
        """Get the value or return default."""
        match self:
            Result.Ok(value):
                return value
            Result.Err(_):
                return default
    
    fn expect(message: str) -> T:
        """Get the value or panic with message."""
        match self:
            Result.Ok(value):
                return value
            Result.Err(err):
                revert(f"{message}: {err}")
    
    fn map[U](f: fn(T) -> U) -> Result[U, E]:
        """Map a function over the ok value."""
        match self:
            Result.Ok(value):
                return Result.Ok(f(value))
            Result.Err(err):
                return Result.Err(err)
    
    fn and_then[U](f: fn(T) -> Result[U, E]) -> Result[U, E]:
        """Chain result operations."""
        match self:
            Result.Ok(value):
                return f(value)
            Result.Err(err):
                return Result.Err(err)

# ============================================================================
# Vec - Dynamic array
# ============================================================================

contract Vec[T]:
    """Dynamic array with automatic resizing."""
    
    _items: list[T]
    _len: uint256
    _capacity: uint256
    
    @constructor
    fn __init__():
        """Create empty vector."""
        self._items = []
        self._len = 0
        self._capacity = 0
    
    @external
    fn push(item: T):
        """Add item to end of vector."""
        if self._len == self._capacity:
            self._grow()
        self._items[self._len] = item
        self._len = self._len + 1
    
    @external
    fn pop() -> Option[T]:
        """Remove and return last item."""
        if self._len == 0:
            return Option.None
        
        self._len = self._len - 1
        let item = self._items[self._len]
        return Option.Some(item)
    
    @view
    fn get(index: uint256) -> Option[T]:
        """Get item at index."""
        if index >= self._len:
            return Option.None
        return Option.Some(self._items[index])
    
    @external
    fn set(index: uint256, value: T) -> bool:
        """Set item at index."""
        if index >= self._len:
            return false
        self._items[index] = value
        return true
    
    @view
    fn len() -> uint256:
        """Get number of items."""
        return self._len
    
    @view
    fn is_empty() -> bool:
        """Check if vector is empty."""
        return self._len == 0
    
    @view
    fn capacity() -> uint256:
        """Get current capacity."""
        return self._capacity
    
    @external
    fn clear():
        """Remove all items."""
        self._len = 0
    
    @external
    fn reserve(additional: uint256):
        """Reserve capacity for at least additional more items."""
        let needed = self._len + additional
        if needed > self._capacity:
            self._grow_to(needed)
    
    @internal
    fn _grow():
        """Grow capacity by 2x or to 4 if empty."""
        let new_capacity = if self._capacity == 0: 4 else: self._capacity * 2
        self._grow_to(new_capacity)
    
    @internal
    fn _grow_to(new_capacity: uint256):
        """Grow to specific capacity."""
        # Allocate new array
        let new_items = list[T](new_capacity)
        
        # Copy existing items
        for i in range(self._len):
            new_items[i] = self._items[i]
        
        self._items = new_items
        self._capacity = new_capacity
    
    @view
    fn contains(item: T) -> bool:
        """Check if vector contains item."""
        for i in range(self._len):
            if self._items[i] == item:
                return true
        return false
    
    @external
    fn remove(index: uint256) -> Option[T]:
        """Remove item at index and shift remaining items."""
        if index >= self._len:
            return Option.None
        
        let item = self._items[index]
        
        # Shift items left
        for i in range(index, self._len - 1):
            self._items[i] = self._items[i + 1]
        
        self._len = self._len - 1
        return Option.Some(item)
    
    @external
    fn insert(index: uint256, item: T) -> bool:
        """Insert item at index."""
        if index > self._len:
            return false
        
        if self._len == self._capacity:
            self._grow()
        
        # Shift items right
        for i in range(self._len, index, -1):
            self._items[i] = self._items[i - 1]
        
        self._items[index] = item
        self._len = self._len + 1
        return true
    
    @view
    fn first() -> Option[T]:
        """Get first item."""
        if self._len == 0:
            return Option.None
        return Option.Some(self._items[0])
    
    @view
    fn last() -> Option[T]:
        """Get last item."""
        if self._len == 0:
            return Option.None
        return Option.Some(self._items[self._len - 1])

# ============================================================================
# HashMap - Hash table
# ============================================================================

struct Pair[K, V]:
    """Key-value pair."""
    key: K
    value: V

contract HashMap[K, V]:
    """Hash map with separate chaining."""
    
    _buckets: list[Vec[Pair[K, V]]]
    _len: uint256
    _num_buckets: uint256
    
    @constructor
    fn __init__():
        """Create empty hash map."""
        self._num_buckets = 16
        self._len = 0
        self._init_buckets()
    
    @internal
    fn _init_buckets():
        """Initialize bucket array."""
        self._buckets = list[Vec[Pair[K, V]]](self._num_buckets)
        for i in range(self._num_buckets):
            self._buckets[i] = Vec[Pair[K, V]]()
    
    @external
    fn insert(key: K, value: V):
        """Insert or update key-value pair."""
        let hash = self._hash(key)
        let bucket_idx = hash % self._num_buckets
        let bucket = self._buckets[bucket_idx]
        
        # Check if key exists
        for i in range(bucket.len()):
            let pair = bucket.get(i).unwrap()
            if pair.key == key:
                # Update existing
                bucket.set(i, Pair(key: key, value: value))
                return
        
        # Add new pair
        bucket.push(Pair(key: key, value: value))
        self._len = self._len + 1
        
        # Resize if load factor too high
        if self._len > self._num_buckets * 2:
            self._resize()
    
    @view
    fn get(key: K) -> Option[V]:
        """Get value for key."""
        let hash = self._hash(key)
        let bucket_idx = hash % self._num_buckets
        let bucket = self._buckets[bucket_idx]
        
        for i in range(bucket.len()):
            let pair = bucket.get(i).unwrap()
            if pair.key == key:
                return Option.Some(pair.value)
        
        return Option.None
    
    @view
    fn contains(key: K) -> bool:
        """Check if key exists."""
        return self.get(key).is_some()
    
    @external
    fn remove(key: K) -> Option[V]:
        """Remove key and return value."""
        let hash = self._hash(key)
        let bucket_idx = hash % self._num_buckets
        let bucket = self._buckets[bucket_idx]
        
        for i in range(bucket.len()):
            let pair = bucket.get(i).unwrap()
            if pair.key == key:
                bucket.remove(i)
                self._len = self._len - 1
                return Option.Some(pair.value)
        
        return Option.None
    
    @view
    fn len() -> uint256:
        """Get number of entries."""
        return self._len
    
    @view
    fn is_empty() -> bool:
        """Check if map is empty."""
        return self._len == 0
    
    @external
    fn clear():
        """Remove all entries."""
        self._init_buckets()
        self._len = 0
    
    @internal
    fn _hash(key: K) -> uint256:
        """Hash function for keys."""
        # Simple hash - in real implementation would use better hash
        # This is a placeholder that will be replaced with proper hashing
        return uint256(keccak256(abi.encode(key)))
    
    @internal
    fn _resize():
        """Resize hash map when load factor is high."""
        let old_buckets = self._buckets
        self._num_buckets = self._num_buckets * 2
        self._init_buckets()
        self._len = 0
        
        # Rehash all entries
        for i in range(len(old_buckets)):
            let bucket = old_buckets[i]
            for j in range(bucket.len()):
                let pair = bucket.get(j).unwrap()
                self.insert(pair.key, pair.value)

# ============================================================================
# String Operations
# ============================================================================

fn str_len(s: str) -> uint256:
    """Get string length."""
    # Native implementation
    return ffi_call("str_len", [s])

fn str_is_empty(s: str) -> bool:
    """Check if string is empty."""
    return str_len(s) == 0

fn str_contains(s: str, substr: str) -> bool:
    """Check if string contains substring."""
    return ffi_call("str_contains", [s, substr])

fn str_starts_with(s: str, prefix: str) -> bool:
    """Check if string starts with prefix."""
    return ffi_call("str_starts_with", [s, prefix])

fn str_ends_with(s: str, suffix: str) -> bool:
    """Check if string ends with suffix."""
    return ffi_call("str_ends_with", [s, suffix])

fn str_to_lowercase(s: str) -> str:
    """Convert string to lowercase."""
    return ffi_call("str_to_lowercase", [s])

fn str_to_uppercase(s: str) -> str:
    """Convert string to uppercase."""
    return ffi_call("str_to_uppercase", [s])

fn str_trim(s: str) -> str:
    """Trim whitespace from both ends."""
    return ffi_call("str_trim", [s])

fn str_trim_start(s: str) -> str:
    """Trim whitespace from start."""
    return ffi_call("str_trim_start", [s])

fn str_trim_end(s: str) -> str:
    """Trim whitespace from end."""
    return ffi_call("str_trim_end", [s])

fn str_split(s: str, delimiter: str) -> Vec[str]:
    """Split string by delimiter."""
    return ffi_call("str_split", [s, delimiter])

fn str_split_lines(s: str) -> Vec[str]:
    """Split string into lines."""
    return str_split(s, "\n")

fn str_join(parts: Vec[str], separator: str) -> str:
    """Join strings with separator."""
    return ffi_call("str_join", [parts, separator])

fn str_substring(s: str, start: uint256, end: uint256) -> str:
    """Get substring from start to end."""
    return ffi_call("str_substring", [s, start, end])

fn str_char_at(s: str, index: uint256) -> Option[str]:
    """Get character at index."""
    if index >= str_len(s):
        return Option.None
    return Option.Some(ffi_call("str_char_at", [s, index]))

fn str_format(template: str, args: Vec[str]) -> str:
    """Format string with arguments."""
    return ffi_call("str_format", [template, args])

fn str_replace(s: str, from: str, to: str) -> str:
    """Replace all occurrences."""
    return ffi_call("str_replace", [s, from, to])

fn str_repeat(s: str, count: uint256) -> str:
    """Repeat string count times."""
    let result = ""
    for i in range(count):
        result = result + s
    return result

# ============================================================================
# Character Classification
# ============================================================================

fn is_digit(ch: str) -> bool:
    """Check if character is a digit."""
    if str_len(ch) != 1:
        return false
    let code = char_code(ch)
    return code >= 48 and code <= 57  # '0' to '9'

fn is_alpha(ch: str) -> bool:
    """Check if character is alphabetic."""
    if str_len(ch) != 1:
        return false
    let code = char_code(ch)
    return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)  # A-Z or a-z

fn is_alphanumeric(ch: str) -> bool:
    """Check if character is alphanumeric."""
    return is_alpha(ch) or is_digit(ch)

fn is_whitespace(ch: str) -> bool:
    """Check if character is whitespace."""
    return ch == " " or ch == "\t" or ch == "\n" or ch == "\r"

fn char_code(ch: str) -> uint256:
    """Get ASCII/Unicode code of character."""
    return ffi_call("char_code", [ch])

fn from_char_code(code: uint256) -> str:
    """Create character from code."""
    return ffi_call("from_char_code", [code])

# ============================================================================
# Conversion Functions
# ============================================================================

fn to_string(value: uint256) -> str:
    """Convert integer to string."""
    if value == 0:
        return "0"
    
    let digits = Vec[str]()
    let mut n = value
    
    while n > 0:
        let digit = n % 10
        digits.push(from_char_code(48 + digit))  # '0' + digit
        n = n / 10
    
    # Reverse digits
    let result = ""
    for i in range(digits.len(), 0, -1):
        result = result + digits.get(i - 1).unwrap()
    
    return result

fn parse_uint(s: str) -> Result[uint256, str]:
    """Parse string as unsigned integer."""
    if str_is_empty(s):
        return Result.Err("Empty string")
    
    let mut result: uint256 = 0
    
    for i in range(str_len(s)):
        let ch = str_char_at(s, i).unwrap()
        if not is_digit(ch):
            return Result.Err(f"Invalid digit: {ch}")
        
        let digit = char_code(ch) - 48  # '0'
        result = result * 10 + digit
    
    return Result.Ok(result)

fn parse_int(s: str) -> Result[int256, str]:
    """Parse string as signed integer."""
    if str_is_empty(s):
        return Result.Err("Empty string")
    
    let mut negative = false
    let mut start = 0
    
    if str_starts_with(s, "-"):
        negative = true
        start = 1
    elif str_starts_with(s, "+"):
        start = 1
    
    let substr = str_substring(s, start, str_len(s))
    let unsigned_result = parse_uint(substr)?
    
    if negative:
        return Result.Ok(-(unsigned_result as int256))
    else:
        return Result.Ok(unsigned_result as int256)

# ============================================================================
# FFI Placeholder
# ============================================================================

fn ffi_call(name: str, args: Vec[any]) -> any:
    """Call foreign function interface."""
    # This will be implemented by the VM
    # Placeholder for now
    revert("FFI not implemented in this context")

# ============================================================================
# Box Type - Heap allocation
# ============================================================================

contract Box[T]:
    """Heap-allocated value."""
    
    _value: T
    
    @constructor
    fn __init__(value: T):
        """Create boxed value."""
        self._value = value
    
    @view
    fn get() -> T:
        """Get the value."""
        return self._value
    
    @external
    fn set(value: T):
        """Set the value."""
        self._value = value
    
    @view
    fn clone() -> Box[T]:
        """Clone the box."""
        return Box(self._value)

# Helper function
fn box_new[T](value: T) -> Box[T]:
    """Create a new box."""
    return Box(value)
