; =============================================================================
; LESSON 08 — EXERCISE 1 SOLUTION: Eight Bands from Eight Calls
; =============================================================================
;
; Challenge: keep the same four colors but double the number of bands — EIGHT
; bands of 24 scanlines instead of four of 48 — so the frame makes eight calls
; to PaintBand instead of four.
;
; The change is almost entirely in the constants and the color table:
;
;   BANDS  4 -> 8        the band loop now runs eight times (8 x 24 = 192
;                        painted lines, plus the beam-release line = 193)
;   LINES 48 -> 24       each band is half as tall
;   BandColors           the palette repeats: $42 $C8 $96 $1A $42 $C8 $96 $1A
;
; The band loop itself is untouched — that is the payoff of a shared
; subroutine.  The stack traffic doubles with it: every one of the eight calls
; still pushes the band counter, pushes a return address, pops the return
; address and pulls the counter, so DrawScreen now works the stack hard twice
; per band.
;
; Expected screen: eight bands — red, green, blue, gold, then the same four
; colors again at half height.  As in the lesson ROM the top band is one
; scanline taller: the beam-release line already carries its color.
;
; (Stack note: the deepest point is still SP = $FA.  Painting more bands does
; not make the stack deeper, because the round trip is balanced within each
; band — frames, not bands, would make it grow.)
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- Colors (NTSC) ---
RED         = $42       ; band 0 and band 4
GREEN       = $C8       ; band 1 and band 5
BLUE        = $96       ; band 2 and band 6
GOLD        = $1A       ; band 3 and band 7

; --- Geometry ---
BANDS       = 8         ; bands on the screen: 8 calls of 24 painted lines
LINES       = 24        ; scanlines per PaintBand call (top band + the release
                        ; line; 8 x 24 + 1 = 193 non-blanked scanlines)

    * = $F000

Reset:
    +clean_start

; =============================================================================
; MAIN LOOP — one pass = one frame; SP = $FF at this label
; =============================================================================
StartFrame:
    +vsync

    LDA #$02
    STA VBLANK
    +set_timer 43
    +wait_timer

    LDA BandColors          ; pre-load the top band's color before the beam
    STA COLUBK              ; is released (a call costs cycles — see the lesson)

    LDA #$00
    STA VBLANK

    JSR DrawScreen          ; SP: $FF -> $FD ... back to $FF on return

    STA WSYNC               ; move the blank-on into HBLANK: the unwind home
                            ; from DrawScreen would otherwise clip partway
                            ; across the last band line

    LDA #$02
    STA VBLANK
    +set_timer 35
    +wait_timer

    JMP StartFrame

; =============================================================================
; DrawScreen — eight bands, eight calls to the same painter
; =============================================================================
DrawScreen:
    LDX #0                  ; X = band index: 0 = top band, 7 = bottom band
BandLoop:
    TXA
    PHA                     ; save the band counter   (SP: $FD -> $FC)
    LDA BandColors,X        ; A = this band's color
    LDX #LINES              ; X = 24: the line count PaintBand wants
    JSR PaintBand           ; paint the band          (SP: $FC -> $FA inside)
    PLA
    TAX                     ; X = the band counter back (SP: $FC -> $FD)
    INX
    CPX #BANDS              ; eight bands painted?
    BNE BandLoop
    RTS                     ; SP: $FD -> $FF

; =============================================================================
; PaintBand — paint X scanlines of the color in A (unchanged from the lesson)
; =============================================================================
PaintBand:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEX
    BNE -
    RTS

; =============================================================================
; DATA — the palette, twice: eight bands in four colors
; =============================================================================
BandColors:
    !byte RED, GREEN, BLUE, GOLD        ; bands 0..3
    !byte RED, GREEN, BLUE, GOLD        ; bands 4..7

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
