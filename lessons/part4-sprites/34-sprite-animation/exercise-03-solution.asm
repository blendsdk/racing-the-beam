; =============================================================================
; LESSON 34 — EXERCISE 3 SOLUTION: Walk and Move (Stretch Goal)
; =============================================================================
; Part 4: Sprites
;
; Exercise: combine the walk cycle with horizontal movement.
;
; The technique: SpriteX moves 1 pixel per frame and bounces at 16/144;
; the direction byte also selects REFP0, so the walker faces the way it
; moves.  The animation tick, the frame pointer, and the body are the
; lesson's; only the positioning and the direction byte are new.
;
; Build: acme -f plain -o build/lesson34-ex3.bin \
;        lessons/part4-sprites/34-sprite-animation/exercise-03-solution.asm
; Run:   stella build/lesson34-ex3.bin
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
SPRITE_HEIGHT  = 16
POS_BIAS       = 3
ANIM_RATE      = 8      ; frames per walk step (7.5 Hz)

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
FrameIndex     = $80    ; 0-3, the current walk frame
AnimCounter    = $81    ; 0-7, the frame cadence
FramePtr       = $84    ; two-byte pointer to the current 16-row frame
SpriteX        = $86    ; 16-144, the walker's TIA X
Direction      = $87    ; +1 right, -1 ($FF) left

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA FrameIndex
    STA AnimCounter
    LDA #16
    STA SpriteX
    LDA #$01
    STA Direction

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- advance the walk frame every 8 frames ---
    INC AnimCounter
    LDA AnimCounter
    CMP #ANIM_RATE
    BNE NoAnimStep
    LDA #$00
    STA AnimCounter
    INC FrameIndex
    LDA FrameIndex
    AND #$03
AnimStep:                   ; checkpoint: A = the new 0-3 index
    STA FrameIndex
NoAnimStep:

; --- move horizontally, bounce at 16/144, face the direction ---
    LDA SpriteX
    CLC
    ADC Direction
    CMP #145
    BCC CheckLow
    LDA #144
    STA SpriteX
    LDA #$FF
    STA Direction
    JMP MoveDone
CheckLow:
    CMP #16
    BCS StoreX
    LDA #16
    STA SpriteX
    LDA #$01
    STA Direction
    JMP MoveDone
StoreX:
    STA SpriteX
MoveDone:
MoveTick:                   ; checkpoint: A = the new X on a normal frame, the new Direction on a bounce
    LDA #$00
    LDX Direction
    BMI FaceLeft
    JMP FaceStore
FaceLeft:
    LDA #$08
FaceStore:
FaceWrite:                  ; checkpoint: A = REFP0 (0 right, 8 left)
    STA REFP0

; --- FramePtr = FrameTable + FrameIndex * 16 ---
    LDA FrameIndex
    ASL
    ASL
    ASL
    ASL
    CLC
    ADC #<FrameTable
FramePtrWrite:              ; checkpoint: A = the frame base low byte
    STA FramePtr
    LDA #>FrameTable
    ADC #$00
    STA FramePtr+1

; --- position, colors ---
    LDA SpriteX
    CLC
    ADC #POS_BIAS
    JSR SetHorizPos
    LDA #$42
    STA COLUP0              ; red
    LDA #$02
    STA COLUBK              ; dark neutral
    LDA #$00
    STA NUSIZ0
    STA REFP1

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — the pointer walks the 16-row frame
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK
    LDX #SPRITE_TOP
VisibleStart:
TopLoop:
    STA WSYNC
    DEX
    BNE TopLoop

    LDY #0
BodyStart:
BodyLoop:
    LDA (FramePtr),Y
SpriteWrite:                ; checkpoint: A = this row's shape
    STA GRP0
    STA WSYNC
    INY
    CPY #SPRITE_HEIGHT
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
; SET HORIZONTAL POSITION — the Lesson 26 routine, with the +3 bias
; =============================================================================
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

; =============================================================================
; WALK FRAMES — 4 x 16 rows; rows 0-11 are shared, rows 12-15 are the legs
; =============================================================================
FrameTable:
; --- frame 0: legs apart ---
    !byte %00011000         ; row 0  (head)
    !byte %00111100         ; 1
    !byte %00111110         ; 2  (right-facing nose)
    !byte %00011000         ; 3
    !byte %01111110         ; 4  (arms)
    !byte %11111111         ; 5
    !byte %11111111         ; 6
    !byte %01111110         ; 7
    !byte %00111100         ; 8  (body)
    !byte %00111100         ; 9
    !byte %00111100         ; 10
    !byte %00111100         ; 11
    !byte %01100110         ; 12 (legs)
    !byte %01100110         ; 13
    !byte %01100110         ; 14
    !byte %11000011         ; 15
; --- frame 1: passing pose ---
    !byte %00011000
    !byte %00111100
    !byte %00111110         ; right-facing nose
    !byte %00011000
    !byte %01111110
    !byte %11111111
    !byte %11111111
    !byte %01111110
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %00100100
    !byte %00100100
    !byte %00100100
    !byte %01000010
; --- frame 2: legs closing ---
    !byte %00011000
    !byte %00111100
    !byte %00111110         ; right-facing nose
    !byte %00011000
    !byte %01111110
    !byte %11111111
    !byte %11111111
    !byte %01111110
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %01100110
    !byte %01100110
    !byte %00100100
    !byte %01000010
; --- frame 3: passing pose, feet apart ---
    !byte %00011000
    !byte %00111100
    !byte %00111110         ; right-facing nose
    !byte %00011000
    !byte %01111110
    !byte %11111111
    !byte %11111111
    !byte %01111110
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %00100100
    !byte %00100100
    !byte %01100110
    !byte %11000011

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
