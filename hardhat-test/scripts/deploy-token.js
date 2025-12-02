import hre from "hardhat";

async function main() {
  console.log("╔════════════════════════════════════════════════════════════╗");
  console.log("║           🚀 Deploying Quorlin Token Contract 🚀          ║");
  console.log("╚════════════════════════════════════════════════════════════╝");
  console.log();

  // Get the deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("  📝 Deployer address:", deployer.address);

  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("  💰 Deployer balance:", hre.ethers.formatEther(balance), "ETH");
  console.log();

  // The bytecode compiled from Quorlin -> Yul -> EVM
  // This is the deployment bytecode (constructor + runtime code)
  const bytecode = "0x5f3580600355335f5260046020528060405f20555f80523360205260405267b40fa3947a0a069d60605fa161024c806100375f395ff3fe5f3560e01c8063d44b3d19146100625780630269620e1461005d578063cd9f4dee1461005857806350525c861461005357806387f2aa741461004e576329a76db314610049575f80fd5b610242565b610220565b61020a565b610137565b6100f4565b60043560243590335f5260046020528160405f2054106100d85780156100d857335f52600460205260405f206100998382546100e9565b90555f818152600460205260409020546100b49083906100dc565b60405f2055335f5260205260405267b40fa3947a0a069d60605fa160015f5260205ff35b5f80fd5b919082019182106100d857565b8181106100d8570390565b60243560043580156100d857335f52600560205260405f20815f526020528160405f2055335f52602052604052677d20bd6ffcb8b1a860605fa160015f5260205ff35b6004356024356044359182610155825f52600460205260405f205490565b106100d8578261017933835f52600560205260405f20905f5260205260405f205490565b106100d85781156100d8575f8181526004602052604090205461019d9084906100e9565b60405f8181209290925583825260046020529020546101bd9084906100dc565b60405f818120929092558282526005602090815281832033845290529020546101e79084906100e9565b60405f20555f5260205260405267b40fa3947a0a069d60605fa160015f5260205ff35b6004355f52600460205260405f20545f5260205ff35b6004355f52600560205260405f206024355f5260205260405f20545f5260205ff35b6003545f5260205ff3";

  // Initial supply parameter (e.g., 1,000,000 tokens with 18 decimals)
  const initialSupply = hre.ethers.parseUnits("1000000", 18);

  // Encode the constructor parameter (initial_supply)
  const constructorParams = hre.ethers.AbiCoder.defaultAbiCoder().encode(
    ["uint256"],
    [initialSupply]
  );

  // Combine bytecode with constructor parameters
  const deploymentData = bytecode + constructorParams.slice(2); // Remove '0x' from params

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

  console.log("  ✅ Total supply stored:", hre.ethers.toBigInt(totalSupplyData).toString());
  console.log();

  return contractAddress;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
