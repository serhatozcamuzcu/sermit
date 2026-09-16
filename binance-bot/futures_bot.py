"""
Binance USDT-M Futures icin long/short pozisyon acma/kapatma araci.

Bu script hicbir islemi kendiliginden BASLATMAZ. Sadece komut satirindan
verilen talimati calistirir - ne zaman long/short acilacagina/kapanacagina
her zaman siz karar verirsiniz.

Kullanmadan once:
  1. binance-bot/.env.example dosyasini .env olarak kopyalayin.
  2. BINANCE_API_KEY / BINANCE_API_SECRET degerlerinizi girin.
  3. Once BINANCE_TESTNET=true ile test edin, sonucu kontrol edin.
  4. Gercek parayla calistirmadan once BINANCE_TESTNET=false yapin.
"""

import argparse
import os
import sys

from binance.client import Client
from binance.enums import (
    SIDE_BUY,
    SIDE_SELL,
    ORDER_TYPE_MARKET,
    ORDER_TYPE_STOP_MARKET,
    ORDER_TYPE_TAKE_PROFIT_MARKET,
)
from binance.exceptions import BinanceAPIException
from dotenv import load_dotenv

load_dotenv()


def _make_client() -> Client:
    api_key = os.environ.get("BINANCE_API_KEY")
    api_secret = os.environ.get("BINANCE_API_SECRET")
    if not api_key or not api_secret:
        sys.exit("Hata: BINANCE_API_KEY / BINANCE_API_SECRET tanimli degil (.env dosyasina bakin).")

    testnet = os.environ.get("BINANCE_TESTNET", "true").lower() == "true"
    client = Client(api_key, api_secret, testnet=testnet)
    if testnet:
        print("[bilgi] Testnet modunda calisiyor - gercek para kullanilmiyor.")
    else:
        print("[uyari] MAINNET modunda calisiyor - GERCEK PARA kullanilacak.")
    return client


def set_leverage(client: Client, symbol: str, leverage: int) -> None:
    client.futures_change_leverage(symbol=symbol, leverage=leverage)
    print(f"Kaldirac ayarlandi: {symbol} -> {leverage}x")


def get_position(client: Client, symbol: str) -> dict | None:
    for pos in client.futures_position_information(symbol=symbol):
        if float(pos["positionAmt"]) != 0:
            return pos
    return None


def open_position(
    client: Client,
    symbol: str,
    side: str,
    quantity: float,
    leverage: int | None,
    stop_loss_pct: float | None,
    take_profit_pct: float | None,
) -> None:
    if leverage:
        set_leverage(client, symbol, leverage)

    order_side = SIDE_BUY if side == "long" else SIDE_SELL
    order = client.futures_create_order(
        symbol=symbol,
        side=order_side,
        type=ORDER_TYPE_MARKET,
        quantity=quantity,
    )
    print(f"{side.upper()} pozisyon acildi: {symbol} miktar={quantity} orderId={order['orderId']}")

    entry_price = float(client.futures_mark_price(symbol=symbol)["markPrice"])
    close_side = SIDE_SELL if side == "long" else SIDE_BUY

    if stop_loss_pct:
        sl_price = (
            entry_price * (1 - stop_loss_pct / 100)
            if side == "long"
            else entry_price * (1 + stop_loss_pct / 100)
        )
        client.futures_create_order(
            symbol=symbol,
            side=close_side,
            type=ORDER_TYPE_STOP_MARKET,
            stopPrice=round(sl_price, 2),
            closePosition=True,
        )
        print(f"Stop-loss emri kondu: {round(sl_price, 2)}")

    if take_profit_pct:
        tp_price = (
            entry_price * (1 + take_profit_pct / 100)
            if side == "long"
            else entry_price * (1 - take_profit_pct / 100)
        )
        client.futures_create_order(
            symbol=symbol,
            side=close_side,
            type=ORDER_TYPE_TAKE_PROFIT_MARKET,
            stopPrice=round(tp_price, 2),
            closePosition=True,
        )
        print(f"Take-profit emri kondu: {round(tp_price, 2)}")


def close_position(client: Client, symbol: str) -> None:
    position = get_position(client, symbol)
    if not position:
        print(f"{symbol} icin acik pozisyon bulunamadi.")
        return

    amt = float(position["positionAmt"])
    close_side = SIDE_SELL if amt > 0 else SIDE_BUY
    client.futures_create_order(
        symbol=symbol,
        side=close_side,
        type=ORDER_TYPE_MARKET,
        quantity=abs(amt),
        reduceOnly=True,
    )
    client.futures_cancel_all_open_orders(symbol=symbol)
    print(f"Pozisyon kapatildi: {symbol} miktar={abs(amt)} (bekleyen SL/TP emirleri iptal edildi)")


def main() -> None:
    parser = argparse.ArgumentParser(description="Binance Futures long/short araci")
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
    client = _make_client()

    try:
        if args.command in ("long", "short"):
            open_position(
                client,
                symbol=args.symbol,
                side=args.command,
                quantity=args.quantity,
                leverage=args.leverage,
                stop_loss_pct=args.stop_loss_pct,
                take_profit_pct=args.take_profit_pct,
            )
        elif args.command == "close":
            close_position(client, args.symbol)
        elif args.command == "status":
            position = get_position(client, args.symbol)
            print(position if position else f"{args.symbol} icin acik pozisyon yok.")
    except BinanceAPIException as exc:
        sys.exit(f"Binance API hatasi: {exc}")


if __name__ == "__main__":
    main()
