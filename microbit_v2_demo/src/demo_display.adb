with System;
with Microbit_V2.LEDs;

package body Demo_Display is

   subtype Text_Length is Natural range 0 .. Max_Text;

   type Job is record
      Text   : String (1 .. Max_Text) := (others => ' ');
      Length : Text_Length := 0;
   end record;

   -------------
   -- Mailbox --
   -------------

   protected Mailbox with Priority => System.Default_Priority is
      procedure Post (J : Job);
      entry Take (J : out Job);
      procedure Done;
      function Is_Busy return Boolean;
   private
      Pending : Job;
      Ready   : Boolean := False;   --  enkel barriär, som Ravenscar kräver
      Working : Boolean := False;
   end Mailbox;

   protected body Mailbox is

      procedure Post (J : Job) is
      begin
         Pending := J;
         Ready   := True;
         Working := True;
      end Post;

      entry Take (J : out Job) when Ready is
      begin
         J     := Pending;
         Ready := False;
      end Take;

      procedure Done is
      begin
         --  Fortfarande upptagen om en ny text hann postas under rullningen.
         Working := Ready;
      end Done;

      function Is_Busy return Boolean is (Working);

   end Mailbox;

   --------------
   -- Scroller --
   --------------

   task Scroller with Priority => System.Default_Priority;

   task body Scroller is
      J : Job;
   begin
      loop
         Mailbox.Take (J);
         Microbit_V2.LEDs.Scroll_Text (J.Text (1 .. J.Length));
         Mailbox.Done;
      end loop;
   end Scroller;

   ------------
   -- Scroll --
   ------------

   procedure Scroll (Text : String) is
      J : Job;
   begin
      J.Length := Text'Length;
      J.Text (1 .. Text'Length) := Text;
      Mailbox.Post (J);
   end Scroll;

   ----------
   -- Busy --
   ----------

   function Busy return Boolean is (Mailbox.Is_Busy);

end Demo_Display;
