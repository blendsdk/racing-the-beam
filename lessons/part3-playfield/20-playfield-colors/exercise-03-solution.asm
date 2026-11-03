; =============================================================================
; LESSON 20 — EXERCISE 3 SOLUTION: A Four-Quadrant Frame (Stretch Goal)
; =============================================================================
; Part 3: Playfield
;
; Exercise: top half in score mode (red|blue), bottom half in normal color
; (green), switched at the middle of the picture.
;
; The technique: CTRLPF can change at any line, not just once per frame.
; Split the visible kernel into two 96-line loops.  The first loop holds
; line 37-132 with CTRLPF = $03 (REF + SCORE); after its last WSYNC, the
; CPU is at line 133, and the CTRLPF = $01 write lands in that line's
; HBLANK.  The second loop holds lines 133-228 with the normal color.
;
; Colors: COLUPF = $C8 green, COLUP0 = $42 red, COLUP1 = $84 blue,
; COLUBK = $02.  The pattern is the lesson ROM's wall with the central gap.
;
; Expected picture:
;   lines 37-132   (top half)     red left, blue right, dark central gap
;   lines 133-228  (bottom half)  green wall, dark central gap
;
; Debugger checkpoints: VisibleStart (37), TopMode (A = $03, line 37),
; BottomMode (A = $01, line 133), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson20-ex3.bin \
;        lessons/part3-playfield/20-playfield-colors/exercise-03-solution.asm
; Run:   stella build/lesson20-ex3.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
HALF_LINES     = 96

    * = $F000

Reset:
    +clean_start

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the wall and all three colors, written once per frame ---
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    LDA #$3F
    STA PF2
    LDA #$C8
    STA COLUPF
    LDA #$42
    STA COLUP0
    LDA #$84
    STA COLUP1
    LDA #$02
    STA COLUBK

    +wait_timer

; --- visible: top half in score mode, bottom half in normal color ---
    LDA #$00
    STA VBLANK              ; release the beam on line 37
VisibleStart:               ; checkpoint: the picture's first line (37)
    LDX #HALF_LINES
    LDA #$03                ; REF + SCORE for the top half
    STA CTRLPF
TopMode:                    ; checkpoint: A = $03, line 37
TopLoop:
    STA WSYNC
    DEX
    BNE TopLoop

    LDX #HALF_LINES         ; CPU is at line 133 here
    LDA #$01                ; REF only: the normal green wall
    STA CTRLPF
BottomMode:                 ; checkpoint: A = $01, line 133
BottomLoop:
    STA WSYNC
    DEX
    BNE BottomLoop

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
