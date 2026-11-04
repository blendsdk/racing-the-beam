; =============================================================================
; LESSON 27: Sprite Movement — Reading the Joystick — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   The Lesson 25 invader patrols horizontally.  With no joystick input it
;   moves one pixel per frame, bounces at X=16 and X=144, and keeps going.
;   Holding left or right takes over the direction; holding both stops it.
;
; Reading the joystick:
;   SWCHA is at $0280 and is active-low: 0 = pressed.  Player 0 uses bits
;   4 (up), 5 (down), 6 (left), and 7 (right).  This lesson reads bits 6-7:
;
;     SWCHA & $C0   meaning
;     $C0           neither left nor right: keep the current direction
;     $80           left pressed:  direction = -1 ($FF)
;     $40           right pressed: direction = +1
;     $00           both pressed:  direction = 0 (stop)
;
;   SWACNT is set to $00 in Reset so all port A pins are inputs.
;
; Movement:
;   SpriteX is a 0-159 value.  Direction is +1 or -1 (two's complement $FF).
;   Each frame: X += Direction, clamp to 16..144, flip the direction if the
;   clamp was hit, then call SetHorizPos with X + 3 (the routine's output
;   delay bias from Lesson 26).  The sprite stays at the Lesson 25 vertical
;   schedule (visible line 80, eight rows).
;
;   The auto-patrol is deliberate: with no controller the ROM still shows
;   the movement, which makes the captured states unambiguous.  Press the
;   joystick in Stella and the same code follows it.
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), MoveTick (A = the new X, every frame),
;   PosApply (A = X + 3), DirWrite (A = the input direction, every frame held),
;   VisibleStart (37), BodyStart (117), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson27.bin \
;        lessons/part4-sprites/27-sprite-movement/27-sprite-movement.asm
; Run:   stella build/lesson27.bin
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
MIN_X          = 16
MAX_X          = 144
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
