--  5x5 LED-matrisen på micro:bit v2.
--
--  Matrisen multiplexas radvis av en bakgrundstask (Scanner) i paketets
--  kropp: en rad i taget tänds i 2 ms, så hela bilden uppdateras 100 gånger
--  per sekund. Du behöver bara ändra bilden; tasken startar automatiskt när
--  paketet elaboreras.
--
--  Koordinater som i MakeCode/CODAL: X är kolumn 0..4 (vänster till höger),
--  Y är rad 0..4 (uppifrån och ned).

with Ada.Real_Time;

package Microbit_V2.LEDs is

   subtype Coord is Natural range 0 .. 4;

   type Image is array (Coord, Coord) of Boolean;   --  indexeras (Y, X)

   Blank : constant Image := (others => (others => False));

   --  Bygg en bild av fem strängar, en per rad. '#' eller '1' betyder tänd,
   --  allt annat släckt. Exempel: To_Image (".#.#.", ...)
   function To_Image (Row_0, Row_1, Row_2, Row_3, Row_4 : String) return Image
     with Pre => Row_0'Length = 5 and then Row_1'Length = 5
                 and then Row_2'Length = 5 and then Row_3'Length = 5
                 and then Row_4'Length = 5;

   ---------------------
   -- Bild-operationer --
   ---------------------

   procedure Show (Img : Image);
   --  Visa en hel bild.

   procedure Set (X, Y : Coord; On : Boolean := True);
   --  Tänd (eller släck) en enskild LED.

   procedure Clear (X, Y : Coord);
   --  Släck en enskild LED.

   procedure Clear;
   --  Släck alla LED:er.

   function Current return Image;
   --  Bilden som visas just nu.

   ----------
   -- Text --
   ----------

   procedure Show (C : Character);
   --  Visa ett tecken (ASCII 32..126; övriga visas som '?').

   procedure Scroll_Text
     (Text : String;
      Step : Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (120));
   --  Rulla texten från höger till vänster. Blockerar anroparen tills
   --  texten har rullat förbi helt.

   -------------------
   -- Färdiga bilder --
   -------------------

   function Heart  return Image;
   function Smile  return Image;
   function Sad    return Image;
   function Yes    return Image;
   function No     return Image;

end Microbit_V2.LEDs;
