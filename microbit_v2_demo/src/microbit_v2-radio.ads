--  nRF52833-radion i BLE 1 Mbit-läge, styrd direkt via register (ingen
--  SoftDevice). Paketet kan skicka och ta emot råa BLE-advertising-PDU:er
--  på advertising-kanalerna 37, 38 och 39.
--
--  Motsvarar NRF.Radio i nrf5x_hal för v1, men skrivet för nRF52833.
--  Skillnader mot nRF51 som spelar roll här:
--    * HF-klockan måste komma från extern kristall (HFXO) för radion;
--      runtimen startar den inte, så Initialize gör det.
--    * TXPOWER har andra steg (+4 .. -40 dBm).
--    * PCNF0 har fler fält (PLEN m.fl.); standardvärdena passar BLE 1M.

with Ada.Real_Time;

package Microbit_V2.Radio is

   type BLE_Channel is range 0 .. 39;
   subtype Advertising_Channel is BLE_Channel range 37 .. 39;

   type TX_Power is
     (Minus_20_dBm, Minus_16_dBm, Minus_12_dBm, Minus_8_dBm, Minus_4_dBm,
      Zero_dBm, Plus_4_dBm);

   --  En advertising-PDU är 2 byte header + högst 37 byte payload.
   Max_PDU_Length : constant := 2 + 37;

   subtype PDU_Buffer is Byte_Array (0 .. Max_PDU_Length - 1);

   procedure Initialize (Power : TX_Power := Zero_dBm)
     with Post => Initialized;

   function Initialized return Boolean;

   procedure Set_TX_Power (Power : TX_Power)
     with Pre => Initialized;

   ------------
   -- Sändning --
   ------------

   procedure Transmit_Advertising_PDU
     (Channel : Advertising_Channel;
      PDU     : Byte_Array)
     with Pre => Initialized
                 and then PDU'Length in 2 .. Max_PDU_Length
                 and then Natural (PDU (PDU'First + 1)) = PDU'Length - 2;
   --  Skickar PDU:n (header + payload, utan preamble, access address och
   --  CRC; dem lägger radion till) och väntar tills sändningen är klar,
   --  ungefär 0,5 ms.

   ---------------
   -- Mottagning --
   ---------------

   procedure Receive_Advertising_PDU
     (Channel  : Advertising_Channel;
      Deadline : Ada.Real_Time.Time;
      PDU      : out PDU_Buffer;
      Length   : out Natural;
      RSSI     : out Integer;
      Received : out Boolean)
     with Pre => Initialized;
   --  Lyssnar på kanalen tills ett paket med korrekt CRC tagits emot eller
   --  Deadline passerats. Vid mottagning är Received = True, PDU (0 ..
   --  Length - 1) innehåller header + payload och RSSI är signalstyrkan i
   --  dBm (negativ). Paket med fel CRC hoppas över.
   --
   --  Anroparen sover i små steg (0,5 ms) medan radion lyssnar, så andra
   --  tasks får köra under tiden.

end Microbit_V2.Radio;
