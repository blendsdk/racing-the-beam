; =============================================================================
; LESSON 31: Copies and Sizes — NUSIZ Register — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   Shows all eight player copy/size modes with one static picture.  The
;   192 visible lines are split into eight 24-line bands; band k writes
;   NUSIZ0 = k and draws the same two-pixel pattern.  One capture shows
;   one copy, two copies at three spacings, three copies at two spacings,
;   double width, and quad width.
;
; NUSIZ bits 0-2:
;   0  one copy, normal
;   1  two copies, close (16 clocks apart)
;   2  two copies, medium (32)
;   3  three copies, close
;   4  two copies, wide (64)
;   5  one copy, double width
;   6  three copies, medium
;   7  one copy, quad width
;
;   Bits 4-5 set the missile width; the missile is disabled here, so they
;   stay 0.
;
; The per-line kernel:
;   LDA BandNUSIZ,X   4   (the band's mode)
;   STA NUSIZ0        3
;   LDA #PATTERN      2
;   STA GRP0          3
;   STA WSYNC         3
;   INX / CPX / BNE   7
;   ---------------------------------
;   total            22 of 76 cycles (23 from X=132, where the table read
;                    crosses into $F1xx; WSYNC absorbs the extra cycle)
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
; The player is at X=40; the pattern is `$18` (two adjacent pixels).
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), VisibleStart (37), BandWrite (A = the
;   band value, 192 hits; the A runs change at lines 37/61/85/109/133/157/181/
;   205), PatternWrite (A = $18, 192 hits), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson31.bin \
;        lessons/part4-sprites/31-copies-and-sizes/31-copies-and-sizes.asm
; Run:   stella build/lesson31.bin
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
PATTERN        = $18
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
