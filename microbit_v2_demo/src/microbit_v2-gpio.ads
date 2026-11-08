--  Minimal GPIO för nRF52833. Till skillnad från nRF51 finns två portar:
--  P0 (pinnar 0..31) och P1 (pinnar 0..9). micro:bit v2 använder P1 bland
--  annat för LED-kolumn 4 (P1.05).

package Microbit_V2.GPIO is

   type Port_Number is range 0 .. 1;
   type Pin_Number  is range 0 .. 31;

   type Pin is record
      Port : Port_Number;
      Num  : Pin_Number;
   end record;

   type Pull_Mode is (No_Pull, Pull_Down, Pull_Up);

   procedure Configure_Output (P : Pin; High_Drive : Boolean := False);
   procedure Configure_Input  (P : Pin; Pull : Pull_Mode := No_Pull);

   procedure Set   (P : Pin) with Inline;
   procedure Clear (P : Pin) with Inline;
   procedure Write (P : Pin; High : Boolean) with Inline;

   function Is_High (P : Pin) return Boolean with Inline;

end Microbit_V2.GPIO;
