; =============================================================================
; LESSON 10 — EXERCISE 2 SOLUTION: Point the Table Around
; =============================================================================
;
; Challenge: walk a zero-page pointer with (zp),Y and switch between two
; tables so the screen alternates.  One pointer, two 12-byte ROM tables:
; the ascending ramp and the same ramp read backwards.  Every couple of
; seconds the pointer is repointed and the whole picture flips.
;
; Why this works:
;   - LDA (Ptr),Y names a ZERO-PAGE PAIR ($80/$81), not an address.  The CPU
;     reads a 16-bit address out of those two bytes and adds Y to it.  The
;     table's location is therefore decided at RUN TIME — that is what makes
;     the flip possible: four STA instructions change which table every band
;     reads from, without touching the kernel at all.
;   - PaintBand's contract keeps Y, so the band loop indexes the pointer's
;     target with no save and restore.
;   - Both tables are page-aligned together, so Y = 0...11 never crosses a
;     page and each load costs exactly 5 cycles.
;
; The switch itself uses the lesson 09 flip: EOR #$01 turns 0 into 1 and 1
; into 0, and the resulting zero flag picks the branch.
;
; Frame geometry: 192 non-blanked scanlines — 12 equal bands of 16 lines,
; with the beam-release line counted as band 0's first line.  The blank-on
; after the last band waits for HBLANK first, so the last band line is whole.
;
; Expected screen: the ascending ramp ($1A at the top ... $88 at the bottom)
; for two seconds, then the descending ramp ($88 ... $1A) for two seconds,
; alternating forever.  In the debugger, $80/$81 hold the address of the
; table being displayed: TableUp for one phase, TableDown for the other.
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- RAM variables ---
Ptr         = $80       ; $80/$81: the (zp),Y pointer — TableUp or TableDown
ToggleTimer = $82       ; frames left before the pointer switches tables
WhichTable  = $83       ; 0 = ascending table, 1 = descending table

; --- Program constants ---
BANDS        = 12       ; bands on the screen
LINES        = 16       ; scanlines per band (12 x 16 = 192 visible lines)
TOGGLE_FRAMES = 120     ; frames between switches (~2 seconds at 60 Hz)

    * = $F000

Reset:
    +clean_start

    ; --- Start on the ascending table ---
    LDA #<TableUp           ; low byte of the table's ROM address ...
    STA Ptr
    LDA #>TableUp           ; ... and high byte.  $80/$81 = the table
    STA Ptr+1
    LDA #$00
    STA WhichTable          ; 0 = ascending
    LDA #TOGGLE_FRAMES
    STA ToggleTimer         ; two seconds until the first flip

; =============================================================================
; MAIN LOOP — one pass = one frame
; =============================================================================
StartFrame:
    +vsync

    LDA #$02
    STA VBLANK
    +set_timer 43

    +wait_timer

    LDA #$00
    STA VBLANK              ; release the beam: this line is band 0's first
    LDY #$00                ; Y = 0: the pointer's target byte for band 0
    LDA (Ptr),Y             ; band 0's color through the pointer
Band0Fetch:                 ; debugger checkpoint: break here, A = table[0]
    STA COLUBK              ; written in HBLANK, so the release line shows it

; -----------------------------------------------------------------------------
; KERNEL — twelve bands through the pointer
; -----------------------------------------------------------------------------
    LDX #LINES-1            ; X = 15: release line + 15 painted = band 0
    JSR PaintBand

    LDY #$01                ; Y = 1: the next byte of the pointed-at table
BandLoop:
    LDA (Ptr),Y             ; INDIRECT INDEXED: pointer's target + Y
BandFetch:                  ; debugger checkpoint: break here, A = table[Y]
    LDX #LINES
    JSR PaintBand           ; paint it — A and Y survive, X is used up
    INY
    CPY #BANDS              ; 0 ... 11 — stopped at the table's edge
    BNE BandLoop

; -----------------------------------------------------------------------------
; OVERSCAN
; -----------------------------------------------------------------------------
    STA WSYNC               ; wait for HBLANK before blanking
    LDA #$02
    STA VBLANK
    +set_timer 35
    +wait_timer

; -----------------------------------------------------------------------------
; GAME LOGIC — repoint the pointer every TOGGLE_FRAMES frames
; -----------------------------------------------------------------------------
    DEC ToggleTimer         ; one frame closer to the switch
    BNE NoToggle            ; not 0 yet -> keep the same table
    LDA #TOGGLE_FRAMES      ; countdown reached 0 -> reload it ...
    STA ToggleTimer

    LDA WhichTable          ; ... and flip which table we are on
    EOR #$01                ; 0 -> 1, 1 -> 0 (EOR sets Z from the result)
    STA WhichTable
    BNE UseDown             ; A = 1 -> the descending table

    ; A = 0 -> the ascending table
    LDA #<TableUp
    STA Ptr
    LDA #>TableUp
    STA Ptr+1
    JMP NoToggle

UseDown:
    LDA #<TableDown
    STA Ptr
    LDA #>TableDown
    STA Ptr+1

NoToggle:
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
; DATA — the two tables, read through the pointer at $80/$81
; =============================================================================
; Both tables start inside one page so Y = 0...11 cannot cross a page:
; LDA (zp),Y stays at exactly 5 cycles for every entry.
    !align 255, 0, 0
TableUp:                        ; ascending: $1A + $0A per entry
    !byte $1A, $24, $2E, $38, $42, $4C
    !byte $56, $60, $6A, $74, $7E, $88
TableDown:                      ; the same twelve bytes, reversed
    !byte $88, $7E, $74, $6A, $60, $56
    !byte $4C, $42, $38, $2E, $24, $1A

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
