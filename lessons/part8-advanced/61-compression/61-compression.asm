; =============================================================================
; LESSON 61: Compression & Data Encoding — Fitting More in 4KB
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "the compressed logo": a 4,096-byte cartridge that stores a 192-row
;   playfield picture as a run-length-encoded stream and rebuilds one row at a
;   time while the beam is drawing the picture.  The raw picture is 576 bytes
;   (192 rows x 3 playfield bytes); the packed stream is 214 bytes, 37.2% of
;   the raw size.  A second stream (224 bytes) is the byte-count screen; SELECT
;   switches between them.
;
; The picture:
;   The playfield is reflected (CTRLPF = $01).  Each row is three bytes:
;     PF0  bits 4-7  the leftmost four playfield chunks
;     PF1  bits 7-0  the next eight chunks
;     PF2  bits 0-7  the last eight chunks (bit 0 is the leftmost)
;   A chunk is four color clocks wide, so the 20 playfield bits fill the left
;   half of the 160-pixel screen and the reflected playfield fills the right.
;   The logo screen is a bold "RTB" over a band of status text:
;     PK214   the packed stream length
;     RW576   the raw picture length
;     CK41    the checksum of the decoded 576 bytes
;   The status text is part of the picture, so it is part of the stream.  The
;   generator iterates until the numbers printed on screen are exactly the
;   numbers of the stream that carries them (a fixed point).
;
; The RLE format (one control byte per token):
;   bit 7 = 1  a run:  the low seven bits are count-1, the next byte is the
;              value, and the decoder repeats that value count times.
;   bit 7 = 0  literals: the low seven bits are count-1, and the next count
;              bytes are copied unchanged.
;   Counts are 1..128.  This encoder writes only counts that are multiples of
;   three, so every token ends exactly on a row boundary, and every token
;   covers at least two rows (count >= 6).  The generator enforces both rules;
;   the row-stepped decoder relies on them.
;
; The decoder:
;   A small state machine with a three-byte row buffer at $80-$82.  The
;   register X holds the remaining bytes of the current token minus one, Y is
;   the index into the stream, and $8A/$8B hold the run value and the mode.
;   The visible kernel displays the row in RowBuf and decodes the NEXT row
;   during the same scanline; the row buffer is overwritten only after the
;   three playfield writes, so the current line is already on the beam.
;   The worst path is the last row of a literal token, and it is exactly 76
;   cycles:
;     JMP into LoopLit                      3
;     LDA RowBuf / STA PF0                  6
;     LDA RowBuf+1 / STA PF1                6
;     LDA RowBuf+2 / STA PF2                6
;     LDA (DecodePtr),Y / STA RowBuf / INY 10
;     LDA (DecodePtr),Y / STA RowBuf+1 / INY 10
;     LDA (DecodePtr),Y / STA RowBuf+2 / INY 10
;     DEX DEX DEX                           6
;     BPL (not taken)                       2
;     DEC RowsLeft / BEQ (not taken)         7
;     LAX (DecodePtr),Y / INY               7
;     STA WSYNC                             3
;     total                                76
;   The WSYNC write lands on the last cycle of the line, so the line stays 76
;   cycles.  Every other path is shorter.  Measured STA WSYNC start cycles
;   (the line total is three cycles more):
;     literal continuation   67  (70)
;     literal token start    71  (74)
;     run continuation       49  (52)
;     run token start        71  (74)
;   The one-row token paths are at least two cycles over the line.  The
;   encoder never emits a one-row token, so they are safety code only.
;   Stella's state log confirms BodyStart 37/5 and OverscanStart 229/6.
;
;   The control prefetch at the end of a token uses the undocumented NMOS
;   instruction LAX (DecodePtr),Y ($B3): it loads A and X from the stream in
;   five cycles.  The documented LDA (DecodePtr),Y + TAX pair takes seven and
;   would push the worst line to 78 cycles, so the picture would grow a line.
;   Lesson 58 introduced LAX and the stable illegal opcodes; this lesson uses
;   the (zp),Y form, and the LAX_IND_Y macro below keeps the opcode byte
;   visible.
;
; Why the row buffer matters:
;   The 2600 has 128 bytes of RAM.  576 bytes of picture cannot be held there,
;   and the cartridge cannot spare 576 bytes for every screen.  The row buffer
;   is the whole trick: the picture exists in RAM only three bytes at a time,
;   and those three bytes are exactly what the TIA needs for one line.
;
; The checksum:
;   At startup a verification pass decodes each stream from its first byte to
;   its last, adds every decoded byte into an 8-bit sum, and stops when the
;   count reaches 576.  The kernel's own decode is the same stream; the sum is
;   the proof that the stream the screen is showing is the stream the table
;   says it is.  A host script (the doc shows the Python) produces the same
;   576 bytes and the same sum.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5, OverscanStart 229.
;   No player or missile is used, so there is no HMOVE in this kernel.
;
; The visible picture: 192 lines, one decoded row per line.
;
; Checkpoints (the state log's scanline/cycle and the A register):
;   StartFrame   the first VSYNC instruction
;   VblankStart  the first VBLANK instruction
;   BodyStart    the first visible line
;   OverscanStart the first overscan instruction
;   Screen       A = 0 (logo) or 1 (byte counts)
;   DecodePtrRead A = the stream's low byte
;   RowsLeftRead A = 191 (the rows the loop still has to draw)
;   RowByte0/1/2 A = the three row bytes at the playfield writes
;   DecodeCount  A/X = $02/$40 = 576 decoded bytes
;   Checksum     A = the logo stream's checksum ($41)
;   PackedLenRead A = 214 (logo) or 224 (stats), the active stream's length
;   RawLenRead   A = $40, the low byte of the 576-byte raw length
;   ChecksumRead A = $41 (logo) or $DB (stats), the active stream's sum
;
; RAM map (+clean_start zeroes every byte):
;   $80-$82  RowBuf       the three playfield bytes for the next line
;   $83-$84  DecodePtr    the active stream's 16-bit base address
;   $85      RowsLeft     rows left in the visible loop (191)
;   $86      PackedLen    the active stream's length in bytes
;   $87      RawLen       the low byte of the 576-byte raw length ($40)
;   $88      ChecksumVal  the active stream's decoded checksum
;   $89      ScreenNum    0 = logo screen, 1 = byte-count screen
;   $8A      RunValue     the value of the current run token
;   $8B      Mode         0 = literal row, 1 = run row
;   $8C      PrevSelect   the SELECT switch's previous state (debounce)
;   $8D-$8E  DecodeCnt    the verification pass's 16-bit byte counter
;   $8F      free
;   $90      SumLogo      the logo stream's checksum
;   $91      SumStats     the byte-count stream's checksum
;   $92      SumTmp       the verification pass's running sum
;   $93      PassValue    the verification pass's current byte
;   $94-$9F  free
;   $F8-$FF  stack
;
; Build: acme -f plain -o build/lesson61.bin \
;        lessons/part8-advanced/61-compression/61-compression.asm
; Run:   stella build/lesson61.bin
; The ROM is 4,096 bytes.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; -----------------------------------------------------------------------------
; LAX_IND_Y — the undocumented NMOS "load A and X" instruction, (zp),Y form
; -----------------------------------------------------------------------------
; ACME's !cpu 6502 does not accept the mnemonic, so the two opcode bytes are
; written out.  Lesson 58 introduced the stable illegal opcodes; this lesson
; uses LAX for one job: the control prefetch must put the next token's control
; byte in X in five cycles.  The documented LDA (ptr),Y + TAX pair needs seven,
; and that extra cycle pushes the last row of a literal token over the 76-cycle
; line.  $B3 is LAX (zp),Y: it loads A and X from the byte at (zp)+Y.
!macro LAX_IND_Y .zp {
    !byte $B3, .zp
}

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44          ; 37-line VBLANK (44 ticks)
OVERSCAN_TIMER = 36          ; 30-line overscan (1 + 35 x 64 cycles)
RAW_LEN        = 576         ; 192 rows x 3 playfield bytes
ROWS_LOOP      = 191         ; 191 loop rows + the pre-decoded row 0

; =============================================================================
; RAM ALLOCATION ($80-$9F; +clean_start zeroes every byte)
; =============================================================================
RowBuf      = $80            ; $80-$82
DecodePtr   = $83            ; $83-$84
RowsLeft    = $85
PackedLen   = $86
RawLen      = $87
ChecksumVal = $88
ScreenNum   = $89
RunValue    = $8A
Mode        = $8B
PrevSelect  = $8C
DecodeCnt   = $8D            ; $8D-$8E (verification pass only)
SumLogo     = $90
SumStats    = $91
SumTmp      = $92
PassValue   = $93

; =============================================================================
; RESET — the TIA setup and the two verification passes
; =============================================================================
    * = $F000

Reset:
    +clean_start             ; zero TIA and RAM, set SP = $FF

    LDA #$00
    STA COLUBK               ; black background
    LDA #$0E
    STA COLUPF               ; the picture is white
    LDA #$01
    STA CTRLPF               ; reflect the playfield
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA #$02
    STA VBLANK               ; blank the picture while the startup passes run

; -----------------------------------------------------------------------------
; The verification pass: decode each stream, add all 576 bytes into a sum
; -----------------------------------------------------------------------------
; This runs before the first frame.  The screen is blanked, so it may take as
; long as it needs.  It proves the stream is exactly 576 decoded bytes and it
; produces the checksum the status text carries.
    LDA #<LogoStream
    STA DecodePtr
    LDA #>LogoStream
    STA DecodePtr+1
    JSR VerifyStream
    STA SumLogo
Checksum:                    ; checkpoint: A = the logo stream's checksum $41
    LDA #<StatsStream
    STA DecodePtr
    LDA #>StatsStream
    STA DecodePtr+1
    JSR VerifyStream
    STA SumStats

; The first frame starts from the logo screen.
    LDA #$00
    STA ScreenNum
    LDA #ROWS_LOOP
    STA RowsLeft
    LDA #<RAW_LEN
    STA RawLen
    JMP StartFrame

; -----------------------------------------------------------------------------
; VerifyStream — decode 576 bytes and sum them
; -----------------------------------------------------------------------------
; In: DecodePtr = the stream's base.  Out: A = the 8-bit sum, DecodeCnt =
; $0240.  This is a separate, slow decoder: it has the whole frame to itself,
; so it can afford the simple byte-at-a-time form.  It stops at exactly 576
; bytes, which is the guarantee that the visible decoder will not read past
; the stream.
VerifyStream:
    LDY #0
    LDA #$00
    STA SumTmp
    STA DecodeCnt
    STA DecodeCnt+1
NextToken:
    LDA DecodeCnt            ; 576 = $0240: is the picture complete?
    CMP #$40
    BNE ReadToken
    LDA DecodeCnt+1
    CMP #$02
    BEQ PassDone
ReadToken:
    LDA (DecodePtr),Y        ; the control byte
    INY
    TAX                      ; TAX sets N from the control: bit 7 decides
    BMI RunToken
; --- literals: copy count bytes into the sum ---------------------------------
    INX                      ; X = count
LitAdd:
    LDA (DecodePtr),Y
    INY
    STA PassValue
    LDA SumTmp
    CLC
    ADC PassValue
    STA SumTmp
    INC DecodeCnt
    BNE +
    INC DecodeCnt+1
+   DEX
    BNE LitAdd
    JMP NextToken
; --- a run: the low seven bits are count-1, the next byte is the value --------
RunToken:
    TXA
    AND #$7F
    CLC
    ADC #1
    TAX                      ; X = count
    LDA (DecodePtr),Y        ; the run's value
    INY
    STA PassValue
RunAdd:
    LDA SumTmp
    CLC
    ADC PassValue
    STA SumTmp
    INC DecodeCnt
    BNE +
    INC DecodeCnt+1
+   DEX
    BNE RunAdd
    JMP NextToken
PassDone:
    LDX DecodeCnt            ; X = $40
    LDA DecodeCnt+1          ; A = $02
DecodeCount:                 ; checkpoint: A/X = $02/$40 = 576 bytes
    LDA SumTmp
    RTS

; -----------------------------------------------------------------------------
; PreDecode — fill RowBuf with row 0 and set X and Mode
; -----------------------------------------------------------------------------
; In: DecodePtr = the stream's base, Y = 0.  Out: RowBuf = row 0, X = the
; token's count-1 minus 3 (the row's three bytes are already consumed), and
; Mode = 0 for a literal token or 1 for a run token.  The visible loop's first
; step continues from here.
PreDecode:
    LDA (DecodePtr),Y
    INY
    TAX
    BMI PreRun
    LDA (DecodePtr),Y
    STA RowBuf
    INY
    LDA (DecodePtr),Y
    STA RowBuf+1
    INY
    LDA (DecodePtr),Y
    STA RowBuf+2
    INY
    DEX
    DEX
    DEX
    LDA #0
    STA Mode
    RTS
PreRun:
    AND #$7F
    TAX
    LDA (DecodePtr),Y
    STA RunValue
    INY
    LDA RunValue
    STA RowBuf
    STA RowBuf+1
    STA RowBuf+2
    DEX
    DEX
    DEX
    LDA #1
    STA Mode
    RTS

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                  ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                 ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK               ; blank the picture
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; SELECT — one step per press, not one per frame
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  PrevSelect remembers the previous
; frame so a held switch toggles the screen once.
    LDA SWCHB
    AND #$02
    BEQ SelectDown
    LDA #$00
    STA PrevSelect
    JMP SelectDone
SelectDown:
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA ScreenNum
    EOR #$01
    STA ScreenNum
SelectDone:

; -----------------------------------------------------------------------------
; Choose the active stream and set the decoder's starting state
; -----------------------------------------------------------------------------
    LDA ScreenNum
Screen:                      ; checkpoint: A = 0 (logo) or 1 (byte counts)
    BNE UseStats

; --- the logo screen ---------------------------------------------------------
    LDA #<LogoStream
    STA DecodePtr
    LDA #>LogoStream
    STA DecodePtr+1
    LDA #LogoPacked
    STA PackedLen
    LDA SumLogo
    STA ChecksumVal
    JMP StreamReady

; --- the byte-count screen ---------------------------------------------------
UseStats:
    LDA #<StatsStream
    STA DecodePtr
    LDA #>StatsStream
    STA DecodePtr+1
    LDA #StatsPacked
    STA PackedLen
    LDA SumStats
    STA ChecksumVal

StreamReady:
    LDA #<RAW_LEN
    STA RawLen
    LDY #0
    LDA #ROWS_LOOP
    STA RowsLeft
    LDA DecodePtr
DecodePtrRead:                   ; checkpoint: A = the stream's low byte
    JSR PreDecode
    LDA RowsLeft
RowsLeftRead:                    ; checkpoint: A = 191 rows still to draw
    LDA PackedLen
PackedLenRead:                   ; checkpoint: A = 214 (logo) or 224 (stats)
    LDA RawLen
RawLenRead:                      ; checkpoint: A = $40 (the low byte of 576)
    LDA ChecksumVal
ChecksumRead:                    ; checkpoint: A = $41 (logo) or $DB (stats)
    NOP                          ; the label must name a non-polling instruction

    +wait_timer
    LDA #$00
    STA VBLANK               ; picture on

; =============================================================================
; THE VISIBLE KERNEL — 192 lines, one decoded row per line
; =============================================================================
; At the top of every line the row in RowBuf is written to PF0/PF1/PF2.  Then
; the decoder rebuilds the NEXT row in RowBuf.  The writes happen first, so the
; line already on the beam keeps its picture while the buffer is overwritten.
BodyStart:                   ; checkpoint: scanline 37, visible line 0
    LDA Mode
    BNE LoopRun

; -----------------------------------------------------------------------------
; LoopLit — display one row and decode three literal bytes
; -----------------------------------------------------------------------------
LoopLit:
    LDA RowBuf
    STA PF0
    LDA RowBuf+1
RowByte1:                    ; checkpoint: A = the second row byte
    STA PF1
    LDA RowBuf+2
RowByte2:                    ; checkpoint: A = the third row byte
    STA PF2
    LDA (DecodePtr),Y
    STA RowBuf
    INY
    LDA (DecodePtr),Y
    STA RowBuf+1
    INY
    LDA (DecodePtr),Y
    STA RowBuf+2
    INY
    DEX
    DEX
    DEX
    BPL ContLit
; --- the token ended: prefetch the next control byte -------------------------
    DEC RowsLeft
    BEQ LastTramp1
Prefetch1:
    +LAX_IND_Y DecodePtr
    INY
    STA WSYNC
    JMP TokenStart
ContLit:
    DEC RowsLeft
    BEQ LastTramp1
    STA WSYNC
    JMP LoopLit
LastTramp1:
    STA WSYNC
    JMP LastRow

; -----------------------------------------------------------------------------
; LoopRun — display one row and repeat the run's value
; -----------------------------------------------------------------------------
LoopRun:
    LDA RowBuf
RowByte0:                    ; checkpoint: A = the first row byte
    STA PF0
    LDA RowBuf+1
    STA PF1
    LDA RowBuf+2
    STA PF2
    LDA RunValue
    STA RowBuf
    STA RowBuf+1
    STA RowBuf+2
    DEX
    DEX
    DEX
    BPL ContRun
    DEC RowsLeft
    BEQ LastTramp2
Prefetch2:
    +LAX_IND_Y DecodePtr
    INY
    STA WSYNC
    JMP TokenStart
ContRun:
    DEC RowsLeft
    BEQ LastTramp2
    STA WSYNC
    JMP LoopRun
LastTramp2:
    STA WSYNC
    JMP LastRow

; -----------------------------------------------------------------------------
; TokenStart — display one row and decode the first row of a new token
; -----------------------------------------------------------------------------
; X holds the prefetched control byte.  Bit 7 selects run or literal; for a
; literal the low seven bits are already count-1, so X is ready.
TokenStart:
    LDA RowBuf
    STA PF0
    LDA RowBuf+1
    STA PF1
    LDA RowBuf+2
    STA PF2
    TXA
    BMI RunStart
    LDA (DecodePtr),Y
    STA RowBuf
    INY
    LDA (DecodePtr),Y
    STA RowBuf+1
    INY
    LDA (DecodePtr),Y
    STA RowBuf+2
    INY
    DEX
    DEX
    DEX
    BPL TokCont
; --- a one-row token (not produced by this encoder) -------------------------
    DEC RowsLeft
    BEQ LastTramp3
Prefetch3:
    +LAX_IND_Y DecodePtr
    INY
    STA WSYNC
    JMP TokenStart
TokCont:
    DEC RowsLeft
    BEQ LastTramp3
    STA WSYNC
    JMP LoopLit
LastTramp3:
    STA WSYNC
    JMP LastRow

; -----------------------------------------------------------------------------
; RunStart — decode the first row of a run token
; -----------------------------------------------------------------------------
RunStart:
    TXA
    AND #$7F
    TAX
    LDA (DecodePtr),Y
    STA RunValue
    INY
    LDA RunValue
    STA RowBuf
    STA RowBuf+1
    STA RowBuf+2
    DEX
    DEX
    DEX
    BPL RunCont
    DEC RowsLeft
    BEQ LastTramp4
Prefetch4:
    +LAX_IND_Y DecodePtr
    INY
    STA WSYNC
    JMP TokenStart
RunCont:
    DEC RowsLeft
    BEQ LastTramp4
    STA WSYNC
    JMP LoopRun
LastTramp4:
    STA WSYNC
    JMP LastRow

; -----------------------------------------------------------------------------
; LastRow — the 192nd visible line: display the final row and stop decoding
; -----------------------------------------------------------------------------
LastRow:
    LDA RowBuf
    STA PF0
    LDA RowBuf+1
    STA PF1
    LDA RowBuf+2
    STA PF2
    STA WSYNC
    NOP                      ; the Part 7/8 skeleton enters the overscan six
    NOP                      ; cycles into line 229
    NOP

; =============================================================================
; OVERSCAN — 30 lines, then the next frame
; =============================================================================
OverscanStart:               ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; THE STREAMS
; =============================================================================
; Each stream is page-aligned and smaller than 256 bytes.  That keeps every
; (DecodePtr),Y accesses stay inside one page: no index ever crosses
; a page boundary, so no load costs an extra cycle.
    !align 255, 0
LogoStream:
    !byte $88, $FF        ; run  x  9 $FF  rows   0-  2
    !byte $88, $00        ; run  x  9 $00  rows   3-  5
    !byte $8B, $FF        ; run  x 12 $FF  rows   6-  9
    !byte $88, $00        ; run  x  9 $00  rows  10- 12
    !byte $85, $FF        ; run  x  6 $FF  rows  13- 14
    !byte $88, $00        ; run  x  9 $00  rows  15- 17
    !byte $91, $FF        ; run  x 18 $FF  rows  18- 23
    !byte $8B, $00        ; run  x 12 $00  rows  24- 27
    !byte $29                      ; lit  x 42       rows  28- 41
    !byte $80, $CF, $0E, $80, $CF, $0E, $80, $24
    !byte $12, $80, $24, $12, $80, $24, $12, $80
    !byte $24, $12, $80, $C4, $0E, $80, $C4, $0E
    !byte $80, $44, $12, $80, $44, $12, $80, $24
    !byte $12, $80, $24, $12, $80, $24, $0E, $80
    !byte $24, $0E
    !byte $8B, $00        ; run  x 12 $00  rows  42- 45
    !byte $85, $FF        ; run  x  6 $FF  rows  46- 47
    !byte $8B, $00        ; run  x 12 $00  rows  48- 51
    !byte $8B, $FF        ; run  x 12 $FF  rows  52- 55
    !byte $88, $00        ; run  x  9 $00  rows  56- 58
    !byte $85, $FF        ; run  x  6 $FF  rows  59- 60
    !byte $88, $00        ; run  x  9 $00  rows  61- 63
    !byte $91, $FF        ; run  x 18 $FF  rows  64- 69
    !byte $8B, $00        ; run  x 12 $00  rows  70- 73
    !byte $85, $FF        ; run  x  6 $FF  rows  74- 75
    !byte $91, $00        ; run  x 18 $00  rows  76- 81
    !byte $1D                      ; lit  x 30       rows  82- 91
    !byte $70, $AE, $52, $70, $AE, $52, $50, $A2
    !byte $52, $50, $A2, $52, $70, $CE, $72, $70
    !byte $CE, $72, $10, $A8, $42, $10, $A8, $42
    !byte $10, $AE, $42, $10, $AE, $42
    !byte $8B, $00        ; run  x 12 $00  rows  92- 95
    !byte $1D                      ; lit  x 30       rows  96-105
    !byte $70, $AE, $77, $70, $AE, $77, $50, $A8
    !byte $14, $50, $A8, $14, $70, $EE, $74, $70
    !byte $EE, $74, $30, $E2, $54, $30, $E2, $54
    !byte $50, $AE, $74, $50, $AE, $74
    !byte $8B, $00        ; run  x 12 $00  rows 106-109
    !byte $1D                      ; lit  x 30       rows 110-119
    !byte $70, $AA, $02, $70, $AA, $02, $10, $AA
    !byte $02, $10, $AA, $02, $10, $CE, $02, $10
    !byte $CE, $02, $10, $A2, $02, $10, $A2, $02
    !byte $70, $A2, $02, $70, $A2, $02
    !byte $91, $00        ; run  x 18 $00  rows 120-125
    !byte $85, $FF        ; run  x  6 $FF  rows 126-127
    !byte $8E, $00        ; run  x 15 $00  rows 128-132
    !byte $8B, $FF        ; run  x 12 $FF  rows 133-136
    !byte $88, $00        ; run  x  9 $00  rows 137-139
    !byte $85, $FF        ; run  x  6 $FF  rows 140-141
    !byte $8E, $00        ; run  x 15 $00  rows 142-146
    !byte $91, $FF        ; run  x 18 $FF  rows 147-152
    !byte $8B, $00        ; run  x 12 $00  rows 153-156
    !byte $85, $FF        ; run  x  6 $FF  rows 157-158
    !byte $8E, $00        ; run  x 15 $00  rows 159-163
    !byte $8B, $FF        ; run  x 12 $FF  rows 164-167
    !byte $88, $00        ; run  x  9 $00  rows 168-170
    !byte $85, $FF        ; run  x  6 $FF  rows 171-172
    !byte $8E, $00        ; run  x 15 $00  rows 173-177
    !byte $91, $FF        ; run  x 18 $FF  rows 178-183
    !byte $85, $00        ; run  x  6 $00  rows 184-185
    !byte $91, $FF        ; run  x 18 $FF  rows 186-191
LogoPacked = * - LogoStream

; The assembler can pin the packed length, and does.  It cannot sum the
; decoded bytes without running the decoder, so the checksum is guarded by the
; startup pass and the host decode instead: a changed decoded sum with an
; unchanged length fails those checks, not the assembler.
    !if LogoPacked != 214 {
        !error "LogoPacked changed: update the PK214 status rows and the fixed point"
    }
    !if LogoPacked > 256 {
        !error "the logo stream must stay inside one page"
    }

    !align 255, 0
StatsStream:
    !byte $88, $FF        ; run  x  9 $FF  rows   0-  2
    !byte $94, $00        ; run  x 21 $00  rows   3-  9
    !byte $2C                      ; lit  x 45       rows  10- 24
    !byte $00, $E8, $07, $00, $E8, $07, $00, $E8
    !byte $07, $00, $A8, $01, $00, $A8, $01, $00
    !byte $A8, $01, $00, $E8, $07, $00, $E8, $07
    !byte $00, $E8, $07, $00, $C8, $01, $00, $C8
    !byte $01, $00, $C8, $01, $00, $AE, $07, $00
    !byte $AE, $07, $00, $AE, $07
    !byte $88, $00        ; run  x  9 $00  rows  25- 27
    !byte $85, $FF        ; run  x  6 $FF  rows  28- 29
    !byte $91, $00        ; run  x 18 $00  rows  30- 35
    !byte $2C                      ; lit  x 45       rows  36- 50
    !byte $00, $EE, $07, $00, $EE, $07, $00, $EE
    !byte $07, $00, $82, $01, $00, $82, $01, $00
    !byte $82, $01, $00, $E2, $07, $00, $E2, $07
    !byte $00, $E2, $07, $00, $22, $05, $00, $22
    !byte $05, $00, $22, $05, $00, $E2, $07, $00
    !byte $E2, $07, $00, $E2, $07
    !byte $88, $00        ; run  x  9 $00  rows  51- 53
    !byte $85, $FF        ; run  x  6 $FF  rows  54- 55
    !byte $97, $00        ; run  x 24 $00  rows  56- 63
    !byte $1D                      ; lit  x 30       rows  64- 73
    !byte $70, $AE, $57, $70, $AE, $57, $50, $A2
    !byte $54, $50, $A2, $54, $70, $CE, $77, $70
    !byte $CE, $77, $10, $A8, $41, $10, $A8, $41
    !byte $10, $AE, $47, $10, $AE, $47
    !byte $8B, $00        ; run  x 12 $00  rows  74- 77
    !byte $1D                      ; lit  x 30       rows  78- 87
    !byte $70, $AC, $07, $70, $AC, $07, $10, $AA
    !byte $05, $10, $AA, $05, $10, $CA, $03, $10
    !byte $CA, $03, $10, $AA, $05, $10, $AA, $05
    !byte $70, $AC, $07, $70, $AC, $07
    !byte $91, $00        ; run  x 18 $00  rows  88- 93
    !byte $8B, $FF        ; run  x 12 $FF  rows  94- 97
    !byte $88, $00        ; run  x  9 $00  rows  98-100
    !byte $85, $FF        ; run  x  6 $FF  rows 101-102
    !byte $8E, $00        ; run  x 15 $00  rows 103-107
    !byte $91, $FF        ; run  x 18 $FF  rows 108-113
    !byte $8B, $00        ; run  x 12 $00  rows 114-117
    !byte $85, $FF        ; run  x  6 $FF  rows 118-119
    !byte $8E, $00        ; run  x 15 $00  rows 120-124
    !byte $8B, $FF        ; run  x 12 $FF  rows 125-128
    !byte $88, $00        ; run  x  9 $00  rows 129-131
    !byte $85, $FF        ; run  x  6 $FF  rows 132-133
    !byte $8E, $00        ; run  x 15 $00  rows 134-138
    !byte $91, $FF        ; run  x 18 $FF  rows 139-144
    !byte $8B, $00        ; run  x 12 $00  rows 145-148
    !byte $85, $FF        ; run  x  6 $FF  rows 149-150
    !byte $8E, $00        ; run  x 15 $00  rows 151-155
    !byte $8B, $FF        ; run  x 12 $FF  rows 156-159
    !byte $88, $00        ; run  x  9 $00  rows 160-162
    !byte $85, $FF        ; run  x  6 $FF  rows 163-164
    !byte $8E, $00        ; run  x 15 $00  rows 165-169
    !byte $91, $FF        ; run  x 18 $FF  rows 170-175
    !byte $8B, $00        ; run  x 12 $00  rows 176-179
    !byte $85, $FF        ; run  x  6 $FF  rows 180-181
    !byte $8B, $00        ; run  x 12 $00  rows 182-185
    !byte $91, $FF        ; run  x 18 $FF  rows 186-191
StatsPacked = * - StatsStream

    !if StatsPacked != 224 {
        !error "StatsPacked changed: update the PK224 status rows and the fixed point"
    }
    !if StatsPacked > 256 {
        !error "the byte-count stream must stay inside one page"
    }

    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset, Reset, Reset
