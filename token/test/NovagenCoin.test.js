const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NovagenCoin", function () {
  const SUPPLY = 1_000_000n;

  async function deploy() {
    const [owner, alice, bob] = await ethers.getSigners();
    const token = await ethers.deployContract("NovagenCoin", [owner.address, SUPPLY]);
    return { token, owner, alice, bob };
  }

  it("isim, sembol ve ondalık doğru", async function () {
    const { token } = await deploy();
    expect(await token.name()).to.equal("Novagen Coin");
    expect(await token.symbol()).to.equal("NVG");
    expect(await token.decimals()).to.equal(18n);
  });

  it("tüm arz alıcıya basılır", async function () {
    const { token, owner } = await deploy();
    const expected = ethers.parseUnits(SUPPLY.toString(), 18);
    expect(await token.totalSupply()).to.equal(expected);
    expect(await token.balanceOf(owner.address)).to.equal(expected);
  });

  it("transfer çalışır", async function () {
    const { token, owner, alice } = await deploy();
    const amount = ethers.parseUnits("250", 18);
    await expect(token.transfer(alice.address, amount)).to.changeTokenBalances(
      token,
      [owner, alice],
      [-amount, amount]
    );
  });

  it("yetersiz bakiyeyle transfer reddedilir", async function () {
    const { token, alice, bob } = await deploy();
    await expect(
      token.connect(alice).transfer(bob.address, 1n)
    ).to.be.revertedWithCustomError(token, "ERC20InsufficientBalance");
  });

  it("burn toplam arzı azaltır", async function () {
    const { token } = await deploy();
    const amount = ethers.parseUnits("1000", 18);
    const before = await token.totalSupply();
    await token.burn(amount);
    expect(await token.totalSupply()).to.equal(before - amount);
  });
});
