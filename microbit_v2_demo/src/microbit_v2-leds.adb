with System;
with Microbit_V2.GPIO; use Microbit_V2.GPIO;
with Microbit_V2.Font;

package body Microbit_V2.LEDs is

   use Ada.Real_Time;

   --  Pinnar enligt CODAL (codal-microbit-v2, model/MicroBitIO.h).
   --  En LED lyser när dess rad är hög och dess kolumn är låg.
   Row_Pins : constant array (Coord) of Pin :=
     ((0, 21), (0, 22), (0, 15), (0, 24), (0, 19));
   Col_Pins : constant array (Coord) of Pin :=
     ((0, 28), (0, 11), (0, 31), (1, 5), (0, 30));

   Row_Time : constant Time_Span := Milliseconds (2);

   --  Hög prioritet så att visningen inte flimrar när andra tasks är
   --  upptagna; Scanner gör väldigt lite arbete per varv.
   Frame_Ceiling    : constant System.Priority := System.Priority'Last;
   Scanner_Priority : constant System.Priority := System.Priority'Last;

   -----------
   -- Frame --
   -----------

   protected Frame with Priority => Frame_Ceiling is
      procedure Put (Img : Image);
      procedure Put_Pixel (X, Y : Coord; On : Boolean);
      function Get return Image;
   private
      Buffer : Image := Blank;
   end Frame;

   protected body Frame is

      procedure Put (Img : Image) is
      begin
         Buffer := Img;
      end Put;

      procedure Put_Pixel (X, Y : Coord; On : Boolean) is
      begin
         Buffer (Y, X) := On;
      end Put_Pixel;

      function Get return Image is (Buffer);

   end Frame;

   -------------
   -- Scanner --
   -------------

   task Scanner with Priority => Scanner_Priority;

   task body Scanner is
      Next : Time := Clock;
      Img  : Image;
   begin
      for P of Row_Pins loop
         Configure_Output (P);
         Clear (P);
      end loop;

      for P of Col_Pins loop
         Configure_Output (P);
         Set (P);       --  kolumnerna är aktivt låga, alltså släckt
      end loop;

      loop
         Img := Frame.Get;   --  en hel bild per varv, så ingen "tearing"

         for Y in Coord loop
            Clear (Row_Pins ((Y + 4) mod 5));   --  släck föregående rad

            for X in Coord loop
               Write (Col_Pins (X), High => not Img (Y, X));
            end loop;

            Set (Row_Pins (Y));

            Next := Next + Row_Time;
            delay until Next;
         end loop;
      end loop;
   end Scanner;

   --------------
   -- To_Image --
   --------------

   function To_Image (Row_0, Row_1, Row_2, Row_3, Row_4 : String) return Image
   is
      Result : Image := Blank;

      procedure Fill (Y : Coord; Row : String) is
      begin
         for X in Coord loop
            Result (Y, X) := Row (Row'First + X) in '#' | '1';
         end loop;
      end Fill;

   begin
      Fill (0, Row_0);
      Fill (1, Row_1);
      Fill (2, Row_2);
      Fill (3, Row_3);
      Fill (4, Row_4);
      return Result;
   end To_Image;

   ----------
   -- Show --
   ----------

   procedure Show (Img : Image) is
   begin
      Frame.Put (Img);
   end Show;

   ---------
   -- Set --
   ---------

   procedure Set (X, Y : Coord; On : Boolean := True) is
   begin
      Frame.Put_Pixel (X, Y, On);
   end Set;

   -----------
   -- Clear --
   -----------

   procedure Clear (X, Y : Coord) is
   begin
      Frame.Put_Pixel (X, Y, False);
   end Clear;

   procedure Clear is
   begin
      Frame.Put (Blank);
   end Clear;

   -------------
   -- Current --
   -------------

   function Current return Image is (Frame.Get);

   ---------------
   -- Glyph_For --
   ---------------

   function Glyph_For (C : Character) return Font.Glyph is
     (Font.Glyphs (if C in Font.Glyph_Character then C else '?'));

   ----------
   -- Show --
   ----------

   procedure Show (C : Character) is
      G      : constant Font.Glyph := Glyph_For (C);
      Result : Image;
   begin
      for Y in Coord loop
         for X in Coord loop
            Result (Y, X) := Font.Pixel (G, X, Y);
         end loop;
      end loop;
      Frame.Put (Result);
   end Show;

   -----------------
   -- Scroll_Text --
   -----------------

   procedure Scroll_Text
     (Text : String;
      Step : Time_Span := Milliseconds (120))
   is
      Char_Width : constant := 6;   --  5 kolumner glyf + 1 kolumn mellanrum

      --  Texten ses som en lång remsa av kolumner. Kolumn V (0-baserad)
      --  hör till tecken V / Char_Width. Remsan börjar 5 kolumner till höger
      --  om displayen och slutar när sista tecknet lämnat vänsterkanten.

      function Lit (V : Integer; Y : Coord) return Boolean is
         Index  : Integer;
         Column : Integer;
      begin
         if V < 0 then
            return False;
         end if;

         Index  := V / Char_Width;
         Column := V mod Char_Width;

         if Index >= Text'Length or else Column >= 5 then
            return False;
         end if;

         return Font.Pixel (Glyph_For (Text (Text'First + Index)), Column, Y);
      end Lit;

      Total : constant Integer := Text'Length * Char_Width + 5;
      Img   : Image;
      Next  : Time := Clock;
   begin
      for Offset in 0 .. Total loop
         for Y in Coord loop
            for X in Coord loop
               Img (Y, X) := Lit (Offset + X - 5, Y);
            end loop;
         end loop;

         Frame.Put (Img);
         Next := Next + Step;
         delay until Next;
      end loop;
   end Scroll_Text;

   -------------------
   -- Färdiga bilder --
   -------------------

   function Heart return Image is
     (To_Image (".#.#.",
                "#####",
                "#####",
                ".###.",
                "..#.."));

   function Smile return Image is
     (To_Image (".....",
                ".#.#.",
                ".....",
                "#...#",
                ".###."));

   function Sad return Image is
     (To_Image (".....",
                ".#.#.",
                ".....",
                ".###.",
                "#...#"));

   function Yes return Image is
     (To_Image (".....",
                "....#",
                "...#.",
                "#.#..",
                ".#..."));

   function No return Image is
     (To_Image ("#...#",
                ".#.#.",
                "..#..",
                ".#.#.",
                "#...#"));

end Microbit_V2.LEDs;
