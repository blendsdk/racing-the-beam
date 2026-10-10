; =============================================================================
; LESSON 10 — EXERCISE 1 SOLUTION: The Ramp, All the Way Down
; =============================================================================
;
; Challenge: in the lesson ROM the indexed ramp is only the BOTTOM half — six
; bands read from a six-byte table with LDA Ramp,Y.  Extend it: make the
; WHOLE picture a twelve-band ramp, fetched with one LDA Ramp,Y loop and a
; twelve-byte table.
;
; Why this works:
;   - LDA Ramp,Y is absolute,Y: Y is added to the table's 16-bit address, so
;     ONE instruction reads any of the twelve entries.  Y is the index.
;   - PaintBand's register contract (Lesson 08) says Y is never touched, so
;     the loop's index survives the call — no save and restore needed.
;   - The table is page-aligned, so Y = 0...11 cannot cross a page and every
;     load costs exactly 4 cycles (a page crossing would make it 5).
;
; The table continues the lesson ROM's ramp: each entry is $0A above the one
; before, so $42, $4C, $56, ... $B0.
;
; Frame geometry: 192 non-blanked scanlines — 12 equal bands of 16 lines.
; Band 0's color is fetched right after the beam is released, so the
; beam-release line is band 0's FIRST line and PaintBand paints the other 15;
; every other band is one PaintBand call of 16 lines.  The blank-on after the
; last band waits for HBLANK first, so the last band line is painted whole.
;
; Expected screen: twelve equal bands, a smooth ramp from $42 at the top to
; $B0 at the bottom — the same picture the lesson ROM's bottom half shows,
; continued to the top of the screen.
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- Program constants ---
BANDS       = 12        ; bands on the screen — one per table entry
LINES       = 16        ; scanlines per band (12 x 16 = 192 visible lines)

    * = $F000

Reset:
    +clean_start

; =============================================================================
; MAIN LOOP — one pass = one frame; the ramp is static
; =============================================================================
StartFrame:
    +vsync

    LDA #$02
    STA VBLANK              ; blank the beam while we set up
    +set_timer 43

    +wait_timer             ; finish the ~37 scanlines of VBLANK

    LDA #$00
    STA VBLANK              ; release the beam: this line is band 0's first
    LDY #$00                ; Y = 0: the table index for the top band
    LDA Ramp,Y              ; band 0's color through the table
Band0Fetch:                 ; debugger checkpoint: break here, A = $42, Y = $00
    STA COLUBK              ; written in HBLANK, so the release line shows it

; -----------------------------------------------------------------------------
; KERNEL — twelve bands, each one LDA Ramp,Y away
; -----------------------------------------------------------------------------
    LDX #LINES-1            ; X = 15: release line + 15 painted = band 0
    JSR PaintBand

    LDY #$01                ; Y = 1: the second entry is next
BandLoop:
    LDA Ramp,Y              ; ABSOLUTE,Y: one instruction, twelve colors
BandFetch:                  ; debugger checkpoint: break here, A = Ramp[Y]
    LDX #LINES
    JSR PaintBand           ; paint it — A and Y survive, X is used up
    INY                     ; next table entry
    CPY #BANDS              ; 0 ... 11 — stopped at the table's edge
    BNE BandLoop

; -----------------------------------------------------------------------------
; OVERSCAN
; -----------------------------------------------------------------------------
    STA WSYNC               ; wait for HBLANK before blanking: the last band
                            ; line is being drawn right now, so writing VBLANK
                            ; here would clip it partway across
    LDA #$02
    STA VBLANK
    +set_timer 35
    +wait_timer

    JMP StartFrame

; =============================================================================
; PaintBand — paint X scanlines of the color in A (from the lesson ROM)
; Registers: A survives, Y is never touched, X is used up as the counter.
; =============================================================================
PaintBand:
-   STA WSYNC
    STA COLUBK
    DEX
    BNE -
    RTS

; =============================================================================
; DATA — twelve ramp colors, read as Ramp,Y
; =============================================================================
; Page-aligned so the index cannot cross a page: LDA abs,Y costs exactly
; 4 cycles for every entry here.
    !align 255, 0, 0
Ramp:
    !byte $42, $4C, $56, $60    ; bands 0-3  ($42 + $0A per entry)
    !byte $6A, $74, $7E, $88    ; bands 4-7
    !byte $92, $9C, $A6, $B0    ; bands 8-11

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
