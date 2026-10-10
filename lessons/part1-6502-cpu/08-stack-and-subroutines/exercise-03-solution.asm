; =============================================================================
; LESSON 08 — EXERCISE 3 SOLUTION: A Three-Level Chain (Stretch Goal)
; =============================================================================
;
; Challenge: build a call chain three levels deep and show — in the debugger —
; that SP drops exactly 2 bytes per level, reaches $F9 at the deepest point,
; and is back at $FF before the next frame starts.
;
; The chain:
;
;   frame loop  --JSR-->  DrawScreen  --JSR-->  PaintBandRow  --JSR-->  PaintBand
;     level 0              level 1               level 2                level 3
;      SP $FF               SP $FD                SP $FB                 SP $F9
;
; Each JSR pushes a 2-byte return address, so the depth math is pure
; subtraction: $FF - 2 - 2 - 2 = $F9.  (The lesson ROM stops at $FA because
; its stack also holds the pushed band counter; this version keeps its counter
; in Y instead, which no level of the chain touches, so the chain is exactly
; three JSRs deep.)
;
; Why bother with a middle level?  PaintBandRow's only job here is to supply
; the line count and delegate — a one-line wrapper.  Real kernels are built
; this way: a high-level routine decides WHAT to draw, a middle routine
; decides HOW BIG, and the deepest routine paints.  The stack remembers the
; way home at every level.
;
; The stack page $01 is the SAME physical 128 bytes as RAM $80-$FF, so the
; deepest level's return address is written at $01FA/$01FB — which is the RAM
; bytes at $FA/$FB — and SP reaches $F9.  Keep variables below $F9.
;
; Expected screen: the same four bands as the lesson ROM — red, green, blue,
; gold — painted through a three-deep chain; SP returns to $FF every frame.
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- Colors (NTSC) ---
RED         = $42       ; top band
GREEN       = $C8
BLUE        = $96
GOLD        = $1A       ; bottom band

; --- Geometry ---
BANDS       = 4         ; bands on the screen: 4 calls of 48 painted lines
LINES       = 48        ; scanlines per PaintBand call (top band + the release
                        ; line; 4 x 48 + 1 = 193 non-blanked scanlines)

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

    JSR DrawScreen          ; level 1          (SP: $FF -> $FD)

    STA WSYNC               ; move the blank-on into HBLANK: the unwind home
                            ; through the chain would otherwise clip partway
                            ; across the last band line

    LDA #$02
    STA VBLANK
    +set_timer 35
    +wait_timer

    JMP StartFrame          ; SP is $FF again: the chain unwound itself

; =============================================================================
; LEVEL 1: DrawScreen — walk the bands; the counter lives in Y
; =============================================================================
; Y is used nowhere else in the chain, so it survives every call without a
; push — the safe place to keep a live counter in a deep chain is a register
; nobody else touches.  X, by contrast, is passed DOWN the chain as the line
; count and is used up by the painter at the bottom.
; =============================================================================
DrawScreen:
    LDY #0                  ; Y = band index: 0 = top band, 3 = bottom band
BandLoop:
    LDA BandColors,Y        ; A = this band's color
    JSR PaintBandRow        ; level 2          (SP: $FD -> $FB)
    INY
    CPY #BANDS
    BNE BandLoop
    RTS                     ; back to the frame loop (SP: $FD -> $FF)

; =============================================================================
; LEVEL 2: PaintBandRow — decide how big, then delegate to the artist
; =============================================================================
PaintBandRow:
    LDX #LINES              ; X = 48 scanlines for the band below
    JSR PaintBand           ; level 3          (SP: $FB -> $F9, the deepest)
    RTS                     ; (SP: $F9 -> $FB)

; =============================================================================
; LEVEL 3: PaintBand — the actual line-by-line painter
; =============================================================================
PaintBand:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEX                     ; one line fewer to go: 48, 47, ... 1
    BNE -                   ; loop until the scanline counter reaches 0
    RTS                     ; back up to level 2 (SP: $F9 -> $FB)

; =============================================================================
; DATA
; =============================================================================
BandColors:
    !byte RED, GREEN, BLUE, GOLD        ; band 0 = top ... band 3 = bottom

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
