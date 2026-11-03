; =============================================================================
; LESSON 20 — EXERCISE 2 SOLUTION: A Three-Color Wall
; =============================================================================
; Part 3: Playfield
;
; Exercise: keep score mode but open gaps in the pattern so the background
; becomes a third color.
;
; The technique: a playfield bit that is 0 shows COLUBK.  PF1 = $CC clears
; chunks 6-7 and 10-11 (and, in reflect, their mirrors 28-29 and 32-33).
; With COLUBK = $1A (gold), those gaps are gold; the left half is red and
; the right half blue.  The central PF2 gap (chunks 18-21) is gold too.
;
; There is no animation here: score mode stays on, so the three colors are
; stable and easy to check.
;
;   COLUP0 = $42 red      left half
;   COLUP1 = $84 blue     right half
;   COLUBK = $1A gold     the gaps
;   CTRLPF = $03          REF + SCORE
;
; Debugger checkpoints: CtrlWrite (A = $03), VisibleStart (37).
;
; Build: acme -f plain -o build/lesson20-ex2.bin \
;        lessons/part3-playfield/20-playfield-colors/exercise-02-solution.asm
; Run:   stella build/lesson20-ex2.bin
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

; --- score mode, always on ---
    LDA #$03
    STA CTRLPF
CtrlWrite:                  ; checkpoint: A = $03

; --- the pattern: two vertical slots in PF1, plus the central gap ---
    LDA #$F0
    STA PF0
    LDA #$CC
    STA PF1                 ; chunks 4-5 on, 6-7 off, 8-9 on, 10-11 off
    LDA #$3F
    STA PF2                 ; chunks 12-17 on, 18-19 off
    LDA #$C8
    STA COLUPF              ; unused in score mode, set for completeness
    LDA #$42
    STA COLUP0              ; left half red
    LDA #$84
    STA COLUP1              ; right half blue
    LDA #$1A
    STA COLUBK              ; gold shows through every 0 bit

    +wait_timer

    LDA #$00
    STA VBLANK
    LDX #VISIBLE_LINES
VisibleStart:
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
