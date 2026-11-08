--  Passiv BLE-skanner: lyssnar på advertising-kanalerna och plockar ut
--  "Manufacturer Specific Data" med ett visst företags-ID. Det är
--  motsatsen till BLE_Beacon: så kan en PC skicka data till micro:bit:en
--  utan anslutning.
--
--  Kräver att radion är initierad (t.ex. via BLE_Beacon.Initialize).

with Ada.Real_Time;
with Interfaces;
with Microbit_V2.Radio;

package Microbit_V2.BLE_Scanner is

   --  Tillverkardata får vara högst 31 - 2 - 2 = 27 byte (AD-längd, AD-typ
   --  och företags-ID tar 4 av de 31 byten).
   Max_Data_Length : constant := 27;

   subtype Data_Buffer is Byte_Array (0 .. Max_Data_Length - 1);

   type Result is record
      Found       : Boolean := False;
      Data        : Data_Buffer := (others => 0);
      Data_Length : Natural := 0;
      RSSI        : Integer := 0;
      Address     : Byte_Array (0 .. 5) := (others => 0);
      Channel     : Microbit_V2.Radio.Advertising_Channel := 37;
   end record;

   procedure Listen
     (Company_ID : Interfaces.Unsigned_16;
      Window     : Ada.Real_Time.Time_Span;
      Item       : out Result)
     with Pre => Microbit_V2.Radio.Initialized;
   --  Lyssnar i högst Window. Byter kanal 37 -> 38 -> 39 mellan anropen.
   --  Returnerar så fort ett paket med rätt företags-ID hittats
   --  (Item.Found = True) eller när tiden är slut (Item.Found = False).
   --  Data (0 .. Data_Length - 1) är tillverkardatan efter företags-ID:t.

   function Find_Manufacturer_Data
     (PDU        : Byte_Array;
      Company_ID : Interfaces.Unsigned_16;
      Data       : out Data_Buffer;
      Length     : out Natural) return Boolean;
   --  Tolkar en hel advertising-PDU (header + AdvA + AD-strukturer). Är
   --  synlig så att du kan använda den med egna Radio-anrop.

end Microbit_V2.BLE_Scanner;
