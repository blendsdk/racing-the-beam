; =============================================================================
; LESSON 26: Horizontal Positioning — The Divide-by-15 Trick — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   Moves the Lesson 25 invader through five exact horizontal positions —
;   X = 16, 48, 80, 112, 144 — one every 60 frames.  Each frame the VBLANK
;   code calls SetHorizPos with the current target.
;
; The two tools of horizontal positioning:
;   - RESP0 is a strobe: it sets player 0's position counter to wherever the
;     beam is when the write lands.  When you strobe determines the coarse
;     position, in 3-color-clock steps (the CPU runs 3 clocks per cycle).
;   - HMP0 + HMOVE apply a signed fine offset of -8..+7 color clocks.  The
;     high nibble of HMP0 holds the value; negative moves RIGHT, positive
;     moves LEFT.  HMOVE must be strobed in HBLANK.
;
; The divide-by-15 routine:
;   Each SBC #15 / BCS iteration costs 5 CPU cycles = 15 color clocks of
;   beam travel.  The loop subtracts 15 until the carry clears; it runs one
;   extra time to detect the underflow, so A exits as a negative byte
;   ($F1..$FF).  EOR #7 and four ASLs turn that into the signed fine value
;   (positive = left).  The routine then strobes RESP0 and, on the next
;   line's HBLANK, HMOVE.
;
;   The routine's landing has a constant offset: the coarse position is
;   15 x (quotient + 1) - 12, and EOR #7 encodes the overshoot u as u - 9
;   where exact placement needs u - 12.  The three-clock difference means
;   the routine lands three pixels left of the value passed to it, so the
;   table stores target + 3 and the measured X is exact.
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
; The sprite sits at visible line 80 (scanline 117), exactly as in Lesson 25.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), PosStep (A = the new 0..4 index, every
;   60 frames), PosApply (A = the biased table value, every frame), Resp0Write
;   (the coarse strobe; its cycle advances with the table), HmoveApply (the
;   fine-motion strobe, next line), VisibleStart (37), BodyStart (117),
;   OverscanStart (229).
;
; Build: acme -f plain -o build/lesson26.bin \
;        lessons/part4-sprites/26-horizontal-positioning/26-horizontal-positioning.asm
; Run:   stella build/lesson26.bin
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
POS_FRAMES     = 60     ; ~1 second per position
POS_COUNT      = 5

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
FrameCounter   = $80
PosIndex       = $81    ; 0..4, the current entry in PosTable

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the tour tick: advance the position every POS_FRAMES frames ---
    INC FrameCounter
    LDA FrameCounter
    CMP #POS_FRAMES
    BNE ApplyPos
    LDA #$00
    STA FrameCounter
    INC PosIndex
    LDA PosIndex
    CMP #POS_COUNT
    BNE PosStepStore
    LDA #$00
PosStepStore:
PosStep:                    ; checkpoint: A = the new index (one hit per 60 frames)
    STA PosIndex

; --- position the player for this frame ---
ApplyPos:
    LDX PosIndex
    LDA PosTable,X
PosApply:                   ; checkpoint: A = the biased table value (target + 3)
    JSR SetHorizPos

    LDA #$42
    STA COLUP0              ; red
    LDA #$02
    STA COLUBK              ; dark neutral
    LDA #$00
    STA NUSIZ0
    STA REFP0

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — the Lesson 25 kernel, unchanged except for the moving X
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
SpriteWrite:
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

; -----------------------------------------------------------------------------
; OVERSCAN
; -----------------------------------------------------------------------------
OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SET HORIZONTAL POSITION — the classic divide-by-15 routine
; =============================================================================
; Input: A = the biased target (target + 3), 0-162.  Clobbers A only; X and Y survive.
; The routine spends about two lines, so call it in VBLANK.
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
Resp0Write:                 ; checkpoint: the coarse strobe (cycle 5 x SBC count + 14)
    STA RESP0               ; set the position counter to the beam's clock
    STA WSYNC               ; move to the next line's HBLANK
HmoveApply:                 ; checkpoint: next line, HBLANK
    STA HMOVE               ; apply HMP0 (and the other HM registers)
    RTS

; =============================================================================
; POSITION TABLE — five targets, left to right
; =============================================================================
PosTable:
    !byte 19, 51, 83, 115, 147   ; target + 3 (the routine's output-delay bias)

; =============================================================================
; SPRITE SHAPE — the Lesson 25 invader
; =============================================================================
SpriteShape:
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
