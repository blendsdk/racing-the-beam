; =============================================================================
; LESSON 42: Difficulty and Progression — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; What this program does:
;   "the difficulty ladder": the console's two difficulty switches choose how
;   the game starts, and a 15-entry speed table keeps raising the pressure as
;   the player survives.  The left switch picks the starting level (1 on
;   novice, 5 on expert); the right switch picks the enemy's width (8 pixels
;   on novice, 16 pixels on expert, NUSIZ1=5).  A level bar, three life
;   cells per half, and a two-cell switch indicator per half are the visible
;   state.
;
; The screen (192 visible lines, CTRLPF=$01 so the playfield is mirrored):
;   visible 0-7     the level bar: Level chunks per half, gold ($1A)
;   visible 8-15    the life cells: three red ($42) cells per half, each
;                   2 chunks, at X=8, 16, and 24; one cell per remaining life
;   visible 16-23   the switch indicator: two white ($0E) 1-chunk cells per
;                   half; the left cell is lit when the left switch is on
;                   expert (SWCHB bit 6=1), the right cell when the right
;                   switch is on expert (bit 7=1)
;   visible 24-139  the play area: the gold edge walls (PF0=$F0 mirrored)
;   visible 140-155 P0 (16 rows, red $42) and P1 (16 rows, green $C8);
;                   both share these scanlines so CXPPMM bit 7 can set
;   visible 156-191 the play area's bottom wall section
;   The zones total 8+8+8+116+16+36 = 192 lines; OverscanStart is scanline
;   229.
;
; The game:
;   P0 starts at X=80 and moves left/right with the joystick, clamped to
;   X=24..136.  P1 starts at X=24, direction right, and bounces between
;   X=24 and X=136 at Speed = SpeedTable[Level] (1..4 pixels per frame).
;   A P0-P1 contact (CXPPMM bit 7, read in VBLANK and edge-detected) costs a
;   life, beeps, respawns P1 on the opposite side of P0, and arms 60 frames
;   of invulnerability (P1 blinks during it).  At 0 lives the play area turns
;   red, Invuln and FlashTimer are cleared, the play update freezes, and fire
;   starts a new game.
;
;   Every 300 survived play frames the level-up path runs.  A level that
;   actually changes flashes the bar for 30 frames and plays a beep; at the
;   cap the clock reloads but the flash and beep are skipped.  The level
;   timer is 16 bits: LevelTimerLo/LevelTimerHi hold 300 = $012C.
;
; The switches (SWCHB, $0282):
;   bit 6  P0 difficulty (the left switch): 0=novice/B, 1=expert/A
;   bit 7  P1 difficulty (the right switch): 0=novice/B, 1=expert/A
;   Older register tables -- including this course's pre-fix comment -- had
;   the polarity inverted; include/vcs.asm now states 0=B/novice/1=A/expert,
;   and Stella's -ld/-rd command line options agree: -ld A gives bit 6=1.
;   The starting level is sampled when a game starts: novice -> 1,
;   expert -> 5.  The width is sampled every frame, so flipping the right
;   switch changes NUSIZ1 immediately: novice -> 0 (8 px), expert -> 5
;   (double width, 16 px).
;
; The auto-demo (so the captures are deterministic):
;   With no joystick input P0 stands still at X=80, so the bouncing P1
;   reaches it on its own.  The first drawn contact is at frame 49 and the
;   VBLANK read charges it at frame 50; the 60-frame invulnerability lets
;   P1 pass through P0 before the latch can count again, so the next contact
;   waits for the far-wall round trip.  The passive run therefore survives
;   long enough to reach level 2 at frame 301 and loses its last life at
;   frame 374.  The red game-over field then stays until fire is pressed;
;   fire starts a new game at the switch-selected starting level (level 1 on
;   novice, level 5 on expert).
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), ReadSWCHB (A = SWCHB),
;   NUSIZWrite (A = NUSIZ1), ReadCX (A = CXPPMM), CXClear (the strobe),
;   SpeedWrite (A = speed), LevelUp (A = level), LifeStep (A = lives),
;   LifeInit (A = 3 at a fresh game),
;   BodyStart (37), HmoveApply/HmoveDone (one per frame), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson42.bin \
;        lessons/part6-game-dev/42-difficulty/42-difficulty.asm
; Run:   stella build/lesson42.bin     (click the screen to hear the beep)
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

LEVEL_MAX      = 15
LEVEL_FRAMES_LO = $2C    ; 300 frames = $012C
LEVEL_FRAMES_HI = $01
INVULN_FRAMES  = 60
FLASH_FRAMES   = 30

START_NOVICE   = 1       ; left switch = novice/B (bit 6 = 0)
START_EXPERT   = 5       ; left switch = expert/A (bit 6 = 1)
ENEMY_MIN_X    = 24
ENEMY_MAX_X    = 136
PLAYER_MIN_X   = 24
PLAYER_MAX_X   = 136

BEEP_FRAMES    = 8
HIT_PITCH      = $08     ; AUDF 8 on AUDC $0C: a short, bright hit
LEVEL_PITCH    = $0C     ; a slightly lower note for a level-up
BEEP_PITCH_DEFAULT = HIT_PITCH

C_RED          = $42
C_GOLD         = $1A
C_GREEN        = $C8
C_WHITE        = $0E
C_BG           = $02

; --- Lesson variables (RAM $80-$9C; +clean_start zeroes them) ---
Level        = $80   ; 1..15, the current level
LevelTimerLo = $81   ; the 16-bit survival clock, low byte (300 = $012C)
LevelTimerHi = $82   ; the survival clock, high byte
Lives        = $83   ; 3 at the start, 0 = game over
EnemyX       = $84   ; P1's left edge, 24..136
EnemyDir     = $85   ; 1 = moving right, 0 = moving left
PlayerX      = $86   ; P0's left edge, 24..136
Switches     = $87   ; the last SWCHB read
Invuln       = $88   ; frames of invulnerability remaining
FlashTimer   = $89   ; frames of level-bar flashing remaining
GameOver     = $8A   ; 1 = the red frozen field; fire restarts
Frame        = $8B   ; free-running 8-bit frame counter (blink uses bit 2)
PrevFire     = $8C   ; fire state last frame (1 = pressed)
NewFire      = $8D   ; this frame's fire 0 -> 1 edge
Speed        = $8E   ; SpeedTable[Level], 1..4
NeedStart    = $8F   ; 1 = the next VBLANK must start a game
StartLevel   = $90   ; the switch-selected starting level
CollBit      = $91   ; this frame's CXPPMM bit 7 and then its 0 -> 1 edge
PrevColl     = $92   ; last frame's CXPPMM bit 7
LevelPF0     = $93   ; the level bar's three playfield bytes
LevelPF1     = $94
LevelPF2     = $95
LifePF0      = $96   ; the life cells' two playfield bytes
LifePF1      = $97
SwitchPF0    = $98   ; the switch indicator's two playfield bytes
SwitchPF1    = $99
EnemyDraw    = $9A   ; $FF, or 0 during the invulnerability blink's off phase
BeepTimer    = $9B   ; frames of beep remaining
BeepPitch    = $9C   ; AUDF for the beep
;
; The shared score/random libraries are not used, so $9D-$D7 is free.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the first game starts in the first VBLANK, after SWCHB is read --------
; Reset only marks the game as pending; StartGame samples the left switch,
; so the switch's state at power-on is the state that starts the game.
    LDA #1
    STA NeedStart
    LDA #BEEP_PITCH_DEFAULT
    STA BeepPitch

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
; 1. THE FRAME COUNTER AND THE BEEP'S CLOCK
; -----------------------------------------------------------------------------
    INC Frame
    LDA BeepTimer
    BEQ BeepDone
    DEC BeepTimer
    BNE BeepDone
    LDA #$00
    STA AUDV0
BeepDone:

; -----------------------------------------------------------------------------
; 2. READ THE CONSOLE SWITCHES
; -----------------------------------------------------------------------------
; SWCHB reports the difficulty switches as 0 = B/novice and 1 = A/expert:
; bit 6 is the left (P0) switch and bit 7 the right (P1) switch.  The byte
; is stored so the visible kernel can draw the indicator, and it is re-read
; every frame so a mid-game flip is visible immediately.
    LDA SWCHB
ReadSWCHB:                  ; checkpoint: A = SWCHB
    STA Switches

; --- the two-cell switch indicator ------------------------------------------
; The left cell is PF0 bit 6 (chunk 2, X=8); the right cell is PF1 bit 5
; (chunk 6, X=24).  A cell is lit when its switch is on expert (bit = 1).
    LDA #$00
    STA SwitchPF0
    STA SwitchPF1
    LDA Switches
    AND #$40                ; the left switch (P0 difficulty)
    BEQ SwitchLeftDone
    LDA #$40                ; expert: light the left cell
    STA SwitchPF0
SwitchLeftDone:
    LDA Switches
    AND #$80                ; the right switch (P1 difficulty)
    BEQ SwitchRightDone
    LDA #$20                ; expert: light the right cell
    STA SwitchPF1
SwitchRightDone:

; -----------------------------------------------------------------------------
; 3. THE ENEMY'S WIDTH FROM THE RIGHT SWITCH
; -----------------------------------------------------------------------------
; NUSIZ1=0 is one 8-pixel copy; NUSIZ1=5 is double width (16 pixels).  The
; store writes the whole register, so bits 4-5 become 0: the missile size is
; 1 pixel.  This lesson does not use the missiles.
    LDA Switches
    AND #$80
    BEQ EnemyWidthNovice
    LDA #$05                ; expert: double width
    BNE EnemyWidthStore
EnemyWidthNovice:
    LDA #$00                ; novice: one 8-px enemy
EnemyWidthStore:
    STA NUSIZ1
NUSIZWrite:                 ; checkpoint: A = NUSIZ1

; -----------------------------------------------------------------------------
; 4. FIRE — one action per 0 -> 1 edge
; -----------------------------------------------------------------------------
    LDA INPT4
FireRead:                   ; checkpoint: A = INPT4
    AND #$80
    EOR #$80                ; 1 = pressed
    STA NewFire
    EOR PrevFire
    AND NewFire
    STA NewFire             ; NewFire = pressed & ~wasPressed
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire

; -----------------------------------------------------------------------------
; 5. THE P0-P1 COLLISION LATCH
; -----------------------------------------------------------------------------
; Both players are drawn on visible lines 140-155, so CXPPMM bit 7 can set.
; The read is in VBLANK and therefore describes the previous visible frame.
; The latch is sticky until CXCLR, so the code keeps the previous bit and
; keeps only the 0 -> 1 edge: a contact that lasts several frames is one hit.
    LDA CXPPMM
ReadCX:                     ; checkpoint: A = CXPPMM
    AND #$80                ; bit 7 = P0-P1
    STA CollBit
    EOR PrevColl
    AND CollBit
    TAX                     ; X = the 0 -> 1 edge ($80 or 0)
    LDA CollBit
    STA PrevColl
    STX CollBit             ; CollBit = the new-contact bit
    LDA #$00
    STA CXCLR
CXClear:                    ; checkpoint: the latches are cleared

; -----------------------------------------------------------------------------
; 6. START A GAME WHEN REQUESTED
; -----------------------------------------------------------------------------
; StartGame samples the left switch, so the starting level is fixed for the
; life of the game; flipping the switch mid-game does not move the ladder.
    LDA NeedStart
    BEQ NoStartGame
    JSR StartGame
NoStartGame:

; -----------------------------------------------------------------------------
; 7. THE PLAY UPDATE, OR THE GAME-OVER FREEZE
; -----------------------------------------------------------------------------
    LDA GameOver
    BEQ PlayUpdate
    ; --- game over: play freezes; fire starts a new game ------------------
    LDA NewFire
    BNE GameOverRestart
    JMP DisplayBuild
GameOverRestart:
    JSR StartGame
    JMP DisplayBuild

PlayUpdate:
; --- invulnerability counts down one frame at a time -----------------------
    LDA Invuln
    BEQ InvulnDone
    DEC Invuln
InvulnDone:

; --- a new P0-P1 contact costs a life --------------------------------------
; The edge test and the invulnerability window together mean one contact is
; one life, even though the latch stays set while the sprites overlap.
    LDA CollBit
    BEQ NoCollision
    LDA Invuln
    BNE NoCollision
    LDA Lives
    SEC
    SBC #1
LifeStep:                   ; checkpoint: A = the new life count
    STA Lives
    LDA #HIT_PITCH
    STA BeepPitch
    JSR BeepStart
    JSR RespawnEnemy
    LDA #INVULN_FRAMES
    STA Invuln
    LDA Lives
    BNE NoCollision
    LDA #1
    STA GameOver            ; the next frame draws the red field
    LDA #0
    STA Invuln              ; stop the enemy blink on the frozen field
    STA FlashTimer          ; stop the level-bar flash on the frozen field
NoCollision:

; --- P0's motion: the joystick, clamped to the walled play area ------------
    LDA SWCHA
    AND #$C0                ; P0 left (bit 6) and right (bit 7)
    CMP #$C0
    BEQ PlayerMoveDone
    LDA SWCHA
    AND #$40                ; left
    BNE PlayerNoLeft
    JMP MoveLeft
PlayerNoLeft:
    LDA SWCHA
    AND #$80                ; right
    BNE PlayerMoveDone
    JMP MoveRight
PlayerMoveDone:

; --- the speed table, indexed by level -------------------------------------
    LDX Level
    DEX                     ; level 1 -> table entry 0
    LDA SpeedTable,X
    STA Speed
SpeedWrite:                 ; checkpoint: A = SpeedTable[Level]

; --- P1's deterministic bounce ---------------------------------------------
    JSR MoveEnemy

; --- the 300-frame survival clock ------------------------------------------
    LDA LevelTimerLo
    BNE LevelDecLo
    LDA LevelTimerHi
    BEQ LevelUpNow
    DEC LevelTimerHi
    LDA #$FF
    STA LevelTimerLo
    JMP LevelTickDone
LevelDecLo:
    DEC LevelTimerLo
    JMP LevelTickDone
LevelUpNow:
    LDA Level
    CMP #LEVEL_MAX
    BCS LevelCapNow
    CLC
    ADC #1
    CMP #LEVEL_MAX
    BCC LevelUpStore
LevelCapNow:
    LDA #LEVEL_MAX
LevelUpStore:
LevelUp:                    ; checkpoint: A = the new level (capped at 15)
    CMP Level
    BEQ LevelAtCap          ; no change: reload the clock, skip the reward
    STA Level
    LDA #FLASH_FRAMES
    STA FlashTimer
    LDA #LEVEL_PITCH
    STA BeepPitch
    JSR BeepStart
LevelAtCap:
    LDA #LEVEL_FRAMES_LO
    STA LevelTimerLo
    LDA #LEVEL_FRAMES_HI
    STA LevelTimerHi
LevelTickDone:

; --- the level-bar flash clock ---------------------------------------------
    LDA FlashTimer
    BEQ FlashDone
    DEC FlashTimer
FlashDone:

; -----------------------------------------------------------------------------
; 8. BUILD THE DISPLAY BYTES FOR THIS FRAME
; -----------------------------------------------------------------------------
DisplayBuild:
; --- the level bar: Level chunks per half, or a 4-on/4-off flash -----------
    LDA FlashTimer
    BEQ LoadLevelBar
    LDA Frame
    AND #$04                ; 4 frames off, 4 frames on while flashing
    BNE LoadLevelBar
    LDA #$00
    STA LevelPF0
    STA LevelPF1
    STA LevelPF2
    JMP LevelBarDone
LoadLevelBar:
    LDA Level
    ASL                     ; Level * 3: three playfield bytes per entry
    CLC
    ADC Level
    TAX
    LDA LevelBarPF,X
    STA LevelPF0
    LDA LevelBarPF+1,X
    STA LevelPF1
    LDA LevelBarPF+2,X
    STA LevelPF2
LevelBarDone:

; --- the life cells: 3, 2, 1, or 0 lit cells -------------------------------
    LDA Lives
    ASL                     ; two playfield bytes per entry
    TAX
    LDA LifePF,X
    STA LifePF0
    LDA LifePF+1,X
    STA LifePF1

; --- P1 blinks while it is invulnerable ------------------------------------
    LDA #$FF
    STA EnemyDraw
    LDA Invuln
    BEQ EnemyDrawDone
    LDA Frame
    AND #$04
    BNE EnemyDrawDone
    LDA #$00
    STA EnemyDraw
EnemyDrawDone:

; -----------------------------------------------------------------------------
; 9. POSITION BOTH PLAYERS, THEN STROBE ONE HMOVE
; -----------------------------------------------------------------------------
; Both use the same +POS_BIAS target as Lesson 26/41.  Their fine values sit
; in HMP0/HMP1 until the single HMOVE applies both in one HBLANK.
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA EnemyX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
    STA WSYNC
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed (next line, cycle 3)

; -----------------------------------------------------------------------------
; 10. COLORS, SIZES, AND THE FIRST VISIBLE LINE'S PLAYFIELD
; -----------------------------------------------------------------------------
    LDA #C_RED
    STA COLUP0              ; P0 is red
    LDA #C_GREEN
    STA COLUP1              ; P1 is green
    LDA #C_BG
    STA COLUBK              ; the dark play-field background
    LDA #$01
    STA CTRLPF              ; reflect the playfield; ball one pixel wide
    LDA #$00
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL

; --- the level bar's first line is preloaded in VBLANK ---------------------
; The level zone has no write stage of its own: it only waits eight lines.
; Without the preload, visible line 0 would still show the previous frame's
; play-area wall bytes (PF0=$F0) until line 1.  Loading the three PF bytes
; and the gold colour here makes line 0 as solid as the other seven.
    LDA LevelPF0
    STA PF0
    LDA LevelPF1
    STA PF1
    LDA LevelPF2
    STA PF2
    LDA #C_GOLD
    STA COLUPF

; --- the game-over field is red --------------------------------------------
    LDA GameOver
    BEQ GameOverColorDone
    LDA #C_RED
    STA COLUBK
GameOverColorDone:

    +wait_timer

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
    LDA #$00
    STA VBLANK

BodyStart:                  ; checkpoint: scanline 37, visible line 0

; --- visible 0-7: the level bar (PF and COLUPF preloaded in VBLANK) --------
    LDY #8
LevelZone:
    STA WSYNC
    DEY
    BNE LevelZone

; --- visible 8-15: the life cells (red) ------------------------------------
    LDA #C_RED
    STA COLUPF
    LDA LifePF0
    STA PF0
    LDA LifePF1
    STA PF1
    LDA #$00
    STA PF2
    LDY #8
LifeZone:
    STA WSYNC
    DEY
    BNE LifeZone

; --- visible 16-23: the switch indicator (white) --------------------------
    LDA #C_WHITE
    STA COLUPF
    LDA SwitchPF0
    STA PF0
    LDA SwitchPF1
    STA PF1
    LDA #$00
    STA PF2
    LDY #8
SwitchZone:
    STA WSYNC
    DEY
    BNE SwitchZone

; --- visible 24-139: the edge walls, no sprites ---------------------------
    LDA #C_GOLD
    STA COLUPF
    LDA #$F0                ; PF0 bits 4-7: the 16-px wall at each edge
    STA PF0
    LDA #$00
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    LDY #116
PlayTop:
    STA WSYNC
    DEY
    BNE PlayTop

; --- visible 140-155: both 16-row players ---------------------------------
; The two stores land at cycles 5-10 of the first sprite line, well before
; the earliest P0/P1 pixel (X=24 is absolute clock 92, CPU cycle ~31).
    LDA EnemyDraw
    STA GRP1
    LDA #$FF
    STA GRP0
    LDY #16
PlaySprites:
    STA WSYNC
    DEY
    BNE PlaySprites

; --- visible 156-191: the players are over; walls only --------------------
    LDA #$00
    STA GRP0
    STA GRP1
    LDY #36
PlayBottom:
    STA WSYNC
    DEY
    BNE PlayBottom
    JMP FrameEnd

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
FrameEnd:
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; StartGame — the switch-selected starting level and a fresh game
; =============================================================================
; Called from the first VBLANK (NeedStart) and from the game-over fire edge.
; The left switch (SWCHB bit 6) picks novice=1 or expert=5; the value is
; stored in StartLevel so the debugger can show what the switch chose.
StartGame:
    LDA Switches
    AND #$40                ; the left switch
    BEQ StartNovice
    LDA #START_EXPERT
    BNE StartLevelStore
StartNovice:
    LDA #START_NOVICE
StartLevelStore:
    STA StartLevel
StartLevelSet:              ; checkpoint: A = the switch-selected start level
    STA Level
    LDA #3
    STA Lives
LifeInit:                   ; checkpoint: A = 3 at the start of a game
    LDA #LEVEL_FRAMES_LO
    STA LevelTimerLo
    LDA #LEVEL_FRAMES_HI
    STA LevelTimerHi
    LDA #80
    STA PlayerX
    LDA #ENEMY_MIN_X
    STA EnemyX
    LDA #1
    STA EnemyDir
    LDA #$00
    STA Invuln
    STA FlashTimer
    STA GameOver
    STA NeedStart
    STA PrevColl
    LDA #BEEP_PITCH_DEFAULT
    STA BeepPitch
    RTS

; =============================================================================
; RespawnEnemy — put P1 on the side away from P0, moving back toward P0
; =============================================================================
; A = the hit was already charged to Lives.  If P0 was to the right of P1,
; P1 respawns at the right wall and moves left; otherwise it respawns at the
; left wall and moves right.  The trip back is the player's breathing room.
RespawnEnemy:
    LDA EnemyX
    CMP PlayerX
    BCC RespawnRight
    LDA #ENEMY_MIN_X
    STA EnemyX
    LDA #1
    STA EnemyDir
    RTS
RespawnRight:
    LDA #ENEMY_MAX_X
    STA EnemyX
    LDA #0
    STA EnemyDir
    RTS

; =============================================================================
; MoveEnemy — P1's bounce, at Speed pixels per frame
; =============================================================================
; The clamp is also the bounce: a step past a wall snaps to the wall and
; flips EnemyDir.  At the 1..4 px speeds the difference is invisible.
MoveEnemy:
    LDA EnemyDir
    BNE EnemyRight
; --- moving left -----------------------------------------------------------
    LDA EnemyX
    SEC
    SBC Speed
    BCS EnemyLeftInRange
    LDA #ENEMY_MIN_X
    STA EnemyX
    LDA #1
    STA EnemyDir
    RTS
EnemyLeftInRange:
    CMP #ENEMY_MIN_X
    BCS EnemyLeftStore
    LDA #ENEMY_MIN_X
    STA EnemyX
    LDA #1
    STA EnemyDir
    RTS
EnemyLeftStore:
    STA EnemyX
    RTS
; --- moving right ----------------------------------------------------------
EnemyRight:
    LDA EnemyX
    CLC
    ADC Speed
    BCC EnemyRightInRange
    LDA #ENEMY_MAX_X
    STA EnemyX
    LDA #0
    STA EnemyDir
    RTS
EnemyRightInRange:
    CMP #(ENEMY_MAX_X + 1)
    BCC EnemyRightStore
    LDA #ENEMY_MAX_X
    STA EnemyX
    LDA #0
    STA EnemyDir
    RTS
EnemyRightStore:
    STA EnemyX
    RTS

; =============================================================================
; P0's movement, clamped to the walled play area
; =============================================================================
MoveLeft:
    DEC PlayerX
    LDA PlayerX
    CMP #PLAYER_MIN_X
    BCS MoveDone
    LDA #PLAYER_MIN_X
    STA PlayerX
    JMP MoveDone
MoveRight:
    INC PlayerX
    LDA PlayerX
    CMP #(PLAYER_MAX_X + 1)
    BCC MoveDone
    LDA #PLAYER_MAX_X
    STA PlayerX
MoveDone:
    JMP PlayerMoveDone

; =============================================================================
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
BeepStart:
    LDA #BEEP_FRAMES
    STA BeepTimer
    LDA #$0C                ; AUDC 0C: the div-6 tone from Lesson 35
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0
    RTS

; =============================================================================
; COARSE POSITIONING — P0 and P1, one HMOVE at the end
; =============================================================================
; A = the target TIA X plus POS_BIAS.  Each routine strobes its RESxx and
; leaves the fine value in its HMxx; the caller's single HMOVE applies both
; fine offsets in one HBLANK (the one-HMOVE rule from Lesson 28).
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

; =============================================================================
; SPEED TABLE — 15 entries, indexed by Level-1
; =============================================================================
; The ladder is deliberately gentle at the bottom: levels 1-3 are 1 px,
; 4-6 are 2 px, 7-10 are 3 px, and 11-15 are 4 px per frame.  Level 5 is
; therefore twice level 1, which is what the two captures compare.
SpeedTable:
    !byte 1,1,1,2,2,2,3,3,3,3,4,4,4,4,4

; =============================================================================
; LEVEL-BAR TABLE — N chunks from the left, three playfield bytes per entry
; =============================================================================
; PF0 bits 4-7 are the first four chunks (bit 4 leftmost); PF1 bits 7-0 are
; the next eight (bit 7 leftmost); PF2 bits 0-2 are the last three (bit 0 is
; leftmost, because PF2's bit order is reversed).  CTRLPF=$01 mirrors the
; same chunks from the right edge, so every count is "per half".
LevelBarPF:
    !byte $00,$00,$00       ; 0 chunks
    !byte $10,$00,$00       ; 1
    !byte $30,$00,$00       ; 2
    !byte $70,$00,$00       ; 3
    !byte $F0,$00,$00       ; 4
    !byte $F0,$80,$00       ; 5
    !byte $F0,$C0,$00       ; 6
    !byte $F0,$E0,$00       ; 7
    !byte $F0,$F0,$00       ; 8
    !byte $F0,$F8,$00       ; 9
    !byte $F0,$FC,$00       ; 10
    !byte $F0,$FE,$00       ; 11
    !byte $F0,$FF,$00       ; 12
    !byte $F0,$FF,$01       ; 13
    !byte $F0,$FF,$03       ; 14
    !byte $F0,$FF,$07       ; 15

; =============================================================================
; LIFE-CELL TABLE — three cells at X=8, 16, and 24
; =============================================================================
; Cell 1 is PF0 bits 6-7 (chunks 2-3, X=8); cell 2 is PF1 bits 6-7 (chunks
; 4-5, X=16); cell 3 is PF1 bits 4-5 (chunks 6-7, X=24).
LifePF:
    !byte $00,$00           ; 0 lives
    !byte $C0,$00           ; 1 life: cell 1
    !byte $C0,$C0           ; 2 lives: cells 1 and 2
    !byte $C0,$F0           ; 3 lives: all three cells

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
