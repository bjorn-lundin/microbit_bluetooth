--  Demo för micro:bit v2, med data åt båda hållen över BLE-advertising.
--
--  micro:bit -> PC (beacon, namn "Ada:bit", företags-ID 0xFFFF):
--    byte 0..1 : räknare, little endian
--    byte 2    : bit 0 = A nedtryckt, bit 1 = B nedtryckt
--    byte 3    : sekvensnummer för senast mottagna kommando (kvittens)
--
--  PC -> micro:bit (sender.py, företags-ID 0xFFFF):
--    byte 0..1 : 'A', 'd'   (magiska byte, så att andra testenheter
--                            med 0xFFFF inte tolkas som kommandon)
--    byte 2    : sekvensnummer 1..255; samma nummer igen ignoreras
--    byte 3    : kommando
--    byte 4..  : data
--
--  Kommandon:
--    1 = text   : ASCII-text, högst 20 tecken, rullas på displayen
--    2 = bild   : 4 byte, 25 bitar; bit (Y * 5 + X) = LED (X, Y)
--    3 = släck  : släcker displayen
--    4 = räknare: 2 byte little endian, sätter räknaren
--
--  Knapp A räknar upp och knapp B nollställer, som förut. En
--  knapptryckning tar också tillbaka siffervisningen efter bild/släck.

with Ada.Real_Time;           use Ada.Real_Time;
with Interfaces;              use Interfaces;
with Microbit_V2;             use Microbit_V2;
with Microbit_V2.LEDs;
with Microbit_V2.Buttons;     use Microbit_V2.Buttons;
with Microbit_V2.BLE_Beacon;
with Microbit_V2.BLE_Scanner;
with Demo_Display;

procedure Microbit_V2_Demo is

   Listen_Window : constant Time_Span := Milliseconds (90);

   Magic_0 : constant Byte := Character'Pos ('A');
   Magic_1 : constant Byte := Character'Pos ('d');

   Cmd_Text    : constant Byte := 1;
   Cmd_Image   : constant Byte := 2;
   Cmd_Clear   : constant Byte := 3;
   Cmd_Counter : constant Byte := 4;

   --  Counter: displayen visar räknarens sista siffra.
   --  Remote : displayen visar det PC:n senast skickade (bild/släckt).
   type Display_Mode is (Counter, Remote);

   Mode     : Display_Mode := Counter;
   Count    : Unsigned_16  := 0;
   Was_A    : Boolean      := False;
   Was_B    : Boolean      := False;
   Last_Seq : Byte         := 0;   --  0 = inget kommando mottaget ännu

   Item : BLE_Scanner.Result;

   ----------------
   -- To_Image --
   ----------------

   function To_Image (Bits : Byte_Array) return LEDs.Image is
      Img : LEDs.Image := LEDs.Blank;
   begin
      for Y in LEDs.Coord loop
         for X in LEDs.Coord loop
            declare
               I : constant Natural := Y * 5 + X;
            begin
               if I / 8 < Bits'Length then
                  Img (Y, X) :=
                    (Shift_Right (Bits (Bits'First + I / 8), I mod 8)
                     and 1) = 1;
               end if;
            end;
         end loop;
      end loop;
      return Img;
   end To_Image;

   --------------------
   -- Handle_Command --
   --------------------

   procedure Handle_Command (Cmd : Byte; Data : Byte_Array) is
   begin
      if Cmd = Cmd_Text then
         declare
            Len  : constant Natural :=
              Natural'Min (Data'Length, Demo_Display.Max_Text);
            Text : String (1 .. Len);
         begin
            for I in Text'Range loop
               Text (I) := Character'Val (Data (Data'First + I - 1));
            end loop;
            Mode := Counter;
            Demo_Display.Scroll (Text);
         end;

      elsif Cmd = Cmd_Image then
         Mode := Remote;
         LEDs.Show (To_Image (Data));

      elsif Cmd = Cmd_Clear then
         Mode := Remote;
         LEDs.Clear;

      elsif Cmd = Cmd_Counter and then Data'Length >= 2 then
         Count := Unsigned_16 (Data (Data'First))
                  or Shift_Left (Unsigned_16 (Data (Data'First + 1)), 8);
         Mode := Counter;
      end if;
   end Handle_Command;

begin
   LEDs.Show (LEDs.Heart);
   delay until Clock + Milliseconds (800);
   LEDs.Scroll_Text ("Hej!");

   BLE_Beacon.Initialize;

   loop
      --  Knappar
      declare
         A_Now : constant Boolean := Is_Pressed (A);
         B_Now : constant Boolean := Is_Pressed (B);
      begin
         if A_Now and not Was_A then
            Count := Count + 1;
            Mode  := Counter;
         end if;

         if B_Now and not Was_B then
            Count := 0;
            Mode  := Counter;
         end if;

         Was_A := A_Now;
         Was_B := B_Now;

         --  Display
         if Mode = Counter and then not Demo_Display.Busy then
            LEDs.Show
              (Character'Val (Character'Pos ('0') + Natural (Count mod 10)));
         end if;

         --  Sänd status och kvittens
         BLE_Beacon.Advertise
           (Company_ID => BLE_Beacon.Test_Company_ID,
            Data       => (Byte (Count and 16#FF#),
                           Byte (Shift_Right (Count, 8)),
                           (if A_Now then 1 else 0)
                             or (if B_Now then 2 else 0),
                           Last_Seq),
            Name       => "Ada:bit");
      end;

      --  Lyssna efter kommandon. Listen byter kanal varje gång.
      BLE_Scanner.Listen (BLE_Beacon.Test_Company_ID, Listen_Window, Item);

      if Item.Found
        and then Item.Data_Length >= 4
        and then Item.Data (0) = Magic_0
        and then Item.Data (1) = Magic_1
        and then Item.Data (2) /= 0
        and then Item.Data (2) /= Last_Seq
      then
         Last_Seq := Item.Data (2);
         Handle_Command
           (Cmd  => Item.Data (3),
            Data => Item.Data (4 .. Item.Data_Length - 1));
      end if;
   end loop;
end Microbit_V2_Demo;
