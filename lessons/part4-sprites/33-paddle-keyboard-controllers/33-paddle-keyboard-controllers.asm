; =============================================================================
; LESSON 33: Paddle & Keyboard Controllers — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   A controller monitor.  Paddle 0's charge time positions a red needle;
;   the eight SWCHA bits light eight green playfield columns; the fire
;   button turns a green block red.  With no controller, the paddle read
;   times out, the needle sits at X=24, the columns are dark, and the fire
;   block is green.
;
; Reading a paddle (INPT0-INPT3):
;   The paddle is an RC circuit.  VBLANK bit 7 discharges it; clearing bit 7
;   starts the charge, and the input bit goes high when the capacitor crosses
;   the threshold.  (Bit 6 latches the fire buttons.)  The loop counts until
;   that happens.
;
;   The loop is bounded at 128 iterations (CPY #128) so a missing paddle
;   cannot hang the ROM and the read fits the 37-line VBLANK.  A timeout
;   stores 0, meaning no paddle or a resistance beyond the single-frame
;   bound.  The raw count is not calibrated; the monitor maps it to needle
;   X = count + 24 (24-151).
;
; Reading the raw matrix (SWCHA):
;   With SWACNT=$00 the port is all inputs, so a switch to ground (a joystick
;   direction, or a driving controller's switch) reads 0.  PF1 is loaded with
;   the inverted byte, so a closed switch lights one of the eight columns in
;   chunks 4-11 (reflected on the right half).
;
;   A CX50 keyboard controller is a driven 4x3 matrix: the program must set
;   SWACNT=$FF, pull one of the row lines (bits 4-7) low, wait ~400us, and
;   read the three column bits (INPT0/INPT1/INPT4, 0=pressed).  This monitor
;   shows the raw port; the doc explains the keypad scan, which is the next
;   step.  The driving controller is a name-only aside (two Gray-code bits).
;
; Reading fire (INPT4):
;   Bit 7 is 0 when pressed.  The block's COLUP1 is green when released and
;   red when pressed.
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
; The needle and the fire block start at visible line 80 (scanline 117):
; 80 top + 32 body + 1 clear + 79 bottom = 192.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), PaddleRead (A = the count, 0-127),
;   PaddleX (A = the needle X), KeyWrite (A = the inverted SWCHA byte),
;   FireWrite (A = COLUP1), PosApply0/1, HmoveApply, VisibleStart (37),
;   BodyStart (117, 32 hits), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson33.bin \
;        lessons/part4-sprites/33-paddle-keyboard-controllers/33-paddle-keyboard-controllers.asm
; Run:   stella build/lesson33.bin
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
    ; SWACNT resets to $00 (all port A pins inputs); no write is needed.

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- paddle 0: discharge, charge, count until ready or 128 ---
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
    LDA INPT0
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
