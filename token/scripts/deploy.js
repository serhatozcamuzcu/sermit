const hre = require("hardhat");

// Toplam arz (tam birim; 18 ondalık kontrat içinde eklenir)
const INITIAL_SUPPLY = 1_000_000n;

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log(`Ağ: ${hre.network.name}`);
  console.log(`Deploy eden: ${deployer.address}`);

  const token = await hre.ethers.deployContract("NovagenCoin", [
    deployer.address,
    INITIAL_SUPPLY,
  ]);
  await token.waitForDeployment();

  const address = await token.getAddress();
  console.log(`NovagenCoin (NVG) deploy edildi: ${address}`);
  console.log(
    `Toplam arz: ${hre.ethers.formatUnits(await token.totalSupply(), 18)} NVG`
  );
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
