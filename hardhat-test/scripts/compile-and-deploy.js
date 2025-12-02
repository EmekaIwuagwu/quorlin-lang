import hre from "hardhat";
import { execSync } from "child_process";
import fs from "fs";
import path from "path";

async function main() {
  console.log("╔════════════════════════════════════════════════════════════╗");
  console.log("║      🚀 Compile & Deploy Quorlin Token Contract 🚀       ║");
  console.log("╚════════════════════════════════════════════════════════════╝");
  console.log();

  // Step 1: Compile Quorlin to Yul
  console.log("  [1/3] 📝 Compiling Quorlin → Yul...");
  const projectRoot = path.resolve("..");
  const qlcPath = path.join(projectRoot, "target", "release", "qlc");
  const tokenQlPath = path.join(projectRoot, "examples", "token.ql");
  const tokenYulPath = path.join(projectRoot, "hardhat-test", "token.yul");

  try {
    execSync(`"${qlcPath}" compile "${tokenQlPath}" --target evm --output "${tokenYulPath}"`, {
      stdio: "pipe"
    });
    console.log("        ✅ Quorlin compiled successfully");
  } catch (error) {
    console.error("        ❌ Failed to compile Quorlin");
    console.error(error.message);
    process.exit(1);
  }

  // Step 2: Compile Yul to Bytecode with solc
  console.log("  [2/3] ⚙️  Compiling Yul → Bytecode...");

  let bytecode;
  try {
    // Try to use solc if available
    const solcOutput = execSync(`solc --strict-assembly "${tokenYulPath}" --bin --optimize`, {
      encoding: "utf-8",
      stdio: "pipe"
    });

    // Extract bytecode from solc output
    const lines = solcOutput.split("\n");
    const bytecodeIndex = lines.findIndex(line => line.includes("Binary representation:"));
    if (bytecodeIndex >= 0 && lines[bytecodeIndex + 1]) {
      bytecode = "0x" + lines[bytecodeIndex + 1].trim();
      console.log("        ✅ Yul compiled to bytecode");
    } else {
      throw new Error("Could not extract bytecode from solc output");
    }
  } catch (error) {
    console.log("        ⚠️  solc not found, using pre-compiled bytecode");
    console.log("        💡 Install solc for automatic compilation");

    // Fallback to reading from file if it exists
    const bytecodeFile = path.join(projectRoot, "hardhat-test", "token.bin");
    if (fs.existsSync(bytecodeFile)) {
      bytecode = "0x" + fs.readFileSync(bytecodeFile, "utf-8").trim();
    } else {
      console.error("        ❌ No bytecode file found. Please compile manually.");
      process.exit(1);
    }
  }

  console.log("        📏 Bytecode length:", bytecode.length, "characters");
  console.log();

  // Step 3: Deploy the contract
  console.log("  [3/3] 🚀 Deploying to network...");
  console.log();

  const [deployer] = await hre.ethers.getSigners();
  console.log("  📝 Deployer address:", deployer.address);

  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("  💰 Deployer balance:", hre.ethers.formatEther(balance), "ETH");
  console.log();

  // Initial supply parameter (1,000,000 tokens with 18 decimals)
  const initialSupply = hre.ethers.parseUnits("1000000", 18);

  // Encode the constructor parameter
  const constructorParams = hre.ethers.AbiCoder.defaultAbiCoder().encode(
    ["uint256"],
    [initialSupply]
  );

  // Combine bytecode with constructor parameters
  const deploymentData = bytecode + constructorParams.slice(2);

  console.log("  🔧 Deploying with initial supply:", hre.ethers.formatUnits(initialSupply, 18));
  console.log();

  // Deploy the contract
  const tx = await deployer.sendTransaction({
    data: deploymentData,
    gasLimit: 3000000
  });

  console.log("  ⏳ Transaction hash:", tx.hash);
  console.log("  ⏳ Waiting for confirmation...");

  const receipt = await tx.wait();
  const contractAddress = receipt.contractAddress;

  console.log();
  console.log("╔════════════════════════════════════════════════════════════╗");
  console.log("║              ✨ DEPLOYMENT SUCCESSFUL ✨                  ║");
  console.log("╚════════════════════════════════════════════════════════════╝");
  console.log();
  console.log("  📦 Contract address:", contractAddress);
  console.log("  ⛽ Gas used:", receipt.gasUsed.toString());
  console.log("  🔗 Block number:", receipt.blockNumber);
  console.log();
  console.log("════════════════════════════════════════════════════════════");
  console.log();

  // Verify deployment by reading total supply
  const totalSupplySelector = "0x29a76db3"; // get_total_supply() selector
  const totalSupplyData = await hre.ethers.provider.call({
    to: contractAddress,
    data: totalSupplySelector
  });

  const totalSupply = hre.ethers.toBigInt(totalSupplyData);
  console.log("  ✅ Total supply verified:", hre.ethers.formatUnits(totalSupply, 18), "tokens");
  console.log();

  // Save contract address for interact script
  const addressFile = path.join(projectRoot, "hardhat-test", "deployed-address.txt");
  fs.writeFileSync(addressFile, contractAddress);
  console.log("  💾 Contract address saved to deployed-address.txt");
  console.log();

  return contractAddress;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
