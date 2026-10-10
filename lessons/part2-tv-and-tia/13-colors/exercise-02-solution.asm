; =============================================================================
; LESSON 13 — EXERCISE 2 SOLUTION: The Chart Match
; =============================================================================
;
; Challenge: render the lesson's band->name table as a static chart.  Sixteen
; bands of twelve lines, one named color per band, straight out of a lookup
; table — no clock, no stepping, no computation.  The names live in the
; lesson's table (and its caption), not on screen: match each band to its
; name by eye.
;
; Why this works:
;   - ChartColors is the whole picture: sixteen palette bytes, written in
;     the same order as the lesson's table, top band first.  The kernel is
;     the lesson's band loop with the OR removed — the table entries are
;     already complete bytes.
;   - Band 0 (the release line) counts inside its 12: Y = 11 after its color
;     is written in HBLANK.
;   - Counted waits: 11 + 15 x 12 = 191, plus the release line = 192.  The
;     frame around it: 3 + 37 + 192 + 30 = 262.
;   - There are no RAM variables at all — the chart never changes, so
;     nothing needs to be remembered between frames.
;
; The table, band by band (the lesson's names):
;    0 $0E light gray     4 $42 red           8 $84 blue          12 $C8 green
;    1 $1A gold           5 $5E pink          9 $9E light blue    13 $DE bright yellow-green
;    2 $2E orange         6 $6E light violet 10 $AE aqua          14 $EE yellow-green
;    3 $3E peach          7 $7E violet       11 $BE teal-green    15 $FE yellow
;
; Debugger: break at BandWrite and watch A walk the table — every byte is
; a complete palette color, and no two bands share one.  Watch COLUBK in
; the TIA view: it should agree with the table for all sixteen bands.
;
; Expected screen: sixteen equal 12-line bands — the course's named colors
; as a still chart, light gray at the top through the wheel to yellow at
; the bottom.  Compare band for band against the lesson table; that match
; IS the exercise.
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame
; =============================================================================
VBLANK_LINES   = 37     ; blanked lines between VSYNC and the picture
BANDS          = 16     ; visible bands — one per table entry
LINES          = 12     ; scanlines per band (16 x 12 = 192 visible lines)
OVERSCAN_LINES = 30     ; blanked lines after the picture

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
; MAIN LOOP  —  one pass = one TV frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; VSYNC — exactly 3 lines
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = start VSYNC
    STA VSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    LDA #$00
    STA VSYNC               ; exactly 3 lines

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
; -----------------------------------------------------------------------------
; VBLANK — 37 blanked lines
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    LDX #VBLANK_LINES
VblankLines:
    STA WSYNC
    DEX
    BNE VblankLines

VisibleStart:               ; debugger checkpoint: visible's first line (Stella: 37)
; -----------------------------------------------------------------------------
; VISIBLE — 192 lines = sixteen named-color bands of 12
; -----------------------------------------------------------------------------
; The lesson's kernel, minus the OR: the table entries ARE complete bytes.
    LDA #$00
    STA VBLANK              ; release the beam — visible line 1
    LDX #$00
    LDA ChartColors,X       ; band 0: light gray ($0E)
    STA COLUBK              ; lands in HBLANK: the release line shows it
    LDY #LINES-1            ; Y = 11: release line + 11 painted = 12
    JSR PaintLines
    LDX #$01                ; bands 1...15 remain
BandLoop:
    LDA ChartColors,X       ; this band's named color, out of the table
BandWrite:                  ; debugger checkpoint: A = the band's byte, X = band
    LDY #LINES              ; a full band of 12
    JSR PaintLines
    INX
    CPX #BANDS              ; 0...15 — the loop bound IS the table's size
    BNE BandLoop

    STA WSYNC               ; let the last band line finish before blanking
    LDA #$02
OverscanStart:              ; debugger checkpoint: overscan's first line (Stella: 229)
    STA VBLANK
    LDX #OVERSCAN_LINES
OverscanLines:
    STA WSYNC
    DEX
    BNE OverscanLines
    JMP StartFrame          ; 262 lines done: next frame

; =============================================================================
; SUBROUTINE: PaintLines — paint Y scanlines with the color in A
; =============================================================================
; How to call:   A = color byte, Y = scanline count, then JSR PaintLines
; What it does:  waits for the next scanline to start, then writes the color
;                to COLUBK once per line for Y lines — every write lands in
;                HBLANK, so band boundaries fall exactly on scanlines.
; Registers:     A survives, X is never touched (the band index lives there),
;                Y is used up counting lines down to 0.
; Stack:         JSR pushed the return address; the RTS pops it.
; =============================================================================
PaintLines:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEY                     ; one line fewer to go
    BNE -
    RTS

; =============================================================================
; DATA — the course's named colors, top band first
; =============================================================================
; Same order as the lesson's band->name table.  Each entry is the complete
; palette byte: hue nibble + luminance field, bit 0 zero.
    !align 15, 0, 0
ChartColors:
    !byte $0E, $1A, $2E, $3E    ; 0 light gray, 1 gold, 2 orange, 3 peach
    !byte $42, $5E, $6E, $7E    ; 4 red, 5 pink, 6 light violet, 7 violet
    !byte $84, $9E, $AE, $BE    ; 8 blue, 9 light blue, 10 aqua, 11 teal-green
    !byte $C8, $DE, $EE, $FE    ; 12 green, 13 bright yellow-green, 14 yellow-green, 15 yellow

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
