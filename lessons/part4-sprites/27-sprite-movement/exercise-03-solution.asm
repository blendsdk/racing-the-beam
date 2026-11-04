; =============================================================================
; LESSON 27 — EXERCISE 3 SOLUTION: Vertical Movement (Stretch Goal)
; =============================================================================
; Part 4: Sprites
;
; Exercise: move the sprite vertically with the joystick's up/down bits.
;
; The technique: horizontal position is a variable (SpriteX), and vertical
; position is a line count.  Make the top count a variable too (SpriteTop):
; the top loop loads it, and the bottom count is computed as
; 192 - SpriteTop - 8 - 1 each frame.  Up and down adjust SpriteTop by 4,
; clamped to 40..140.  The horizontal patrol from the lesson ROM continues.
;
;   SWCHA & $30   meaning
;   $30           neither up nor down
;   $20           up pressed:   SpriteTop -= 4
;   $10           down pressed: SpriteTop += 4
;   $00           both: no vertical change
;
; Debugger checkpoints: MoveTick (A = the new X), TopTick (A = the new or
; clamped SpriteTop, every frame exactly one of up/down is held), VisibleStart (37), BodyStart
; (37 + SpriteTop), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson27-ex3.bin \
;        lessons/part4-sprites/27-sprite-movement/exercise-03-solution.asm
; Run:   stella build/lesson27-ex3.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
SPRITE_HEIGHT  = 8
MIN_X          = 16
MAX_X          = 144
START_X        = 80
POS_BIAS       = 3
MIN_TOP        = 40
MAX_TOP        = 140
TOP_START      = 80
TOP_STEP       = 4

SpriteX        = $80
Direction      = $81
SpriteTop      = $82
BottomCount    = $83

    * = $F000

Reset:
    +clean_start
    LDA #START_X
    STA SpriteX
    LDA #TOP_START
    STA SpriteTop
    LDA #$01
    STA Direction
    LDA #$00
    STA SWACNT

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- horizontal: read left/right, choose a direction ---
    LDA SWCHA
    AND #$C0
    CMP #$80
    BEQ DirLeft
    CMP #$40
    BEQ DirRight
    CMP #$00
    BEQ DirStop
    JMP DirDone
DirRight:
    LDA #$01
    JMP DirStore
DirLeft:
    LDA #$FF
    JMP DirStore
DirStop:
    LDA #$00
DirStore:
DirWrite:
    STA Direction
DirDone:

; --- move, bounce at the bounds ---
    LDA SpriteX
    CLC
    ADC Direction
    CMP #(MAX_X + 1)
    BCC CheckLow
    LDA #MAX_X
    STA SpriteX
    LDA #$FF
    STA Direction
    JMP MoveDone
CheckLow:
    CMP #MIN_X
    BCS StoreX
    LDA #MIN_X
    STA SpriteX
    LDA #$01
    STA Direction
    JMP MoveDone
StoreX:
    STA SpriteX
MoveDone:
    LDA SpriteX
MoveTick:
    CLC
    ADC #POS_BIAS
PosApply:
    JSR SetHorizPos

; --- vertical: read up/down, adjust the top count ---
    LDA SWCHA
    AND #$30
    CMP #$20                ; up pressed
    BEQ MoveUp
    CMP #$10                ; down pressed
    BEQ MoveDown
    JMP VDone
MoveUp:
    LDA SpriteTop
    SEC
    SBC #TOP_STEP
    CMP #MIN_TOP
    BCS StoreTop
    LDA #MIN_TOP
    JMP StoreTop
MoveDown:
    LDA SpriteTop
    CLC
    ADC #TOP_STEP
    CMP #(MAX_TOP + 1)
    BCC StoreTop
    LDA #MAX_TOP
StoreTop:
TopTick:                    ; checkpoint: A = the new or clamped SpriteTop; exactly one of up/down held
    STA SpriteTop
VDone:
    LDA #(VISIBLE_LINES - SPRITE_HEIGHT - 1)
    SEC
    SBC SpriteTop
    STA BottomCount

    LDA #$42
    STA COLUP0
    LDA #$02
    STA COLUBK
    LDA #$00
    STA NUSIZ0
    STA REFP0

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — the top count and bottom count are variables
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK
    LDX SpriteTop
VisibleStart:
TopLoop:
    STA WSYNC
    DEX
    BNE TopLoop

    LDX #0
BodyStart:
BodyLoop:
    LDA SpriteShape,X
    STA GRP0
    STA WSYNC
    INX
    CPX #SPRITE_HEIGHT
    BNE BodyLoop

    LDA #$00
    STA GRP0
    STA WSYNC

    LDX BottomCount
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

; Input: A = the biased target (target + 3), 0-162.
SetHorizPos:
    STA WSYNC               ; start on a fresh line
    SEC
Div15:
    SBC #15                 ; 5 cycles = 15 clocks of beam travel
    BCS Div15
    EOR #7                  ; the negative remainder becomes the signed fine value
    ASL
    ASL
    ASL
    ASL
    STA HMP0
Resp0Write:
    STA RESP0               ; coarse position at the beam's clock
    STA WSYNC
HmoveApply:
    STA HMOVE               ; apply the fine motion in HBLANK
    RTS

SpriteShape:
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %11011011
    !byte %11111111
    !byte %00100100
    !byte %01011010
    !byte %10100101

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
