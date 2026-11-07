; =============================================================================
; LESSON 67: The Wave Lab — generated levels for a hand-written engine
; =============================================================================
; Part 9: The DSL Path
;
; What this program does:
;   A playable shooter whose levels are not written here.  Two level specs
;   (waves-a.txt, waves-b.txt) are validated and lowered by
;   lesson67-generate.py into generated-levels.inc: names, colours, eight
;   20-character backdrop rows, wave timings, positions, speeds and types.
;   This source is the engine: it reads those fixed tables and interprets
;   them.  The 2600 never parses the spec at run time.
;
;   Picture: 16-line label/score band + 1-line transition +
;            64-line generated backdrop + 111-line play area = 192 visible lines.
;     - the band draws the six-character level name (five rows) and the
;       six-digit score (the shared score library's nine-row window).
;     - the backdrop is the level's eight playfield rows, eight lines each.
;     - the play area is a 2-line kernel: 51 logical rows, each drawn twice.
;       Seven setup lines position P0/P1 and prepare row 0; the 102 game
;       lines and the two blank lines at the bottom complete the 111.
;       The play area is picture lines 81-191 (scanlines 118-228).
;       P0 is the player, P1/M0/M1/BALL are the four enemy slots.  Waves
;       spawn at the generated frames; type 0 falls straight, type 1 drifts
;       left/right.  Fire launches the ball upward.  A hit scores; an enemy
;       that reaches the bottom is removed; a wave that arrives with all four
;       slots full is dropped.
;       After the last wave's frame plus 120, the level loops.
;   SELECT switches levels and resets the frame, waves, shot and score.
;
; The DSL (see lesson67-generate.py for the validator):
;   level A | name WAVE-A | bg $02 | pf $1A
;   backdrop <20 chars>   (exactly eight, '.' empty, 'X' solid)
;   wave <index> <frame> <x> <y> <speed> <type>
;   index 0..N-1 in order; frame 0..255; x 0..152; y 64..160; speed 1..3;
;   type 0 straight, 1 drift.  Frames strictly increase, and the last frame
;   plus 120 must fit a byte.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5, OverscanStart 229/6.
;
; Checkpoints (source label, expected Stella state):
;   StartFrame    259/3   the first VSYNC instruction
;   VblankStart     0/5   the first VBLANK instruction
;   BodyStart      37/5   the first visible line
;   OverscanStart 229/6   the first overscan instruction
;   LevelRead     A = 0/1, the active level
;   LevelWrite    A = the new level after a SELECT edge
;   WaveSpawn     A = the wave index; X = the chosen slot offset (0,4,8,12)
;   ScoreWrite    A = the score after a hit
;   FrameRead     A = the frame counter after the increment
;
; RAM map (+clean_start zeroes every byte):
;   $80 Level         0 = A, 1 = B
;   $81 Frame         the level's frame counter, 0..LevelLoop
;   $82 WaveIndex     the next wave to spawn
;   $83 WaveCount     LevelWaveCount[Level]
;   $84 LevelPtrLo    the descriptor or array pointer; P1Start during the play
;   $85 LevelPtrHi    the pointer's high byte
;   $86 PlayerX       P0's left edge, 8..152
;   $87 ShotX         the ball shot's X
;   $88 ShotY         the ball shot's Y (moves up 4 per frame)
;   $89 ShotActive    0 = no shot, 1 = the ball is the shot
;   $8A Score         the score, 0..99
;   $8B PrevSelect    SELECT state last frame
;   $8C NewSelect     SELECT state this frame
;   $8D PrevFire      fire state last frame
;   $8E free
;   $8F-$9E           the four enemy slots, four bytes each:
;                       +0 active, +1 x, +2 y, +3 type/speed
;                       bits 0-1 speed, bit 2 drift direction,
;                       bits 6-7 type (0 straight, 1 drift)
;   $9F Tmp           scratch (NameRow, TmpPF2, PlayRow)
;   $A0-$D7           the shared score library (ScoreDigits, ScoreRow,
;                     ScoreTmp, ScoreBuf).  The play kernel borrows
;                     ScoreDigits[0..2] for M1Row/M0Row/BallRow; the score's
;                     master is the Score byte and RebuildScore rewrites the
;                     digits from it.
;   $D8 ArrayPtrLo    the level-array pointer
;   $D9 ArrayPtrHi    the pointer's high byte (scratch P1Row in the play)
;   $DA SlotOfs       scratch: the chosen enemy-slot byte offset during a spawn
;   $DB-$F1 free
;   $F2-$FF effective stack (the score chain's deepest use is 14 bytes: five
;           return addresses + four PHAs).  No name buffer sits here: the name
;           is drawn from the generated LevelNName ROM table.
;
; The visible kernel reuses library scratch between phases.  The aliases are
; safe because the phases never overlap:
;   $A6 ScoreRow  / NextGRP0 / TmpPF0
;   $A7 ScoreTmp  / NextGRP1 / TmpPF1
;   $9F Tmp       / NameRow / TmpPF2 / PlayRow
;   $84 LevelPtrLo/ P1Start
;   $D8/$D9 ArrayPtr / P1Row
;   $A0-$A2 ScoreDigits / M1Row / M0Row / BallRow
;   $DA SlotOfs / free after the spawn
;
; Build: acme -f plain -o build/lesson67.bin \
;        lessons/part9-dsl-path/67-automatable-patterns/67-automatable-patterns.asm
; Run:   stella build/lesson67.bin
; The ROM is exactly 4,096 bytes; no mapper, no bankswitching.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; CONSTANTS
; =============================================================================
VBLANK_TIMER    = 44          ; 37-line VBLANK (44 ticks)
OVERSCAN_TIMER  = 36          ; 30-line overscan (36 ticks)
POS_BIAS        = 3           ; the Lesson 26 player output delay
BALL_BIAS       = 4           ; the missile/ball output delay

PLAYER_MIN      = 8
PLAYER_MAX      = 152
PLAYER_MOVE     = 4
PLAYER_Y        = 170         ; the player's sprite top
SHOT_SPEED      = 4
SHOT_TOP        = 84          ; the play area's top; a shot above this is gone
ENEMY_BOTTOM    = 184         ; an enemy whose top reaches here is gone

PLAY_START      = 84          ; the object-row origin (the first game line is 88)
PLAY_ROWS       = 51          ; 102 game lines / 2 lines per logical row
PLAYER_ROW      = 43          ; (PLAYER_Y - PLAY_START) / 2

SLOT_COUNT      = 4
SLOT_SIZE       = 4
SLOT0_ACTIVE    = $8F
SLOT0_X         = $90
SLOT0_Y         = $91
SLOT0_TYPE      = $92
SLOT1_ACTIVE    = $93
SLOT1_X         = $94
SLOT1_Y         = $95
SLOT2_ACTIVE    = $97
SLOT2_X         = $98
SLOT2_Y         = $99
SLOT3_ACTIVE    = $9B
SLOT3_X         = $9C
SLOT3_Y         = $9D

DIR_BIT         = $04         ; bit 2: 1 = drift right, 0 = drift left

C_WHITE         = $0E
C_PLAYER        = $C8         ; green
C_ENEMY         = $1A         ; gold

; =============================================================================
; RAM
; =============================================================================
Level       = $80
Frame       = $81
WaveIndex   = $82
WaveCount   = $83
LevelPtr    = $84             ; two bytes: $84/$85
PlayerX     = $86
ShotX       = $87
ShotY       = $88
ShotActive  = $89
Score       = $8A
PrevSelect  = $8B
NewSelect   = $8C
PrevFire    = $8D
Tmp         = $9F

ArrayPtr    = $D8             ; two bytes: $D8/$D9
SlotOfs     = $DA             ; scratch: the chosen slot offset during a spawn

; The play kernel aliases.  The header explains why the phases cannot overlap.
P1Start     = LevelPtr        ; $84
NextGRP0    = $A6             ; ScoreRow
NextGRP1    = $A7             ; ScoreTmp
TmpPF0      = $A6
TmpPF1      = $A7
TmpPF2      = $9F
NameRow     = $9F
PlayRow     = $9F
P1Row       = $D9

; The three one-row objects' logical rows are computed in VBLANK and kept
; in the score library's ScoreDigits bytes.  ScoreDigits is not the score's
; master (the Score byte is); RebuildScore starts with ScoreClear, which
; rewrites all six digits, so the play kernel may borrow three of them.
M1Row       = $A0
M0Row       = $A1
BallRow     = $A2

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreSetup positions P0/P1 at 56/64, sets three-copy close mode and VDEL,
; and strobes the HMOVE.  ScoreDraw paints the six 8-pixel columns.
; ScoreClear/ScoreSetDigit rebuild the six-digit window.  The library owns
; $A0-$D7.  It is sourced after the ROM origin because it contains code.
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
    STA ENAM0
    STA ENAM1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA VDELP0
    STA VDELP1
    LDA #$10                ; repeat playfield, 2-pixel ball
    STA CTRLPF
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1

    ; --- the initial level state -------------------------------------------
    LDA #0
    STA Level
    STA PrevSelect
    STA NewSelect
    STA PrevFire
    STA WaveIndex
    STA ShotActive
    STA Score
    LDA #$FF
    STA Frame               ; the first VBLANK increment makes frame 0
    LDA #80
    STA PlayerX
    LDA #0
    STA ShotX
    STA ShotY
    ; clear the four enemy slots
    LDX #0
ResetSlots:
    LDA #0
    STA SLOT0_ACTIVE,X
    INX
    INX
    INX
    INX
    CPX #16
    BNE ResetSlots

    JSR SetLevelData
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
; SELECT — one level switch per fresh press
; -----------------------------------------------------------------------------
    LDA SWCHB
    AND #$02
    EOR #$02                 ; 1 = SELECT pressed
    STA NewSelect
    AND PrevSelect
    EOR NewSelect            ; new & ~previous: a fresh press
    BEQ NoLevelSwitch

    ; Switch levels and reset the level state.  Frame is set to $FF so the
    ; increment below makes frame 0 and the first wave (if frame 0) spawns.
    LDA Level
    EOR #$01                 ; A -> B, B -> A
    STA Level
LevelWrite:                  ; checkpoint: A = the new level
    NOP
    LDA #$FF
    STA Frame
    LDA #0
    STA WaveIndex
    STA ShotActive
    STA Score
    LDX #0
SwitchSlots:
    LDA #0
    STA SLOT0_ACTIVE,X
    INX
    INX
    INX
    INX
    CPX #16
    BNE SwitchSlots
    JSR SetLevelData
    JSR ScoreClear

NoLevelSwitch:
    LDA NewSelect
    STA PrevSelect

; -----------------------------------------------------------------------------
; FRAME COUNTER AND LEVEL LOOP
; -----------------------------------------------------------------------------
    INC Frame
    LDA Frame
FrameRead:                   ; checkpoint: A = the frame counter
    NOP

    LDA Level
LevelRead:                   ; checkpoint: A = the active level
    NOP

    ; After the last wave plus 120 frames, restart the wave clock.  The score
    ; and the level itself continue; only the waves reset.
    LDX Level
    LDA LevelLoop,X
    CMP Frame
    BNE NoLoop
    LDA #0
    STA Frame
    STA WaveIndex
    STA ShotActive
    LDX #0
LoopSlots:
    LDA #0
    STA SLOT0_ACTIVE,X
    INX
    INX
    INX
    INX
    CPX #16
    BNE LoopSlots
NoLoop:

; -----------------------------------------------------------------------------
; GAME LOGIC
; -----------------------------------------------------------------------------
    JSR MovePlayer
    JSR HandleFire
    JSR UpdateEnemies
    JSR SpawnWaves
    JSR UpdateShot
    JSR SetP1Start           ; the play kernel's P1 start row
    JSR SetObjectRows        ; the three one-row objects' logical rows

; -----------------------------------------------------------------------------
; COLOURS AND CLEARED OBJECTS FOR THE BAND / BACKDROP
; -----------------------------------------------------------------------------
    LDX Level
    LDA LevelBG,X
    STA COLUBK
    LDA LevelPF,X
    STA COLUPF
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1

    LDA #0
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2

; -----------------------------------------------------------------------------
; POSITION THE BALL, M0 AND M1 FOR THE SCORE LIBRARY'S HMOVE
; -----------------------------------------------------------------------------
    ; ball: the shot when active, otherwise the slot-3 enemy
    LDA ShotActive
    BEQ BallSlotPos
    LDA ShotX
    JMP BallPosition
BallSlotPos:
    LDA SLOT3_ACTIVE
    BEQ BallDefault
    LDA SLOT3_X
    JMP BallPosition
BallDefault:
    LDA #80
BallPosition:
    CLC
    ADC #(BALL_BIAS)
    SEC
    JSR SetCoarseBL

    ; missile 0: slot 1
    LDA SLOT1_ACTIVE
    BEQ M0Default
    LDA SLOT1_X
    JMP M0Position
M0Default:
    LDA #80
M0Position:
    CLC
    ADC #(BALL_BIAS)
    SEC
    JSR SetCoarseM0

    ; missile 1: slot 2
    LDA SLOT2_ACTIVE
    BEQ M1Default
    LDA SLOT2_X
    JMP M1Position
M1Default:
    LDA #80
M1Position:
    CLC
    ADC #(BALL_BIAS)
    SEC
    JSR SetCoarseM1

    ; The score library positions P0 and P1 at 56/64 and applies one HMOVE
    ; to all five fine-motion registers.
    JSR ScoreSetup

VblankWait:
    +wait_timer
    LDA #$00
    STA VBLANK               ; picture on

; =============================================================================
; PLAY KERNEL — prepare one logical row (2 scanlines)
; =============================================================================
; The 2-line kernel does the work during the second (hold) line of the
; previous row.  The caller stores the prepared bytes at the start of the
; next line, so the whole 76-cycle hold line is available for this routine.
;
; P0 is the player: its eight sprite rows are fixed at the last eight play
; rows, so its table index is simply PlayRow - PLAYER_ROW.  P1 is slot 0 and
; uses a start row plus an eight-row state byte; the missiles and ball are
; one logical row each, and their rows are precomputed in VBLANK.  On return
; A = the ball enable, X = the M1 enable, Y = the M0 enable.  Slot Y values
; are picture rows: logical row = (Y - PLAY_START) / 2.
!macro PrepareRow {
    ; --- P0: the player at the fixed PLAYER_ROW ---------------------------
    LDA #0
    STA NextGRP0
    LDA PlayRow
    CMP #PLAYER_ROW
    BCC .P0Done
    SEC
    SBC #PLAYER_ROW
    TAY
    LDA PlayerShape,Y
    STA NextGRP0
.P0Done:

    ; --- P1: slot 0, state-driven ----------------------------------------
    LDA PlayRow
    CMP P1Start
    BNE .P1NoStart
    LDA #0
    STA P1Row
.P1NoStart:
    LDA P1Row
    CMP #8
    BCS .P1Off
    TAY
    LDA EnemyShape,Y
    STA NextGRP1
    INC P1Row
    JMP .P1Done
.P1Off:
    LDA #0
    STA NextGRP1
.P1Done:

    ; --- M1, M0 and the ball: one precomputed row each --------------------
    LDX #0
    LDA M1Row
    CMP PlayRow
    BNE .M1Done
    LDX #2
.M1Done:

    LDY #0
    LDA M0Row
    CMP PlayRow
    BNE .M0Done
    LDY #2
.M0Done:

    LDA BallRow
    CMP PlayRow
    BNE .BallOff
    LDA #2
    JMP .Done
.BallOff:
    LDA #0
.Done:
}

; =============================================================================
; THE BACKDROP ROW MACRO
; =============================================================================
; Each call displays one generated playfield row for eight scanlines.  The
; three bytes are preloaded during the previous line, then stored at the
; start of the row's first line; seven WSYNCs hold them for the rest of the
; row.  Row 0's preload runs on line 53 (the one-line transition after the
; band), its first store is 54 (the first backdrop line), and the last row
; ends on 117.  The caller must have set ArrayPtr to the 24-byte backdrop.
!macro BackdropRow .offset {
    LDY #.offset
    LDA (ArrayPtr),Y
    STA TmpPF0
    INY
    LDA (ArrayPtr),Y
    STA TmpPF1
    INY
    LDA (ArrayPtr),Y
    STA TmpPF2
    STA WSYNC
    LDA TmpPF0
    STA PF0
    LDA TmpPF1
    STA PF1
    LDA TmpPF2
    STA PF2
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
}

; =============================================================================
; NAME ROWS — five rows of the six-column name, read straight from the ROM
; =============================================================================
; The generator lowers the level name into a 30-byte column-major table
; (six columns x five rows) in the generated include.  This macro draws one
; level's table; the dispatch below selects Level0Name or Level1Name.  The
; name never lives in RAM, so the score hit's deepest call chain cannot touch
; it.  The six columns are P0/P1 in three-copy close mode; ScoreSetup (in
; VBLANK) has positioned them at 56/64 and turned VDEL on, and this routine
; leaves NUSIZ/VDEL on for ScoreDraw.
!macro NameRows .base {
    LDA #0
    STA NameRow
.line:
    LDY NameRow
    LDA .base+0,Y
    STA WSYNC               ; line 0 is the setup/blank line
    STA GRP0                ; column 0
    LDA .base+5,Y
    STA GRP1                ; column 1
    LDA .base+10,Y
    STA GRP0                ; column 2
    LDA .base+15,Y
    STA ScoreTmp            ; hold column 3 while Y is needed
    LDX .base+20,Y          ; column 4 (a direct load saves the LDA/TAX pair)
    LDA .base+25,Y
    LDY ScoreTmp
    NOP                     ; the ScoreDraw timing pad
    CPX NameRow             ; timing only; flags discarded
    STY GRP1                ; column 3
    STX GRP0                ; column 4
    STA GRP1                ; column 5
    STA GRP0                ; commit column 5 through the cross-latch
    LDX NameRow
    INX
    STX NameRow
    CPX #5
    BNE .line
    LDA #0
    STA GRP0
    STA GRP1
}

; =============================================================================
; VISIBLE PICTURE — band, backdrop, play area
; =============================================================================
BodyStart:                   ; checkpoint: scanline 37, visible line 0
    JSR NameDraw             ; rows 1-5; row 0 is the setup line
    LDA #0
    STA GRP0
    STA GRP1
    STA WSYNC                ; row 6
    JSR ScoreDraw            ; rows 7-15 (setup + eight score rows)

    ; The band is over; the game objects get their own colours.  The score
    ; and name pixels are already drawn, so changing the player colours here
    ; affects only the backdrop and play area.
    LDA #$10                ; one player copy, 2-pixel missiles
    STA NUSIZ0              ; ScoreDraw leaves the three-copy mode set
    STA NUSIZ1
    LDA #C_PLAYER
    STA COLUP0
    LDA #C_ENEMY
    STA COLUP1

; -----------------------------------------------------------------------------
; THE GENERATED BACKDROP — eight playfield rows, eight lines each
; -----------------------------------------------------------------------------
    ; Load the level's backdrop pointer (descriptor offset 10).
    LDY #10
    JSR LoadLevelArray
    LDA LevelPtr
    STA ArrayPtr
    LDA LevelPtr+1
    STA ArrayPtr+1

    +BackdropRow 0
    +BackdropRow 3
    +BackdropRow 6
    +BackdropRow 9
    +BackdropRow 12
    +BackdropRow 15
    +BackdropRow 18
    +BackdropRow 21

; -----------------------------------------------------------------------------
; THE PLAY AREA — seven setup lines, then 51 logical rows (102 lines)
; -----------------------------------------------------------------------------
; The play area is picture lines 81-191 (scanlines 118-228), 111 lines:
;   118  clear PF, HMCLR, P0's WSYNC (the P0 divide runs on 119)
;   119  P0 divide
;   120  P1's WSYNC (the P1 divide runs on 121)
;   121  P1 divide
;   122  HMOVE + play-state init
;   123  the HMOVE notch; prepare row 0
;   125  store row 0 (the PlayLoop checkpoint)
;   127  the first loop-body store (row 1); 51 logical rows (102 game lines)
;   227-228  two blank lines; PlayDone has four WSYNCs; overscan 229/6
PlayStart:
    STA WSYNC
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    STA HMCLR                ; the VBLANK fine offsets are already applied
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    SEC                      ; the positioner's divide starts with carry set
    JSR SetCoarseP0          ; its WSYNC ends 118; divide on 119
    STA WSYNC                ; ends 119
    LDA SLOT0_ACTIVE
    BEQ P1Default
    LDA SLOT0_X
    JMP P1Position
P1Default:
    LDA #80
P1Position:
    CLC
    ADC #POS_BIAS
    SEC
    JSR SetCoarseP1          ; its WSYNC ends 120; divide on 121
    STA WSYNC                ; ends 121
PlayHmove:
    STA HMOVE                ; line 122 HBLANK: blanks the next line (123)
    LDA #0
    STA PlayRow
    LDA #$FF
    STA P1Row
    STA WSYNC                ; ends 122
    +PrepareRow              ; row 0 on 123
    STA WSYNC                ; ends the prepare line

    STX ENAM1
    STY ENAM0
    STA ENABL
    LDA NextGRP0
    STA GRP0
    LDA NextGRP1
    STA GRP1
    INC PlayRow
    LDA PlayRow
    CMP #PLAY_ROWS
    BEQ PlayDone

PlayLoop:
    ; Row PlayRow is prepared during the remainder of the store line and
    ; the following hold line; its stores land at the next line's start.
    +PrepareRow
    STA WSYNC                ; ends the hold line
    STX ENAM1
    STY ENAM0
    STA ENABL
    LDA NextGRP0
    STA GRP0
    LDA NextGRP1
    STA GRP1
    INC PlayRow
    LDA PlayRow
    CMP #PLAY_ROWS
    BEQ PlayDone
    JMP PlayLoop

PlayDone:
    ; Four WSYNCs end the last row's store line, its hold line, and the two
    ; blank lines after the play area; the picture reaches 228 and the JMP
    ; lands at 229/6.
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    BIT Frame
    JMP OverscanStart

; =============================================================================
; OVERSCAN — 30 lines, then the next frame
; =============================================================================
OverscanStart:               ; checkpoint: scanline 229, cycle 6
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; NAME DRAW — select the level's 30-byte ROM name table
; =============================================================================
; The name is read from the generated table, not from a RAM buffer.  The band
; lines 0-6 draw the name; ScoreDraw then paints lines 7-15 from ScoreBuf.
NameDraw:
    LDA Level
    BEQ NameDraw0
    +NameRows Level1Name
    RTS
NameDraw0:
    +NameRows Level0Name
    RTS

; =============================================================================
; PLAYER AND FIRE
; =============================================================================
MovePlayer:
    ; left
    LDA SWCHA
    AND #$40                ; bit 6 = left, 0 = pressed
    BNE MoveNotLeft
    LDA PlayerX
    SEC
    SBC #PLAYER_MOVE
    CMP #PLAYER_MIN
    BCS MoveStoreLeft
    LDA #PLAYER_MIN
MoveStoreLeft:
    STA PlayerX
MoveNotLeft:
    ; right
    LDA SWCHA
    AND #$80                ; bit 7 = right, 0 = pressed
    BNE MoveNotRight
    LDA PlayerX
    CLC
    ADC #PLAYER_MOVE
    CMP #(PLAYER_MAX + 1)
    BCC MoveStoreRight
    LDA #PLAYER_MAX
MoveStoreRight:
    STA PlayerX
MoveNotRight:
    RTS

; -----------------------------------------------------------------------------
; HandleFire — one shot at a time; a press launches the ball from the player
; -----------------------------------------------------------------------------
HandleFire:
    LDA INPT4
    AND #$80
    EOR #$80                ; 1 = fire pressed
    STA Tmp
    AND PrevFire
    EOR Tmp                 ; new & ~previous
    BEQ NoFirePress
    LDA ShotActive
    BNE NoFirePress
    LDA #1
    STA ShotActive
    LDA PlayerX
    CLC
    ADC #4
    STA ShotX
    LDA #(PLAYER_Y - 1)
    STA ShotY
    LDA #0
    STA SLOT3_ACTIVE        ; the ball becomes the shot
NoFirePress:
    LDA Tmp
    STA PrevFire
    RTS

; =============================================================================
; ENEMIES — the four-slot table update
; =============================================================================
; X counts the slot byte offset: 0, 4, 8, 12.  Type 0 falls straight; type 1
; adds a one-pixel drift, bouncing at PLAYER_MIN/PLAYER_MAX.  The main lesson
; rejects type 2, so a type-2 byte would behave as straight here; the zigzag
; exercise adds the third branch.
UpdateEnemies:
    LDX #0
EnemyLoop:
    LDA SLOT0_ACTIVE,X
    BEQ EnemyNext
    ; y += speed
    LDA SLOT0_TYPE,X
    AND #$03
    STA Tmp
    LDA SLOT0_Y,X
    CLC
    ADC Tmp
    STA SLOT0_Y,X
    CMP #ENEMY_BOTTOM
    BCS EnemyKill
    ; type 1 drifts; type 0 (and the unhandled type) falls straight
    LDA SLOT0_TYPE,X
    AND #$C0
    CMP #$40
    BEQ EnemyDrift
    JMP EnemyNext
EnemyDrift:
    LDA SLOT0_TYPE,X
    AND #DIR_BIT
    BEQ DriftLeft
    ; right
    LDA SLOT0_X,X
    CLC
    ADC #1
    CMP #(PLAYER_MAX + 1)
    BCS DriftRightClamp
    STA SLOT0_X,X
    JMP EnemyNext
DriftRightClamp:
    LDA #PLAYER_MAX
    STA SLOT0_X,X
    LDA SLOT0_TYPE,X
    EOR #DIR_BIT
    STA SLOT0_TYPE,X
    JMP EnemyNext
DriftLeft:
    LDA SLOT0_X,X
    SEC
    SBC #1
    CMP #PLAYER_MIN
    BCC DriftLeftClamp
    STA SLOT0_X,X
    JMP EnemyNext
DriftLeftClamp:
    LDA #PLAYER_MIN
    STA SLOT0_X,X
    LDA SLOT0_TYPE,X
    EOR #DIR_BIT
    STA SLOT0_TYPE,X
    JMP EnemyNext
EnemyKill:
    LDA #0
    STA SLOT0_ACTIVE,X
EnemyNext:
    INX
    INX
    INX
    INX
    CPX #(SLOT_COUNT * SLOT_SIZE)
    BNE EnemyLoop
    RTS

; =============================================================================
; WAVE SPAWN — read the generated arrays through the level descriptor
; =============================================================================
; The first inactive slot wins: 0 = P1, 1 = M0, 2 = M1, 3 = the ball.  If all
; four slots are active the wave is dropped and its index consumed, so the
; four objects always represent four lives.  A wave that lands in slot 3
; while a shot is in flight is stored but not shown: the ball displays the
; shot until the shot ends.
SpawnWaves:
    LDA WaveIndex
    CMP WaveCount
    BCS SpawnDone
    LDY #0                   ; descriptor offset 0: WaveFrame
    JSR LoadLevelArray
    LDY WaveIndex
    LDA (LevelPtr),Y
    CMP Frame
    BNE SpawnDone

    ; Find the first inactive slot.  If all four are active, drop this wave
    ; and consume its index: a busy lab loses the spawn rather than
    ; overwriting an enemy, so the four objects always represent four lives.
    LDX #0
FindSlot:
    LDA SLOT0_ACTIVE,X
    BEQ SlotFound
    INX
    INX
    INX
    INX
    CPX #(SLOT_COUNT * SLOT_SIZE)
    BNE FindSlot
    ; all four occupied: consume the wave
    INC WaveIndex
    RTS

SlotFound:
    STX SlotOfs              ; the chosen slot byte offset, 0/4/8/12
    LDA #1
    STA SLOT0_ACTIVE,X

    ; x = WaveX
    LDY #2
    JSR LoadLevelArray
    LDY WaveIndex
    LDA (LevelPtr),Y
    LDX SlotOfs
    STA SLOT0_X,X

    ; y = WaveY
    LDY #4
    JSR LoadLevelArray
    LDY WaveIndex
    LDA (LevelPtr),Y
    LDX SlotOfs
    STA SLOT0_Y,X

    ; type/speed = (type << 6) | speed | direction-right
    LDY #6
    JSR LoadLevelArray
    LDY WaveIndex
    LDA (LevelPtr),Y
    STA Tmp                  ; speed
    LDY #8
    JSR LoadLevelArray
    LDY WaveIndex
    LDA (LevelPtr),Y
    ASL
    ASL
    ASL
    ASL
    ASL
    ASL                      ; type into bits 6-7
    ORA Tmp
    ORA #DIR_BIT
    LDX SlotOfs
    STA SLOT0_TYPE,X

    LDA WaveIndex
WaveSpawn:                   ; checkpoint: A = the wave index
    NOP
    INC WaveIndex
SpawnDone:
    RTS

; =============================================================================
; SHOT AND COLLISIONS
; =============================================================================
UpdateShot:
    LDA ShotActive
    BEQ ShotDone
    LDA ShotY
    SEC
    SBC #SHOT_SPEED
    CMP #SHOT_TOP
    BCC ShotGone
    STA ShotY

    ; Test slots 0-2.  Slot 3 is the ball's other role; while the shot owns
    ; the ball, a queued slot-3 enemy is not on screen and cannot be hit.
    LDX #0
ShotCheckLoop:
    LDA SLOT0_ACTIVE,X
    BEQ ShotNextSlot
    ; |ShotX - slot X| <= 6
    LDA ShotX
    SEC
    SBC SLOT0_X,X
    BCS ShotDxPos
    EOR #$FF
    ADC #1
ShotDxPos:
    CMP #7
    BCS ShotNextSlot
    ; |ShotY - slot Y| <= 8
    LDA ShotY
    SEC
    SBC SLOT0_Y,X
    BCS ShotDyPos
    EOR #$FF
    ADC #1
ShotDyPos:
    CMP #9
    BCS ShotNextSlot
    ; hit
    LDA #0
    STA SLOT0_ACTIVE,X
    STA ShotActive
    JSR AddScore
    RTS
ShotNextSlot:
    INX
    INX
    INX
    INX
    CPX #(3 * SLOT_SIZE)    ; slots 0, 1, 2 only
    BNE ShotCheckLoop
ShotDone:
    RTS
ShotGone:
    LDA #0
    STA ShotActive
    RTS

; -----------------------------------------------------------------------------
; AddScore — cap at 99, rebuild the six-digit window, then checkpoint
; -----------------------------------------------------------------------------
AddScore:
    LDA Score
    CMP #99
    BCS AddScoreStore
    INC Score
AddScoreStore:
    LDA Score
ScoreWrite:                  ; checkpoint: A = the score
    NOP
    JSR RebuildScore
    RTS

; RebuildScore — ScoreClear then the tens and ones digits in the last two
; columns.  The window reads 000042 for a score of 42; the value is 0-99.
RebuildScore:
    JSR ScoreClear
    LDA Score
    LDX #0
ScoreTens:
    CMP #10
    BCC ScoreTensDone
    SBC #10
    INX
    JMP ScoreTens
ScoreTensDone:
    STA Tmp                  ; ones
    LDA #4                   ; position 4 = tens, X = tens digit
    JSR ScoreSetDigit
    LDA #5                   ; position 5 = ones
    LDX Tmp
    JSR ScoreSetDigit
    RTS

; =============================================================================
; LEVEL DATA
; =============================================================================
; SetLevelData: LevelPtr = LevelDescLo/Hi[Level]; WaveCount = the level's
; wave count.  LoadLevelArray reads one of the descriptor's six pointers.
SetLevelData:
    LDX Level
    LDA LevelDescLo,X
    STA LevelPtr
    LDA LevelDescHi,X
    STA LevelPtr+1
    LDA LevelWaveCount,X
    STA WaveCount
    RTS

; SetP1Start — P1Start = (Slot0Y - PLAY_START) / 2, or $FF when the slot is
; inactive or still above the play area.  This runs in VBLANK, after the
; wave loads have finished with the $84 scratch byte.
SetP1Start:
    LDA #$FF
    STA P1Start
    LDA SLOT0_ACTIVE
    BEQ SetP1Done
    LDA SLOT0_Y
    SEC
    SBC #PLAY_START
    BCC SetP1Done
    LSR
    STA P1Start
SetP1Done:
    RTS

; -----------------------------------------------------------------------------
; SetObjectRows — precompute the three one-row objects' logical rows.
; $FF means "not on any play row".  The ball uses the shot's Y when the shot
; is active, otherwise the slot-3 enemy's Y.
; -----------------------------------------------------------------------------
SetObjectRows:
    LDA #$FF
    STA M1Row
    LDA SLOT2_ACTIVE
    BEQ ObjM1Done
    LDA SLOT2_Y
    SEC
    SBC #PLAY_START
    BCC ObjM1Done
    LSR
    STA M1Row
ObjM1Done:
    LDA #$FF
    STA M0Row
    LDA SLOT1_ACTIVE
    BEQ ObjM0Done
    LDA SLOT1_Y
    SEC
    SBC #PLAY_START
    BCC ObjM0Done
    LSR
    STA M0Row
ObjM0Done:
    LDA #$FF
    STA BallRow
    LDA ShotActive
    BEQ ObjBallSlot
    LDA ShotY
    JMP ObjBallRow
ObjBallSlot:
    LDA SLOT3_ACTIVE
    BEQ ObjBallDone
    LDA SLOT3_Y
ObjBallRow:
    SEC
    SBC #PLAY_START
    BCC ObjBallDone
    LSR
    STA BallRow
ObjBallDone:
    RTS

; LoadLevelArray: Y = descriptor offset (0,2,4,6,8,10).  On return LevelPtr
; points at the requested array and Y is one past the pointer's high byte.
LoadLevelArray:
    LDX Level
    LDA LevelDescLo,X
    STA ArrayPtr
    LDA LevelDescHi,X
    STA ArrayPtr+1
    LDA (ArrayPtr),Y
    STA LevelPtr
    INY
    LDA (ArrayPtr),Y
    STA LevelPtr+1
    RTS

; =============================================================================
; POSITIONING — the Lesson 26 divide-by-15 routines
; =============================================================================
; The caller sets the carry before the JSR; the routine's WSYNC starts the
; line and the divide begins on the following line.  That is why each
; positioner costs two visible lines.  The carry is preserved across WSYNC.
SetCoarseP0:
    STA WSYNC
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

SetCoarseM0:
    STA WSYNC
DivM0:
    SBC #15
    BCS DivM0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMM0
    STA RESM0
    RTS

SetCoarseM1:
    STA WSYNC
DivM1:
    SBC #15
    BCS DivM1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMM1
    STA RESM1
    RTS

SetCoarseBL:
    STA WSYNC
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
; DATA — the sprite shapes
; =============================================================================
; PlayerShape: eight rows, top-down; P0 is 8 pixels wide.
PlayerShape:
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %11111111
    !byte %11111111
    !byte %01111110
    !byte %00111100
    !byte %00011000

; EnemyShape: eight rows, top-down.
EnemyShape:
    !byte %00111100
    !byte %01111110
    !byte %11011011
    !byte %11111111
    !byte %11111111
    !byte %11011011
    !byte %01111110
    !byte %00111100

; =============================================================================
; THE GENERATED LEVEL TABLES
; =============================================================================
; generated-levels.inc is produced by lesson67-generate.py from waves-a.txt
; and waves-b.txt.  It is data only; the engine above interprets it.
    !source "lessons/part9-dsl-path/67-automatable-patterns/generated-levels.inc"

; =============================================================================
; VECTORS — the 6507 reads RESET at $FFFC and jumps to Reset
; =============================================================================
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
