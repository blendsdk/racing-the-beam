; =============================================================================
; LESSON 29 — EXERCISE 2 SOLUTION: A Thin Ball
; =============================================================================
; Part 4: Sprites
;
; Exercise: shrink the ball to 1 pixel and move it between the missiles.
;
; The technique: CTRLPF bits 4-5 set the ball width; $00 = 1 pixel.
; The ball target becomes 68, which measures X=79 — between missile 0
; (X=63) and missile 1 (X=95).  The width and the position are independent.
;
; Build: acme -f plain -o build/lesson29-ex2.bin \
;        lessons/part4-sprites/29-missiles-and-ball/exercise-02-solution.asm
; Run:   stella build/lesson29-ex2.bin
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
SPRITE_TOP     = 96
SPRITE_HEIGHT  = 8
P0_X           = 24
M0_X           = 64
M1_X           = 96
BL_X           = 68     ; measured landing: X=79
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

; --- position all four objects, then apply all four fine offsets once ---
    LDA #(P0_X + POS_BIAS)
PosApplyP0:
    JSR SetCoarseP0
    LDA #(M0_X + POS_BIAS)
PosApplyM0:
    JSR SetCoarseM0
    LDA #(M1_X + POS_BIAS)
PosApplyM1:
    JSR SetCoarseM1
    LDA #(BL_X + POS_BIAS)
PosApplyBL:
    JSR SetCoarseBL
    STA WSYNC
HmoveApply:
    STA HMOVE

    LDA #$42
    STA COLUP0              ; red: player 0 and missile 0
    LDA #$84
    STA COLUP1              ; blue: missile 1
    LDA #$C8
    STA COLUPF              ; green: the ball
    LDA #$02
    STA COLUBK
    LDA #$00
    STA NUSIZ0              ; P0 normal, M0 1 px
    LDA #$20
    STA NUSIZ1              ; M1 4 px
    LDA #$00
    STA CTRLPF              ; ball 1 px
    LDA #$00
    STA REFP0
    STA REFP1
    STA ENAM0
    STA ENAM1
    STA ENABL               ; off until the body enables them

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — player 0's eight rows; the small objects on rows 2-5
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
    LDA ShapeP0,X
    STA GRP0
; --- enable the missiles and ball on rows 2-5 ---
    CPX #2
    BCC DisableSmall
    CPX #6
    BCS DisableSmall
    LDA #$02
    STA ENAM0
    STA ENAM1
    STA ENABL
    JMP EnableDone
DisableSmall:
    LDA #$00
    STA ENAM0
    STA ENAM1
    STA ENABL
EnableDone:
    STA WSYNC
    INX
    CPX #SPRITE_HEIGHT
    BNE BodyLoop

    LDA #$00
    STA GRP0
    STA ENAM0
    STA ENAM1
    STA ENABL
    STA WSYNC

    LDX #(VISIBLE_LINES - SPRITE_TOP - SPRITE_HEIGHT - 1)
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

; =============================================================================
; COARSE POSITIONING — one routine per object; no HMOVE here
; =============================================================================
; Input: A = the biased target (target + 3).
SetCoarseP0:
    STA WSYNC
    SEC
DivP0:
    SBC #15
    BCS DivP0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
RespP0:
    STA RESP0
    RTS

SetCoarseM0:
    STA WSYNC
    SEC
DivM0:
    SBC #15
    BCS DivM0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMM0
RespM0:
    STA RESM0
    RTS

SetCoarseM1:
    STA WSYNC
    SEC
DivM1:
    SBC #15
    BCS DivM1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMM1
RespM1:
    STA RESM1
    RTS

SetCoarseBL:
    STA WSYNC
    SEC
DivBL:
    SBC #15
    BCS DivBL
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMBL
RespBL:
    STA RESBL
    RTS

; =============================================================================
; SHAPE — player 0's eight rows
; =============================================================================
ShapeP0:
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %11011011
    !byte %11111111
    !byte %00100100
    !byte %01011010
    !byte %10100101

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
