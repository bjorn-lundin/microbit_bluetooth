--  Låter demoprogrammet rulla text i bakgrunden, så att huvudloopen kan
--  fortsätta lyssna på radion under tiden. Under Ravenscar/Jorvik måste
--  tasks ligga på biblioteksnivå, därför ett eget paket.

package Demo_Display is

   Max_Text : constant := 20;

   procedure Scroll (Text : String)
     with Pre => Text'Length <= Max_Text;
   --  Börjar rulla texten i bakgrunden och returnerar direkt. En ny text
   --  som skickas medan en rullning pågår visas när den är klar (den
   --  senaste vinner).

   function Busy return Boolean;
   --  True från det att Scroll anropats tills texten har rullat klart.

end Demo_Display;
