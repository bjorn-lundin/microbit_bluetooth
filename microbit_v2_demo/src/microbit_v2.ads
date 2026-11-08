--  Rotpaket för ett litet BSP till BBC micro:bit v2 (nRF52833).
--
--  Barnpaket:
--    Microbit_V2.GPIO       - GPIO för portarna P0 och P1
--    Microbit_V2.LEDs       - 5x5 LED-matrisen (scannas av en egen task)
--    Microbit_V2.Font       - 5x5-font (från CODAL, MIT-licens)
--    Microbit_V2.Buttons    - knapp A och B
--    Microbit_V2.Radio      - nRF52833-radion i BLE 1 Mbit-läge
--    Microbit_V2.BLE_Beacon - BLE-advertising (icke anslutningsbar beacon)

with Interfaces;

package Microbit_V2 with Pure is

   subtype Byte is Interfaces.Unsigned_8;

   type Byte_Array is array (Natural range <>) of Byte;

end Microbit_V2;
