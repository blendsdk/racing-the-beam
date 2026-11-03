; =============================================================================
; LESSON 21 — EXERCISE 1 SOLUTION: Move the Gate
; =============================================================================
; Part 3: Playfield
;
; Exercise: move the doorway and start the right half solid.
;
; The technique: LEFT2 and RIGHT0 are the two bytes beside the centre.
;   LEFT2  = $0F  bits 4-7 clear -> chunks 16-19 off (a 4-chunk doorway)
;   RIGHT0 = $F0  chunks 20-23 on  (the right half starts solid)
;
; Remember PF2's bit order: bit 0 is leftmost, so $0F (00001111) displays
; as 11110000 — chunks 12-15 on, 16-19 off.  The doorway moves left and
; widens from two chunks to four; the right half's first four chunks are
; now on, so the dark gap is x = 409-505; the solid right half runs to
; x = 625, where the alternating stripes begin.
;
; The per-line cycle ledger is unchanged: left writes at hit 10/15/20,
; right writes at 35/46/57, anchor at 59.
;
; Debugger checkpoints: Left2 (hit 20, A = $0F), Right0 (hit 35, A = $F0),
; VisibleStart (37).
;
; Build: acme -f plain -o build/lesson21-ex1.bin \
;        lessons/part3-playfield/21-asymmetric-playfield/exercise-01-solution.asm
; Run:   stella build/lesson21-ex1.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192

    * = $F000

Reset:
    +clean_start

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    LDA #$00
    STA CTRLPF              ; repeat
    LDA #$C8
    STA COLUPF
    LDA #$02
    STA COLUBK

    LDX #VISIBLE_LINES
    +wait_timer

    LDA #$00
    STA VBLANK
VisibleStart:
    LDA #$F0
    STA PF0
Left0:
    LDA #$FF
    STA PF1
Left1:
    LDA #$0F                ; chunks 16-19 off
    STA PF2
Left2:                      ; checkpoint: hit 20, A = $0F
    NOP
    NOP
    NOP
    NOP
    NOP
    LDA #$F0                ; the right half starts solid
    STA PF0
Right0:                     ; checkpoint: hit 35, A = $F0
    NOP
    NOP
    NOP
    LDA #$AA
    STA PF1
Right1:
    NOP
    NOP
    NOP
    LDA #$55
    STA PF2
Right2:
    STA WSYNC
    DEX
    BNE VisibleStart

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
