; =============================================================================
; LESSON 44 — EXERCISE 2 SOLUTION: The Dead Zone — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; EXERCISE 2: chase only when Distance > 16; otherwise patrol.  In the dead
; zone the enemy holds its position, so EnemyMove reports 0 and there is no
; chase/patrol chatter at the threshold.
;
; The changes from the main ROM:
;   1. CHASE_RANGE becomes 16.  Patrol enters chase only when Distance > 16.
;   2. The chase's low-distance branch goes to PATROL (state 0), not flee.
;      DEAD_ZONE=16 is the boundary; the hold frame reports 0.
;   3. MoveEnemy's patrol branch is a hold: it returns delta 0 without
;      touching EnemyX.  That is the "no jitter" part of the exercise.
;   4. Flee is still reachable with fire.  Its 60-frame timer and the
;      > 32 exit are unchanged, so the state row still shows red after a
;      fire press.
;   5. Because the chase returns to patrol at <= 16 instead of fleeing at
;      <= 24, the auto-demo's provoke produces a short chase and then the
;      dead-zone hold.  Press fire to see the flee state.
;   The screen layout, the distance bar, the life system, and the auto-demo
;   clocks are the main ROM's.
;
; Checkpoints: the main ROM's.  In the dead zone EnemyMove reports A=0 and
;   EnemyXWrite reports the unchanged EnemyX; EnemyStateWrite stays 0.
;
; Build: acme -f plain -o build/ex44-2.bin \
;        lessons/part6-game-dev/44-ai-enemy-behavior/exercise-02-solution.asm
; Run:   stella build/ex44-2.bin     (click the screen to hear the beep)
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

ENEMY_MIN_X    = 24      ; P1's left edge at the left wall
ENEMY_MAX_X    = 136     ; P1's left edge at the right wall
PLAYER_MIN_X   = 24
PLAYER_MAX_X   = 136
PLAYER_START_X = 64
ENEMY_START_X  = 80

PATROL_STEP    = 1
CHASE_STEP     = 2
FLEE_STEP      = 2

CHASE_RANGE    = 16      ; exercise 2: patrol -> chase when Distance > 16
DEAD_ZONE      = 16      ; chase -> patrol when Distance <= 16
FLEE_EXIT_RANGE = 32     ; flee -> patrol only when Distance > 32
FLEE_FRAMES    = 60
INVULN_FRAMES  = 60
HIT_PITCH      = $08     ; AUDF 8 on AUDC $0C: a short, bright hit

TRACK_FRAMES   = 120     ; the auto-demo's track phase
PROVOKE_FRAMES = 90      ; the auto-demo's run-away phase
TRACK_NEAR     = 18      ; track: back away below this distance
TRACK_FAR      = 22      ; track: approach above this distance

C_RED          = $42
C_GOLD         = $1A
C_GREEN        = $C8
C_WHITE        = $0E
C_BG           = $02

STATE_PATROL_PF0 = $C0   ; PF0 bits 6-7: chunks 2-3, X=8-15
STATE_CHASE_PF1  = $C0   ; PF1 bits 6-7: chunks 4-5, X=16-23
STATE_FLEE_PF1   = $30   ; PF1 bits 4-5: chunks 6-7, X=24-31

; --- Lesson variables (RAM $80-$9C; +clean_start zeroes them) --------------
EnemyState   = $80   ; 0=patrol, 1=chase, 2=flee
EnemyX       = $81   ; P1's left edge, 24..136
EnemyDir     = $82   ; patrol direction: 1 = right, 0 = left
EnemyTimer   = $83   ; flee frames remaining (the 60-frame clock)
PlayerX      = $84   ; P0's left edge, 24..136
Lives        = $85   ; 3 at the start, 0 = game over
Distance     = $86   ; |PlayerX - EnemyX|, 0..112, after the life path
Invuln       = $87   ; frames of invulnerability remaining
GameOver     = $88   ; 1 = the red frozen field; fire restarts
Frame        = $89   ; free-running 8-bit frame counter (blink uses bit 2)
PrevFire     = $8A   ; fire state last frame (1 = pressed)
NewFire      = $8B   ; this frame's fire 0 -> 1 edge
NeedStart    = $8C   ; 1 = the next VBLANK must start a game
PrevColl     = $8D   ; last frame's CXPPMM bit 7
CollBit      = $8E   ; this frame's CXPPMM bit 7, then its 0 -> 1 edge
PlayerRight  = $8F   ; 1 = PlayerX >= EnemyX, 0 = PlayerX < EnemyX
EnemyDelta   = $90   ; the signed movement delta chosen this frame
EnemyStep    = $91   ; |EnemyDelta| while it is applied to EnemyX
StatePF0     = $92   ; the state row's playfield bytes for this frame
StatePF1     = $93
DistPF0      = $94   ; the distance bar's playfield bytes for this frame
DistPF1      = $95
StateColor   = $96   ; the active state's colour ($C8, $1A, or $42)
EnemyDraw    = $97   ; $FF, or 0 during the invulnerability blink's off phase
BeepTimer    = $98   ; frames of beep remaining
BeepPitch    = $99   ; AUDF for the beep
AutoTimer    = $9A   ; the auto-demo's phase clock
AutoMode     = $9B   ; 0 = track, 1 = provoke
PlayerStep   = $9C   ; 1 or 2 while a player movement routine runs
;
; $9D-$D7 are free.  The shared score/random libraries are not used.
; The stack lives at $F8-$FF.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the first game starts in the first VBLANK -----------------------------
; Reset only marks the game as pending.  StartGame sets the positions, the
; three lives, and the patrol state, so a power-on and a fire restart use
; exactly the same door.
    LDA #1
    STA NeedStart
    LDA #HIT_PITCH
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
; Frame drives the invulnerability blink (bit 2: four frames on, four off).
; BeepTimer counts down every frame and silences channel 0 at zero.
    INC Frame

    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0               ; silence at the end of the tick
BeepClockDone:

; -----------------------------------------------------------------------------
; 2. FIRE — one action per 0 -> 1 edge
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while the fire button is pressed.  The EOR turns that into
; a 1, and the EOR/AND pair keeps only the new press, so holding the button
; does not re-arm the flee timer on every frame.
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
; 3. THE P0-P1 COLLISION LATCH
; -----------------------------------------------------------------------------
; Both players are drawn on visible lines 100-115, so CXPPMM bit 7 can set.
; The read is in VBLANK and therefore describes the previous visible frame.
; The latch is sticky until CXCLR, so the code keeps the previous bit and
; keeps only the 0 -> 1 edge: an overlap that lasts several frames is one hit.
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
; 4. START A GAME WHEN REQUESTED
; -----------------------------------------------------------------------------
    LDA NeedStart
    BEQ NoStartGame
    JSR StartGame
NoStartGame:

; -----------------------------------------------------------------------------
; 5. THE GAME-OVER FREEZE, OR THE PLAY UPDATE
; -----------------------------------------------------------------------------
; Game over keeps drawing the last frame; the background is red, set in the
; colour block below.  Fire calls StartGame and the new game runs this frame.
    LDA GameOver
    BEQ PlayUpdate
    LDA NewFire
    BEQ FrozenFrame
    JSR StartGame
    JSR ComputeDistance      ; the new game's bar, before the first picture
    JMP BuildDisplay
FrozenFrame:
    JMP BuildDisplay

PlayUpdate:

; -----------------------------------------------------------------------------
; 6. THE ENEMY'S BRAIN — state transitions, then movement
; -----------------------------------------------------------------------------
; UpdateEnemy reads Distance and PlayerRight, which ComputeDistance computed
; at the end of the previous frame (section 9).  The one-frame pipeline is the
; same shape as Lesson 38's collision read: the brain decides from the picture
; that is already on screen, and the new positions are measured afterwards.
    JSR UpdateEnemy

; -----------------------------------------------------------------------------
; 7. THE PLAYER — the joystick, or the auto-demo when no direction is held
; -----------------------------------------------------------------------------
; SWCHA is active low: bits 6 (left) and 7 (right) are 0 while pressed.  A
; manual direction cancels the demo's current phase and restarts its clock.
    LDA SWCHA
    AND #$C0                ; P0 left (bit 6) and right (bit 7)
    CMP #$C0
    BEQ AutoPlayer
    LDA #0
    STA AutoMode
    LDA #TRACK_FRAMES
    STA AutoTimer
    LDA SWCHA
    AND #$40                ; left
    BNE ManualNoLeft
    JSR MovePlayerLeft1
    JMP PlayerDone
ManualNoLeft:
    LDA SWCHA
    AND #$80                ; right
    BNE PlayerDone
    JSR MovePlayerRight1
    JMP PlayerDone
AutoPlayer:
    JSR AutoDemo
PlayerDone:

; -----------------------------------------------------------------------------
; 8. INVULNERABILITY AND THE LIFE COUNT
; -----------------------------------------------------------------------------
; Invuln counts down one frame at a time.  A new contact while Invuln is zero
; costs a life, beeps, respawns P1 away from the player, and re-arms 60
; frames.  At zero lives the field freezes and turns red.
    LDA Invuln
    BEQ InvulnDone
    DEC Invuln
InvulnDone:

    LDA CollBit
    BEQ NoLifeLost
    LDA Invuln
    BNE NoLifeLost
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
    BNE NoLifeLost
    LDA #1
    STA GameOver            ; the next frame draws the red field
    LDA #0
    STA Invuln              ; stop the blink on the frozen field
NoLifeLost:

; -----------------------------------------------------------------------------
; 9. THE DISTANCE AND THE SIDE, MEASURED AFTER THE LIFE PATH
; -----------------------------------------------------------------------------
; Distance is |PlayerX - EnemyX|; PlayerRight records which side of the enemy
; the player is on.  Measuring after the moves AND after the life block means
; a respawn is included: the hit frame's bar shows the new gap, and the frozen
; red field keeps that gap.  The next frame's brain reads the same positions
; the viewer saw.
    JSR ComputeDistance

; -----------------------------------------------------------------------------
; 10. BUILD THE STATE ROW, THE DISTANCE BAR, AND THE BLINK
; -----------------------------------------------------------------------------
BuildDisplay:
; --- the state row: one 8-pixel cell per state, in the state's colour ------
    LDA EnemyState
    CMP #1
    BEQ BuildChase
    CMP #2
    BEQ BuildFlee
    LDA #STATE_PATROL_PF0
    STA StatePF0
    LDA #$00
    STA StatePF1
    LDA #C_GREEN
    STA StateColor
    JMP StateBuilt
BuildChase:
    LDA #$00
    STA StatePF0
    LDA #STATE_CHASE_PF1
    STA StatePF1
    LDA #C_GOLD
    STA StateColor
    JMP StateBuilt
BuildFlee:
    LDA #$00
    STA StatePF0
    LDA #STATE_FLEE_PF1
    STA StatePF1
    LDA #C_RED
    STA StateColor
StateBuilt:

; --- the distance bar: Distance / 16 chunks, 0..7 -------------------------
; Four LSRs divide by 16.  The table entry holds the PF0/PF1 bytes that light
; that many chunks from the left edge; CTRLPF's mirror repeats it on the
; right.  A zero distance leaves the bar dark.
    LDA Distance
    LSR
    LSR
    LSR
    LSR
    TAX
    LDA DistBarPF0,X
    STA DistPF0
    LDA DistBarPF1,X
    STA DistPF1

; --- P1 blinks while it is invulnerable ------------------------------------
    LDA #$FF
    STA EnemyDraw
    LDA Invuln
    BEQ EnemyDrawDone
    LDA Frame
    AND #$04                ; four frames on, four off
    BNE EnemyDrawDone
    LDA #$00
    STA EnemyDraw
EnemyDrawDone:

; -----------------------------------------------------------------------------
; 11. POSITION BOTH PLAYERS, THEN STROBE ONE HMOVE
; -----------------------------------------------------------------------------
; Both use the same +POS_BIAS target as Lesson 26/41/42.  Their fine values
; sit in HMP0/HMP1 until the single HMOVE applies both in one HBLANK (the
; one-HMOVE rule from Lesson 28).
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
HmoveDone:                  ; checkpoint: the store has executed (next line)

; -----------------------------------------------------------------------------
; 12. COLOURS, SIZES, CONTROL, AND THE FIRST VISIBLE LINE'S PLAYFIELD
; -----------------------------------------------------------------------------
; P0 is red; P1 takes the state colour, so the enemy and the state row agree.
; The state row's PF bytes and colour are preloaded here: BodyStart's first
; write would land in HBLANK anyway, but the preload makes line 0 as solid as
; the rest of the row.
    LDA #C_RED
    STA COLUP0
    LDA GameOver
    BEQ PlayerColorDone
    LDA #C_WHITE            ; keep P0 visible on the red game-over field
    STA COLUP0
PlayerColorDone:
    LDA StateColor
    STA COLUP1
    LDA #C_BG
    STA COLUBK
    LDA #$00
    STA NUSIZ0              ; both players are one 8-pixel copy
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL
    LDA #$01
    STA CTRLPF              ; reflect the playfield; ball one pixel wide

; --- the game-over field is red --------------------------------------------
    LDA GameOver
    BEQ PreloadStateRow
    LDA #C_RED
    STA COLUBK
PreloadStateRow:
    LDA StateColor
    STA COLUPF
    LDA StatePF0
    STA PF0
    LDA StatePF1
    STA PF1
    LDA #$00
    STA PF2

    +wait_timer

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
    LDA #$00
    STA VBLANK

BodyStart:                  ; checkpoint: scanline 37, visible line 0

; --- visible 0-7: the state row (PF and COLUPF preloaded in VBLANK) -------
    LDY #8
StateRow:
    STA WSYNC
    DEY
    BNE StateRow

; --- visible 8-15: the distance bar (white) -------------------------------
; White separates the bar from the gold wall directly below it: a one-chunk
; bar inside X=0-15 would otherwise be invisible against the wall.  The first
; column's writes land at cycles 5-22 of visible line 8, before PF0's first
; visible slot at cycle 22.7.
    LDA #C_WHITE
    STA COLUPF
    LDA DistPF0
    STA PF0
    LDA DistPF1
    STA PF1
    LDA #$00
    STA PF2
    LDY #8
DistRow:
    STA WSYNC
    DEY
    BNE DistRow

; --- visible 16-99: the play area's top section, walls only ---------------
    LDA #C_GOLD
    STA COLUPF
    LDA #$F0                ; PF0 bits 4-7: the 16-px wall at each edge
    STA PF0
    LDA #$00
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    LDY #84
PlayTop:
    STA WSYNC
    DEY
    BNE PlayTop

; --- visible 100-115: both 16-row players ---------------------------------
; P0 is always solid; P1 is EnemyDraw ($FF, or 0 during the blink's off
; phase).  The stores land by cycle 11, well before the earliest sprite pixel
; (X=24 is absolute clock 92, CPU cycle ~31).
    LDA #$FF
    STA GRP0
    LDA EnemyDraw
    STA GRP1
    LDY #16
PlaySprites:
    STA WSYNC
    DEY
    BNE PlaySprites

; --- visible 116-191: the players are over; walls only --------------------
    LDA #$00
    STA GRP0
    STA GRP1
    LDY #76
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
; StartGame — the one door into a fresh game
; =============================================================================
; Called from the first VBLANK (NeedStart) and from the game-over fire edge.
; P0 starts left of P1 at a 16-pixel distance, so the first frame is a patrol;
; the auto-demo then keeps the pair together or provokes a chase.
StartGame:
    LDA #3
    STA Lives
LifeInit:                   ; checkpoint: A = 3 at the start of a game
    LDA #PLAYER_START_X
    STA PlayerX
    LDA #ENEMY_START_X
    STA EnemyX
    LDA #1
    STA EnemyDir
    LDA #0
    STA EnemyTimer
    STA Invuln
    STA GameOver
    STA NeedStart
    STA PrevColl
    STA CollBit
    STA AutoMode
    LDA #TRACK_FRAMES
    STA AutoTimer
    LDA #HIT_PITCH
    STA BeepPitch
    LDA #0
    JSR SetEnemyState       ; a fresh game starts in patrol
    RTS

; =============================================================================
; RespawnEnemy — put P1 on the side away from P0
; =============================================================================
; If the player is in the right half, P1 respawns at the left wall; otherwise
; at the right wall.  The 60-frame invulnerability in the caller is the
; breathing room; this placement keeps the respawn itself safe.
RespawnEnemy:
    LDA PlayerX
    CMP #80
    BCS RespawnAtLeft
    LDA #ENEMY_MAX_X
    STA EnemyX
    LDA #0
    STA EnemyDir
    JMP RespawnState
RespawnAtLeft:
    LDA #ENEMY_MIN_X
    STA EnemyX
    LDA #1
    STA EnemyDir
RespawnState:
    LDA #0
    JSR SetEnemyState
    LDA #0
    STA EnemyTimer
    RTS

; =============================================================================
; ComputeDistance — Distance = |PlayerX - EnemyX|, plus PlayerRight
; =============================================================================
; The subtraction is unsigned because the two bytes are compared first.  A
; carry of 1 from CMP means PlayerX >= EnemyX, so the same carry feeds SBC.
ComputeDistance:
    LDA PlayerX
    CMP EnemyX
    BCC PlayerIsLeft
    SBC EnemyX              ; C=1: A = PlayerX - EnemyX
    STA Distance
    LDA #1
    STA PlayerRight
    JMP DistanceDone
PlayerIsLeft:
    LDA EnemyX
    SEC
    SBC PlayerX
    STA Distance
    LDA #0
    STA PlayerRight
DistanceDone:
    LDA Distance
DistanceCalc:               ; checkpoint: A = the distance, 0..112
    RTS

; =============================================================================
; UpdateEnemy — the state transitions, then the movement
; =============================================================================
; Order matters: fire is checked first and wins from every state; then the
; current state's rule.  Patrol holds in the dead zone, the chase returns
; to patrol at <= 16, and flee waits for the 60-frame clock AND a distance
; > 32.
UpdateEnemy:
    LDA NewFire
    BEQ EnemyNoFire
    JMP EnterFlee
EnemyNoFire:
    LDA EnemyState
    CMP #2
    BEQ UpdateFlee
    CMP #1
    BEQ UpdateChase

; --- state 0: patrol (the dead zone holds position) -----------------------
    LDA Distance
    CMP #(CHASE_RANGE + 1)  ; Distance >= 17?
    BCC EnemyPatrol         ; no: stay in the dead zone and hold
    LDA #1
    JSR SetEnemyState
    JMP MoveEnemy
EnemyPatrol:
    JMP MoveEnemy

; --- state 1: chase --------------------------------------------------------
UpdateChase:
    LDA Distance
    CMP #(DEAD_ZONE + 1)    ; Distance <= 16?
    BCS EnemyChase          ; A >= 17: still outside the dead zone
    LDA #0
    JSR SetEnemyState       ; back to patrol; the hold reports delta 0
    JMP MoveEnemy
EnemyChase:
    JMP MoveEnemy

; --- state 2: flee ---------------------------------------------------------
UpdateFlee:
    LDA EnemyTimer
    BEQ FleeExitCheck
    DEC EnemyTimer
    BNE EnemyFleeMove       ; still counting: no exit yet
FleeExitCheck:
    LDA Distance
    CMP #(FLEE_EXIT_RANGE + 1) ; Distance > 32?
    BCC EnemyFleeMove       ; no: the cornered enemy stays red
    LDA #0
    JSR SetEnemyState
EnemyFleeMove:
    JMP MoveEnemy

EnterFlee:
    LDA #2
    JSR SetEnemyState
    LDA #FLEE_FRAMES
    STA EnemyTimer
    JMP MoveEnemy

; =============================================================================
; MoveEnemy — choose a signed delta, then apply it
; =============================================================================
; A patrol turns at a wall and moves one pixel the other way on the same
; frame.  Chase and flee use PlayerRight, so they move toward or away from
; the player without another subtraction.
MoveEnemy:
    LDA EnemyState
    CMP #2
    BEQ FleeMove
    CMP #1
    BEQ ChaseMove

; --- patrol: hold position in the dead zone -------------------------------
; The exercise's "no jitter" is this single decision: the default state does
; not move.  EnemyMove reports 0, so the log shows the dead zone directly.
PatrolMove:
    LDA #0
    JMP ApplyDelta

; --- chase: +2 toward the player, -2 away --------------------------------
ChaseMove:
    LDA PlayerRight
    BEQ ChaseLeft
    LDA #CHASE_STEP
    JMP ApplyDelta
ChaseLeft:
    LDA #$FE                ; -2
    JMP ApplyDelta

; --- flee: +2 away from the player, -2 toward ----------------------------
FleeMove:
    LDA PlayerRight
    BEQ FleeRight
    LDA #$FE                ; -2
    JMP ApplyDelta
FleeRight:
    LDA #FLEE_STEP
    JMP ApplyDelta

; =============================================================================
; ApplyDelta — EnemyX = clamp(EnemyX + delta, 24, 136)
; =============================================================================
; The delta is signed.  A positive delta is added with CLC/ADC; a negative
; delta is converted to its magnitude and subtracted, because a raw ADC of
; $FF would carry for every EnemyX >= 1 and trip the high clamp.
ApplyDelta:
EnemyMove:                  ; checkpoint: A = the signed delta (+1, -1, +2, -2)
    STA EnemyDelta
    BPL DeltaPositive

; --- negative: A = |delta|, then EnemyX - |delta| -------------------------
    EOR #$FF
    CLC
    ADC #1                  ; two's complement: $FF -> 1, $FE -> 2
    STA EnemyStep
    LDA EnemyX
    SEC
    SBC EnemyStep
    CMP #ENEMY_MIN_X
    BCC DeltaLow
    STA EnemyX
    JMP DeltaDone

; --- positive: EnemyX + delta --------------------------------------------
DeltaPositive:
    CLC
    ADC EnemyX
    BCS DeltaHigh           ; a wrap: clamp to the right wall
    CMP #(ENEMY_MAX_X + 1)
    BCS DeltaHigh
    STA EnemyX
    JMP DeltaDone

DeltaLow:
    LDA #ENEMY_MIN_X
    STA EnemyX
    JMP DeltaDone
DeltaHigh:
    LDA #ENEMY_MAX_X
    STA EnemyX
DeltaDone:
    LDA EnemyX
EnemyXWrite:                ; checkpoint: A = the new EnemyX, 24..136
    RTS

; =============================================================================
; SetEnemyState — the one door into a state
; =============================================================================
; A = the new state.  Every transition goes through here, so EnemyStateWrite
; reports exactly the value every transition stored.
SetEnemyState:
    STA EnemyState
EnemyStateWrite:            ; checkpoint: A = the new state
    RTS

; =============================================================================
; AutoDemo — P0's movement when the joystick is untouched
; =============================================================================
; AutoTimer toggles the patrol phase between track (120 frames) and provoke
; (90 frames).  The state overrides the phase for chase and flee: a chase is
; always run away from, and a flee is always followed at the same speed.
AutoDemo:
    DEC AutoTimer
    BNE AutoTimerDone
    LDA AutoMode
    EOR #1
    STA AutoMode
    BNE AutoProvokeReload
    LDA #TRACK_FRAMES
    STA AutoTimer
    JMP AutoTimerDone
AutoProvokeReload:
    LDA #PROVOKE_FRAMES
    STA AutoTimer
AutoTimerDone:
    LDA EnemyState
    CMP #1
    BEQ AutoChase
    CMP #2
    BEQ AutoFlee

; --- patrol: track the enemy, or run away during a provoke ----------------
    LDA AutoMode
    BNE AutoProvoke
    LDA Distance
    CMP #(TRACK_FAR + 1)    ; more than 22: walk toward the enemy
    BCS AutoApproach
    CMP #TRACK_NEAR         ; less than 18: back away
    BCC AutoRetreat
    RTS                     ; 18..22: hold the gap
AutoApproach:
    LDA PlayerRight
    BNE AutoApproachLeft
    JMP MovePlayerRight1
AutoApproachLeft:
    JMP MovePlayerLeft1
AutoRetreat:
    LDA PlayerRight
    BNE AutoRetreatRight
    JMP MovePlayerLeft1
AutoRetreatRight:
    JMP MovePlayerRight1
AutoProvoke:
    LDA PlayerRight
    BNE AutoProvokeRight
    JMP MovePlayerLeft2
AutoProvokeRight:
    JMP MovePlayerRight2

; --- chase: run away at 2 -------------------------------------------------
AutoChase:
    LDA PlayerRight
    BNE AutoChaseRight
    JMP MovePlayerLeft2
AutoChaseRight:
    JMP MovePlayerRight2

; --- flee: hold still, so the enemy's 60-frame escape is visible ----------
AutoFlee:
    RTS

; =============================================================================
; PLAYER MOVEMENT — clamps at 24 and 136
; =============================================================================
MovePlayerLeft1:
    LDX #1
    JMP PlayerLeftStep
MovePlayerLeft2:
    LDX #2
    JMP PlayerLeftStep
PlayerLeftStep:
    STX PlayerStep
    LDA PlayerX
    SEC
    SBC PlayerStep
    CMP #PLAYER_MIN_X
    BCC PlayerLeftClamp
    STA PlayerX
    RTS
PlayerLeftClamp:
    LDA #PLAYER_MIN_X
    STA PlayerX
    RTS

MovePlayerRight1:
    LDX #1
    JMP PlayerRightStep
MovePlayerRight2:
    LDX #2
    JMP PlayerRightStep
PlayerRightStep:
    STX PlayerStep
    LDA PlayerX
    CLC
    ADC PlayerStep
    CMP #(PLAYER_MAX_X + 1)
    BCS PlayerRightClamp
    STA PlayerX
    RTS
PlayerRightClamp:
    LDA #PLAYER_MAX_X
    STA PlayerX
    RTS

; =============================================================================
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
; AUDC 0C is the div-6 tone from Lesson 35; AUDV 0A is audible but not loud.
; The VBLANK clock silences the channel eight frames later.
BeepStart:
    LDA #8
    STA BeepTimer
    LDA #$0C
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
; DISTANCE-BAR TABLE — N chunks from the left, two playfield bytes per entry
; =============================================================================
; PF0 bits 4-7 are the first four chunks (bit 4 leftmost); PF1 bits 7-5 are
; the next three (bit 7 leftmost).  CTRLPF=$01 mirrors the same chunks from
; the right edge, so every count is "per half".  N = Distance/16 (0-7).
DistBarPF0:
    !byte $00,$10,$30,$70,$F0,$F0,$F0,$F0
DistBarPF1:
    !byte $00,$00,$00,$00,$00,$80,$C0,$E0

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
