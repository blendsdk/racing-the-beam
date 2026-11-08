; =============================================================================
; LESSON 79 — EXERCISE 3 SOLUTION: The Playfield Mark (Stretch Goal)
; =============================================================================
; Part 11: Legendary Techniques
;
; What this program does:
;   The Lesson 79 calling card with the publisher mark drawn by the
;   playfield instead of the players.  PF0/PF1/PF2 draw a blocky 4-pixel
;   RACE wordmark in the bottom eight lines: twelve 4-pixel chunks, four
;   3-chunk letters, 48 pixels wide at TIA X=0-47.  CTRLPF=$02 is SCORE mode, so the left
;   half uses COLUP0 (gold) and the right half COLUP1 (background); only the
;   left-half mark is visible.  The players are blank and free.  The PF
;   table is 8 rows x 3 bytes = 24 bytes.  The frame, score and play band
;   are unchanged.
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
;     visible 178-182   the handover    5 lines   blank the players for the PF mark
;     visible 183-191   the mark        9 lines   the playfield mark kernel
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
;   The handover blanks both players, turns the ball off, clears VDEL, and
;   consumes five WSYNCs.  There is no mark positioner and no third HMOVE:
;   the playfield mark does not use a moving object.  The HMOVE budget drops
;   from three to two per frame (the score's and the play's).
;
; The mark band (visible 183-191):
;   The mark is a playfield kernel.  The 24-byte table is 8 rows x 3
;   bytes (PF0/PF1/PF2): four 3-chunk letters (RACE) across 12 chunks, each
;   chunk 4 pixels wide, so the blocky wordmark is 48 pixels across.  Line 0
;   is the setup/blank line; lines 1-8 write the table's PF bytes before the
;   playfield's first chunk (cycle 22.7).  The mark spans TIA X=0-47.
;   CTRLPF=$02 is SCORE mode: the
;   left half uses COLUP0 (gold) and the right half COLUP1 (background), so
;   only the left-half mark is visible.  The players are blank and free.
;
;   If MarkVisible=0 the band still consumes nine lines: the program skips
;   the PF rows, keeps the playfield blank, clears VDEL, and waits nine
;   WSYNCs.
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
;   MarkStart (220), MarkDone (229/7), OverscanStart (229/7);
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
;   $89-$8B            free (3 bytes)
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
; Build: acme -f plain -o build/exercise-03.bin \
;        lessons/part11-legendary/79-publisher-mark/exercise-03-solution.asm
; Run:   stella build/exercise-03.bin
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
; The playfield mark does not use the players.  Blank both players, turn the
; ball off, clear VDEL, and consume the five handover lines.  The mark band's
; setup line sets the PF colours and CTRLPF.
HandoverStart:              ; checkpoint: scanline 215, visible line 178
    LDA #$00
    STA PF0                 ; the ground's full-width playfield ends here
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL
    STA VDELP0
    STA VDELP1
    LDX #$05
HandoverWait:
    STA WSYNC
    DEX
    BNE HandoverWait

; =============================================================================
; VISIBLE LINE 183-191: THE MARK BAND (9 lines)
; =============================================================================
; The mark is drawn by the playfield, not the players.  Line 0 is the
; setup/blank line; lines 1-8 are the eight rows of a 24-byte PF table
; (8 rows x 3 bytes).  CTRLPF=$02 is SCORE mode: the left half uses
; COLUP0 (gold) and the right half COLUP1 (background), so the 12 chunks
; (48 pixels) of the blocky RACE wordmark appear only in the left half.
; The players are blank and free for the game.  When hidden, the same nine
; lines are consumed by nine WSYNCs with PF off.
MarkStart:                  ; checkpoint: scanline 220, visible line 183
    LDA MarkVisible
    BEQ MarkHidden
    LDA #C_GOLD
    STA COLUP0
    LDA #C_BG
    STA COLUP1
    LDA #$02                ; SCORE mode; the pattern repeats
    STA CTRLPF
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL
    STA VDELP0
    STA VDELP1
    STA WSYNC               ; line 0: the setup/blank line
    LDY #$07
MarkLine:
    LDA MarkPF0,Y
    STA PF0
    LDA MarkPF1,Y
    STA PF1
    LDA MarkPF2,Y
    STA PF2
    NOP                     ; put the row's WSYNC at a known store position
    NOP                     ; (a WSYNC parks the CPU until the HCount wrap
    NOP                     ; whatever cycle it is written on)
    STA WSYNC
    DEY
    BPL MarkLine
    BIT Frame                ; put the overscan entry at 229/7
MarkDone:                   ; checkpoint: scanline 229, visible line 192
OverscanStart:              ; checkpoint: scanline 229, the first blank line
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; The hidden path is after the overscan so the visible path falls straight
; through MarkDone.  It still covers the mark band: nine WSYNCs, 220-228.
MarkHidden:
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL
    STA VDELP0
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
; TOGGLEMARK — flip MarkVisible; SELECT and the demo share it
; =============================================================================
ToggleMark:
    LDA MarkVisible
    EOR #$01
    STA MarkVisible
MarkVisibleWrite:           ; checkpoint: A = the new MarkVisible (0/1)
    RTS

; =============================================================================
; THE MARK'S PF TABLE — eight rows x three bytes
; =============================================================================
; Row r (0 = bottom) is MarkPF0/1/2 + r.  The 12 chunks are four 3-chunk
; letters, RACE: R chunks 0-2, A 3-5, C 6-8, E 9-11.  PF0 carries chunks
; 0-3 (bit 4 = chunk 0), PF1 chunks 4-11 (bit 7 = chunk 4), and PF2 is
; always 0.  The table is page-aligned so each load is four cycles.
    !align 255, 0
MarkPF0:
    !byte $00, $D0, $D0, $D0, $D0, $B0, $D0, $30
    !align 255, 0
MarkPF1:
    !byte $00, $5F, $64, $64, $E6, $64, $64, $9F
    !align 255, 0
MarkPF2:
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
; 56/64 routine; this exercise's mark uses the playfield, not the score setup.
    !source "include/score.asm"

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
