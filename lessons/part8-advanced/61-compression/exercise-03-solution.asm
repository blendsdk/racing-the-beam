; =============================================================================
; LESSON 61 — EXERCISE 3 SOLUTION
; A 2-bit-per-pixel dictionary scheme for a 96-byte buffer
; =============================================================================
; The exercise: compress a picture with two bits per pixel, decompress it, and
; draw the result.
;
; What this program does:
;   A 20 x 19 picture is stored as 96 bytes at two bits per pixel (4 pixels per
;   byte).  Each 2-bit value is an index into a four-entry dictionary, and each
;   dictionary entry is one playfield bit (on or off).  At startup the program
;   walks the 96 bytes, looks up every pixel, and rebuilds the 19 playfield
;   rows (three bytes per row, 57 bytes) in RAM at $90.  The visible kernel
;   draws those rows as a small framed picture in the middle of the screen.
;
; The format:
;   96 bytes = 19 rows x 5 bytes, plus one pad byte.  Five bytes hold 20 pixels
;   at 2 bits each.  A byte's pixels are, from left to right, bits 7-6, 5-4,
;   3-2 and 1-0.  The dictionary is four bytes: 0, 1, 1, 0.  Codewords 1 and 2
;   both light a pixel; 0 and 3 leave it dark.  The playfield has one colour,
;   so the dictionary maps two codewords to "on" and two to "off"; on a
;   two-colour object the same table would select the colour instead.
;
; The picture:
;   A 20 x 19 diamond with a checkerboard core.  The reflected playfield
;   mirrors it on the right.
;
; The frame: 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5, OverscanStart 229/4
;   (the overscan timer absorbs the two-cycle phase difference; the frame stays
;   262 lines).
;
; RAM map:
;   $80-$82  RowBuf     one decoded playfield row (decompressor scratch)
;   $83-$84  ImgPtr     the image row pointer
;   $85-$89  free
;   $8A      PackIdx    the source byte index during the decompress
;   $8B      YSAVE      the pixel index across a lookup
;   $8C      RowCount   the rows left in the startup decompress
;   $8D      ByteTmp    the packed byte being split
;   $8E-$8F  free
;   $90-$C8  Image      19 rows x 3 bytes = 57 bytes of decoded playfield
;   $C9-$F7  free
;   $F8-$FF  stack
;
; Build: acme -f plain -o build/exercise-03-solution.bin \
;        lessons/part8-advanced/61-compression/exercise-03-solution.asm
; The ROM is 4,096 bytes.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36

RowBuf   = $80
ImgPtr   = $83
PackIdx  = $8A
Image    = $90
YSAVE    = $8B
RowCount = $8C
ByteTmp  = $8D

IMAGE_ROWS = 19

; =============================================================================
; RESET — set the TIA and decompress the 96 bytes
; =============================================================================
    * = $F000
Reset:
    +clean_start
    LDA #$00
    STA COLUBK
    LDA #$0E
    STA COLUPF
    LDA #$01
    STA CTRLPF

    LDA #0
    STA PackIdx
    LDA #<Image
    STA ImgPtr
    LDA #>Image
    STA ImgPtr+1
    LDA #IMAGE_ROWS
    STA RowCount
NextRow:
    JSR DecodeRow
    LDA ImgPtr
    CLC
    ADC #3
    STA ImgPtr
    BCC +
    INC ImgPtr+1
+   DEC RowCount
    BNE NextRow

    JMP StartFrame

; -----------------------------------------------------------------------------
; DecodeRow — expand five packed bytes into one 3-byte playfield row
; -----------------------------------------------------------------------------
; The 20 pixels are numbered 0..19:
;   pixels 0-3   -> PF0 bits 4-7
;   pixels 4-11  -> PF1 bits 7-0
;   pixels 12-19 -> PF2 bits 0-7
; Every 2-bit codeword is looked up in Dict; a nonzero entry sets the bit.
DecodeRow:
    LDA #0
    STA RowBuf
    STA RowBuf+1
    STA RowBuf+2
    LDY #0
PixelLoop:
    TYA
    LSR
    LSR                       ; A = pixel / 4 = the source byte offset
    CLC
    ADC PackIdx
    TAX
    LDA Packed,X              ; four codewords in this byte
    STA ByteTmp
    STY YSAVE
    TYA
    AND #3                    ; which codeword?
    TAX
    LDA ShiftTable,X          ; 3, 2, 1 or 0 2-bit shifts
    TAX
    LDA ByteTmp
    BEQ CodewordReady         ; (a zero byte needs no shifting)
    CPX #0
    BEQ CodewordReady
ShiftLoop:
    LSR
    LSR
    DEX
    BNE ShiftLoop
CodewordReady:
    AND #3
    TAX
    LDA Dict,X
    BEQ NextPixel
    LDY YSAVE
    CPY #4
    BCC SetPF0
    CPY #12
    BCC SetPF1
    TYA
    SEC
    SBC #12
    TAX
    LDA PF2Bits,X
    ORA RowBuf+2
    STA RowBuf+2
    JMP NextPixel
SetPF1:
    TYA
    SEC
    SBC #4
    TAX
    LDA PF1Bits,X
    ORA RowBuf+1
    STA RowBuf+1
    JMP NextPixel
SetPF0:
    LDA PF0Bits,Y
    ORA RowBuf
    STA RowBuf
NextPixel:
    LDY YSAVE
    INY
    CPY #20
    BNE PixelLoop
    LDY #0
    LDA RowBuf
    STA (ImgPtr),Y
    INY
    LDA RowBuf+1
    STA (ImgPtr),Y
    INY
    LDA RowBuf+2
    STA (ImgPtr),Y
    LDA PackIdx
    CLC
    ADC #5
    STA PackIdx
    RTS

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:
    +vsync
VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
; The image pointer is set here, not after the status bar: the first image
; row's three stores must happen early enough for the beam to see them.
    LDA #<Image
    STA ImgPtr
    LDA #>Image
    STA ImgPtr+1
    +wait_timer
    LDA #$00
    STA VBLANK

BodyStart:
    ; 8 status lines: a full-width white bar
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    LDY #8
StatusLoop:
    STA WSYNC
    DEY
    BNE StatusLoop

    ; 19 decoded image rows (ImgPtr was set in VBLANK)
    LDX #IMAGE_ROWS
ImageLoop:
    LDY #0
    LDA (ImgPtr),Y
    STA PF0
    INY
    LDA (ImgPtr),Y
    STA PF1
    INY
    LDA (ImgPtr),Y
    STA PF2
    LDA ImgPtr
    CLC
    ADC #3
    STA ImgPtr
    BCC +
    INC ImgPtr+1
+   STA WSYNC
    DEX
    BNE ImageLoop

    ; the rest of the picture is blank
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #165
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

; =============================================================================
; THE DICTIONARY AND THE BIT TABLES
; =============================================================================
Dict:
    !byte 0, 1, 1, 0
ShiftTable:
    !byte 3, 2, 1, 0
PF0Bits:
    !byte $10, $20, $40, $80
PF1Bits:
    !byte $80, $40, $20, $10, $08, $04, $02, $01
PF2Bits:
    !byte $01, $02, $04, $08, $10, $20, $40, $80

; =============================================================================
; THE 96-BYTE PACKED PICTURE — 19 rows x 5 bytes, 2 bits per pixel
; =============================================================================
; Row r's five bytes hold 20 codewords.  The diamond's outline is codeword 1,
; its checkerboard core is codeword 2, and the background is 0.  The last byte
; pads the 95 used bytes to 96.
    !align 255, 0
Packed:
    !byte $00, $00, $10, $00, $00   ; row 0
    !byte $00, $00, $44, $00, $00   ; row 1
    !byte $00, $01, $21, $00, $00   ; row 2
    !byte $00, $04, $88, $40, $00   ; row 3
    !byte $00, $12, $22, $10, $00   ; row 4
    !byte $00, $48, $88, $84, $00   ; row 5
    !byte $01, $22, $22, $21, $00   ; row 6
    !byte $04, $88, $88, $88, $40   ; row 7
    !byte $12, $22, $22, $22, $10   ; row 8
    !byte $48, $88, $88, $88, $84   ; row 9
    !byte $12, $22, $22, $22, $10   ; row 10
    !byte $04, $88, $88, $88, $40   ; row 11
    !byte $01, $22, $22, $21, $00   ; row 12
    !byte $00, $48, $88, $84, $00   ; row 13
    !byte $00, $12, $22, $10, $00   ; row 14
    !byte $00, $04, $88, $40, $00   ; row 15
    !byte $00, $01, $21, $00, $00   ; row 16
    !byte $00, $00, $44, $00, $00   ; row 17
    !byte $00, $00, $10, $00, $00   ; row 18
    !byte $00                         ; pad to 96 bytes

    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset, Reset, Reset
