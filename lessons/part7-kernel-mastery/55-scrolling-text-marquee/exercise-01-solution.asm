; =============================================================================
; LESSON 55, EXERCISE 1: Change the Message — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; The exercise replaces the base message with "KERNEL MASTERY" (14 chars).
; MESSAGE_LEN = 14, so each row holds 15 bytes (14 glyph bytes + one zero pad)
; and the pre-shifted table is 8 phases x 8 rows x 15 bytes = 960 bytes.
; The wrap is MESSAGE_LEN * 8 - 48 = 64.  Everything else is the base lesson.
;
; The base comments below describe the original 17-character example; the
; constants and the table in this file are the 14-character version.
;
; =============================================================================
; =============================================================================
; LESSON 55: Scrolling Text Marquee — The Activision Logo Effect
; =============================================================================
; Part 7: Kernel Mastery
;
; What this program does:
;   "the marquee": a six-character, 48-pixel text window at the top of the
;   screen, scrolling the message "KERNEL MASTERY" one pixel at a time
;   over a starfield with a one-pixel shooting star.
;
; The text window
;   The Lesson 39 score kernel draws six 8-pixel columns with two players in
;   three-copy close mode.  P0 sits at TIA X=56 (copies at 56, 72, 88) and P1
;   at X=64 (copies at 64, 80, 96), so the six columns interleave across
;   X=56-103: a 48-pixel cell block.  ScoreSetup positions the players and
;   turns VDEL on; ScoreDraw writes the eight glyph rows and consumes nine
;   visible lines (line 0 is the setup/blank line, lines 1-8 are the rows).
;
; The font and the message
;   The font is 39 glyphs (A-Z, 0-9, space, dash, period), eight bytes each,
;   bottom-up.  A glyph is 5x7 inside an 8x8 cell, bit 7 is the leftmost
;   pixel, and every glyph's byte 0 is $00, so the lit block is seven rows
;   (visible 1-7, capture y = 107 + 3.15 * line = 109-130).
;
;   The message is "KERNEL MASTERY" (14 characters).  A runtime shift
;   would be too expensive in the score kernel, so the program keeps eight
;   pre-shifted copies of the message, one for each horizontal phase.  The
;   table is 8 phases x 8 rows x 15 bytes = 960 bytes; each row holds the
;   14 message bytes plus one zero pad.  For phase p, the output byte is
;
;       (message[i] << p) | (message[i+1] >> (8-p))     for p > 0
;       message[i]                                      for p = 0
;
;   The fill selects the phase block with ScrollOffset & 7 and the byte
;   index with ScrollOffset >> 3, then copies the six columns:
;
;       ScoreBuf + c*8 + r = ShiftedTable[phase][r][byteIndex + c]
;
;   The destination is column-major because ScoreDraw reads one column at a
;   time; the source is row-major because a row's 15 bytes are contiguous.
;   That is 8 rows x 6 columns = 48 stores.  The window scrolls 0-64
;   (14*8 - 48 = 64), one pixel every two frames; SELECT resets to 0 and
;   fire pauses/resumes.  The auto-demo scrolls without input.
;
;   At offset 0 the window reads "KERNEL"; the message wraps at 64.
;
; The starfield
;   Visible 9-191 is a 183-line starfield drawn by a one-line kernel from
;   three page-aligned 183-byte planes (StarPF0/1/2).  The playfield is
;   reflected (CTRLPF=$01), so the pattern doubles across the centre.  A
;   one-pixel ball at TIA X=80 is the shooting star: it moves down one line
;   per frame, BallY 0-182.  The stars are white $0E; on the ball's row the
;   kernel writes COLUPF=$1A just before the ball's pixel, so the shooting
;   star is gold (the few playfield stars to its right on that line share
;   the gold write).
;
;   The text zone is 9 lines and the starfield is 183 lines: 9 + 183 = 192.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;   The score's single HMOVE applies HMP0, HMP1 and the ball's HMBL; the
;   ball's coarse RESBL and HMBL are set before ScoreSetup.  There is one
;   HMOVE per frame.
;
; Checkpoints (Stella scanline/cycle numbers are measured in the lesson):
;   StartFrame (259), VblankStart (0), BodyStart (37), OverscanStart (229);
;   ScrollOffsetRead (A = the offset, 0..64), PhaseRead/ByteIndexRead;
;   TextRow (0..7), TextCol (0..5), TextFill (A = the first byte of a row);
;   ScoreDraw (37/11), ScoreDrawRow (37/26); HmoveApply/HmoveDone (the
;   score library's one HMOVE); BallYRead (A = the ball's row), BallRow
;   (Y = the ball's row in the kernel); FirePause (A = 0/1 after a press);
;   SelectReset (A = 0).
;
; RAM map (+clean_start zeroes every byte):
;   $80 ScrollOffset   0..64
;   $81 ScrollTimer    the two-frame scroll divider
;   $82 PrevFire       fire state last frame (1 = pressed)
;   $83 PrevSelect     SELECT state last frame (1 = pressed)
;   $84 FirePause      0 = scrolling, 1 = paused
;   $85 BeepTimer      frames of beep remaining
;   $86 BeepPitch      AUDF for the beep
;   $87 Startup        frames left before the fire edge is trusted
;   $88 NewFire        this frame's fire 0 -> 1 edge
;   $89 Scratch        SELECT's pressed state
;   $8A BallY          the shooting star's row, 0..182
;   $8B Phase          ScrollOffset & 7, 0..7
;   $8C ByteIndex      ScrollOffset >> 3, 0..8
;   $8D TextPtrLo      the fill pointer (low byte)
;   $8E TextPtrHi      the fill pointer (high byte)
;   $8F TextRow        the fill's row, 0..7
;   $90 TextCol        the fill's column, 0..5
;   $91 TextFirst      the first byte of each row (a debug latch)
;   $92-$9F free (14 bytes)
;   $A0-$D7 the score library: ScoreDigits, ScoreRow, ScoreTmp, ScoreBuf
;   $D8-$F7 free (32 bytes)
;   $F8-$FF stack
;
; Build: acme -f plain -o build/exercise-01.bin \
;        lessons/part7-kernel-mastery/55-scrolling-text-marquee/exercise-01-solution.asm
; Run:   stella build/exercise-01.bin     (click the screen to unmute the beeps)
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
TEXT_TOP       = 0       ; the text zone's first visible line
TEXT_LINES     = 9       ; ScoreDraw's nine lines
STAR_TOP       = 9       ; the starfield's first visible line
STAR_LINES     = 183     ; 192 - 9

MESSAGE_LEN    = 14      ; "KERNEL MASTERY"
ROW_BYTES      = MESSAGE_LEN + 1   ; 14 bytes + one zero pad
PHASE_BYTES    = 8 * ROW_BYTES     ; one phase block: 8 rows x 15 bytes
SCROLL_MAX     = MESSAGE_LEN * 8 - 48   ; 64: the last six-character window

TEXT_COLUMNS   = 6       ; six 8-pixel columns
TEXT_ROWS      = 8       ; eight glyph rows

BALL_X         = 80      ; the shooting star's TIA X
BALL_LINES     = STAR_LINES   ; the ball's row wraps at the bottom

C_WHITE        = $0E     ; the text and the stars
C_GOLD         = $1A     ; the shooting star
C_BG           = $02     ; the background

BEEP_FRAMES    = 2       ; a two-frame tick
BEEP_PITCH     = $08     ; AUDF 8 on AUDC $0C: a short, bright beep

; The frame arithmetic is a build-time assertion, not a comment.
!if TEXT_TOP != 0 {
    !error "the text zone must start at visible line 0"
}
!if STAR_TOP != TEXT_TOP + TEXT_LINES {
    !error "the starfield must start after the nine text lines"
}
!if STAR_TOP + STAR_LINES != SCREEN_LINES {
    !error "the text zone plus the starfield must total 192 lines"
}
!if SCROLL_MAX != 64 {
    !error "the message must wrap at 64"
}
!if PHASE_BYTES != 120 {
    !error "one phase block must be 8 rows x 15 bytes"
}

; =============================================================================
; RAM ALLOCATION ($80-$91; +clean_start zeroes every byte)
; =============================================================================
ScrollOffset  = $80   ; the text window's first pixel, 0..64
ScrollTimer   = $81   ; the two-frame scroll divider
PrevFire      = $82   ; fire state last frame (1 = pressed)
PrevSelect    = $83   ; SELECT state last frame (1 = pressed)
FirePause     = $84   ; 0 = scrolling, 1 = paused
BeepTimer     = $85   ; frames of beep remaining
BeepPitch     = $86   ; AUDF for the beep
Startup       = $87   ; frames left before the fire edge is trusted
NewFire       = $88   ; this frame's fire 0 -> 1 edge
Scratch       = $89   ; SELECT's pressed state
BallY         = $8A   ; the shooting star's row, 0..182
Phase         = $8B   ; ScrollOffset & 7
ByteIndex     = $8C   ; ScrollOffset >> 3
TextPtrLo     = $8D   ; the fill pointer's low byte
TextPtrHi     = $8E   ; the fill pointer's high byte
TextRow       = $8F   ; the fill's row, 0..7
TextCol       = $90   ; the fill's column, 0..5
TextFirst     = $91   ; the first byte of each row (a debug latch)
;
; $92-$9F are free.  The score library owns $A0-$D7.  $D8-$F7 are free.
; The stack lives at $F8-$FF; the call depth is one level (SetCoarseBL,
; ScoreSetup, BeepStart).

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreSetup, ScoreDraw, ScoreInit, ScoreClear, ScoreSetDigit, ScoreAddOne and
; ScoreFont live here.  The library owns $A0-$D7 and defines the lesson's
; only HMOVE.  It is sourced first so its RAM symbols (ScoreBuf and friends)
; are known when the lesson's fill is assembled; the reset vector still
; points at the lesson's Reset below.
    !source "include/score.asm"

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the fire button)

    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #$08
    STA Startup             ; ignore the fire line while the console settles
    LDA #$FF
    STA BallY               ; the first frame's INC wraps to 0, the top row

; --- the TIA's fixed state ---------------------------------------------------
    LDA #C_BG
    STA COLUBK              ; the dark field behind the text and the stars
    LDA #$01
    STA CTRLPF              ; reflect the playfield; the ball is one pixel
    LDA #C_WHITE
    STA COLUP0              ; the six text columns are white
    STA COLUP1
    STA COLUPF              ; the stars are white until the ball's row
    LDA #$00
    STA NUSIZ0              ; ScoreSetup sets the three-copy mode
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    STA ENABL

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; 1. THE BEEP'S CLOCK
; -----------------------------------------------------------------------------
; The same two-byte beep the rest of Part 6 and Part 7 uses: BeepTimer counts
; down every frame and channel 0 goes silent at zero.
    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0
BeepClockDone:

; -----------------------------------------------------------------------------
; 2. FIRE — pause or resume the scroll on the 0 -> 1 edge
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  EOR turns that into a 1, and the
; EOR/AND pair keeps only a new press, so holding the button toggles once.
; The first eight frames are not trusted: INPT4 can read low while the
; console settles, so Startup forces the edge clear until it reaches zero.
    LDA INPT4
    AND #$80
    EOR #$80                ; 1 = pressed
    STA NewFire
    EOR PrevFire
    AND NewFire
    STA NewFire             ; NewFire = pressed & ~wasPressed
    LDA Startup
    BEQ FireEdgeReady
    DEC Startup
    LDA #$00
    STA NewFire
FireEdgeReady:
    LDA NewFire
    BEQ NoFireEdge
    LDA FirePause
    EOR #$01                ; 0 -> 1 = pause, 1 -> 0 = resume
    STA FirePause
FirePauseSet:               ; checkpoint: A = the new pause flag
    JSR BeepStart
NoFireEdge:
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire

; -----------------------------------------------------------------------------
; 3. SELECT — reset the message to offset 0 and resume the scroll
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  The edge, not the level, resets the
; window.  SELECT also clears the pause so the demo restarts moving.
    LDA SWCHB
    AND #$02
    EOR #$02                ; 1 = pressed
    STA Scratch
    EOR PrevSelect
    AND Scratch
    BEQ NoSelectEdge
    LDA #$00
    STA ScrollOffset
    STA ScrollTimer
    STA FirePause
SelectReset:                ; checkpoint: A = 0, the new offset
    JSR BeepStart
NoSelectEdge:
    LDA Scratch
    STA PrevSelect

; -----------------------------------------------------------------------------
; 4. THE SCROLL CLOCK — one pixel every two frames
; -----------------------------------------------------------------------------
; ScrollTimer's low bit is the divider.  FirePause skips the whole clock, so
; a paused message keeps its offset and resumes from it.  The offset wraps
; 64 -> 0: after the last six-character window the message starts again.
    LDA FirePause
    BNE NoScrollStep
    INC ScrollTimer
    LDA ScrollTimer
    AND #$01
    BNE NoScrollStep
    INC ScrollOffset
    LDA ScrollOffset
    CMP #(SCROLL_MAX + 1)
    BCC ScrollStore
    LDA #$00
ScrollStore:
    STA ScrollOffset
NoScrollStep:
    LDA ScrollOffset
ScrollOffsetRead:           ; checkpoint: A = the window's first pixel

; -----------------------------------------------------------------------------
; 5. THE SHOOTING STAR — one line down per frame
; -----------------------------------------------------------------------------
    INC BallY
    LDA BallY
    CMP #BALL_LINES
    BCC BallStore
    LDA #$00
BallStore:
    STA BallY
BallYRead:                  ; checkpoint: A = the ball's row
    NOP

; -----------------------------------------------------------------------------
; 6. THE PHASE POINTER — phase block + byte index
; -----------------------------------------------------------------------------
; Phase = ScrollOffset & 7 selects one of the eight pre-shifted blocks.
; ByteIndex = ScrollOffset >> 3 selects the first of the six columns inside
; the 15-byte row.  The pointer is the block's base plus the byte index;
; the fill advances it by ROW_BYTES (15) per row.
    LDA ScrollOffset
    AND #$07
    STA Phase
PhaseRead:                  ; checkpoint: A = the phase, 0..7
    LDA ScrollOffset
    LSR
    LSR
    LSR
    STA ByteIndex
ByteIndexRead:              ; checkpoint: A = the byte index, 0..8

    LDX Phase
    LDA PhasePtrLo,X
    CLC
    ADC ByteIndex
    STA TextPtrLo
    LDA PhasePtrHi,X
    ADC #$00
    STA TextPtrHi

; -----------------------------------------------------------------------------
; 7. THE TEXT FILL — 48 stores at ScoreBuf + c*8 + r
; -----------------------------------------------------------------------------
; The source is row-major (one 15-byte row at a time); the destination is
; column-major (column c's eight rows at ScoreBuf+c*8).  X is the row and
; Y is the column, so the six stores use the fixed ScoreBuf+0/8/16/24/32/40
; bases with X as the row offset.  TextRow and TextCol are debug latches;
; they make the stride visible in the state log.
    LDX #0
FillRow:
    STX TextRow
    LDY #0
    STY TextCol
    LDA (TextPtrLo),Y
    STA TextFirst
TextFill:                   ; checkpoint: A = the first byte of the row
    STA ScoreBuf+0,X
    INY
    STY TextCol
    LDA (TextPtrLo),Y
    STA ScoreBuf+8,X
    INY
    STY TextCol
    LDA (TextPtrLo),Y
    STA ScoreBuf+16,X
    INY
    STY TextCol
    LDA (TextPtrLo),Y
    STA ScoreBuf+24,X
    INY
    STY TextCol
    LDA (TextPtrLo),Y
    STA ScoreBuf+32,X
    INY
    STY TextCol
    LDA (TextPtrLo),Y
    STA ScoreBuf+40,X
TextColLast:                ; checkpoint: TextCol = 5, A = the last byte
    ; The next row starts ROW_BYTES further on.  The pointer is 16 bits
    ; because a phase block is 144 bytes and can cross a page boundary.
    LDA TextPtrLo
    CLC
    ADC #ROW_BYTES
    STA TextPtrLo
    BCC FillNoCarry
    INC TextPtrHi
FillNoCarry:
    INX
    CPX #TEXT_ROWS
    BNE FillRow

; -----------------------------------------------------------------------------
; 8. THE SCORE SETUP AND THE ONE HMOVE
; -----------------------------------------------------------------------------
; SetCoarseBL's RESBL/HMBL and ScoreSetup's RESP0/RESP1/HMP0/HMP1 are all set
; first; ScoreSetup's single HMOVE applies the three fine offsets in one
; HBLANK.  The score's three-copy window needs VDEL on, which ScoreSetup
; sets.  The caller supplies the colours (white above).
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    LDA #C_WHITE
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL

    LDA #(BALL_X + POS_BIAS + 1)   ; the ball's reset is one clock short
    JSR SetCoarseBL                ; sets HMBL and RESBL
    JSR ScoreSetup                 ; sets NUSIZ/VDEL, P0/P1, then one HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines: the text band (9) and the starfield (183)
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    JSR ScoreDraw           ; 9 lines: line 0 setup, lines 1-8 rows

; The score's cleanup has cleared GRP0/GRP1 and VDEL; the starfield starts
; on visible line 9 (scanline 46) and draws 183 lines.
StarStart:                  ; checkpoint: scanline 46, visible line 9
StarField:
    LDY #0
StarRow:                    ; checkpoint: Y = 0..182
    ; The stars are white on every line.  The write is first so the ball's
    ; gold write below can change the colour on its own line.
    LDA #C_WHITE
    STA COLUPF
    LDA StarPF0,Y
    STA PF0                 ; chunks 0-3 (the page-aligned plane)
    LDA StarPF1,Y
    STA PF1                 ; chunks 4-11
    LDA StarPF2,Y
    STA PF2                 ; chunks 12-19
    ; The ball is one pixel at X=80, so its enable must be latched before
    ; the beam reaches pixel 80 (about cycle 49 from the line start).  The
    ; compare comes first; on the ball's row the gold write and the enable
    ; follow immediately, and there is no clear to waste cycles.  On every
    ; other row the clear is still early enough (cycle ~36) to hide the ball.
    CPY BallY
    BNE NoBall
BallRow:                    ; checkpoint: Y = BallY
    LDA #C_GOLD
    STA COLUPF              ; the gold write lands before the ball's pixel
    LDA #$02
    STA ENABL
    JMP StarWait
NoBall:
    LDA #$00
    STA ENABL               ; off before X=80 on every other row
StarWait:
    STA WSYNC
    INY
    CPY #STAR_LINES
    BNE StarRow
    JMP OverscanStart       ; 183 lines: visible 9-191

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
; SetCoarseBL — the Lesson 26 divide-by-15 dance for the ball
; =============================================================================
; A = the desired left edge + POS_BIAS + 1.  The first WSYNC starts a fresh
; line; each loop iteration is 5 cycles = 15 colour clocks, which is why
; dividing by 15 works.  The remainder becomes the fine value and RESBL
; strobes the coarse position; ScoreSetup's HMOVE applies HMBL.
; The routine is 32-byte aligned so the loop's taken BCS stays inside one
; page: a page-crossing branch costs one extra cycle per iteration and would
; shift the ball by 15 colour clocks.
    !align 31, 0
SetCoarseBL:
    STA WSYNC
    SEC
DivBL:
    SBC #15
    BCS DivBL
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMBL
    STA RESBL
    RTS

; =============================================================================
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
; AUDC 0C is the div-6 tone from Lesson 35; AUDV 0A is audible but not loud.
; The VBLANK clock silences the channel two frames later.
BeepStart:
    LDA #BEEP_FRAMES
    STA BeepTimer
    LDA #$0C
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0
    RTS

; =============================================================================
; THE PHASE POINTERS — one 16-bit pointer per pre-shifted phase
; =============================================================================
; The fill needs a runtime block base, so the eight low bytes and eight high
; bytes are kept as two small tables.  X = Phase selects the entry; the
; byte index is added to the low byte and the carry goes into the high byte.
PhasePtrLo:
    !byte <(ShiftedTable + 0*PHASE_BYTES), <(ShiftedTable + 1*PHASE_BYTES)
    !byte <(ShiftedTable + 2*PHASE_BYTES), <(ShiftedTable + 3*PHASE_BYTES)
    !byte <(ShiftedTable + 4*PHASE_BYTES), <(ShiftedTable + 5*PHASE_BYTES)
    !byte <(ShiftedTable + 6*PHASE_BYTES), <(ShiftedTable + 7*PHASE_BYTES)
PhasePtrHi:
    !byte >(ShiftedTable + 0*PHASE_BYTES), >(ShiftedTable + 1*PHASE_BYTES)
    !byte >(ShiftedTable + 2*PHASE_BYTES), >(ShiftedTable + 3*PHASE_BYTES)
    !byte >(ShiftedTable + 4*PHASE_BYTES), >(ShiftedTable + 5*PHASE_BYTES)
    !byte >(ShiftedTable + 6*PHASE_BYTES), >(ShiftedTable + 7*PHASE_BYTES)

; =============================================================================
; THE PRE-SHIFTED MESSAGE — 8 phases x 8 rows x 15 bytes = 960 bytes
; =============================================================================
; The message is "KERNEL MASTERY" (14 characters).  Each row's 15th byte is
; a zero pad: it is never read by the six-column window, but the shift of the
; last real byte needs it.  The bytes are generated from the font below with
; the formula in the source header.  The table is row-major inside a phase;
; the lesson's fill turns it into the score buffer's column-major order.
ShiftedTable:
    ; --- phase 0: every byte shifted left 0 pixel(s) ---
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; phase 0, font row 0
    !byte $88,$F8,$88,$88,$F8,$F8,$00,$88,$88,$F0,$20,$F8,$88,$20,$00   ; phase 0, font row 1
    !byte $90,$80,$90,$88,$80,$80,$00,$88,$88,$08,$20,$80,$90,$20,$00   ; phase 0, font row 2
    !byte $A0,$80,$A0,$88,$80,$80,$00,$88,$88,$08,$20,$80,$A0,$20,$00   ; phase 0, font row 3
    !byte $C0,$F0,$F0,$98,$F0,$80,$00,$A8,$F8,$70,$20,$F0,$F0,$20,$00   ; phase 0, font row 4
    !byte $A0,$80,$88,$A8,$80,$80,$00,$A8,$88,$80,$20,$80,$88,$50,$00   ; phase 0, font row 5
    !byte $90,$80,$88,$C8,$80,$80,$00,$D8,$88,$80,$20,$80,$88,$88,$00   ; phase 0, font row 6
    !byte $88,$F8,$F0,$88,$F8,$80,$00,$88,$70,$78,$F8,$F8,$F0,$88,$00   ; phase 0, font row 7
    ; --- phase 1: every byte shifted left 1 pixel(s) ---
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; phase 1, font row 0
    !byte $11,$F1,$11,$11,$F1,$F0,$01,$11,$11,$E0,$41,$F1,$10,$40,$00   ; phase 1, font row 1
    !byte $21,$01,$21,$11,$01,$00,$01,$11,$10,$10,$41,$01,$20,$40,$00   ; phase 1, font row 2
    !byte $41,$01,$41,$11,$01,$00,$01,$11,$10,$10,$41,$01,$40,$40,$00   ; phase 1, font row 3
    !byte $81,$E1,$E1,$31,$E1,$00,$01,$51,$F0,$E0,$41,$E1,$E0,$40,$00   ; phase 1, font row 4
    !byte $41,$01,$11,$51,$01,$00,$01,$51,$11,$00,$41,$01,$10,$A0,$00   ; phase 1, font row 5
    !byte $21,$01,$11,$91,$01,$00,$01,$B1,$11,$00,$41,$01,$11,$10,$00   ; phase 1, font row 6
    !byte $11,$F1,$E1,$11,$F1,$00,$01,$10,$E0,$F1,$F1,$F1,$E1,$10,$00   ; phase 1, font row 7
    ; --- phase 2: every byte shifted left 2 pixel(s) ---
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; phase 2, font row 0
    !byte $23,$E2,$22,$23,$E3,$E0,$02,$22,$23,$C0,$83,$E2,$20,$80,$00   ; phase 2, font row 1
    !byte $42,$02,$42,$22,$02,$00,$02,$22,$20,$20,$82,$02,$40,$80,$00   ; phase 2, font row 2
    !byte $82,$02,$82,$22,$02,$00,$02,$22,$20,$20,$82,$02,$80,$80,$00   ; phase 2, font row 3
    !byte $03,$C3,$C2,$63,$C2,$00,$02,$A3,$E1,$C0,$83,$C3,$C0,$80,$00   ; phase 2, font row 4
    !byte $82,$02,$22,$A2,$02,$00,$02,$A2,$22,$00,$82,$02,$21,$40,$00   ; phase 2, font row 5
    !byte $42,$02,$23,$22,$02,$00,$03,$62,$22,$00,$82,$02,$22,$20,$00   ; phase 2, font row 6
    !byte $23,$E3,$C2,$23,$E2,$00,$02,$21,$C1,$E3,$E3,$E3,$C2,$20,$00   ; phase 2, font row 7
    ; --- phase 3: every byte shifted left 3 pixel(s) ---
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; phase 3, font row 0
    !byte $47,$C4,$44,$47,$C7,$C0,$04,$44,$47,$81,$07,$C4,$41,$00,$00   ; phase 3, font row 1
    !byte $84,$04,$84,$44,$04,$00,$04,$44,$40,$41,$04,$04,$81,$00,$00   ; phase 3, font row 2
    !byte $04,$05,$04,$44,$04,$00,$04,$44,$40,$41,$04,$05,$01,$00,$00   ; phase 3, font row 3
    !byte $07,$87,$84,$C7,$84,$00,$05,$47,$C3,$81,$07,$87,$81,$00,$00   ; phase 3, font row 4
    !byte $04,$04,$45,$44,$04,$00,$05,$44,$44,$01,$04,$04,$42,$80,$00   ; phase 3, font row 5
    !byte $84,$04,$46,$44,$04,$00,$06,$C4,$44,$01,$04,$04,$44,$40,$00   ; phase 3, font row 6
    !byte $47,$C7,$84,$47,$C4,$00,$04,$43,$83,$C7,$C7,$C7,$84,$40,$00   ; phase 3, font row 7
    ; --- phase 4: every byte shifted left 4 pixel(s) ---
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; phase 4, font row 0
    !byte $8F,$88,$88,$8F,$8F,$80,$08,$88,$8F,$02,$0F,$88,$82,$00,$00   ; phase 4, font row 1
    !byte $08,$09,$08,$88,$08,$00,$08,$88,$80,$82,$08,$09,$02,$00,$00   ; phase 4, font row 2
    !byte $08,$0A,$08,$88,$08,$00,$08,$88,$80,$82,$08,$0A,$02,$00,$00   ; phase 4, font row 3
    !byte $0F,$0F,$09,$8F,$08,$00,$0A,$8F,$87,$02,$0F,$0F,$02,$00,$00   ; phase 4, font row 4
    !byte $08,$08,$8A,$88,$08,$00,$0A,$88,$88,$02,$08,$08,$85,$00,$00   ; phase 4, font row 5
    !byte $08,$08,$8C,$88,$08,$00,$0D,$88,$88,$02,$08,$08,$88,$80,$00   ; phase 4, font row 6
    !byte $8F,$8F,$08,$8F,$88,$00,$08,$87,$07,$8F,$8F,$8F,$08,$80,$00   ; phase 4, font row 7
    ; --- phase 5: every byte shifted left 5 pixel(s) ---
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; phase 5, font row 0
    !byte $1F,$11,$11,$1F,$1F,$00,$11,$11,$1E,$04,$1F,$11,$04,$00,$00   ; phase 5, font row 1
    !byte $10,$12,$11,$10,$10,$00,$11,$11,$01,$04,$10,$12,$04,$00,$00   ; phase 5, font row 2
    !byte $10,$14,$11,$10,$10,$00,$11,$11,$01,$04,$10,$14,$04,$00,$00   ; phase 5, font row 3
    !byte $1E,$1E,$13,$1E,$10,$00,$15,$1F,$0E,$04,$1E,$1E,$04,$00,$00   ; phase 5, font row 4
    !byte $10,$11,$15,$10,$10,$00,$15,$11,$10,$04,$10,$11,$0A,$00,$00   ; phase 5, font row 5
    !byte $10,$11,$19,$10,$10,$00,$1B,$11,$10,$04,$10,$11,$11,$00,$00   ; phase 5, font row 6
    !byte $1F,$1E,$11,$1F,$10,$00,$11,$0E,$0F,$1F,$1F,$1E,$11,$00,$00   ; phase 5, font row 7
    ; --- phase 6: every byte shifted left 6 pixel(s) ---
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; phase 6, font row 0
    !byte $3E,$22,$22,$3E,$3E,$00,$22,$22,$3C,$08,$3E,$22,$08,$00,$00   ; phase 6, font row 1
    !byte $20,$24,$22,$20,$20,$00,$22,$22,$02,$08,$20,$24,$08,$00,$00   ; phase 6, font row 2
    !byte $20,$28,$22,$20,$20,$00,$22,$22,$02,$08,$20,$28,$08,$00,$00   ; phase 6, font row 3
    !byte $3C,$3C,$26,$3C,$20,$00,$2A,$3E,$1C,$08,$3C,$3C,$08,$00,$00   ; phase 6, font row 4
    !byte $20,$22,$2A,$20,$20,$00,$2A,$22,$20,$08,$20,$22,$14,$00,$00   ; phase 6, font row 5
    !byte $20,$22,$32,$20,$20,$00,$36,$22,$20,$08,$20,$22,$22,$00,$00   ; phase 6, font row 6
    !byte $3E,$3C,$22,$3E,$20,$00,$22,$1C,$1E,$3E,$3E,$3C,$22,$00,$00   ; phase 6, font row 7
    ; --- phase 7: every byte shifted left 7 pixel(s) ---
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; phase 7, font row 0
    !byte $7C,$44,$44,$7C,$7C,$00,$44,$44,$78,$10,$7C,$44,$10,$00,$00   ; phase 7, font row 1
    !byte $40,$48,$44,$40,$40,$00,$44,$44,$04,$10,$40,$48,$10,$00,$00   ; phase 7, font row 2
    !byte $40,$50,$44,$40,$40,$00,$44,$44,$04,$10,$40,$50,$10,$00,$00   ; phase 7, font row 3
    !byte $78,$78,$4C,$78,$40,$00,$54,$7C,$38,$10,$78,$78,$10,$00,$00   ; phase 7, font row 4
    !byte $40,$44,$54,$40,$40,$00,$54,$44,$40,$10,$40,$44,$28,$00,$00   ; phase 7, font row 5
    !byte $40,$44,$64,$40,$40,$00,$6C,$44,$40,$10,$40,$44,$44,$00,$00   ; phase 7, font row 6
    !byte $7C,$78,$44,$7C,$40,$00,$44,$38,$3C,$7C,$7C,$78,$44,$00,$00   ; phase 7, font row 7

; =============================================================================
; THE FONT — 39 glyphs x 8 bytes, bottom-up, bit 7 = the leftmost pixel
; =============================================================================
; The runtime does not read the font: the pre-shifted table above is the
; runtime copy.  The font is kept here as the glyph atlas, so every byte of
; the table can be checked against a visible 5x7 shape and regenerated with
; the header's formula.  Byte 0 is the bottom row and is $00 in every glyph;
; bytes 1-7 are the lit rows, so the visible block is seven scanlines.
Font:
    ; A
    !byte $00,$88,$88,$88,$F8,$88,$88,$70
    ; B
    !byte $00,$F0,$88,$88,$F0,$88,$88,$F0
    ; C
    !byte $00,$70,$88,$80,$80,$80,$88,$70
    ; D
    !byte $00,$F0,$88,$88,$88,$88,$88,$F0
    ; E
    !byte $00,$F8,$80,$80,$F0,$80,$80,$F8
    ; F
    !byte $00,$80,$80,$80,$F0,$80,$80,$F8
    ; G
    !byte $00,$70,$88,$88,$B8,$80,$88,$70
    ; H
    !byte $00,$88,$88,$88,$F8,$88,$88,$88
    ; I
    !byte $00,$F8,$20,$20,$20,$20,$20,$F8
    ; J
    !byte $00,$60,$90,$90,$10,$10,$10,$38
    ; K
    !byte $00,$88,$90,$A0,$C0,$A0,$90,$88
    ; L
    !byte $00,$F8,$80,$80,$80,$80,$80,$80
    ; M
    !byte $00,$88,$88,$88,$A8,$A8,$D8,$88
    ; N
    !byte $00,$88,$88,$88,$98,$A8,$C8,$88
    ; O
    !byte $00,$70,$88,$88,$88,$88,$88,$70
    ; P
    !byte $00,$80,$80,$80,$F0,$88,$88,$F0
    ; Q
    !byte $00,$68,$90,$A8,$88,$88,$88,$70
    ; R
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0
    ; S
    !byte $00,$F0,$08,$08,$70,$80,$80,$78
    ; T
    !byte $00,$20,$20,$20,$20,$20,$20,$F8
    ; U
    !byte $00,$70,$88,$88,$88,$88,$88,$88
    ; V
    !byte $00,$20,$50,$88,$88,$88,$88,$88
    ; W
    !byte $00,$88,$D8,$A8,$A8,$88,$88,$88
    ; X
    !byte $00,$88,$88,$50,$20,$50,$88,$88
    ; Y
    !byte $00,$20,$20,$20,$20,$50,$88,$88
    ; Z
    !byte $00,$F8,$80,$40,$20,$10,$08,$F8
    ; 0
    !byte $00,$70,$88,$C8,$A8,$98,$88,$70
    ; 1
    !byte $00,$F8,$20,$20,$20,$20,$60,$20
    ; 2
    !byte $00,$F8,$40,$20,$10,$08,$88,$70
    ; 3
    !byte $00,$F0,$08,$08,$70,$08,$08,$F0
    ; 4
    !byte $00,$10,$10,$F8,$90,$50,$30,$10
    ; 5
    !byte $00,$70,$88,$08,$08,$F0,$80,$F8
    ; 6
    !byte $00,$70,$88,$88,$F0,$80,$88,$70
    ; 7
    !byte $00,$40,$40,$40,$20,$10,$08,$F8
    ; 8
    !byte $00,$70,$88,$88,$70,$88,$88,$70
    ; 9
    !byte $00,$70,$88,$08,$78,$88,$88,$70
    ; space
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    ; dash
    !byte $00,$00,$00,$00,$F8,$00,$00,$00
    ; period
    !byte $00,$60,$60,$00,$00,$00,$00,$00

; =============================================================================
; THE STARFIELD — three page-aligned 183-byte planes
; =============================================================================
; Row r of the world is StarPF0+r, StarPF1+r and StarPF2+r.  The planes are
; page-aligned, so LDA StarPFx,Y with Y=0..182 never crosses a page.  PF0
; uses only bits 4-7 (chunks 0-3); PF1 covers chunks 4-11 and PF2 chunks
; 12-19.  The pattern is sparse (about 57 lit chunks before the reflection).
    !align 255, 0
StarPF0:
    !byte $00,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 0-15
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$70   ; rows 16-31
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$00,$00   ; rows 32-47
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 48-63
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 64-79
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 80-95
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 96-111
    !byte $70,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 112-127
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$00,$00,$00,$00   ; rows 128-143
    !byte $00,$00,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 144-159
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$00,$00,$00,$00   ; rows 160-175
    !byte $00,$00,$00,$00,$00,$00,$00   ; rows 176-182

    !align 255, 0
StarPF1:
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$00   ; rows 0-15
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 16-31
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$02,$00,$00,$00,$00,$01,$00,$00   ; rows 32-47
    !byte $02,$00,$00,$00,$00,$30,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 48-63
    !byte $00,$00,$00,$18,$00,$00,$00,$00,$00,$00,$00,$03,$00,$00,$00,$0C   ; rows 64-79
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 80-95
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 96-111
    !byte $00,$00,$00,$00,$00,$00,$00,$08,$00,$00,$00,$00,$00,$00,$04,$00   ; rows 112-127
    !byte $00,$00,$00,$00,$00,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 128-143
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40   ; rows 144-159
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 160-175
    !byte $00,$00,$00,$00,$00,$00,$00   ; rows 176-182

    !align 255, 0
StarPF2:
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 0-15
    !byte $00,$60,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$38,$00,$00,$00   ; rows 16-31
    !byte $00,$00,$00,$00,$00,$00,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 32-47
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$C0,$00,$00,$00,$00,$00   ; rows 48-63
    !byte $00,$00,$00,$00,$00,$08,$00,$00,$00,$00,$00,$00,$00,$00,$F8,$00   ; rows 64-79
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$00,$00,$00   ; rows 80-95
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$00,$00,$00,$00,$00   ; rows 96-111
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 112-127
    !byte $00,$00,$00,$00,$02,$00,$04,$04,$00,$E0,$00,$00,$00,$00,$00,$00   ; rows 128-143
    !byte $00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 144-159
    !byte $00,$00,$00,$00,$C0,$02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$08   ; rows 160-175
    !byte $00,$00,$01,$00,$00,$00,$00   ; rows 176-182

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
