; =============================================================================
; LESSON 57 — EXERCISE 1 SOLUTION: Fill All 128 Bytes — Racing the Beam
; =============================================================================
; Part 8: Advanced Topics
;
; EXERCISE 1: fill all 128 Superchip bytes with a pattern and light all 16
;   gauge cells.
;
;   The init loop writes X EOR $A5 to $1000+X for X = 0..127, then reads each
;   byte back through $1080+X and compares it.  If every byte matches, it
;   writes $FF to GaugeHi and GaugeLo, so the 16-cell gauge in the status band
;   is completely lit.  A mismatch sets FillFailFlag ($AD), clears both gauge
;   bytes, and the periodic update checks the flag before it ORs a cell, so a
;   failed fill leaves the gauge empty permanently.  The display is the test
;   result.
;
;   The rest of the demo is the lesson's notebook: the 32-byte message still
;   scrolls through the six-character window, one character every eight
;   frames, and the marker still sweeps.  The gauge stays full because every
;   cell was written during the init fill.
;
; The F8SC layout, entry stub, signature, RAM windows, frame skeleton and
; RAM map are the lesson's; this file changes only the init (the fill) and
; adds the FillRead/FillDone checkpoints.
;
; Checkpoints: StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   OverscanStart (229/6), Frame (A = the frame count);
;   FillRead (A = each byte read back), FillDone (A = $FF when all match);
;   FillFailFlag ($AD) = $01 on a mismatch, 0 on success;
;   RamWrite/RamRead/RamPtr/Writes/Reads (the lesson's periodic update).
;
; Build: acme -f plain -o build/exercise-01.bin \
;        lessons/part8-advanced/57-superchip/exercise-01-solution.asm
; Run:   stella build/exercise-01.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan
POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

SCREEN_LINES   = 192     ; every frame draws 192 visible lines
STATUS_LINES   = 8       ; the SC label and gauge band
TEXT_ROWS      = 7       ; seven rows per three-character line
TEXT_LINES     = 14      ; two lines of three characters
PLAY_LINES     = 184     ; 192 - 8 status lines
MARKER_TOP     = 152     ; the marker's first play row
MARKER_X_BASE  = 24      ; the sweep's left edge, TIA X 24..87

C_BG           = $00     ; black notebook page
C_STATUS       = $C8     ; green SC label and gauge
C_TEXT         = $0E     ; white message
C_MARK         = $1A     ; gold marker

GAUGE_CELLS    = 16      ; 16 groups of eight bytes = 128
RAM_BYTES      = 128     ; the Superchip's full RAM

; The frame arithmetic is a build-time assertion, not a comment.
!if STATUS_LINES + PLAY_LINES != SCREEN_LINES {
    !error "the status band plus the play area must total 192 lines"
}
!if MARKER_TOP + 8 > PLAY_LINES {
    !error "the marker strip must fit inside the play area"
}
!if GAUGE_CELLS * 8 != RAM_BYTES {
    !error "the 16 gauge cells must cover the 128 RAM bytes"
}

; =============================================================================
; RAM ALLOCATION ($80-$AD; +clean_start zeroes every byte)
; =============================================================================
; The checkpoint labels RamPtr, Writes and Reads cannot share a name with a
; variable, so the variables carry role names and the checkpoints keep the
; names the lesson documents.
WritePtr    = $80    ; the Superchip write pointer, 0..127
MessagePtr  = $81    ; the message index, 0..31
FrameCount  = $82    ; frames since reset, wraps at 256
WriteCount  = $83    ; the number of Superchip writes
ReadCount   = $84    ; the number of Superchip reads
GaugeLo     = $85    ; gauge cells 8-15, cell 8 in bit 0
GaugeHi     = $86    ; gauge cells 0-7, cell 0 in bit 7
Window      = $87    ; six glyph indices, oldest at Window+0

; The display bitmap: two lines of three characters.  A line uses PF0 for its
; first character (chunks 0-3) and PF1 for its second and third (chunks 4-7
; and 8-11).  Rows 0-6 are line A (the older three characters); rows 7-13 are
; line B (the newer three).
MsgPF0      = $8D    ; fourteen PF0 bytes: line A rows 0-6, line B rows 0-6
MsgPF1      = $9B    ; fourteen PF1 bytes: line A rows 0-6, line B rows 0-6

Tmp0        = $A9    ; bitmap packing scratch
Scratch     = $AA    ; a glyph row byte, then the new glyph
FontPtr     = $AB    ; the current font row's base (zero page, two bytes)
FillFailFlag = $AD   ; 1 = a fill mismatch: the gauge stays empty

; $AE-$D7 are free.  The stack lives at $F8-$FF; the call depth is one level
; (SetCoarseP0, Update, BuildBitmap, AsciiToGlyph).

; =============================================================================
; BANK 0 — real $E000, virtual $F000.  THE RESET-ONLY BANK.
; =============================================================================
; The flat ROM starts here.  Bank 0 is not used by the demo; it exists so that
; a console reset while bank 0 is selected still finds a valid vector and a
; stub that selects bank 1.  Its first 256 bytes are the F8SC signature.
    * = $E000
    !pseudopc $F000 {

; -----------------------------------------------------------------------------
; The signature — 128 bytes duplicated at +128
; -----------------------------------------------------------------------------
; $F000-$F07F is the write window and $F080-$F0FF is the read window when the
; CPU runs; the file bytes here are what the emulator's auto-detect reads.
; The two halves must be identical, or Stella selects plain F8.
    !fill 128, $EA
    !fill 128, $EA

; -----------------------------------------------------------------------------
; Bank 0's entry — the same six bytes as bank 1's entry
; -----------------------------------------------------------------------------
    * = $F100
Bank0Entry:
    LDA $1FF9               ; select bank 1 (the hotspot read)
    JMP $F106               ; the JMP is fetched from bank 1 at $F103
                            ; $F106 is bank 1's init, right after the stub

; Bank 0 has no code after the stub.  The fill is $EA (NOP) so an accidental
; fetch is harmless; the vectors below are the only bytes that matter.
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Bank0Entry, Bank0Entry, Bank0Entry
}

; =============================================================================
; BANK 1 — real $F000, virtual $F000.  THE NOTEBOOK.
; =============================================================================
; This is the start bank: F8SC extends F8, and F8 selects bank 1 at power-on.
; Its reset vector at $FFFC is the one the CPU uses, so bank 1's entry at
; $F100 is the first instruction that runs.
    * = $F000
    !pseudopc $F000 {

; -----------------------------------------------------------------------------
; The signature — the same duplicated 128 bytes as bank 0
; -----------------------------------------------------------------------------
    !fill 128, $EA
    !fill 128, $EA

; -----------------------------------------------------------------------------
; Entry — the six-byte stub at $F100
; -----------------------------------------------------------------------------
; The bank-0 reset and the bank-1 reset both arrive here.  LDA $1FF9 selects
; bank 1; the JMP opcode at $F103 is then fetched from bank 1.  The target
; $F106 is the first byte after the six-byte stub: a JMP to $F100 would
; re-enter the stub and loop forever.
    * = $F100
Entry:
    LDA $1FF9               ; select bank 1
    JMP $F106               ; continue at Init, after the six-byte stub

; -----------------------------------------------------------------------------
; Init — the power-on setup ($F106)
; -----------------------------------------------------------------------------
Init:
    +clean_start            ; zero TIA and RIOT RAM, set the stack to $FF
    LDA #$00
    STA SWACNT              ; port A is an input port (the joystick)

; --- the Superchip RAM is NOT zeroed by the console --------------------------
; A real 128-byte SRAM powers up in an unknown state.  Write all 128 bytes
; explicitly, through the write window.  This is also the first proof that the
; window is live: the read window below would return the written zeros.
    LDX #0
    LDA #$00
InitRam:
    STA $1000,X             ; write byte X through the write window
    INX
    CPX #RAM_BYTES
    BNE InitRam

; --- the named variables (clean_start already zeroed them) -------------------
    LDA #$00
    STA WritePtr
    STA MessagePtr
    STA FrameCount
    STA WriteCount
    STA ReadCount
    STA GaugeLo
    STA GaugeHi
    STA FillFailFlag

; --- the window starts with six spaces, not six glyph 0s --------------------
; The bitmap is blank until the first update, but the window bytes must also
; be spaces: a zero byte is glyph 0 ('A'), and the first shift would otherwise
; drag five 'A's into the picture.
    LDX #0
    LDA #36                 ; glyph 36 is the space
InitWindow:
    STA Window,X
    INX
    CPX #6
    BNE InitWindow

; --- exercise 1: fill all 128 bytes and light all 16 gauge cells -------------
; The pattern X EOR $A5 makes every byte different, so a read-back that is
; stuck at one value cannot pass.  X is the address and the pattern's high
; byte; Scratch holds the expected value across the read.
    LDX #0
FillLoop:
    TXA
    EOR #$A5
    STA Scratch             ; the expected byte
    STA $1000,X             ; the write window
    LDA $1080,X             ; the read window
FillRead:                   ; checkpoint: A = the byte read back
    CMP Scratch
    BNE FillFail
    INX
    CPX #RAM_BYTES
    BNE FillLoop
    LDA #$FF
    STA GaugeLo
    STA GaugeHi
    LDA GaugeHi
FillDone:                   ; checkpoint: A = $FF, all 16 cells lit
    JMP InitDone
FillFail:
    LDA #$01
    STA FillFailFlag        ; lock the gauge empty
    LDA #$00
    STA GaugeLo
    STA GaugeHi
    LDA GaugeHi
    JMP InitDone
InitDone:

; --- the TIA's fixed state ---------------------------------------------------
    LDA #C_BG
    STA COLUBK              ; black page
    LDA #C_STATUS
    STA COLUPF              ; green until the message band
    LDA #C_MARK
    STA COLUP0              ; the marker
    LDA #$01
    STA CTRLPF              ; reflect the playfield: the pattern doubles
    LDA #$00
    STA NUSIZ0              ; one copy of P0
    STA GRP0
    STA PF0
    STA PF1
    STA PF2

    JMP StartFrame

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK              ; blank the picture
    +set_timer VBLANK_TIMER

; --- the status band's colours ----------------------------------------------
; The status band is green; the message band switches to white below.
    LDA #C_STATUS
    STA COLUPF
    LDA #C_MARK
    STA COLUP0

; --- the frame counter and the eight-frame update clock ----------------------
    INC FrameCount
    LDA FrameCount
Frame:                      ; checkpoint: A = the new frame count
    AND #$07
    BNE NoUpdate
    JSR Update
NoUpdate:

; --- the marker's X: 24 + (FrameCount & 63), one divide-by-15 dance ----------
    LDA FrameCount
    AND #$3F
    CLC
    ADC #(MARKER_X_BASE + POS_BIAS)
    JSR SetCoarseP0         ; sets HMP0 and strobes RESP0
    STA WSYNC
    STA HMOVE               ; the frame's only HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; THE VISIBLE KERNEL — 192 lines
; =============================================================================

; --- 8 status lines: the SC label and the 16-cell gauge ----------------------
; PF0 draws "SC" in chunks 0-3 (two 2-chunk letters).  PF1 draws gauge cells
; 0-7 and PF2 draws cells 8-15.  Reflection mirrors the whole status band, so
; the reader sees the label at both edges and the gauge on both sides.
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDY #0
StatusRow:
    LDA ScRow,Y
    STA PF0                 ; the SC label
    LDA GaugeHi
    STA PF1                 ; cells 0-7
    LDA GaugeLo
    STA PF2                 ; cells 8-15
    STA WSYNC
    INY
    CPY #7
    BNE StatusRow

; Row 7 is a solid separator in all 20 chunks.
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    STA WSYNC

; --- 14 play lines: two lines of three characters ----------------------------
; The bitmap is rebuilt every eight frames, so these fourteen lines are a
; simple table read.  Line A is the older three characters (top), line B the
; newer three (bottom).  COLUPF changes to white after the separator's line
; has been drawn; the first text row's PF0 store follows at cycle 14.
    LDA #C_TEXT
    STA COLUPF
    LDY #0
TextRow:
    LDA MsgPF0,Y
    STA PF0
    LDA MsgPF1,Y
    STA PF1
    LDA #$00
    STA PF2
    STA GRP0
    STA WSYNC
    INY
    CPY #TEXT_LINES
    BNE TextRow

; --- the rest of the play area: background and the marker --------------------
; The playfield is already zero; the TIA holds it for the remaining 170
; lines.  GRP0 comes from the 184-byte strip, one byte per line.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
PlayRow:
    LDA MarkerStrip,Y
    STA GRP0
    STA WSYNC
    INY
    CPY #PLAY_LINES
    BNE PlayRow

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; Update — one Superchip write and read, every eight frames
; =============================================================================
; The message index selects an ASCII byte; the write pointer selects one of
; the 128 RAM bytes.  The write goes through $1000+X, the read comes back
; through $1080+X.  The same read byte then drives the display: the new glyph
; shifts into the six-character window and the gauge lights the byte's group.
Update:
; --- the message byte and the write ------------------------------------------
    LDX MessagePtr
    LDA Message,X           ; the next ASCII character
    LDX WritePtr            ; X = 0..127
    STA $1000,X             ; the write window
RamWrite:                   ; checkpoint: A = the byte written, X = RamPtr
; --- the read-back ------------------------------------------------------------
    LDA $1080,X             ; the read window
RamRead:                    ; checkpoint: A = the byte read back

; --- the byte becomes a glyph -------------------------------------------------
    JSR AsciiToGlyph
    STA Scratch             ; the new glyph index (0..36)

; --- shift the six-glyph window left and append the new glyph ----------------
    LDX #0
ShiftWindow:
    LDA Window+1,X
    STA Window,X
    INX
    CPX #5
    BNE ShiftWindow
    LDA Scratch
    STA Window+5

; --- light the gauge cell of the byte just written ---------------------------
; Cell c is bytes 8c..8c+7.  Cells 0-7 live in GaugeHi (cell 0 in bit 7),
; cells 8-15 in GaugeLo (cell 8 in bit 0).  A cell stays lit once any of its
; eight bytes has been written, so the mask is ORed, never cleared.
; A failed fill sets FillFailFlag: skip the OR so the gauge stays empty.
    LDA FillFailFlag
    BNE GaugeDone
    LDA WritePtr
    LSR
    LSR
    LSR                     ; cell = WritePtr >> 3, 0..15
    TAX
    CPX #8
    BCS HighCell
    LDA CellBitHi,X          ; $80 >> cell
    ORA GaugeHi
    STA GaugeHi
    JMP GaugeDone
HighCell:
    LDA CellBitLo-8,X        ; x = 8..15, table index 0..7
    ORA GaugeLo
    STA GaugeLo
GaugeDone:

; --- advance the write pointer, 0..127 ---------------------------------------
    INC WritePtr
    LDA WritePtr
    CMP #RAM_BYTES
    BCC WritePtrDone
    LDA #$00
    STA WritePtr
WritePtrDone:
    LDA WritePtr
RamPtr:                     ; checkpoint: A = the new write pointer

; --- advance the message pointer, 0..31 --------------------------------------
    INC MessagePtr
    LDA MessagePtr
    AND #$1F
    STA MessagePtr
MsgPtr:                     ; checkpoint: A = the new message pointer

; --- count the operations -----------------------------------------------------
    INC WriteCount
    LDA WriteCount
Writes:                     ; checkpoint: A = the write count
    INC ReadCount
    LDA ReadCount
Reads:                      ; checkpoint: A = the read count

; --- rebuild the 7 x 3 playfield bitmap from the window ----------------------
    JMP BuildBitmap         ; tail call: BuildBitmap returns to the caller

; =============================================================================
; AsciiToGlyph — map ' ', '0'-'9', and 'A'-'Z' to the font's 37 glyphs
; =============================================================================
; The font order is A-Z (0-25), 0-9 (26-35), space (36).  The message only
; contains those characters, so no other case is needed.
AsciiToGlyph:
    CMP #$20                ; space
    BEQ GlyphSpace
    CMP #$30                ; below '0' is not used
    BCC GlyphLetter
    CMP #$3A                ; above '9' falls through to the letter path
    BCS GlyphLetter
    SEC
    SBC #$16                ; '0' ($30) - 26 = $16: A = digit + 26
    RTS
GlyphLetter:
    SEC
    SBC #$41                ; 'A' ($41): A = 0..25
    RTS
GlyphSpace:
    LDA #36
    RTS

; =============================================================================
; BuildBitmap — turn six glyphs into two lines of PF0/PF1 pairs
; =============================================================================
; Each glyph is four chunks wide.  Line A (the older three characters) is
; written to bitmap rows 0-6; line B (the newer three) to rows 7-13.  In a
; row, character 0 is PF0 bits 7-4 (chunks 0-3), character 1 is PF1 bits 7-4
; (chunks 4-7), and character 2 is PF1 bits 3-0 (chunks 8-11).  PF2 stays
; zero.  The reflection draws the mirrored copy on the right half.
;
; The six glyphs are read from FontRow0..FontRow6 through FontPtr; each row
; is 37 bytes, one per glyph, so the pointer advances by 37 after each row.
BuildBitmap:
    LDA #<FontRow0
    STA FontPtr
    LDA #>FontRow0
    STA FontPtr+1
    LDX #0                  ; X = the glyph row, 0..6
BuildRow:
; --- line A: characters 0, 1, 2 ----------------------------------------------
; The font nibble has bit 3 = the leftmost chunk.  PF0's high nibble runs
; bit 4 (left) to bit 7 (right), so character 0's nibble is reversed before
; it moves up; PF1's high nibble runs bit 7 (left) to bit 4 (right) and its
; low nibble runs bit 3 (left) to bit 0 (right), so characters 1 and 2 need
; no reversal.
    LDY Window+0
    LDA (FontPtr),Y
    AND #$0F
    TAY
    LDA Rev4,Y              ; reverse the four chunk bits
    ASL
    ASL
    ASL
    ASL                     ; the nibble moves to PF0's high four bits
    STA MsgPF0,X

    LDY Window+1
    LDA (FontPtr),Y
    AND #$0F
    ASL
    ASL
    ASL
    ASL
    STA Tmp0
    LDY Window+2
    LDA (FontPtr),Y
    AND #$0F
    ORA Tmp0
    STA MsgPF1,X

; --- line B: characters 3, 4, 5 ----------------------------------------------
    LDY Window+3
    LDA (FontPtr),Y
    AND #$0F
    TAY
    LDA Rev4,Y
    ASL
    ASL
    ASL
    ASL
    STA MsgPF0+7,X

    LDY Window+4
    LDA (FontPtr),Y
    AND #$0F
    ASL
    ASL
    ASL
    ASL
    STA Tmp0
    LDY Window+5
    LDA (FontPtr),Y
    AND #$0F
    ORA Tmp0
    STA MsgPF1+7,X

; --- next font row ------------------------------------------------------------
    LDA FontPtr
    CLC
    ADC #37                 ; one 37-byte font row
    STA FontPtr
    LDA FontPtr+1
    ADC #$00
    STA FontPtr+1
    INX
    CPX #TEXT_ROWS
    BNE BuildRow
    RTS

; =============================================================================
; SetCoarseP0 — the Lesson 26 divide-by-15 positioning dance
; =============================================================================
; A = the desired left edge + POS_BIAS.  Each loop pass is 5 cycles = 15
; colour clocks, which is why dividing by 15 works.  The remainder becomes
; HMP0's fine value and RESP0 strobes the coarse position.
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
; THE DATA — bank 1 starts its tables at $F400
; =============================================================================
    !if * > $F400 {
        !error "bank 1's code must end before $F400"
    }
    !fill $F400 - *, $EA

; --- the "SC" label, one PF0 byte per status row -----------------------------
; Chunks 0-1 are the S, chunks 2-3 the C: bits 4-5 and 6-7 of PF0.
ScRow:
    !byte $F0, $50, $50, $70, $60, $60, $F0

; --- the gauge masks ----------------------------------------------------------
; CellBitHi[c] = $80 >> c for cells 0-7; CellBitLo[c] = $01 << c for 8-15.
CellBitHi:
    !byte $80, $40, $20, $10, $08, $04, $02, $01
CellBitLo:
    !byte $01, $02, $04, $08, $10, $20, $40, $80

; --- the 4-bit reversal used by PF0's high nibble ----------------------------
; A glyph nibble has bit 3 = the left chunk; PF0's high nibble has bit 4 =
; the left chunk.  Reversing maps bit 3 to bit 0, which the shift moves to
; bit 4.  The table is 16 bytes: Rev4[n] is n's four bits reversed.
Rev4:
    !byte $0, $8, $4, $C, $2, $A, $6, $E, $1, $9, $5, $D, $3, $B, $7, $F

; --- the marker strip, one GRP0 byte per play line ---------------------------
MarkerStrip:
    !fill MARKER_TOP, $00
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !fill PLAY_LINES - MARKER_TOP - 8, $00

; --- the 4-chunk x 7-row font, row-major -------------------------------------
; 37 glyphs: A-Z, 0-9, space.  Each row byte is a nibble: bit 3 is the left
; chunk, bit 0 the right chunk.  The rows are contiguous 37-byte blocks
; because BuildBitmap advances by 37.
FontRow0:
    !byte $6,$E,$7,$E,$F,$F,$7,$9,$F,$3,$9,$8,$9,$9,$6,$E,$6,$E,$7,$F,$9,$9,$9,$9,$9,$F,$6,$2,$6,$E,$2,$F,$6,$F,$6,$6,$0
FontRow1:
    !byte $9,$9,$8,$9,$8,$8,$8,$9,$6,$1,$A,$8,$F,$D,$9,$9,$9,$9,$8,$6,$9,$9,$9,$9,$9,$1,$9,$6,$9,$1,$6,$8,$8,$1,$9,$9,$0
FontRow2:
    !byte $9,$9,$8,$9,$8,$8,$8,$9,$6,$1,$C,$8,$F,$F,$9,$9,$9,$9,$8,$6,$9,$9,$9,$6,$6,$2,$B,$2,$1,$1,$A,$8,$8,$2,$9,$9,$0
FontRow3:
    !byte $F,$E,$8,$9,$E,$E,$B,$F,$6,$1,$8,$8,$9,$B,$9,$E,$9,$E,$6,$6,$9,$9,$9,$6,$6,$6,$D,$2,$2,$6,$A,$E,$E,$2,$6,$7,$0
FontRow4:
    !byte $9,$9,$8,$9,$8,$8,$9,$9,$6,$1,$C,$8,$9,$9,$9,$8,$B,$C,$1,$6,$9,$9,$F,$6,$6,$8,$9,$2,$4,$1,$F,$1,$9,$4,$9,$1,$0
FontRow5:
    !byte $9,$9,$8,$9,$8,$8,$9,$9,$6,$9,$A,$8,$9,$9,$9,$8,$6,$A,$1,$6,$9,$6,$F,$9,$6,$8,$9,$2,$8,$1,$2,$1,$9,$4,$9,$1,$0
FontRow6:
    !byte $9,$E,$7,$E,$F,$8,$7,$9,$F,$6,$9,$F,$9,$9,$6,$8,$1,$9,$E,$6,$6,$6,$9,$9,$6,$F,$6,$7,$F,$E,$2,$E,$6,$4,$6,$6,$0

; --- the 32-byte message -----------------------------------------------------
; Five leading spaces then "SUPERCHIP 128 BYTE NOTEBOOK" so the six-character
; window starts blank and fills from the right.
Message:
    !byte $20,$20,$20,$20,$20,$53,$55,$50,$45,$52,$43,$48,$49,$50,$20,$31
    !byte $32,$38,$20,$42,$59,$54,$45,$20,$4E,$4F,$54,$45,$42,$4F,$4F,$4B

; -----------------------------------------------------------------------------
; The vectors
; -----------------------------------------------------------------------------
; All three point at the entry stub at $F100.  The 2600 has no interrupts, but
; every bank carries valid vectors because a reset can happen in any bank.
    !if * > $FFFA {
        !error "bank 1's data must end before $FFFA"
    }
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Entry, Entry, Entry
}
