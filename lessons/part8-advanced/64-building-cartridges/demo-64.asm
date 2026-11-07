; =============================================================================
; LESSON 64: Building Your Own Cartridge — From ROM to Physical Cart
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "the burn-in test": a 4,096-byte cartridge test ROM.  It is the program
;   you run first on a freshly built cartridge: it proves that the ROM data
;   survived the burn, that the console's 128 bytes of RAM work, that the
;   controllers reach the program, and that the frame is stable.
;
;   Two pages, switched by the SELECT switch:
;
;     Page 0 — the burn-in page.
;       * Eight vertical colour bars across the top of the page (54 lines),
;         drawn by changing COLUBK at fixed cycles inside each line.
;       * The label CART TEST, two four-character words in the six-column
;         score window (48 pixels, 8 per glyph): CART in columns 0-3 on
;         the first band and TEST in columns 0-3 on the second.  The
;         window uses four-character labels, so no word is split across
;         bands.
;       * A 16-bit checksum of the whole 4,096-byte image ($F000-$FFFF,
;         including the three vectors), computed once after power-on at 64
;         bytes per frame, shown under SUM as four hex digits, high byte
;         first (for example $1A2B reads 1A2B).
;       * A RIOT RAM test: $A5/$5A are written to four free bytes and read
;         back; the line under RAM reads PASS (0) or FAIL (1).
;       * The frame counter, four decimal digits, under FRAME.
;
;     Page 1 — the controller page.
;       * A 26-line colour-bar field at the top.
;       * SWCHA (both joysticks, active low) as eight playfield blocks, bit
;         7 on the left, under JOY; the RLDU legend below the blocks names
;         player 0's four bits in block order: bit 7 = R, 6 = L, 5 = D,
;         4 = U.
;       * SWCHB (the console switches, active low) as eight blocks under
;         CONS; the SWCHB legend below the blocks names the register, and
;         the doc's table maps each block to its switch bit (bit 7/6 are
;         the difficulty switches, bit 3 is COLOR, bit 1 SELECT, bit 0
;         RESET; bits 2, 4 and 5 are unused).
;       * INPT4 (player 0 fire, bit 7) as a single block under FIRE; only
;         bit 7 is defined, so the low seven bits are masked off.
;       * The frame counter under FRAME, and the label CONTROLLER TEST,
;         shown as the four-character labels CTRL and TEST.  CTRL is
;         the short form of CONTROLLER; both words use columns 0-3.
;
;   The text is the Lesson 63 six-column score window: P0 at TIA X=56
;   (copies at 56/72/88) and P1 at X=64 (copies at 64/80/96), NUSIZ=3 and
;   VDEL on, positioned once by the score library's ScoreSetup.  The six
;   columns are contiguous: 56, 64, 72, 80, 88, 96 — no gap inside a word.
;   The static labels are 48-byte ROM blocks read by the text_line macro
;   (the Lesson 63 kernel).  Each block is six columns x eight rows; the
;   letters occupy consecutive columns 0-3 (0-4 for FRAME and SWCHB) and
;   the unused columns are blank, so a word is never split across bands.
;   The four-character values are composed into the library's 48-byte
;   ScoreBuf in the eight-line gap before their band and drawn by
;   ScoreDraw.  The values are the checksum, PASS/FAIL and the frame
;   counter (all four characters); a value uses columns 0-3.  The value
;   glyphs in PlayerFont are seven pixels wide, so the four characters
;   fill the window with one blank pixel between neighbours.  The
;   controller page's RLDU and SWCHB are static legends under the bit
;   blocks, not dynamic values.
;
;   The colour bars use the Lesson 18 mid-line technique: a store takes
;   effect from colour clock 3 x (the cycle of the next instruction).  The
;   visible picture starts at colour clock 68, so the first store hits at
;   cycle 22 (clock 66, still in HBLANK) and the next seven are 7 cycles
;   apart: hits 29, 36, 43, 50, 57, 64, 71.  Measured bar widths in the
;   960-pixel capture: 114, 126, 126, 126, 126, 126, 126, 90 px.
;   ColourBars starts with a black alignment line (STA WSYNC, BIT, NOP),
;   so the body begins at cycle 5 on the next line; without it the first
;   body starts about 16 cycles late and its first store lands at cycle
;   38 (clock 114), leaving a thin misaligned top line.  The burn-in page
;   uses 54 bar lines plus the alignment line (55 lines), the controller
;   page 26 plus one (27); the page totals are exactly 192 lines.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5; OverscanStart is at
;   scanline 229 on both pages (cycle 8 in this build).  One HMOVE,
;   from ScoreSetup at reset.
;
; The checksum:
;   Sum = (Sum + byte) & $FFFF for byte = $F000, $F001, ... $FFFF.
;   It is a 16-bit wrapping sum, not a CRC.  $80 holds the low byte and
;   $81 the high byte; the display shows the high byte first, so a sum of
;   $1A2B reads "1A2B".  The checksum runs in overscan, 64 bytes per frame:
;   64 chunks x 64 bytes = 4,096 bytes, and the last chunk includes
;   $FFFA-$FFFF, the vectors.  It takes 64 frames (about 1.07 s at 60 Hz);
;   the four SUM cells stay blank until the last chunk is added.
;
; The RAM test:
;   At reset, after +clean_start, $99-$9C receive $A5/$5A/$A5/$5A and are
;   read back.  RamResult ($82) is 0 when every byte matches and 1 when any
;   byte differs.  0 = PASS, 1 = FAIL.
;
; The controller page (all inputs active low):
;   SWCHA bit 7/6/5/4 = player 0 right/left/down/up; bits 3-0 = player 1.
;   SWCHB bit 0 = RESET, bit 1 = SELECT, bit 3 = COLOR (1) / B&W (0),
;          bits 6-7 = the two difficulty switches.
;   INPT4 bit 7 = player 0 fire; 0 while the button is held.  Only bit 7
;   is defined; the low seven bits of INPT4 are not reliable, so the INPT4
;   block row masks them off and shows bit 7 alone (the leftmost block).
;   The raw bytes are in $85 (SWCHA), $86 (SWCHB), $87 (INPT4).  A SELECT
;   press switches the page in VBLANK, so the SELECT block is observable
;   only with the switch held across power-on (the -holdselect state log);
;   the still is idle.  RESET restarts the console, so its block cannot be
;   observed while the program is running (released = 1).
;
; Checkpoints (label, Stella scanline/cycle, and the A register):
;   StartFrame    259/3   the first VSYNC instruction
;   VblankStart     0/5   the first VBLANK instruction
;   BodyStart      37/5   the page dispatch
;   OverscanStart 229     the first overscan instruction
;   PageRead       A = the current page, 0 or 1
;   FrameRead      A = the free-running frame counter, 0..255
;   ChecksumRead   A = the checksum's LOW byte ($80); the high byte is $81
;   RamResultRead  A = 0 (PASS) or 1 (FAIL)
;   SwchaRead      A = the raw SWCHA byte (both joysticks)
;   SwchbRead      A = the raw SWCHB byte (the console switches)
;   Inpt4Read      A = the raw INPT4 byte (bit 7 = fire)
;
; The band ledgers (all cycles counted from the row's WSYNC):
;   text_line: the Lesson 63 six-column kernel; nine visible lines (one
;     setup line plus eight glyph rows, the last sharing its line with the
;     aligning WSYNC).  Its stores are inside the 76-cycle line by
;     construction; the columns are contiguous because NUSIZ=3.
;   ScoreDraw: the score library's nine-line kernel, reading ScoreBuf.
;   Gap + value: the gap starts a 10-tick RIOT timer (577 cycles) and then
;     sets the four glyphs, clears the players and playfield, and copies
;     the four glyphs into ScoreBuf (about 450 cycles).  The wait ends on
;     line 7 and the value band follows, so the gap is exactly eight lines.
;     ScoreDraw then draws the four-character value in columns 0-3.
;   bit_band: a leading gap line, then BitsToPF (about 60 cycles) and its
;     WSYNC; six block rows of three loads and three stores follow, then
;     one clear line.  The gap line separates a label from the blocks.
;   The measured page totals are exactly 192 lines, which is why
;   OverscanStart is 229 on both pages.
;
; RAM map (+clean_start zeroes every byte):
;   $80-$81 Checksum       the 16-bit sum, low byte first
;   $82     RamResult      0 = pass, 1 = fail
;   $83     Page           0 = burn-in, 1 = controller
;   $84     Frame          the free-running frame counter
;   $85     Swcha          the raw SWCHA byte
;   $86     Swchb          the raw SWCHB byte
;   $87     Inpt4          the raw INPT4 byte
;   $88-$89 CsPtr          the checksum's read pointer
;   $8A     CsCount        checksum chunks left, 64 -> 0
;   $8B     PrevSelect     the SELECT level last frame
;   $8C     Scratch        SELECT's pressed level this frame
;   $8D-$90 Char0-3        the four glyph indices of the next value
;   $91-$98 GlyphPtr0-3    the four glyph pointers during a compose
;   $99-$9C RamTest0-3     the four RAM-test bytes
;   $9D-$9F BitPF0-2       the live bit-block bytes
;   $A0-$A5 ScoreDigits    the score library (unused here)
;   $A6     ScoreRow       the score library's/text macro's row counter
;   $A7     ScoreTmp       the score library's/text macro's scratch
;   $A8-$D7 ScoreBuf       the 48-byte six-column text buffer
;   $D8-$DB FrameChars     the frame counter's four precomputed digits
;   $DC-$F7 free (28 bytes)
;   $F8-$FF stack
;
; Build: acme -f plain -o build/demo-64.bin \
;        lessons/part8-advanced/64-building-cartridges/demo-64.asm
; Run:   stella build/demo-64.bin        (SELECT switches pages)
; The ROM is 4,096 bytes.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK (44 ticks, see include/macro.asm)
OVERSCAN_TIMER = 36      ; 30-line overscan
GAP_TIMER      = 10      ; 1 + 9 x 64 = 577 cycles: the eight-line value gap
BAND_LINES     = 8       ; BlankBand's eight lines

; The eight colour bars.  The hues are drawn from the Lesson 13 palette.
BAR0 = $0E               ; light grey
BAR1 = $1A               ; gold
BAR2 = $2E               ; orange
BAR3 = $3E               ; peach
BAR4 = $42               ; red
BAR5 = $5E               ; pink
BAR6 = $84               ; blue
BAR7 = $C8               ; green

; The glyph indices of the runtime font (the 8-byte score-font order).
GLYPH_0        = 0
GLYPH_1        = 1
GLYPH_2        = 2
GLYPH_3        = 3
GLYPH_4        = 4
GLYPH_5        = 5
GLYPH_6        = 6
GLYPH_7        = 7
GLYPH_8        = 8
GLYPH_9        = 9
GLYPH_A        = 10
GLYPH_B        = 11
GLYPH_C        = 12
GLYPH_D        = 13
GLYPH_E        = 14
GLYPH_F        = 15
GLYPH_P        = 16
GLYPH_S        = 17
GLYPH_I        = 18
GLYPH_L        = 19
GLYPH_U        = 20
GLYPH_R        = 21
GLYPH_BLANK    = 22

; The checksum runs 64 bytes per frame.  64 chunks x 64 bytes = 4,096.
CHECK_CHUNK    = 64
CHECK_CHUNKS   = 4096 / CHECK_CHUNK

; =============================================================================
; RAM ALLOCATION ($80-$9F and $D8-$F7; the score library owns $A0-$D7)
; =============================================================================
Checksum      = $80      ; 2 bytes: $80 low, $81 high
RamResult     = $82      ; 0 = pass, 1 = fail
Page          = $83      ; 0 = burn-in, 1 = controller
Frame         = $84      ; the free-running frame counter
Swcha         = $85      ; the raw SWCHA byte
Swchb         = $86      ; the raw SWCHB byte
Inpt4         = $87      ; the raw INPT4 byte
CsPtr         = $88      ; 2 bytes: the checksum read pointer
CsCount       = $8A      ; checksum chunks left
PrevSelect    = $8B      ; SELECT's level last frame
Scratch       = $8C      ; SELECT's pressed level this frame
Char0         = $8D      ; the four glyph indices of the next value
Char1         = $8E
Char2         = $8F
Char3         = $90
GlyphPtr0     = $91      ; the four glyph pointers during a compose
GlyphPtr1     = $93
GlyphPtr2     = $95
GlyphPtr3     = $97
RamTest0      = $99
RamTest1      = $9A
RamTest2      = $9B
RamTest3      = $9C
BitPF0        = $9D      ; the live bit-block bytes
BitPF1        = $9E
BitPF2        = $9F
; $A0-$D7 are the score library's (ScoreDigits, ScoreRow, ScoreTmp,
; ScoreBuf).  This lesson uses ScoreRow, ScoreTmp and the 48-byte buffer.
FrameChars    = $D8      ; 4 bytes: the frame counter's decimal digits

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreSetup sets NUSIZ=3 (three close copies), VDEL on, positions P0 at
; TIA X=56 and P1 at X=64, and strobes ONE HMOVE.  ScoreDraw draws the six
; columns of ScoreBuf.  The library owns $A0-$D7.  It is sourced at the
; ROM origin because it contains code; the reset vector still points here.
    * = $F000

    !source "include/score.asm"

; =============================================================================
; MACROS (defined before use)
; =============================================================================
; text_line — the Lesson 63 six-column, 8-row kernel, reading a ROM block.
; The base block is 48 bytes: column c at base + c*8, row 0 at the bottom.
!macro text_line .base {
    LDA #7
    STA ScoreRow
-   LDY ScoreRow
    LDA .base+0,Y
    STA WSYNC
    STA GRP0
    LDA .base+8,Y
    STA GRP1
    LDA .base+16,Y
    STA GRP0
    LDA .base+24,Y
    STA ScoreTmp
    LDA .base+32,Y
    TAX
    LDA .base+40,Y
    LDY ScoreTmp
    NOP
    CPX ScoreRow
    STY GRP1
    STX GRP0
    STA GRP1
    STA GRP0
    DEC ScoreRow
    BPL -
    STA WSYNC               ; align the next band to a fresh line
}

; text_band — a static label: set the six-copy mode, then draw the block.
!macro text_band .label {
    JSR SetScoreMode
    +text_line .label
}

; bit_band — eight playfield blocks from one raw input byte.
; The compute line is 72 cycles and parks; six block rows follow, then a
; clear line.  Bit 7 is the leftmost block.
!macro bit_band .src, .mask {
    STA WSYNC               ; the gap line: keep the label clear
    LDA .src
    AND #.mask
    JSR BitsToPF
    STA WSYNC               ; line 0: the compute line
    LDY #0
-   LDA BitPF0
    STA PF0
    LDA BitPF1
    STA PF1
    LDA BitPF2
    STA PF2
    STA WSYNC
    INY
    CPY #6
    BNE -
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
}

; =============================================================================
; RESET — power-on entry
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (joysticks)
    STA SWBCNT              ; port B is an input port (console switches)

    ; --- the RIOT RAM test ------------------------------------------------
    ; Write two complementary patterns to four free bytes and read them
    ; back.  RamResult is 0 when all four match.
    LDA #$A5
    STA RamTest0
    STA RamTest2
    LDA #$5A
    STA RamTest1
    STA RamTest3
    LDA RamTest0
    CMP #$A5
    BNE RamFail
    LDA RamTest1
    CMP #$5A
    BNE RamFail
    LDA RamTest2
    CMP #$A5
    BNE RamFail
    LDA RamTest3
    CMP #$5A
    BNE RamFail
    LDA #$00
    BEQ RamDone
RamFail:
    LDA #$01
RamDone:
    STA RamResult

    ; --- the checksum's starting state ------------------------------------
    LDA #$00
    STA Checksum
    STA Checksum+1
    STA CsPtr
    LDA #$F0
    STA CsPtr+1
    LDA #CHECK_CHUNKS
    STA CsCount

    ; --- the frame state ---------------------------------------------------
    LDA #$00
    STA Page
    STA Frame
    STA PrevSelect

    ; --- the fixed TIA state ----------------------------------------------
    LDA #$00
    STA COLUBK              ; the text background is black
    STA CTRLPF              ; repeat playfield; the ball is unused
    STA GRP0
    STA GRP1
    LDA #$0E                ; white text and bit blocks
    STA COLUP0
    STA COLUP1
    STA COLUPF

    ; --- the six-column score window --------------------------------------
    ; ScoreSetup sets NUSIZ=3, VDEL on, positions P0/P1 at 56/64, and
    ; strobes the frame's only HMOVE.  The per-band SetScoreMode writes
    ; only re-enable VDEL/NUSIZ after ScoreDraw turns VDEL off.
    JSR ScoreSetup

    JMP StartFrame

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    LDA #$00
    STA COLUBK              ; the alignment line is black

; -----------------------------------------------------------------------------
; 1. THE INPUTS — read all three sources every frame
; -----------------------------------------------------------------------------
    LDA SWCHA
    STA Swcha
SwchaRead:                  ; checkpoint: A = the raw SWCHA byte
    NOP
    LDA SWCHB
    STA Swchb
SwchbRead:                  ; checkpoint: A = the raw SWCHB byte
    NOP
    LDA INPT4
    STA Inpt4
Inpt4Read:                  ; checkpoint: A = the raw INPT4 byte
    NOP

; -----------------------------------------------------------------------------
; 2. SELECT — a press cycles the test pages
; -----------------------------------------------------------------------------
    LDA Swchb
    AND #$02
    EOR #$02                ; 1 = pressed
    STA Scratch
    EOR PrevSelect
    AND Scratch
    BEQ NoSelect
    LDA Page
    EOR #$01
    STA Page
NoSelect:
    LDA Scratch
    STA PrevSelect

; -----------------------------------------------------------------------------
; 3. THE FRAME COUNTER AND ITS FOUR DECIMAL DIGITS
; -----------------------------------------------------------------------------
    INC Frame
    LDA Frame
FrameRead:                  ; checkpoint: A = the frame count, 0..255
    NOP
    LDX #0
FrameHundreds:
    CMP #100
    BCC FrameHundredsDone
    SBC #100
    INX
    BNE FrameHundreds
FrameHundredsDone:
    STX FrameChars+1
    LDX #0
FrameTens:
    CMP #10
    BCC FrameTensDone
    SBC #10
    INX
    BNE FrameTens
FrameTensDone:
    STX FrameChars+2
    STA FrameChars+3
    LDA #$00
    STA FrameChars+0

; -----------------------------------------------------------------------------
; 4. THE PAGE STATE
; -----------------------------------------------------------------------------
    LDA Page
PageRead:                   ; checkpoint: A = 0 (burn-in) or 1 (controller)
    NOP

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; THE VISIBLE PICTURE — the page dispatch
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDA #$00
    STA COLUBK              ; the alignment line is black
    LDA Page
    BEQ BurnPage
    JMP ControllerPage

; =============================================================================
; PAGE 0 — THE BURN-IN PAGE (24 bands, 192 lines)
; =============================================================================
BurnPage:
    LDY #54                 ; the burn-in bar field
    JSR ColourBars
    JSR BlankBand

    +text_band LabelCart
    +text_band LabelTest
    +text_band LabelBlank

    JSR BlankBand

    +text_band LabelSum
    +set_timer GAP_TIMER
    JSR SetChecksumChars
    JSR ClearCompose
    +wait_timer
    JSR SetScoreMode
    JSR ScoreDraw

    JSR BlankBand

    +text_band LabelRam
    +set_timer GAP_TIMER
    JSR SetRamChars
    JSR ClearCompose
    +wait_timer
    JSR SetScoreMode
    JSR ScoreDraw

    JSR BlankBand

    +text_band LabelFrame
    +set_timer GAP_TIMER
    JSR SetFrameChars
    JSR ClearCompose
    +wait_timer
    JSR SetScoreMode
    JSR ScoreDraw

    JMP OverscanStart

; =============================================================================
; PAGE 1 — THE CONTROLLER PAGE (24 bands, 192 lines)
; =============================================================================
ControllerPage:
    LDY #26                 ; the controller bar field
    JSR ColourBars
    JSR BlankBand

    +text_band LabelCtrl
    +text_band LabelTest
    +text_band LabelBlank

    JSR BlankBand

    +text_band LabelJoy
    +bit_band Swcha, $FF    ; eight blocks, bit 7 leftmost
    +text_band LabelRldu     ; names the four player-0 direction bits

    JSR BlankBand

    +text_band LabelCons
    +bit_band Swchb, $FF
    +text_band LabelSwchb      ; names the SWCHB register

    JSR BlankBand

    +text_band LabelFire
    +bit_band Inpt4, $80    ; only bit 7 is defined for INPT4

    JSR BlankBand

    +text_band LabelFrame
    +set_timer GAP_TIMER
    JSR SetFrameChars
    JSR ClearCompose
    +wait_timer
    JSR SetScoreMode
    JSR ScoreDraw

    JMP OverscanStart

; =============================================================================
; FRAME END — 30 overscan lines, the checksum chunk, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    JSR ChecksumChunk
    +wait_timer
    JMP StartFrame

; =============================================================================
; ColourBars — Y = number of lines.  Eight bars across each line.
; =============================================================================
; The line body starts at cycle 5: DEY (0-1) and BNE (2-4) follow the
; previous line's WSYNC, and the first line is aligned by the entry
; STA WSYNC + BIT + NOP.  A store paints from colour clock 3 x the cycle
; of the next instruction (Lesson 18), so the hits below put the bar
; boundaries at clocks 66, 87, 108, 129, 150, 171, 192 and 213.  The
; visible picture begins at clock 68; the first bar is 114 pixels wide in
; the capture, the six inside bars 126, and the last 90.
ColourBars:
    LDA #$00
    STA COLUBK              ; the alignment line is black
    STA WSYNC               ; align the body to a fresh line
    BIT Checksum            ; 3 cycles
    NOP                     ; 2 cycles: the body starts at cycle 5
BarBody:
    LDA #BAR0               ; 5-6
    STA COLUBK              ; 7-9    hit 10: the base in HBLANK
    NOP                     ; 10-11
    NOP                     ; 12-13
    BIT Checksum            ; 14-16  a 3-cycle pad; no side effects
    LDA #BAR0               ; 17-18
    STA COLUBK              ; 19-21  hit 22 (clock 66)
    NOP                     ; 22-23
    LDA #BAR1               ; 24-25
    STA COLUBK              ; 26-28  hit 29
    NOP
    LDA #BAR2
    STA COLUBK              ; hit 36
    NOP
    LDA #BAR3
    STA COLUBK              ; hit 43
    NOP
    LDA #BAR4
    STA COLUBK              ; hit 50
    NOP
    LDA #BAR5
    STA COLUBK              ; hit 57
    NOP
    LDA #BAR6
    STA COLUBK              ; hit 64
    NOP                     ; 64-65
    LDA #BAR7               ; 66-67
    STA COLUBK              ; 68-70  hit 71 (clock 213)
    STA WSYNC               ; 71-73  park until the line ends
    DEY                     ; the next line: 0-1
    BNE BarBody             ; 2-4
    LDA #$00
    STA COLUBK              ; the text background is black again
    RTS

; =============================================================================
; BlankBand — eight lines with no graphics
; =============================================================================
BlankBand:
    LDA #$00
    LDY #BAND_LINES
-   STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA WSYNC
    DEY
    BNE -
    RTS

; =============================================================================
; SetScoreMode — clear the playfield, three close copies, VDEL on
; =============================================================================
; ScoreSetup leaves the players in this mode; ScoreDraw turns VDEL off at
; the end of every value, so each band re-enables it.  The playfield is
; cleared here so a bit-block row cannot persist behind a label.  No HMOVE
; here: the positions do not change.
SetScoreMode:
    LDA #$00
    STA PF0                 ; the labels and values own the playfield
    STA PF1
    STA PF2
    LDA #$03
    STA NUSIZ0
    STA NUSIZ1
    LDA #$01
    STA VDELP0
    STA VDELP1
    RTS

; =============================================================================
; ClearCompose — blank the players/playfield, then compose the value
; =============================================================================
; The gap started the GAP_TIMER; the clear and the compose must finish
; before the timer expires (577 cycles), which keeps the gap eight lines.
ClearCompose:
    LDA #$00
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    JSR ComposeValue
    RTS

; =============================================================================
; ComposeValue — Char0-3 -> ScoreBuf columns 0-3
; =============================================================================
; A value is four glyphs wide and left-aligned in the six-column window:
; columns 0-3 hold the glyphs, columns 4 and 5 stay zero from +clean_start.
ComposeValue:
    LDX Char0
    LDA FontPtrLo,X
    STA GlyphPtr0
    LDA FontPtrHi,X
    STA GlyphPtr0+1
    LDX Char1
    LDA FontPtrLo,X
    STA GlyphPtr1
    LDA FontPtrHi,X
    STA GlyphPtr1+1
    LDX Char2
    LDA FontPtrLo,X
    STA GlyphPtr2
    LDA FontPtrHi,X
    STA GlyphPtr2+1
    LDX Char3
    LDA FontPtrLo,X
    STA GlyphPtr3
    LDA FontPtrHi,X
    STA GlyphPtr3+1
    LDY #0
-   LDA (GlyphPtr0),Y
    STA ScoreBuf+0,Y
    LDA (GlyphPtr1),Y
    STA ScoreBuf+8,Y
    LDA (GlyphPtr2),Y
    STA ScoreBuf+16,Y
    LDA (GlyphPtr3),Y
    STA ScoreBuf+24,Y
    INY
    CPY #8
    BNE -
    RTS

; =============================================================================
; SetChecksumChars — the four hex digits, high byte first
; =============================================================================
SetChecksumChars:
    LDA CsCount
    BNE CsBlank
    LDA Checksum+1
    PHA
    LSR
    LSR
    LSR
    LSR
    STA Char0               ; the high byte's high nibble
    PLA
    AND #$0F
    STA Char1               ; the high byte's low nibble
    LDA Checksum
ChecksumRead:               ; checkpoint: A = the checksum's low byte
    NOP
    PHA
    LSR
    LSR
    LSR
    LSR
    STA Char2               ; the low byte's high nibble
    PLA
    AND #$0F
    STA Char3               ; the low byte's low nibble
    RTS
CsBlank:
    LDA #GLYPH_BLANK
    STA Char0
    STA Char1
    STA Char2
    STA Char3
    RTS

; =============================================================================
; SetRamChars — PASS or FAIL
; =============================================================================
SetRamChars:
    LDA RamResult
RamResultRead:              ; checkpoint: A = 0 (PASS) or 1 (FAIL)
    NOP
    BNE RamFailLine
    LDX #0
-   LDA PassGlyphs,X
    STA Char0,X
    INX
    CPX #4
    BNE -
    RTS
RamFailLine:
    LDX #0
-   LDA FailGlyphs,X
    STA Char0,X
    INX
    CPX #4
    BNE -
    RTS

; =============================================================================
; SetFrameChars — copy the four digits computed in VBLANK
; =============================================================================
SetFrameChars:
    LDA FrameChars+0
    STA Char0
    LDA FrameChars+1
    STA Char1
    LDA FrameChars+2
    STA Char2
    LDA FrameChars+3
    STA Char3
    RTS

; =============================================================================
; BitsToPF — A = the raw byte; fills BitPF0/1/2 with the eight blocks
; =============================================================================
; Block positions: bit 7 at chunk 2 (PF0 bit 6), bits 6-3 at chunks 4, 6,
; 8, 10 (PF1 bits 7, 5, 3, 1), bits 2-0 at chunks 12, 14, 16 (PF2 bits
; 0, 2, 4).  The four 16-byte tables hold the pre-shifted contribution of
; each nibble.  Char0 is free here (the value compose runs later).
BitsToPF:
    STA Char0
    LSR
    LSR
    LSR
    LSR
    TAX
    LDA BitHighPF0,X
    STA BitPF0
    LDA BitHighPF1,X
    STA BitPF1
    LDA Char0
    AND #$0F
    TAX
    LDA BitPF1
    ORA BitLowPF1,X
    STA BitPF1
    LDA BitLowPF2,X
    STA BitPF2
    RTS

; The high nibble: bit 7 -> PF0 $40; bits 6/5/4 -> PF1 $80/$20/$08.
BitHighPF0:
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    !byte $40,$40,$40,$40,$40,$40,$40,$40
BitHighPF1:
    !byte $00,$08,$20,$28,$80,$88,$A0,$A8
    !byte $00,$08,$20,$28,$80,$88,$A0,$A8
; The low nibble: bit 3 -> PF1 $02; bits 2/1/0 -> PF2 $01/$04/$10.
BitLowPF1:
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    !byte $02,$02,$02,$02,$02,$02,$02,$02
BitLowPF2:
    !byte $00,$10,$04,$14,$01,$11,$05,$15
    !byte $00,$10,$04,$14,$01,$11,$05,$15

; =============================================================================
; ChecksumChunk — add the next 64 bytes to the 16-bit checksum
; =============================================================================
; The pointer walks $F000 -> $FFC0, so the final chunk reads through
; $FFFF, the last vector byte.  CsCount reaches 0 after 64 chunks.
ChecksumChunk:
    LDA CsCount
    BEQ CheckDone
    LDY #0
-   LDA (CsPtr),Y
    CLC
    ADC Checksum
    STA Checksum
    BCC CheckNoCarry
    INC Checksum+1
CheckNoCarry:
    INY
    CPY #CHECK_CHUNK
    BNE -
    LDA CsPtr
    CLC
    ADC #CHECK_CHUNK
    STA CsPtr
    BCC CheckNoPage
    INC CsPtr+1
CheckNoPage:
    DEC CsCount
CheckDone:
    RTS

; =============================================================================
; THE VALUE FONT AND THE LABEL DATA
; =============================================================================
; PlayerFont holds the value glyphs.  Each glyph body is stretched to seven
; pixels (bits 7-1), so a four-character value fills its four columns with
; one blank pixel between neighbours and no gap that reads as a blank
; column.  The static label blocks below use the five-pixel letter forms,
; which suit a single word in four consecutive columns.
PlayerFont:
    !byte $00,$7C,$C6,$C6,$E6,$DE,$C6,$7C   ; 0 0
    !byte $00,$FE,$38,$38,$38,$38,$78,$38   ; 1 1
    !byte $00,$FE,$60,$38,$1C,$06,$C6,$7C   ; 2 2
    !byte $00,$7C,$C6,$06,$1C,$38,$1C,$FE   ; 3 3
    !byte $00,$1C,$1C,$FE,$DC,$7C,$3C,$1C   ; 4 4
    !byte $00,$7C,$C6,$06,$06,$FC,$C0,$FE   ; 5 5
    !byte $00,$7C,$C6,$C6,$FC,$C0,$C6,$7C   ; 6 6
    !byte $00,$38,$38,$38,$38,$1C,$C6,$FE   ; 7 7
    !byte $00,$7C,$C6,$C6,$7C,$C6,$C6,$7C   ; 8 8
    !byte $00,$7C,$C6,$06,$7E,$C6,$C6,$7C   ; 9 9
    !byte $00,$C6,$C6,$C6,$FE,$C6,$C6,$38   ; 10 A
    !byte $00,$F8,$C6,$C6,$F8,$C6,$C6,$F8   ; 11 B
    !byte $00,$38,$C6,$C0,$C0,$C0,$C6,$38   ; 12 C
    !byte $00,$F8,$C6,$C6,$C6,$C6,$C6,$F8   ; 13 D
    !byte $00,$FE,$C0,$C0,$F8,$C0,$C0,$FE   ; 14 E
    !byte $00,$C0,$C0,$C0,$F8,$C0,$C0,$FE   ; 15 F
    !byte $00,$C0,$C0,$C0,$F8,$C6,$C6,$F8   ; 16 P
    !byte $00,$F8,$06,$06,$38,$C0,$C0,$3E   ; 17 S
    !byte $00,$FE,$10,$10,$10,$10,$10,$FE   ; 18 I
    !byte $00,$FE,$C0,$C0,$C0,$C0,$C0,$C0   ; 19 L
    !byte $00,$38,$C6,$C6,$C6,$C6,$C6,$C6   ; 20 U
    !byte $00,$C6,$C8,$D0,$F8,$C6,$C6,$F8   ; 21 R
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; 22  

FontPtrLo:
    !byte <(PlayerFont + 0)
    !byte <(PlayerFont + 8)
    !byte <(PlayerFont + 16)
    !byte <(PlayerFont + 24)
    !byte <(PlayerFont + 32)
    !byte <(PlayerFont + 40)
    !byte <(PlayerFont + 48)
    !byte <(PlayerFont + 56)
    !byte <(PlayerFont + 64)
    !byte <(PlayerFont + 72)
    !byte <(PlayerFont + 80)
    !byte <(PlayerFont + 88)
    !byte <(PlayerFont + 96)
    !byte <(PlayerFont + 104)
    !byte <(PlayerFont + 112)
    !byte <(PlayerFont + 120)
    !byte <(PlayerFont + 128)
    !byte <(PlayerFont + 136)
    !byte <(PlayerFont + 144)
    !byte <(PlayerFont + 152)
    !byte <(PlayerFont + 160)
    !byte <(PlayerFont + 168)
    !byte <(PlayerFont + 176)
FontPtrHi:
    !byte >(PlayerFont + 0)
    !byte >(PlayerFont + 8)
    !byte >(PlayerFont + 16)
    !byte >(PlayerFont + 24)
    !byte >(PlayerFont + 32)
    !byte >(PlayerFont + 40)
    !byte >(PlayerFont + 48)
    !byte >(PlayerFont + 56)
    !byte >(PlayerFont + 64)
    !byte >(PlayerFont + 72)
    !byte >(PlayerFont + 80)
    !byte >(PlayerFont + 88)
    !byte >(PlayerFont + 96)
    !byte >(PlayerFont + 104)
    !byte >(PlayerFont + 112)
    !byte >(PlayerFont + 120)
    !byte >(PlayerFont + 128)
    !byte >(PlayerFont + 136)
    !byte >(PlayerFont + 144)
    !byte >(PlayerFont + 152)
    !byte >(PlayerFont + 160)
    !byte >(PlayerFont + 168)
    !byte >(PlayerFont + 176)

    !align 7, 0
LabelCart:                        ; "CART"
    !byte $00,$70,$88,$80,$80,$80,$88,$70   ; column 0 'C'
    !byte $00,$88,$88,$88,$F8,$88,$88,$70   ; column 1 'A'
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0   ; column 2 'R'
    !byte $00,$20,$20,$20,$20,$20,$20,$F8   ; column 3 'T'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelTest:                        ; "TEST"
    !byte $00,$20,$20,$20,$20,$20,$20,$F8   ; column 0 'T'
    !byte $00,$F8,$80,$80,$F0,$80,$80,$F8   ; column 1 'E'
    !byte $00,$F0,$08,$08,$70,$80,$80,$78   ; column 2 'S'
    !byte $00,$20,$20,$20,$20,$20,$20,$F8   ; column 3 'T'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelCtrl:                        ; "CTRL"
    !byte $00,$70,$88,$80,$80,$80,$88,$70   ; column 0 'C'
    !byte $00,$20,$20,$20,$20,$20,$20,$F8   ; column 1 'T'
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0   ; column 2 'R'
    !byte $00,$F8,$80,$80,$80,$80,$80,$80   ; column 3 'L'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelSum:                         ; "SUM"
    !byte $00,$F0,$08,$08,$70,$80,$80,$78   ; column 0 'S'
    !byte $00,$70,$88,$88,$88,$88,$88,$88   ; column 1 'U'
    !byte $00,$88,$88,$88,$A8,$A8,$D8,$88   ; column 2 'M'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 3 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelRam:                         ; "RAM"
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0   ; column 0 'R'
    !byte $00,$88,$88,$88,$F8,$88,$88,$70   ; column 1 'A'
    !byte $00,$88,$88,$88,$A8,$A8,$D8,$88   ; column 2 'M'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 3 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelFrame:                       ; "FRAME"
    !byte $00,$80,$80,$80,$F0,$80,$80,$F8   ; column 0 'F'
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0   ; column 1 'R'
    !byte $00,$88,$88,$88,$F8,$88,$88,$70   ; column 2 'A'
    !byte $00,$88,$88,$88,$A8,$A8,$D8,$88   ; column 3 'M'
    !byte $00,$F8,$80,$80,$F0,$80,$80,$F8   ; column 4 'E'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelJoy:                         ; "JOY"
    !byte $00,$70,$88,$88,$88,$08,$08,$08   ; column 0 'J'
    !byte $00,$70,$88,$88,$88,$88,$88,$70   ; column 1 'O'
    !byte $00,$20,$20,$20,$50,$88,$88,$88   ; column 2 'Y'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 3 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelRldu:                        ; "RLDU"
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0   ; column 0 'R'
    !byte $00,$F8,$80,$80,$80,$80,$80,$80   ; column 1 'L'
    !byte $00,$F0,$88,$88,$88,$88,$88,$F0   ; column 2 'D'
    !byte $00,$70,$88,$88,$88,$88,$88,$88   ; column 3 'U'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelCons:                        ; "CONS"
    !byte $00,$70,$88,$80,$80,$80,$88,$70   ; column 0 'C'
    !byte $00,$70,$88,$88,$88,$88,$88,$70   ; column 1 'O'
    !byte $00,$88,$88,$88,$98,$A8,$C8,$88   ; column 2 'N'
    !byte $00,$F0,$08,$08,$70,$80,$80,$78   ; column 3 'S'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelSwchb:                       ; "SWCHB"
    !byte $00,$F0,$08,$08,$70,$80,$80,$78   ; column 0 'S'
    !byte $00,$D8,$A8,$A8,$88,$88,$88,$88   ; column 1 'W'
    !byte $00,$70,$88,$80,$80,$80,$88,$70   ; column 2 'C'
    !byte $00,$88,$88,$88,$F8,$88,$88,$88   ; column 3 'H'
    !byte $00,$F0,$88,$88,$F0,$88,$88,$F0   ; column 4 'B'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelFire:                        ; "FIRE"
    !byte $00,$80,$80,$80,$F0,$80,$80,$F8   ; column 0 'F'
    !byte $00,$F8,$20,$20,$20,$20,$20,$F8   ; column 1 'I'
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0   ; column 2 'R'
    !byte $00,$F8,$80,$80,$F0,$80,$80,$F8   ; column 3 'E'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelBlank:                       ; a blank band, six empty columns
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 0 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 1 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 2 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 3 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

PassGlyphs:
    !byte 16,10,17,17
FailGlyphs:
    !byte 15,10,18,19


; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
