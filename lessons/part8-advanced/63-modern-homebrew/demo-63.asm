; =============================================================================
; LESSON 63: Modern Homebrew — Dev Carts and Community
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "the attract mode": a 4,096-byte production-value title screen.  Two
;   scenes share one 262-line frame:
;
;     Scene 0 — the title.  A large playfield "RTB" logo (seven chunk rows,
;       eight scanlines each) over a 64-row starfield; solid colour-cycling
;       border bands across the top and bottom; a six-character scrolling
;       marquee ("MODERN HOMEBREW ") drawn by P0/P1 in the Lesson 55
;       six-column window; and a 32-note TIA tune on channel 0.
;
;     Scene 1 — the credits.  A fixed dark-blue field, gold stars and border
;       bands, and a four-line white credit block ("RACING / THE / BEAM /
;       THANKS") drawn by the same P0/P1 window.
;
;   Fire advances to the credits; SELECT returns to the title.  An auto-demo
;   advances title -> credits after 300 frames (5 s at 60 Hz) so the two
;   captures are reproducible without input; the credits screen then stays
;   until SELECT.  Fire and SELECT are edge-triggered: a held button acts
;   once.
;
;   The title's marquee scrolls one pixel every four frames.  Scroll 0..80
;   selects a phase (0..7) and a character offset (0..10).  The message is
;   stored pre-shifted in eight 128-byte phase blocks, the Lesson 55
;   technique; FillMarquee copies six columns into the score library's
;   buffer and ScoreDraw draws the nine-line band.
;
;   The tune is a 32-note table.  TuneTimer counts down in frames; at zero
;   the next note writes AUDF0, AUDC0=$0C and AUDV0=$0A.  The note tables are
;   two parallel 32-byte arrays (frequency, duration), so the engine needs
;   only an index and a timer.  The tune restarts on a scene change.
;   Javatari starts muted; click the player to hear it.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5, OverscanStart 229/6.
;
; The title picture (192 visible lines):
;   rows   0-7    the top border band (all 20 chunks lit)
;   rows   8-16   the marquee (line 8 setup, lines 9-16 glyphs).  ScoreDraw
;                 writes only P0/P1, so the border's PF bytes stay latched
;                 behind the text and the visible top bar is 17 lines tall.
;   rows  17-47   starfield (31 lines)
;   rows  48-103  the RTB logo (7 rows x 8 lines), stars OR'd in
;   rows 104-183  starfield (80 lines)
;   rows 184-191  the bottom border band
;
; The credits picture (192 visible lines):
;   rows   0-7    the top border band
;   rows   8-31   starfield (24 lines)
;   rows  32-40   credit line 1 (row 32 setup, rows 33-40 glyphs)
;   rows  41-71   starfield (31 lines)
;   rows  72-80   credit line 2
;   rows  81-111  starfield (31 lines)
;   rows 112-120  credit line 3
;   rows 121-151  starfield (31 lines)
;   rows 152-160  credit line 4
;   rows 161-183  starfield (23 lines)
;   rows 184-191  the bottom border band
;   The text macro ends with an aligning WSYNC: the last glyph row and the
;   first star row share a line in the register timeline, and the WSYNC
;   makes the next loop start on a fresh line.  Each block is 40 lines.
;   The macro writes only P0/P1; the playfield bytes stay latched at the
;   last star row for the eight text lines, so a few gold chunks repeat
;   behind a word.  The star loops resume on the line after the block.
;
; The starfield:
;   StarPF0/1/2 are 64-byte planes, page-aligned.  The kernel indexes them
;   with Y & $3F, so the 64-row pattern repeats three times down the screen.
;   The pattern is sparse: one or two 4-pixel chunks per row.  The logo zone
;   is an expanded table: each of the seven logo rows is repeated eight times
;   with !fill and OR'd with the star plane at run time, so the compact
;   LOGO_Rn_* constants are the only logo definition.
;
; Cycle ledger (the line is 76 cycles; every visible line fits):
;   star loop, title:   TYA+AND+TAX (6) + three plane loads/stores (21) +
;                       STA WSYNC+INY+CPY+BNE (10) = 37.
;   star loop, credits: the same 37 plus the two GRP clears (8) = 45.
;   logo loop:          6 + (LDA 4 + ORA 4 + STA 3) x 3 + 10 = 49;
;                       50 on a row whose table read crosses a page.
;   top/bottom border:  21 on the first line (the LDA), 19 on the rest.
;   ScoreDraw and the text-line macro are the Lesson 55 sequence; its stores
;   are inside the 76-cycle line by construction (Lesson 55 measured them).
;
; Checkpoints (Stella scanline/cycle, and the A register):
;   StartFrame    259/3  the first VSYNC instruction
;   VblankStart   0/5    the first VBLANK instruction
;   BodyStart     37/5   the scene dispatch
;   SceneRead     37/8   A = 0 (title) or 1 (credits), every frame
;   OverscanStart 229/6  the first overscan instruction (title path)
;   CreditsOverscan 229/6 the first overscan instruction (credits path)
;   ScrollRead    A = the marquee offset, 0..80
;   TunePtrRead   A = the note index, 0..31
;   FrameRead     A = the free-running frame count, 0..255
;
; RAM map (+clean_start zeroes every byte):
;   $80 Scene          0 = title, 1 = credits
;   $81 Frame          the free-running frame counter (a byte)
;   $82 Scroll         the marquee offset, 0..80
;   $83 TunePtr        the note index, 0..31
;   $84 TuneTimer      frames left on the current note
;   $85 PrevFire       fire state last frame
;   $86 PrevSelect     SELECT state last frame
;   $87 Startup        frames left before fire is trusted
;   $88 NewFire        this frame's fire 0 -> 1 edge
;   $89 Scratch        SELECT's pressed level
;   $8A AutoTimerLo    the 300-frame auto-demo timer, low byte
;   $8B AutoTimerHi    the timer, high byte
;   $8C ColorTimer     frames left before the next colour
;   $8D ColorIndex     0..7 into TitleColors
;   $8E ScrollTimer    the four-frame scroll divider
;   $8F Phase          Scroll & 7
;   $90 ByteIndex      Scroll >> 3, 0..10
;   $91 TextPtrLo      the pre-shifted row pointer
;   $92 TextPtrHi
;   $93-$9F free (13 bytes)
;   $A0-$A5 ScoreDigits  the score library's six digits (unused)
;   $A6 ScoreRow       the score library's/text macro's row counter
;   $A7 ScoreTmp       the score library's/text macro's scratch
;   $A8-$D7 ScoreBuf   the score library's 48-byte column-major buffer
;   $D8-$F7 free (32 bytes)
;   $F8-$FF stack
;
; Build: acme -f plain -o build/demo-63.bin \
;        lessons/part8-advanced/63-modern-homebrew/demo-63.asm
; Run:   stella build/demo-63.bin     (click the screen to unmute the tune)
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

SCREEN_LINES   = 192     ; the visible picture
TOP_BORDER     = 8       ; rows 0-7 are the top band
BOTTOM_BORDER  = 184     ; rows 184-191 are the bottom band

LOGO_TOP       = 48      ; the RTB logo's first row
LOGO_ROWS      = 7       ; seven chunk rows
LOGO_LINES     = LOGO_ROWS * 8   ; eight scanlines per chunk row = 56
LOGO_END       = LOGO_TOP + LOGO_LINES

MSG_LEN        = 16      ; "MODERN HOMEBREW "
MSG_WINDOW     = 6       ; six 8-pixel columns
SCROLL_MAX     = MSG_LEN * 8 - MSG_WINDOW * 8   ; 80
SCROLL_PERIOD  = 4       ; one pixel every four frames

TEXT_ROWS      = 8       ; eight glyph rows

CRED1_TOP      = 32      ; the four credit blocks' setup rows
CRED2_TOP      = 72
CRED3_TOP      = 112
CRED4_TOP      = 152

TUNE_LEN       = 32      ; 32 notes, then the tune wraps
TUNE_AUDC      = $0C     ; the div-6 pure tone from Lesson 35
TUNE_AUDV      = $0A     ; audible, not loud

SCENE_TITLE    = 0
SCENE_CREDITS  = 1

AUTO_FRAMES    = 300     ; title -> credits after 300 frames (5 s)
AUTO_LO        = AUTO_FRAMES & $FF
AUTO_HI        = AUTO_FRAMES >> 8

C_TITLE_BG     = $02     ; the title's deep-space background
C_CRED_BG      = $84     ; the credits' blue field
C_CRED_PF      = $1A     ; the credits' gold stars and bands
C_WHITE        = $0E     ; the text and the title's first colour


; The logo rows, top to bottom, with no border bits.  Chunks 3-16 hold
; "RTB": R at 3-6, T at 8-11, B at 13-16.  Each row is one playfield
; byte per register.  The !fill block below repeats each row eight times.
LOGO_R0_PF0 = $80
LOGO_R0_PF1 = $EF
LOGO_R0_PF2 = $0E
LOGO_R1_PF0 = $80
LOGO_R1_PF1 = $26
LOGO_R1_PF2 = $12
LOGO_R2_PF0 = $80
LOGO_R2_PF1 = $26
LOGO_R2_PF2 = $12
LOGO_R3_PF0 = $80
LOGO_R3_PF1 = $C6
LOGO_R3_PF2 = $0E
LOGO_R4_PF0 = $80
LOGO_R4_PF1 = $46
LOGO_R4_PF2 = $12
LOGO_R5_PF0 = $80
LOGO_R5_PF1 = $26
LOGO_R5_PF2 = $12
LOGO_R6_PF0 = $80
LOGO_R6_PF1 = $26
LOGO_R6_PF2 = $0E

; The frame arithmetic is a build-time assertion, not a comment.
!if LOGO_END > BOTTOM_BORDER {
    !error "the logo must end before the bottom border"
}
!if CRED4_TOP + 8 > BOTTOM_BORDER {
    !error "the last credit block must end before the bottom border"
}
!if SCROLL_MAX != 80 {
    !error "the message must scroll to offset 80"
}
!if MSG_LEN != 16 {
    !error "the pre-shifted table is generated for exactly 16 characters"
}

; =============================================================================
; RAM ALLOCATION ($80-$92; +clean_start zeroes every byte)
; =============================================================================
Scene         = $80   ; 0 = title, 1 = credits
Frame         = $81   ; the free-running frame counter (a byte)
Scroll        = $82   ; the marquee offset, 0..80
TunePtr       = $83   ; the note index, 0..31
TuneTimer     = $84   ; frames left on the current note
PrevFire      = $85   ; fire state last frame
PrevSelect    = $86   ; SELECT state last frame
Startup       = $87   ; frames left before fire is trusted
NewFire       = $88   ; this frame's fire 0 -> 1 edge
Scratch       = $89   ; SELECT's pressed level
AutoTimerLo   = $8A   ; the 300-frame auto-demo timer, low byte
AutoTimerHi   = $8B   ; the timer, high byte
ColorTimer    = $8C   ; frames left before the next colour
ColorIndex    = $8D   ; 0..7 into TitleColors
ScrollTimer   = $8E   ; the four-frame scroll divider
Phase         = $8F   ; Scroll & 7
ByteIndex     = $90   ; Scroll >> 3, 0..10
TextPtrLo     = $91   ; the pre-shifted row pointer
TextPtrHi     = $92
;
; $93-$9F are free.  The score library owns $A0-$D7 (ScoreDigits,
; ScoreRow, ScoreTmp and the 48-byte ScoreBuf).  $D8-$F7 are free.
; The stack lives at $F8-$FF; the demo nests two levels (ScoreSetup calls
; ScoreSetupP0/P1).  The exercise's score calls add two more, which fills the
; 8-byte reservation; plan the stack before adding them.

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreSetup positions P0/P1 at X=56/64, enables three-copy close mode and
; VDEL, and strobes the frame's only HMOVE.  ScoreDraw draws the six-column
; marquee.  The library owns $A0-$D7.  It is sourced after the ROM origin
; because it contains code; the reset vector still points at this Reset.
    * = $F000

    !source "include/score.asm"

; =============================================================================
; THE TEXT-LINE MACRO — the Lesson 55 six-column sequence, reused
; =============================================================================
; A = the base of a 48-byte column-major block (six columns x eight rows,
; bottom-up).  The eight iterations draw eight visible lines.  The closing
; WSYNC makes the caller's next code start on a fresh line, so the star loop
; that follows draws exactly 31 lines before the next text block.  The NOP
; and CPX are the timing the score kernel uses; do not "clean them up".
!macro text_line .base {
    LDA #TEXT_ROWS - 1
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
    STA WSYNC               ; align the next star loop to a fresh line
}

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the fire button)

    ; Scene 0, the first frame, the first note, the auto-demo armed.
    LDA #SCENE_TITLE
    STA Scene
    LDA #$00
    STA Frame
    STA Scroll
    STA ScrollTimer
    STA TunePtr
    STA PrevFire
    STA PrevSelect
    STA NewFire
    STA ColorIndex
    LDA #1
    STA TuneTimer           ; the first TuneStep loads note 0
    LDA #8
    STA Startup             ; ignore the fire line while the console settles
    STA ColorTimer
    LDA #AUTO_LO
    STA AutoTimerLo
    LDA #AUTO_HI
    STA AutoTimerHi

    ; The fixed TIA state.  The scene setup changes the colours each frame.
    LDA #C_TITLE_BG
    STA COLUBK
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    STA COLUPF
    LDA #$00
    STA CTRLPF              ; repeat playfield; the ball is unused
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    STA ENABL
    STA ENAM0
    STA ENAM1
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

; -----------------------------------------------------------------------------
; 1. THE TUNE — one note at a time on channel 0
; -----------------------------------------------------------------------------
; TuneTimer counts down every frame.  At zero the current index writes the
; note, the timer reloads from TuneDur, and the index advances (31 -> 0).
; The checkpoint reports the index of the note that starts on this frame.
    JSR TuneStep

; -----------------------------------------------------------------------------
; 2. FIRE — the 0 -> 1 edge moves to the credits
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  EOR turns that into a 1; the
; EOR/AND pair keeps only a new press, so holding the button acts once.
; Startup is eight frames.  While it counts down NewFire is forced clear and
; PrevFire is held at 0, so a button held from power-on still produces one
; edge when the console has settled (this is what -holdjoy0 F relies on).
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
    STA PrevFire
    JMP FirePrevDone        ; do not overwrite PrevFire while settling
FireEdgeReady:
    LDA NewFire
    BEQ NoFireEdge
    LDA #SCENE_CREDITS
    STA Scene
    LDA #0
    STA AutoTimerLo         ; a manual change disarms the auto-demo
    STA AutoTimerHi
    STA TunePtr             ; and restarts the tune
    LDA #1
    STA TuneTimer
NoFireEdge:
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire
FirePrevDone:

; -----------------------------------------------------------------------------
; 3. SELECT — the 0 -> 1 edge returns to the title and rearms the auto-demo
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  SELECT also rewinds the marquee so
; the title always starts at "MODERN".  There is no SELECT debounce: a held
; switch acts once because PrevSelect remembers the level.
    LDA SWCHB
    AND #$02
    EOR #$02                ; 1 = pressed
    STA Scratch
    EOR PrevSelect
    AND Scratch
    BEQ NoSelectEdge
    LDA #SCENE_TITLE
    STA Scene
    LDA #AUTO_LO
    STA AutoTimerLo
    LDA #AUTO_HI
    STA AutoTimerHi
    LDA #0
    STA Scroll
    STA ScrollTimer
    STA TunePtr
    LDA #1
    STA TuneTimer
NoSelectEdge:
    LDA Scratch
    STA PrevSelect

; -----------------------------------------------------------------------------
; 4. THE AUTO-DEMO — title -> credits after 300 frames
; -----------------------------------------------------------------------------
; The timer runs only on the title.  Fire clears it and SELECT reloads it, so
; a manual scene is never overruled a frame later.  The credits screen stays
; until SELECT: the captures can wait for it without racing a return trip.
    LDA Scene
    BNE NoAutoDemo
    LDA AutoTimerLo
    SEC
    SBC #1
    STA AutoTimerLo
    BCS AutoNoBorrow
    DEC AutoTimerHi
AutoNoBorrow:
    LDA AutoTimerLo
    ORA AutoTimerHi
    BNE NoAutoDemo
    LDA #SCENE_CREDITS
    STA Scene
    LDA #0
    STA TunePtr
    LDA #1
    STA TuneTimer
NoAutoDemo:

; -----------------------------------------------------------------------------
; 5. THE MARQUEE CLOCK — one pixel every four frames
; -----------------------------------------------------------------------------
; The scroll runs in both scenes; only the title draws it.  The wrap at 80
; returns to the first six-character window ("MODERN").
    INC ScrollTimer
    LDA ScrollTimer
    AND #(SCROLL_PERIOD - 1)
    BNE NoScrollStep
    INC Scroll
    LDA Scroll
    CMP #(SCROLL_MAX + 1)
    BCC ScrollStore
    LDA #$00
ScrollStore:
    STA Scroll
NoScrollStep:
    LDA Scroll
ScrollRead:                 ; checkpoint: A = the marquee offset, 0..80
    NOP

; -----------------------------------------------------------------------------
; 6. THE COLOUR CLOCK — one palette entry every eight frames
; -----------------------------------------------------------------------------
; Only the title uses ColorIndex; the credits scene writes a fixed gold.
    DEC ColorTimer
    BNE NoColorStep
    LDA #8
    STA ColorTimer
    INC ColorIndex
    LDA ColorIndex
    AND #$07
    STA ColorIndex
NoColorStep:

; -----------------------------------------------------------------------------
; 7. THE FRAME COUNTER
; -----------------------------------------------------------------------------
    INC Frame
    LDA Frame
FrameRead:                  ; checkpoint: A = the free-running frame count
    NOP

; -----------------------------------------------------------------------------
; 8. SCENE SETUP — colours, the marquee fill, the one HMOVE
; -----------------------------------------------------------------------------
; ScoreSetup runs in both scenes: the title's ScoreDraw and the credits'
; text macro both need the three-copy window and VDEL.  It strobes the
; frame's only HMOVE, which applies HMP0 and HMP1 in one HBLANK.
    LDA Scene
    BEQ SetupTitle
SetupCredits:
    LDA #C_CRED_BG
    STA COLUBK
    LDA #C_CRED_PF
    STA COLUPF
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    JMP DisplayCommon

SetupTitle:
    LDA #C_TITLE_BG
    STA COLUBK
    LDX ColorIndex
    LDA TitleColors,X
    STA COLUPF
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    JSR FillMarquee

DisplayCommon:
    LDA #$00
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    JSR ScoreSetup
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; THE VISIBLE PICTURE — the scene dispatch
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDA Scene
SceneRead:                  ; checkpoint: A = 0 (title) or 1 (credits)
    BEQ TitleKernel
    JMP CreditsKernel

; =============================================================================
; SCENE 0 — THE TITLE
; =============================================================================
TitleKernel:
    ; --- rows 0-7: the top border band ------------------------------------
    LDY #0
    LDA #$FF
TitleTopBorder:
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
    INY
    CPY #TOP_BORDER
    BNE TitleTopBorder

    ; --- rows 8-16: the marquee -------------------------------------------
    ; ScoreDraw's line 0 is a setup line; the glyphs show on lines 9-16.
    JSR ScoreDraw

    ; --- rows 17-47: the starfield above the logo ------------------------
    LDY #17
TitleStarsTop:
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    STA WSYNC
    INY
    CPY #LOGO_TOP
    BNE TitleStarsTop

    ; --- rows 48-103: the logo, stars OR'd into the gaps ------------------
    ; LogoZonePF* - LOGO_TOP,Y turns the global row into the expanded
    ; table's 0..55 index without a second counter in RAM.
    LDY #LOGO_TOP
TitleLogo:
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    ORA LogoZonePF0-LOGO_TOP,Y
    STA PF0
    LDA StarPF1,X
    ORA LogoZonePF1-LOGO_TOP,Y
    STA PF1
    LDA StarPF2,X
    ORA LogoZonePF2-LOGO_TOP,Y
    STA PF2
    STA WSYNC
    INY
    CPY #LOGO_END
    BNE TitleLogo

    ; --- rows 104-183: the starfield below the logo ----------------------
    LDY #LOGO_END
TitleStarsBottom:
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    STA WSYNC
    INY
    CPY #BOTTOM_BORDER
    BNE TitleStarsBottom

    ; --- rows 184-191: the bottom border band ----------------------------
    LDA #$FF
    LDY #BOTTOM_BORDER
TitleBottomBorder:
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE TitleBottomBorder

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
; The two kernels each fall through to an identical block, so both paths
; reach the first overscan instruction at the same cycle.  The credits path
; has its own label for the state log; the instructions are the same.
OverscanStart:              ; checkpoint: scanline 229 on the title path
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SCENE 1 — THE CREDITS
; =============================================================================
CreditsKernel:
    ; --- rows 0-7: the top border band ------------------------------------
    LDY #0
    LDA #$FF
CreditsTopBorder:
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
    INY
    CPY #TOP_BORDER
    BNE CreditsTopBorder

    ; --- rows 8-31: stars above the first credit line ---------------------
    LDY #TOP_BORDER
CreditsStars1:
    LDA #$00
    STA GRP0                ; the players are blank on every star line
    STA GRP1
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    STA WSYNC
    INY
    CPY #CRED1_TOP
    BNE CreditsStars1

    +text_line CreditsLine1

    ; --- rows 40-71: stars between the first two credit lines ------------
    LDY #(CRED1_TOP + TEXT_ROWS + 1)
CreditsStars2:
    LDA #$00
    STA GRP0
    STA GRP1
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    STA WSYNC
    INY
    CPY #CRED2_TOP
    BNE CreditsStars2

    +text_line CreditsLine2

    ; --- rows 80-111: stars between the second and third lines -----------
    LDY #(CRED2_TOP + TEXT_ROWS + 1)
CreditsStars3:
    LDA #$00
    STA GRP0
    STA GRP1
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    STA WSYNC
    INY
    CPY #CRED3_TOP
    BNE CreditsStars3

    +text_line CreditsLine3

    ; --- rows 120-151: stars between the third and fourth lines ----------
    LDY #(CRED3_TOP + TEXT_ROWS + 1)
CreditsStars4:
    LDA #$00
    STA GRP0
    STA GRP1
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    STA WSYNC
    INY
    CPY #CRED4_TOP
    BNE CreditsStars4

    +text_line CreditsLine4

    ; --- rows 160-183: stars below the last credit line ------------------
    LDY #(CRED4_TOP + TEXT_ROWS + 1)
CreditsStars5:
    LDA #$00
    STA GRP0
    STA GRP1
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    STA WSYNC
    INY
    CPY #BOTTOM_BORDER
    BNE CreditsStars5

    ; --- rows 184-191: the bottom border band ----------------------------
    LDA #$FF
    LDY #BOTTOM_BORDER
CreditsBottomBorder:
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE CreditsBottomBorder

CreditsOverscan:            ; checkpoint: scanline 229 on the credits path
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; FillMarquee — copy six columns from the pre-shifted phase block
; =============================================================================
; Phase = Scroll & 7 selects one of eight 128-byte blocks.  ByteIndex =
; Scroll >> 3 selects the first of the six 8-pixel columns.  The source row
; is 16 bytes; a six-byte read therefore never crosses a page.  The
; destination is ScoreBuf, column-major and bottom-up, as ScoreDraw expects.
FillMarquee:
    LDA Scroll
    AND #$07
    STA Phase
    LDA Scroll
    LSR
    LSR
    LSR
    STA ByteIndex

    LDX Phase
    LDA PhasePtrLo,X
    CLC
    ADC ByteIndex
    STA TextPtrLo
    LDA PhasePtrHi,X
    ADC #$00
    STA TextPtrHi

    LDX #0                  ; the glyph row, 0 (bottom) to 7 (top)
FillRow:
    LDY #0
    LDA (TextPtrLo),Y
    STA ScoreBuf+0,X
    INY
    LDA (TextPtrLo),Y
    STA ScoreBuf+8,X
    INY
    LDA (TextPtrLo),Y
    STA ScoreBuf+16,X
    INY
    LDA (TextPtrLo),Y
    STA ScoreBuf+24,X
    INY
    LDA (TextPtrLo),Y
    STA ScoreBuf+32,X
    INY
    LDA (TextPtrLo),Y
    STA ScoreBuf+40,X
    LDA TextPtrLo
    CLC
    ADC #16                 ; the next row is 16 bytes on
    STA TextPtrLo
    BCC FillNoCarry
    INC TextPtrHi
FillNoCarry:
    INX
    CPX #TEXT_ROWS
    BNE FillRow
    RTS

; =============================================================================
; TuneStep — advance the 32-note tune on channel 0
; =============================================================================
; A note's duration is in frames.  The timer is preloaded with 1 at reset and
; on every scene change, so the first frame plays note 0.  The checkpoint
; reports the index of the note that starts on this frame, not the next one.
TuneStep:
    DEC TuneTimer
    BNE TuneDone
    LDX TunePtr
    TXA
TunePtrRead:                ; checkpoint: A = the note index, 0..31
    NOP
    LDX TunePtr
    LDA TuneFreq,X
    STA AUDF0
    LDA #TUNE_AUDC
    STA AUDC0
    LDA #TUNE_AUDV
    STA AUDV0
    LDA TuneDur,X
    STA TuneTimer
    INX
    CPX #TUNE_LEN
    BCC TuneStore
    LDX #0
TuneStore:
    STX TunePtr
TuneDone:
    RTS

; =============================================================================
; THE TABLES
; =============================================================================

; --- the colour cycle: eight bright NTSC hues -------------------------------
; The title's border bands, logo and stars all share COLUPF, so they change
; together.  The credits scene uses a fixed gold instead.
TitleColors:
    !byte $0E, $1A, $2A, $3A, $4A, $5A, $8A, $AA

; --- the tune: 32 notes, 8 groups of 4 --------------------------------------
; AUDF is the TIA divider (higher = lower pitch).  The note names in the
; lesson are the nearest equal-tempered pitch, not a claim about exact tuning.
; Group 1 is C4-E4-G4-C5; group 2 D4-F4-A4-D5; group 3 E4-G4-B♭4-E5; group 4
; is the cadence C5-G4-E4-C4.
TuneFreq:
    !byte 19,15,12,9,   12,15,19,19
    !byte 17,14,11,8,   11,14,17,17
    !byte 15,12,10,7,   10,12,15,15
    !byte 9,12,15,19,   15,12,19,19
TuneDur:
    !byte 6,6,6,12,     6,6,6,12
    !byte 6,6,6,12,     6,6,6,12
    !byte 6,6,6,12,     6,6,6,12
    !byte 6,6,6,12,     6,6,6,12

; --- the eight phase-block pointers ----------------------------------------
; Each phase block is 8 rows x 16 bytes = 128 bytes.  The table is 16-aligned
; and the rows are 16 bytes, so the fill's six-byte read stays in one page.
PhasePtrLo:
    !byte <(ShiftedTable + 0*128), <(ShiftedTable + 1*128)
    !byte <(ShiftedTable + 2*128), <(ShiftedTable + 3*128)
    !byte <(ShiftedTable + 4*128), <(ShiftedTable + 5*128)
    !byte <(ShiftedTable + 6*128), <(ShiftedTable + 7*128)
PhasePtrHi:
    !byte >(ShiftedTable + 0*128), >(ShiftedTable + 1*128)
    !byte >(ShiftedTable + 2*128), >(ShiftedTable + 3*128)
    !byte >(ShiftedTable + 4*128), >(ShiftedTable + 5*128)
    !byte >(ShiftedTable + 6*128), >(ShiftedTable + 7*128)

; =============================================================================
; THE LOGO ZONE — each compact row repeated eight times
; =============================================================================
; The compact LOGO_Rn_* constants above are the single source of truth.
; !fill repeats each row across its eight scanlines, so the title kernel can
; index the expanded plane with the global row (0..55) and OR it with stars.
!align 15, 0
LogoZonePF0:
    !fill 8, LOGO_R0_PF0
    !fill 8, LOGO_R1_PF0
    !fill 8, LOGO_R2_PF0
    !fill 8, LOGO_R3_PF0
    !fill 8, LOGO_R4_PF0
    !fill 8, LOGO_R5_PF0
    !fill 8, LOGO_R6_PF0
LogoZonePF1:
    !fill 8, LOGO_R0_PF1
    !fill 8, LOGO_R1_PF1
    !fill 8, LOGO_R2_PF1
    !fill 8, LOGO_R3_PF1
    !fill 8, LOGO_R4_PF1
    !fill 8, LOGO_R5_PF1
    !fill 8, LOGO_R6_PF1
LogoZonePF2:
    !fill 8, LOGO_R0_PF2
    !fill 8, LOGO_R1_PF2
    !fill 8, LOGO_R2_PF2
    !fill 8, LOGO_R3_PF2
    !fill 8, LOGO_R4_PF2
    !fill 8, LOGO_R5_PF2
    !fill 8, LOGO_R6_PF2

; =============================================================================
; THE STARFIELD — three page-aligned 64-byte planes
; =============================================================================
; Row r is StarPF0+r, StarPF1+r, StarPF2+r.  The kernel uses Y & $3F, so the
; 64-row pattern repeats three times down the 192-line picture.  The bits
; follow the TIA layout: PF0 bits 4-7 are chunks 0-3, PF1 bits 7-0 are
; chunks 4-11, PF2 bits 0-7 are chunks 12-19.  The border handles the far
; edges; the stars keep to chunks 1-18.
    !align 255, 0
StarPF0:
    !byte $00,$20,$00,$00,$00,$00,$80,$00   ; rows 0-7
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; rows 8-15
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; rows 16-23
    !byte $20,$00,$00,$00,$00,$00,$00,$00   ; rows 24-31
    !byte $00,$00,$20,$00,$00,$00,$00,$00   ; rows 32-39
    !byte $80,$00,$40,$00,$00,$00,$00,$00   ; rows 40-47
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; rows 48-55
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; rows 56-63

    !align 255, 0
StarPF1:
    !byte $02,$00,$40,$02,$00,$10,$00,$04   ; rows 0-7
    !byte $00,$00,$00,$00,$00,$00,$01,$01   ; rows 8-15
    !byte $00,$00,$00,$01,$00,$08,$00,$00   ; rows 16-23
    !byte $00,$00,$01,$00,$00,$00,$00,$00   ; rows 24-31
    !byte $00,$80,$00,$40,$00,$80,$00,$00   ; rows 32-39
    !byte $00,$00,$00,$80,$00,$10,$00,$00   ; rows 40-47
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; rows 48-55
    !byte $00,$00,$00,$00,$00,$04,$02,$00   ; rows 56-63

    !align 255, 0
StarPF2:
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; rows 0-7
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; rows 8-15
    !byte $01,$10,$40,$00,$00,$00,$00,$00   ; rows 16-23
    !byte $00,$04,$00,$08,$08,$24,$20,$40   ; rows 24-31
    !byte $10,$00,$02,$00,$00,$00,$00,$00   ; rows 32-39
    !byte $00,$20,$40,$01,$10,$00,$00,$00   ; rows 40-47
    !byte $10,$20,$00,$00,$01,$00,$10,$10   ; rows 48-55
    !byte $04,$20,$02,$02,$08,$00,$00,$00   ; rows 56-63

; =============================================================================
; THE CREDIT BLOCKS — four 48-byte column-major, bottom-up blocks
; =============================================================================
; Each block is six columns x eight rows.  The text_line macro reads column
; c's eight bytes at base+c*8, with Y = 7 (top) down to 0 (bottom).
CreditsLine1:
    ; column 0: 'R'
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0
    ; column 1: 'A'
    !byte $00,$88,$88,$88,$F8,$88,$88,$70
    ; column 2: 'C'
    !byte $00,$70,$88,$80,$80,$80,$88,$70
    ; column 3: 'I'
    !byte $00,$F8,$20,$20,$20,$20,$20,$F8
    ; column 4: 'N'
    !byte $00,$88,$88,$88,$98,$A8,$C8,$88
    ; column 5: 'G'
    !byte $00,$70,$88,$88,$B8,$80,$88,$70

CreditsLine2:
    ; column 0: 'space'
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    ; column 1: 'T'
    !byte $00,$20,$20,$20,$20,$20,$20,$F8
    ; column 2: 'H'
    !byte $00,$88,$88,$88,$F8,$88,$88,$88
    ; column 3: 'E'
    !byte $00,$F8,$80,$80,$F0,$80,$80,$F8
    ; column 4: 'space'
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    ; column 5: 'space'
    !byte $00,$00,$00,$00,$00,$00,$00,$00

CreditsLine3:
    ; column 0: 'space'
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    ; column 1: 'B'
    !byte $00,$F0,$88,$88,$F0,$88,$88,$F0
    ; column 2: 'E'
    !byte $00,$F8,$80,$80,$F0,$80,$80,$F8
    ; column 3: 'A'
    !byte $00,$88,$88,$88,$F8,$88,$88,$70
    ; column 4: 'M'
    !byte $00,$88,$88,$88,$A8,$A8,$D8,$88
    ; column 5: 'space'
    !byte $00,$00,$00,$00,$00,$00,$00,$00

CreditsLine4:
    ; column 0: 'T'
    !byte $00,$20,$20,$20,$20,$20,$20,$F8
    ; column 1: 'H'
    !byte $00,$88,$88,$88,$F8,$88,$88,$88
    ; column 2: 'A'
    !byte $00,$88,$88,$88,$F8,$88,$88,$70
    ; column 3: 'N'
    !byte $00,$88,$88,$88,$98,$A8,$C8,$88
    ; column 4: 'K'
    !byte $00,$88,$90,$A0,$C0,$A0,$90,$88
    ; column 5: 'S'
    !byte $00,$F0,$08,$08,$70,$80,$80,$78

; =============================================================================
; THE FONT ATLAS — the 5x7 glyphs the tables were generated from
; =============================================================================
; These bytes are the glyph source, not a runtime table: the pre-shifted
; marquee and the four credit blocks above are generated from them.  Byte 0
; is the bottom row; bit 7 is the leftmost pixel.  Every glyph's byte 0 is
; $00, so the lit part is seven scanlines tall.
FontAtlas:
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    ; 'space'
    !byte $00,$88,$88,$88,$F8,$88,$88,$70
    ; 'A'
    !byte $00,$F0,$88,$88,$F0,$88,$88,$F0
    ; 'B'
    !byte $00,$70,$88,$80,$80,$80,$88,$70
    ; 'C'
    !byte $00,$F0,$88,$88,$88,$88,$88,$F0
    ; 'D'
    !byte $00,$F8,$80,$80,$F0,$80,$80,$F8
    ; 'E'
    !byte $00,$70,$88,$88,$B8,$80,$88,$70
    ; 'G'
    !byte $00,$88,$88,$88,$F8,$88,$88,$88
    ; 'H'
    !byte $00,$F8,$20,$20,$20,$20,$20,$F8
    ; 'I'
    !byte $00,$88,$90,$A0,$C0,$A0,$90,$88
    ; 'K'
    !byte $00,$88,$88,$88,$A8,$A8,$D8,$88
    ; 'M'
    !byte $00,$88,$88,$88,$98,$A8,$C8,$88
    ; 'N'
    !byte $00,$70,$88,$88,$88,$88,$88,$70
    ; 'O'
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0
    ; 'R'
    !byte $00,$F0,$08,$08,$70,$80,$80,$78
    ; 'S'
    !byte $00,$20,$20,$20,$20,$20,$20,$F8
    ; 'T'
    !byte $00,$88,$D8,$A8,$A8,$88,$88,$88
    ; 'W'

; =============================================================================
; THE PRE-SHIFTED MARQUEE — 8 phases x 8 rows x 16 bytes = 1,024 bytes
; =============================================================================
; For phase p, row r and character i, the output byte is
;     (glyph[i][r] << p) | (glyph[i+1][r] >> (8-p))     for p > 0
;     glyph[i][r]                                       for p = 0
; where glyph[16] is a zero pad.  A row is 16 bytes (the 16-character
; message), so a six-byte window starting at byteIndex (0..10) never crosses
; a page.  Phase p starts at ShiftedTable + 128*p; row r starts at +16*r.
    !align 15, 0
ShiftedTable:
    ; ---- phase 0: the window shifted left 0 pixel(s) ----
    ; font row 0 (blank for every glyph)
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; phase 0, font row 1 (0 = bottom, 7 = top)
    !byte $88,$70,$F0,$F8,$88,$88,$00,$88,$70,$88,$F8,$F0,$88,$F8,$88,$00
    ; phase 0, font row 2 (0 = bottom, 7 = top)
    !byte $88,$88,$88,$80,$90,$88,$00,$88,$88,$88,$80,$88,$90,$80,$D8,$00
    ; phase 0, font row 3 (0 = bottom, 7 = top)
    !byte $88,$88,$88,$80,$A0,$88,$00,$88,$88,$88,$80,$88,$A0,$80,$A8,$00
    ; phase 0, font row 4 (0 = bottom, 7 = top)
    !byte $A8,$88,$88,$F0,$F0,$98,$00,$F8,$88,$A8,$F0,$F0,$F0,$F0,$A8,$00
    ; phase 0, font row 5 (0 = bottom, 7 = top)
    !byte $A8,$88,$88,$80,$88,$A8,$00,$88,$88,$A8,$80,$88,$88,$80,$88,$00
    ; phase 0, font row 6 (0 = bottom, 7 = top)
    !byte $D8,$88,$88,$80,$88,$C8,$00,$88,$88,$D8,$80,$88,$88,$80,$88,$00
    ; phase 0, font row 7 (0 = bottom, 7 = top)
    !byte $88,$70,$F0,$F8,$F0,$88,$00,$88,$70,$88,$F8,$F0,$F0,$F8,$88,$00
    ; ---- phase 1: the window shifted left 1 pixel(s) ----
    ; font row 0 (blank for every glyph)
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; phase 1, font row 1 (0 = bottom, 7 = top)
    !byte $10,$E1,$E1,$F1,$11,$10,$01,$10,$E1,$11,$F1,$E1,$11,$F1,$10,$00
    ; phase 1, font row 2 (0 = bottom, 7 = top)
    !byte $11,$11,$11,$01,$21,$10,$01,$11,$11,$11,$01,$11,$21,$01,$B0,$00
    ; phase 1, font row 3 (0 = bottom, 7 = top)
    !byte $11,$11,$11,$01,$41,$10,$01,$11,$11,$11,$01,$11,$41,$01,$50,$00
    ; phase 1, font row 4 (0 = bottom, 7 = top)
    !byte $51,$11,$11,$E1,$E1,$30,$01,$F1,$11,$51,$E1,$E1,$E1,$E1,$50,$00
    ; phase 1, font row 5 (0 = bottom, 7 = top)
    !byte $51,$11,$11,$01,$11,$50,$01,$11,$11,$51,$01,$11,$11,$01,$10,$00
    ; phase 1, font row 6 (0 = bottom, 7 = top)
    !byte $B1,$11,$11,$01,$11,$90,$01,$11,$11,$B1,$01,$11,$11,$01,$10,$00
    ; phase 1, font row 7 (0 = bottom, 7 = top)
    !byte $10,$E1,$E1,$F1,$E1,$10,$01,$10,$E1,$11,$F1,$E1,$E1,$F1,$10,$00
    ; ---- phase 2: the window shifted left 2 pixel(s) ----
    ; font row 0 (blank for every glyph)
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; phase 2, font row 1 (0 = bottom, 7 = top)
    !byte $21,$C3,$C3,$E2,$22,$20,$02,$21,$C2,$23,$E3,$C2,$23,$E2,$20,$00
    ; phase 2, font row 2 (0 = bottom, 7 = top)
    !byte $22,$22,$22,$02,$42,$20,$02,$22,$22,$22,$02,$22,$42,$03,$60,$00
    ; phase 2, font row 3 (0 = bottom, 7 = top)
    !byte $22,$22,$22,$02,$82,$20,$02,$22,$22,$22,$02,$22,$82,$02,$A0,$00
    ; phase 2, font row 4 (0 = bottom, 7 = top)
    !byte $A2,$22,$23,$C3,$C2,$60,$03,$E2,$22,$A3,$C3,$C3,$C3,$C2,$A0,$00
    ; phase 2, font row 5 (0 = bottom, 7 = top)
    !byte $A2,$22,$22,$02,$22,$A0,$02,$22,$22,$A2,$02,$22,$22,$02,$20,$00
    ; phase 2, font row 6 (0 = bottom, 7 = top)
    !byte $62,$22,$22,$02,$23,$20,$02,$22,$23,$62,$02,$22,$22,$02,$20,$00
    ; phase 2, font row 7 (0 = bottom, 7 = top)
    !byte $21,$C3,$C3,$E3,$C2,$20,$02,$21,$C2,$23,$E3,$C3,$C3,$E2,$20,$00
    ; ---- phase 3: the window shifted left 3 pixel(s) ----
    ; font row 0 (blank for every glyph)
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; phase 3, font row 1 (0 = bottom, 7 = top)
    !byte $43,$87,$87,$C4,$44,$40,$04,$43,$84,$47,$C7,$84,$47,$C4,$40,$00
    ; phase 3, font row 2 (0 = bottom, 7 = top)
    !byte $44,$44,$44,$04,$84,$40,$04,$44,$44,$44,$04,$44,$84,$06,$C0,$00
    ; phase 3, font row 3 (0 = bottom, 7 = top)
    !byte $44,$44,$44,$05,$04,$40,$04,$44,$44,$44,$04,$45,$04,$05,$40,$00
    ; phase 3, font row 4 (0 = bottom, 7 = top)
    !byte $44,$44,$47,$87,$84,$C0,$07,$C4,$45,$47,$87,$87,$87,$85,$40,$00
    ; phase 3, font row 5 (0 = bottom, 7 = top)
    !byte $44,$44,$44,$04,$45,$40,$04,$44,$45,$44,$04,$44,$44,$04,$40,$00
    ; phase 3, font row 6 (0 = bottom, 7 = top)
    !byte $C4,$44,$44,$04,$46,$40,$04,$44,$46,$C4,$04,$44,$44,$04,$40,$00
    ; phase 3, font row 7 (0 = bottom, 7 = top)
    !byte $43,$87,$87,$C7,$84,$40,$04,$43,$84,$47,$C7,$87,$87,$C4,$40,$00
    ; ---- phase 4: the window shifted left 4 pixel(s) ----
    ; font row 0 (blank for every glyph)
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; phase 4, font row 1 (0 = bottom, 7 = top)
    !byte $87,$0F,$0F,$88,$88,$80,$08,$87,$08,$8F,$8F,$08,$8F,$88,$80,$00
    ; phase 4, font row 2 (0 = bottom, 7 = top)
    !byte $88,$88,$88,$09,$08,$80,$08,$88,$88,$88,$08,$89,$08,$0D,$80,$00
    ; phase 4, font row 3 (0 = bottom, 7 = top)
    !byte $88,$88,$88,$0A,$08,$80,$08,$88,$88,$88,$08,$8A,$08,$0A,$80,$00
    ; phase 4, font row 4 (0 = bottom, 7 = top)
    !byte $88,$88,$8F,$0F,$09,$80,$0F,$88,$8A,$8F,$0F,$0F,$0F,$0A,$80,$00
    ; phase 4, font row 5 (0 = bottom, 7 = top)
    !byte $88,$88,$88,$08,$8A,$80,$08,$88,$8A,$88,$08,$88,$88,$08,$80,$00
    ; phase 4, font row 6 (0 = bottom, 7 = top)
    !byte $88,$88,$88,$08,$8C,$80,$08,$88,$8D,$88,$08,$88,$88,$08,$80,$00
    ; phase 4, font row 7 (0 = bottom, 7 = top)
    !byte $87,$0F,$0F,$8F,$08,$80,$08,$87,$08,$8F,$8F,$0F,$0F,$88,$80,$00
    ; ---- phase 5: the window shifted left 5 pixel(s) ----
    ; font row 0 (blank for every glyph)
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; phase 5, font row 1 (0 = bottom, 7 = top)
    !byte $0E,$1E,$1F,$11,$11,$00,$11,$0E,$11,$1F,$1E,$11,$1F,$11,$00,$00
    ; phase 5, font row 2 (0 = bottom, 7 = top)
    !byte $11,$11,$10,$12,$11,$00,$11,$11,$11,$10,$11,$12,$10,$1B,$00,$00
    ; phase 5, font row 3 (0 = bottom, 7 = top)
    !byte $11,$11,$10,$14,$11,$00,$11,$11,$11,$10,$11,$14,$10,$15,$00,$00
    ; phase 5, font row 4 (0 = bottom, 7 = top)
    !byte $11,$11,$1E,$1E,$13,$00,$1F,$11,$15,$1E,$1E,$1E,$1E,$15,$00,$00
    ; phase 5, font row 5 (0 = bottom, 7 = top)
    !byte $11,$11,$10,$11,$15,$00,$11,$11,$15,$10,$11,$11,$10,$11,$00,$00
    ; phase 5, font row 6 (0 = bottom, 7 = top)
    !byte $11,$11,$10,$11,$19,$00,$11,$11,$1B,$10,$11,$11,$10,$11,$00,$00
    ; phase 5, font row 7 (0 = bottom, 7 = top)
    !byte $0E,$1E,$1F,$1E,$11,$00,$11,$0E,$11,$1F,$1E,$1E,$1F,$11,$00,$00
    ; ---- phase 6: the window shifted left 6 pixel(s) ----
    ; font row 0 (blank for every glyph)
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; phase 6, font row 1 (0 = bottom, 7 = top)
    !byte $1C,$3C,$3E,$22,$22,$00,$22,$1C,$22,$3E,$3C,$22,$3E,$22,$00,$00
    ; phase 6, font row 2 (0 = bottom, 7 = top)
    !byte $22,$22,$20,$24,$22,$00,$22,$22,$22,$20,$22,$24,$20,$36,$00,$00
    ; phase 6, font row 3 (0 = bottom, 7 = top)
    !byte $22,$22,$20,$28,$22,$00,$22,$22,$22,$20,$22,$28,$20,$2A,$00,$00
    ; phase 6, font row 4 (0 = bottom, 7 = top)
    !byte $22,$22,$3C,$3C,$26,$00,$3E,$22,$2A,$3C,$3C,$3C,$3C,$2A,$00,$00
    ; phase 6, font row 5 (0 = bottom, 7 = top)
    !byte $22,$22,$20,$22,$2A,$00,$22,$22,$2A,$20,$22,$22,$20,$22,$00,$00
    ; phase 6, font row 6 (0 = bottom, 7 = top)
    !byte $22,$22,$20,$22,$32,$00,$22,$22,$36,$20,$22,$22,$20,$22,$00,$00
    ; phase 6, font row 7 (0 = bottom, 7 = top)
    !byte $1C,$3C,$3E,$3C,$22,$00,$22,$1C,$22,$3E,$3C,$3C,$3E,$22,$00,$00
    ; ---- phase 7: the window shifted left 7 pixel(s) ----
    ; font row 0 (blank for every glyph)
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; phase 7, font row 1 (0 = bottom, 7 = top)
    !byte $38,$78,$7C,$44,$44,$00,$44,$38,$44,$7C,$78,$44,$7C,$44,$00,$00
    ; phase 7, font row 2 (0 = bottom, 7 = top)
    !byte $44,$44,$40,$48,$44,$00,$44,$44,$44,$40,$44,$48,$40,$6C,$00,$00
    ; phase 7, font row 3 (0 = bottom, 7 = top)
    !byte $44,$44,$40,$50,$44,$00,$44,$44,$44,$40,$44,$50,$40,$54,$00,$00
    ; phase 7, font row 4 (0 = bottom, 7 = top)
    !byte $44,$44,$78,$78,$4C,$00,$7C,$44,$54,$78,$78,$78,$78,$54,$00,$00
    ; phase 7, font row 5 (0 = bottom, 7 = top)
    !byte $44,$44,$40,$44,$54,$00,$44,$44,$54,$40,$44,$44,$40,$44,$00,$00
    ; phase 7, font row 6 (0 = bottom, 7 = top)
    !byte $44,$44,$40,$44,$64,$00,$44,$44,$6C,$40,$44,$44,$40,$44,$00,$00
    ; phase 7, font row 7 (0 = bottom, 7 = top)
    !byte $38,$78,$7C,$78,$44,$00,$44,$38,$44,$7C,$78,$78,$7C,$44,$00,$00

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
