; =============================================================================
; LESSON 18 — EXERCISE 1 SOLUTION: Move One Boundary
; =============================================================================
; Part 2: TV & TIA
;
; Exercise: move one column boundary by NOP-count changes — without moving
;           the other two.
;
; The technique: boundary 2's position is set by the NOP gap after boundary
; 1's write.  Add cycles there and boundary 2 moves later; but boundaries
; after it move too unless you take the same cycles back out of a later gap.
; This solution moves boundary 2 +4 cycles (hit 49 -> 53) by giving its gap
; two more NOPs (NOP x 4 -> NOP x 6), and removes 4 cycles from the next gap
; (NOP x 3 + BIT -> NOP x 1 + BIT) so boundary 3 stays exactly where it was.
;
; The per-line ledger (exactly 76 cycles, like the lesson ROM):
;   DEX / BNE                5    0-4
;   LDA #COL1 / BIT / STA    8    5-12   base:     hit 13 -> clock 39 (HBLANK)
;   NOP x 9                 18   13-30
;   LDA #COL2 / STA          5   31-35   boundary 1: hit 36 -> clock 108  (unchanged)
;   NOP x 6                 12   36-47   (four more cycles than the lesson ROM)
;   LDA #COL3 / STA          5   48-52   boundary 2: hit 53 -> clock 159  (MOVED)
;   NOP x 1 + BIT            5   53-57   (four fewer cycles than the lesson ROM)
;   LDA #COL4 / STA          5   58-62   boundary 3: hit 63 -> clock 189  (unchanged)
;   STA WSYNC                3   63-65   anchor: write 65, park 66-75
;   ----------------------------------------------------------------
;   total                   76
;
; Expected picture: the four columns, but boundary 2 sits 12 color clocks
; (72 capture pixels) to the right — widths 40 / 51 / 30 / 39 clocks
; (default was 40 / 39 / 42 / 39).  Boundary 1 and 3 have not moved.
;
; Debugger checkpoints: BaseTick (13), B1Tick (36), B2Tick (53, was 49),
;   B3Tick (63), all 192 hits per frame; A = the color just written.
;
; Build: acme -f plain -o build/lesson18-ex1.bin \
;        lessons/part2-tv-and-tia/18-mid-scanline-changes/exercise-01-solution.asm
; Run:   stella build/lesson18-ex1.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines (Lesson 15)
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines (Lesson 15)

COL1           = $42
COL2           = $84
COL3           = $C8
COL4           = $1A

VISIBLE_LINES  = 192

Scratch        = $80    ; unused RAM byte — the odd-gap tuner reads it

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

; =============================================================================
; MAIN LOOP  —  one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
    LDA #$02                ; bit 1 = start VSYNC
    STA VSYNC
    STA WSYNC               ; VSYNC line 1
    STA WSYNC               ; VSYNC line 2
    STA WSYNC               ; VSYNC line 3
    LDA #$00
    STA VSYNC               ; pulse off — exactly 3 lines

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
    LDA #$02
    STA VBLANK
    LDA #VBLANK_TIMER
    STA TIM64T              ; 44 ticks for 37 lines

VblankWait:
    LDA INTIM
VblankPoll:                 ; debugger checkpoint: A = the value just read
    BNE VblankWait
    LDX #VISIBLE_LINES      ; 192 lines to paint
    STA WSYNC               ; park the rest of line 36
    LDA #$00
    STA VBLANK              ; release the beam
VisibleStart:               ; debugger checkpoint: the picture's first line (Stella: 37)
VarBody:
    LDA #COL1               ; 5-6
    BIT Scratch             ; 7-9    the 3-cycle odd-gap tuner
    STA COLUBK              ; 10-12
BaseTick:                   ; checkpoint: hit cycle 13
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP                     ; 18 cycles
    LDA #COL2               ; 31-32
    STA COLUBK              ; 33-35
B1Tick:                     ; checkpoint: hit cycle 36 — boundary 1 (unmoved)
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP                     ; 12 cycles: four more than the lesson ROM
    LDA #COL3               ; 48-49
    STA COLUBK              ; 50-52
B2Tick:                     ; checkpoint: hit cycle 53 — boundary 2 (MOVED +4)
    NOP                     ; 2
    BIT Scratch             ; 3      five cycles: four fewer than the lesson ROM
    LDA #COL4               ; 58-59
    STA COLUBK              ; 60-62
B3Tick:                     ; checkpoint: hit cycle 63 — boundary 3 (unmoved)
    STA WSYNC               ; 63-65  anchor: write 65, park 66-75
VarNext:
    DEX
    BNE VarBody
    JMP OverscanStart       ; 192 lines done

OverscanStart:              ; debugger checkpoint: overscan's first line (Stella: 229)
    LDA #$02
    STA VBLANK
    LDA #OVERSCAN_TIMER
    STA TIM64T              ; 36 ticks for 30 lines

OverscanWait:
    LDA INTIM
OverscanPoll:               ; debugger checkpoint: A = the value just read
    BNE OverscanWait
    STA WSYNC
    JMP StartFrame

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
