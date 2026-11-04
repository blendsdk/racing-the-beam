; =============================================================================
; LESSON 27 — EXERCISE 2 SOLUTION: Edge to Edge
; =============================================================================
; Part 4: Sprites
;
; Exercise: let the sprite reach X=8 and X=152.
;
; The technique: only the bounds change.  At X=8 the sprite spans 8-15; at
; X=152 it spans 152-159, the last visible clock.  The patrol and the
; joystick logic are unchanged.
;
; Build: acme -f plain -o build/lesson27-ex2.bin \
;        lessons/part4-sprites/27-sprite-movement/exercise-02-solution.asm
; Run:   stella build/lesson27-ex2.bin
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
SPRITE_HEIGHT  = 8
MIN_X          = 8
MAX_X          = 152
START_X        = 80
POS_BIAS       = 3      ; Lesson 26's measured output-delay calibration

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
SpriteX        = $80    ; 0-159, the desired TIA X
Direction      = $81    ; +1, -1 ($FF), or 0

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start
    LDA #START_X
    STA SpriteX
    LDA #$01
    STA Direction           ; start moving right
    LDA #$00
    STA SWACNT              ; all port A pins are inputs

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- read the joystick and choose a direction ---
    LDA SWCHA
    AND #$C0                ; bits 7 (right) and 6 (left)
    CMP #$80
    BEQ DirLeft
    CMP #$40
    BEQ DirRight
    CMP #$00
    BEQ DirStop
    JMP DirDone             ; $C0: neither pressed, keep patrolling
DirRight:
    LDA #$01
    JMP DirStore
DirLeft:
    LDA #$FF
    JMP DirStore
DirStop:
    LDA #$00
DirStore:
DirWrite:                   ; checkpoint: A = the direction, every frame a horizontal input is held
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
    STA Direction           ; bounce left
    JMP MoveDone
CheckLow:
    CMP #MIN_X
    BCS StoreX
    LDA #MIN_X
    STA SpriteX
    LDA #$01
    STA Direction           ; bounce right
    JMP MoveDone
StoreX:
    STA SpriteX
MoveDone:
    LDA SpriteX
MoveTick:                   ; checkpoint: A = the new X, every frame
    CLC
    ADC #POS_BIAS
PosApply:                   ; checkpoint: A = the biased target
    JSR SetHorizPos

    LDA #$42
    STA COLUP0
    LDA #$02
    STA COLUBK
    LDA #$00
    STA NUSIZ0
    STA REFP0

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — the Lesson 25 kernel
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
    LDA SpriteShape,X
    STA GRP0
    STA WSYNC
    INX
    CPX #SPRITE_HEIGHT
    BNE BodyLoop

    LDA #$00
    STA GRP0
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
; SET HORIZONTAL POSITION — the Lesson 26 divide-by-15 routine
; =============================================================================
; Input: A = the biased target (target + 3), 0-162.
SetHorizPos:
    STA WSYNC               ; start on a fresh line
    SEC
Div15:
    SBC #15                 ; each iteration = 5 cycles = 15 clocks of beam
    BCS Div15
    EOR #7                  ; the negative remainder becomes the signed fine value
    ASL                     ; move bits 0-3 into HMP0's high nibble
    ASL
    ASL
    ASL
    STA HMP0
Resp0Write:
    STA RESP0               ; set the position counter to the beam's clock
    STA WSYNC               ; move to the next line's HBLANK
HmoveApply:
    STA HMOVE               ; apply HMP0 (and the other HM registers)
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
