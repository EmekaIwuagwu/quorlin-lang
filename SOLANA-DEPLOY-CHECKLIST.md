# Solana Deployment - Quick Checklist

**⏱️ Time: 10 minutes (if prerequisites installed)**

---

## ✅ Checklist

### Prerequisites
- [ ] Rust installed (`rustc --version`)
- [ ] Solana CLI installed (`solana --version`)
- [ ] Anchor installed (`anchor --version`)
- [ ] Wallet created (`ls ~/.config/solana/id.json`)
- [ ] DevNet SOL (`solana balance` > 0.5 SOL)

---

## 🚀 Quick Deploy Commands

```bash
# 1. Pull latest code
cd /path/to/quorlin-lang
git pull origin claude/quorlin-compiler-setup-018umvaBWj2DWyPtPny19Mqu

# 2. Build compiler (first time only)
cargo build --release

# 3. Configure Solana
solana config set --url https://api.devnet.solana.com
solana airdrop 2

# 4. Compile Quorlin → Solana
./target/release/qlc compile examples/token.ql --target solana --output anchor-test/programs/quorlin-token/src/lib.rs

# 5. Build & Deploy
cd anchor-test
anchor build
anchor deploy --provider.cluster devnet

# 6. Get Program ID
solana address -k target/deploy/quorlin_token-keypair.json

# 7. Verify
solana program show <PROGRAM_ID> --url devnet
```

---

## 🎯 One-Command Deploy (Automated)

```bash
cd anchor-test
./scripts/compile-and-deploy.sh
```

---

## 📝 Post-Deployment

```bash
# View on Explorer
https://explorer.solana.com/address/<PROGRAM_ID>?cluster=devnet

# Run tests
anchor test --skip-local-validator

# Check balance
solana balance
```

---

## 🔄 Update/Redeploy

```bash
# Recompile
./target/release/qlc compile examples/token.ql --target solana --output anchor-test/programs/quorlin-token/src/lib.rs

# Rebuild & upgrade
cd anchor-test
anchor build
anchor upgrade --provider.cluster devnet target/deploy/quorlin_token.so --program-id <PROGRAM_ID>
```

---

## ⚡ Quick Install Commands

**Rust:**
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

**Solana:**
```bash
sh -c "$(curl -sSfL https://release.solana.com/stable/install)"
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
```

**Anchor:**
```bash
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
avm install latest && avm use latest
```

**Wallet:**
```bash
solana-keygen new --outfile ~/.config/solana/id.json
```

---

## 🎯 Expected Results

✅ Program deployed successfully
✅ Program ID: `Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS`
✅ Visible on Solana Explorer
✅ Balance decreased by ~1.7 SOL (for rent)
✅ Tests pass

---

**Done! 🚀**
