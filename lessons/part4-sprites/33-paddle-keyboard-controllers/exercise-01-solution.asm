; =============================================================================
; LESSON 33 — EXERCISE 1 SOLUTION: Paddle 1
; =============================================================================
; Part 4: Sprites
;
; Exercise: read paddle 1 (INPT1) instead of paddle 0.
;
; The technique: one operand.  The discharge/charge/count loop is the same;
; only the input register changes.  The needle now follows paddle 1.  With no
; paddle on the port the read may time out (X=24); with a paddle at minimum
; resistance it returns a small count.  The capture environment presented
; paddle 1 at minimum, so the measured X is 28.
;
; Build: acme -f plain -o build/lesson33-ex1.bin \
;        lessons/part4-sprites/33-paddle-keyboard-controllers/exercise-01-solution.asm
; Run:   stella build/lesson33-ex1.bin
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
SPRITE_TOP     = 80
NEEDLE_HEIGHT  = 32
FIRE_HEIGHT    = 8
FIRE_X         = 140
POS_BIAS       = 3
PADDLE_MAX     = 128

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
PaddleValue    = $80    ; 0-127, the raw charge count (0 on timeout)
NeedleX        = $81    ; 24-151, the needle position

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

; --- paddle 1: discharge, charge, count until ready or 128 ---
    LDA #$82                ; bit 7 = discharge, bit 1 = blank
    STA VBLANK
    LDX #50
PadDischarge:
    DEX
    BNE PadDischarge
    LDA #$42                ; bit 6 = fire latch, bit 1 = blank; bit 7 cleared = charge
    STA VBLANK
    LDY #0
PadWait:
    LDA INPT1
    BMI PadReady            ; bit 7 = 1: the capacitor is charged
    INY
    CPY #PADDLE_MAX
    BNE PadWait
    LDY #0                  ; timeout: no paddle or resistance beyond the bound
PadReady:
    STY PaddleValue
    LDA PaddleValue
PaddleRead:                 ; checkpoint: A = the count, 0-127
    CLC
    ADC #24
PaddleX:                    ; checkpoint: A = the needle X
    STA NeedleX

; --- the raw-port columns: PF1 = the inverted SWCHA byte ---
    LDA SWCHA
    EOR #$FF
KeyWrite:                   ; checkpoint: A = the inverted SWCHA
    STA PF1

; --- the fire button: INPT4 bit 7 = 0 when pressed ---
    LDA INPT4
    AND #$80
    BNE FireOff
    LDA #$42                ; pressed: red
    BNE FireStore
FireOff:
    LDA #$C8                ; released: green
FireStore:
FireWrite:                  ; checkpoint: A = COLUP1
    STA COLUP1

; --- position the needle (P0) and the fire block (P1) ---
    LDA NeedleX
    CLC
    ADC #POS_BIAS
PosApply0:                  ; checkpoint: P0's biased target
    JSR SetCoarse0
    LDA #(FIRE_X + POS_BIAS)
PosApply1:                  ; checkpoint: P1's biased target
    JSR SetCoarse1
    STA WSYNC
HmoveApply:                 ; checkpoint: the single HMOVE
    STA HMOVE

    LDA #$C8
    STA COLUPF              ; green playfield columns
    LDA #$02
    STA COLUBK              ; dark neutral
    LDA #$42
    STA COLUP0              ; red needle
    LDA #$01
    STA CTRLPF              ; reflect the raw-port columns
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    STA REFP0
    STA REFP1

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — 32 rows: the needle (P0) and the 8-row fire block (P1)
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
    LDA #$FF
    STA GRP0                ; the needle bar
    CPX #FIRE_HEIGHT
    BCS NoFire
    LDA #$FF
    BNE FireDraw
NoFire:
    LDA #$00
FireDraw:
    STA GRP1                ; the fire block, 8 rows
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

; =============================================================================
; COARSE POSITIONING — two objects, one HMOVE
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

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
