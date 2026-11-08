; =============================================================================
; LESSON 79 — EXERCISE 1 SOLUTION: A Ten-Letter 4x7 Mark
; =============================================================================
; Part 11: Legendary Techniques
;
; What this program does:
;   The Lesson 79 calling card with a ten-letter wordmark.  The mark table
;   still holds six 8x8 cells (48 bytes), but each cell now packs two 4x7
;   letters side by side: the left letter in bits 7-4 and the right letter
;   in bits 3-0, one 4-pixel glyph per nibble.  The word RACINGBEAM needs
;   five cells (40 pixels), so the sixth cell is blank.  The frame, the
;   score, the play band and the handover are unchanged.
;   The player catches the star; every catch adds one to the score.  SELECT
;   hides or shows the mark, proving that the mark is an independent screen
;   element and not part of the play field.  An auto-demo plays the game and
;   scripts the toggle, so both captures are reproducible without input.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   The 192 visible lines are five bands:
;
;     visible   0-  8   the score       9 lines   ScoreDraw (Lesson 39)
;     visible   9- 13   the positioner  5 lines   P0 to PlayerX, ball to BallX
;     visible  14-177   the play      164 lines   82 rows x 2 lines
;     visible 178-182   the handover    5 lines   P0=16, P1=24 for the mark
;     visible 183-191   the mark        9 lines   MarkDraw (unrolled, ten 4x7 letters)
;                       ----------------
;                       9 + 5 + 164 + 5 + 9 = 192
;
;   Absolute scanlines: ScoreDone 46, PlayStart 51, HandoverStart 215,
;   MarkStart 220, MarkDone 229, OverscanStart 229.  The frame gate is
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5.
;
; The score band (visible 0-8):
;   include/score.asm draws six white digits with P0/P1 in three-copy close
;   mode.  P0 sits at TIA X=56 (copies at 56, 72, 88) and P1 at X=64 (copies
;   at 64, 80, 96), so the six columns interleave across X=56-103: a
;   48-pixel block.  ScoreSetup runs in VBLANK, sets NUSIZ=3 and VDEL on,
;   positions the players, and strobes ONE HMOVE.  ScoreDraw consumes nine
;   lines: line 0 is the setup/blank line and lines 1-8 are the eight rows.
;   Every glyph's byte 0 is $00, so the lit digits are visible 1-7.
;
;   The play field's P1 is blank: P1 is reserved for the score and the mark.
;
; The top positioner (visible 9-13):
;   P0 moves from the score's X=56 to PlayerX; the ball moves to BallX.
;   SetGameP0 and SetGameBall are the Lesson 26 divide-by-15 routines.  Each
;   starts with a WSYNC and ends with a WSYNC, so each costs exactly two
;   lines for every X; the fifth line carries the HMOVE.  The ball's target
;   adds one extra pixel because a ball's reset is one colour clock shorter
;   than a player's (Lesson 29/39).  NUSIZ0=NUSIZ1=0 (one 8-pixel copy
;   each), VDEL off, COLUP0 red, COLUPF gold.  The ball is left disabled here;
;   the play kernel enables it only on its four rows, so no stray pixel
;   appears on the positioner line.
;
;   The HMOVE applies HMP0 and the ball's HMBL in the HBLANK of line 50.
;   Its left-edge blanking is on that positioner line, not on the play.
;
; The play band (visible 14-177, 164 lines = 82 rows x 2):
;   A two-line kernel.  Each row writes GRP0, the ball's ENABL, and PF0/PF1/
;   PF2.  The playfield is reflected (CTRLPF=$01); the sky is mostly dark,
;   with four two-row star bands and a full-width gold horizon; the ground
;   is a solid dark-green band.  The player is an 8-pixel-wide, 16-line-tall
;   figure fixed at kernel rows 72-79.  The ball is one pixel wide and four
;   kernel rows tall (eight scanlines); BallY runs 8-70 and is its top row.
;
;   The ball is eight scanlines tall and shares COLUPF with the playfield.
;   In the sky it is gold against the dark background; on the green ground
;   (rows 69-81) it takes the ground colour and blends near the catch.  That
;   is the trade-off of a one-colour playfield/ball register, and it is
;   called out in the lesson.
;
;   CXP0FB bit 6 (P0-ball) is read in the next VBLANK: the latch describes
;   the visible frame that just ended, so a catch is one frame late by
;   construction (Lessons 38/50).  A hit adds one with ScoreAddOne, resets
;   the ball to row 8, and chooses a new X.  The new X alternates between 56
;   and 104.  Once the demo is running (AutoPlay=1 after 120 frames), the
;   one-pixel-per-frame player can reach either X before the star lands.
;   The first respawn at X=56 (frame 63) is missed because the demo has not
;   started; the second catch is frame 188, and the 62-frame cadence starts
;   there.
;
; The handover (visible 178-182):
;   SetMarkP0 positions P0 at TIA X=16 (two lines), SetMarkP1 positions P1 at
;   X=24 (two lines), and the fifth line carries ONE HMOVE.  NUSIZ=3 for
;   both, VDEL on, COLUP0/COLUP1 gold ($1A), ENABL off.  The HMOVE's
;   left-edge blanking falls on the blank handover line, not on the mark.
;   No motion register is written again until the next frame's VBLANK, far
;   beyond the 24-cycle rule.
;
; The mark band (visible 183-191):
;   MarkSetup is the mark-position copy of ScoreSetup.  It cannot call the
;   shared ScoreSetup because that routine hard-codes 56/64, and changing
;   the library would affect Lessons 39, 40, 50, 55, 61, 63 and the
;   capstones.  The lesson copies the setup and explains why.
;
;   MarkBuf is a 48-byte ROM table, column-major and bottom-up: column c,
;   row r lives at MarkBuf + c*8 + r.  The six 8-pixel cells pack ten 4x7
;   letters two per cell: the left letter is bits 7-4, the right letter bits
;   3-0.  RACINGBEAM uses five cells (40 pixels) and the sixth cell is blank.
;   Byte 0 is $00, so the lit block is seven rows (visible 184-190).  The
;   table is preceded by !align 255,0: all 48 bytes stay in one page, so
;   every LDA MarkBuf+n,Y is four cycles.  A page cross would add one cycle
;   and shift that column in the kernel.
;
;   MarkDraw is unrolled: the eight rows are eight expansions of
;   MarkPreload/MarkStores with fixed table addresses.  There is no loop
;   counter, which gives the row the cycles to place the C commit in the
;   gap between P0 copy 0 (CLK 84-91) and P0 copy 1 (CLK 100-107).  The
;   commits are at write cycles 5, 11, 31, 34, 37 and 40; the C commit at
;   31/CLK 93 is the one that used to bleed the C glyph into the R cell.
;   The row is 59 cycles, comfortably inside 76; the cleanup blanks
;   GRP0/GRP1, clears VDEL, and a nine-NOP/BIT delay puts MarkDone at
;   229/6.  The band still consumes nine lines.
;
;   If MarkVisible=0 the band still consumes nine lines: the program skips
;   MarkDraw, keeps the players blank, clears VDEL, and waits nine WSYNCs.
;   The frame stays 262 in both states.
;
; Input and the auto-demo:
;   SWCHA P0 left/right (bits 6/7, active low) moves PlayerX one pixel per
;   frame, clamped to 8-144.  INPT4 fire (bit 7, active low) resets the
;   score to 000000 with ScoreClear on a new press.  SWCHB bit 1 SELECT
;   (active low) toggles MarkVisible on a new press.  After 120 idle frames
;   the auto-demo starts: the player tracks BallX-3, so the star lands on
;   the player's left-centre.  At frame 240 the demo calls the same
;   ToggleMark path as SELECT, hiding the mark for the second capture.  The
;   demo's state byte is AutoPlay: 0 = idle, 1 = tracking, 2 = the mark has
;   been hidden (so the scripted toggle happens once).
;
; Checkpoints (the A/X/Y values are the state at the label):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   ScoreDone (46), PlayStart (51), HandoverStart (215),
;   MarkStart (220), MarkDone (229), OverscanStart (229/6);
;   ScoreWrite (A = the new score's rightmost digit), MarkVisibleWrite
;   (A = the new MarkVisible, 0/1), PlayerXRead (A = PlayerX on the manual
;   left branch), BallYRead (A = BallY before the fall), Hit (A = the new
;   score's rightmost digit), SelectEdge (A = 1 on a toggle).
;
; RAM map (the exact map; +clean_start zeroes every byte):
;   $80 Frame          frame counter, 8 bits
;   $81 PlayerX        the player's TIA X, 8-144
;   $82 BallX          the ball's TIA X, 24-136
;   $83 BallY          the ball's top kernel row, 8-70
;   $84 PrevFire       fire edge latch (0 = released, 1 = pressed)
;   $85 PrevSelect     SELECT edge latch (0 = released, 1 = pressed)
;   $86 AutoTimer      idle frames, 0-120
;   $87 AutoPlay       0 = idle, 1 = tracking, 2 = the scripted toggle ran
;   $88 MarkVisible    0 = hidden, 1 = visible; reset sets 1
;   $89-$8A            free (2 bytes)
;   $8B MarkTmp        MarkDraw's column-2 scratch
;   $8C BallNext       the ball-enable lookahead for the next play row
;   $8D-$8F            free (3 bytes)
;   $A0-$A5 ScoreDigits
;   $A6 ScoreRow
;   $A7 ScoreTmp
;   $A8-$D7 ScoreBuf    48 bytes, column-major, bottom-up
;   $D8-$F7            free (32 bytes)
;   $F8-$FF            stack
;
;   The mark table is in ROM, not RAM: the score changes every catch, the
;   mark never changes, so moving it to ROM saves 48 RAM bytes.
;
; Build: acme -f plain -o build/exercise-01.bin \
;        lessons/part11-legendary/79-publisher-mark/exercise-01-solution.asm
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

; --- the visible-line budget --------------------------------------------------
PLAY_ROWS      = 82      ; visible 14-177: 82 rows x 2 scanlines = 164 lines
SKY_ROWS       = 69      ; play rows 0-68: the sky and the horizon row
PLAYER_TOP     = 72      ; the player's first kernel row (visible 158)
PLAYER_ROWS    = 8       ; the player is 8 kernel rows = 16 scanlines
BALL_START_Y   = 8       ; the star's top row at respawn
BALL_END_Y     = 70      ; the last top row before a miss

P0_MIN         = 8       ; the player's left clamp (TIA X)
P0_MAX         = 144     ; the player's right clamp (8 pixels wide)
P0_START       = 76      ; power-on: the ball at 80 is inside the player
PLAYER_CENTRE  = 3       ; the auto-demo aims three pixels left of BallX

; --- the auto-demo ------------------------------------------------------------
AUTO_FRAMES    = 120     ; idle frames before the demo starts
AUTO_TOGGLE    = 240     ; the demo hides the mark at this frame

; --- the mark positions -------------------------------------------------------
MARK_P0_X      = 16      ; P0's TIA X; copies at 16, 32, 48
MARK_P1_X      = 24      ; P1's TIA X; copies at 24, 40, 56
; The six interleaved cells span TIA X=16-63.

; --- colours ------------------------------------------------------------------
C_WHITE        = $0E     ; the score
C_PLAYER       = $42     ; the player: red
C_GOLD         = $1A     ; the star, the stars, the mark
C_GROUND       = $C4     ; the ground: dark green
C_BG           = $02     ; the sky: near-black

; --- the score library's fixed positions (include/score.asm) ------------------
; The score uses SCORE_P0_X=56 and SCORE_P1_X=64; the mark uses 16 and 24.
; The mark's setup is copied below because the library hard-codes the score.

; =============================================================================
; RAM ALLOCATION ($80-$8C; +clean_start zeroes every byte)
; =============================================================================
Frame        = $80   ; the frame counter, 8 bits
PlayerX      = $81   ; the player's left edge, 8-144
BallX        = $82   ; the ball's left edge, 24-136
BallY        = $83   ; the ball's top kernel row, 8-70
PrevFire     = $84   ; 0 = fire released, 1 = held
PrevSelect   = $85   ; 0 = SELECT released, 1 = held
AutoTimer    = $86   ; idle frames, 0-120
AutoPlay     = $87   ; 0 = idle, 1 = tracking, 2 = the scripted toggle ran
MarkVisible  = $88   ; 0 = hidden, 1 = visible
MarkTmp      = $8B   ; MarkDraw's column-2 scratch
BallNext     = $8C   ; the ball-enable lookahead for the next play row
ScoreOnes    = $A5   ; ScoreDigits+5: the visible score's rightmost digit
;
; $8D-$8F are free (3 bytes).  The score library owns $A0-$D7; $D8-$F7 is
; free.  The stack lives at $F8-$FF.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joystick)

; --- the score starts at 000000 ----------------------------------------------
    JSR ScoreInit           ; zero the digits and the 48-byte buffer
    JSR ScoreClear          ; build the six zero glyphs: 000000

; --- the game's initial state ------------------------------------------------
    LDA #P0_START
    STA PlayerX
    LDA #$50                ; 80: the star starts above the player
    STA BallX
    LDA #BALL_START_Y
    STA BallY
    LDA #$01
    STA MarkVisible         ; the mark is visible at power-on

; --- the static colours and controls -----------------------------------------
    LDA #C_BG
    STA COLUBK
    LDA #C_GOLD
    STA COLUPF
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    LDA #$01
    STA CTRLPF              ; reflect the playfield; the ball is one pixel
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL
    STA NUSIZ0
    STA NUSIZ1

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    INC Frame

; -----------------------------------------------------------------------------
; 1. THE COLLISION — CXP0FB bit 6 (P0-ball), read one frame late
; -----------------------------------------------------------------------------
; The latch describes the visible frame that just ended, so the hit is always
; one frame late by construction.  CXCLR clears every latch after the read.
    LDA CXP0FB
    AND #$40                ; bit 6: player 0 met the ball
    BEQ NoHit
    JSR ScoreAddOne         ; add one, with a decimal carry
    LDA ScoreOnes           ; ScoreDigits+5: the rightmost digit
ScoreWrite:                 ; checkpoint: A = the new rightmost digit
Hit:                        ; checkpoint: A = the new rightmost digit
    LDA #BALL_START_Y
    STA BallY               ; respawn at the top of the field
    LDA BallX
    CMP #$50                ; 80: alternate the respawn left and right
    BCS HitLeft
    LDA #$68                ; 104
    JMP HitStoreX
HitLeft:
    LDA #$38                ; 56
HitStoreX:
    STA BallX               ; the player can reach either X before the fall
    JMP HitDone
NoHit:
    LDA BallY
BallYRead:                  ; checkpoint: A = BallY before the step
    CMP #BALL_END_Y
    BCS BallReset
    INC BallY
    JMP HitDone
BallReset:
    LDA #BALL_START_Y
    STA BallY               ; the star reached the ground: start again
HitDone:
    LDA #$00
    STA CXCLR               ; the latches have done their job for this frame

; -----------------------------------------------------------------------------
; 2. P0 — the joystick, or the auto-demo seeking the star
; -----------------------------------------------------------------------------
; SWCHA's P0 direction bits are active low: left reads $80 after AND #$C0,
; right reads $40, and neither reads $C0.  TIA X is clamped to 8..144.
    LDA SWCHA
    AND #$C0
    CMP #$C0
    BEQ AutoDemo            ; neither pressed: run the demo
    LDA SWCHA
    AND #$40                ; left
    BNE MoveRight
    LDA PlayerX
PlayerXRead:                ; checkpoint: A = PlayerX on the left branch
    CMP #P0_MIN
    BEQ MoveDone
    DEC PlayerX
    JMP MoveDone
MoveRight:
    LDA SWCHA
    AND #$80                ; right
    BNE AutoDemo            ; both directions: treat as no input
    LDA PlayerX
    CMP #P0_MAX
    BEQ MoveDone
    INC PlayerX
    JMP MoveDone

; The auto-demo: after AUTO_FRAMES idle frames, track BallX-3.  The seek
; target is clamped to the player's travel, and the player moves one pixel
; per frame, so it is under the star before the star reaches row 70.
AutoDemo:
    LDA AutoPlay
    BNE AutoTrack
    INC AutoTimer
    LDA AutoTimer
    CMP #AUTO_FRAMES
    BCC MoveDone
    LDA #$01
    STA AutoPlay            ; the demo starts
AutoTrack:
    LDA BallX
    SEC
    SBC #PLAYER_CENTRE
    CMP #P0_MIN
    BCS AutoHigh
    LDA #P0_MIN
AutoHigh:
    CMP #(P0_MAX + 1)
    BCC AutoCompare
    LDA #P0_MAX
AutoCompare:
    CMP PlayerX
    BEQ MoveDone
    BCC AutoLeft
    INC PlayerX
    JMP MoveDone
AutoLeft:
    DEC PlayerX
MoveDone:

; -----------------------------------------------------------------------------
; 3. FIRE — a new press resets the score to 000000
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while the button is pressed.  PrevFire is the edge latch,
; so a held button resets once, not once per frame.
    LDA INPT4
    BMI FireReleased
    LDA PrevFire
    BNE FireDone
    LDA #$01
    STA PrevFire
    JSR ScoreClear
    JMP FireDone
FireReleased:
    LDA #$00
    STA PrevFire
FireDone:

; -----------------------------------------------------------------------------
; 4. SELECT — a new press toggles the mark
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is pressed.  The scripted demo toggle jumps
; to SelectEdge, the same path as the switch, so both use ToggleMark.
    LDA SWCHB
    AND #$02
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA #$01
SelectEdge:                 ; checkpoint: A = 1 on a toggle
    JSR ToggleMark
    JMP SelectDone
SelectReleased:
    LDA #$00
    STA PrevSelect
SelectDone:

; -----------------------------------------------------------------------------
; 5. THE SCRIPTED TOGGLE — hide the mark once, at frame 240
; -----------------------------------------------------------------------------
; The demo is in stage 1 after frame 120.  At frame 240 it calls the SELECT
; path and advances to stage 2, so the toggle cannot repeat.
    LDA AutoPlay
    CMP #$01
    BNE AutoToggleDone
    LDA Frame
    CMP #AUTO_TOGGLE
    BNE AutoToggleDone
    LDA #$02
    STA AutoPlay
    LDA #$01
    JMP SelectEdge
AutoToggleDone:

; -----------------------------------------------------------------------------
; 6. POSITION THE SCORE — one HMOVE in VBLANK
; -----------------------------------------------------------------------------
; ScoreSetup sets NUSIZ=3 and VDEL on, positions P0/P1 at 56/64, and strobes
; the one HMOVE that applies HMP0/HMP1.  The ball's stale HMBL is applied
; too, but the ball is disabled until the play kernel and is repositioned by
; the top positioner, so nothing visible moves.
    JSR ScoreSetup

; -----------------------------------------------------------------------------
; 7. THE SCORE BAND'S COLOURS AND CONTROLS
; -----------------------------------------------------------------------------
; The score digits are white; the playfield is blank during the score band.
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    LDA #C_GOLD
    STA COLUPF
    LDA #C_BG
    STA COLUBK
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA ENABL
    STA GRP0
    STA GRP1
    LDA #$01
    STA CTRLPF              ; reflect the playfield; the ball is one pixel

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE LINE 0-8: THE SCORE BAND (9 lines)
; =============================================================================
; ScoreDraw consumes nine visible lines: line 0 is the setup/blank line, the
; rows are displayed on lines 1-8, and the cleanup shares line 8.  The
; library entry is the ScoreDraw checkpoint; the caller resumes on line 9.
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    JSR ScoreDraw

; =============================================================================
; VISIBLE LINE 9-13: THE TOP POSITIONER (5 lines)
; =============================================================================
; ScoreDone is visible line 9 / scanline 46.  The score's P0/P1 are at
; 56/64; the play needs P0 at PlayerX and the ball at BallX.  NUSIZ and
; VDEL are reset for one 8-pixel player; COLUP0 is red; the ball is off
; during the positioner so no stray pixel appears on line 50.
ScoreDone:                  ; checkpoint: scanline 46, visible line 9
    LDA #$00                ; NUSIZ 0 = one 8-pixel copy each
    STA NUSIZ0
    STA NUSIZ1
    LDA #$00
    STA VDELP0
    STA VDELP1
    LDA #C_PLAYER
    STA COLUP0
    LDA #C_GOLD
    STA COLUPF
    LDA #$00
    STA ENABL
    STA BallNext            ; row 0 is above the ball (BallY >= 8)

    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetGameP0           ; line 46 stall, line 47 division, ends on 48
    LDA BallX
    CLC
    ADC #(POS_BIAS + 1)     ; the ball's reset is one colour clock shorter
    JSR SetGameBall         ; line 48 stall, line 49 division, ends on 50
    STA HMOVE               ; line 50's HBLANK: apply HMP0 and HMBL
    ; The HMOVE is early in HBLANK.  Eight NOPs put the following WSYNC
    ; store at 50/25; a WSYNC parks the CPU until the HCount wrap whatever
    ; cycle it is written on, so the play band starts on line 51.
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    STA WSYNC               ; release on line 51, the first play line

; =============================================================================
; VISIBLE LINE 14-177: THE PLAY BAND (164 lines = 82 rows x 2)
; =============================================================================
; PlayStart is visible line 14 / scanline 51.  The row body stores in this
; order, which meets every pixel deadline on the steady row:
;
;   PF0       completes ~9     PF0 chunk 0: cycle 22.7
;   GRP0      completes ~16    P0's first pixel: (8+68)/3 = 25.3 (X=8)
;   PF1       completes ~23    PF1 chunk 4: cycle 28.0
;   ENABL     completes ~29    the ball's first pixel: (24+68)/3 = 30.7
;   PF2       completes ~36    PF2 chunk 12: cycle 38.7
;
; The ball's enable is a six-cycle lookahead pair (LDA BallNext + STA
; ENABL); the test for the next row runs after the PF stores, with the rest
; of the 152-cycle pair to spare.  The first WSYNC ends the work line; the
; loop tail and the second WSYNC run on the second line, and the JMP lands
; at the start of the next row's work line, so each row is exactly two
; scanlines.
; =============================================================================
; PLAYROW — one two-line row of the play band
; =============================================================================
; Y is the kernel row (0-81); it indexes P0Strip and the three PF planes.
; BallNext is the enable computed for this row by the previous row.  The
; lookahead test at the end computes the enable for row Y+1:
;
;   TYA + 1 - BallY, then CMP #4
;   carry set   -> the next row is outside the ball's four rows
;   carry clear -> the next row is inside; BallNext = 2
!macro PlayRow {
    LDA PlayPF0,Y
    STA PF0
    LDA P0Strip,Y
    STA GRP0
    LDA PlayPF1,Y
    STA PF1
    LDA BallNext
    STA ENABL
    LDA PlayPF2,Y
    STA PF2
    TYA
    CLC
    ADC #$01
    SEC
    SBC BallY
    CMP #$04
    LDA #$00
    BCS +
    LDA #$02
+
    STA BallNext
}

PlayStart:                  ; checkpoint: scanline 51, visible line 14
    LDY #$00

SkyLoop:
    +PlayRow
    STA WSYNC
    INY
    CPY #SKY_ROWS
    BEQ SkyDone
    STA WSYNC
    JMP SkyLoop
SkyDone:
    STA WSYNC
; Row 68 is the horizon: its PF bytes are $F0/$FF/$FF, the full width.
; It is part of the sky loop, so COLUPF stays gold for the horizon line.

    LDA #C_GROUND
    STA COLUPF
GroundLoop:
    +PlayRow
    STA WSYNC
    INY
    CPY #PLAY_ROWS
    BEQ GroundDone
    STA WSYNC
    JMP GroundLoop
GroundDone:
    STA WSYNC
; 82 rows x 2 lines = visible 14-177.  The last WSYNC releases the CPU on
; scanline 215, the first handover line.

; =============================================================================
; VISIBLE LINE 178-182: THE HANDOVER (5 lines)
; =============================================================================
; The handover is MarkSetup: three-copy close mode, VDEL on, gold, ball off,
; and the two players positioned at 16/24.  Each set routine is two lines;
; the fifth line carries the HMOVE.  No motion write follows it until the
; next frame's VBLANK.
HandoverStart:              ; checkpoint: scanline 215, visible line 178
MarkSetup:
    LDA #$03
    STA NUSIZ0
    STA NUSIZ1
    LDA #$01
    STA VDELP0
    STA VDELP1
    LDA #C_GOLD
    STA COLUP0
    STA COLUP1
    LDA #$00
    STA ENABL               ; the ball leaves the screen
    STA PF0                 ; the ground's full-width playfield ends here
    STA PF1
    STA PF2
    LDA #(MARK_P0_X + POS_BIAS)
    JSR SetMarkP0           ; line 215 stall, line 216 division, ends on 217
    LDA #(MARK_P1_X + POS_BIAS)
    JSR SetMarkP1           ; line 217 stall, line 218 division, ends on 219
    STA HMOVE               ; line 219's HBLANK: apply HMP0/HMP1
    ; The same store-position delay as the top positioner: the WSYNC
    ; store is at 219/25 and the mark band starts on line 220.
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    STA WSYNC               ; release on line 220, the first mark line

; =============================================================================
; VISIBLE LINE 183-191: THE MARK BAND (9 lines)
; =============================================================================
; MarkStart is visible line 183 / scanline 220.  MarkDraw consumes nine
; lines exactly like ScoreDraw: line 0 is the setup/blank line, rows 1-8 are
; the glyph rows, and the cleanup shares line 8.  When the mark is hidden,
; the same nine lines are consumed by nine WSYNCs, so the frame does not
; change.
MarkStart:                  ; checkpoint: scanline 220, visible line 183
    LDA MarkVisible
    BEQ MarkHidden
    JSR MarkDraw            ; nine lines: 220 setup, 221-228 rows
MarkDone:                   ; checkpoint: scanline 229, visible line 192
OverscanStart:              ; checkpoint: scanline 229, the first blank line
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; The hidden mark path lives after the overscan so the visible path can fall
; straight through MarkDone into OverscanStart.  It still runs during the
; mark band: MarkStart branches here, the nine WSYNCs cover 220-228, and the
; JMP returns to MarkDone at the start of line 229.
MarkHidden:
    LDA #$00
    STA GRP0                ; keep both players blank
    STA GRP1
    STA VDELP0              ; VDEL is a drawing tool, not a state
    STA VDELP1
    LDX #$09
MarkBlankLoop:
    STA WSYNC
    DEX
    BNE MarkBlankLoop
    JMP MarkDone

; =============================================================================
; SETGAMEP0 / SETGAMEBALL — two-line divide-by-15 positioning
; =============================================================================
; A = the desired left edge + POS_BIAS.  The first WSYNC starts a fresh line;
; the divide loop and the stores run on that line; the final WSYNC ends it.
; The worst case (A=147) is under 70 cycles, inside the 76-cycle line, so
; each call costs exactly two scanlines for every X.  That is what keeps
; PlayStart fixed.
SetGameP0:
    STA WSYNC
    SEC
DivGameP0:
    SBC #15
    BCS DivGameP0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    STA WSYNC
    RTS

SetGameBall:
    STA WSYNC
    SEC
DivGameBall:
    SBC #15
    BCS DivGameBall
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMBL
    STA RESBL
    STA WSYNC
    RTS

; =============================================================================
; SETMARKP0 / SETMARKP1 — the mark's two-line positioning
; =============================================================================
; This is the same divide-by-15 routine as SetGameP0/SetGameBall, with the
; mark's targets.  It is a copy, not a call to the score library: ScoreSetup
; hard-codes 56/64 and the library is shared by seven earlier lessons.
SetMarkP0:
    STA WSYNC
    SEC
DivMarkP0:
    SBC #15
    BCS DivMarkP0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    STA WSYNC
    RTS

SetMarkP1:
    STA WSYNC
    SEC
DivMarkP1:
    SBC #15
    BCS DivMarkP1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
    STA RESP1
    STA WSYNC
    RTS

; =============================================================================
; TOGGLEMARK — flip MarkVisible; SELECT and the demo share it
; =============================================================================
ToggleMark:
    LDA MarkVisible
    EOR #$01
    STA MarkVisible
MarkVisibleWrite:           ; checkpoint: A = the new MarkVisible (0/1)
    RTS

; =============================================================================
; MARKDRAW — the 48-pixel mark kernel
; =============================================================================
; Preconditions: MarkSetup ran (NUSIZ=3, VDEL on, P0=16, P1=24) and MarkBuf
; is page-aligned.  MarkDraw consumes NINE visible lines: line 0 is the
; setup/blank line, the eight rows are displayed on lines 1-8, and the
; cleanup shares line 8.
;
; The six stores and the seventh flush are the Lesson 39 VDEL sequence:
;
;   STA GRP0  col 0 (R)   stages R
;   STA GRP1  col 1 (A)   commits R to P0, stages A
;   STA GRP0  col 2 (C)   commits A to P1, stages C
;   STA GRP1  col 3 (I)   commits C to P0, stages I
;   STA GRP0  col 4 (N)   commits I to P1, stages N
;   STA GRP1  col 5 (G)   commits N to P0, stages G
;   STA GRP0  col 5 (G)   commits G to P1 (the seventh flush)
;
; A literal ScoreDraw clone does not work at X=16/24.  ScoreDraw's stores
; are timed for the score's copies at X=56/64, whose first pixels arrive at
; cycle (56+68)/3 = 41.3 and (64+68)/3 = 44.0.  Moving the block 40 pixels
; left moves every copy 13.3 cycles earlier: the mark's P0 copies arrive at
; cycles (16+68)/3 = 28.0, (32+68)/3 = 33.3 and (48+68)/3 = 38.7, and its
; P1 copies at 30.7, 36.0 and 41.3.  ScoreDraw's later commits land at
; cycles 44-53, after the mark's copies, so every copy would show the first
; column: the screen reads "RARARA", not "RACING".
;
; The kernel is unrolled: MarkPreload and MarkStores are expanded for the
; eight rows with fixed table addresses, so there is no loop counter or
; branch.  Each row is 15 cycles of preload, 3 for the WSYNC, and 41 of
; stores and loads = 59 cycles, well inside the 76-cycle line.  The
; GRP1/GRP0 writes that commit the six columns start at cycles 3, 9, 29,
; 32, 35 and 38 (write cycles 5, 11, 31, 34, 37 and 40).  The C commit at
; write 31 (CLK 93) sits in the gap between P0 copy 0 (CLK 84-91) and P0
; copy 1 (CLK 100-107); the later commits at CLK 102, 111 and 120 keep
; 6/5/4 CLK of margin before the P1 copy 1, P0 copy 2 and P1 copy 2
; windows.  That removes the C-to-R bleed and keeps every column on its
; own copy.
;
; The delay before the cleanup is the line-count adjustment: nine NOPs
; and a three-cycle BIT Frame.  Without it the unrolled kernel returns on
; line 229 too early; with it the cleanup's RTS spills onto scanline 229 at
; cycle 6, so the mark band still covers nine lines and the frame stays 262.

!macro MarkPreload .r {
    LDA MarkBuf+16+.r
    STA MarkTmp
    LDA MarkBuf+0+.r
    LDX MarkBuf+8+.r
}
!macro MarkStores .r {
    STA GRP0
    STX GRP1
    LDA MarkTmp
    STA GRP0
    LDY MarkBuf+32+.r
    LDA MarkBuf+24+.r
    LDX MarkBuf+40+.r
    BIT Frame
    NOP
    STA GRP1
    STY GRP0
    STX GRP1
    STX GRP0
}

MarkDraw:
    +MarkPreload 7
    STA WSYNC
MarkDrawRow:
    +MarkStores 7
    +MarkPreload 6
    STA WSYNC
    +MarkStores 6
    +MarkPreload 5
    STA WSYNC
    +MarkStores 5
    +MarkPreload 4
    STA WSYNC
    +MarkStores 4
    +MarkPreload 3
    STA WSYNC
    +MarkStores 3
    +MarkPreload 2
    STA WSYNC
    +MarkStores 2
    +MarkPreload 1
    STA WSYNC
    +MarkStores 1
    +MarkPreload 0
    STA WSYNC
    +MarkStores 0

    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    BIT Frame
    LDA #$00
    STA GRP0
    STA GRP1
    STA VDELP0
    STA VDELP1
    RTS


; =============================================================================
; THE MARK TABLE — ten 4x7 glyphs, two per 8x8 cell, column-major
; =============================================================================
; Column c, row r is MarkBuf + c*8 + r.  Each cell packs two letters:
; the left letter is the high nibble (bits 7-4) and the right letter is the
; low nibble (bits 3-0).  The word RACINGBEAM is five cells (RA, CI, NG, BE,
; AM) = 40 pixels; the sixth cell is blank.  Byte 0 of every cell is $00, so
; the lit block is seven rows (visible 184-190).  The table is page-aligned,
; so every LDA MarkBuf+n,Y is four cycles.
;
; The glyphs are 4 pixels wide and 7 pixels tall.  Each row is a nibble with
; bit 7 (of the nibble) as the leftmost pixel; the font is stored bottom-up
; like the five-wide score font.
    !align 255, 0
MarkBuf:
    ; cell 0: R | A
    !byte $00, $99, $99, $A9, $EF, $99, $99, $E6
    ; cell 1: C | I
    !byte $00, $6F, $96, $86, $86, $86, $96, $6F
    ; cell 2: N | G
    !byte $00, $96, $99, $B9, $BB, $D8, $D9, $96
    ; cell 3: B | E
    !byte $00, $EF, $98, $98, $EE, $98, $98, $EF
    ; cell 4: A | M
    !byte $00, $99, $99, $99, $F9, $9F, $9F, $69
    ; cell 5: blank (the word uses 40 of the 48 pixels)
    !byte $00, $00, $00, $00, $00, $00, $00, $00

; =============================================================================
; THE PLAY BAND'S PLAYFIELD PLANES — one byte per two-line row
; =============================================================================
; The three planes are page-aligned, so LDA PlayPFx,Y never crosses a page.
; The bytes change only at band boundaries:
;
;   rows  0- 1  star band A   PF1=$20 (chunk 6)
;   rows  2-15  dark sky
;   rows 16-17  star band B   PF1=$04 (chunk 9)
;   rows 18-31  dark sky
;   rows 32-33  star band C   PF2=$08 (chunk 15)
;   rows 34-47  dark sky
;   rows 48-49  star band D   PF1=$40 (chunk 5), PF2=$02 (chunk 13)
;   rows 50-67  dark sky
;   row  68     the horizon  PF0=$F0, PF1=PF2=$FF (full width)
;   rows 69-81  the ground   the same full-width bytes
;
; CTRLPF=$01 reflects the playfield, so every star and the horizon appear in
; both halves.  COLUPF is gold in the sky and on the horizon; the ground is
; dark green.  The one-pixel ball shares COLUPF, so it is gold in the sky
; and green on the ground — the blend near the catch is deliberate.
    !align 255, 0
PlayPF0:
    !fill 68, $00           ; rows 0-67: the sky has no PF0 star bits
    !fill 14, $F0           ; rows 68-81: the horizon and the ground

    !align 255, 0
PlayPF1:
    !byte $20, $20          ; rows 0-1: star band A
    !fill 14, $00           ; rows 2-15: dark sky
    !byte $04, $04          ; rows 16-17: star band B
    !fill 14, $00           ; rows 18-31: dark sky
    !fill 2, $00            ; rows 32-33: star band C uses PF2
    !fill 14, $00           ; rows 34-47: dark sky
    !byte $40, $40          ; rows 48-49: star band D
    !fill 18, $00           ; rows 50-67: dark sky
    !fill 14, $FF           ; rows 68-81: the horizon and the ground

    !align 255, 0
PlayPF2:
    !fill 2, $00            ; rows 0-1: star band A uses PF1
    !fill 14, $00           ; rows 2-15: dark sky
    !fill 2, $00            ; rows 16-17: star band B uses PF1
    !fill 14, $00           ; rows 18-31: dark sky
    !byte $08, $08          ; rows 32-33: star band C
    !fill 14, $00           ; rows 34-47: dark sky
    !byte $02, $02          ; rows 48-49: star band D
    !fill 18, $00           ; rows 50-67: dark sky
    !fill 14, $FF           ; rows 68-81: the horizon and the ground

; =============================================================================
; THE PLAYER'S STRIP — one byte per two-line row
; =============================================================================
; The player is eight kernel rows (16 scanlines) tall at rows 72-79, so the
; feet sit two rows above the bottom of the field.  The top row is solid:
; the falling ball meets the player's head anywhere across the 8-pixel body,
; which is what makes the auto-demo's catch repeatable.  Every other row is
; blank.  The strip is page-aligned for a four-cycle LDA.
    !align 255, 0
P0Strip:
    !fill PLAYER_TOP, $00
    !byte $FF, $3C, $3C, $18, $7E, $5A, $5A, $18
    !fill (PLAY_ROWS - PLAYER_TOP - PLAYER_ROWS), $00

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreInit, ScoreClear, ScoreSetup, ScoreSetDigit, ScoreAddOne, ScoreDraw,
; and ScoreFont live here.  The library must be sourced inside the ROM area
; (after * = $F000) and after include/vcs.asm.  Its ScoreSetup is the
; 56/64 routine; the mark has its own MarkSetup above.
    !source "include/score.asm"

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
