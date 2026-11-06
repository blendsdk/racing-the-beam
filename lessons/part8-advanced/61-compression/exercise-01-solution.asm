; =============================================================================
; LESSON 61 — EXERCISE 1 SOLUTION
; A 16-frame 8x8 sprite table, compressed with RLE and drawn
; =============================================================================
; The exercise: compress a 16 x 8 sprite table with run-length encoding and
; draw it.
;
; What this program does:
;   The table is 16 animation frames of eight bytes each: a ball that falls,
;   squashes and rises again.  Stored raw it is 136 bytes (17 frames); stored
;   as an RLE stream it is 66 bytes (48.5%).  A small decoder rebuilds one byte per
;   visible line into an eight-byte buffer.  The kernel displays the current
;   byte with STA GRP0 and then overwrites that same buffer slot with the NEXT
;   frame's byte, so one eight-byte buffer is enough: the line that has just
;   been drawn never needs its old byte again.  VBLANK resets the stream index
;   and pre-decodes frame 0 every frame, so the strip repeats; without that
;   reset the second frame would read past the end of the 66-byte stream.
;
; The stream (the same token format as the lesson):
;   bit 7 = 1  run:   the low seven bits are count-1; the next byte is the
;              value, repeated count times.
;   bit 7 = 0  literals: the low seven bits are count-1; the next count bytes
;              are copied.
;   The table has 17 frames: the 16 displayed frames and one pad frame of
;   zeros, so the pipeline's decode during the last displayed frame has valid
;   bytes to read.  The pad frame is never displayed.
;
; The picture:
;   8 status lines (a full-width bar) + 128 sprite lines (16 frames x 8) +
;   56 blank lines = 192.  Player 0 is eight pixels wide at x=76.
;
; The frame: 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5, OverscanStart 229.
;   Checkpoints: StreamReady (Y = the stream index after the per-frame reset;
;   the same value every frame) and FrameByte0 (A = the current frame's first
;   sprite byte).
;
; RAM map:
;   $80-$87  CurBuf      the eight bytes of the current sprite frame
;   $88-$8F  free
;   $90      TokLeft     bytes left in the current token
;   $91      free        (the current run's value is carried in X)
;   $92      Mode        0 = literal, 1 = run
;   $93      free
;   $94      FramesLeft  the frames still to draw (16)
;   $95      StatusLeft  the status bar's line counter
;   $96-$9F  free
;   $F8-$FF  stack
;
; Build: acme -f plain -o build/exercise-01-solution.bin \
;        lessons/part8-advanced/61-compression/exercise-01-solution.asm
; The ROM is 4,096 bytes.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
POS_BIAS       = 3
PLAYER_X       = 76

CurBuf     = $80
TokLeft    = $90
Mode       = $92
FramesLeft = $94
StatusLeft = $95

; -----------------------------------------------------------------------------
; NEXT_BYTE — decode one sprite byte into A, inlined into the line loop
; -----------------------------------------------------------------------------
; X carries the control byte, then the token's count, and on a run token it
; carries the run value across the lines.  The display's line index is baked
; into the unrolled SPRITE_LINE macro, so the decoder is free to use X.  Y is
; the stream index.  The token state lives in $90 and $92.  Inlining the decode
; avoids the 12 cycles of a JSR/RTS pair.
!macro NEXT_BYTE {
    !zone {
    LDA TokLeft
    BNE .have
    LDA SpriteStream,Y
    INY
    TAX                      ; X = the control byte (the line index is baked)
    BMI .run
; --- literals ---------------------------------------------------------------
    INX                      ; count = control + 1
    STX TokLeft
    LDA #0
    STA Mode
    JMP .have
; --- run --------------------------------------------------------------------
.run:
    TXA
    AND #$7F
    CLC
    ADC #1
    STA TokLeft
    LDA SpriteStream,Y
    INY
    TAX                      ; X carries the run value across the lines
    LDA #1
    STA Mode
.have:
    DEC TokLeft
    LDA Mode
    BNE .isrun
    LDA SpriteStream,Y
    INY
    JMP .done
.isrun:
    TXA
.done:
    }
}

; =============================================================================
; RESET — position the player and decode frame 0
; =============================================================================
    * = $F000
Reset:
    +clean_start
    LDA #$00
    STA COLUBK
    LDA #$0E
    STA COLUPF
    LDA #$0E
    STA COLUP0               ; the ball is white
    LDA #$00
    STA GRP0
    LDA #$01
    STA CTRLPF

    JMP StartFrame

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:
    +vsync
VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    LDA #(PLAYER_X + POS_BIAS)
    JSR SetCoarseP0
    STA WSYNC
    STA HMOVE

; -----------------------------------------------------------------------------
; Reset the decoder and pre-decode frame 0 — every frame
; -----------------------------------------------------------------------------
; The stream is a one-shot table: it is consumed from byte 0.  Resetting Y,
; TokLeft and Mode and decoding the first eight bytes here is what makes the
; animation repeat instead of reading the !EA fill after the last frame.
    LDA #0
    STA TokLeft
    STA Mode
    LDY #0
    +NEXT_BYTE
    STA CurBuf+0
    +NEXT_BYTE
    STA CurBuf+1
    +NEXT_BYTE
    STA CurBuf+2
    +NEXT_BYTE
    STA CurBuf+3
    +NEXT_BYTE
    STA CurBuf+4
    +NEXT_BYTE
    STA CurBuf+5
    +NEXT_BYTE
    STA CurBuf+6
    +NEXT_BYTE
    STA CurBuf+7

    +wait_timer
StreamReady:                 ; checkpoint: Y = the stream index after the reset
                             ; and the frame-0 pre-decode (constant per frame)
    LDA #$00
    STA VBLANK

BodyStart:
; --- 8 status lines: a full-width bar ---------------------------------------
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    LDA #8
    STA StatusLeft           ; a zero-page counter: Y is the stream index and X
StatusLoop:                  ; holds the decoder state, so neither may be used
    STA WSYNC
    DEC StatusLeft
    BNE StatusLoop

; --- 128 sprite lines: 16 frames x 8 bytes -----------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA #16
    STA FramesLeft
!macro SPRITE_LINE .n {
    LDA CurBuf+.n
    STA GRP0
    +NEXT_BYTE
    STA CurBuf+.n
    STA WSYNC
}
FrameLoop:
    LDA CurBuf+0
FrameByte0:                  ; checkpoint: A = the current frame's first byte
    STA GRP0
    +NEXT_BYTE
    STA CurBuf+0
    STA WSYNC
    +SPRITE_LINE 1
    +SPRITE_LINE 2
    +SPRITE_LINE 3
    +SPRITE_LINE 4
    +SPRITE_LINE 5
    +SPRITE_LINE 6
    +SPRITE_LINE 7
    DEC FramesLeft
    BEQ FramesDone
    JMP FrameLoop
FramesDone:

; --- the sprite ends; 56 blank lines ----------------------------------------
    LDA #$00
    STA GRP0
    LDY #56
TailLoop:
    STA WSYNC
    DEY
    BNE TailLoop

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; -----------------------------------------------------------------------------
; SetCoarseP0 — the Lesson 26 divide-by-15 positioning dance
; -----------------------------------------------------------------------------
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
    STA RESP0
    RTS

; =============================================================================
; THE RLE SPRITE STREAM — 17 frames of 8 bytes (136 raw bytes) -> 66 bytes
; =============================================================================
; Frame k places a 4-pixel ball at row k (frames 0-7) or 15-k (frames 8-15);
; the last frame is the pad frame the pipeline reads but never displays.
    !align 255, 0
SpriteStream:
    !byte $82, $3C, $85, $00, $82, $3C, $85, $00
    !byte $82, $3C, $85, $00, $82, $3C, $85, $00
    !byte $82, $3C, $85, $00, $82, $3C, $85, $00
    !byte $01, $3C, $3C, $86, $00, $00, $3C, $86
    !byte $00, $00, $3C, $85, $00, $01, $3C, $3C
    !byte $84, $00, $82, $3C, $83, $00, $82, $3C
    !byte $83, $00, $82, $3C, $83, $00, $82, $3C
    !byte $83, $00, $82, $3C, $83, $00, $82, $3C
    !byte $8C, $00

    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset, Reset, Reset
