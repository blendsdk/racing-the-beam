; =============================================================================
; LESSON 10 — EXERCISE 3 SOLUTION: The Wrap Trap, Rebuilt Safely *(Stretch)*
; =============================================================================
;
; Challenge: provoke the zero-page wrap and then rebuild the lookup safely.
;
; THE TRAP.  Suppose you want "the byte 128 past $80" and write:
;
;     LDX #$80
;     LDA $80,X       ; you think: $80 + $80 = $100
;
; Two things are wrong.  First, $100 is not RAM: the 2600's only RAM is the
; 128 bytes at $80-$FF.  Second — and this is the wrap — zero page,X adds the
; index in EIGHT bits only: $80 + $80 = $100, and the CPU throws away the
; carry, so the effective address is $00.  Address $00 is a TIA address, not
; memory: reading it returns the CXM0P collision register.  The load does not
; fault or crash; A silently holds hardware state, and a band painted with it
; shows an arbitrary color.  That is the worst kind of bug: no error, wrong
; picture.
;
; (The same wrap exists for zero page,Y.  Absolute,X and absolute,Y do NOT
; wrap — they compute a real 16-bit address — and neither does the pointer
; mode below.)
;
; THE SAFE REBUILD.  Put the table's 16-bit address in a zero-page pointer
; and read through it:
;
;     LDA (Ptr),Y     ; the CPU reads Ptr's two bytes and adds Y
;
; The add is sixteen bits wide: Y is added to the low byte and the carry
; propagates into the high byte, so the access can leave page $00 without
; wrapping into a different device (crossing a page costs one extra cycle,
; 5 -> 6 — a timing cost, not a correctness one).  The pointer's target can
; be anywhere in the address space, which is why every table walk on the
; 2600 is written this way.
;
; The table is indexed with a bounded counter: Y runs 0...11 and the loop
; stops with CPY #BANDS.  A table walk is only as safe as its index — the
; wrap bug is really an index that was never range-checked.
;
; Frame geometry: 192 non-blanked scanlines — 12 equal bands of 16 lines,
; with the beam-release line counted as band 0's first line.  The blank-on
; after the last band waits for HBLANK first, so the last band line is whole.
;
; Expected screen: the twelve-band ramp, painted entirely through $80/$81 —
; the same picture Exercise 1 paints, but every byte arrives through a
; pointer instead of an absolute,Y index.  In the debugger, the pointer reads
; the ROM address of the Ramp table, and every band's A comes from it —
; nothing is ever read from a TIA address.
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- RAM variables ---
Ptr         = $80       ; $80/$81: the safe 16-bit pointer to the ROM table

; --- Program constants ---
BANDS       = 12        ; bands on the screen — one per table entry
LINES       = 16        ; scanlines per band (12 x 16 = 192 visible lines)

    * = $F000

Reset:
    +clean_start

    ; --- Point the safe pointer at the table ---
    LDA #<Ramp              ; A = the table address's low byte ...
PtrLow:                     ; debugger checkpoint: break here for the low byte
    STA Ptr
    LDA #>Ramp              ; ... and its high byte
PtrHigh:                    ; debugger checkpoint: break here for the high byte
    STA Ptr+1

; =============================================================================
; MAIN LOOP — one pass = one frame; the ramp is static
; =============================================================================
StartFrame:
    +vsync

    LDA #$02
    STA VBLANK
    +set_timer 43

    +wait_timer

    LDA #$00
    STA VBLANK              ; release the beam: this line is band 0's first
    LDY #$00                ; Y = 0: the first table entry
    LDA (Ptr),Y             ; SAFE: pointer's 16-bit target + Y, no wrapping
Band0Fetch:                 ; debugger checkpoint: break here, A = Ramp[0]
    STA COLUBK              ; written in HBLANK, so the release line shows it

; -----------------------------------------------------------------------------
; KERNEL — twelve bands, each fetched through the pointer
; -----------------------------------------------------------------------------
    LDX #LINES-1            ; X = 15: release line + 15 painted = band 0
    JSR PaintBand

    LDY #$01                ; Y = 1: the second entry is next
BandLoop:
    LDA (Ptr),Y             ; INDIRECT INDEXED: a true 16-bit address + Y
FetchSafe:                  ; debugger checkpoint: break here, A = Ramp[Y]
    LDX #LINES
    JSR PaintBand           ; paint it — A and Y survive, X is used up
    INY
    CPY #BANDS              ; bounded index: 0 ... 11 — never past the table
    BNE BandLoop

; -----------------------------------------------------------------------------
; OVERSCAN
; -----------------------------------------------------------------------------
    STA WSYNC               ; wait for HBLANK before blanking
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
; DATA — the ramp, read through the pointer at $80/$81
; =============================================================================
; The same twelve bytes Exercise 1 uses ($42 + $0A per entry), so the safe
; rebuild paints the identical picture.  Page-aligned so Y = 0...11 cannot
; cross a page: each LDA (zp),Y costs exactly 5 cycles here (a crossing
; would make it 6).
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
