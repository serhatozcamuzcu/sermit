# Binance Futures Long/Short Araci

Binance USDT-M Futures uzerinde kaldiracli long/short pozisyon acmak/kapatmak
icin basit bir komut satiri araci. **Hicbir islemi otomatik/kendiliginden
baslatmaz** — her komut sizin elle calistirmanizla tetiklenir.

## Kurulum

```bash
cd binance-bot
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

`.env` dosyasini kendi Binance API anahtarlarinizla doldurun. Anahtarlari
olustururken **Futures** iznini acin, **withdraw (para cekme)** iznini
KAPALI birakin.

## Once testnet ile deneyin

`.env` icinde `BINANCE_TESTNET=true` iken, sahte bakiyeyle
[Binance Futures Testnet](https://testnet.binancefuture.com/) uzerinde
calisir. Gercek para riski yoktur. Once burada test etmeniz siddetle
onerilir.

Gercek hesaba gecmek icin `.env` icinde `BINANCE_TESTNET=false` yapin.

## Kullanim

```bash
# 5x kaldiracla BTCUSDT long ac, %2 stop-loss ve %4 take-profit koy
python futures_bot.py long BTCUSDT 0.01 --leverage 5 --stop-loss 2 --take-profit 4

# ETHUSDT short ac
python futures_bot.py short ETHUSDT 0.1 --leverage 3

# Acik pozisyonu goruntule
python futures_bot.py status BTCUSDT

# Acik pozisyonu kapat (bekleyen SL/TP emirlerini de iptal eder)
python futures_bot.py close BTCUSDT
```

## Riskler

- Kaldiracli islemler likidasyon riski tasir; kaybedebileceginizden fazlasini
  kaybedebilirsiniz.
- `quantity` degeri sembolun minimum islem miktari kurallarina (lot size)
  uymalidir, aksi halde Binance API hata doner.
- Bu arac bir yatirim tavsiyesi degildir; hangi pozisyonu ne zaman
  acacaginiza/kapatacaginiza siz karar verirsiniz.
