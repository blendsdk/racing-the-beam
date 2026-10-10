; =============================================================================
; LESSON 11 — EXERCISE 1 SOLUTION: A Table of Your Own
; =============================================================================
;
; Challenge: write a second 16-byte color table and display it with LDA
; table,X — sixteen equal bands, one per table entry, top to bottom.  The
; lesson ROM hands you both the table and the moving offset; here you supply
; the colors and the picture stands still.
;
; Why this works:
;   - !byte in ROM is the table; LDA Palette,X is the reader.  X is BOTH the
;     band number and the table index, so the loop that walks the screen and
;     the loop that walks the table are one single loop.
;   - The table has exactly 16 entries and X runs 0...15; CPX #BANDS stops the
;     loop at the table's edge, so no mask is needed here.  When an index only
;     ever counts up, the loop bound IS the bounds discipline.
;   - PaintLines counts lines in Y and never touches X (the shape of Lesson
;     09's PaintBand contract), which is what lets X stay the index across
;     the call.
;
; The table: the 16 hues at one luminance — entry k = (k << 4) | $0E.  Hue 0
; is the gray step of the color wheel; hues 1...15 walk the wheel, so the
; picture is a constant-brightness rainbow with a gray step in it.
;
; Frame geometry: 192 non-blanked scanlines — 16 equal bands of 12 lines.
; Band 0's color is fetched during VBLANK, so the beam-release line is band
; 0's FIRST line and PaintLines paints the other 11; every other band is one
; PaintLines call of 12 lines.  The blank-on after the last band waits for
; HBLANK first (STA WSYNC), so the last band line is painted whole.
;
; Expected screen: sixteen equal bands of the same brightness — light gray at
; the top, then the color wheel in order: yellow, orange, peach, pink, violet,
; blue-violet, blue, light blue, aqua, green, and the yellow-greens, finishing
; in a yellow-orange at the bottom.  Nothing moves.
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
BANDS       = 16        ; bands on the screen — one per table entry
LINES       = 12        ; scanlines per band (16 x 12 = 192 non-blanked lines)

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame; the palette is static
; =============================================================================
StartFrame:
    +vsync                  ; 3-line VSYNC — "a new frame starts now"

    LDA #$02
    STA VBLANK              ; blank the beam while we set up
    +set_timer 43           ; ~37 scanlines of VBLANK

; -----------------------------------------------------------------------------
; BAND 0 — fetched while the beam is still blanked
; -----------------------------------------------------------------------------
; Band 0 is the TOP band, and its color has to be in COLUBK before the release
; line's visible portion starts — the store happens in HBLANK, right after
; VBLANK is cleared, so the release line is band 0's first line.  X = 0 selects
; the table's first entry; there is nothing else to compute.
    LDX #$00                ; X = 0: index 0 is both the top band and entry 0
    LDA Palette,X           ; LDA table,X — the index picks the entry
Band0Fetch:                 ; debugger checkpoint: break here, A = Palette[0], X = $00
    TAY                     ; park the color: +wait_timer clobbers A

    +wait_timer             ; finish the ~37 scanlines of VBLANK

    LDA #$00
    STA VBLANK              ; release the beam: this line is band 0's FIRST line
    TYA                     ; A = band 0's color again
    STA COLUBK              ; written in HBLANK, so the release line shows it
    LDY #LINES-1            ; Y = 11: release line + 11 painted = band 0's 12
    JSR PaintLines          ; paint them — A survives, X is never touched

; -----------------------------------------------------------------------------
; BANDS 1-15 — X walks the screen and the table together
; -----------------------------------------------------------------------------
    LDX #$01                ; X = 1: the second entry is next
BandLoop:
    LDA Palette,X           ; LDA table,X — entry X paints band X
BandFetch:                  ; debugger checkpoint: break here, A = Palette[X], X = index
    LDY #LINES              ; Y = 12: a full band
    JSR PaintLines          ; paint it — PaintLines never touches X
    INX                     ; next band, next entry
    CPX #BANDS              ; 0...15 — stop at the table's edge
    BNE BandLoop

; -----------------------------------------------------------------------------
; OVERSCAN
; -----------------------------------------------------------------------------
    STA WSYNC               ; wait for HBLANK before blanking: the last band
                            ; line is being drawn right now, so writing VBLANK
                            ; here would clip it partway across
    LDA #$02
    STA VBLANK
    +set_timer 35           ; ~30 scanlines of overscan
    +wait_timer

    JMP StartFrame          ; next frame — the picture never changes

; =============================================================================
; SUBROUTINE: PaintLines — paint Y scanlines of the color in A
; =============================================================================
; How to call:   A = color byte, Y = scanline count, then JSR PaintLines
; What it does:  waits for the next scanline to start, then writes the color
;                to COLUBK once per line for Y lines.  Writing the color
;                right after the WSYNC puts the change in the first few
;                cycles of the line, so band boundaries fall exactly on a
;                scanline.
; Registers:     A survives (still the color) and X is never touched — the
;                palette index lives in X, so this loop depends on that; Y
;                is used up: the line counter counts it down to 0.
; Stack:         JSR pushed the return address; the RTS pops it.
; =============================================================================
PaintLines:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEY                     ; one line fewer to go: 12, 11, ... 1
    BNE -                   ; loop until the line counter reaches 0
    RTS                     ; return; the return address comes off the stack

; =============================================================================
; DATA — a hue wheel at one luminance, read as Palette,X
; =============================================================================
; Entry k is (k << 4) | $0E: the hue nibble k runs 0...15 while the luminance
; nibble stays at 7, so the table is the color wheel itself with no
; light-to-dark ramp in it.  16-byte aligned, so X = 0...15 can never push a
; load across a page boundary (a page cross would cost one extra cycle).
; (!align's third field is the pad byte: 0 fills the gap with zeros.)
    !align 15, 0, 0
Palette:
    !byte $0E, $1E, $2E, $3E    ; hues 0-3  (0 is the gray step)
    !byte $4E, $5E, $6E, $7E    ; hues 4-7
    !byte $8E, $9E, $AE, $BE    ; hues 8-11
    !byte $CE, $DE, $EE, $FE    ; hues 12-15

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
