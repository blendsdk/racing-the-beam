; =============================================================================
; LESSON 62: Reverse Engineering a Classic Game
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "Wall Buster": a 4,096-byte course-written Breakout-style game, small
;   enough to annotate in full and complete enough to take apart with the
;   Stella debugger.  It is NOT a historical classic: every byte is original,
;   so the lesson can map every routine, table, and RAM byte without copyright
;   risk.  The reverse-engineering method transfers to any 4K ROM.
;
; The game:
;   A paddle (player 0) at the bottom, a two-pixel ball (the ball sprite), a
;   6 x 4 brick wall (the playfield), a two-digit score (player 1), a life
;   counter (the vertical bar under the score), and a game-over/restart state.
;   The joystick moves the paddle; with no joystick input the paddle tracks
;   the ball, so the ROM demonstrates itself.  A brick disappears when the
;   ball's leading edge reaches its two playfield chunks; the score goes up by
;   one; a ball that reaches the bottom costs a life; at zero lives the red
;   game-over field appears and fire starts a new game.
;
; The wall (playfield):
;   20 chunks, 4 pixels each, reflected into the right half.  Six unique brick
;   columns, each two chunks (8 pixels) wide, with one chunk of gap:
;     brick 0  chunks 1-2    PF0 bits 5-6   $60
;     brick 1  chunks 4-5    PF1 bits 7-6   $C0
;     brick 2  chunks 7-8    PF1 bits 4-3   $18
;     brick 3  chunks 10-11  PF1 bits 1-0   $03
;     brick 4  chunks 13-14  PF2 bits 2-1   $06
;     brick 5  chunks 16-17  PF2 bits 5-4   $30
;   Each of the four rows is one 6-bit mask (Brick0..Brick3).  VBLANK rebuilds
;   the four rows' PF bytes from the masks every frame; a hit clears one bit.
;   The reflected playfield draws each brick twice, so the wall shows twelve
;   columns but the collision table is the six-column wall.  Clearing a bit
;   removes both mirror images, which is the classic playfield behaviour.
;
; The score (player 1):
;   ScoreGlyphs is a 25 x 16 table: one 16-row column per score value 0..24.
;   Rows 0-6 are the tens digit, rows 7-8 are blank, rows 9-15 are the ones
;   digit.  ScorePtr points at the selected entry; the kernel reads one row per
;   scanline.  The two digits are stacked vertically at X=76.  Rows 17-22 are
;   the life bar: two rows per remaining life (six rows for three lives).
;
; The overlay (SELECT):
;   A TV can only show the 192 visible lines; the 3 VSYNC, 37 VBLANK, and 30
;   overscan lines are blanked.  The overlay therefore draws a frame map in
;   the visible window: rows 0-2 white (VSYNC), rows 3-39 blue (VBLANK),
;   rows 40-161 green (the kernel, compressed into 122 lines), rows 162-191
;   red (overscan).  On every row the playfield draws a four-pixel dash whose
;   position is the row number divided by eight, so the diagonal is the
;   kernel's row loop: row Y lights chunk Y >> 3 (clamped to the right edge).
;   The four colours and the diagonal are the evidence that the frame has four
;   phases and that the kernel walks Y from 0 to 191.  The map is a visual
;   projection, not a photograph of the blanked regions: their true line
;   counts (3, 37, 30) are kept and the 192-line kernel is compressed into the
;   122 lines that remain.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5, OverscanStart 229/6.
;   One HMOVE per frame, in VBLANK, after three coarse positioners.
;
; Kernel cycle ledger (the line is 76 cycles; the measured frame stays 262):
;   DrawBallLine stores the ball enable 21 cycles after it is entered on the
;     ball-off path (TYA 2, CLC 2, ADC 2, SEC 2, SBC 3, CMP 2, BCS 3,
;     LDA 2, STA 3), or 23 on the ball-on path (BCS 2, LDA 2, STA 3, JMP 3).
;     STA WSYNC adds three more, so the WSYNC write is at 24 or 26.
;   The numbers below are measured with a Stella breakpoint at BallLineSync,
;     not derived; each is the CPU cycle at which the STA WSYNC instruction
;     starts; the write completes three cycles later:
;       first visible line  54      score rows (1-15)      48
;       separator 16        44      life bar 17 (first)   64
;       life bar 18-21      67      life bar 22 (ball)     69
;       blank 23-31         46/40
;       first brick 32      65      brick body             43
;       brick gap 63        65      play 64 (first)        48
;       play 65-175         40      paddle 176 (first)     46
;       paddle 177-183      40      bottom 184 (first)     50
;       bottom 185-190      42
;   The worst line is life-bar row 22 with the ball on: the STA WSYNC starts
;     at 69 and the write completes at 72, four cycles before the line ends
;     (seven from the instruction start).  Without the ball the row is 67.
;     The ball's top is 23, but the enable for row 23 is written during row
;     22, so on the right half the ball is also drawn on row 22.  A brick
;     line or gap with the ball on is 67.  The first visible line's 54
;     includes the one-time zone entry.  Every line fits.
;   The last visible row is DrawLastLine: STA WSYNC + RTS, so the return
;     address (OverscanStart) is at scanline 229 cycle 6 (play), 7 (game
;     over), or 9 (frame map).
;
; Checkpoints (the state log's scanline/cycle and the A or Y register):
;   StartFrame    the first VSYNC instruction
;   VblankStart   the first VBLANK instruction
;   BodyStart     the first visible line
;   OverscanStart the first overscan instruction
;   KernelRow     Y = the visible row, 0..190 (inside DrawBallLine)
;   KernelRowLast Y = 191, the final visible row (DrawLastLine)
;   BallMove      A = the new BallX
;   HitBrick      A = the brick index 0..23
;   ScoreWrite    A = the new score
;   OverlayWrite  A = the new overlay flag (the Overlay byte at $88)
;   MapRow        Y = the overlay map's row, 0..191
;
; RAM map (+clean_start zeroes every byte):
;   $80  PaddleX     the paddle's left edge, 0..152
;   $81  BallX       the ball's left edge, 0..157
;   $82  BallY       the ball's top edge, 23..188
;   $83  BallDX      1 = right, $FF = left
;   $84  BallDY      2 = down, $FE = up
;   $85  Score       0..24
;   $86  Lives       3..0
;   $87  State       0 = play, 1 = game over
;   $88  Overlay     0 = game, 1 = frame map
;   $89-$8A ScorePtr  the selected 16-row glyph column
;   $8B-$8E Brick0..3 the four 6-bit brick-row masks
;   $8F-$92 BrickPF0  the four rows' PF0 bytes
;   $93-$96 BrickPF1  the four rows' PF1 bytes
;   $97-$9A BrickPF2  the four rows' PF2 bytes
;   $9B  LineCount    the seven-line brick counter / the fire-edge scratch
;   $9C  PrevSelect   SELECT debounce
;   $9D  PrevFire     fire-edge debounce
;   $9E  TmpRow       brick collision scratch
;   $9F  TmpCol       brick collision scratch
;   $F8-$FF stack
;
; Build: acme -f plain -o build/lesson62.bin \
;        lessons/part8-advanced/62-reverse-engineering/demo-62.asm
; Run:   stella build/lesson62.bin
; The ROM is 4,096 bytes.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44          ; 37-line VBLANK (44 ticks)
OVERSCAN_TIMER = 36          ; 30-line overscan (1 + 35 x 64 cycles)
POS_BIAS       = 3           ; the Lesson 26 output-delay bias

BALL_H         = 4           ; the ball's visible height in scanlines
BALL_TOP       = 23          ; the first row below the life bar
BALL_BOTTOM    = 188         ; the first row past the paddle
BRICK_TOP      = 32          ; the wall's first visible row
BRICK_ROWS     = 4
BRICK_H        = 8
PADDLE_Y       = 176         ; the paddle's first visible row
PADDLE_MAX     = 152         ; the paddle's rightmost left edge
P1_X           = 76          ; the score column's left edge

C_WHITE        = $0E
C_GOLD         = $1A
C_BRICK        = $1A
C_RED          = $42
C_BLUE         = $84
C_GREEN        = $C2
C_PADDLE       = $C8
C_BG           = $02
C_VSYNC        = $0E
C_VBLANK       = $84
C_KERNEL       = $C2
C_OVERSCAN     = $42

; =============================================================================
; RAM ALLOCATION ($80-$9F; +clean_start zeroes every byte)
; =============================================================================
PaddleX     = $80
BallX       = $81
BallY       = $82
BallDX      = $83
BallDY      = $84
Score       = $85
Lives       = $86
State       = $87
Overlay     = $88
ScorePtr    = $89            ; $89-$8A
Brick0      = $8B            ; $8B-$8E
Brick1      = $8C
Brick2      = $8D
Brick3      = $8E
BrickPF0    = $8F            ; $8F-$92
BrickPF1    = $93            ; $93-$96
BrickPF2    = $97            ; $97-$9A
LineCount   = $9B
PrevSelect  = $9C
PrevFire    = $9D
TmpRow      = $9E
TmpCol      = $9F

; =============================================================================
; RESET — the TIA setup and the first game
; =============================================================================
    * = $F000

Reset:
    +clean_start             ; zero TIA and RAM, set SP = $FF
    LDA #$00
    STA SWACNT               ; port A is an input port (the joystick)
    JSR StartGame            ; score 0, three lives, full wall, ball in play
    JMP StartFrame

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
; SELECT — one toggle per press, not one per frame
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  PrevSelect remembers the previous
; frame so a held switch toggles the overlay once.
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
    LDA Overlay
    EOR #$01
    STA Overlay
OverlayWrite:                ; checkpoint: A = the new overlay flag
    NOP
SelectDone:

; -----------------------------------------------------------------------------
; FIRE — one start per press, and only on the game-over screen
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  EOR flips it to 1 = pressed; the
; changed-and-still-pressed test keeps only the 0 -> 1 edge.
    LDA INPT4
    AND #$80
    EOR #$80
    STA LineCount            ; this frame's fire bit (scratch)
    EOR PrevFire
    AND LineCount
    BEQ NoFire
    LDA State
    BEQ NoFire
    JSR StartGame            ; fire restarts the game
NoFire:
    LDA LineCount
    STA PrevFire

; -----------------------------------------------------------------------------
; GAME LOGIC — only while State = 0
; -----------------------------------------------------------------------------
    LDA State
    BEQ GameLogic
    JMP DisplaySetup

GameLogic:
; --- the paddle: the joystick, or the auto-demo ------------------------------
    LDA SWCHA
    AND #$C0                 ; P0 left (bit 6) and right (bit 7)
    CMP #$C0
    BEQ AutoPaddle           ; neither pressed: track the ball
    LDA SWCHA
    AND #$40                 ; left
    BNE PaddleRight
    LDA PaddleX
    SEC
    SBC #4
    BCS PaddleLeftOK
    LDA #0
PaddleLeftOK:
    JMP PaddleStore
PaddleRight:
    LDA SWCHA
    AND #$80                 ; right
    BNE PaddleDone
    LDA PaddleX
    CLC
    ADC #4
    CMP #(PADDLE_MAX + 1)
    BCC PaddleStore
    LDA #PADDLE_MAX
    JMP PaddleStore
AutoPaddle:
    LDA BallX
    SEC
    SBC #3                   ; centre the 8-pixel paddle on the 2-pixel ball
    BCS AutoPaddleOK
    LDA #0
AutoPaddleOK:
    CMP #(PADDLE_MAX + 1)
    BCC PaddleStore
    LDA #PADDLE_MAX
PaddleStore:
    STA PaddleX
PaddleDone:

; --- the ball moves one byte per axis --------------------------------------
    LDA BallX
    CLC
    ADC BallDX
    STA BallX
BallMove:                    ; checkpoint: A = the new BallX
    LDA BallY
    CLC
    ADC BallDY
    STA BallY

; --- side walls and the ceiling --------------------------------------------
    LDA BallX
    CMP #1
    BCC BounceX
    CMP #158                 ; the ball is two pixels wide: 158-159 is the edge
    BCS BounceX
    JMP XDone
BounceX:
; Clamp before the flip: a fast BallDX must not leave BallX at 159, because the
; brick test's centre would be 160 and the mirrored column $FF would read past
; the 80-byte ColTable.  The ball is two pixels wide, so 158 is the last legal
; left edge.
    LDA BallX
    CMP #158
    BCC LeftWallClamp
    LDA #158
    STA BallX
    JMP FlipX
LeftWallClamp:
    LDA #0
    STA BallX
FlipX:
    LDA BallDX
    EOR #$FE                 ; 1 <-> $FF
    STA BallDX
XDone:
    LDA BallY
    CMP #BALL_TOP
    BCS TopDone
    LDA #BALL_TOP
    STA BallY
    LDA #2
    STA BallDY
TopDone:

; --- the bottom: a life, or the game-over state ----------------------------
    LDA BallY
    CMP #BALL_BOTTOM
    BCC BottomDone
    DEC Lives
    BEQ GameOver
    JSR RespawnBall
    JMP BottomDone
GameOver:
    LDA #1
    STA State
BottomDone:

; --- the paddle: a bounce, a snap above the paddle, and an angle -----------
    LDA BallDY
    BMI NoPaddle
    LDA BallY
    CLC
    ADC #3                   ; the ball's bottom edge
    CMP #PADDLE_Y
    BCC NoPaddle
    CMP #(PADDLE_Y + 8)
    BCS NoPaddle
    LDA BallX
    CLC
    ADC #2                   ; the ball's right edge
    CMP PaddleX
    BCC NoPaddle
    LDA PaddleX
    CLC
    ADC #8
    CMP BallX
    BCC NoPaddle
; --- a hit: snap the ball above the paddle and reverse the vertical step ---
    LDA #(PADDLE_Y - BALL_H)
    STA BallY
    LDA #$FE
    STA BallDY
    LDA BallX
    CLC
    ADC #1                   ; the ball's centre
    SEC
    SBC PaddleX
    CMP #4
    BCC PaddleHitLeft
    LDA #1                   ; right half: send it right
    BNE PaddleDXStore
PaddleHitLeft:
    LDA #$FF                 ; left half: send it left
PaddleDXStore:
    STA BallDX
NoPaddle:

; --- the bricks: the leading edge picks one row and the centre one column --
    LDA BallDY
    BMI BrickUp
    LDA BallY
    CLC
    ADC #3                   ; moving down: the bottom edge leads
    JMP BrickEdge
BrickUp:
    LDA BallY                ; moving up: the top edge leads
BrickEdge:
    CMP #BRICK_TOP
    BCC NoBrickHit
    CMP #(BRICK_TOP + 32)
    BCS NoBrickHit
    SEC
    SBC #BRICK_TOP
    LSR
    LSR
    LSR
    STA TmpRow               ; row 0..3
    LDA BallX
    CLC
    ADC #1                   ; the ball's centre
    TAX
    CPX #80
    BCC BrickColLeft
    TXA
    EOR #$FF
    SEC
    SBC #96                  ; 159 - centre: mirror the right half
    TAX
BrickColLeft:
    LDA ColTable,X
    CMP #$FF
    BEQ NoBrickHit
    STA TmpCol               ; column 0..5
    LDA TmpRow
    ASL
    STA LineCount
    ASL
    CLC
    ADC LineCount            ; row * 6
    CLC
    ADC TmpCol
HitBrick:                    ; checkpoint: A = the brick index 0..23
    TAY                      ; mirror the index into Y for the debugger
    LDA TmpRow
    TAX                      ; X = row
    LDY TmpCol
    LDA BitMask,Y
    AND Brick0,X
    BEQ NoBrickHit
; --- clear the bit, score one, and reverse the vertical step ---------------
    LDA BitMask,Y
    EOR Brick0,X
    STA Brick0,X
    INC Score
    LDA Score
ScoreWrite:                  ; checkpoint: A = the new score
    LDA BallDY
    EOR #$FC                 ; 2 <-> $FE
    STA BallDY
    LDA Brick0
    ORA Brick1
    ORA Brick2
    ORA Brick3
    BNE NoBrickHit
    LDA #1                   ; the wall is gone: the game is over (a win)
    STA State
NoBrickHit:

; =============================================================================
; DISPLAY SETUP — tags, tables, colours and the one HMOVE
; =============================================================================
DisplaySetup:
; --- the score pointer: one of the 25 sixteen-row columns -------------------
    LDX Score
    LDA ScorePtrLo,X
    STA ScorePtr
    LDA ScorePtrHi,X
    STA ScorePtr+1

; --- rebuild the four brick rows' playfield bytes from the masks -----------
    LDX #0
RebuildBricks:
    LDY Brick0,X
    LDA BrickPF0Table,Y
    STA BrickPF0,X
    LDA BrickPF1Table,Y
    STA BrickPF1,X
    LDA BrickPF2Table,Y
    STA BrickPF2,X
    INX
    CPX #4
    BNE RebuildBricks

; --- colours, sizes, and the blank TIA state -------------------------------
    LDA #C_WHITE
    STA COLUP1               ; the score and the life bar
    LDA #C_PADDLE
    STA COLUP0               ; the paddle
    LDA #C_BRICK
    STA COLUPF               ; the bricks and the ball
    LDA State
    BEQ NormalBg
    LDA #C_RED
    JMP BgStore
NormalBg:
    LDA #C_BG
BgStore:
    STA COLUBK
    LDA #$11                 ; reflect the playfield; the ball is 2 px
    STA CTRLPF
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    STA REFP0
    STA REFP1
    STA GRP0
    STA GRP1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA TmpCol               ; the brick-column scratch starts clear

; --- position P0 (paddle), P1 (score), BL (ball), then one HMOVE -----------
; Each coarse routine consumes a line; the three calls and the final WSYNC
; fit inside the 37-line VBLANK, and one HMOVE applies all three fine values.
    LDA PaddleX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA #(P1_X + POS_BIAS)
    JSR SetCoarseP1
    LDA BallX
    CLC
    ADC #(POS_BIAS + 1)      ; the ball's reset is one clock shorter
    JSR SetCoarseBL
    STA WSYNC
    STA HMOVE                ; the one HMOVE of the frame

    +wait_timer
    LDA #$00
    STA VBLANK               ; picture on

; =============================================================================
; THE VISIBLE KERNEL — selector: map, game-over, or play
; =============================================================================
BodyStart:                   ; checkpoint: scanline 37, visible line 0
    LDA Overlay
    BEQ NotMap
    JMP MapKernel
NotMap:
    LDA State
    BEQ PlayKernel
    JMP OverKernel

; -----------------------------------------------------------------------------
; PLAY KERNEL — 192 lines, four zones, one JSR per line
; -----------------------------------------------------------------------------
PlayKernel:
    LDY #0
; --- visible 0-15: the score's sixteen rows --------------------------------
ScoreRows:
    LDA (ScorePtr),Y
    STA GRP1
    JSR DrawBallLine
    CPY #16
    BNE ScoreRows

; --- visible 16: the separator between the score and the life bar ----------
    LDA #$00
    STA GRP1
    JSR DrawBallLine

; --- visible 17-22: the life bar, two rows per life ------------------------
    LDX #6
LivesRows:
    LDA Lives
    ASL
    STA TmpRow
    TYA
    SEC
    SBC #17
    CMP TmpRow
    BCS NoLifeBar
    LDA #$FF
    BNE LifeBarStore
NoLifeBar:
    LDA #$00
LifeBarStore:
    STA GRP1
    JSR DrawBallLine
    DEX
    BNE LivesRows

; --- visible 23-31: the gap between the life bar and the wall --------------
    LDA #$00
    STA GRP1
    LDX #9
BlankRows:
    JSR DrawBallLine
    DEX
    BNE BlankRows

; --- visible 32-63: four brick rows, seven lines plus a one-line gap ------
; X is 0 after the blank loop and becomes the brick-row index.  LineCount is
; the seven-line counter; the gap line prepares the next row's state so the
; first brick line only writes the three PF bytes.
    LDA #7
    STA LineCount
BrickSetup:
    LDA BrickPF0,X
    STA PF0
    LDA BrickPF1,X
    STA PF1
    LDA BrickPF2,X
    STA PF2
BrickLine:
    JSR DrawBallLine
    DEC LineCount
    BNE BrickLine
BrickGap:
    LDA #$00                 ; the row gap: no playfield on this line
    STA PF0
    STA PF1
    STA PF2
    LDA #7                   ; prepare the next row's seven-line counter
    STA LineCount
    INX
    CPX #4
    BEQ BricksDone
    JSR DrawBallLine         ; the gap line for rows 0-2
    JMP BrickSetup
BricksDone:
    JSR DrawBallLine         ; the gap line for row 3

; --- visible 64-175: the open play area ------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDX #112
PlayRows:
    JSR DrawBallLine
    DEX
    BNE PlayRows

; --- visible 176-183: the paddle -------------------------------------------
    LDA #$FF
    STA GRP0
    LDX #8
PaddleRows:
    JSR DrawBallLine
    DEX
    BNE PaddleRows

; --- visible 184-191: the bottom margin ------------------------------------
    LDA #$00
    STA GRP0
    LDX #8
BottomRows:
    DEX
    BEQ BottomLast
    JSR DrawBallLine
    JMP BottomRows
BottomLast:
    JSR DrawLastLine

; =============================================================================
; OVERSCAN — 30 lines, then the next frame
; =============================================================================
; DrawLastLine ends with STA WSYNC + RTS, so its return address is this label
; at scanline 229 cycle 6.
OverscanStart:               ; checkpoint: scanline 229, cycle 6
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; -----------------------------------------------------------------------------
; DrawBallLine — one scanline: the row checkpoint and the next row's ball flag
; -----------------------------------------------------------------------------
; Y is the absolute visible row.  The ball window for the row being drawn was
; prepared by the previous call, so this call sets the window for row Y+1
; before the WSYNC.  The ENABL store lands about 21 cycles after the call,
; after the first visible clocks; the pixels of the ball that lie left of the
; store keep the previous line's enable, while the pixels to its right take
; the new one.  The ball is therefore one scanline higher when it is on the
; right half (X above the store pixel) than when it is on the left.  The
; collision test uses BallY, so it is one line below the visible ball on the
; right half.  That is a real 4K timing compromise; the doc records it.
DrawBallLine:
KernelRow:                   ; checkpoint: Y = the visible row 0..190
    TYA
    CLC
    ADC #1
    SEC
    SBC BallY
    CMP #BALL_H
    BCS BallNextOff
    LDA #$02
    STA ENABL
    JMP BallLineSync
BallNextOff:
    LDA #$00
    STA ENABL
BallLineSync:
    STA WSYNC
    INY
    RTS

; -----------------------------------------------------------------------------
; DrawLastLine — the 192nd row: its ball flag was set by row 190, so this is
; a bare WSYNC and return.  The return lands on OverscanStart at 229/6.
; -----------------------------------------------------------------------------
DrawLastLine:
KernelRowLast:               ; checkpoint: Y = 191, the final visible row
    STA WSYNC
    RTS

; -----------------------------------------------------------------------------
; OVER KERNEL — the red field, the final score, and the restart bar
; -----------------------------------------------------------------------------
OverKernel:
    LDY #0
OverScore:
    LDA (ScorePtr),Y
    STA GRP1
    STA WSYNC
    INY
    CPY #16
    BNE OverScore

    LDA #$00
    STA GRP1
    STA WSYNC
    INY

    LDX #6
OverLives:
    LDA Lives
    ASL
    STA TmpRow
    TYA
    SEC
    SBC #17
    CMP TmpRow
    BCS OverNoLife
    LDA #$FF
    BNE OverLifeStore
OverNoLife:
    LDA #$00
OverLifeStore:
    STA GRP1
    STA WSYNC
    INY
    DEX
    BNE OverLives

; --- visible 23-175: the red field -----------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP1                 ; clear the life bar's last $FF from the red field
    LDX #153
OverField:
    STA WSYNC
    DEX
    BNE OverField

; --- visible 176-183: the white restart bar --------------------------------
    LDA #$FF
    STA PF0
    STA PF1
    STA PF2
    LDA #C_WHITE
    STA COLUPF
    LDX #8
OverBar:
    STA WSYNC
    DEX
    BNE OverBar

; --- visible 184-191: the red bottom margin --------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDX #8
OverBottom:
    STA WSYNC
    DEX
    BNE OverBottom
    JMP OverscanStart

; -----------------------------------------------------------------------------
; MAP KERNEL — the overlay: four phase colours and the row bar
; -----------------------------------------------------------------------------
; Rows 0-2 white (VSYNC), 3-39 blue (VBLANK), 40-161 green (kernel), 162-191
; red (overscan).  The bar on row Y is Y >> 3 chunks long, so the staircase
; records the kernel's row loop.  The true blanked phases keep their line
; counts (3, 37, 30); the 192-line kernel is compressed into 122 rows.
MapKernel:
    LDA #C_WHITE
    STA COLUPF               ; the row bar is white on all four zones
    LDY #0
MapRow:                      ; checkpoint: Y = the map row 0..191
    CPY #3
    BCS MapNotVsync
    LDA #C_VSYNC
    JMP MapBg
MapNotVsync:
    CPY #40
    BCS MapNotVblank
    LDA #C_VBLANK
    JMP MapBg
MapNotVblank:
    CPY #162
    BCS MapOverscan
    LDA #C_KERNEL
    JMP MapBg
MapOverscan:
    LDA #C_OVERSCAN
MapBg:
    STA COLUBK
    TYA
    LSR
    LSR
    LSR
    TAX
    LDA BarPF0,X
    STA PF0
    LDA BarPF1,X
    STA PF1
    LDA BarPF2,X
    STA PF2
    STA WSYNC
    INY
    CPY #192
    BNE MapRow
    JMP OverscanStart

; =============================================================================
; StartGame — a fresh game: score 0, three lives, a full wall, a served ball
; =============================================================================
StartGame:
    LDA #$00
    STA Score
    STA State
    STA Overlay              ; a restart returns to the game view
    LDA #3
    STA Lives
    LDA #$3F                 ; all six brick columns in every row
    STA Brick0
    STA Brick1
    STA Brick2
    STA Brick3
    LDA #76
    STA PaddleX
    LDA #76
    STA BallX
    LDA #168
    STA BallY
    LDA #1
    STA BallDX
    LDA #$FE                 ; up two pixels per frame
    STA BallDY
    RTS

; =============================================================================
; RespawnBall — serve the ball from the paddle after a life is lost
; =============================================================================
RespawnBall:
    LDA PaddleX
    CLC
    ADC #3
; The clamp is defensive: PaddleX is 0..152 today, so PaddleX+3 <= 155 and the
; CMP never triggers.  It keeps the serve safe if the paddle range ever grows.
    CMP #158
    BCC RespawnBallX
    LDA #157
RespawnBallX:
    STA BallX
    LDA #168
    STA BallY
    LDA #1
    STA BallDX
    LDA #$FE
    STA BallDY
    RTS

; =============================================================================
; THE THREE COARSE POSITIONERS — one line each, one HMOVE for all
; =============================================================================
; Input: A = the target X plus a bias.  The routines leave HMP0/HMP1/HMBL set;
; the caller's single STA HMOVE applies all three fine values in one HBLANK.
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
; THE DATA TABLES
; =============================================================================
; BitMask: the bit for each of the six brick columns, indexed by the column.
BitMask:
    !byte $01, $02, $04, $08, $10, $20

; ColTable: map the left half's pixel X (0..79) to a brick column, or $FF for
; a gap or margin.  A brick is pixels 4+12n .. 11+12n (chunks 1+3n .. 2+3n),
; so the table is the wall's geometry written out; the right half is mirrored
; onto it.
ColTable:
    !byte $FF, $FF, $FF, $FF, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $FF, $FF, $FF, $FF, $01, $01, $01, $01
    !byte $01, $01, $01, $01, $FF, $FF, $FF, $FF, $02, $02
    !byte $02, $02, $02, $02, $02, $02, $FF, $FF, $FF, $FF
    !byte $03, $03, $03, $03, $03, $03, $03, $03, $FF, $FF
    !byte $FF, $FF, $04, $04, $04, $04, $04, $04, $04, $04
    !byte $FF, $FF, $FF, $FF, $05, $05, $05, $05, $05, $05
    !byte $05, $05, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF

; BrickPF0/1/2: the three playfield bytes for every 6-bit brick-row mask.
; The bit-to-chunk mapping is the table in the header; the tables are the
; kernel's translation from "which bricks are left" to "what the TIA draws".
BrickPF0Table:
    !byte $00, $60, $00, $60, $00, $60, $00, $60
    !byte $00, $60, $00, $60, $00, $60, $00, $60
    !byte $00, $60, $00, $60, $00, $60, $00, $60
    !byte $00, $60, $00, $60, $00, $60, $00, $60
    !byte $00, $60, $00, $60, $00, $60, $00, $60
    !byte $00, $60, $00, $60, $00, $60, $00, $60
    !byte $00, $60, $00, $60, $00, $60, $00, $60
    !byte $00, $60, $00, $60, $00, $60, $00, $60
BrickPF1Table:
    !byte $00, $00, $C0, $C0, $18, $18, $D8, $D8
    !byte $03, $03, $C3, $C3, $1B, $1B, $DB, $DB
    !byte $00, $00, $C0, $C0, $18, $18, $D8, $D8
    !byte $03, $03, $C3, $C3, $1B, $1B, $DB, $DB
    !byte $00, $00, $C0, $C0, $18, $18, $D8, $D8
    !byte $03, $03, $C3, $C3, $1B, $1B, $DB, $DB
    !byte $00, $00, $C0, $C0, $18, $18, $D8, $D8
    !byte $03, $03, $C3, $C3, $1B, $1B, $DB, $DB
BrickPF2Table:
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $06, $06, $06, $06, $06, $06, $06, $06
    !byte $06, $06, $06, $06, $06, $06, $06, $06
    !byte $30, $30, $30, $30, $30, $30, $30, $30
    !byte $30, $30, $30, $30, $30, $30, $30, $30
    !byte $36, $36, $36, $36, $36, $36, $36, $36
    !byte $36, $36, $36, $36, $36, $36, $36, $36

; BarPF0/1/2: the overlay row bar.  Entry n lights one playfield chunk at
; position n (clamped to chunk 19); the kernel indexes it with Y >> 3, so the
; bar on row Y is a four-pixel dash that steps right once every eight rows.
; The diagonal is the row loop; the zone colours stay visible around it.
BarPF0:
    !byte $10, $20, $40, $80, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
BarPF1:
    !byte $00, $00, $00, $00, $80, $40, $20, $10
    !byte $08, $04, $02, $01, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
BarPF2:
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $01, $02, $04, $08
    !byte $10, $20, $40, $80, $80, $80, $80, $80

; =============================================================================
; THE SCORE TABLE — 25 entries of 16 rows, one per score value
; =============================================================================
; Rows 0-6 are the tens glyph, rows 7-8 are blank, rows 9-15 are the ones
; glyph.  Each glyph is a 5x7 font shifted one bit left inside the 8-pixel
; player.  ScorePtr selects an entry; the kernel reads one row per scanline.
ScoreGlyphs:
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $1C, $22, $26, $2A, $32, $22, $1C   ;  0 = 00
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $08, $18, $08, $08, $08, $08, $1C   ;  1 = 01
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $1C, $22, $02, $04, $08, $10, $3E   ;  2 = 02
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $3E, $04, $08, $04, $02, $22, $1C   ;  3 = 03
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $04, $0C, $14, $24, $3E, $04, $04   ;  4 = 04
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $3E, $20, $3C, $02, $02, $22, $1C   ;  5 = 05
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $0C, $10, $20, $3C, $22, $22, $1C   ;  6 = 06
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $3E, $02, $04, $08, $10, $10, $10   ;  7 = 07
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $1C, $22, $22, $1C, $22, $22, $1C   ;  8 = 08
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $1C, $22, $22, $1E, $02, $04, $18   ;  9 = 09
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $1C, $22, $26, $2A, $32, $22, $1C   ; 10 = 10
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $08, $18, $08, $08, $08, $08, $1C   ; 11 = 11
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $1C, $22, $02, $04, $08, $10, $3E   ; 12 = 12
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $3E, $04, $08, $04, $02, $22, $1C   ; 13 = 13
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $04, $0C, $14, $24, $3E, $04, $04   ; 14 = 14
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $3E, $20, $3C, $02, $02, $22, $1C   ; 15 = 15
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $0C, $10, $20, $3C, $22, $22, $1C   ; 16 = 16
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $3E, $02, $04, $08, $10, $10, $10   ; 17 = 17
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $1C, $22, $22, $1C, $22, $22, $1C   ; 18 = 18
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $1C, $22, $22, $1E, $02, $04, $18   ; 19 = 19
    !byte $1C, $22, $02, $04, $08, $10, $3E, $00, $00, $1C, $22, $26, $2A, $32, $22, $1C   ; 20 = 20
    !byte $1C, $22, $02, $04, $08, $10, $3E, $00, $00, $08, $18, $08, $08, $08, $08, $1C   ; 21 = 21
    !byte $1C, $22, $02, $04, $08, $10, $3E, $00, $00, $1C, $22, $02, $04, $08, $10, $3E   ; 22 = 22
    !byte $1C, $22, $02, $04, $08, $10, $3E, $00, $00, $3E, $04, $08, $04, $02, $22, $1C   ; 23 = 23
    !byte $1C, $22, $02, $04, $08, $10, $3E, $00, $00, $04, $0C, $14, $24, $3E, $04, $04   ; 24 = 24

; ScorePtrLo/Hi: the address of each 16-row entry.  Two 25-byte tables keep
; the 400-byte glyph block free to live anywhere in the cartridge.
ScorePtrLo:
    !byte <(ScoreGlyphs+0), <(ScoreGlyphs+16), <(ScoreGlyphs+32), <(ScoreGlyphs+48), <(ScoreGlyphs+64)
    !byte <(ScoreGlyphs+80), <(ScoreGlyphs+96), <(ScoreGlyphs+112), <(ScoreGlyphs+128), <(ScoreGlyphs+144)
    !byte <(ScoreGlyphs+160), <(ScoreGlyphs+176), <(ScoreGlyphs+192), <(ScoreGlyphs+208), <(ScoreGlyphs+224)
    !byte <(ScoreGlyphs+240), <(ScoreGlyphs+256), <(ScoreGlyphs+272), <(ScoreGlyphs+288), <(ScoreGlyphs+304)
    !byte <(ScoreGlyphs+320), <(ScoreGlyphs+336), <(ScoreGlyphs+352), <(ScoreGlyphs+368), <(ScoreGlyphs+384)
ScorePtrHi:
    !byte >(ScoreGlyphs+0), >(ScoreGlyphs+16), >(ScoreGlyphs+32), >(ScoreGlyphs+48), >(ScoreGlyphs+64)
    !byte >(ScoreGlyphs+80), >(ScoreGlyphs+96), >(ScoreGlyphs+112), >(ScoreGlyphs+128), >(ScoreGlyphs+144)
    !byte >(ScoreGlyphs+160), >(ScoreGlyphs+176), >(ScoreGlyphs+192), >(ScoreGlyphs+208), >(ScoreGlyphs+224)
    !byte >(ScoreGlyphs+240), >(ScoreGlyphs+256), >(ScoreGlyphs+272), >(ScoreGlyphs+288), >(ScoreGlyphs+304)
    !byte >(ScoreGlyphs+320), >(ScoreGlyphs+336), >(ScoreGlyphs+352), >(ScoreGlyphs+368), >(ScoreGlyphs+384)

; =============================================================================
; VECTORS — the 6507 reads RESET at $FFFC and jumps to Reset
; =============================================================================
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
