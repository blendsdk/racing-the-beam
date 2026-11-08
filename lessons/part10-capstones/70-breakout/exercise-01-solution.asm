; =============================================================================
; LESSON 70: Capstone 2 — Breakout — Racing the Beam
; =============================================================================
; Part 10: Capstone Projects
;
; Exercise 1 solution: MULTI-HIT BRICKS.
;   The main lesson's Breakout with a second hit point per brick.  A 6-byte
;   BrickHP map (one bit per unique brick, bit 5 = leftmost) remembers which
;   bricks have been hit once.  The first hit clears the HP bit, keeps the
;   brick on screen, darkens its row, and scores 1; the second hit clears the
;   brick map bit, removes the brick, and scores 2.  The 6-byte BrickRowTable
;   now carries two bits per brick row (bit 0 = the ball is in the first
;   4-line half, bit 1 = the second half); the rest of the game is the main's.
;
; The screen (192 visible lines):
;   picture lines 0-8     the score band.  include/score.asm draws the nine
;                         lines (line 0 is the setup/blank line, lines 1-8 are
;                         the six digits, 000000 at power-on).
;   picture line 9        blank; NUSIZ0 returns to one copy and the play
;                         positioners are prepared.
;   picture lines 10-14   the positioners: the ball is positioned in VBLANK
;                         (the score's HMOVE applies it); the visible block
;                         positions P0 at PaddleX with one HMOVE.  The fifth
;                         line prepares brick row 0.
;   picture lines 15-62   the brick field: 6 brick rows x 8 lines.  Each
;                         row's PF0/PF1/PF2 come from the 64-entry BrickPF
;                         table, keyed by the 6-bit row mask.  Reflect mode
;                         (CTRLPF bit 0) mirrors the 6 unique bricks to 12
;                         visible per row.  The ball is enabled by the
;                         6-byte BrickRowTable, two bits per brick row (one
;                         per 4-line half).
;   picture lines 63-190  the play area: 32 rows x 4 lines.  The 32-byte
;                         PlayRowTable (bit 0 = P0 paddle, bit 1 = ball)
;                         drives P0 and the ball; the paddle is 8x8 (2 rows)
;                         and the ball is 4x4 (1 row).
;   picture line 191      blank.
;   9 + 1 + 5 + 48 + 128 + 1 = 192.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame is scanline 259, VblankStart 0, BodyStart 37, ScoreDone 46,
;   BrickStart 51, PlayStart 99, OverscanStart 229.
;
; The brick geometry:
;   Each brick is 8 pixels (2 playfield chunks) with a 4-pixel gap; 6 bricks
;   fill 68 of the 80 pixels of a half.  The first brick starts at X=8
;   (chunk 2), so the field is symmetric under reflect mode: the leftmost
;   brick covers X=8-15 and the mirrored rightmost brick covers X=144-151.
;   The six unique bricks map to the six mask bits, bit 5 = leftmost:
;
;     mask bit 5 (col 0): chunks 2-3   -> PF0 bits 6-7
;     mask bit 4 (col 1): chunks 5-6   -> PF1 bits 6-5
;     mask bit 3 (col 2): chunks 8-9   -> PF1 bits 3-2
;     mask bit 2 (col 3): chunks 11-12 -> PF1 bit 0 + PF2 bit 0
;     mask bit 1 (col 4): chunks 14-15 -> PF2 bits 2-3
;     mask bit 0 (col 5): chunks 17-18 -> PF2 bits 5-6
;
;   BrickPF is 64 entries x 3 bytes = 192 ROM bytes, stored as three 64-byte
;   columns (PF0, PF1, PF2) so the kernel indexes a mask without multiplying
;   by three: LDA BrickPF0,X / STA PF0, then PF1 and PF2.  The group is page
;   aligned so the 192 bytes never cross a page, and each column is 64-byte
;   aligned so an indexed load always takes the same cycles.
;
; The brick collision (all of it in VBLANK, on the previous frame's latch):
;   CXBLPF bit 7 = the ball overlapped the playfield.  The row is
;   (BallY - 15) / 8 (0-5).  The ball's centre X is BallX + 2.  On the left
;   half (centre < 80) the unique column is (centre - 8) / 12 (0-5); on the
;   right half it is 5 - ((centre - 80) / 12).  The bit is 1 << (5 - column).
;   A set bit clears the brick, decrements BricksLeft, adds one to the score,
;   and bounces: VY reverses, and VX also reverses when the centre is within
;   two pixels of the brick's left or right edge.  A hit on an already-empty
;   brick is ignored.
;
; The paddle and ball:
;   The paddle is P0, 8x8, at PaddleY=179 (play rows 29-30), X 8..152, and
;   moves 4 pixels/frame with the P0 left/right joystick bits (SWCHA bits
;   6/7, active low; include/vcs.asm is the authority).  The ball is 4x4,
;   the slow angle table's VX is -2..+2, the fast -3..+3, the turbo -4..+4;
;   VY is +-2..+-4.  It bounces off the play-area top?  No: the
;   ball must pass the play-area top (line 63) to reach the bricks, so the
;   top wall is the top of the brick field (Y=15).  It bounces off the left
;   and right walls (X=4 and X=152), and off the paddle through CXP0FB bit 6.
;   The paddle's five angle zones set VX (-2,-1,0,+1,+2 slow; wider at
;   speed 3 and 4) and VY stays negative (the ball goes up).
;
; Lives and levels:
;   Three lives.  A miss (BallY > 190) decrements Lives; at zero GameState=1
;   and fire restarts.  Clearing every unique brick of the pattern advances
;   the level: three patterns (Level0 full 36, Level1 diamond 24, Level2
;   checkerboard 18), then the patterns repeat with a faster ball (speed 2
;   at level 0, 3 at levels 1-2, 4 from level 3 on).  BricksLeft is the
;   pattern's brick count.
;
; The score library:
;   include/score.asm owns $A0-$D7 and draws nine visible lines.  ScoreSetup
;   is called every frame in VBLANK (it re-positions P0/P1 at 56/64 and
;   strobes one HMOVE).  ScoreDraw runs first in the body; then P0 is
;   repositioned to PaddleX with a second HMOVE; the ball was positioned in
;   VBLANK and the score's HMOVE applied it.
;   P1 stays at the score's X with GRP1=0, so it is invisible in the play
;   area.  ScoreAddOne adds one per brick; the six digits handle the carry.
;
; The auto-demo:
;   After 120 frames with no left/right input the paddle tracks the ball at
;   up to 4 pixels/frame, aiming three pixels to one side of the ball and
;   alternating every 32 frames so the bounce angle keeps changing.  A miss
;   re-serves.  At frame 480 (eight seconds) the demo advances the pattern
;   once, so the ten-second capture shows the second level; a human player
;   is never affected because any joystick input resets DemoTimer to zero.  The
;   demo is deterministic; the doc discloses the shortcut.
;
; RAM map (the exact map; +clean_start zeroes every byte):
;   $80-$85  BrickMap      6 bytes; 6 bits per row; bit 5 = leftmost brick
;   $86-$8B  BrickRowTable 6 bytes; two bits per brick row: bit 0 = the ball
;                          is in the row's first 4-line half, bit 1 = the
;                          second half; bit 7 = the row has a once-hit brick
;                          (it is drawn in the darker colour)
;   $8C-$91  BrickHP       6 bytes; one bit per unique brick (bit 5 =
;                          leftmost).  Set = the brick is fresh; clear = the
;                          brick has taken its first hit and scores 2 when
;                          it finally breaks.
;   $92      BallX         4..152 (the ball's left edge)
;   $93      BallY         15..190 (the ball's top line, visible coordinates)
;   $94      BallVX        signed: -4..+4 (the turbo table)
;   $95      BallVY        signed: -4..+4
;   $96      PaddleX       8..152 (the paddle's left edge)
;   $97      DemoTimer     the demo's level timer: +1 every two frames; the
;                         skip fires at 240 (480 frames = 8 seconds).  The
;                         paddle's Y is the constant PADDLE_Y = 179; dropping
;                         the PaddleY variable keeps the 14-byte map.
;   $98      Lives         3..0
;   $99      Level         0.. (pattern = Level mod 3; speed from Level)
;   $9A      BricksLeft    the current pattern's remaining bricks
;   $9B      Frame         the free-running frame counter (the demo's
;                         two-frame parity is bit 0)
;   $9C      ServeTimer    60..1 while the ball is parked, 0 in play
;   $9D      GameState     0 = play, 1 = game over
;   $9E      Temp          scratch (also the play kernel's ball byte)
;   $9F      CurP0         scratch (also the play kernel's GRP0 byte)
;   $A0-$D7  the score library (ScoreDigits, ScoreRow, ScoreTmp, ScoreBuf)
;   $D8-$F7  PlayRowTable  32 bytes; bit 0 = P0 paddle, bit 1 = ball
;   $F8-$FF  stack
;
;   The score add is called from the top-level VBLANK, never from inside
;   BallStep: the library's deepest stack use is seven bytes with one JSR
;   level, which fits $F9-$FF.  A second JSR level would reach $F7 and
;   corrupt the PlayRowTable.
;
; Controls:
;   Left joystick left/right moves the paddle (4 pixels/frame).
;   Fire starts a waiting serve early; fire restarts after game over.
;
; Checkpoints (the A/X/Y/SP values are the state at the label):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   ScoreDone (46), BrickStart (51), PlayStart (99), OverscanStart (229),
;   PaddleXRead (A=PaddleX), BallXRead (A=BallX), BallYRead (A=BallY),
;   BrickHit (A=the brick row 0-5), HpHit (A=the new HP mask after the first
;   hit), BrickClear (A=the new brick mask after the final hit),
;   ScoreAdd (the score library: A=the digit after the add),
;   LifeLost (A=the new Lives), LevelStart (A=the new Level).
;
; Build: acme -f plain -o build/lesson70.bin \
;        lessons/part10-capstones/70-breakout/70-breakout.asm
; Run:   stella build/lesson70.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
; The 42-cycle fill keeps each zone-boundary WSYNC store before the end of
; the line; a WSYNC written late still halts to the next line, which is why
; the fill is fixed-length.  It is timing, not decoration.
!macro burn_line {
    !fill 21, $EA          ; 21 NOPs = 42 cycles
}

VBLANK_TIMER   = 44       ; 1 + 43 x 64 = 2753 cycles = 36.2 lines; the
                          ; timer + wait_timer's WSYNC make the measured 37-line VBLANK
OVERSCAN_TIMER = 36       ; 1 + 35 x 64 = 2241 cycles = 29.5 lines; the
                          ; timer + WSYNC make the measured 30-line overscan

PADDLE_MIN     = 8        ; the paddle's left-edge limits
PADDLE_MAX     = 152
PADDLE_Y       = 179      ; play rows 29-30: visible lines 179-186
PADDLE_SPEED   = 4

BALL_LEFT      = 4        ; the ball's wall limits (its left edge)
BALL_RIGHT     = 152
BALL_TOP       = 15       ; the top of the brick field: the ball's ceiling
BALL_BOTTOM    = 190      ; BallY > 190 is a miss
SERVE_FRAMES   = 60

BRICK_TOP      = 15       ; visible line of the first brick row
BRICK_ROWS     = 6
BRICK_ROW_LINES= 8

PLAY_TOP       = 63       ; visible line of the first play row
PLAY_ROWS      = 32

PADDLE_BIAS    = 3        ; the Lesson 26 player positioning bias
BALL_BIAS      = 4        ; the ball's output delay is one clock shorter

C_SCORE        = $0E      ; the score digits: white
C_PADDLE       = $C8      ; P0 in the play area: green
C_BRICK        = $28      ; a fresh brick: orange
C_BRICK_HIT    = $26      ; a row with a once-hit brick: darker orange
C_BALL         = $0E      ; the ball in the play area: white
C_BG           = $00      ; black

AUTO_START     = 120      ; frames with no input before the auto-demo
DEMO_LEVEL     = 240      ; DemoTimer count (every two frames) for the skip:
                          ; 240 x 2 = 480 frames = 8 seconds

; =============================================================================
; RAM ALLOCATION ($80-$FF; the score library owns $A0-$D7, the stack $F8-$FF)
; =============================================================================
BrickMap     = $80        ; 6 bytes ($80-$85)
BrickRowTable= $86        ; 6 bytes ($86-$8B)
BrickHP      = $8C        ; 6 bytes ($8C-$91)
BallX        = $92
BallY        = $93
BallVX       = $94
BallVY       = $95
PaddleX      = $96
DemoTimer    = $97        ; the demo's level timer: +1 every two frames
Lives        = $98
Level        = $99
BricksLeft   = $9A
Frame        = $9B
ServeTimer   = $9C
GameState    = $9D
Temp         = $9E
CurP0        = $9F
PlayRowTable = $D8        ; 32 bytes ($D8-$F7)

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreSetup, ScoreDraw, ScoreInit, ScoreClear, ScoreSetDigit, ScoreAddOne and
; ScoreFont live here.  The library owns $A0-$D7 and is sourced after the ROM
; origin so its code has a program counter.  The reset vector at $FFFC still
; points at this lesson's Reset below.
    !source "include/score.asm"

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joystick)

    LDA #C_SCORE
    STA COLUP0              ; the score's left digits
    STA COLUP1              ; the score's right digits
    LDA #C_BRICK
    STA COLUPF              ; the bricks (and the ball in the brick zone)
    LDA #C_BG
    STA COLUBK
    LDA #$21
    STA CTRLPF              ; reflect the left half + a 4-pixel ball
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    STA REFP0
    STA REFP1
    STA VDELP0
    STA VDELP1
    STA VDELBL
    STA GRP0
    STA GRP1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2

    LDA #3
    STA Lives
    LDA #0
    STA Level
    STA GameState
    STA Frame
    STA DemoTimer
    STA BallVY
    LDA #60
    STA PaddleX
    LDA #62
    STA BallX               ; the serve's starting X, at the paddle
    LDA #175
    STA BallY               ; just above the paddle
    LDA #1
    STA BallVX              ; the serve drifts right
    LDA #SERVE_FRAMES
    STA ServeTimer
    LDA #0
    STA CXCLR

    JSR ScoreInit
    JSR ScoreClear          ; the display reads 000000
    LDA #0                  ; pattern 0: the full field
    JSR LoadPattern

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK              ; blank the picture while the game thinks
    +set_timer VBLANK_TIMER
    INC Frame

; The previous frame left the playfield and the sprites latched.  Clear them
; before the score band: the score uses only P0/P1/PF=0, and the ball would
; otherwise appear at BallX during the score's nine lines.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA ENABL
    STA GRP0
    STA GRP1

; -----------------------------------------------------------------------------
; 1. THE POSITIONERS — the ball in VBLANK, then the score's one HMOVE
; -----------------------------------------------------------------------------
; The ball is independent of the score, so its coarse position and HMBL are
; set before ScoreSetup.  ScoreSetup ends with one HMOVE, which applies P0,
; P1 and the ball in the same horizontal blank.  The ball's position is fixed
; for the frame; the score band keeps ENABL=0.
    LDA BallX
    CLC
    ADC #BALL_BIAS
    JSR SetCoarseBL
    JSR ScoreSetup
; The score's HMOVE has applied P0/P1/the ball.  Zero P1's and the ball's
; fine offsets so the play-area HMOVE moves only the paddle.
    LDA #$00
    STA HMP1
    STA HMBL

; -----------------------------------------------------------------------------
; 2. READ THE INPUT, THE FIRE EDGE, AND THE AUTO-DEMO
; -----------------------------------------------------------------------------
    JSR ReadInput

; --- a restart or the demo's level advance runs at the top level -------------
; ReadInput only sets a request in Temp.  The score library is called from here,
; never from inside ReadInput: one JSR level keeps its pushes inside $F8-$FF.
    LDA Temp
    CMP #$FF
    BNE NoRestartRequest
    LDA #0
    STA GameState
    STA Level
    STA Frame
    STA DemoTimer
    STA BallVY
    LDA #3
    STA Lives
    LDA #60
    STA PaddleX
    LDA #62
    STA BallX
    LDA #175
    STA BallY
    LDA #1
    STA BallVX
    LDA #SERVE_FRAMES
    STA ServeTimer
    JSR ScoreClear
    LDA #0
    JSR LoadPattern
NoRestartRequest:
    LDA Temp
    CMP #$FE
    BNE NoLevelRequest
    JSR LevelUp
NoLevelRequest:

; -----------------------------------------------------------------------------
; 3. THE SERVE TIMER (the ball is parked at the paddle until it reaches zero)
; -----------------------------------------------------------------------------
    JSR ServeStep

; -----------------------------------------------------------------------------
; 4. THE BALL: THE LATCHES, THE MOTION, THE WALLS, THE PADDLE, THE BRICKS
; -----------------------------------------------------------------------------
; Temp is the "a brick was cleared this frame" flag.  ScoreAddOne is called
; from this top level (not from BallStep): the score library's deepest stack
; use fits only with one JSR level.
    LDA #0
    STA Temp
    JSR BallStep
    LDA Temp                ; 0 = no brick, 1 = first hit, 2 = final hit
    BEQ NoBrickScore
BrickScoreLoop:
    JSR ScoreAddOne         ; the score library's ScoreAdd checkpoint is inside
    DEC Temp
    BNE BrickScoreLoop
NoBrickScore:

; -----------------------------------------------------------------------------
; 5. THE LEVEL CHECK AND THE ROW TABLES
; -----------------------------------------------------------------------------
    LDA BricksLeft
    BNE NoLevelUp
    JSR LevelUp
NoLevelUp:
    JSR BuildTables

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE 0-8 — THE SCORE BAND (nine lines from the score library)
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, picture line 0
    JSR ScoreDraw           ; nine lines; returns at scanline 46

; =============================================================================
; VISIBLE 9 — THE BLANK LINE
; =============================================================================
ScoreDone:                  ; checkpoint: scanline 46, picture line 9
    LDA #$00
    STA NUSIZ0              ; one 8-pixel copy for the paddle
    STA PF0
    STA PF1
    STA PF2
    STA ENABL
    LDA #C_PADDLE
    STA COLUP0              ; the score's pixels are already latched white
    STA WSYNC               ; consume picture line 9 -> line 10

; =============================================================================
; VISIBLE 10-14 — THE PLAY POSITIONERS (five lines)
; =============================================================================
; Five lines are 10-14 (scanlines 47-51).  Only P0 needs a coarse position
; here: the ball was positioned in VBLANK, and the score's HMOVE applied it.
; P1 and the ball get zero fine offsets before this second HMOVE so it moves
; only the paddle.  The six NOPs before the first WSYNC push its write past
; the start of the visible area (cycle ~23) so it really ends the line.
; SetCoarseP0 pads the divide to a fixed length, so the HMOVE lands on the
; same line for every paddle position.
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    LDA PaddleX
    CLC
    ADC #PADDLE_BIAS
    JSR SetCoarseP0
    STA WSYNC               ; the divide's fixed length -> the HMOVE line
    STA HMOVE               ; the HMOVE line's HBLANK
; The first brick row's colour: a row with a once-hit brick is darker.
    LDA BrickRowTable+0
    AND #$80                ; bit 7: row 0 has a once-hit brick
    BEQ ExPosFresh
    LDA #C_BRICK_HIT
    JMP ExPosColour
ExPosFresh:
    LDA #C_BRICK
ExPosColour:
    STA COLUPF
    +burn_line
    STA WSYNC               ; the HMOVE's stall ends on this line
    NOP                     ; the halt has taken effect; BrickStart is line 51

; =============================================================================
; VISIBLE 14 — THE BRICK ROW 0 SETUP (the checkpoint line)
; =============================================================================
; The first brick row's PF bytes and the first 4-line half's ENABL are set
; up here, on the fifth positioner line.  The actual PF stores run at the
; start of line 15 (scanline 52), before the playfield's first pixels.
BrickStart:                 ; checkpoint: scanline 51, picture line 14
    LDX #0
    LDA BrickRowTable,X
    AND #$01                ; bit 0: the ball is in the first 4-line half
    ASL                     ; 0 or 1 -> 0 or 2 (the ENABL value)
    STA CurP0               ; the first half's ENABL byte (0 or 2)
    LDA #0
    STA Temp                ; the brick row counter
    NOP
    NOP
    +burn_line
    STA WSYNC               ; consume picture line 14 -> line 15

; =============================================================================
; VISIBLE 15-62 — THE BRICK FIELD: 6 ROWS x 8 LINES
; =============================================================================
; Each row's first line stores the three PF bytes and the first half's ENABL.
; The order is ENABL, PF0, PF1, PF2: ENABL's store lands at cycle 13 (before
; the ball's leftmost pixel at cycle 24), PF0 at 20 (before its deadline
; 22.7), PF1 at 27 (before 28), PF2 at 34 (before 38.7).  The second half's
; ENABL is written at the start of line 5.  The next row's first-half ENABL
; is prepared during line 5.
BrickRowLoop:               ; eight lines: the row's first line starts here
    LDY Temp
    LDX BrickMap,Y          ; the row's 6-bit mask (X = the PF index)
    LDA CurP0
    STA ENABL               ; the first 4-line half's ball bit
    LDA BrickPF0,X
    STA PF0
    LDA BrickPF1,X
    STA PF1
    LDA BrickPF2,X
    STA PF2

    LDA BrickRowTable,Y
    AND #$02                ; bit 1: the ball is in the second 4-line half
    STA CurP0               ; hold the second half's ENABL until line 5

    STA WSYNC               ; line 1
    STA WSYNC               ; line 2
    STA WSYNC               ; line 3
    STA WSYNC               ; line 4

    LDA CurP0
    STA ENABL               ; line 5: the second half's ball bit
    LDY Temp
    INY                     ; the next brick row
    CPY #BRICK_ROWS
    BEQ BrickNoNextRow
    LDA BrickRowTable,Y
    AND #$01                ; the next row's first-half ball bit
    ASL                     ; 0 or 1 -> 0 or 2
    STA CurP0
BrickNoNextRow:
    STA WSYNC               ; line 5
    STA WSYNC               ; line 6
    STA WSYNC               ; line 7
    ; line 8 is the one-line vertical gap between brick rows: blank the
    ; playfield before this line's visible area, then wait it out.  The gap
    ; line also chooses the next row's colour: a row with any once-hit brick
    ; is drawn in the darker colour.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA Temp
    CMP #(BRICK_ROWS - 1)
    BEQ BrickLastRow
    LDY Temp
    INY                     ; the next brick row
    LDA BrickRowTable,Y
    AND #$80                ; bit 7: the next row has a once-hit brick
    BEQ BrickGapFresh
    LDA #C_BRICK_HIT
    JMP BrickGapColour
BrickGapFresh:
    LDA #C_BRICK
BrickGapColour:
    STA COLUPF
    STA WSYNC               ; line 8
    INC Temp
    JMP BrickRowLoop
BrickLastRow:
    ; line 8 of the last brick row is picture line 62 (scanline 99); the
    ; play row 0 is prepared here and the WSYNC consumes the line.
    ; (falls through to PlayStart)

; =============================================================================
; VISIBLE 62 — THE PLAY ROW 0 SETUP (the checkpoint line)
; =============================================================================
PlayStart:                  ; checkpoint: scanline 99, picture line 62
    LDA #C_BALL             ; the last brick row's gap: the play area is next
    STA COLUPF
    LDX #0
    LDA PlayRowTable,X
    TAY
    LDA DecodeP0,Y
    STA CurP0
    LDA DecodeBall,Y
    STA Temp
    STA WSYNC               ; consume picture line 62 -> line 63

; =============================================================================
; VISIBLE 63-190 — THE PLAY AREA: 32 ROWS x 4 LINES
; =============================================================================
; The first line of every row stores GRP0 and ENABL and clears the playfield
; (the PF is still the last brick row's).  The store order and timing:
; GRP0 at cycle 17 (the paddle's leftmost X=8 has deadline 25.3), ENABL at
; cycle 23 (the ball's leftmost X=4 has deadline 24).  The PF clears that
; follow are no-ops: the brick field's gap line already blanked the PF.
; The fourth line decodes the next row.
PlayRowLoop:
    NOP
    NOP
    NOP                     ; match the first row's phase to the steady state
    LDA #C_BALL
    STA COLUPF              ; the ball in the play area is white
    LDA CurP0
    STA GRP0
    LDA Temp
    STA ENABL
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC               ; line 1

    STA WSYNC               ; line 2
    STA WSYNC               ; line 3

    INX
    CPX #PLAY_ROWS
    BEQ PlayNoNextRow
    LDA PlayRowTable,X
    TAY
    LDA DecodeP0,Y
    STA CurP0
    LDA DecodeBall,Y
    STA Temp
PlayNoNextRow:
    STA WSYNC               ; line 4
    CPX #PLAY_ROWS
    BNE PlayRowLoop

; =============================================================================
; VISIBLE 191 — THE BLANK LINE
; =============================================================================
; The last play row's sprites are still latched.  Clear them immediately:
; the stores land at cycles 5 and 8, before this line's visible area starts.
; The colour restores then push the final WSYNC past the HBLANK (cycle ~23)
; so the blank line is really displayed and the overscan starts on 229.
    LDA #$00
    STA GRP0
    STA ENABL
    LDA #C_SCORE
    STA COLUP0
    STA COLUP1
    LDA #C_BRICK
    STA COLUPF
    +burn_line
    STA WSYNC               ; consume picture line 191 -> overscan
    NOP                     ; the halt has taken effect; overscan is line 229

; =============================================================================
; OVERSCAN — 30 lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; READ INPUT — the paddle, the fire button, and the auto-demo
; =============================================================================
; SWCHA is active low.  P0's left/right are bits 6/7 (include/vcs.asm); a
; held direction resets DemoTimer, the auto-demo timer.  With no
; direction for 120 frames the demo takes over.  Fire (INPT4 bit 7) starts
; a waiting serve early, and restarts after game over.
ReadInput:
    LDA PaddleX
PaddleXRead:                ; checkpoint: A = PaddleX
    LDA BallX
BallXRead:                  ; checkpoint: A = BallX
    LDA BallY
BallYRead:                  ; checkpoint: A = BallY

; --- fire: restart at game over, or shorten a waiting serve ---
    LDA INPT4
    AND #$80
    BNE ReadNoFire
    LDA GameState
    BNE ReadRequestRestart
    LDA ServeTimer
    BEQ ReadNoFire
    LDA #$01
    STA ServeTimer          ; the next ServeStep decrements to zero
ReadNoFire:

; --- game over: wait for fire, or let the demo restart after two seconds ---
    LDA GameState
    BNE ReadGameOver

; --- the joystick or the demo ---
    LDA SWCHA
    AND #$C0                ; P0 left/right (bits 6/7), active low
    CMP #$C0
    BEQ ReadNoDirection
    LDA #$00
    STA DemoTimer           ; a direction takes over; reset the demo timer
    LDA SWCHA
    AND #$40                ; left
    BNE ReadMoveRight
    LDA PaddleX
    SEC
    SBC #PADDLE_SPEED
    CMP #PADDLE_MIN
    BCS ReadStoreLeft
    LDA #PADDLE_MIN
ReadStoreLeft:
    STA PaddleX
    RTS
ReadMoveRight:
    LDA SWCHA
    AND #$80                ; right
    BNE ReadDone
    LDA PaddleX
    CLC
    ADC #PADDLE_SPEED
    CMP #(PADDLE_MAX + 1)
    BCC ReadStoreRight
    LDA #PADDLE_MAX
ReadStoreRight:
    STA PaddleX
    RTS

ReadNoDirection:
    LDA Frame
    AND #$01
    BNE ReadDemoTick
    INC DemoTimer           ; one count every two frames
ReadDemoTick:
    LDA DemoTimer
    CMP #(AUTO_START / 2)   ; 60 counts = 120 frames = 2 seconds
    BCC ReadDone
    JSR AutoPaddle
    LDA DemoTimer
    CMP #DEMO_LEVEL
    BNE ReadDone
    LDA #(AUTO_START / 2)   ; keep the demo active after the skip
    STA DemoTimer
    LDA #$FE                ; ask the top-level VBLANK for the level advance
    STA Temp
ReadDone:
    RTS

; --- game over: fire (or the demo after two seconds) restarts ---
ReadGameOver:
    LDA Frame
    CMP #AUTO_START
    BCC ReadDone
    ; fall into the request
ReadRequestRestart:
    LDA #$FF                ; ask the top-level VBLANK for the restart
    STA Temp
    RTS

; =============================================================================
; AUTO PADDLE — track the ball at up to four pixels per frame
; =============================================================================
; The target is the paddle position that puts the paddle's centre three
; pixels to one side of the ball's centre: BallX - 5, or BallX + 1.  The
; side alternates with Frame bit 5 so the paddle hit keeps changing the
; ball's angle.  The target is clamped to 8..152 and the paddle moves at
; most PADDLE_SPEED pixels toward it.
AutoPaddle:
    LDA Frame
    AND #$20
    BEQ AutoAimLeft
    LDA BallX
    CLC
    ADC #1
    JMP AutoClamp
AutoAimLeft:
    LDA BallX
    SEC
    SBC #5
    BCS AutoClamp
    LDA #0
AutoClamp:
    CMP #PADDLE_MIN
    BCS AutoClampHigh
    LDA #PADDLE_MIN
    JMP AutoTargetReady
AutoClampHigh:
    CMP #(PADDLE_MAX + 1)
    BCC AutoTargetReady
    LDA #PADDLE_MAX
AutoTargetReady:
    STA Temp
    CMP PaddleX
    BEQ AutoDone
    BCC AutoMoveLeft
    LDA PaddleX
    CLC
    ADC #PADDLE_SPEED
    CMP #(PADDLE_MAX + 1)
    BCC AutoStoreRight
    LDA #PADDLE_MAX
AutoStoreRight:
    STA PaddleX
    RTS
AutoMoveLeft:
    LDA PaddleX
    SEC
    SBC #PADDLE_SPEED
    CMP #PADDLE_MIN
    BCS AutoStoreLeft
    LDA #PADDLE_MIN
AutoStoreLeft:
    STA PaddleX
AutoDone:
    RTS

; =============================================================================
; SERVE STEP — count the parked frames; at zero the ball launches upward
; =============================================================================
ServeStep:
    LDA GameState
    BNE ServeStepDone
    LDA ServeTimer
    BEQ ServeStepDone
    DEC ServeTimer
    BNE ServeStepDone
    JSR GetSpeed            ; A = 2, 3 or 4
    EOR #$FF
    CLC
    ADC #1
    STA BallVY              ; the launch: straight up at the level's speed
ServeStepDone:
    RTS

; =============================================================================
; GET SPEED — A = 2 at level 0, 3 at levels 1-2, 4 from level 3 on
; =============================================================================
GetSpeed:
    LDA Level
    BEQ SpeedIsTwo
    CMP #3
    BCS SpeedIsFour
    LDA #3
    RTS
SpeedIsTwo:
    LDA #2
    RTS
SpeedIsFour:
    LDA #4
    RTS

; =============================================================================
; BALL STEP — the latches, the motion, the paddle, the bricks, the miss
; =============================================================================
; Temp is the "brick cleared" flag (set to 1 only on a real brick removal).
; The paddle and brick latches are read first, then CXCLR clears them for the
; next frame.  The ball's motion happens after the paddle test, so a paddle
; hit can move the ball out of the paddle before the next frame's latch.
BallStep:
    LDA GameState
    BNE BallFrozen
    LDA ServeTimer
    BNE BallFrozen

; --- the paddle latch: CXP0FB bit 6, only while the ball is moving down ---
    LDA CXP0FB
    AND #$40
    BEQ BallCheckBrick
    LDA BallVY
    BMI BallCheckBrick      ; moving up: a stale overlap, not a hit
    JSR PaddleBounce
    JMP BallClearLatch

BallCheckBrick:
    LDA CXBLPF
    AND #$80
    BEQ BallClearLatch
    LDA BallVY
    BPL BallClearLatch      ; moving down: a stale overlap, not a hit
    JSR BrickCollision

BallClearLatch:
    LDA #$00
    STA CXCLR               ; the latches are read; start the next frame clean

; --- the horizontal and vertical motion ---
    LDA BallX
    CLC
    ADC BallVX
    STA BallX
    LDA BallY
    CLC
    ADC BallVY
    STA BallY

; --- the left and right walls at X=4 and X=152 ---
    LDA BallX
    CMP #BALL_LEFT
    BCS BallCheckRight
    LDA #BALL_LEFT
    STA BallX
    JSR ReverseVX
BallCheckRight:
    LDA BallX
    CMP #(BALL_RIGHT + 1)
    BCC BallCheckTop
    LDA #BALL_RIGHT
    STA BallX
    JSR ReverseVX

; --- the top wall at Y=15 (the ball passes the play-area top at 63) ---
BallCheckTop:
    LDA BallY
    CMP #BALL_TOP
    BCS BallCheckMiss
    LDA #BALL_TOP
    STA BallY
    JSR ReverseVY

; --- the miss: the ball's top passed the last play line ---
BallCheckMiss:
    LDA BallY
    CMP #(BALL_BOTTOM + 1)
    BCC BallStepDone
    JMP LifeLostHandler
BallStepDone:
    RTS

BallFrozen:
    LDA #$00
    STA CXCLR
    RTS

; =============================================================================
; PADDLE BOUNCE — the five angle zones set VX; VY always goes up
; =============================================================================
; The ball's centre (BallX+2) is compared with the paddle's centre
; (PaddleX+4): the offset plus three is a 0..10 index.  The zone boundaries
; give the five zones 2,2,3,2,2 pixels wide.  VY is set to -speed and the
; ball is moved to PaddleY-4 so the next frame's latch is clean.
PaddleBounce:
    LDA BallX
    SEC
    SBC PaddleX
    CLC
    ADC #3                  ; 0..10 (the ball spans -3..+7 around the paddle)
    CMP #2
    BCC PaddleZone0
    CMP #4
    BCC PaddleZone1
    CMP #7
    BCC PaddleZone2
    CMP #9
    BCC PaddleZone3
    LDX #4
    JMP PaddleZoneReady
PaddleZone0:
    LDX #0
    JMP PaddleZoneReady
PaddleZone1:
    LDX #1
    JMP PaddleZoneReady
PaddleZone2:
    LDX #2
    JMP PaddleZoneReady
PaddleZone3:
    LDX #3
PaddleZoneReady:
    ; choose the slow, fast or turbo angle table from Level
    LDA Level
    BEQ PaddleSlow
    CMP #3
    BCS PaddleTurbo
    LDA PaddleAngleFast,X
    JMP PaddleAngleHave
PaddleSlow:
    LDA PaddleAngleSlow,X
    JMP PaddleAngleHave
PaddleTurbo:
    LDA PaddleAngleTurbo,X
PaddleAngleHave:
    STA BallVX
    JSR GetSpeed
    EOR #$FF
    CLC
    ADC #1
    STA BallVY              ; up at the level's speed
    LDA #(PADDLE_Y - 4)
    STA BallY               ; just above the paddle
    RTS

; =============================================================================
; BRICK COLLISION — the row, the unique column, the mask bit, the bounce
; =============================================================================
; On entry Y is free and Temp is 0 (the top level's "brick cleared" flag).
; The row stays in Y through the whole routine: the column math uses A and X
; only, and the mask lookups use BrickMap,Y.  A hit on an already-empty brick
; returns without touching Temp, so the top level does not score it.
BrickCollision:
    ; row = (BallY - 15) / 8
    LDA BallY
    SEC
    SBC #BRICK_TOP
    BCS BrickRowOK
    LDA #0
BrickRowOK:
    LDY #0
BrickDiv8:
    CMP #8
    BCC BrickRowDone
    SBC #8
    INY
    BNE BrickDiv8
BrickRowDone:
    TYA
BrickHit:                   ; checkpoint: A = the brick row 0-5
    ; the ball's centre X
    LDA BallX
    CLC
    ADC #2
    CMP #80
    BCS BrickRightHalf

    ; left half: col = (centre - 8) / 12
    SEC
    SBC #8
    BCS BrickLeftOK
    LDA #0
BrickLeftOK:
    LDX #0
BrickDiv12:
    CMP #12
    BCC BrickColReady
    SBC #12
    INX
    BNE BrickDiv12
    JMP BrickColReady

    ; right half: col = 5 - ((centre - 80) / 12)
BrickRightHalf:
    SEC
    SBC #80
    BCS BrickRightOK
    LDA #0
BrickRightOK:
    LDX #0
BrickDiv12R:
    CMP #12
    BCC BrickRightDone
    SBC #12
    INX
    BNE BrickDiv12R
BrickRightDone:
    TXA
    EOR #$FF
    CLC
    ADC #6                  ; 5 - X
    CMP #6                  ; the far-right gap can index past col 5
    BCC BrickRightClamp
    LDA #5
BrickRightClamp:
    TAX
BrickColReady:
    ; test the brick's bit: bit 5 = leftmost column
    LDA BrickMap,Y
    AND BitTable,X
    BEQ BrickNoHit

    ; is this brick still fresh?  A set HP bit is the first hit.
    LDA BrickHP,Y
    AND BitTable,X
    BEQ BrickSecondHit

    ; first hit: clear the HP bit, keep the brick, score 1
    LDA BrickHP,Y
    EOR BitTable,X
    STA BrickHP,Y
HpHit:                      ; checkpoint: A = the new HP mask
    LDA BrickRowTable,Y
    ORA #$80                ; mark the row: a brick has been hit once
    STA BrickRowTable,Y
    LDA #1
    STA Temp
    JMP BrickBounce

    ; final hit: clear the brick map bit, remove the brick, score 2
BrickSecondHit:
    LDA BrickMap,Y
    EOR BitTable,X
    STA BrickMap,Y
BrickClear:                 ; checkpoint: A = the new brick mask
    DEC BricksLeft
    LDA #2
    STA Temp

BrickBounce:
    ; the brick's left edge, to decide whether the ball also reverses VX
    LDA BallX
    CLC
    ADC #2
    STA CurP0               ; the ball's centre
    CMP #80
    BCS BrickEdgeRight
    LDA BrickLeftEdges,X
    JMP BrickEdgeHave
BrickEdgeRight:
    LDA BrickRightEdges,X
BrickEdgeHave:
    ; A = the brick's left edge.  Compute centre - edge without a scratch
    ; byte: ~edge + centre + 1.  The score flag in Temp is untouched.
    EOR #$FF
    CLC
    ADC CurP0
    CLC
    ADC #1
    CMP #3
    BCC BrickNearEdge       ; 0..2: near the left edge
    CMP #5
    BCC BrickNoXFlip        ; 3..4: the middle of the brick
    CMP #8
    BCS BrickNoXFlip        ; 8+: outside the brick's 8 pixels
BrickNearEdge:              ; 5..7: near the right edge
    LDA BallVX
    EOR #$FF
    CLC
    ADC #1
    STA BallVX
BrickNoXFlip:
    LDA BallVY
    EOR #$FF
    CLC
    ADC #1
    STA BallVY              ; the vertical bounce
    RTS
BrickNoHit:
    RTS

; =============================================================================
; THE LEVEL — load a pattern, count it, and serve
; =============================================================================
LevelUp:
    INC Level
    LDA Level
LevelStart:                 ; checkpoint: A = the new Level
    JSR Mod3
    JMP LoadPattern

; A = Level mod 3
Mod3:
    LDA Level
Mod3Loop:
    CMP #3
    BCC Mod3Done
    SBC #3
    JMP Mod3Loop
Mod3Done:
    RTS

; A = the pattern index (0-2): copy its six masks into BrickMap, set
; BricksLeft from PatternCount, and park the ball at the paddle.
LoadPattern:
    TAX                     ; X = the pattern index
    TXA
    ASL
    TAY
    LDA PatternPtr,Y
    STA Temp
    LDA PatternPtr+1,Y
    STA CurP0
    LDY #5
PatternCopy:
    LDA (Temp),Y
    STA BrickMap,Y
    STA BrickHP,Y           ; every brick starts fresh (two hits)
    DEY
    BPL PatternCopy
    LDA PatternCount,X
    STA BricksLeft

    LDY #5
PatternClearRows:
    LDA #$00
    STA BrickRowTable,Y
    DEY
    BPL PatternClearRows

    LDA #SERVE_FRAMES
    STA ServeTimer
    LDA PaddleX
    CLC
    ADC #2
    STA BallX
    LDA #(PADDLE_Y - 4)
    STA BallY
    LDA #1
    STA BallVX
    LDA #0
    STA BallVY
    RTS

; =============================================================================
; REVERSE VX / VY — two's-complement negation
; =============================================================================
ReverseVX:
    LDA BallVX
    EOR #$FF
    CLC
    ADC #1
    STA BallVX
    RTS

ReverseVY:
    LDA BallVY
    EOR #$FF
    CLC
    ADC #1
    STA BallVY
    RTS

; =============================================================================
; LIFE LOST — one life down; at zero the game is over, otherwise re-serve
; =============================================================================
LifeLostHandler:
    DEC Lives
    LDA Lives
LifeLost:                   ; checkpoint: A = the new Lives
    BNE LifeRespawn
    LDA #1
    STA GameState           ; game over; fire restarts
    LDA #0
    STA Frame               ; the demo's game-over wait starts now
    STA BallVY
    RTS
LifeRespawn:
    LDA #SERVE_FRAMES
    STA ServeTimer
    LDA PaddleX
    CLC
    ADC #2
    STA BallX
    LDA #(PADDLE_Y - 4)
    STA BallY
    LDA #1
    STA BallVX
    LDA #0
    STA BallVY
    RTS

; =============================================================================
; BUILD TABLES — the 6-byte brick row table and the 32-byte play row table
; =============================================================================
BuildTables:
    LDX #0
BuildClearBrick:
    LDA BrickRowTable,X
    AND #$80                ; keep the row's damage bit; clear the ball bits
    STA BrickRowTable,X
    INX
    CPX #6
    BNE BuildClearBrick

    LDA #$00                ; the brick clear leaves A = the last damage byte
    LDX #0
BuildClearPlay:
    STA PlayRowTable,X
    INX
    CPX #PLAY_ROWS
    BNE BuildClearPlay

    ; the ball's 4-line row in the brick field (visible lines 15-62).
    ; The 4-line row 0..11 maps to a brick row 0..5 and a half bit 1/2.
    LDA BallY
    CMP #BRICK_TOP
    BCC BuildNoBrickBall
    CMP #(BRICK_TOP + 48)
    BCS BuildNoBrickBall
    SEC
    SBC #BRICK_TOP
    LSR
    LSR                     ; /4: 0..11
    LSR                     ; /2: the brick row 0..5; C = the half
    TAX
    LDA #$01
    BCC BuildBrickHalf0
    LDA #$02
BuildBrickHalf0:
    ORA BrickRowTable,X
    STA BrickRowTable,X
BuildNoBrickBall:

    ; the paddle's two 4-line rows
    LDA #PADDLE_Y
    SEC
    SBC #PLAY_TOP
    LSR
    LSR
    TAX
    LDA PlayRowTable,X
    ORA #$01
    STA PlayRowTable,X
    INX
    LDA PlayRowTable,X
    ORA #$01
    STA PlayRowTable,X

    ; the ball's 4-line row in the play area (visible lines 63-190)
    LDA BallY
    CMP #PLAY_TOP
    BCC BuildNoPlayBall
    CMP #(PLAY_TOP + 128)
    BCS BuildNoPlayBall
    SEC
    SBC #PLAY_TOP
    LSR
    LSR                     ; /4: 0..31
    TAX
    LDA PlayRowTable,X
    ORA #$02
    STA PlayRowTable,X
BuildNoPlayBall:
    RTS

; =============================================================================
; COARSE POSITIONING — the Lesson 26 divide-by-15 routines; no HMOVE here
; =============================================================================
; Input: A = the target + the object's bias.  Each routine starts on a fresh
; line, subtracts 15 until the carry clears, turns the negative remainder
; into the signed fine value, stores it in HMxx, and strobes RESxx.  The
; caller applies the fine offsets with one HMOVE.
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
; The divide's length grows with PaddleX.  A delay of 5 * (10 - coarse)
; cycles after RESP0 makes the total constant, so the trailing WSYNC and the
; HMOVE land on the same line for every paddle position.  DelayCount is a
; 160-byte table indexed by PaddleX; the 5-cycle DEY/BNE loop counts down.
    LDX PaddleX
    LDY DelayCount,X
    BEQ P0DelayDone
P0DelayLoop:
    DEY
    BNE P0DelayLoop
P0DelayDone:
    RTS

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
; THE DECODE TABLES — index a row byte to the two TIA bytes
; =============================================================================
; Index = bit 1 ball, bit 0 P0.  Each table is aligned so the indexed loads
; never cross a page.
    !align 7, 0
DecodeP0:
    !byte $00, $FF, $00, $FF
    !align 7, 0
DecodeBall:
    !byte $00, $00, $02, $02

; =============================================================================
; ENABLE BYTE — 0 -> ENABL 0, 1 -> ENABL 2 (the ball's enable bit)
; =============================================================================
    !align 2, 0
EnableByte:
    !byte $00, $02

; =============================================================================
; BIT TABLE — 1 << (5 - column), for columns 0..5
; =============================================================================
    !align 3, 0
BitTable:
    !byte $20, $10, $08, $04, $02, $01

; =============================================================================
; BRICK EDGES — the visible left edge of each unique column
; =============================================================================
BrickLeftEdges:
    !byte 8, 20, 32, 44, 56, 68
BrickRightEdges:
    !byte 144, 132, 120, 108, 96, 84

; =============================================================================
; THE PADDLE ANGLE TABLES — five zones, indexed by the hit offset
; =============================================================================
; The slow table is the level-0 table: -2,-1,0,+1,+2.  The fast and turbo
; tables scale the extremes so the ball crosses more of the field per trip.
PaddleAngleSlow:
    !byte $FE, $FF, $00, $01, $02
PaddleAngleFast:
    !byte $FD, $FE, $00, $02, $03
PaddleAngleTurbo:
    !byte $FC, $FD, $00, $03, $04

; =============================================================================
; THE LEVEL PATTERNS — six 6-bit masks each; PatternCount is the brick count
; =============================================================================
; Level0 is the opening full field (36 bricks).  Level1 is a diamond (24);
; Level2 is a checkerboard (18).  After level 2 the patterns repeat faster.
Level0:
    !byte $3F, $3F, $3F, $3F, $3F, $3F
Level1:
    !byte $0C, $1E, $3F, $3F, $1E, $0C
Level2:
    !byte $15, $2A, $15, $2A, $15, $2A
PatternCount:
    !byte 36, 24, 18
PatternPtr:
    !word Level0, Level1, Level2

; =============================================================================
; DELAYCOUNT — the P0 positioner's fixed-length delay, indexed by PaddleX
; =============================================================================
; value = 10 - floor((PaddleX + 3) / 15); the DEY/BNE loop costs 5 cycles per
; unit, exactly the divide loop's 5-cycle SBC/BCS step.  The table is page
; aligned so the indexed load takes the same 4 cycles for every PaddleX.
    !align 255, 0
DelayCount:
    !byte $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $09, $09, $09, $09
    !byte $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $08, $08, $08, $08, $08
    !byte $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $07, $07, $07, $07, $07
    !byte $07, $07, $07, $07, $07, $07, $07, $07, $07, $06, $06, $06, $06, $06, $06, $06
    !byte $06, $06, $06, $06, $06, $06, $06, $06, $05, $05, $05, $05, $05, $05, $05, $05
    !byte $05, $05, $05, $05, $05, $05, $05, $04, $04, $04, $04, $04, $04, $04, $04, $04
    !byte $04, $04, $04, $04, $04, $04, $03, $03, $03, $03, $03, $03, $03, $03, $03, $03
    !byte $03, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02
    !byte $02, $02, $02, $02, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
    !byte $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

; =============================================================================
; BRICKPF — the 64-entry x 3-byte brick table (192 bytes)
; =============================================================================
; Three 64-byte columns.  Entry m is the PF0/PF1/PF2 triple for the 6-bit row
; mask m; entry 0 is an empty row and entry $3F is the full 12-brick row.
    !align 255, 0
BrickPF0:
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0
    !byte $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0
    !byte $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0
    !byte $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0
    !align 63, 0
BrickPF1:
    !byte $00, $00, $00, $00, $01, $01, $01, $01
    !byte $0C, $0C, $0C, $0C, $0D, $0D, $0D, $0D
    !byte $60, $60, $60, $60, $61, $61, $61, $61
    !byte $6C, $6C, $6C, $6C, $6D, $6D, $6D, $6D
    !byte $00, $00, $00, $00, $01, $01, $01, $01
    !byte $0C, $0C, $0C, $0C, $0D, $0D, $0D, $0D
    !byte $60, $60, $60, $60, $61, $61, $61, $61
    !byte $6C, $6C, $6C, $6C, $6D, $6D, $6D, $6D
    !align 63, 0
BrickPF2:
    !byte $00, $60, $0C, $6C, $01, $61, $0D, $6D
    !byte $00, $60, $0C, $6C, $01, $61, $0D, $6D
    !byte $00, $60, $0C, $6C, $01, $61, $0D, $6D
    !byte $00, $60, $0C, $6C, $01, $61, $0D, $6D
    !byte $00, $60, $0C, $6C, $01, $61, $0D, $6D
    !byte $00, $60, $0C, $6C, $01, $61, $0D, $6D
    !byte $00, $60, $0C, $6C, $01, $61, $0D, $6D
    !byte $00, $60, $0C, $6C, $01, $61, $0D, $6D

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
