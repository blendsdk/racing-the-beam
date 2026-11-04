; =============================================================================
; LESSON 32 — EXERCISE 1 SOLUTION: No Delay
; =============================================================================
; Part 4: Sprites
;
; Exercise: turn VDEL off and align the two players.
;
; The technique: store 0 to VDELP1 instead of 1.  Both graphics registers
; now reach the screen on the line they are written; the two striped blocks
; share the same top row.
;
; Build: acme -f plain -o build/lesson32-ex1.bin \
;        lessons/part4-sprites/32-vertical-delay/exercise-01-solution.asm
; Run:   stella build/lesson32-ex1.bin
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
SPRITE_TOP     = 88
SPRITE_HEIGHT  = 16
P0_X           = 48
P1_X           = 104
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

    LDA #(P0_X + POS_BIAS)
PosApply0:                  ; checkpoint: P0's biased target
    JSR SetCoarse0
    LDA #(P1_X + POS_BIAS)
PosApply1:                  ; checkpoint: P1's biased target
    JSR SetCoarse1
    STA WSYNC
HmoveApply:                 ; checkpoint: the single HMOVE
    STA HMOVE

    LDA #$42
    STA COLUP0
    LDA #$84
    STA COLUP1
    LDA #$02
    STA COLUBK
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    STA REFP0
    STA REFP1
    LDA #$00
VdelWrite:                  ; checkpoint: A = $00
    STA VDELP1              ; no delay: both players align

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — identical shapes; both players align
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK
    LDX #SPRITE_TOP
VisibleStart:
TopLoop:
    STA WSYNC
    DEX
    BNE TopLoop

    LDX #0
BodyStart:
BodyLoop:
    LDA Shape,X
    STA GRP0
    LDA Shape,X
    STA GRP1
    STA WSYNC
    INX
    CPX #SPRITE_HEIGHT
    BNE BodyLoop

    LDA #$00
    STA GRP0                ; clear (no delay active)
    STA GRP1                ; clear player 1
    STA WSYNC

    LDX #(VISIBLE_LINES - SPRITE_TOP - SPRITE_HEIGHT - 1)
BottomLoop:
    STA GRP0                ; keep the register cleared
    STA WSYNC
    DEX
    BNE BottomLoop

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; COARSE POSITIONING — two players, one HMOVE
; =============================================================================
SetCoarse0:
    STA WSYNC
    SEC
Div0:
    SBC #15
    BCS Div0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
Resp0Write:                 ; checkpoint: P0's coarse strobe
    STA RESP0
    RTS

SetCoarse1:
    STA WSYNC
    SEC
Div1:
    SBC #15
    BCS Div1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
Resp1Write:                 ; checkpoint: P1's coarse strobe
    STA RESP1
    RTS

; =============================================================================
; SHAPE — a 16-row striped block
; =============================================================================
Shape:
    !byte %11111111
    !byte %10000001
    !byte %10000001
    !byte %10000001
    !byte %11111111
    !byte %10000001
    !byte %10000001
    !byte %10000001
    !byte %11111111
    !byte %10000001
    !byte %10000001
    !byte %10000001
    !byte %11111111
    !byte %10000001
    !byte %10000001
    !byte %10000001

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
