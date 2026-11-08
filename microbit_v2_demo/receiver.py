#!/usr/bin/env python3
"""Tar emot BLE-advertising från microbit_v2_demo.

Installera:   pip install bleak
Kör:          python3 receiver.py

Fungerar på Linux (BlueZ), macOS och Windows. På macOS visas ett UUID i
stället för Bluetooth-adressen; det är normalt.
"""

import asyncio

from bleak import BleakScanner

COMPANY_ID = 0xFFFF  # samma som BLE_Beacon.Test_Company_ID


def on_advertisement(device, adv):
    data = adv.manufacturer_data.get(COMPANY_ID)
    # Sändarens egna paket (sender.py) börjar med "Ad"; hoppa över dem.
    if data is None or len(data) < 3 or data[:2] == b"Ad":
        return

    count = int.from_bytes(data[0:2], "little")
    state = data[2]
    a = "A" if state & 1 else "-"
    b = "B" if state & 2 else "-"
    ack = data[3] if len(data) > 3 else 0

    print(
        f"{device.address}  {adv.local_name or '?':8}  RSSI {adv.rssi:4} dBm  "
        f"räknare {count:5}  knappar {a}{b}  kvittens {ack:3}"
    )


async def main():
    print("Lyssnar efter micro:bit (Ctrl+C för att avsluta) ...")
    async with BleakScanner(detection_callback=on_advertisement):
        while True:
            await asyncio.sleep(1)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
