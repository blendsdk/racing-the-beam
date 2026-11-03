; =============================================================================
; LESSON 21 — EXERCISE 2 SOLUTION: Mirror the Right Half
; =============================================================================
; Part 3: Playfield
;
; Exercise: make the right half a mirror of the left by using reflect mode
; instead of mid-line rewrites.
;
; The technique: when CTRLPF bit 0 (REF) is set, the TIA draws the right
; half by reading the 20 bits in reverse.  There is nothing to rewrite, so
; the visible kernel becomes the simple hold used in Lessons 19-20:
; write the registers once per frame, then park 192 lines.
;
; Pattern: PF0 = $F0, PF1 = $FF, PF2 = $3F.  PF2's bits 6-7 are clear, so
; chunks 18-19 are off; reflect mirrors them into 20-21.  The wall is
; symmetric with a four-chunk central gap (x = 457-552, transitions at 457
; and 553) — the Lesson 20 wall without the score split.
;
; Debugger checkpoints: CtrlWrite (A = $01), VisibleStart (37).
;
; Build: acme -f plain -o build/lesson21-ex2.bin \
;        lessons/part3-playfield/21-asymmetric-playfield/exercise-02-solution.asm
; Run:   stella build/lesson21-ex2.bin
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

    LDA #$01
    STA CTRLPF              ; REF = 1: mirror the right half
CtrlWrite:                  ; checkpoint: A = $01
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    LDA #$3F
    STA PF2
    LDA #$C8
    STA COLUPF
    LDA #$02
    STA COLUBK

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
