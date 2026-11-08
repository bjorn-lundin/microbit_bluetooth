with System;
with Interfaces; use Interfaces;

package body Microbit_V2.BLE_Beacon is

   --  FICR: fabriksprogrammerad, unik adress per chip.
   FICR_DEVICEADDR_0 : Unsigned_32
     with Import, Volatile, Address => System'To_Address (16#1000_00A4#);
   FICR_DEVICEADDR_1 : Unsigned_32
     with Import, Volatile, Address => System'To_Address (16#1000_00A8#);

   --  PDU-header: typ ADV_NONCONN_IND (0b0010), TxAdd = 1 (slumpadress).
   ADV_NONCONN_IND : constant Byte := 16#02#;
   TxAdd_Random    : constant Byte := 16#40#;

   --  AD-typer (Bluetooth Assigned Numbers)
   AD_Flags         : constant Byte := 16#01#;
   AD_Complete_Name : constant Byte := 16#09#;
   AD_Manufacturer  : constant Byte := 16#FF#;

   --  LE General Discoverable Mode + BR/EDR Not Supported
   Flags_Value : constant Byte := 16#06#;

   Address : Device_Address_Bytes := (others => 0);

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Power : Microbit_V2.Radio.TX_Power := Microbit_V2.Radio.Zero_dBm)
   is
      A0 : constant Unsigned_32 := FICR_DEVICEADDR_0;
      A1 : constant Unsigned_32 := FICR_DEVICEADDR_1;
   begin
      Address :=
        (0 => Byte (A0 and 16#FF#),
         1 => Byte (Shift_Right (A0, 8) and 16#FF#),
         2 => Byte (Shift_Right (A0, 16) and 16#FF#),
         3 => Byte (Shift_Right (A0, 24)),
         4 => Byte (A1 and 16#FF#),
         --  De två högsta bitarna = 11 betyder "static random address".
         5 => Byte (Shift_Right (A1, 8) and 16#FF#) or 16#C0#);

      Microbit_V2.Radio.Initialize (Power);
   end Initialize;

   --------------------
   -- Device_Address --
   --------------------

   function Device_Address return Device_Address_Bytes is (Address);

   ---------------
   -- Advertise --
   ---------------

   procedure Advertise
     (Company_ID : Unsigned_16;
      Data       : Byte_Array;
      Name       : String := "")
   is
      PDU  : Byte_Array (0 .. Microbit_V2.Radio.Max_PDU_Length - 1) :=
        (others => 0);
      Last : Natural := 1;   --  index för senast skrivna byte

      procedure Put (B : Byte) is
      begin
         Last := Last + 1;
         PDU (Last) := B;
      end Put;

   begin
      --  Header: typ + TxAdd, längden fylls i på slutet.
      PDU (0) := ADV_NONCONN_IND or TxAdd_Random;

      --  AdvA
      for B of Address loop
         Put (B);
      end loop;

      --  AD: Flags
      Put (2);
      Put (AD_Flags);
      Put (Flags_Value);

      --  AD: Manufacturer Specific Data (företags-ID little endian + data)
      Put (Byte (3 + Data'Length));
      Put (AD_Manufacturer);
      Put (Byte (Company_ID and 16#FF#));
      Put (Byte (Shift_Right (Company_ID, 8)));
      for B of Data loop
         Put (B);
      end loop;

      --  AD: Complete Local Name
      if Name'Length > 0 then
         Put (Byte (1 + Name'Length));
         Put (AD_Complete_Name);
         for C of Name loop
            Put (Character'Pos (C));
         end loop;
      end if;

      --  Längdfältet = allt efter de två header-byten.
      PDU (1) := Byte (Last - 1);

      for Channel in Microbit_V2.Radio.Advertising_Channel loop
         Microbit_V2.Radio.Transmit_Advertising_PDU
           (Channel, PDU (0 .. Last));
      end loop;
   end Advertise;

end Microbit_V2.BLE_Beacon;
