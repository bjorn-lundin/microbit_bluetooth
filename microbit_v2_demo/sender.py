#!/usr/bin/env python3
"""Skickar kommandon till micro:bit:en (microbit_v2_demo) via BLE-advertising.

Kräver Linux med BlueZ (t.ex. openSUSE) och:   pip install bleak
(bleak drar med dbus-fast, som används för att annonsera via BlueZ.)

Exempel:
    python3 sender.py text "Hej Ada"
    python3 sender.py image 01010 11111 11111 01110 00100
    python3 sender.py clear
    python3 sender.py count 42

Skriptet annonserar kommandot och lyssnar sedan efter kvittens (byte 3 i
micro:bit:ens beacon blir vårt sekvensnummer), växelvis, tills kommandot
kvitterats eller tiden tagit slut. Med --no-ack annonseras bara kommandot.
"""

import argparse
import asyncio
import os
import random
import sys
import time
import unicodedata

from dbus_fast import BusType, Variant
from dbus_fast.errors import DBusError
from dbus_fast.aio import MessageBus
from dbus_fast.constants import PropertyAccess
from dbus_fast.service import ServiceInterface, dbus_property, method

COMPANY_ID = 0xFFFF
MAGIC = b"Ad"

CMD_TEXT = 1
CMD_IMAGE = 2
CMD_CLEAR = 3
CMD_COUNT = 4

MAX_TEXT = 20
ADV_PATH = "/org/bluez/microbit_sender/advertisement0"

BLUEZ = "org.bluez"
ADV_MANAGER = "org.bluez.LEAdvertisingManager1"


# --------------------------------------------------------------------------
# Kommandon -> bytes
# --------------------------------------------------------------------------

def to_ascii(text: str) -> bytes:
    """å -> a, ä -> a, ö -> o osv.; övrigt utanför ASCII blir '?'."""
    plain = unicodedata.normalize("NFKD", text)
    out = []
    for ch in plain:
        if unicodedata.combining(ch):
            continue
        out.append(ch if 32 <= ord(ch) <= 126 else "?")
    return "".join(out).encode("ascii")


def image_bits(rows: list[str]) -> bytes:
    """Fem rader med fem tecken ('1' eller '#' = tänd) -> 4 byte."""
    if len(rows) != 5 or any(len(r) != 5 for r in rows):
        raise ValueError("bilden ska vara 5 rader med 5 tecken var")
    value = 0
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in "1#":
                value |= 1 << (y * 5 + x)
    return value.to_bytes(4, "little")


def build_payload(seq: int, cmd: int, data: bytes = b"") -> bytes:
    return MAGIC + bytes([seq, cmd]) + data


# --------------------------------------------------------------------------
# BlueZ-annonsering via D-Bus
# --------------------------------------------------------------------------

class Advertisement(ServiceInterface):
    """org.bluez.LEAdvertisement1 som BlueZ läser och sänder ut."""

    def __init__(self, manufacturer_data: bytes):
        super().__init__("org.bluez.LEAdvertisement1")
        self._data = manufacturer_data

    @method()
    def Release(self):
        pass

    @dbus_property(access=PropertyAccess.READ)
    def Type(self) -> "s":
        return "broadcast"           # icke anslutningsbar

    @dbus_property(access=PropertyAccess.READ)
    def ManufacturerData(self) -> "a{qv}":
        return {COMPANY_ID: Variant("ay", self._data)}


class IntervalAdvertisement(Advertisement):
    """Som Advertisement, men ber om 100 ms sändintervall.

    Vissa BlueZ-/kernelversioner (bl.a. på Raspberry Pi) avvisar hela
    annonsen om de får MinInterval/MaxInterval; då försöker vi utan.
    """

    @dbus_property(access=PropertyAccess.READ)
    def MinInterval(self) -> "u":
        return 100

    @dbus_property(access=PropertyAccess.READ)
    def MaxInterval(self) -> "u":
        return 100


async def find_adv_manager(bus: MessageBus):
    """Hitta första Bluetooth-adaptern som kan annonsera."""
    intro = await bus.introspect(BLUEZ, "/")
    root = bus.get_proxy_object(BLUEZ, "/", intro)
    objects = await root.get_interface(
        "org.freedesktop.DBus.ObjectManager").call_get_managed_objects()

    for path, interfaces in sorted(objects.items()):
        if ADV_MANAGER in interfaces:
            intro = await bus.introspect(BLUEZ, path)
            obj = bus.get_proxy_object(BLUEZ, path, intro)
            return path, obj.get_interface(ADV_MANAGER)

    raise RuntimeError(
        "hittade ingen Bluetooth-adapter som kan annonsera "
        "(är bluetooth-tjänsten igång och adaptern påslagen?)")


class Advertiser:
    def __init__(self, payload: bytes, bus_type: BusType = BusType.SYSTEM):
        self.payload = payload
        self.bus_type = bus_type
        self.bus = None
        self.manager = None
        self.adapter = None

    async def start(self):
        self.bus = await MessageBus(bus_type=self.bus_type).connect()
        self.adapter, self.manager = await find_adv_manager(self.bus)

        try:
            self.bus.export(ADV_PATH, IntervalAdvertisement(self.payload))
            await self.manager.call_register_advertisement(ADV_PATH, {})
            return
        except DBusError as e:
            first_error = e
            self.bus.unexport(ADV_PATH)

        # Andra försöket: utan önskat intervall.
        self.bus.export(ADV_PATH, Advertisement(self.payload))
        try:
            await self.manager.call_register_advertisement(ADV_PATH, {})
        except DBusError:
            self.bus.unexport(ADV_PATH)
            self.manager = None
            raise
        print(f"(BlueZ avvisade önskat intervall: {first_error.text}; "
              "sänder med standardintervall)")

    async def stop(self):
        if self.manager is not None:
            try:
                await self.manager.call_unregister_advertisement(ADV_PATH)
            except Exception:
                pass
        if self.bus is not None:
            try:
                self.bus.unexport(ADV_PATH)
            except Exception:
                pass
            self.bus.disconnect()


# --------------------------------------------------------------------------
# Lyssna på micro:bit:ens beacon (för kvittens)
# --------------------------------------------------------------------------

class AckWatcher:
    """Håller koll på senaste kvitterade sekvensnummer från micro:bit:en."""

    def __init__(self):
        self.last_ack = None
        self.seen = asyncio.Event()
        self.changed = asyncio.Event()

    def callback(self, device, adv):
        data = adv.manufacturer_data.get(COMPANY_ID)
        # Vår egen annonsering börjar med "Ad"; micro:bit:ens med räknaren.
        if data is None or len(data) < 4 or data[:2] == MAGIC:
            return
        if adv.local_name not in (None, "Ada:bit"):
            return
        if data[3] != self.last_ack:
            self.last_ack = data[3]
            self.changed.set()
        self.seen.set()


ADV_PHASE = 1.5    # sekunder att annonsera per varv
SCAN_PHASE = 1.5   # sekunder att lyssna efter kvittens per varv


async def scan(watcher: AckWatcher, seconds: float, until=lambda: False):
    """Skanna i högst `seconds`, eller tills until() blir sant."""
    from bleak import BleakScanner   # importeras här så att testerna slipper

    end = time.monotonic() + seconds
    async with BleakScanner(detection_callback=watcher.callback):
        while not until():
            remaining = end - time.monotonic()
            if remaining <= 0:
                break
            watcher.changed.clear()
            try:
                await asyncio.wait_for(watcher.changed.wait(),
                                       min(remaining, 0.2))
            except asyncio.TimeoutError:
                pass


async def send(cmd: int, data: bytes, timeout: float,
               wait_ack: bool = True) -> bool:
    """Annonsera kommandot. Annonsering och skanning sker växelvis, aldrig
    samtidigt: Raspberry Pi:s Bluetooth-chip (och en del andra) vägrar
    starta en icke anslutningsbar annons medan en skanning pågår
    (kernelfel "Failed (0x03)")."""
    watcher = AckWatcher()

    if wait_ack:
        # Ta reda på micro:bit:ens nuvarande kvittens, så att vi väljer ett
        # annat sekvensnummer (annars skulle den ignorera kommandot).
        await scan(watcher, 3.0, until=watcher.seen.is_set)
        if not watcher.seen.is_set():
            print("Ser ingen micro:bit ännu, skickar ändå ...")

    seq = random.choice([s for s in range(1, 256) if s != watcher.last_ack])
    payload = build_payload(seq, cmd, data)
    print(f"Skickar seq {seq}: {payload.hex(' ')}")

    if not wait_ack:
        adv = Advertiser(payload)
        await adv.start()
        try:
            await asyncio.sleep(timeout)
        finally:
            await adv.stop()
        print(f"Annonserade i {timeout:g} s (ingen kvittens begärd).")
        return True

    start = time.monotonic()
    deadline = start + timeout
    while time.monotonic() < deadline:
        adv = Advertiser(payload)
        await adv.start()
        try:
            await asyncio.sleep(ADV_PHASE)
        finally:
            await adv.stop()

        await scan(watcher, SCAN_PHASE, until=lambda: watcher.last_ack == seq)
        if watcher.last_ack == seq:
            ms = (time.monotonic() - start) * 1000
            print(f"Kvitterat av micro:bit efter {ms:.0f} ms.")
            return True

    if watcher.seen.is_set():
        print(f"Ingen kvittens inom {timeout:g} s.")
    else:
        print(f"Skickat i {timeout:g} s, men micro:bit:ens beacon syntes "
              "aldrig, så kvittensen kunde inte kontrolleras. Testa "
              "receiver.py, eller kör med --no-ack.")
    return False


# --------------------------------------------------------------------------
# Kommandorad
# --------------------------------------------------------------------------

def parse_args(argv):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--timeout", type=float, default=10.0,
                   help="sekunder att försöka (standard 10)")
    p.add_argument("--no-ack", action="store_true",
                   help="skanna inte efter kvittens; annonsera bara i "
                        "--timeout sekunder")
    sub = p.add_subparsers(dest="command", required=True)

    t = sub.add_parser("text", help=f"rulla text (högst {MAX_TEXT} tecken)")
    t.add_argument("text")

    i = sub.add_parser("image", help="visa en 5x5-bild, fem rader")
    i.add_argument("rows", nargs=5, metavar="RAD")

    sub.add_parser("clear", help="släck displayen")

    c = sub.add_parser("count", help="sätt räknaren (0..65535)")
    c.add_argument("value", type=int)

    return p.parse_args(argv)


def command_bytes(args) -> tuple[int, bytes]:
    if args.command == "text":
        text = to_ascii(args.text)
        if len(text) > MAX_TEXT:
            print(f"Texten kortas till {MAX_TEXT} tecken.", file=sys.stderr)
            text = text[:MAX_TEXT]
        return CMD_TEXT, text
    if args.command == "image":
        return CMD_IMAGE, image_bits(args.rows)
    if args.command == "clear":
        return CMD_CLEAR, b""
    if args.command == "count":
        if not 0 <= args.value <= 0xFFFF:
            raise ValueError("räknaren måste vara 0..65535")
        return CMD_COUNT, args.value.to_bytes(2, "little")
    raise ValueError(args.command)


def main(argv=None) -> int:
    args = parse_args(argv)
    try:
        cmd, data = command_bytes(args)
        ok = asyncio.run(send(cmd, data, args.timeout,
                              wait_ack=not args.no_ack))
    except ValueError as e:
        print(f"Fel: {e}", file=sys.stderr)
        return 2
    except RuntimeError as e:
        print(f"Fel: {e}", file=sys.stderr)
        return 1
    except DBusError as e:
        print(f"Fel från BlueZ: {e.type}: {e.text}", file=sys.stderr)
        print("Se orsaken i loggen: journalctl -u bluetooth -n 20",
              file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Fel: {e!r}", file=sys.stderr)
        return 1
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
