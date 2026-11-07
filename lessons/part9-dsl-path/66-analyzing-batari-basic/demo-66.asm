; =============================================================================
; LESSON 66 DEMO: The bB Anatomy Viewer
; =============================================================================
; Part 9: The DSL Path
;
; What this program does:
;   A hand-written ACME demo that visualizes how batari BASIC works.  It is
;   NOT bB output and it is NOT generated code: the real bB 1.9 compilation
;   is the separate lesson66.bas / lesson66.generated.txt / lesson66-bb.bin
;   reference.  This ROM is the teaching model.
;
;   Three lenses, selected by SELECT or by the auto-demo:
;     Lens 0 RUN   - a 16-line band (a 3-line gold bar + the white six-digit
;                    frame counter) over a 176-row picture: 5 position/setup
;                    rows, the 168-row starfield loop (Y=6..173), two blank
;                    spacer rows, and the StarLast row.  The picture is a
;                    starfield playfield, a green P0 ship that auto-pans, a
;                    gold P1 enemy, and a white ball.  The objects echo the
;                    bB sample's player0/player1/ball.  There is no text.
;     Lens 1 ZONES - the frame map: 192 visible lines as a teaching
;                    projection of VSYNC (3 white), VBLANK (37 blue), the
;                    kernel (192 compressed to 122 green), and overscan
;                    (30 red).  A white row bar steps right one playfield
;                    chunk every eight rows; the repeat playfield draws the
;                    same staircase in both 80-pixel halves.  There is no text; the lesson
;                    names the phases.  The blanked phases are NOT visible
;                    on a TV; the map compresses the kernel into the lines
;                    the visible window has room for.
;     Lens 2 VARS  - a 16-line band (a 3-line gold bar + the six-digit
;                    group/address window) over a 16x8 grid of the 128 RIOT
;                    RAM bytes $80-$FF.  Every cell is one byte, drawn as a
;                    four-pixel bar whose height is the group code: SYS is
;                    eight lines, SCR seven, PTR six, TMP five, RND four,
;                    PF three, DIM two; AUX is the top dot and STK the
;                    bottom dot.  Each grid row is nine display lines (a
;                    preload line that repeats the first cell line, then the
;                    eight cell lines) plus two dark gap lines: 8 x 11 = 88.
;                    An 8-pixel ball makes the selected row a solid white
;                    block over those nine lines; it spans the 4-pixel cell
;                    and the 4-pixel gap after it.  The six-digit window
;                    shows the group code in the digit to the left of the
;                    two hex digits of $80 + MapIndex (for example 0 8 0 is
;                    group 0, SYS, at $80).  There is no legend text; the
;                    lesson's table maps the groups.
;
;   Auto-demo: a 240-frame (about four-second) timer advances the lens
;   0 -> 1 -> 2 -> 0 when no SELECT has been pressed; any SELECT edge
;   advances the lens immediately and resets the timer.  A fixed wait is
;   therefore deterministic: about 2 s is RUN, 6 s is ZONES, 10 s is VARS.
;   The auto-demo only changes Lens at a frame boundary; the frame stays
;   262 lines.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5, OverscanStart 229/6.
;   Every lens's last visible line ends with STA WSYNC / BIT / JMP so the
;   overscan label lands at 229/6, exactly the course skeleton.
;
; Checkpoints (source label, expected Stella state):
;   StartFrame   259/3   the first VSYNC instruction
;   VblankStart    0/5   the first VBLANK instruction
;   BodyStart     37/5   the first visible line
;   OverscanStart 229/6  the first overscan instruction
;   LensRead     A = 0/1/2, the active lens
;   LensWrite    A = the new lens (SELECT or the auto-demo)
;   FrameRead    A = the free-running frame counter
;   MapIndexRead A = the highlighted RAM byte index, 0..127
;
; RAM map (+clean_start zeroes every byte):
;   $80 Lens         0 = RUN, 1 = ZONES, 2 = VARS
;   $81 Frame        free-running frame counter
;   $82 ShipX        the RUN ship's left edge, 8..144
;   $83 ShipDir      1 = right, $FF = left
;   $84 free
;   $85 MapIndex     the VARS highlighted byte, 0..127
;   $86 PrevSelect   SELECT level last frame
;   $87 NewSelect    SELECT level this frame
;   $88 free
;   $89 BallX        the ball's target X
;   $8A free
;   $8B TmpA         scratch
;   $8C GridRow      the VARS grid row, 0..7
;   $8D ScreenY      the ZONES screen row counter
;   $8E BarIdx       the ZONES bar table index, 0..23
;   $8F LineCount    the ZONES band line counter
;   $90 SelectedRow  MapIndex >> 4, 0..7 (the grid row)
;   $91 OwnerGroup   the VARS group code, 0..8
;   $92 MapTick      the MapIndex speed divider
;   $93-$94 free
;   $95 LensTimer    the auto-demo frame counter, 0..239
;   $96 free
;   $97 TmpB         the hex-glyph copy counter
;   $98-$9F free
;   $A0-$D7 the shared score library (ScoreDigits, ScoreRow, ScoreTmp,
;           ScoreBuf)
;   $D8-$F7 free
;   $F8-$FF stack
;
; Build: acme -f plain -o build/demo-66.bin \
;        lessons/part9-dsl-path/66-analyzing-batari-basic/demo-66.asm
; Run:   stella build/demo-66.bin
; The ROM is 4,096 bytes.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; CONSTANTS
; =============================================================================
VBLANK_TIMER    = 44          ; 37-line VBLANK (44 ticks)
OVERSCAN_TIMER  = 36          ; 30-line overscan (36 ticks)
POS_BIAS        = 3           ; the Lesson 26 output-delay bias
AUTO_LENS_FRAMES = 240        ; the auto-demo: about four seconds per lens

; --- the three lenses -------------------------------------------------------
LENS_RUN   = 0
LENS_ZONES = 1
LENS_VARS  = 2

; --- RUN geometry -----------------------------------------------------------
RUN_FIRST   = 6               ; the first StarBody row's Y coordinate (screen row 21)
SHIP_Y      = 120             ; the ship's picture row
ENEMY_Y     = 60              ; the enemy's picture row
BALL_Y      = 40              ; the ball's picture row
SHIP_MIN    = 8
SHIP_MAX    = 144
ENEMY_X     = 100
RUN_BALL_X  = 80

; --- VARS layout (192 visible lines) ----------------------------------------
; 16 label + 2 top gap + 8 rows x (1 preload + 8 cell + 2 gap) = 88
; + 85 blank + 1 last row = 192.

; --- colours (TIA colour bytes, not RGB) -----------------------------------
C_WHITE   = $0E
C_BLUE    = $84
C_GREEN   = $C2
C_RED     = $42
C_GOLD    = $1A
C_SHIP    = $C8
C_BG      = $02

; =============================================================================
; RAM
; =============================================================================
Lens        = $80
Frame       = $81
ShipX       = $82
ShipDir     = $83
; $84 free
MapIndex    = $85
PrevSelect  = $86
NewSelect   = $87
; $88 free
BallX       = $89
; $8A free
TmpA        = $8B
GridRow     = $8C
ScreenY     = $8D
BarIdx      = $8E
LineCount   = $8F
SelectedRow = $90
OwnerGroup  = $91
MapTick     = $92
LensTimer   = $95
TmpB        = $97
; $93-$94, $96 and $98-$9F are free
; $A0-$D7 the score library
; $D8-$F7 free
; $F8-$FF stack

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreSetup positions P0/P1 at 56/64, sets three-copy close mode and VDEL,
; and strobes the HMOVE.  ScoreDraw paints the six 8-pixel columns.
; ScoreAddOne increments the six decimal digits.  The library owns $A0-$D7.
; It is sourced after the ROM origin because it contains code.
    * = $F000

    !source "include/score.asm"

; =============================================================================
; RESET
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port
    STA SWBCNT              ; port B is an input port
    STA GRP0
    STA GRP1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA VDELP0
    STA VDELP1
    LDA #$0E
    STA COLUP0
    STA COLUP1
    LDA #$02
    STA COLUBK
    LDA #$10                ; repeat playfield, 2-pixel ball
    STA CTRLPF

    ; --- the initial lens state --------------------------------------------
    LDA #LENS_RUN
    STA Lens
    STA Frame
    STA PrevSelect
    STA NewSelect
    STA MapIndex
    STA MapTick
    STA GridRow
    STA LensTimer
    LDA #60
    STA ShipX
    LDA #1
    STA ShipDir
    LDA #RUN_BALL_X
    STA BallX
    LDA #0
    STA SelectedRow
    STA OwnerGroup

    ; --- the score ---------------------------------------------------------
    JSR ScoreInit
    JSR ScoreClear
    JSR ScoreSetup           ; P0/P1 at 56/64, NUSIZ=3, VDEL=1, HMOVE

    JMP StartFrame

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262
; =============================================================================
StartFrame:                  ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                 ; checkpoint: scanline 0, cycle 5
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; SELECT and the auto-demo — one lens advance, then reset the timer
; -----------------------------------------------------------------------------
; A SELECT edge advances the lens immediately; otherwise the 240-frame
; auto-demo timer advances it.  Both paths reset the timer and call the
; same advance routine, so the lens-entry side effects cannot diverge.
    LDA SWCHB
    AND #$02
    EOR #$02                 ; 1 = SELECT pressed
    STA NewSelect
    AND PrevSelect
    EOR NewSelect            ; new & ~previous: a fresh press
    BEQ CheckAutoDemo
    LDA #0
    STA LensTimer
    JSR AdvanceLens
    JMP SelectDone
CheckAutoDemo:
    INC LensTimer
    LDA LensTimer
    CMP #AUTO_LENS_FRAMES
    BCC SelectDone
    LDA #0
    STA LensTimer
    JSR AdvanceLens
SelectDone:
    LDA NewSelect
    STA PrevSelect


; -----------------------------------------------------------------------------
; FRAME COUNTER
; -----------------------------------------------------------------------------
    INC Frame
    LDA Frame
FrameRead:                   ; checkpoint: A = the frame counter
    NOP

; -----------------------------------------------------------------------------
; LENS-SPECIFIC STATE
; -----------------------------------------------------------------------------
    LDA Lens
LensRead:                    ; checkpoint: A = the active lens
    NOP
    BEQ VblankRun
    CMP #LENS_ZONES
    BEQ VblankZones
    JMP VblankVars

; --- RUN --------------------------------------------------------------------
VblankRun:
    ; the ship auto-pans between SHIP_MIN and SHIP_MAX
    LDA ShipX
    CLC
    ADC ShipDir
    CMP #SHIP_MIN
    BCS RunCheckRight
    LDA #SHIP_MIN
    STA ShipX
    JMP RunTurn
RunCheckRight:
    CMP #(SHIP_MAX + 1)
    BCC RunShipStore
    LDA #SHIP_MAX
    STA ShipX
RunTurn:
    LDA ShipDir
    EOR #$FE                 ; 1 <-> $FF
    STA ShipDir
    JMP RunColours
RunShipStore:
    STA ShipX
RunColours:
    ; the score counts frames in decimal, like the bB sample's score = score+1
    JSR ScoreAddOne
    LDA #RUN_BALL_X
    STA BallX
    LDA #C_BG
    STA COLUBK
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    LDA #C_GOLD
    STA COLUPF
    LDA #$10                 ; repeat playfield, 2-pixel ball
    STA CTRLPF
    LDA #$00
    STA VDELBL               ; the RUN ball's enable is immediate
    JMP VblankCommon

; --- ZONES ------------------------------------------------------------------
VblankZones:
    LDA #$00
    STA GRP0
    STA GRP1
    STA ENABL
    STA NUSIZ0
    STA NUSIZ1
    STA VDELP0
    STA VDELP1
    STA VDELBL
    ; preload the first white VSYNC row: the first BarLines store is too late
    ; for the left-half PF slots, so the VBLANK supplies row 0.
    LDA BarPF0
    STA PF0
    LDA BarPF1
    STA PF1
    LDA BarPF2
    STA PF2
    LDA #$10
    STA CTRLPF               ; repeat: the staircase appears in both halves
    LDA #0
    STA ScreenY
    STA BarIdx
    LDA #C_WHITE
    STA COLUPF
    STA COLUBK
    LDA #3
    STA LineCount
    JMP VblankWait

; --- VARS -------------------------------------------------------------------
VblankVars:
    ; advance the highlighted cell every eight frames
    INC MapTick
    LDA MapTick
    AND #$07
    BNE NoMapAdvance
    INC MapIndex
    LDA MapIndex
    CMP #128
    BCC MapStore
    LDA #0
MapStore:
    STA MapIndex
NoMapAdvance:
    LDA MapIndex
MapIndexRead:                ; checkpoint: A = the highlighted RAM byte index
    NOP

    ; the selected row and the owner group
    LDA MapIndex
    LSR
    LSR
    LSR
    LSR
    STA SelectedRow

    JSR SetOwner
    JSR BuildHexScore
    JSR SetVarBall

    LDA #C_BG
    STA COLUBK
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    STA COLUPF
    LDA #$30                 ; repeat playfield, 8-pixel ball
    STA CTRLPF
    LDA #$00
    STA VDELBL               ; the VARS ball's block is the row's nine display lines
    JMP VblankCommon

; --- the shared score / ball positioning ------------------------------------
VblankCommon:
    ; clear the visible objects before the score band
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL

    ; preload the first score-band row: the ScoreBand stores in the first
    ; visible line are too late for the left-half PF slots, so the VBLANK
    ; supplies the colour and the three bytes here.
    LDA #C_GOLD
    STA COLUPF
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2

    ; position the ball; ScoreSetup's HMOVE applies HMP0/HMP1/HMBL together
    LDA BallX
    CLC
    ADC #(POS_BIAS + 1)
    JSR SetCoarseBL
    JSR ScoreSetup

    ; the score band's score is white
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1

    JMP VblankWait

VblankWait:
    +wait_timer
    LDA #$00
    STA VBLANK               ; picture on

; =============================================================================
; VISIBLE PICTURE — the three lenses
; =============================================================================
BodyStart:                   ; checkpoint: scanline 37, visible line 0
    LDA Lens
    BEQ RunLens
    CMP #LENS_ZONES
    BNE NotZoneLens
    JMP ZoneLens
NotZoneLens:
    JMP VarLens

; -----------------------------------------------------------------------------
; LENS 0 — RUN
; -----------------------------------------------------------------------------
RunLens:
    JSR ScoreBand
    JMP RunPicture

RunPicture:
    ; the picture's objects have their own colours; the score is already drawn
    LDA #C_SHIP
    STA COLUP0
    LDA #C_GOLD
    STA COLUP1
    LDA #C_GOLD
    STA COLUPF

    ; Position P0 (ship) and P1 (enemy).  The two positioners and the final
    ; WSYNC consume five picture rows (screen 16-20); the first StarBody row
    ; is Y=6 on screen row 21.  The starfield loop is Y=6..173 (168 rows), the
    ; two blank spacers take the next two rows, and StarLast draws the last
    ; row.  16 + 5 + 168 + 2 + 1 = 192.
    LDA ShipX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    STA WSYNC                ; start the enemy's positioner on a fresh line
    LDA #(ENEMY_X + POS_BIAS)
    JSR SetCoarseP1
    LDA #0
    STA HMBL                 ; the ball's fine offset was applied in VBLANK
    STA WSYNC
    STA HMOVE                ; HMOVE blanks the leftmost 8 pixels of this
                             ; first star row (the only row it affects)
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL
    LDY #RUN_FIRST
RunToBall:
    CPY #BALL_Y
    BEQ RunBallZone
    JSR StarLine
    JMP RunToBall
RunBallZone:
RunBallLoop:
    JSR StarBallLine          ; StarBody clobbers X, so test Y instead
    CPY #(BALL_Y + 4)
    BNE RunBallLoop
RunToEnemy:
    CPY #ENEMY_Y
    BEQ RunEnemyZone
    JSR StarLine
    JMP RunToEnemy
RunEnemyZone:
RunEnemyLoop:
    JSR StarEnemyLine
    CPY #(ENEMY_Y + 6)
    BNE RunEnemyLoop
RunToShip:
    CPY #SHIP_Y
    BEQ RunShipZone
    JSR StarLine
    JMP RunToShip
RunShipZone:
RunShipLoop:
    JSR StarShipLine
    CPY #(SHIP_Y + 6)
    BNE RunShipLoop
RunBottom:
    CPY #174
    BEQ RunLast
    JSR StarLine
    JMP RunBottom
RunLast:
    ; two blank spacer rows: 16 band + 5 position + 168 starfield = 189;
    ; the two spacers make 191 and StarLast draws the 192nd line.  The first
    ; WSYNC ends the last starfield row before the PF is cleared, so that
    ; row keeps its right half; the second spacer line also computes the last
    ; row's index so StarLast can store PF before the left-half latch.
    STA WSYNC                ; end the last starfield row
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC                ; blank spacer row 1
    ; compute the last row's starfield index while this spacer line runs, so
    ; StarLast can store PF before the left-half latch on the next line
    TYA
    CLC
    ADC Frame
    AND #$0F
    TAX
    STA WSYNC                ; blank spacer row 2
    JMP StarLast

; --- StarLast — the final visible row; X was computed in RunLast; the
; --- WSYNC/BIT/JMP tail lands at 229/6 -------------------------------------
StarLast:
    ; X was computed on the previous spacer line, so the first PF store lands
    ; early enough for the left-half latch; the second WSYNC/BIT/JMP keeps the
    ; overscan landing at 229/6.
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    LDA #0
    STA ENABL
    STA GRP0
    STA GRP1
    STA WSYNC
    BIT Frame                ; three cycles of alignment
    JMP OverscanStart        ; fetched at 229/6

; -----------------------------------------------------------------------------
; THE SCORE BAND — 3 gold bar rows + 4 blank + 9 score rows = 16
; -----------------------------------------------------------------------------
; The band is shared by RUN and VARS.  The gold bar identifies the bB-style
; score header; the six-digit window underneath is the score (RUN) or the
; group/address window (VARS).  There is no text in the band.
ScoreBand:
    LDA #C_GOLD
    STA COLUPF
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    LDY #3
BandBar:
    STA WSYNC
    DEY
    BNE BandBar
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #4
BandBlank:
    STA WSYNC
    DEY
    BNE BandBlank
    JSR ScoreDraw
    ; leave three-copy / VDEL mode before the picture
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    STA VDELP0
    STA VDELP1
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    RTS

; -----------------------------------------------------------------------------
; LENS 1 — ZONES
; -----------------------------------------------------------------------------
ZoneLens:
    JMP ZonePicture

ZonePicture:
    ; the white VSYNC band: VblankZones already set ScreenY, BarIdx,
    ; COLUPF, COLUBK and LineCount, so the first bar line starts at 37/5.
    JSR BarLines

    ; rows 3-39: VBLANK (37 rows)
    LDA #C_BLUE
    STA COLUBK
    LDA #37
    STA LineCount
    JSR BarLines

    ; rows 40-161: the kernel, compressed to 122 rows
    LDA #C_GREEN
    STA COLUBK
    LDA #122
    STA LineCount
    JSR BarLines

    ; rows 162-190: overscan (29 rows), then the last row below
    LDA #C_RED
    STA COLUBK
    LDA #29
    STA LineCount
    JSR BarLines

    ; row 191: the last map line, then the overscan at 229/6
    LDX BarIdx
    LDA BarPF0,X
    STA PF0
    LDA BarPF1,X
    STA PF1
    LDA BarPF2,X
    STA PF2
    STA WSYNC
    BIT Frame
    JMP OverscanStart

; --- BarLines — draw LineCount bar-only rows --------------------------------
; ScreenY is the absolute map row; BarIdx is the bar table position.  The
; next row's BarIdx is prepared during the current row, so the line starts
; with the bar bytes already known.
BarLines:
BarLine:
    LDX BarIdx
    LDA BarPF0,X
    STA PF0
    LDA BarPF1,X
    STA PF1
    LDA BarPF2,X
    STA PF2
    LDA ScreenY
    CLC
    ADC #1
    AND #7
    BNE BarNoStep
    INC BarIdx
BarNoStep:
    INC ScreenY
    STA WSYNC
    DEC LineCount
    BNE BarLine
    RTS

; -----------------------------------------------------------------------------
; LENS 2 — VARS
; -----------------------------------------------------------------------------
VarLens:
    JSR ScoreBand
    JMP VarPicture

; --- WriteGridLine — the shared grid cell line, with the left/right split ---
; X is the table entry.  The macro is used for the preload line and for all
; eight cell lines so the split is identical (a JSR per line would push the
; left-half stores past the latch).  The L bytes go early; the R bytes follow
; after the left half's latch.  The caller adds the WSYNC.
!macro WriteGridLine {
    LDA GridL0,X
    STA PF0
    LDA GridL1,X
    STA PF1
    LDA GridL2,X
    STA PF2
    LDA GridR0,X
    STA PF0
    NOP
    NOP
    NOP
    LDA GridR1,X
    STA PF1
    NOP
    NOP
    NOP
    LDA GridR2,X
    STA PF2
}

VarPicture:
    LDA #C_WHITE
    STA COLUPF               ; the grid is white
    ; the two gap lines before grid row 0 (screen rows 16-17)
    LDX #0                   ; X = the grid table index, 0..63
    LDA #0
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
    STA WSYNC
    ; preload row 0's first cell line (X=0) before the line starts; the
    ; macro writes the full left/right split, not just the L bytes.
    +WriteGridLine

    ; eight rows: the preload line, eight cell lines, and two gap lines each
    LDA #0
    STA GridRow
GridRowLoop:
    ; The ball is a solid white block over the selected row's nine display
    ; lines (the preload line plus the eight cell lines); the gap lines and
    ; the other rows are off.
    LDA GridRow
    CMP SelectedRow
    BNE RowCellsOff
    LDA #2
    JMP RowCellsStore
RowCellsOff:
    LDA #0
RowCellsStore:
    STA ENABL
    LDY #8
GridCellLoop:
    +WriteGridLine
    INX
    STA WSYNC
    DEY
    BNE GridCellLoop

    ; the two blank gap lines after this row
    LDA #0
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC                ; gap line 1
    ; After the last row X=64 would read past the 64-byte grid planes; skip
    ; that preload so the tail line stays dark.  The check runs on the first
    ; gap line, so the rows 0-6 preload keeps its early L stores.
    LDA GridRow
    CMP #7
    BEQ TailSkip
    STA WSYNC                ; gap line 2
    +WriteGridLine           ; the next row's preload, full split
    JMP TailDone
TailSkip:
    STA WSYNC                ; gap line 2
TailDone:
    INC GridRow
    LDA GridRow
    CMP #8
    BNE GridRowLoop

    ; the grid is done; the ball is off and the rest of the screen is dark
    LDA #0
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    ; 85 dark rows below the grid: the skipped tail line plus 84 blanks
    LDY #85
VarBlank:
    STA WSYNC
    DEY
    BNE VarBlank

    ; row 191: the last visible line
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
    BIT Frame
    JMP OverscanStart

; =============================================================================
; THE RUN PICTURE LINE ROUTINES
; =============================================================================
; StarBody draws the starfield row and waits; it leaves GRP0/GRP1/ENABL alone.
; The wrappers set the object for the current row, then tail-call StarBody.
StarLine:
    LDA #C_GOLD
    STA COLUPF               ; the starfield is gold on ordinary rows
    LDA #$00
    STA ENABL
    STA GRP0
    STA GRP1
    JMP StarBody

StarBallLine:
    LDA #C_WHITE
    STA COLUPF               ; the ball's four rows are white
    LDA #$02
    STA ENABL
    JMP StarBody

StarEnemyLine:
    TYA
    SEC
    SBC #ENEMY_Y
    TAX
    LDA EnemyGfx,X
    STA GRP1
    JMP StarBody

StarShipLine:
    TYA
    SEC
    SBC #SHIP_Y
    TAX
    LDA ShipGfx,X
    STA GRP0
    JMP StarBody

StarBody:
    TYA
    CLC
    ADC Frame
    AND #$0F
    TAX
    STA WSYNC
    ; the index is known before the line starts, so the three stores land in
    ; the left-half PF slots (PF0 ~7, PF1 ~14, PF2 ~21) instead of ~52-69.
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    INY
    RTS

; =============================================================================
; POSITIONING — the Lesson 26 divide-by-15 coarse routines
; =============================================================================
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
; VARS HELPERS
; =============================================================================
; SetOwner — A = the owner group code for MapIndex.
;   0 SYS    $80-$92 and $EE-$EF   player/ball/missile state + playfieldpos
;   1 SCR    $93-$95              the three score bytes
;   2 PTR    $96-$9B              the six score pointers
;   3 TMP    $9C-$A1              temp1-temp6
;   4 RND    $A2-$A3              rand and scorecolor
;   5 PF     $A4-$D3              the playfield / var0-var47 block
;   6 DIM    $D4-$ED              the a-z pool (the dim aliases)
;   7 AUX    $F0-$F5              aux1-aux6, free in this program
;   8 STK    $F6-$FF              the bB stack
SetOwner:
    LDA MapIndex
    CMP #$13
    BCC OwnerSys
    CMP #$16
    BCC OwnerScr
    CMP #$1C
    BCC OwnerPtr
    CMP #$22
    BCC OwnerTmp
    CMP #$24
    BCC OwnerRnd
    CMP #$54
    BCC OwnerPf
    CMP #$6E
    BCC OwnerDim
    CMP #$70
    BCC OwnerSys
    CMP #$76
    BCC OwnerAux
    LDA #8
    JMP OwnerStore
OwnerSys:
    LDA #0
    JMP OwnerStore
OwnerScr:
    LDA #1
    JMP OwnerStore
OwnerPtr:
    LDA #2
    JMP OwnerStore
OwnerTmp:
    LDA #3
    JMP OwnerStore
OwnerRnd:
    LDA #4
    JMP OwnerStore
OwnerPf:
    LDA #5
    JMP OwnerStore
OwnerDim:
    LDA #6
    JMP OwnerStore
OwnerAux:
    LDA #7
OwnerStore:
    STA OwnerGroup
    RTS

; SetVarBall — BallX is the selected cell's left edge.  The 8-pixel ball
; spans the 4-pixel cell and the 4-pixel gap after it.  The ball has no Y
; register; the vertical white block is the grid's ENABL logic.
SetVarBall:
    LDA MapIndex
    AND #$0F
    CMP #8
    BCS VarBallRight
    ASL
    ASL
    ASL
    STA BallX
    RTS
VarBallRight:
    SEC
    SBC #8
    ASL
    ASL
    ASL
    CLC
    ADC #80
    STA BallX
    RTS

; BuildHexScore — the six-digit window: the three left digits are blank,
; then the group code, then the two hex digits of $80 + MapIndex.
BuildHexScore:
    ; blank the first three columns
    LDX #24
    LDA #0
ClearHex:
    DEX
    STA ScoreBuf,X
    BNE ClearHex

    LDA MapIndex
    CLC
    ADC #$80
    STA TmpA

    ; position 5 = the low nibble
    LDA TmpA
    AND #$0F
    TAX
    LDA #5
    JSR SetHexGlyph
    ; position 4 = the high nibble
    LDA TmpA
    LSR
    LSR
    LSR
    LSR
    TAX
    LDA #4
    JSR SetHexGlyph
    ; position 3 = the owner group code
    LDX OwnerGroup
    LDA #3
    JSR SetHexGlyph
    RTS

; SetHexGlyph — A = position 0-5, X = glyph 0-15.  Copies eight bottom-up
; bytes from HexFont into that column of ScoreBuf.
SetHexGlyph:
    STA TmpB
    TXA
    ASL
    ASL
    ASL
    TAX
    LDA TmpB
    ASL
    ASL
    ASL
    TAY
    LDA #8
    STA TmpB
HexCopy:
    LDA HexFont,X
    STA ScoreBuf,Y
    INX
    INY
    DEC TmpB
    BNE HexCopy
    RTS

; =============================================================================
; OVERSCAN — 30 lines, then the next frame
; =============================================================================
OverscanStart:               ; checkpoint: scanline 229, cycle 6
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; -----------------------------------------------------------------------------
; AdvanceLens — advance 0 -> 1 -> 2 -> 0 and run the lens-entry side effects
; -----------------------------------------------------------------------------
AdvanceLens:
    LDA Lens
    CLC
    ADC #1
    CMP #3
    BCC AdvanceStore
    LDA #0
AdvanceStore:
    STA Lens
LensWrite:                   ; checkpoint: A = the new lens
    NOP
    CMP #LENS_RUN
    BNE AdvanceNotRun
    ; entering RUN: restart the little score counter
    JSR ScoreClear
    LDA #60
    STA ShipX
    LDA #1
    STA ShipDir
    RTS
AdvanceNotRun:
    CMP #LENS_VARS
    BNE AdvanceDone
    ; entering VARS: restart the highlighted byte
    LDA #0
    STA MapIndex
    STA MapTick
    JSR BuildHexScore
AdvanceDone:
    RTS

; =============================================================================
; DATA TABLES
; =============================================================================

; --- the RUN starfield: sixteen rows of three playfield bytes --------------
; (Y + Frame) & $0F selects the row, so the field scrolls one row per frame.
StarPF0:
    !byte $00, $00, $10, $00, $00, $00, $00, $00
    !byte $00, $40, $00, $00, $00, $00, $00, $00
StarPF1:
    !byte $00, $00, $00, $00, $80, $00, $00, $00
    !byte $00, $00, $00, $08, $00, $00, $00, $00
StarPF2:
    !byte $00, $00, $00, $00, $00, $00, $02, $00
    !byte $00, $00, $00, $00, $00, $20, $00, $00

; --- the RUN sprites: six rows each, same shapes as the bB sample ----------
ShipGfx:
    !byte %00111100
    !byte %01111110
    !byte %11111111
    !byte %11111111
    !byte %01111110
    !byte %00111100
EnemyGfx:
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %11111111
    !byte %01111110
    !byte %00111100

; --- the ZONES row bar: one four-pixel chunk, clamped to chunk 19 ----------
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

; --- the 16x8 VARS grid: six 64-entry planes, indexed row*8 + cell_line -----
; Entry i = grid row i>>3, cell line i&7 (row-major).  L = the left eight columns,
; R = the right eight columns.  The playfield writes L in HBLANK and R after
; the left half has been read, so all sixteen columns are distinct.
GridL0:
    !byte $50, $50, $50, $50, $50, $50, $50, $50
    !byte $50, $50, $50, $50, $50, $50, $50, $50
    !byte $50, $50, $50, $50, $50, $00, $00, $00
    !byte $50, $50, $50, $00, $00, $00, $00, $00
    !byte $50, $50, $50, $00, $00, $00, $00, $00
    !byte $50, $50, $50, $00, $00, $00, $00, $00
    !byte $50, $50, $00, $00, $00, $00, $00, $00
    !byte $50, $00, $00, $00, $00, $00, $00, $00
GridL1:
    !byte $AA, $AA, $AA, $AA, $AA, $AA, $AA, $AA
    !byte $AA, $AA, $AA, $AA, $AA, $AA, $AA, $80
    !byte $AA, $AA, $AA, $A0, $00, $00, $00, $00
    !byte $AA, $AA, $AA, $00, $00, $00, $00, $00
    !byte $AA, $AA, $AA, $00, $00, $00, $00, $00
    !byte $AA, $AA, $A0, $00, $00, $00, $00, $00
    !byte $AA, $AA, $00, $00, $00, $00, $00, $00
    !byte $AA, $00, $00, $00, $00, $00, $00, $00
GridL2:
    !byte $05, $05, $05, $05, $05, $05, $05, $05
    !byte $05, $05, $05, $05, $05, $05, $00, $00
    !byte $05, $05, $05, $00, $00, $00, $00, $00
    !byte $05, $05, $05, $00, $00, $00, $00, $00
    !byte $05, $05, $05, $00, $00, $00, $00, $00
    !byte $05, $05, $00, $00, $00, $00, $00, $00
    !byte $05, $05, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $05
GridR0:
    !byte $50, $50, $50, $50, $50, $50, $50, $50
    !byte $50, $50, $50, $50, $50, $50, $00, $00
    !byte $50, $50, $50, $00, $00, $00, $00, $00
    !byte $50, $50, $50, $00, $00, $00, $00, $00
    !byte $50, $50, $50, $00, $00, $00, $00, $00
    !byte $50, $50, $00, $00, $00, $00, $00, $00
    !byte $50, $50, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $50
GridR1:
    !byte $AA, $AA, $AA, $AA, $AA, $AA, $AA, $AA
    !byte $AA, $AA, $AA, $AA, $AA, $A0, $00, $00
    !byte $AA, $AA, $AA, $00, $00, $00, $00, $00
    !byte $AA, $AA, $AA, $00, $00, $00, $00, $00
    !byte $AA, $AA, $AA, $00, $00, $00, $00, $00
    !byte $AA, $AA, $00, $00, $00, $00, $00, $00
    !byte $AA, $AA, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $AA
GridR2:
    !byte $05, $05, $05, $05, $05, $05, $05, $05
    !byte $05, $05, $05, $05, $05, $00, $00, $00
    !byte $05, $05, $05, $00, $00, $00, $00, $00
    !byte $05, $05, $05, $00, $00, $00, $00, $00
    !byte $05, $05, $05, $00, $00, $00, $00, $00
    !byte $05, $05, $00, $00, $00, $00, $00, $00
    !byte $05, $05, $05, $05, $05, $05, $05, $05
    !byte $00, $00, $00, $00, $00, $00, $00, $05

; --- the hex score font: sixteen glyphs, eight rows, bottom-up -------------
; The 4x7 glyph is shifted into bits 7-4 of the 8-pixel score column.
HexFont:
    !byte $00, $60, $90, $90, $90, $90, $90, $60
    !byte $00, $E0, $40, $40, $40, $40, $C0, $40
    !byte $00, $F0, $80, $40, $20, $10, $90, $60
    !byte $00, $E0, $10, $10, $60, $10, $10, $E0
    !byte $00, $20, $20, $F0, $A0, $A0, $60, $20
    !byte $00, $E0, $10, $10, $E0, $80, $80, $F0
    !byte $00, $60, $90, $90, $E0, $80, $80, $60
    !byte $00, $40, $40, $40, $20, $20, $10, $F0
    !byte $00, $60, $90, $90, $60, $90, $90, $60
    !byte $00, $60, $10, $10, $70, $90, $90, $60
    !byte $00, $90, $90, $90, $F0, $90, $90, $60
    !byte $00, $E0, $90, $90, $E0, $90, $90, $E0
    !byte $00, $60, $90, $80, $80, $80, $90, $60
    !byte $00, $E0, $90, $90, $90, $90, $90, $E0
    !byte $00, $F0, $80, $80, $E0, $80, $80, $F0
    !byte $00, $80, $80, $80, $E0, $80, $80, $F0

; =============================================================================
; VECTORS — the 6507 reads RESET at $FFFC and jumps to Reset
; =============================================================================
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
