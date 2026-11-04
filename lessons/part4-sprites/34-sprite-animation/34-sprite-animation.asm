; =============================================================================
; LESSON 34: Sprite Animation — Walking Cycles & Character States — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   Animates a 16-row walker from a four-frame table.  The body reads the
;   current frame through a zero-page pointer; the frame advances every 8
;   frames (7.5 Hz), and REFP0 flips every 120 frames so the walker faces
;   the other way.
;
; The frame table:
;   Four frames, 16 bytes each, 64 bytes total.  Rows 0-11 are the same
;   upper body in every frame; rows 12-15 are the legs, and they are the
;   only bytes that differ.  The table is the animation; the body is the
;   player.
;
; The frame pointer:
;   FramePtr = FrameTable + FrameIndex * 16.  The index is 0-3, so four
;   ASLs multiply it by 16; the low byte and the high byte are computed in
;   VBLANK.  The body reads (FramePtr),Y with Y = 0..15.  The (zp),Y read
;   is 5 cycles, or 6 when it crosses a page; all four frames are 16-byte
;   aligned here, so the body is 18 cycles (19 only if a frame crosses a page).
;
; Timing:
;   AnimCounter counts 0-7 and advances the frame index when the increment
;   reaches 8; the index wraps at 4.  FlipCounter counts to 120 and toggles FlipState between 0 and 8,
;   which is written to REFP0.  The animation and the direction are two
;   independent counters; neither uses the RIOT timer.
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
; The walker starts at visible line 80 (scanline 117): 80 top + 16 body +
; 1 clear + 95 bottom = 192.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), AnimStep (A = the new 0-3 index, one
;   hit every 8 frames), FramePtrWrite (A = the frame base low byte),
;   FlipWrite (A = 0/8, one hit every 120 frames), VisibleStart (37),
;   BodyStart (117, 16 hits), SpriteWrite (A = the row byte), OverscanStart
;   (229).
;
; Build: acme -f plain -o build/lesson34.bin \
;        lessons/part4-sprites/34-sprite-animation/34-sprite-animation.asm
; Run:   stella build/lesson34.bin
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
SPRITE_X       = 72
POS_BIAS       = 3
ANIM_RATE      = 8      ; frames per walk step (7.5 Hz)
FLIP_RATE      = 120    ; frames per direction flip (2 s)

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
FrameIndex     = $80    ; 0-3, the current walk frame
AnimCounter    = $81    ; 0-7, the frame cadence
FlipCounter    = $82    ; 0-119, the direction cadence
FlipState      = $83    ; 0 or 8, written to REFP0
FramePtr       = $84    ; two-byte pointer to the current 16-row frame

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA FrameIndex
    STA AnimCounter
    STA FlipCounter
    STA FlipState

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

; --- flip the direction every 120 frames ---
    INC FlipCounter
    LDA FlipCounter
    CMP #FLIP_RATE
    BNE NoFlip
    LDA #$00
    STA FlipCounter
    LDA FlipState
    EOR #$08
    STA FlipState
FlipWrite:                  ; checkpoint: A = 0/8, every 120 frames
    STA REFP0
NoFlip:

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
    LDA #(SPRITE_X + POS_BIAS)
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
