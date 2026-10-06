# Binance / MEXC Futures Long/Short Araci

Binance USDⓈ-M Futures ve MEXC Futures (swap) uzerinde kaldiracli long/short
pozisyon acmak/kapatmak icin basit bir komut satiri araci. `ccxt`
kutuphanesi sayesinde ayni kod her iki borsayi da destekler. **Hicbir
islemi otomatik/kendiliginden baslatmaz** — her komut sizin elle
calistirmanizla tetiklenir.

## Kurulum

```bash
cd futures-bot
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

`.env` dosyasini kullanacaginiz borsa(lar)in API anahtarlariyla doldurun.
Anahtarlari olustururken **Futures** iznini acin, **withdraw (para
cekme)** iznini KAPALI birakin.

## Once testnet ile deneyin

- **Binance:** `.env` icinde `BINANCE_TESTNET=true` iken, sahte bakiyeyle
  [Binance Futures Testnet](https://testnet.binancefuture.com/) uzerinde
  calisir. Gercek para riski yoktur.
- **MEXC:** ccxt'in MEXC icin sandbox/testnet destegi sinirlidir. Program
  testnet destegi bulamazsa bunu acikca uyarir ve istekler gercek hesaba
  gider. MEXC'te once **cok kucuk miktarla** (ornegin minimum lot) deneyip
  `status` komutuyla sonucu dogrulayin.

Gercek hesaba gecmek icin ilgili borsanin `.env` degiskenini
`*_TESTNET=false` yapin.

## Kullanim

Borsa secimi `--exchange binance` / `--exchange mexc` ile yapilir
(belirtilmezse `.env` icindeki `EXCHANGE` degeri, o da yoksa `binance`
kullanilir).

```bash
# Binance'te 5x kaldiracla BTCUSDT long ac, %2 stop-loss ve %4 take-profit
python futures_bot.py --exchange binance long BTCUSDT 0.01 --leverage 5 --stop-loss 2 --take-profit 4

# MEXC'te ETHUSDT short ac
python futures_bot.py --exchange mexc short ETHUSDT 0.1 --leverage 3

# Acik pozisyonu goruntule
python futures_bot.py --exchange mexc status ETHUSDT

# Acik pozisyonu kapat (bekleyen emirleri de iptal etmeye calisir)
python futures_bot.py --exchange binance close BTCUSDT
```

## Riskler

- Kaldiracli islemler likidasyon riski tasir; kaybedebileceginizden fazlasini
  kaybedebilirsiniz.
- `quantity` degeri sembolun minimum islem miktari kurallarina (lot size)
  uymalidir, aksi halde borsa API'si hata doner.
- Stop-loss/take-profit, siparise eklenen parametrelerle (`stopLossPrice`,
  `takeProfitPrice`) gonderilir; borsaya gore gercek davranis farklilik
  gosterebilir. **Islemden sonra `status` ile veya borsa arayuzunden
  gercekten yerlestiginden mutlaka emin olun.**
- Bu arac bir yatirim tavsiyesi degildir; hangi pozisyonu ne zaman
  acacaginiza/kapatacaginiza siz karar verirsiniz.
