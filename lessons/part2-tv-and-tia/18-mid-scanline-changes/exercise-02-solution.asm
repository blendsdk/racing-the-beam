; =============================================================================
; LESSON 18 — EXERCISE 2 SOLUTION: A Fifth Column
; =============================================================================
; Part 2: TV & TIA
;
; Exercise: add a fifth column.
;
; The technique: a fifth column needs one more boundary write — a fifth color
; written at its own cycle.  This solution inserts a bright white stripe
; ($0E) between the blue ($84) and the green ($C8) columns: the boundary-2
; write now loads $0E at hit cycle 41 (a zero-cycle gap after $84's write),
; and a new fourth write paints $C8 at hit cycle 48.  The last write ($1A)
; lands at hit cycle 62 so the anchor still fits the 76-cycle line.
;
; The per-line ledger (exactly 65 cycles of work; the anchor parks the rest):
;   DEX / BNE                5    0-4
;   LDA #C1 / BIT / STA      8    5-12   base $42:     hit 13 -> clock 39 (HBLANK)
;   NOP x 9                 18   13-30
;   LDA #C2 / STA            5   31-35   boundary 1 $84: hit 36 -> clock 108
;   (no gap)                 0
;   LDA #C3 / STA            5   36-40   boundary 2 $0E: hit 41 -> clock 123  (new)
;   NOP x 1                  2   41-42
;   LDA #C4 / STA            5   43-47   boundary 3 $C8: hit 48 -> clock 144  (was 147)
;   NOP x 3 + BIT            9   48-56
;   LDA #C5 / STA            5   57-61   boundary 4 $1A: hit 62 -> clock 186  (was 189)
;   STA WSYNC                3   62-64   anchor: write 64, park 65-75
;   ----------------------------------------------------------------
;   total                   65
;
; Expected picture: five columns — $42 / $84 / $0E / $C8 / $1A — with
; widths 40 / 15 / 21 / 42 / 42 clocks (240 / 90 / 126 / 252 / 252 capture
; pixels): the blue column narrows to a stripe, the white one sits beside it.
;
; Debugger checkpoints: BaseTick (13), B1Tick (36), B2Tick (41), B3Tick (48),
;   B4Tick (62), all 192 hits per frame; A = the color just written.
;
; Build: acme -f plain -o build/lesson18-ex2.bin \
;        lessons/part2-tv-and-tia/18-mid-scanline-changes/exercise-02-solution.asm
; Run:   stella build/lesson18-ex2.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — five colors, left to right
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines (Lesson 15)
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines (Lesson 15)

C1             = $42    ; leftmost column
C2             = $84
C3             = $0E    ; the NEW fifth color — a bright white stripe
C4             = $C8
C5             = $1A    ; rightmost column

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
    LDA #C1                 ; 5-6    base $42
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
    LDA #C2                 ; 31-32
    STA COLUBK              ; 33-35
B1Tick:                     ; checkpoint: hit cycle 36 — boundary 1 $84
    LDA #C3                 ; 36-37  (no gap: the stripe follows immediately)
    STA COLUBK              ; 38-40
B2Tick:                     ; checkpoint: hit cycle 41 — boundary 2 $0E (new)
    NOP                     ; 2
    LDA #C4                 ; 43-44
    STA COLUBK              ; 45-47
B3Tick:                     ; checkpoint: hit cycle 48 — boundary 3 $C8
    NOP
    NOP
    NOP                     ; 6
    BIT Scratch             ; 3      (9 cycles)
    LDA #C5                 ; 57-58
    STA COLUBK              ; 59-61
B4Tick:                     ; checkpoint: hit cycle 62 — boundary 4 $1A
    STA WSYNC               ; 62-64  anchor: write 64, park 65-75
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
