; =============================================================================
; LESSON 12 — EXERCISE 2 SOLUTION: 48 / 96 / 48
; =============================================================================
;
; Challenge: re-partition the visible area — keep the frame identical but
; split the 192 lines as 48 / 96 / 48 instead of four equal bands.
;
; Why this works:
;   - The release line is still band 0's first line: 48 lines total
;     (release line + 47 painted), red.
;   - The middle band is ONE PaintLines call with Y = 96 — twice as tall as
;     the band-0 code — painted blue.
;   - The bottom band is one call with Y = 48, green.
;   - Count the painted waits: 47 + 96 + 48 = 191, plus the release line
;     = 192 visible lines.  The VSYNC / VBLANK / overscan sections are
;     untouched, so the frame still waits out exactly 262 scanlines.
;   - "Changing the structure" is exactly this: the partition is whatever
;     the three size constants say it is, and the total is a number you
;     verify — 192 — not a shape you assume.
;
; Debugger: the band boundaries fall at visible lines 1 (release), 49 and
; 145 — frame scanlines 37, 85 and 181.  The MiddleBand and BottomBand
; checkpoints fire one line earlier (Stella scanlines 84 and 180, on the
; last line of the band above); the jumps between them are the partition,
; read off the debugger.
;
; Expected screen: three horizontal bands — red 48 lines, blue 96 lines
; (twice as tall as the red), green 48 lines — filling the same 192-line
; picture window as the lesson ROM, with the same steady frame.
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the phase lengths and the new partition
; =============================================================================
VBLANK_LINES   = 37     ; blanked lines between VSYNC and the picture
OVERSCAN_LINES = 30     ; blanked lines after the picture
TOP_LINES      = 48     ; red band: 48 scanlines
MIDDLE_LINES   = 96     ; blue band: 96 scanlines — twice the top band
BOTTOM_LINES   = 48     ; green band: 48 scanlines
                        ;   TOP + MIDDLE + BOTTOM = 192 visible lines

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
    STA VSYNC               ; pulse on — the 3 VSYNC lines begin here
    STA WSYNC               ; VSYNC line 1 ends
    STA WSYNC               ; VSYNC line 2 ends
    STA WSYNC               ; VSYNC line 3 ends
    LDA #$00
    STA VSYNC               ; pulse off — VSYNC covered exactly 3 lines

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
; -----------------------------------------------------------------------------
; VBLANK — 37 blanked lines
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    LDX #VBLANK_LINES       ; 37 lines to wait out
VblankLines:
    STA WSYNC               ; wait out one blanked line
    DEX
    BNE VblankLines

VisibleStart:               ; debugger checkpoint: visible's first line (Stella: 37)
; -----------------------------------------------------------------------------
; VISIBLE — 192 lines = 48 / 96 / 48
; -----------------------------------------------------------------------------
; Three straight-line sections — no loop this time: with three unequal
; bands a loop would need a size table, and the sizes ARE the exercise.
; What stays true from the lesson: each band's color is written in HBLANK,
; and band 0 counts the release line inside its 48.
    LDA #$00
    STA VBLANK              ; release the beam — this line is visible line 1
    LDA BandColors          ; top band: red
    STA COLUBK              ; lands in HBLANK: the release line shows it
    LDY #TOP_LINES-1        ; Y = 47: release line + 47 painted = 48
    JSR PaintLines
    LDA BandColors+1        ; middle band: blue
MiddleBand:                 ; debugger checkpoint: band 0's last line (Stella: 84)
    LDY #MIDDLE_LINES       ; Y = 96: twice as tall as the top band
    JSR PaintLines
    LDA BandColors+2        ; bottom band: green
BottomBand:                 ; debugger checkpoint: band 1's last line (Stella: 180)
    LDY #BOTTOM_LINES       ; Y = 48
    JSR PaintLines

    STA WSYNC               ; let the last band line finish before blanking
    LDA #$02
OverscanStart:              ; debugger checkpoint: overscan's first line (Stella: 229)
    STA VBLANK              ; blank the screen for overscan
    LDX #OVERSCAN_LINES     ; 30 lines to wait out
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
;                to COLUBK once per line for Y lines.  Y = 96 is just as
;                valid as Y = 48: the loop counts whatever it is given.
; Registers:     A survives; X is never touched; Y is used up.
; Stack:         JSR pushed the return address; the RTS pops it.
; =============================================================================
PaintLines:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEY                     ; one line fewer to go
    BNE -
    RTS

; =============================================================================
; DATA — one color per band, read as BandColors, +1, +2
; =============================================================================
BandColors:
    !byte $42               ; top band    — red
    !byte $84               ; middle band — blue
    !byte $C8               ; bottom band — green

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
