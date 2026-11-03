; =============================================================================
; LESSON 24: The Multicolor Playfield — Racing the Beam
; =============================================================================
; Part 3: Playfield
;
; What this program does:
;   Colors the playfield every scanline.  The shape is the Lesson 19 castle
;   (PF0=$F0, PF1=$CC, PF2=$F0), but COLUPF is written from a 192-byte table,
;   so every line can have its own color.  Two tables alternate every two
;   seconds:
;
;     Rainbow: 16 hue bands of 12 lines, hues 0-15 at luminance 7;
;     Regions: six cool bands of 16 lines, then six warm bands of 16 lines.
;
; Why per-line color is cheap:
;   COLUPF is a normal TIA register; the beam reads it when it draws the
;   playfield.  A write in HBLANK changes the color of the whole line, and a
;   table lookup per line gives every line a different value.  The shape and
;   the color are independent layers: the same 20 bits, a different palette.
;
; The per-line kernel:
;   LDA (ColorPtr),Y   5-9
;   STA COLUPF        10-12   (the color for this line, in HBLANK)
;   INY               13-14
;   STA WSYNC         15-17
;   CPY #192           next line 0-1
;   BNE VisibleStart   next line 2-4
;
;   The release (LDA #$00 + STA VBLANK) is 5 cycles, the same as the
;   steady-state wake (CPY + BNE), so line 37 and line 228 share the phase.
;   Y runs 0..191; the table pointer is swapped in VBLANK, never mid-frame.
;
; The tables:
;   Rainbow (192 bytes): 16 x 12 lines, hue k at luminance 7 ($0E, $1E, ...,
;   $FE).  State A.
;   Regions (192 bytes): 6 x 16 cool ($6E,$7E,$8E,$9E,$AE,$BE), then
;   6 x 16 warm ($2E,$3E,$4E,$5E,$1E,$0E).  State B.
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), StateFlip (A = the new state, at
;   frames 120, 240, ...), VisibleStart (37), ColorWrite (one hit per line,
;   A = the table byte), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson24.bin \
;        lessons/part3-playfield/24-multicolor-playfield/24-multicolor-playfield.asm
; Run:   stella build/lesson24.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines
VISIBLE_LINES  = 192
STATE_FRAMES   = 120    ; ~2 seconds per color table

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
FrameCounter   = $80
ColorState     = $81    ; 0 = Rainbow, 1 = Regions
ColorPtr       = $82    ; 2 bytes: the current 192-byte table

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM; ColorState = 0

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
    +vsync

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the color tick: swap tables every STATE_FRAMES frames ---
    INC FrameCounter
    LDA FrameCounter
    CMP #STATE_FRAMES
    BNE VblankSetColors
    LDA #$00
    STA FrameCounter
    LDA ColorState
    EOR #$01
StateFlip:                  ; debugger checkpoint: A = the new state (flip only)
    STA ColorState

; --- point ColorPtr at the current 192-byte table ---
VblankSetColors:
    LDA ColorState
    BEQ VblankUseRainbow
    LDA #<Regions
    STA ColorPtr
    LDA #>Regions
    STA ColorPtr+1
    JMP VblankSetup
VblankUseRainbow:
    LDA #<Rainbow
    STA ColorPtr
    LDA #>Rainbow
    STA ColorPtr+1

; --- the shape never changes; only the color does ---
VblankSetup:
    LDA #$F0
    STA PF0                 ; chunks 0-3 on
    LDA #$CC
    STA PF1                 ; chunks 4-11: 11001100
    LDA #$F0
    STA PF2                 ; chunks 12-19: 00001111 (bit 0 first)
    LDA #$02
    STA COLUBK              ; dark background
    LDA #$01
    STA CTRLPF              ; reflect: the castle is symmetric

    LDY #0
    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — one COLUPF byte per line
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam on line 37
VisibleStart:               ; debugger checkpoint: the picture's first line (37)
    LDA (ColorPtr),Y        ; 5-9    this line's color
    STA COLUPF              ; 10-12  in HBLANK
ColorWrite:                 ; debugger checkpoint: A = the color, hit 13
    INY                     ; 13-14
    STA WSYNC               ; 15-17  park the rest of the line
    CPY #VISIBLE_LINES      ; next line 0-1
    BNE VisibleStart        ; next line 2-4

; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines; blank-on lands in line 229's HBLANK
; -----------------------------------------------------------------------------
OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; RAINBOW — 16 hue bands of 12 lines (192 bytes)
; =============================================================================
Rainbow:
    !fill 12, $0E           ; hue 0
    !fill 12, $1E           ; hue 1
    !fill 12, $2E           ; hue 2
    !fill 12, $3E           ; hue 3
    !fill 12, $4E           ; hue 4
    !fill 12, $5E           ; hue 5
    !fill 12, $6E           ; hue 6
    !fill 12, $7E           ; hue 7
    !fill 12, $8E           ; hue 8
    !fill 12, $9E           ; hue 9
    !fill 12, $AE           ; hue 10
    !fill 12, $BE           ; hue 11
    !fill 12, $CE           ; hue 12
    !fill 12, $DE           ; hue 13
    !fill 12, $EE           ; hue 14
    !fill 12, $FE           ; hue 15

; =============================================================================
; REGIONS — six cool bands then six warm bands (16 lines each)
; =============================================================================
Regions:
    !fill 16, $6E           ; cool: light violet
    !fill 16, $7E           ; violet
    !fill 16, $8E           ; blue
    !fill 16, $9E           ; light blue
    !fill 16, $AE           ; aqua
    !fill 16, $BE           ; teal-green
    !fill 16, $2E           ; warm: orange
    !fill 16, $3E           ; peach
    !fill 16, $4E           ; light salmon-pink
    !fill 16, $5E           ; pink
    !fill 16, $1E           ; gold
    !fill 16, $0E           ; light gray

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
