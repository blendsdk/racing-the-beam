; =============================================================================
; LESSON 31 — EXERCISE 1 SOLUTION: A Solid Pattern
; =============================================================================
; Part 4: Sprites
;
; Exercise: change the pattern from $18 (two pixels) to $FF (all eight).
;
; The technique: one constant.  The copy modes now show contiguous 8-pixel
; blocks with 8-pixel gaps at the close spacing, 24-pixel gaps at medium,
; and 56-pixel gaps at wide (TIA pixels; 48/144/336 capture px).  The double and quad modes become 16- and
; 32-pixel-wide blocks.
;
; Build: acme -f plain -o build/lesson31-ex1.bin \
;        lessons/part4-sprites/31-copies-and-sizes/exercise-01-solution.asm
; Run:   stella build/lesson31-ex1.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
SPRITE_X       = 40
PATTERN        = $FF
POS_BIAS       = 3

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    LDA #(SPRITE_X + POS_BIAS)
    JSR SetHorizPos
    LDA #$42
    STA COLUP0              ; red
    LDA #$02
    STA COLUBK              ; dark neutral
    LDA #$00
    STA REFP0

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — 192 lines; NUSIZ0 changes every 24 lines
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK
    LDX #0
VisibleStart:
LineLoop:
    LDA BandNUSIZ,X
BandWrite:                  ; checkpoint: A = the band value
    STA NUSIZ0
    LDA #PATTERN
PatternWrite:               ; checkpoint: A = the pattern
    STA GRP0
    STA WSYNC
    INX
    CPX #VISIBLE_LINES
    BNE LineLoop

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SET HORIZONTAL POSITION — the Lesson 26 routine
; =============================================================================
SetHorizPos:
    STA WSYNC
    SEC
Div15:
    SBC #15
    BCS Div15
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    STA WSYNC
    STA HMOVE
    RTS

; =============================================================================
; NUSIZ TABLE — 24 lines of each mode 0-7
; =============================================================================
BandNUSIZ:
    !fill 24, 0
    !fill 24, 1
    !fill 24, 2
    !fill 24, 3
    !fill 24, 4
    !fill 24, 5
    !fill 24, 6
    !fill 24, 7

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
