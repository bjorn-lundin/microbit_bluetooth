--  Enkel BLE-beacon: skickar icke anslutningsbara advertising-paket
--  (ADV_NONCONN_IND) med egen data i fältet "Manufacturer Specific Data"
--  och valfritt ett namn. En PC/Mac kan läsa dem passivt, t.ex. med
--  Python-biblioteket bleak, utan att ansluta.
--
--  Motsvarar BLE_beacon-exemplet för micro:bit v1, porterat till v2.

with Interfaces;
with Microbit_V2.Radio;

package Microbit_V2.BLE_Beacon is

   subtype Device_Address_Bytes is Byte_Array (0 .. 5);
   --  Minst signifikanta byten först, som i luften.

   --  0xFFFF är reserverat av Bluetooth SIG för test och intern
   --  utveckling. Använd det tills du har ett eget företags-ID.
   Test_Company_ID : constant Interfaces.Unsigned_16 := 16#FFFF#;

   --  Advertising-data får vara högst 31 byte. Flags tar 3, rubriken för
   --  tillverkardata 4 och ett namn 2 + namnets längd.
   function Max_Data_Length (Name_Length : Natural) return Integer is
     (31 - 3 - 4 - (if Name_Length = 0 then 0 else 2 + Name_Length));

   procedure Initialize
     (Power : Microbit_V2.Radio.TX_Power := Microbit_V2.Radio.Zero_dBm);
   --  Startar radion och räknar fram enhetens adress.

   function Device_Address return Device_Address_Bytes;
   --  Statisk slumpadress härledd ur chippets unika DEVICEADDR i FICR.
   --  Den är samma vid varje start, men skiljer sig mellan kort.

   procedure Advertise
     (Company_ID : Interfaces.Unsigned_16;
      Data       : Byte_Array;
      Name       : String := "")
     with Pre => Microbit_V2.Radio.Initialized
                 and then Data'Length <= Max_Data_Length (Name'Length);
   --  Skickar en advertising-händelse: samma paket på kanal 37, 38 och 39.
   --  Anropa periodiskt (t.ex. var 100:e ms).

end Microbit_V2.BLE_Beacon;
