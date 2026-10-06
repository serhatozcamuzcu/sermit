"""
Binance ve MEXC Futures/Swap icin long/short pozisyon acma/kapatma araci.

Bu script hicbir islemi kendiliginden BASLATMAZ. Sadece komut satirindan
verilen talimati calistirir - ne zaman long/short acilacagina/kapanacagina
her zaman siz karar verirsiniz.

Kullanmadan once:
  1. futures-bot/.env.example dosyasini .env olarak kopyalayin.
  2. Kullanacaginiz borsa icin API_KEY / API_SECRET degerlerini girin.
  3. Once *_TESTNET=true ile test edin, sonucu kontrol edin.
     (MEXC icin ccxt sandbox destegi sinirlidir, asagidaki uyariya bakin.)
  4. Gercek parayla calistirmadan once ilgili *_TESTNET=false yapin.
"""

import argparse
import os
import sys

import ccxt
from dotenv import load_dotenv

load_dotenv()

EXCHANGES = {
    "binance": {"class": ccxt.binance, "market_type": "future"},
    "mexc": {"class": ccxt.mexc, "market_type": "swap"},
}

KNOWN_QUOTES = ("USDT", "USDC", "BUSD", "USD")


def normalize_symbol(symbol: str) -> str:
    """'BTCUSDT' -> 'BTC/USDT:USDT' (ccxt'in birlesik perpetual sembol formati)."""
    if ":" in symbol:
        return symbol
    if "/" in symbol:
        base, quote = symbol.split("/")
        return f"{base}/{quote}:{quote}"
    for quote in KNOWN_QUOTES:
        if symbol.upper().endswith(quote):
            base = symbol[: -len(quote)]
            return f"{base}/{quote}:{quote}"
    raise ValueError(f"Sembol anlasilamadi: {symbol} (orn: BTCUSDT ya da BTC/USDT:USDT kullanin)")


def make_exchange(name: str):
    if name not in EXCHANGES:
        sys.exit(f"Desteklenmeyen borsa: {name} (secenekler: {', '.join(EXCHANGES)})")

    cfg = EXCHANGES[name]
    prefix = name.upper()
    api_key = os.environ.get(f"{prefix}_API_KEY")
    api_secret = os.environ.get(f"{prefix}_API_SECRET")
    if not api_key or not api_secret:
        sys.exit(f"Hata: {prefix}_API_KEY / {prefix}_API_SECRET tanimli degil (.env dosyasina bakin).")

    exchange = cfg["class"]({
        "apiKey": api_key,
        "secret": api_secret,
        "enableRateLimit": True,
        "options": {"defaultType": cfg["market_type"]},
    })

    testnet_requested = os.environ.get(f"{prefix}_TESTNET", "true").lower() == "true"
    if testnet_requested:
        try:
            exchange.set_sandbox_mode(True)
            print(f"[bilgi] {name}: testnet modunda calisiyor - gercek para kullanilmiyor.")
        except ccxt.NotSupported:
            print(
                f"[UYARI] {name}: ccxt bu borsa icin testnet/sandbox modu sunmuyor. "
                "Istekler GERCEK hesaba gidecek - once cok kucuk miktarla deneyin."
            )
    else:
        print(f"[uyari] {name}: MAINNET modunda calisiyor - GERCEK PARA kullanilacak.")

    return exchange


def set_leverage(exchange, symbol: str, leverage: int) -> None:
    exchange.set_leverage(leverage, symbol)
    print(f"Kaldirac ayarlandi: {symbol} -> {leverage}x")


def get_position(exchange, symbol: str) -> dict | None:
    for pos in exchange.fetch_positions([symbol]):
        if (pos.get("contracts") or 0) != 0:
            return pos
    return None


def open_position(
    exchange,
    symbol: str,
    side: str,
    quantity: float,
    leverage: int | None,
    stop_loss_pct: float | None,
    take_profit_pct: float | None,
) -> None:
    symbol = normalize_symbol(symbol)
    if leverage:
        set_leverage(exchange, symbol, leverage)

    order_side = "buy" if side == "long" else "sell"
    last_price = exchange.fetch_ticker(symbol)["last"]

    params = {}
    if stop_loss_pct:
        sl_price = (
            last_price * (1 - stop_loss_pct / 100)
            if side == "long"
            else last_price * (1 + stop_loss_pct / 100)
        )
        params["stopLossPrice"] = sl_price
    if take_profit_pct:
        tp_price = (
            last_price * (1 + take_profit_pct / 100)
            if side == "long"
            else last_price * (1 - take_profit_pct / 100)
        )
        params["takeProfitPrice"] = tp_price

    order = exchange.create_order(symbol, "market", order_side, quantity, params=params)
    print(f"{side.upper()} pozisyon acildi: {symbol} miktar={quantity} id={order.get('id')}")

    if "stopLossPrice" in params:
        print(f"Stop-loss istegi gonderildi: {params['stopLossPrice']:.6g}")
    if "takeProfitPrice" in params:
        print(f"Take-profit istegi gonderildi: {params['takeProfitPrice']:.6g}")
    if params:
        print(
            "[not] SL/TP'nin borsaya gercekten islendigini 'status' komutuyla "
            "veya borsa arayuzunden kontrol edin; destek borsaya gore degisebilir."
        )


def close_position(exchange, symbol: str) -> None:
    symbol = normalize_symbol(symbol)
    position = get_position(exchange, symbol)
    if not position:
        print(f"{symbol} icin acik pozisyon bulunamadi.")
        return

    amount = abs(position.get("contracts") or 0)
    close_side = "sell" if position.get("side") == "long" else "buy"

    exchange.create_order(symbol, "market", close_side, amount, params={"reduceOnly": True})
    try:
        exchange.cancel_all_orders(symbol)
    except ccxt.NotSupported:
        pass
    print(f"Pozisyon kapatildi: {symbol} miktar={amount}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Binance / MEXC Futures long-short araci")
    parser.add_argument(
        "--exchange",
        default=os.environ.get("EXCHANGE", "binance"),
        choices=list(EXCHANGES),
        help="Islem yapilacak borsa (varsayilan: EXCHANGE env degiskeni ya da 'binance')",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    for cmd in ("long", "short"):
        p = sub.add_parser(cmd, help=f"{cmd.upper()} pozisyon ac")
        p.add_argument("symbol", help="Orn: BTCUSDT")
        p.add_argument("quantity", type=float, help="Islem miktari (coin cinsinden)")
        p.add_argument("--leverage", type=int, default=None, help="Kaldirac orani, orn: 5")
        p.add_argument("--stop-loss", type=float, default=None, dest="stop_loss_pct", help="Stop-loss yuzdesi, orn: 2")
        p.add_argument("--take-profit", type=float, default=None, dest="take_profit_pct", help="Take-profit yuzdesi, orn: 4")

    p_close = sub.add_parser("close", help="Acik pozisyonu kapat")
    p_close.add_argument("symbol", help="Orn: BTCUSDT")

    p_status = sub.add_parser("status", help="Acik pozisyonu goster")
    p_status.add_argument("symbol", help="Orn: BTCUSDT")

    args = parser.parse_args()
    exchange = make_exchange(args.exchange)

    try:
        if args.command in ("long", "short"):
            open_position(
                exchange,
                symbol=args.symbol,
                side=args.command,
                quantity=args.quantity,
                leverage=args.leverage,
                stop_loss_pct=args.stop_loss_pct,
                take_profit_pct=args.take_profit_pct,
            )
        elif args.command == "close":
            close_position(exchange, args.symbol)
        elif args.command == "status":
            position = get_position(exchange, normalize_symbol(args.symbol))
            print(position if position else f"{args.symbol} icin acik pozisyon yok.")
    except ccxt.BaseError as exc:
        sys.exit(f"{args.exchange} API hatasi: {exc}")


if __name__ == "__main__":
    main()
