; =============================================================================
; LESSON 12 — EXERCISE 3 SOLUTION: The 192-Line Budget, Partitioned 16 x 12
; =============================================================================
; (Stretch Goal)
;
; Challenge: prove that the visible area is a budget — exactly 192 lines —
; by partitioning it completely differently: sixteen equal 12-line bands,
; one color each, read from a 16-byte table.
;
; Why this works:
;   - Band 0's color is written in HBLANK (the release line is its first
;     line), then PaintLines paints 11 more; bands 1...15 follow as 15
;     calls of 12 lines each.  Counted waits: 11 + 15 x 12 = 191, plus the
;     release line = 192.  Same window as the lesson ROM, different sum:
;     16 x 12 = 192.
;   - The table is read as Ladder,X with X = 0...15 — Lesson 11's idiom —
;     and the loop bound CPX #16 IS the table's size: an index that only
;     counts up needs no mask.
;   - The table is !align'd to 16 bytes so X can never push a read across a
;     page boundary; every fetch costs exactly 4 cycles.
;   - The frame around it is untouched: 3 + 37 + 192 + 30 = 262.
;
; Debugger: break at BandFetch and watch A and X: A walks the ladder's
; entries $1C ... $FC while X counts 1...15 ($0C, band 0's entry, is loaded
; once before the loop; the fifteenth fetch is the last band, and the next
; frame starts the walk over).
;
; Expected screen: sixteen equal 12-line bands — the 16 hues at one
; brightness, gray at the top through the color wheel to
; the bottom — filling exactly the same 192-line window as the lesson ROM.
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
BANDS          = 16     ; visible bands — one per table entry
LINES          = 12     ; scanlines per band (16 x 12 = 192 visible lines)

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
; VISIBLE — 192 lines = sixteen bands of 12
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam — this line is visible line 1
    LDX #$00                ; X = 0: index 0 is both the top band and entry 0
    LDA Ladder,X            ; band 0's color
    STA COLUBK              ; lands in HBLANK: the release line shows it
    LDY #LINES-1            ; Y = 11: release line + 11 painted = band 0's 12
    JSR PaintLines
    LDX #$01                ; bands 1...15 remain
BandLoop:
    LDA Ladder,X            ; entry X paints band X
BandFetch:                  ; debugger checkpoint: A = Ladder[X], X = index
    LDY #LINES              ; Y = 12: a full band
    JSR PaintLines          ; paint it — A survives, X is never touched
    INX                     ; next band, next entry
    CPX #BANDS              ; 0...15 — the loop bound IS the table's size
    BNE BandLoop

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
;                to COLUBK once per line for Y lines — the write lands in
;                HBLANK, so band boundaries fall exactly on a scanline.
; Registers:     A survives, X is never touched (the ladder index lives
;                there), Y is used up counting lines down to 0.
; Stack:         JSR pushed the return address; the RTS pops it.
; =============================================================================
PaintLines:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEY                     ; one line fewer to go
    BNE -
    RTS

; =============================================================================
; DATA — sixteen colors, read as Ladder,X
; =============================================================================
; Entry k is (k << 4) | $0C: the hue nibble runs 0...15 while the low
; nibble keeps the luminance field (bits 3-1) at 6 — the ladder is the
; color wheel at one brightness, easy to verify band by band.
; (!align's third field is the pad byte: 0 fills the gap with zeros.)
    !align 15, 0, 0
Ladder:
    !byte $0C, $1C, $2C, $3C    ; hues 0-3  (0 is the gray step)
    !byte $4C, $5C, $6C, $7C    ; hues 4-7
    !byte $8C, $9C, $AC, $BC    ; hues 8-11
    !byte $CC, $DC, $EC, $FC    ; hues 12-15

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
