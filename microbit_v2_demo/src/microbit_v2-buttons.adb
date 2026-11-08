with Microbit_V2.GPIO; use Microbit_V2.GPIO;

package body Microbit_V2.Buttons is

   --  Pinnar enligt CODAL: A = P0.14, B = P0.23. Knapparna drar pinnen
   --  till jord när de trycks ned (aktivt låga).
   Pins : constant array (Button) of Pin := (A => (0, 14), B => (0, 23));

   function Is_Pressed (Btn : Button) return Boolean is
     (not Is_High (Pins (Btn)));

begin
   for P of Pins loop
      Configure_Input (P, Pull => Pull_Up);
   end loop;
end Microbit_V2.Buttons;
