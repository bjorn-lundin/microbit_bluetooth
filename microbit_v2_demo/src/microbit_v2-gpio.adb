with System;
with Interfaces; use Interfaces;

package body Microbit_V2.GPIO is

   --  Registerlayout enligt nRF52833 Product Specification / SVD.
   type Pin_Cnf_Array is array (Pin_Number) of Unsigned_32;

   type GPIO_Port is record
      Out_Reg : Unsigned_32;
      Outset  : Unsigned_32;
      Outclr  : Unsigned_32;
      In_Reg  : Unsigned_32;
      Dir     : Unsigned_32;
      Dirset  : Unsigned_32;
      Dirclr  : Unsigned_32;
      Pin_Cnf : Pin_Cnf_Array;
   end record
     with Volatile;

   for GPIO_Port use record
      Out_Reg at 16#504# range 0 .. 31;
      Outset  at 16#508# range 0 .. 31;
      Outclr  at 16#50C# range 0 .. 31;
      In_Reg  at 16#510# range 0 .. 31;
      Dir     at 16#514# range 0 .. 31;
      Dirset  at 16#518# range 0 .. 31;
      Dirclr  at 16#51C# range 0 .. 31;
      Pin_Cnf at 16#700# range 0 .. 32 * 32 - 1;
   end record;

   P0 : aliased GPIO_Port
     with Import, Address => System'To_Address (16#5000_0000#);
   P1 : aliased GPIO_Port
     with Import, Address => System'To_Address (16#5000_0300#);

   Ports : constant array (Port_Number) of not null access GPIO_Port :=
     (0 => P0'Access, 1 => P1'Access);

   --  PIN_CNF-fält
   Dir_Output       : constant Unsigned_32 := 2#1#;        --  bit 0
   Input_Disconnect : constant Unsigned_32 := 2#10#;       --  bit 1
   Pull_Down_Bits   : constant Unsigned_32 := 1 * 2**2;    --  bit 2..3
   Pull_Up_Bits     : constant Unsigned_32 := 3 * 2**2;
   Drive_H0H1       : constant Unsigned_32 := 3 * 2**8;    --  bit 8..10

   function Mask (P : Pin) return Unsigned_32 is
     (Shift_Left (1, Natural (P.Num)))
   with Inline;

   ----------------------
   -- Configure_Output --
   ----------------------

   procedure Configure_Output (P : Pin; High_Drive : Boolean := False) is
   begin
      Ports (P.Port).Pin_Cnf (P.Num) :=
        Dir_Output or Input_Disconnect
        or (if High_Drive then Drive_H0H1 else 0);
   end Configure_Output;

   ---------------------
   -- Configure_Input --
   ---------------------

   procedure Configure_Input (P : Pin; Pull : Pull_Mode := No_Pull) is
   begin
      Ports (P.Port).Pin_Cnf (P.Num) :=
        (case Pull is
            when No_Pull   => 0,
            when Pull_Down => Pull_Down_Bits,
            when Pull_Up   => Pull_Up_Bits);
   end Configure_Input;

   ---------
   -- Set --
   ---------

   procedure Set (P : Pin) is
   begin
      Ports (P.Port).Outset := Mask (P);
   end Set;

   -----------
   -- Clear --
   -----------

   procedure Clear (P : Pin) is
   begin
      Ports (P.Port).Outclr := Mask (P);
   end Clear;

   -----------
   -- Write --
   -----------

   procedure Write (P : Pin; High : Boolean) is
   begin
      if High then
         Set (P);
      else
         Clear (P);
      end if;
   end Write;

   -------------
   -- Is_High --
   -------------

   function Is_High (P : Pin) return Boolean is
     ((Ports (P.Port).In_Reg and Mask (P)) /= 0);

end Microbit_V2.GPIO;
