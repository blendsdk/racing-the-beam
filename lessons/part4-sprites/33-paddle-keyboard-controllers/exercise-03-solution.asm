; =============================================================================
; LESSON 33 — EXERCISE 3 SOLUTION: Two Needles (Stretch Goal)
; =============================================================================
; Part 4: Sprites
;
; Exercise: paddle 0 positions P0, paddle 1 positions P1.
;
; The technique: read one paddle per frame, alternating (even frames INPT0,
; odd frames INPT1), because each bounded read takes about 24 lines of the
; 37-line VBLANK.  The stored values persist, so each needle updates at
; 30 Hz.  Both are 32-row bars; one HMOVE applies both fine offsets.
;
; With no paddles, both reads time out to 0 and the needles overlap at
; X=24; P0 (red) wins the overlap.
;
; Build: acme -f plain -o build/lesson33-ex3.bin \
;        lessons/part4-sprites/33-paddle-keyboard-controllers/exercise-03-solution.asm
; Run:   stella build/lesson33-ex3.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
SPRITE_TOP     = 80
NEEDLE_HEIGHT  = 32
POS_BIAS       = 3
PADDLE_MAX     = 128

FrameCounter   = $80
Paddle0        = $81
Paddle1        = $82
Needle0        = $83
Needle1        = $84

    * = $F000

Reset:
    +clean_start

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    INC FrameCounter
    LDA FrameCounter
    AND #$01
    BNE ReadPaddle1

; --- read paddle 0 ---
    LDA #$82
    STA VBLANK
    LDX #50
Dis0:
    DEX
    BNE Dis0
    LDA #$42
    STA VBLANK
    LDY #0
Wait0:
    LDA INPT0
    BMI Ready0
    INY
    CPY #PADDLE_MAX
    BNE Wait0
    LDY #0
Ready0:
    STY Paddle0
    JMP Position

; --- read paddle 1 ---
ReadPaddle1:
    LDA #$82
    STA VBLANK
    LDX #50
Dis1:
    DEX
    BNE Dis1
    LDA #$42
    STA VBLANK
    LDY #0
Wait1:
    LDA INPT1
    BMI Ready1
    INY
    CPY #PADDLE_MAX
    BNE Wait1
    LDY #0
Ready1:
    STY Paddle1

Position:
    LDA Paddle0
    CLC
    ADC #24
    STA Needle0
    LDA Paddle1
    CLC
    ADC #24
    STA Needle1

    LDA Needle0
    CLC
    ADC #POS_BIAS
    JSR SetCoarse0
    LDA Needle1
    CLC
    ADC #POS_BIAS
    JSR SetCoarse1
    STA WSYNC
    STA HMOVE

    LDA #$C8
    STA COLUPF
    LDA #$02
    STA COLUBK
    LDA #$42
    STA COLUP0
    LDA #$84
    STA COLUP1
    LDA #$01
    STA CTRLPF
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    STA REFP0
    STA REFP1

    +wait_timer

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
    LDA #$FF
    STA GRP0
    STA GRP1
    STA WSYNC
    INX
    CPX #NEEDLE_HEIGHT
    BNE BodyLoop

    LDA #$00
    STA GRP0
    STA GRP1
    STA WSYNC

    LDX #(VISIBLE_LINES - SPRITE_TOP - NEEDLE_HEIGHT - 1)
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
    STA RESP1
    RTS

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
