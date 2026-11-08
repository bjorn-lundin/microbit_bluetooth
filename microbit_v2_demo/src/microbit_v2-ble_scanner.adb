with Interfaces; use Interfaces;

package body Microbit_V2.BLE_Scanner is

   use Ada.Real_Time;
   use Microbit_V2.Radio;

   --  PDU-typer som bär AdvA + AD-data (Core Spec Vol 6, Part B, 2.3).
   ADV_IND         : constant := 0;
   ADV_NONCONN_IND : constant := 2;
   ADV_SCAN_IND    : constant := 6;

   AD_Manufacturer : constant Byte := 16#FF#;

   Next_Channel : Advertising_Channel := 37;

   ----------------------------
   -- Find_Manufacturer_Data --
   ----------------------------

   function Find_Manufacturer_Data
     (PDU        : Byte_Array;
      Company_ID : Unsigned_16;
      Data       : out Data_Buffer;
      Length     : out Natural) return Boolean
   is
      First    : constant Natural := PDU'First;
      PDU_Type : Natural;
      Last     : Natural;   --  index för sista byte i PDU:n
      Pos      : Natural;
   begin
      Data   := (others => 0);
      Length := 0;

      if PDU'Length < 2 + 6 then
         return False;
      end if;

      PDU_Type := Natural (PDU (First) and 16#0F#);
      if PDU_Type not in ADV_IND | ADV_NONCONN_IND | ADV_SCAN_IND then
         return False;
      end if;

      Last := Natural'Min (PDU'Last, First + 1 + Natural (PDU (First + 1)));
      Pos  := First + 2 + 6;   --  hoppa över header och AdvA

      --  Gå igenom AD-strukturerna: [längd][typ][data ...]
      while Pos <= Last loop
         declare
            AD_Len : constant Natural := Natural (PDU (Pos));
         begin
            exit when AD_Len = 0 or else Pos + AD_Len > Last;

            if PDU (Pos + 1) = AD_Manufacturer
              and then AD_Len >= 3
              and then Unsigned_16 (PDU (Pos + 2))
                       + Shift_Left (Unsigned_16 (PDU (Pos + 3)), 8)
                       = Company_ID
            then
               Length := Natural'Min (AD_Len - 3, Max_Data_Length);
               for I in 0 .. Length - 1 loop
                  Data (I) := PDU (Pos + 4 + I);
               end loop;
               return True;
            end if;

            Pos := Pos + 1 + AD_Len;
         end;
      end loop;

      return False;
   end Find_Manufacturer_Data;

   ------------
   -- Listen --
   ------------

   procedure Listen
     (Company_ID : Unsigned_16;
      Window     : Time_Span;
      Item       : out Result)
   is
      Deadline : constant Time := Clock + Window;
      Channel  : constant Advertising_Channel := Next_Channel;
      PDU      : PDU_Buffer;
      Length   : Natural;
      RSSI     : Integer;
      Got_One  : Boolean;
   begin
      Item := (others => <>);
      Item.Channel := Channel;

      Next_Channel :=
        (if Channel = Advertising_Channel'Last
         then Advertising_Channel'First
         else Channel + 1);

      loop
         Receive_Advertising_PDU
           (Channel, Deadline, PDU, Length, RSSI, Got_One);
         exit when not Got_One;

         if Find_Manufacturer_Data
              (PDU (0 .. Length - 1), Company_ID, Item.Data, Item.Data_Length)
         then
            Item.Found   := True;
            Item.RSSI    := RSSI;
            Item.Address := PDU (2 .. 7);
            return;
         end if;
      end loop;
   end Listen;

end Microbit_V2.BLE_Scanner;
