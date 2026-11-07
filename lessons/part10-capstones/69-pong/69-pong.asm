; =============================================================================
; LESSON 69: Capstone 1 — Pong — Racing the Beam
; =============================================================================
; Part 10: Capstone Projects
;
; What this program does:
;   A complete two-player Pong.  Two 8x24 paddles, a 4x8 ball, wall and
;   paddle collisions, a five-zone bounce angle, a 60-frame serve, a
;   one-digit-per-player score, and a first-to-9 game with a flashing
;   winner.  With no joystick input a deterministic auto-demo plays both
;   paddles so the captures show a serve, a rally, and the game-over state.
;
; The screen (192 visible lines):
;   picture lines 0-7     the score band.  P0 draws the left digit at
;                         TIA X=64 and P1 the right digit at X=88.  Each
;                         digit is an 8x7 glyph (font row 7 is blank) from
;                         the 10x8 ScoreFont table.
;   picture line 8        blank.
;   picture lines 9-13    the play positioners: SetCoarseP0 (P0 to 16),
;                         SetCoarseP1 (P1 to 136), SetCoarseBL (the ball to
;                         BallX), then WSYNC + HMOVE.  The three coarse
;                         strobes and one HMOVE take five lines.
;   picture lines 14-191  the play area: 178 lines = 89 rows x 2 lines.
;                         The 89-byte RowTable at $80-$D8 carries one byte
;                         per row (bit 0 = P0, bit 1 = P1, bit 2 = ball).
;                         The first row is decoded before the loop; the
;                         kernel stores the current row at the start of the
;                         row's first line and decodes the next row during
;                         the second line.
;   8 + 1 + 5 + 178 = 192.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame is scanline 259, VblankStart 0, BodyStart 37, ScoreDone 46,
;   PositionDone 51, OverscanStart 229.
;
; Why the row table (the cycle-49 lesson):
;   A one-line kernel that tests three object ranges in turn cannot store
;   GRP0 before P0's pixel time when P0 sits at X=16.  The preflight's
;   direct kernel wrote GRP0 at cycle 49; P0's leftmost pixel is at cycle
;   (16 + 68) / 3 = 28, so the left paddle rendered the previous row's byte
;   and was invisible.  The row table replaces the range tests with three
;   table loads, and the two-line lookahead puts the stores at the start of
;   the row's first line: GRP0 at cycle 12, ENABL at 18, GRP1 at 24.  P0 is
;   fixed at X=16, so its deadline is (16 + 68) / 3 = 28 cycles; the ball
;   can be displayed as far left as X=4 (the score check is BallX < 6), so
;   its deadline is (4 + 68) / 3 = 24.0 cycles.  Both stores are earlier.
;
; The kernel ledger (cycles; one row = two scanlines, 152 cycles):
;   line 1: the previous pair's loop tail INX 2, CPX #90 2, BNE 3 = 7;
;           LDA CurP0 3, STA GRP0 3, LDA CurBall 3, STA ENABL 3,
;           LDA CurP1 3, STA GRP1 3, STA WSYNC 3             = 28
;   line 2: CPX #89 2, BEQ 2; LDA RowTable,X 4, TAY 2,
;           LDA DecodeP0,Y 4, STA CurP0 3, LDA DecodeP1,Y 4,
;           STA CurP1 3, LDA DecodeBall,Y 4, STA CurBall 3,
;           STA WSYNC 3                                     = 34
;   the pair costs 62 cycles of the 152 available, leaving 90 cycles of
;   margin.  The stores land at 12 / 18 / 24 in steady state (8 / 14 / 20
;   on the first row).  P0's deadline at X=16 is cycle 28 and the ball's
;   at X=4 is cycle 24.0; the stores are earlier.
;   The 89th row skips the decode (CPX #89 / BEQ), so its second line
;   costs 8 cycles; the last WSYNC releases the CPU at scanline 229.
;
; RAM map (the exact map; +clean_start zeroes every byte):
;   $80-$D8  RowTable     89 bytes, one byte per two-line row
;   $D9      LeftScore    0-9
;   $DA      RightScore   0-9
;   $DB      P0Y          P0's top row, 8-148
;   $DC      P1Y          P1's top row, 8-148
;   $DD      BallX        4-152 (the ball's left edge; the score check is <6)
;   $DE      BallY        8-164 (the ball's top row)
;   $DF      BallVX       signed: $FE (-2) or $02 (+2)
;   $E0      BallVY       signed: $FE..$02 (-2..+2)
;   $E1      Frame        the frame counter, 8 bits
;   $E2      ServeTimer   60..1 while the ball is parked, 0 in play
;   $E3      GameState    0 = play, 1 = game over
;   $E4      ScoreFlash   0 = the left digit won, 1 = the right digit won
;   $E5      Temp         scratch
;   $E6      CurP0        the current/next row's GRP0 byte (also the score
;                         font base before the score band)
;   $E7      CurP1        the current/next row's GRP1 byte (also the score
;                         font base before the score band)
;   $E8      CurBall      the current/next row's ENABL byte (also the score
;                         flash flag before the score band)
;   $E9      P0Row        P0Y / 2
;   $EA      P1Row        P1Y / 2
;   $EB      BallRow      BallY / 2
;   $EC      P0RowEnd     P0Row + 12
;   $ED      P1RowEnd     P1Row + 12
;   $EE      BallRowEnd   BallRow + 4
;   $EF      PrevFire     bit 0 = fire (0 = released, 1 = pressed), bit 1 unused
;   $F0      AutoTimer    consecutive frames with no direction held
;   $F1-$FF  stack
;
; The game:
;   SWCHA bits 4/5 are P0 up/down and bits 0/1 are P1 up/down (active
;   low; include/vcs.asm is the authority).  A direction moves a paddle 2
;   px/frame, clamped to 8..148.  Fire (INPT4) starts a serve early.
;   The ball moves 2 px/frame horizontally; its vertical speed comes from
;   AngleTable = (-2,-1,0,+1,+2) indexed by (BallY - PaddleY) / 5, clamped
;   to 0..4.  It bounces at Y=8 and Y=164.  CXP0FB/CXP1FB bit 6 is read in
;   VBLANK (the previous frame's latch) and CXCLR clears it.  A hit
;   reverses BallVX and moves the ball out of the paddle.
;   BallX < 6 scores for the right; BallX > 150 scores for the left; the
;   score caps at 9.  ServeTimer=60, the ball parks at X=80, Y=90.  The
;   first serve is fixed left; after a point it serves toward the player
;   who lost.  The first score to reach 9 sets GameState=1; the winner's
;   digit flashes with Frame & $10.  Fire or SELECT resets the scores and
;   serves.
;
; The auto-demo:
;   After 120 frames with no direction held, both paddles track the ball.
;   The right paddle moves up to 2 px/frame; the left moves 1 px/frame
;   toward a target 40 px below the ball's target (the tracking lag taken
;   to its limit), so its 24-pixel paddle cannot touch the 8-pixel ball
;   after the opening rally.  The opening rally exercises the paddle and
;   wall collisions: P0 hits at frame 89, P1 at 145, P0 at 200, P1 at 255;
;   after the fourth the left drifts away and the first point lands at 319.
;   The rest of the demo scores for the right.  The
;   auto-demo also starts a waiting serve early after two seconds, so the
;   ninth point lands at about frame 631 (10.5 s) and the 12 s capture
;   shows the game-over state.  Any up/down direction takes over and
;   resets AutoTimer to zero.
;
; Controls:
;   Left joystick: up/down moves P0.  Right joystick: up/down moves P1.
;   Fire starts a serve early; fire or SELECT restarts after game over.
;
; Checkpoints (the A/X/Y/SP values are the state at the label):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   ScoreDone (46), PositionDone (51), OverscanStart (229),
;   P0YRead (A=P0Y), P1YRead (A=P1Y), BallXRead (A=BallX),
;   BallYRead (A=BallY), ScoreLeft (A=the new left score),
;   ScoreRight (A=the new right score), PaddleHit (A=0 for P0, 1 for P1),
;   WallBounce (A=the clamped Y, 8 or 164), GameStateRead (A=GameState),
;   RowTableWrite (A=the byte at RowTable+0), ServeStart (A=the serve VX).
;
; Build: acme -f plain -o build/lesson69.bin \
;        lessons/part10-capstones/69-pong/69-pong.asm
; Run:   stella build/lesson69.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44       ; 1 + 43 x 64 = 2753 cycles = 36.2 lines; the
                          ; timer + wait_timer's WSYNC make the measured 37-line VBLANK
OVERSCAN_TIMER = 36       ; 1 + 35 x 64 = 2241 cycles = 29.5 lines; the
                          ; timer + WSYNC make the measured 30-line overscan

ROW_COUNT      = 89       ; 89 rows x 2 lines = 178 play lines
PADDLE_ROWS    = 12       ; 12 rows x 2 lines = 24 pixels of paddle
BALL_ROWS      = 4        ; 4 rows x 2 lines = 8 pixels of ball

P0_X           = 16       ; P0's fixed horizontal position
P1_X           = 136      ; P1's fixed horizontal position
PADDLE_MIN     = 8        ; the paddle's top edge limits
PADDLE_MAX     = 148
BALL_TOP       = 8        ; the ball's vertical bounce limits
BALL_BOTTOM    = 164
BALL_LEFT      = 6        ; BallX < 6: the right player scores
BALL_RIGHT     = 150      ; BallX > 150: the left player scores
SERVE_FRAMES   = 60
WIN_SCORE      = 9

PLAY_BIAS      = 3        ; the Lesson 26 player positioning bias
BALL_BIAS      = 4        ; the ball's output delay is one clock shorter

C_P0           = $C8      ; P0 and the left digit: green
C_P1           = $84      ; P1 and the right digit: blue
C_BALL         = $0E      ; the ball: white
C_BG           = $00      ; black

AUTO_START     = 120      ; frames with no input before the auto-demo

; =============================================================================
; RAM ALLOCATION ($80-$F0; the stack is $F1-$FF)
; =============================================================================
RowTable    = $80         ; 89 bytes ($80-$D8)
LeftScore   = $D9
RightScore  = $DA
P0Y         = $DB
P1Y         = $DC
BallX       = $DD
BallY       = $DE
BallVX      = $DF
BallVY      = $E0
Frame       = $E1
ServeTimer  = $E2
GameState   = $E3
ScoreFlash  = $E4
Temp        = $E5
CurP0       = $E6
CurP1       = $E7
CurBall     = $E8
P0Row       = $E9
P1Row       = $EA
BallRow     = $EB
P0RowEnd    = $EC
P1RowEnd    = $ED
BallRowEnd  = $EE
PrevFire    = $EF
AutoTimer   = $F0

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
    STA SWACNT              ; port A is an input port (both joysticks)

    LDA #C_P0
    STA COLUP0
    LDA #C_P1
    STA COLUP1
    LDA #C_BALL
    STA COLUPF
    LDA #C_BG
    STA COLUBK
    LDA #$20
    STA CTRLPF              ; the ball is 4 pixels wide (bits 4-5 = 10)
    LDA #$00
    STA NUSIZ0              ; one 8-pixel copy of each player
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

    LDA #90
    STA P0Y                 ; both paddles start centred
    LDA #90
    STA P1Y
    LDA #80
    STA BallX               ; the ball starts parked at the centre
    LDA #90
    STA BallY
    LDA #$FE
    STA BallVX              ; the first serve travels toward the left
    LDA #$00
    STA BallVY
    LDA #SERVE_FRAMES
    STA ServeTimer
    LDA #$00
    STA GameState
    STA ScoreFlash
    STA LeftScore
    STA RightScore
    STA Frame
    STA PrevFire
    STA AutoTimer
    STA CXCLR

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

; -----------------------------------------------------------------------------
; 1. READ THE INPUT, THE FIRE EDGE, AND THE AUTO-DEMO
; -----------------------------------------------------------------------------
    JSR ReadInput

; -----------------------------------------------------------------------------
; 2. THE SERVE TIMER (the ball is parked until it reaches zero)
; -----------------------------------------------------------------------------
    JSR ServeStep

; -----------------------------------------------------------------------------
; 3. THE BALL: COLLISION LATCHES, MOTION, WALLS, AND SCORING
; -----------------------------------------------------------------------------
    JSR BallStep

; -----------------------------------------------------------------------------
; 4. BUILD THE 89-BYTE ROW TABLE
; -----------------------------------------------------------------------------
    JSR BuildRowTable

; -----------------------------------------------------------------------------
; 5. THE SCORE BAND'S FONT BASES AND FLASH FLAG
; -----------------------------------------------------------------------------
; The score band uses CurP0/CurP1 as the left/right glyph bases (digit * 8)
; and CurBall as the flash flag: $FF draws both digits, 0 blanks the left,
; 1 blanks the right.  The row-0 decode at ScoreDone overwrites all three
; before the play kernel.
    LDA LeftScore
    ASL
    ASL
    ASL
    STA CurP0
    LDA RightScore
    ASL
    ASL
    ASL
    STA CurP1
    LDA #$FF
    STA CurBall
    LDA GameState
    BEQ ScoreNoFlash
    LDA Frame
    AND #$10
    BEQ ScoreNoFlash
    LDA ScoreFlash
    STA CurBall
ScoreNoFlash:

; -----------------------------------------------------------------------------
; 6. POSITION P0 AT 64 AND P1 AT 88 FOR THE SCORE BAND (one HMOVE)
; -----------------------------------------------------------------------------
    LDA #(64 + PLAY_BIAS)
    JSR SetCoarseP0
    LDA #(88 + PLAY_BIAS)
    JSR SetCoarseP1
    STA WSYNC
    STA HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE 0-7 — THE SCORE BAND (8 lines)
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, picture line 0
    LDX #0
ScoreLine:
    TXA
    CLC
    ADC CurP0               ; row + LeftScore * 8
    TAY
    LDA ScoreFont,Y
    STA GRP0                ; the left digit (green)
    LDA CurBall
    BNE ScoreLeftDone
    LDA #$00
    STA GRP0                ; the flash-off frame blanks the left digit
ScoreLeftDone:
    TXA
    CLC
    ADC CurP1               ; row + RightScore * 8
    TAY
    LDA ScoreFont,Y
    STA GRP1                ; the right digit (blue)
    LDA CurBall
    CMP #$01
    BNE ScoreRightDone
    LDA #$00
    STA GRP1                ; the flash-off frame blanks the right digit
ScoreRightDone:
    STA WSYNC
    INX
    CPX #8
    BNE ScoreLine

; =============================================================================
; VISIBLE 8 — THE BLANK LINE
; =============================================================================
; The row-0 decode belongs here: the score band has finished with CurP0/
; CurP1/CurBall, and the kernel needs row 0's object bytes in them.  The
; decode also pushes the line's WSYNC past the start of the visible area;
; a WSYNC written during the leading HBLANK does not wait for the next line.
    LDX #1                  ; the kernel's next-row index
    LDA RowTable
    TAY
    LDA DecodeP0,Y
    STA CurP0
    LDA DecodeP1,Y
    STA CurP1
    LDA DecodeBall,Y
    STA CurBall
    STA WSYNC

; =============================================================================
; VISIBLE 9-13 — THE PLAY POSITIONERS (five lines)
; =============================================================================
    LDA #(P0_X + PLAY_BIAS)
    JSR SetCoarseP0Play     ; P0's coarse position; ScoreDone is on line 46
    LDA #(P1_X + PLAY_BIAS)
    JSR SetCoarseP1         ; P1's coarse position and HMP1
    LDA BallX
    CLC
    ADC #BALL_BIAS
    JSR SetCoarseBL         ; the ball's coarse position and HMBL
    STA WSYNC
    STA HMOVE               ; one HMOVE applies all three fine offsets

; =============================================================================
; VISIBLE 14-191 — THE PLAY AREA: 89 ROWS x 2 LINES
; =============================================================================
PositionDone:               ; checkpoint: scanline 51, picture line 14
    LDA CurP0
    STA GRP0
    LDA CurBall
    STA ENABL
    LDA CurP1
    STA GRP1
    STA WSYNC               ; line 1 of the pair displays the current row

    CPX #ROW_COUNT
    BEQ KernelLastRow       ; row 88 has no next row to decode
    LDA RowTable,X          ; decode the next row during the second line
    TAY
    LDA DecodeP0,Y
    STA CurP0
    LDA DecodeP1,Y
    STA CurP1
    LDA DecodeBall,Y
    STA CurBall
KernelLastRow:
    STA WSYNC               ; line 2 of the pair displays the same row

    INX
    CPX #(ROW_COUNT + 1)
    BNE PositionDone
    ; 89 rows x 2 lines = 178; the last WSYNC releases at scanline 229.

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
; READ INPUT — the paddles, the fire edge, and the auto-demo
; =============================================================================
; SWCHA is active low.  P0's up/down are bits 4/5 and P1's are bits 0/1
; (include/vcs.asm).  A held direction resets AutoTimer and hands control to
; the joystick.  With no direction the auto-demo takes over at 120 frames.
ReadInput:

; The four observation points below are the values the game logic is about
; to use; they let the debugger report the paddle and ball state once a frame.
    LDA P0Y
P0YRead:                    ; checkpoint: A = P0Y
    LDA P1Y
P1YRead:                    ; checkpoint: A = P1Y
    LDA BallX
BallXRead:                  ; checkpoint: A = BallX
    LDA BallY
BallYRead:                  ; checkpoint: A = BallY

; --- the fire edge (bit 7 of INPT4 is 0 while pressed) ---
    LDA INPT4
    AND #$80
    BEQ FireIsDown
    LDA #$00
    JMP FireState
FireIsDown:
    LDA #$01
FireState:
    STA Temp                ; Temp = 1 while fire is held
    LDX #0
    LDA Temp
    BEQ FireEdgeDone
    LDA PrevFire
    AND #$01
    BNE FireEdgeDone
    LDX #1                  ; a new press
FireEdgeDone:
    LDA PrevFire
    AND #$FE
    ORA Temp
    STA PrevFire            ; remember this frame's fire state

    LDA GameState
GameStateRead:              ; checkpoint: A = GameState
    BNE GameOverInput

; --- play: fire starts a waiting serve early ---
    CPX #1
    BNE AutoCheck
    LDA ServeTimer
    BEQ AutoCheck
    LDA #$01
    STA ServeTimer          ; the next ServeStep decrements to zero

; --- the auto-demo starts a waiting serve early after two seconds ---
AutoCheck:
    LDA AutoTimer
    CMP #AUTO_START
    BCC PlayInput
    LDA ServeTimer
    BEQ PlayInput
    LDA #$01
    STA ServeTimer

; --- the paddles: joystick or auto-demo ---
PlayInput:
    LDA SWCHA
    AND #$33                ; P0 up/down (4/5) and P1 up/down (0/1)
    CMP #$33
    BEQ NoDirection
    LDA #$00
    STA AutoTimer           ; a direction takes over
    JSR ManualMoves
    RTS
NoDirection:
    INC AutoTimer
    BNE AutoCounted
    DEC AutoTimer           ; saturate at 255; the auto-demo stays on
AutoCounted:
    LDA AutoTimer
    CMP #AUTO_START
    BCC InputDone
    JSR AutoMoves
InputDone:
    RTS

; --- game over: fire or SELECT restarts ---
GameOverInput:
    CPX #1
    BEQ RestartGame
    LDA SWCHB
    AND #$02                ; SELECT is active low
    BNE InputDone
RestartGame:
    LDA #$00
    STA GameState
    STA LeftScore
    STA RightScore
    STA ScoreFlash
    STA AutoTimer
    LDA #90
    STA P0Y
    STA P1Y
    LDA #80
    STA BallX
    LDA #90
    STA BallY
    LDA #$00
    STA BallVY
    LDA #$FE
    STA BallVX
    LDA #SERVE_FRAMES
    STA ServeTimer
    LDA #$00
    STA CXCLR
    RTS

; =============================================================================
; MANUAL MOVES — two pixels per frame, range-clamped to 8..148
; =============================================================================
; The clamp is a range test, not an equality test.  The auto-demo moves a
; paddle one pixel per frame, so P0Y/P1Y can be odd: from 9 an equality test
; would subtract to 7, 5, 3, 1, $FF, and the row table would then write past
; $D8.  The range test clamps the result in one step.
ManualMoves:
    LDA SWCHA
    AND #$10                ; P0 up
    BNE ManualP0Down
    LDA P0Y
    SEC
    SBC #2
    CMP #PADDLE_MIN
    BCS ManualP0UpStore
    LDA #PADDLE_MIN
ManualP0UpStore:
    STA P0Y
ManualP0Down:
    LDA SWCHA
    AND #$20                ; P0 down
    BNE ManualP1Up
    LDA P0Y
    CLC
    ADC #2
    CMP #(PADDLE_MAX + 1)
    BCC ManualP0DownStore
    LDA #PADDLE_MAX
ManualP0DownStore:
    STA P0Y
ManualP1Up:
    LDA SWCHA
    AND #$01                ; P1 up
    BNE ManualP1Down
    LDA P1Y
    SEC
    SBC #2
    CMP #PADDLE_MIN
    BCS ManualP1UpStore
    LDA #PADDLE_MIN
ManualP1UpStore:
    STA P1Y
ManualP1Down:
    LDA SWCHA
    AND #$02                ; P1 down
    BNE ManualDone
    LDA P1Y
    CLC
    ADC #2
    CMP #(PADDLE_MAX + 1)
    BCC ManualP1DownStore
    LDA #PADDLE_MAX
ManualP1DownStore:
    STA P1Y
ManualDone:
    RTS

; =============================================================================
; AUTO MOVES — both paddles track the ball; the left lags
; =============================================================================
; The right paddle's target centres its 24-pixel paddle on the 8-pixel ball:
; target = BallY - 8, clamped to 8..148.  The right moves up to two pixels
; per frame.  The left moves one pixel per frame toward a target 40 pixels
; below the ball's target: the tracking lag taken to its limit, so the left
; paddle cannot touch the ball after the opening rally.  The right returns the ball
; and the left misses.
AutoMoves:
    LDA BallY
    SEC
    SBC #8
    BCS AutoRTarget
    LDA #PADDLE_MIN
AutoRTarget:
    CMP #(PADDLE_MAX + 1)
    BCC AutoRTargetOK
    LDA #PADDLE_MAX
AutoRTargetOK:
    STA Temp

    LDA P1Y
    CMP Temp
    BEQ AutoRightDone
    BCC AutoRightDown
    LDA P1Y
    SEC
    SBC #2
    CMP #PADDLE_MIN
    BCS AutoRightStore
    LDA #PADDLE_MIN
    JMP AutoRightStore
AutoRightDown:
    LDA P1Y
    CLC
    ADC #2
    CMP #(PADDLE_MAX + 1)
    BCC AutoRightStore
    LDA #PADDLE_MAX
AutoRightStore:
    STA P1Y
AutoRightDone:

    LDA Temp
    CLC
    ADC #40                 ; the left trails the ball by 40 pixels: far
    BCS AutoLagCap          ; enough that its 24-pixel paddle cannot touch
    CMP #(PADDLE_MAX + 1)   ; the 8-pixel ball
    BCC AutoLagOK
AutoLagCap:
    LDA #PADDLE_MAX
AutoLagOK:
    STA Temp

    LDA P0Y
    CMP Temp
    BEQ AutoLeftDone
    BCC AutoLeftDown
    CMP #PADDLE_MIN
    BEQ AutoLeftDone
    DEC P0Y
    JMP AutoLeftDone
AutoLeftDown:
    CMP #PADDLE_MAX
    BEQ AutoLeftDone
    INC P0Y
AutoLeftDone:
    RTS

; =============================================================================
; SERVE STEP — count the parked frames; at zero the ball starts moving
; =============================================================================
ServeStep:
    LDA GameState
    BNE ServeStepDone
    LDA ServeTimer
    BEQ ServeStepDone
    DEC ServeTimer
    BNE ServeStepDone
    LDA BallVX
ServeStart:                 ; checkpoint: A = the serve direction
    NOP
ServeStepDone:
    RTS

; =============================================================================
; BALL STEP — the collision latches, the motion, the walls, and the score
; =============================================================================
BallStep:
    LDA GameState
    BEQ BallCheckTimer
    JMP BallFrozen
BallCheckTimer:
    LDA ServeTimer
    BEQ BallStepRun
    JMP BallFrozen
BallStepRun:

; --- the paddle collision latches (CXP0FB/CXP1FB bit 6) ---
    LDA CXP0FB
    AND #$40
    BEQ BallCheckP1
    LDA BallVX
    BMI BallHitP0           ; moving left, toward P0
    JMP BallNoHit
BallCheckP1:
    LDA CXP1FB
    AND #$40
    BEQ BallNoHit
    LDA BallVX
    BMI BallNoHit           ; moving left, away from P1
    LDA #$01
    JMP BallHitCommon
BallHitP0:
    LDA #$00
BallHitCommon:
PaddleHit:                  ; checkpoint: A = 0 for P0, 1 for P1
    STA Temp                ; the side
    LDA Temp
    BNE BallGetP1Y
    LDA P0Y
    JMP BallHavePaddleY
BallGetP1Y:
    LDA P1Y
BallHavePaddleY:
    STA CurBall             ; scratch: the paddle's top row
    LDA BallY
    SEC
    SBC CurBall
    BCS BallOffset
    LDA #0
BallOffset:
    CMP #21
    BCC BallOffsetOK
    LDA #20
BallOffsetOK:
    LDX #0
BallDiv5:
    CMP #5
    BCC BallDiv5Done
    SBC #5
    INX
    BNE BallDiv5
BallDiv5Done:
    LDA AngleTable,X
    STA BallVY

    LDA Temp
    BNE BallBounceP1
    LDA #2
    STA BallVX              ; P0 sends the ball right
    LDA #(P0_X + 8)
    STA BallX               ; just right of the paddle
    JMP BallClearMove
BallBounceP1:
    LDA #$FE
    STA BallVX              ; P1 sends the ball left
    LDA #(P1_X - 4)
    STA BallX               ; just left of the paddle
    JMP BallClearMove

; --- no hit: clear the latches and move ---
BallNoHit:
BallClearMove:
    LDA #$00
    STA CXCLR               ; the latches are read; start the next frame clean

; --- score check before the move, so the ball cannot wrap at the edges ---
    LDA BallX
    CMP #BALL_LEFT
    BCC BallRightPoint
    CMP #(BALL_RIGHT + 1)
    BCS BallLeftPoint

; --- horizontal and vertical motion ---
    LDA BallX
    CLC
    ADC BallVX
    STA BallX
    LDA BallY
    CLC
    ADC BallVY
    STA BallY

; --- the walls at Y=8 and Y=164 ---
    CMP #BALL_TOP
    BCS BallCheckBottom
    LDA #BALL_TOP
    STA BallY
    JMP BallWallBounce
BallCheckBottom:
    CMP #(BALL_BOTTOM + 1)
    BCC BallStepDone
    LDA #BALL_BOTTOM
    STA BallY
BallWallBounce:
WallBounce:                 ; checkpoint: A = the clamped Y (8 or 164)
    LDA BallVY
    EOR #$FF
    CLC
    ADC #1
    STA BallVY              ; two's-complement negation
BallStepDone:
    RTS

; The game-over and serve-wait paths freeze the ball; clear the latches and
; leave the score check untouched.
BallFrozen:
    LDA #$00
    STA CXCLR
    RTS

; --- the right player scored: BallX < 6 ---
BallRightPoint:
    INC RightScore
    LDA RightScore
    CMP #10
    BCC BallRightCap
    LDA #9
    STA RightScore
BallRightCap:
ScoreRight:                 ; checkpoint: A = the new right score
    CMP #WIN_SCORE
    BCS BallRightWon
    LDA #$FE
    STA BallVX              ; serve toward the loser (the left)
    JMP BallServeSetup
BallRightWon:
    LDA #$01
    STA GameState
    STA ScoreFlash          ; the right digit won
    LDA #$00
    STA ServeTimer
    RTS

; --- the left player scored: BallX > 150 ---
BallLeftPoint:
    INC LeftScore
    LDA LeftScore
    CMP #10
    BCC BallLeftCap
    LDA #9
    STA LeftScore
BallLeftCap:
ScoreLeft:                  ; checkpoint: A = the new left score
    CMP #WIN_SCORE
    BCS BallLeftWon
    LDA #2
    STA BallVX              ; serve toward the loser (the right)
    JMP BallServeSetup
BallLeftWon:
    LDA #$01
    STA GameState
    LDA #$00
    STA ScoreFlash          ; the left digit won
    LDA #$00
    STA ServeTimer
    RTS

; --- park the ball for the next serve ---
BallServeSetup:
    LDA #SERVE_FRAMES
    STA ServeTimer
    LDA #80
    STA BallX
    LDA #90
    STA BallY
    LDA #$00
    STA BallVY
    STA ScoreFlash
    RTS

; =============================================================================
; BUILD ROW TABLE — clear 89 bytes, then OR the three object ranges
; =============================================================================
BuildRowTable:
    LDA P0Y
    JSR ClampPaddle
    STA P0Y
    LDA P1Y
    JSR ClampPaddle
    STA P1Y
    LDX #0
    LDA #$00
RowClear:
    STA RowTable,X
    INX
    CPX #ROW_COUNT
    BNE RowClear

    LDA P0Y
    LSR                     ; P0Row = P0Y / 2
    STA P0Row
    CLC
    ADC #PADDLE_ROWS
    STA P0RowEnd
    LDX P0Row
RowP0:
    LDA RowTable,X
    ORA #$01
    STA RowTable,X
    INX
    CPX P0RowEnd
    BNE RowP0

    LDA P1Y
    LSR
    STA P1Row
    CLC
    ADC #PADDLE_ROWS
    STA P1RowEnd
    LDX P1Row
RowP1:
    LDA RowTable,X
    ORA #$02
    STA RowTable,X
    INX
    CPX P1RowEnd
    BNE RowP1

    LDA BallY
    LSR
    STA BallRow
    CLC
    ADC #BALL_ROWS
    STA BallRowEnd
    LDX BallRow
RowBall:
    LDA RowTable,X
    ORA #$04
    STA RowTable,X
    INX
    CPX BallRowEnd
    BNE RowBall

    LDA RowTable
RowTableWrite:              ; checkpoint: A = the byte at RowTable+0
    RTS

; =============================================================================
; CLAMP PADDLE — A = 8..148 (the row-table build's safety net)
; =============================================================================
; The moves already clamp, but a corrupted P0Y/P1Y must never index past
; RowTable+$D8.  The build clamps both bytes before it computes the ranges.
ClampPaddle:
    CMP #PADDLE_MIN
    BCS ClampHigh
    LDA #PADDLE_MIN
    RTS
ClampHigh:
    CMP #(PADDLE_MAX + 1)
    BCC ClampDone
    LDA #PADDLE_MAX
ClampDone:
    RTS

; =============================================================================
; COARSE POSITIONING — the Lesson 26 divide-by-15 routines; no HMOVE here
; =============================================================================
; Input: A = the target + the object's bias.  Each routine starts on a fresh
; line, subtracts 15 until the carry clears, turns the negative remainder
; into the signed fine value, stores it in HMxx, and strobes RESxx.  The
; caller applies the three fine offsets with one HMOVE.
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

; The play positioner's first routine is SetCoarseP0 with the ScoreDone
; checkpoint on its first line (scanline 46).  The score-band positioner
; in VBLANK uses SetCoarseP0 above, so the checkpoint has exactly one hit
; per frame.
SetCoarseP0Play:
    STA WSYNC
ScoreDone:                 ; checkpoint: scanline 46, the first play positioner
    SEC
DivP0Play:
    SBC #15
    BCS DivP0Play
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    RTS

SetCoarseP1:
    STA WSYNC
    SEC
DivP1:
    SBC #15
    BCS DivP1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
    STA RESP1
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
; THE DECODE TABLES — index a row byte to the three TIA bytes
; =============================================================================
; Index = bit 2 ball, bit 1 P1, bit 0 P0.  Each table is aligned to an
; 8-byte boundary so the kernel's indexed loads never cross a page.
    !align 7, 0
DecodeP0:
    !byte $00, $FF, $00, $FF, $00, $FF, $00, $FF
    !align 7, 0
DecodeP1:
    !byte $00, $00, $FF, $FF, $00, $00, $FF, $FF
    !align 7, 0
DecodeBall:
    !byte $00, $00, $00, $00, $02, $02, $02, $02

; =============================================================================
; THE ANGLE TABLE — the five vertical speeds
; =============================================================================
AngleTable:
    !byte $FE, $FF, $00, $01, $02   ; -2, -1, 0, +1, +2

; =============================================================================
; THE SCORE FONT — ten 8x8 glyphs, top-down; row 7 is blank
; =============================================================================
; The left digit is drawn by P0 at X=64 and the right by P1 at X=88.  Each
; row's byte is ScoreFont + digit * 8 + row; the last row is $00, so the
; lit glyph is seven scanlines tall.
ScoreFont:
    !byte %00111100, %01100110, %01100110, %01100110   ; 0
    !byte %01100110, %01100110, %00111100, %00000000
    !byte %00011000, %00111000, %00011000, %00011000   ; 1
    !byte %00011000, %00011000, %01111110, %00000000
    !byte %00111100, %01100110, %00000110, %00001100   ; 2
    !byte %00110000, %01100000, %01111110, %00000000
    !byte %00111100, %01100110, %00000110, %00011100   ; 3
    !byte %00000110, %01100110, %00111100, %00000000
    !byte %00001100, %00011100, %00111100, %01101100   ; 4
    !byte %01111110, %00001100, %00001100, %00000000
    !byte %01111110, %01100000, %01111100, %00000110   ; 5
    !byte %00000110, %01100110, %00111100, %00000000
    !byte %00011100, %00110000, %01100000, %01111100   ; 6
    !byte %01100110, %01100110, %00111100, %00000000
    !byte %01111110, %00000110, %00001100, %00011000   ; 7
    !byte %00110000, %00110000, %00110000, %00000000
    !byte %00111100, %01100110, %01100110, %00111100   ; 8
    !byte %01100110, %01100110, %00111100, %00000000
    !byte %00111100, %01100110, %01100110, %00111110   ; 9
    !byte %00000110, %00001100, %00111000, %00000000

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
