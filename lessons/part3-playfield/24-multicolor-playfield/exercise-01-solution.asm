; =============================================================================
; LESSON 24 — EXERCISE 1 SOLUTION: A Moving Rainbow
; =============================================================================
; Part 3: Playfield
;
; Exercise: slide the rainbow bands upward, one band per second.
;
; The technique: store the 192-byte rainbow twice (384 bytes) and advance the
; table pointer by 12 bytes every 60 frames.  The kernel keeps reading
; `(ColorPtr),Y` with Y = 0..191; when the pointer moves into the second
; copy, the bands wrap seamlessly.  The offset cycles 0, 12, 24, ..., 180,
; then back to 0; the doubled table guarantees Y+offset never runs past the
; data.
;
; The pointer is a 16-bit add: low = base low + offset, high = base high +
; carry.  The update happens in VBLANK, once per second.
;
; Debugger checkpoints: OffsetStep (A = the new offset, every 60 frames),
; ColorWrite (one hit per line, A = the table byte).
;
; Build: acme -f plain -o build/lesson24-ex1.bin \
;        lessons/part3-playfield/24-multicolor-playfield/exercise-01-solution.asm
; Run:   stella build/lesson24-ex1.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
STEP_FRAMES    = 60     ; one band per ~1 s
BAND_BYTES     = 12

FrameCounter   = $80
ColorOffset    = $81    ; 0, 12, 24, ..., 180
ColorPtr       = $82

    * = $F000

Reset:
    +clean_start

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- advance the offset one band every STEP_FRAMES frames ---
    INC FrameCounter
    LDA FrameCounter
    CMP #STEP_FRAMES
    BNE VblankSetPtr
    LDA #$00
    STA FrameCounter
    LDA ColorOffset
    CLC
    ADC #BAND_BYTES
    CMP #VISIBLE_LINES
    BNE OffsetStore
    LDA #$00
OffsetStore:
OffsetStep:                 ; checkpoint: A = the new offset (tick only)
    STA ColorOffset

; --- ColorPtr = RainbowDouble + offset ---
VblankSetPtr:
    LDA #<RainbowDouble
    CLC
    ADC ColorOffset
    STA ColorPtr
    LDA #>RainbowDouble
    ADC #$00
    STA ColorPtr+1

; --- the shape never changes ---
    LDA #$F0
    STA PF0
    LDA #$CC
    STA PF1
    LDA #$F0
    STA PF2
    LDA #$02
    STA COLUBK
    LDA #$01
    STA CTRLPF

    LDY #0
    +wait_timer

    LDA #$00
    STA VBLANK
VisibleStart:
    LDA (ColorPtr),Y
    STA COLUPF
ColorWrite:                 ; checkpoint: A = the color
    INY
    STA WSYNC
    CPY #VISIBLE_LINES
    BNE VisibleStart

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; DOUBLED RAINBOW — 16 bands x 12 lines, twice (384 bytes)
; =============================================================================
RainbowDouble:
    !fill 12, $0E
    !fill 12, $1E
    !fill 12, $2E
    !fill 12, $3E
    !fill 12, $4E
    !fill 12, $5E
    !fill 12, $6E
    !fill 12, $7E
    !fill 12, $8E
    !fill 12, $9E
    !fill 12, $AE
    !fill 12, $BE
    !fill 12, $CE
    !fill 12, $DE
    !fill 12, $EE
    !fill 12, $FE
    !fill 12, $0E
    !fill 12, $1E
    !fill 12, $2E
    !fill 12, $3E
    !fill 12, $4E
    !fill 12, $5E
    !fill 12, $6E
    !fill 12, $7E
    !fill 12, $8E
    !fill 12, $9E
    !fill 12, $AE
    !fill 12, $BE
    !fill 12, $CE
    !fill 12, $DE
    !fill 12, $EE
    !fill 12, $FE

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
