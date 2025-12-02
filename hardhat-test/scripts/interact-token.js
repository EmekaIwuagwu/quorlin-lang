import hre from "hardhat";

// Function selectors for the token contract
const SELECTORS = {
  transfer: "0xd44b3d19",
  approve: "0x0269620e",
  transfer_from: "0xcd9f4dee",
  balance_of: "0x50525c86",
  allowance: "0x87f2aa74",
  get_total_supply: "0x29a76db3"
};

async function callContract(contractAddress, selector, params = []) {
  const encodedParams = params.length > 0
    ? hre.ethers.AbiCoder.defaultAbiCoder().encode(
        params.map(() => "uint256"),
        params
      ).slice(2) // Remove '0x'
    : "";

  const data = selector + encodedParams;

  try {
    const result = await hre.ethers.provider.call({
      to: contractAddress,
      data: data
    });
    return hre.ethers.toBigInt(result);
  } catch (error) {
    console.error("  ❌ Error calling contract:", error.message);
    throw error;
  }
}

async function sendTransaction(signer, contractAddress, selector, params = []) {
  const encodedParams = params.length > 0
    ? hre.ethers.AbiCoder.defaultAbiCoder().encode(
        params.map(() => "uint256"),
        params
      ).slice(2) // Remove '0x'
    : "";

  const data = selector + encodedParams;

  try {
    const tx = await signer.sendTransaction({
      to: contractAddress,
      data: data,
      gasLimit: 300000
    });

    console.log("  ⏳ Transaction hash:", tx.hash);
    const receipt = await tx.wait();
    console.log("  ✅ Confirmed in block:", receipt.blockNumber);
    return receipt;
  } catch (error) {
    console.error("  ❌ Transaction failed:", error.message);
    throw error;
  }
}

async function main() {
  // Get contract address from environment variable or command line
  const contractAddress = process.env.CONTRACT_ADDRESS || process.argv[process.argv.length - 1];

  // Basic validation - check if it looks like an address
  if (!contractAddress || !contractAddress.startsWith('0x') || contractAddress.length !== 42) {
    console.error("❌ Error: Please provide a valid contract address");
    console.error("");
    console.error("Usage:");
    console.error("  CONTRACT_ADDRESS=0x... npx hardhat run scripts/interact-token.js --network localhost");
    console.error("");
    process.exit(1);
  }

  console.log("╔════════════════════════════════════════════════════════════╗");
  console.log("║         🎮 Interacting with Quorlin Token Contract        ║");
  console.log("╚════════════════════════════════════════════════════════════╝");
  console.log();
  console.log("  📦 Contract address:", contractAddress);
  console.log();

  const [deployer, user1, user2] = await hre.ethers.getSigners();

  // 1. Check total supply
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("  1️⃣  Checking Total Supply");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  const totalSupply = await callContract(contractAddress, SELECTORS.get_total_supply);
  console.log("  📊 Total Supply:", totalSupply.toString());
  console.log();

  // 2. Check deployer balance
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("  2️⃣  Checking Deployer Balance");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  const deployerBalance = await callContract(
    contractAddress,
    SELECTORS.balance_of,
    [deployer.address]
  );
  console.log("  💰 Deployer:", deployer.address);
  console.log("  💰 Balance:", deployerBalance.toString());
  console.log();

  // 3. Transfer tokens to user1
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("  3️⃣  Transferring 1000 Tokens to User1");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("  👤 User1:", user1.address);
  await sendTransaction(
    deployer,
    contractAddress,
    SELECTORS.transfer,
    [user1.address, 1000]
  );
  console.log();

  // 4. Check user1 balance
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("  4️⃣  Checking User1 Balance");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  const user1Balance = await callContract(
    contractAddress,
    SELECTORS.balance_of,
    [user1.address]
  );
  console.log("  💰 User1 Balance:", user1Balance.toString());
  console.log();

  // 5. User1 approves deployer to spend 500 tokens
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("  5️⃣  User1 Approves Deployer to Spend 500 Tokens");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  await sendTransaction(
    user1,
    contractAddress,
    SELECTORS.approve,
    [deployer.address, 500]
  );
  console.log();

  // 6. Check allowance
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("  6️⃣  Checking Allowance");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  const allowance = await callContract(
    contractAddress,
    SELECTORS.allowance,
    [user1.address, deployer.address]
  );
  console.log("  🔐 Allowance (User1 -> Deployer):", allowance.toString());
  console.log();

  // 7. Deployer transfers from user1 to user2
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("  7️⃣  Deployer Transfers 300 from User1 to User2");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("  👤 User2:", user2.address);
  await sendTransaction(
    deployer,
    contractAddress,
    SELECTORS.transfer_from,
    [user1.address, user2.address, 300]
  );
  console.log();

  // 8. Check final balances
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("  8️⃣  Final Balances");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  const finalUser1Balance = await callContract(
    contractAddress,
    SELECTORS.balance_of,
    [user1.address]
  );
  const finalUser2Balance = await callContract(
    contractAddress,
    SELECTORS.balance_of,
    [user2.address]
  );
  const finalDeployerBalance = await callContract(
    contractAddress,
    SELECTORS.balance_of,
    [deployer.address]
  );

  console.log("  💰 Deployer Balance:", finalDeployerBalance.toString());
  console.log("  💰 User1 Balance:", finalUser1Balance.toString());
  console.log("  💰 User2 Balance:", finalUser2Balance.toString());
  console.log();

  console.log("╔════════════════════════════════════════════════════════════╗");
  console.log("║          ✨ ALL INTERACTIONS SUCCESSFUL ✨                ║");
  console.log("╚════════════════════════════════════════════════════════════╝");
  console.log();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
