# microbit_v2_demo

Litet BSP och demo i Ada för BBC micro:bit v2 (nRF52833), byggt med Alire och
runtimen `light_tasking_nrf52833`. Data går åt båda hållen mellan micro:bit och
PC via BLE-advertising, utan anslutning och utan SoftDevice.

## Paket

| Paket | Innehåll |
|---|---|
| `Microbit_V2.GPIO` | GPIO för P0 och P1 |
| `Microbit_V2.LEDs` | 5x5-matrisen: `Show`, `Set`, `Clear`, `Show (Character)`, `Scroll_Text`, färdiga bilder |
| `Microbit_V2.Font` | 5x5-font, ASCII 32..126 (från CODAL, MIT) |
| `Microbit_V2.Buttons` | `Is_Pressed (A)` / `Is_Pressed (B)` |
| `Microbit_V2.Radio` | nRF52833-radion i BLE 1 Mbit-läge: sända och ta emot advertising-PDU:er |
| `Microbit_V2.BLE_Beacon` | `Advertise (Company_ID, Data, Name)` på kanal 37–39 |
| `Microbit_V2.BLE_Scanner` | `Listen (Company_ID, Window, Item)`: tar emot tillverkardata |
| `Demo_Display` | rullar text i en bakgrundstask (bara för demon) |

## Bygga och flasha

```sh
alr build
alr exec -- arm-eabi-objcopy -O ihex bin/microbit_v2_demo microbit_v2_demo.hex
cp microbit_v2_demo.hex /run/media/$USER/MICROBIT/
```

## På datorn

```sh
pip install bleak

python3 receiver.py                     # visa micro:bit:ens status

python3 sender.py text "Hej Ada"        # rulla text (max 20 tecken)
python3 sender.py image 01010 11111 11111 01110 00100
python3 sender.py clear
python3 sender.py count 42
```

`sender.py` kräver Linux med BlueZ. Det annonserar kommandot tills micro:bit:en
kvitterar det (sekvensnumret syns i dess beacon) eller tills `--timeout`
(10 s) gått ut. Annonsering och skanning sker växelvis, eftersom bl.a. Raspberry Pi inte klarar båda samtidigt. Med `--no-ack` annonseras kommandot utan att kvittensen kontrolleras. Å, ä och ö skickas som a, a och o.

## Protokoll

Båda riktningarna använder Manufacturer Specific Data med företags-ID
0xFFFF (reserverat för test).

micro:bit -> PC: `[räknare lo, räknare hi, knappar, kvitterat seq]`

PC -> micro:bit: `['A', 'd', seq, kommando, data ...]`

| Kommando | Data |
|---|---|
| 1 text | ASCII, högst 20 byte |
| 2 bild | 4 byte; bit `Y*5+X` = LED (X, Y) |
| 3 släck | – |
| 4 räknare | 2 byte, little endian |

## Inställningar i alire.toml

* `LFCLK_Src = "RC"`: RC-oscillatorn fungerar alltid som LF-klocka.
* `Use_SWO_Trace = false`: SWO skulle annars ta P1.00 (kantkontakt P20).
