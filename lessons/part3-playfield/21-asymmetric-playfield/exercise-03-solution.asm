; =============================================================================
; LESSON 21 — EXERCISE 3 SOLUTION: Two Asymmetric Bands (Stretch Goal)
; =============================================================================
; Part 3: Playfield
;
; Exercise: a scene with two horizontal bands, each with its own left/right
; pair — the top band uses the lesson ROM's pattern, the bottom band a
; different one.
;
; The technique: the per-line body is duplicated with different constants.
; Two 96-line loops cover the 192 visible lines. The top band's first line
; starts its body at cycle 7 (release 5 + LDX 2); the bottom band's first
; line starts at cycle 6 (the exit BNE is not taken, then LDX 2); every
; later line starts at 5. Every write still lands before its display slot.
;
;   top band (lines 37-132):
;     left  $F0/$FF/$3F   right $00/$AA/$55   (the lesson ROM's split gate)
;   bottom band (lines 133-228):
;     left  $F0/$CC/$3F   right $F0/$CC/$3C   (slotted left, its own stripe pair)
;
; Debugger checkpoints: VisibleStart (37), TopLeft2 (hit 20, A = $3F),
; TopRight0 (hit 35, A = $00), BottomLeft2 (hit 20, A = $3F),
; BottomRight0 (hit 35, A = $F0), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson21-ex3.bin \
;        lessons/part3-playfield/21-asymmetric-playfield/exercise-03-solution.asm
; Run:   stella build/lesson21-ex3.bin
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
    LDA #$00
    STA CTRLPF              ; repeat mode for both bands
    LDA #$C8
    STA COLUPF
    LDA #$02
    STA COLUBK

    +wait_timer

    LDA #$00
    STA VBLANK              ; release on line 37
VisibleStart:               ; checkpoint: the picture's first line (37)
    LDX #HALF_LINES

; =============================================================================
; TOP BAND — lines 37-132
; =============================================================================
TopBody:
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    LDA #$3F
    STA PF2
TopLeft2:                   ; checkpoint: hit 20, A = $3F
    NOP
    NOP
    NOP
    NOP
    NOP
    LDA #$00
    STA PF0
TopRight0:                  ; checkpoint: hit 35, A = $00
    NOP
    NOP
    NOP
    LDA #$AA
    STA PF1
    NOP
    NOP
    NOP
    LDA #$55
    STA PF2
    STA WSYNC
    DEX
    BNE TopBody

; =============================================================================
; BOTTOM BAND — lines 133-228
; =============================================================================
    LDX #HALF_LINES         ; CPU is at line 133; the body starts at cycle 6
BottomBody:
    LDA #$F0
    STA PF0
    LDA #$CC
    STA PF1
    LDA #$3F
    STA PF2
BottomLeft2:                ; checkpoint: hit 20, A = $3F
    NOP
    NOP
    NOP
    NOP
    NOP
    LDA #$F0                ; the bottom right half starts solid
    STA PF0
BottomRight0:               ; checkpoint: hit 35, A = $F0
    NOP
    NOP
    NOP
    LDA #$CC
    STA PF1
    NOP
    NOP
    NOP
    LDA #$3C
    STA PF2
    STA WSYNC
    DEX
    BNE BottomBody

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
