# Quorlin Self-Hosting Quick Reference

**Quick Links**: [Roadmap](SELF_HOSTING_ROADMAP.md) | [Progress](SELF_HOSTING_PHASE1_PROGRESS.md) | [Language Spec](docs/LANGUAGE_SUBSET.md) | [IR Spec](docs/IR_SPECIFICATION.md) | [Runtime](docs/RUNTIME_ARCHITECTURE.md)

---

## 🚀 Quick Start

### For Contributors

```bash
# 1. Review architecture
cat SELF_HOSTING_ROADMAP.md
cat docs/LANGUAGE_SUBSET.md

# 2. Check current progress
cat SELF_HOSTING_PHASE1_PROGRESS.md

# 3. Start implementing
# See "Implementation Checklist" below
```

### For Users (After Bootstrap)

```bash
# Compile a contract with self-hosted compiler
./qlc-selfhosted compile mycontract.ql --target evm -o output.yul

# No Rust toolchain needed!
```

---

## 📋 Implementation Checklist

### Phase 1: Foundation (Weeks 1-4) - 40% COMPLETE

#### Week 1 ✅ DONE
- [x] Create SELF_HOSTING_ROADMAP.md
- [x] Create LANGUAGE_SUBSET.md
- [x] Create IR_SPECIFICATION.md
- [x] Create RUNTIME_ARCHITECTURE.md
- [x] Create compiler directory structure
- [x] Implement compiler/frontend/ast.ql

#### Week 2 🔄 IN PROGRESS
- [ ] Implement compiler/runtime/stdlib.ql
  - [ ] Vec[T] implementation
  - [ ] HashMap[K,V] implementation
  - [ ] Option[T] and Result[T,E]
  - [ ] String operations
- [ ] Implement compiler/frontend/lexer.ql
  - [ ] Token recognition
  - [ ] Indentation handling
  - [ ] Location tracking
  - [ ] Error reporting
- [ ] Test lexer with examples/*.ql

#### Week 3 ⏳ PENDING
- [ ] Implement compiler/frontend/parser.ql
  - [ ] Recursive descent structure
  - [ ] Expression parsing
  - [ ] Statement parsing
  - [ ] Declaration parsing
- [ ] Test parser with examples/*.ql

#### Week 4 ⏳ PENDING
- [ ] Implement compiler/middle/semantic.ql
  - [ ] Symbol table
  - [ ] Type checking
  - [ ] Name resolution
- [ ] Implement compiler/middle/ir_builder.ql
  - [ ] AST to IR lowering
  - [ ] Basic block construction
- [ ] Create bootstrap test framework
- [ ] Phase 1 completion review

### Phase 2: Frontend (Weeks 5-10) - 0% COMPLETE

- [ ] Complete lexer with all features
- [ ] Complete parser with full grammar
- [ ] Complete semantic analyzer
- [ ] Implement security analysis
- [ ] Test with all examples/*.ql
- [ ] Verify output matches Rust compiler

### Phase 3: Middle-End (Weeks 11-14) - 0% COMPLETE

- [ ] Complete IR generation
- [ ] Implement optimization passes
- [ ] Add IR serialization
- [ ] Test IR correctness

### Phase 4: Backends (Weeks 15-20) - 0% COMPLETE

- [ ] Port EVM backend to Quorlin
- [ ] Port Solana backend to Quorlin
- [ ] Port Polkadot backend to Quorlin
- [ ] Port Aptos backend to Quorlin
- [ ] **Implement Quorlin self-target** ⭐
- [ ] Test all backends

### Phase 5: Bootstrap (Weeks 21-24) - 0% COMPLETE

- [ ] Create bootstrap scripts
- [ ] Achieve Stage 1 self-compilation
- [ ] Verify Stage 1 == Stage 2
- [ ] Test all examples compile

### Phase 6: Testing (Weeks 25-28) - 0% COMPLETE

- [ ] End-to-end EVM tests
- [ ] End-to-end Solana tests
- [ ] End-to-end Polkadot tests
- [ ] End-to-end Aptos tests
- [ ] Security validation
- [ ] Performance benchmarks

### Phase 7: Independence (Weeks 29-32) - 0% COMPLETE

- [ ] Remove Rust dependencies
- [ ] Create distribution packages
- [ ] Write installation guides
- [ ] Setup CI/CD
- [ ] Release v2.0.0 🎉

---

## 🎯 Current Focus: Week 2

### Priority 1: Runtime Standard Library

**File**: `compiler/runtime/stdlib.ql`

**Tasks**:
1. Implement Vec[T]
2. Implement HashMap[K,V]
3. Implement Option[T]
4. Implement Result[T,E]
5. Implement string operations

**Example**:
```quorlin
contract Vec[T]:
    _items: list[T]
    _len: uint256
    _capacity: uint256
    
    @constructor
    fn __init__():
        self._items = []
        self._len = 0
        self._capacity = 0
    
    @external
    fn push(item: T):
        if self._len == self._capacity:
            self._grow()
        self._items[self._len] = item
        self._len = self._len + 1
    
    @view
    fn len() -> uint256:
        return self._len
```

### Priority 2: Lexer Implementation

**File**: `compiler/frontend/lexer.ql`

**Tasks**:
1. Implement token recognition
2. Handle Python-style indentation
3. Track source locations
4. Report lexical errors
5. Test with examples/*.ql

**Example**:
```quorlin
contract Lexer:
    source: str
    position: uint256
    line: uint256
    column: uint256
    
    @external
    fn tokenize() -> Result[Vec[Token], CompilerError]:
        let tokens = Vec[Token]()
        
        while not self.is_at_end():
            let token = self.next_token()?
            tokens.push(token)
        
        return Ok(tokens)
```

---

## 📚 Key Documents

### Architecture Documents

1. **SELF_HOSTING_ROADMAP.md** (25 pages)
   - Complete 32-week plan
   - All 7 phases detailed
   - Success criteria

2. **LANGUAGE_SUBSET.md** (35 pages)
   - Systems Quorlin specification
   - All language features
   - Examples and patterns

3. **IR_SPECIFICATION.md** (30 pages)
   - IR structure and design
   - Instruction set
   - Optimization passes

4. **RUNTIME_ARCHITECTURE.md** (28 pages)
   - VM design
   - Bytecode format
   - Memory management

### Progress Documents

1. **SELF_HOSTING_PHASE1_PROGRESS.md**
   - Current status
   - Completed work
   - Next steps

2. **SELF_HOSTING_QUICK_REFERENCE.md** (this file)
   - Quick links
   - Implementation checklist
   - Current focus

---

## 🔧 Development Commands

### Testing

```bash
# Test lexer
./target/release/qlc tokenize examples/counter.ql

# Test parser (when implemented)
./target/release/qlc parse examples/counter.ql

# Test full compilation
./target/release/qlc compile examples/counter.ql --target quorlin
```

### Bootstrap (Future)

```bash
# Stage 0: Build Rust bootstrap
cargo build --release

# Stage 1: Self-compile
./target/release/qlc compile compiler/main.ql --target quorlin -o qlc-stage1

# Stage 2: Verify
./qlc-stage1 compile compiler/main.ql --target quorlin -o qlc-stage2
diff qlc-stage1 qlc-stage2
```

---

## 📊 Progress Metrics

### Overall Progress: 5%

| Phase | Progress | Status |
|-------|----------|--------|
| Phase 1: Foundation | 40% | 🔄 In Progress |
| Phase 2: Frontend | 0% | ⏳ Pending |
| Phase 3: Middle-End | 0% | ⏳ Pending |
| Phase 4: Backends | 0% | ⏳ Pending |
| Phase 5: Bootstrap | 0% | ⏳ Pending |
| Phase 6: Testing | 0% | ⏳ Pending |
| Phase 7: Independence | 0% | ⏳ Pending |

### Lines of Code

| Component | Current | Target | Progress |
|-----------|---------|--------|----------|
| AST | 450 | 500 | 90% |
| Lexer | 0 | 800 | 0% |
| Parser | 0 | 1500 | 0% |
| Semantic | 0 | 1200 | 0% |
| IR Builder | 0 | 1000 | 0% |
| Backends | 0 | 5000 | 0% |
| Runtime | 0 | 3000 | 0% |
| **Total** | **450** | **40,000** | **1%** |

---

## 🎨 Architecture Quick View

```
Quorlin Source (.ql)
        ↓
    [Lexer] → Tokens
        ↓
    [Parser] → AST
        ↓
  [Semantic] → Typed AST
        ↓
  [IR Builder] → QIR
        ↓
   [Optimizer] → Optimized QIR
        ↓
    ┌───┴───┬───────┬─────────┬────────┐
    ↓       ↓       ↓         ↓        ↓
  [EVM] [Solana] [Polkadot] [Aptos] [Quorlin]
    ↓       ↓       ↓         ↓        ↓
  Yul   Anchor   ink!      Move   Bytecode
```

---

## 🚦 Status Indicators

- ✅ **Complete** - Fully implemented and tested
- 🔄 **In Progress** - Currently being worked on
- ⏳ **Pending** - Not started yet
- ⚠️ **Blocked** - Waiting on dependencies
- ❌ **Failed** - Needs rework

---

## 📞 Getting Help

### Documentation

- Read [SELF_HOSTING_ROADMAP.md](SELF_HOSTING_ROADMAP.md) for overall plan
- Read [LANGUAGE_SUBSET.md](docs/LANGUAGE_SUBSET.md) for language features
- Read [IR_SPECIFICATION.md](docs/IR_SPECIFICATION.md) for IR design
- Read [RUNTIME_ARCHITECTURE.md](docs/RUNTIME_ARCHITECTURE.md) for VM design

### Contributing

1. Pick a task from the checklist above
2. Read relevant documentation
3. Implement in Quorlin
4. Test thoroughly
5. Submit PR

### Questions

- Check existing documentation first
- Review architecture decisions in progress report
- Ask in project discussions

---

## 🎯 Success Criteria

### Phase 1 (Current)

- [x] All foundation documents complete
- [x] AST definitions in Quorlin
- [ ] Runtime stdlib implemented
- [ ] Lexer implemented
- [ ] Test framework operational

### Final Success (Week 32)

```bash
# The ultimate test:
$ qlc-selfhosted compile compiler/main.ql --target quorlin -o qlc-stage2
$ qlc-stage2 compile compiler/main.ql --target quorlin -o qlc-stage3
$ diff qlc-stage2 qlc-stage3
# No differences = SUCCESS! 🎉

# And it works for all targets:
$ qlc-selfhosted compile examples/token.ql --target evm
$ qlc-selfhosted compile examples/token.ql --target solana
$ qlc-selfhosted compile examples/token.ql --target ink
$ qlc-selfhosted compile examples/token.ql --target move
# All compile successfully!
```

---

**Last Updated**: 2025-12-11  
**Current Phase**: 1 - Foundation (Week 2)  
**Next Milestone**: Complete runtime stdlib and lexer  
**Overall Progress**: 5%
