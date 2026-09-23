# Novagen Coin (NVG)

Sabit arzlı, yakılabilir (burnable) bir ERC-20 token. [OpenZeppelin](https://docs.openzeppelin.com/contracts/5.x/) kontratları üzerine kuruludur.

| Özellik     | Değer          |
|-------------|----------------|
| İsim        | Novagen Coin   |
| Sembol      | NVG            |
| Ondalık     | 18             |
| Toplam arz  | 1.000.000 NVG  |
| Yeni basım  | Yok (sabit arz)|
| Burn        | Var            |

İsim/sembol `contracts/NovagenCoin.sol` içinde, toplam arz `scripts/deploy.js` içinde değiştirilebilir.

## Kurulum

```bash
cd token
npm install
npm test          # testleri çalıştır
```

## Yerelde deneme

```bash
npx hardhat node               # 1. terminal: yerel blokzincir
npm run deploy:local           # 2. terminal: tokenı deploy et
```

## Test ağına (testnet) deploy

1. `.env.example` dosyasını `.env` olarak kopyalayın ve doldurun.
   **Yalnızca test için açtığınız ayrı bir cüzdanın özel anahtarını kullanın.**
2. Cüzdana faucet'ten test ETH alın (Sepolia veya Base Sepolia).
3. Deploy edin:

```bash
npm run deploy:base-sepolia    # veya: npm run deploy:sepolia
```

Çıktıdaki kontrat adresini MetaMask'e "Token içe aktar" ile ekleyerek NVG bakiyenizi görebilirsiniz.

## Ana ağa (mainnet) çıkmadan önce

- Gerçek para içeren ana ağa deploy etmek geri alınamaz ve gas ücreti gerektirir.
- Türkiye'de kripto varlık ihracı/satışı SPK düzenlemelerine tabidir; tokenı halka satmayı
  veya yatırım aracı olarak sunmayı düşünüyorsanız önce hukuki danışmanlık alın.
- Kontratı bir denetimden (audit) geçirmeniz önerilir.
