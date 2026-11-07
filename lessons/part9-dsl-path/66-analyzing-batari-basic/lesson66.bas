 rem ===========================================================================
 rem LESSON 66 - a course-authored batari BASIC program for analysis
 rem ===========================================================================
 rem This is the high-level program the lesson takes apart.  It is deliberately
 rem small: every line maps to a generated 6502 construct the document quotes.
 rem
 rem Build (bB 1.9 + wasmtime 50.0.1; see the lesson document for the full
 rem command):
 rem   export bB=<path-to-bB-1.9>
 rem   export PATH=<path-to-wasmtime-50.0.1>:$PATH
 rem   sh "$bB/2600basic.sh" lesson66.bas
 rem
 rem The build produces lesson66.bas.bin (4,096 bytes) and the linked
 rem generated listing lesson66.bas.asm (committed as lesson66.generated.txt).
 rem ===========================================================================

 set romsize 4k
 set kernel_options no_blank_lines
 scorecolor = $0e

 rem --- the playfield: eleven rows of thirty-two four-pixel chunks ----------
 rem The default bB playfield is eleven rows; each row is stored as four
 rem bytes, so the playfield array fills $A4-$D3.  A dot is an empty chunk.
 playfield:
 ................................
 ................................
 ................................
 ................................
 ................................
 ................................
 ................................
 ................................
 ................................
 ................................
 ................................
end

 rem --- player 0: the ship, six rows tall -----------------------------------
 player0:
 %00111100
 %01111110
 %11111111
 %11111111
 %01111110
 %00111100
end

 rem --- player 1: the enemy, six rows tall ----------------------------------
 player1:
 %00011000
 %00111100
 %01111110
 %11111111
 %01111110
 %00111100
end

 rem --- the starting positions ----------------------------------------------
 player0x = 60 : player0y = 80
 player1x = 100 : player1y = 80
 ballx = 80 : bally = 40 : ballheight = 4

 rem --- the main loop -------------------------------------------------------
 rem bB has no frame buffer: each statement writes RAM or a TIA register, and
 rem drawscreen runs the generated kernel that paints the frame from that RAM.
main
 COLUBK = $02
 COLUPF = $1a
 COLUP0 = $0e
 COLUP1 = $84
 player0y = player0y + 1
 if player0y > 120 then player0y = 60
 score = score + 1
 drawscreen
 goto main
