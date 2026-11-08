with System;
with System.Storage_Elements;
with Interfaces; use Interfaces;

package body Microbit_V2.Radio is

   use Ada.Real_Time;

   --  Registeroffset enligt nrf52833.svd (Nordic MDK).

   -----------
   -- CLOCK --
   -----------

   type Clock_Registers is record
      Tasks_HFCLKSTART    : Unsigned_32;
      Events_HFCLKSTARTED : Unsigned_32;
   end record
     with Volatile;

   for Clock_Registers use record
      Tasks_HFCLKSTART    at 16#000# range 0 .. 31;
      Events_HFCLKSTARTED at 16#100# range 0 .. 31;
   end record;

   Clock_Regs : Clock_Registers
     with Import, Address => System'To_Address (16#4000_0000#);

   -----------
   -- RADIO --
   -----------

   type Radio_Registers is record
      Tasks_TXEN      : Unsigned_32;
      Tasks_RXEN      : Unsigned_32;
      Tasks_Disable   : Unsigned_32;
      Events_Ready    : Unsigned_32;
      Events_Address  : Unsigned_32;
      Events_End      : Unsigned_32;
      Events_Disabled : Unsigned_32;
      Events_RSSIEND  : Unsigned_32;
      Shorts          : Unsigned_32;
      Crcstatus       : Unsigned_32;
      Packetptr       : Unsigned_32;
      Frequency       : Unsigned_32;
      Txpower         : Unsigned_32;
      Mode            : Unsigned_32;
      Pcnf0           : Unsigned_32;
      Pcnf1           : Unsigned_32;
      Base0           : Unsigned_32;
      Prefix0         : Unsigned_32;
      Txaddress       : Unsigned_32;
      Rxaddresses     : Unsigned_32;
      Crccnf          : Unsigned_32;
      Crcpoly         : Unsigned_32;
      Crcinit         : Unsigned_32;
      Rssisample      : Unsigned_32;
      State           : Unsigned_32;
      Datawhiteiv     : Unsigned_32;
   end record
     with Volatile;

   for Radio_Registers use record
      Tasks_TXEN      at 16#000# range 0 .. 31;
      Tasks_RXEN      at 16#004# range 0 .. 31;
      Tasks_Disable   at 16#010# range 0 .. 31;
      Events_Ready    at 16#100# range 0 .. 31;
      Events_Address  at 16#104# range 0 .. 31;
      Events_End      at 16#10C# range 0 .. 31;
      Events_Disabled at 16#110# range 0 .. 31;
      Events_RSSIEND  at 16#11C# range 0 .. 31;
      Shorts          at 16#200# range 0 .. 31;
      Crcstatus       at 16#400# range 0 .. 31;
      Packetptr       at 16#504# range 0 .. 31;
      Frequency       at 16#508# range 0 .. 31;
      Txpower         at 16#50C# range 0 .. 31;
      Mode            at 16#510# range 0 .. 31;
      Pcnf0           at 16#514# range 0 .. 31;
      Pcnf1           at 16#518# range 0 .. 31;
      Base0           at 16#51C# range 0 .. 31;
      Prefix0         at 16#524# range 0 .. 31;
      Txaddress       at 16#52C# range 0 .. 31;
      Rxaddresses     at 16#530# range 0 .. 31;
      Crccnf          at 16#534# range 0 .. 31;
      Crcpoly         at 16#538# range 0 .. 31;
      Crcinit         at 16#53C# range 0 .. 31;
      Rssisample      at 16#548# range 0 .. 31;
      State           at 16#550# range 0 .. 31;
      Datawhiteiv     at 16#554# range 0 .. 31;
   end record;

   RADIO : Radio_Registers
     with Import, Address => System'To_Address (16#4000_1000#);

   --  SHORTS-bitar
   Short_Ready_Start       : constant Unsigned_32 := 2**0;
   Short_End_Disable       : constant Unsigned_32 := 2**1;
   Short_Address_RSSIStart : constant Unsigned_32 := 2**4;
   Short_Disabled_RSSIStop : constant Unsigned_32 := 2**8;

   Mode_Ble_1Mbit : constant Unsigned_32 := 3;

   --  BLE: access address för advertising och CRC-parametrar
   --  (Bluetooth Core Spec, Vol 6, Part B).
   Adv_Access_Address : constant Unsigned_32 := 16#8E89_BED6#;
   Adv_CRC_Init       : constant Unsigned_32 := 16#55_5555#;
   BLE_CRC_Poly       : constant Unsigned_32 := 16#00_065B#;

   --  Radions frekvens anges som MHz över 2400.
   Channel_Frequency : constant array (Advertising_Channel) of Unsigned_32 :=
     (37 => 2,    --  2402 MHz
      38 => 26,   --  2426 MHz
      39 => 80);  --  2480 MHz

   Power_Value : constant array (TX_Power) of Unsigned_32 :=
     (Minus_20_dBm => 16#EC#,
      Minus_16_dBm => 16#F0#,
      Minus_12_dBm => 16#F4#,
      Minus_8_dBm  => 16#F8#,
      Minus_4_dBm  => 16#FC#,
      Zero_dBm     => 16#00#,
      Plus_4_dBm   => 16#04#);

   Poll_Interval : constant Time_Span := Microseconds (500);

   --  Paketbuffertar som radion läser/skriver med EasyDMA. Volatile så att
   --  kompilatorn varken flyttar skrivningar förbi TASKS_TXEN eller cachar
   --  läsningar av det radion har skrivit.
   TX_Packet : array (0 .. Max_PDU_Length - 1) of Byte
     with Volatile, Alignment => 4;
   RX_Packet : array (0 .. Max_PDU_Length - 1) of Byte
     with Volatile, Alignment => 4;

   Is_Initialized : Boolean := False;

   function Address_Of (A : System.Address) return Unsigned_32 is
     (Unsigned_32 (System.Storage_Elements.To_Integer (A)));

   -----------------
   -- Initialized --
   -----------------

   function Initialized return Boolean is (Is_Initialized);

   ------------------
   -- Set_TX_Power --
   ------------------

   procedure Set_TX_Power (Power : TX_Power) is
   begin
      RADIO.Txpower := Power_Value (Power);
   end Set_TX_Power;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize (Power : TX_Power := Zero_dBm) is
   begin
      --  Starta HF-kristallen (HFXO); radion kräver den.
      Clock_Regs.Events_HFCLKSTARTED := 0;
      Clock_Regs.Tasks_HFCLKSTART := 1;
      while Clock_Regs.Events_HFCLKSTARTED = 0 loop
         null;
      end loop;

      RADIO.Mode := Mode_Ble_1Mbit;

      --  PCNF0: LFLEN = 8 bitar längdfält, S0LEN = 1 byte (PDU-headern),
      --  S1LEN = 0, PLEN = 8 bitars preamble.
      RADIO.Pcnf0 := 8 or Shift_Left (1, 8);

      --  PCNF1: MAXLEN = 37, STATLEN = 0, BALEN = 3 (4 byte access address
      --  = 3 byte base + 1 byte prefix), little endian, whitening på.
      RADIO.Pcnf1 := 37 or Shift_Left (3, 16) or Shift_Left (1, 25);

      --  Access address 0x8E89BED6: de tre låga byten i BASE0 (vänsterställda)
      --  och den höga byten i PREFIX0 (logisk adress 0).
      RADIO.Base0       := Shift_Left (Adv_Access_Address, 8);
      RADIO.Prefix0     := Shift_Right (Adv_Access_Address, 24);
      RADIO.Txaddress   := 0;
      RADIO.Rxaddresses := 1;   --  ta emot på logisk adress 0

      --  CRC: 3 byte, räknas inte över adressen.
      RADIO.Crccnf  := 3 or Shift_Left (1, 8);
      RADIO.Crcpoly := BLE_CRC_Poly;
      RADIO.Crcinit := Adv_CRC_Init;

      Set_TX_Power (Power);
      Is_Initialized := True;
   end Initialize;

   -----------------------
   -- Wait_For_Disabled --
   -----------------------

   procedure Wait_For_Disabled is
   begin
      while RADIO.Events_Disabled = 0 loop
         null;
      end loop;
      RADIO.Events_Disabled := 0;
   end Wait_For_Disabled;

   ------------------------------
   -- Transmit_Advertising_PDU --
   ------------------------------

   procedure Transmit_Advertising_PDU
     (Channel : Advertising_Channel;
      PDU     : Byte_Array)
   is
   begin
      for I in PDU'Range loop
         TX_Packet (I - PDU'First) := PDU (I);
      end loop;

      RADIO.Packetptr   := Address_Of (TX_Packet'Address);
      RADIO.Frequency   := Channel_Frequency (Channel);
      RADIO.Datawhiteiv := Unsigned_32 (Channel);

      RADIO.Events_Ready    := 0;
      RADIO.Events_End      := 0;
      RADIO.Events_Disabled := 0;

      --  READY -> START och END -> DISABLE: en TXEN skickar exakt ett paket
      --  och stänger sedan av radion igen.
      RADIO.Shorts     := Short_Ready_Start or Short_End_Disable;
      RADIO.Tasks_TXEN := 1;

      Wait_For_Disabled;
      RADIO.Shorts := 0;
   end Transmit_Advertising_PDU;

   -----------------------------
   -- Receive_Advertising_PDU --
   -----------------------------

   procedure Receive_Advertising_PDU
     (Channel  : Advertising_Channel;
      Deadline : Time;
      PDU      : out PDU_Buffer;
      Length   : out Natural;
      RSSI     : out Integer;
      Received : out Boolean)
   is
   begin
      PDU      := (others => 0);
      Length   := 0;
      RSSI     := 0;
      Received := False;

      RADIO.Packetptr   := Address_Of (RX_Packet'Address);
      RADIO.Frequency   := Channel_Frequency (Channel);
      RADIO.Datawhiteiv := Unsigned_32 (Channel);

      --  READY -> START, END -> DISABLE, och RSSI mäts från det att
      --  adressen matchat tills radion stängs av.
      RADIO.Shorts := Short_Ready_Start or Short_End_Disable
                      or Short_Address_RSSIStart or Short_Disabled_RSSIStop;

      loop
         RADIO.Events_Disabled := 0;
         RADIO.Events_RSSIEND  := 0;
         RADIO.Tasks_RXEN      := 1;

         --  Vänta på ett paket eller på att tiden tar slut.
         while RADIO.Events_Disabled = 0 loop
            if Clock >= Deadline then
               RADIO.Tasks_Disable := 1;
               Wait_For_Disabled;
               RADIO.Shorts := 0;
               return;
            end if;
            delay until Clock + Poll_Interval;
         end loop;
         RADIO.Events_Disabled := 0;

         if RADIO.Crcstatus = 1 then
            Length :=
              Natural'Min (2 + Natural (RX_Packet (1)), Max_PDU_Length);
            for I in 0 .. Length - 1 loop
               PDU (I) := RX_Packet (I);
            end loop;
            RSSI     := -Integer (RADIO.Rssisample and 16#7F#);
            Received := True;
            RADIO.Shorts := 0;
            return;
         end if;

         --  Fel CRC: lyssna vidare om det finns tid kvar.
         exit when Clock >= Deadline;
      end loop;

      RADIO.Shorts := 0;
   end Receive_Advertising_PDU;

end Microbit_V2.Radio;
