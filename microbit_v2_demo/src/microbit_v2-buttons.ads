--  Knapp A och B på framsidan av micro:bit v2.

package Microbit_V2.Buttons is

   type Button is (A, B);

   function Is_Pressed (Btn : Button) return Boolean;

end Microbit_V2.Buttons;
