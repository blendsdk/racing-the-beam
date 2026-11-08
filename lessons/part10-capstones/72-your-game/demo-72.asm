; =============================================================================
; LESSON 72: Capstone 4 — Your Own Game — Racing the Beam
; =============================================================================
; Part 10: Capstone Projects
;
; What this program does:
;   "Star Catcher" is a complete 4,096-byte mini-game and the skeleton for
;   the reader's own game.  The player catches falling stars with a gold ship
;   while a 30-second clock runs.  Three states drive the machine:
;
;     State 0 TITLE   a gold emblem (P0) and a blinking bar prompt that
;                     stands for "PRESS FIRE" (the course has no text engine
;                     in this skeleton).  The score is hidden because the
;                     score buffer is still zeroed.  Fire begins play; with
;                     no fire the auto-demo begins after a one-second settle
;                     plus two seconds.
;     State 1 PLAY    the score band at the top, a timer bar and three life
;                     markers in the first five play lines, the ship at
;                     Y=168, and a 4x4 ball item falling from Y=24 at a
;                     pseudo-random X (two pixels per frame; the demo's
;                     forced-miss items fall one, slowly).  A catch (CXP0FB bit 6)
;                     scores one and
;                     respawns the item; a miss (ItemY > 180) costs a life.
;                     The 30-second clock is shown as a bar that shrinks.
;     State 2 OVER    the final score stays in the score band, the field
;                     turns red, and the prompt bars blink.  Fire restarts.
;
;   The score library (include/score.asm) draws the six-digit score in nine
;   visible lines.  The sound library (include/sound.asm) plays a catch blip
;   on channel 0 and a miss buzz on channel 1.  Fire is an edge, not a level:
;   the title starts play and the over screen restarts; a fire press during
;   play does nothing.
;
; The screen (192 visible lines):
;   picture lines 0-8     the score band.  ScoreDraw consumes nine lines:
;                         line 0 is the setup/blank line and lines 1-8 are
;                         the six digits.  On the title the score buffer is
;                         zero, so the band is blank and the score is hidden.
;   picture line 9        blank; NUSIZ0 returns to one copy.
;   picture lines 10-14   the visible positioner: P0 is moved from the
;                         score's X=56 to PlayerX with one divide and one
;                         HMOVE.  The ball was positioned in VBLANK and the
;                         score's HMOVE applied it.  HMP1/HMBL are zeroed
;                         just before the second HMOVE, outside the first
;                         HMOVE's 24-cycle window, so it moves only P0.
;   picture lines 15-19   the status zone: two timer-bar lines, one blank,
;                         one lives line, one blank.
;   picture lines 20-167  open zone A: 148 lines of the falling item.
;   picture lines 168-175 the player zone: the 8x8 ship and the item.
;   picture lines 176-190 open zone B: 15 lines of the falling item.
;   picture line 191      blank.
;   9 + 1 + 5 + 5 + 148 + 8 + 15 + 1 = 192.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame is scanline 259, VblankStart 0, BodyStart 37, ScoreDone 46,
;   OverscanStart 229.
;
; The RAM map (the exact map; +clean_start zeroes every byte):
;   $80      GameState     0 = title, 1 = play, 2 = over
;   $81      PlayerX       8..152, the ship's left edge
;   $82      ItemX         8..148, the ball's left edge
;   $83      ItemY         24..181, the ball's top visible line
;   $84      Score         0..255, the catch count
;   $85      Lives         3..0
;   $86      Timer         30..0, seconds
;   $87      Frame         the free-running frame counter
;   $88-$8D  sound engine scratch (SndID, SndChan, SndDefL/H, SndTabL/H)
;   $8E      PrevFire      the previous INPT4 bit 7 (0 pressed, $80 released)
;   $8F      AutoTimer     frames with no joystick direction
;   $90-$9F  sound engine state (SndPtr, SndTimer, SndStep, ...)
;   $A0-$D7  score library (ScoreDigits, ScoreRow, ScoreTmp, ScoreBuf)
;   $D8      Startup       60-frame boot settle, then the 60-frame second tick
;   $D9      ItemDir       1 normal (2 px/frame), 2 forced miss (1 px/frame)
;   $DA      CurItem       alternates 0/1: 0 normal spawn, 1 forced miss
;   $DB      ItemLine      ItemY - 15, the item's play-area line
;   $DC      TimerIdx      2 * (Timer / 3), 0..20, the bar's half-width
;   $DD-$F7  free; the deepest call uses 14 bytes, so SP can reach $F1
;   $F8-$FF  the stack (starts at $FF)
;
;   The sound library owns $88-$8D and $90-$9F, so the game variables sit
;   at $80-$87, $8E-$8F, and $D8-$DC.  No variable lives in the score
;   library, in the free area, or under the stack.
;
; The 30-second clock:
;   Startup counts 60 frames; when it reaches zero it is reloaded and Timer
;   is decremented.  30 ticks x 60 frames = 1,800 frames = 30 seconds at the
;   nominal 60 Hz NTSC frame.  2 * (Timer / 3) is the centered bar's
;   half-width, 0..20 chunks; the bar loses two chunks on each side every
;   three seconds.  When Timer reaches zero the game is over.
;
; The auto-demo (disclosed):
;   After a 60-frame boot settle the title counts 120 more frames with no
;   fire and then starts play with AutoTimer = 120, so the demo is active on
;   the first play frame.  The demo moves P0 toward ItemX at one pixel per
;   frame.  Every second item is a forced miss: it falls at one pixel per
;   frame and spawns on the far side of the player, and the demo does not
;   chase it.  The result is deterministic: the first normal item is caught,
;   then the forced items miss (a normal item can also miss when the ship
;   cannot cross the distance in time); three misses reach the over state.
;   Any joystick direction resets AutoTimer and returns control to the
;   reader.
;
; The three replaceable sections:
;   YOUR GAME — INPUT    ReadJoystick and DemoFollow: the controls.
;   YOUR GAME — UPDATE   TickTimer, MoveItem, CatchItem, MissItem, SpawnItem:
;                        the rules, scoring, and collision policy.
;   YOUR GAME — DRAW     TitleScreen, PlayScreen, OverScreen and the small
;                        graphics tables: the screen.
;   Keep the frame, the score calls, the sound calls, the state/restart
;   helpers, and the auto-demo timer.  Replace the bodies of the three
;   sections and the skeleton becomes your game.
;
; Controls:
;   Left joystick left/right moves the ship at two pixels per frame.
;   Fire starts the title and restarts the over screen (a press edge).
;
; Checkpoints (the A/X/Y/SP values are the state at the label):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   OverscanStart (229/2), StateChange (A = the new state),
;   ScoreWrite (A = the new score), ItemSpawn (A = the item's new X),
;   Catch (A = the score before the catch), Miss (A = the new Lives).
;
; Build: acme -f plain -o build/demo-72.bin \
;        lessons/part10-capstones/72-your-game/demo-72.asm
; Run:   stella build/demo-72.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
; The 42-cycle fill keeps each zone-boundary WSYNC store before the end of
; the line; a late WSYNC still halts to the next line, which is why the fill
; is fixed-length.  It is timing, not decoration.
!macro burn_line {
    !fill 21, $EA          ; 21 NOPs = 42 cycles
}

VBLANK_TIMER    = 44       ; 1 + 43 x 64 = 2753 cycles; the timer plus the
                           ; final WSYNC make the measured 37-line VBLANK
OVERSCAN_TIMER  = 36       ; 1 + 35 x 64 = 2241 cycles; the measured 30 lines

SCREEN_LINES    = 176      ; the play-area lines: picture 15..190
PLAY_TOP        = 15       ; the first picture line after the score/positioner
PLAYER_Y        = 168      ; the ship's top visible line
PLAYER_LINE     = (PLAYER_Y - PLAY_TOP) ; 153
PLAYER_MIN      = 8        ; the ship's left-edge limits
PLAYER_MAX      = 152
PLAYER_SPEED    = 2        ; human movement, pixels per frame
PLAYER_BIAS     = 3        ; the Lesson 26 player output-delay bias
BALL_BIAS       = 4        ; the ball's output delay is one clock shorter
PLAYER_HEIGHT   = 8

ITEM_TOP        = 24       ; the item's first visible line
ITEM_LINE_TOP   = (ITEM_TOP - PLAY_TOP) ; 9
ITEM_MISS       = 180      ; ItemY > 180 is a miss
ITEM_HEIGHT     = 4        ; the 4-pixel ball is four lines tall

STARTUP_FRAMES  = 60       ; one second of boot settle, then one second tick
AUTO_START      = 120      ; title frames with no fire before the auto-demo
TIMER_TICK      = 60       ; frames per Timer second
TIMER_FULL      = 30       ; the clock starts at 30 seconds
TIMER_IDX_FULL  = 20       ; 2 * (30 / 3): the centered bar's half-width

C_SCORE         = $0E      ; the score digits and the over prompt: white
C_PLAYER        = $1A      ; the ship, the item, the timer bar: gold
C_TITLE         = $1A      ; the title emblem and prompt: gold
C_TITLE_DIM     = $06      ; the prompt's off phase: dark grey
C_OVER          = $46      ; the over field: red
C_BG            = $00      ; the play and title background: black

; =============================================================================
; RAM MAP — the exact map (see the header for the full description)
; =============================================================================
GameState       = $80      ; 0 = title, 1 = play, 2 = over
PlayerX         = $81      ; 8..152
ItemX           = $82      ; 8..148
ItemY           = $83      ; 24..181
Score           = $84      ; 0..255
Lives           = $85      ; 3..0
Timer           = $86      ; 30..0 seconds
Frame           = $87      ; the free-running frame counter
PrevFire        = $8E      ; the previous INPT4 bit 7
AutoTimer       = $8F      ; frames with no joystick direction
Startup         = $D8      ; boot settle, then the 60-frame second tick
ItemDir         = $D9      ; 1 normal (2 px/frame), 2 forced (1 px/frame)
CurItem         = $DA      ; alternates 0/1
ItemLine        = $DB      ; ItemY - 15
TimerIdx        = $DC      ; 2 * (Timer / 3), 0..20
; $88-$8D and $90-$9F belong to the sound library; $A0-$D7 to the score
; library; $DD-$F7 are free; the stack starts at $FF.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; THE SHARED LIBRARIES
; =============================================================================
; The score library owns $A0-$D7 and the sound library owns $88-$8D and
; $90-$9F.  They are sourced first so the README's 4K worksheet can measure
; each library exactly from ScoreLibStart/ScoreLibEnd and SoundLibStart/
; SoundLibEnd.  The reset vector at $FFFC points at Reset below.
ScoreLibStart:
    !source "include/score.asm"
ScoreLibEnd:
SoundLibStart:
    !source "include/sound.asm"
SoundLibEnd:

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
    LDA #C_TITLE
    STA COLUPF              ; the title emblem's prompt and the play item
    LDA #C_BG
    STA COLUBK

    LDA #$21                ; reflect mode + a 4-pixel ball
    STA CTRLPF
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA VDELP0
    STA VDELP1
    STA VDELBL
    STA REFP0
    STA REFP1

    LDA #0
    STA GameState           ; state 0 = title
    STA Score
    STA Frame
    STA AutoTimer
    STA CurItem
    STA PrevFire
    LDA #STARTUP_FRAMES
    STA Startup
    LDA #TIMER_FULL
    STA Timer
    LDA #TIMER_IDX_FULL
    STA TimerIdx
    LDA #3
    STA Lives
    LDA #76                 ; the title emblem and the play start position
    STA PlayerX
    STA ItemX
    LDA #ITEM_TOP
    STA ItemY
    LDA #ITEM_LINE_TOP
    STA ItemLine
    LDA #1
    STA ItemDir

    JSR ScoreInit           ; six digits and the 48-byte buffer are zero
    JSR SoundInit           ; both audio channels are silent

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
; otherwise appear at ItemX during the score's nine lines.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA ENABL
    STA GRP0
    STA GRP1

; The score is white in every state; the state-specific background and
; playfield colours are chosen next.
    LDA #C_SCORE
    STA COLUP0
    STA COLUP1

    LDA GameState
    CMP #2
    BEQ VblankOverColors
    CMP #1
    BEQ VblankPlayColors

    ; title: black field, and the prompt blinks gold/dark grey
    LDA #C_BG
    STA COLUBK
    LDA Frame
    AND #$3F
    CMP #48
    BCS VblankTitleDim
    LDA #C_TITLE
    JMP VblankStorePF
VblankTitleDim:
    LDA #C_TITLE_DIM
VblankStorePF:
    STA COLUPF
    JMP VblankColorsDone

VblankPlayColors:
    LDA #C_BG
    STA COLUBK
    LDA #C_PLAYER
    STA COLUPF              ; the timer bar, lives and item are gold
    JMP VblankColorsDone

VblankOverColors:
    LDA #C_OVER
    STA COLUBK              ; the over field is red
    LDA Frame
    AND #$3F
    CMP #48
    BCS VblankOverDim
    LDA #C_SCORE
    JMP VblankStoreOverPF
VblankOverDim:
    LDA #C_TITLE_DIM
VblankStoreOverPF:
    STA COLUPF              ; the over prompt blinks white/dark grey
VblankColorsDone:

; -----------------------------------------------------------------------------
; 1. THE FIRE EDGE AND THE STATE UPDATE
; -----------------------------------------------------------------------------
; Fire is an edge, not a level.  ReadFire starts play from the title and
; restarts from the over state; a press during play is ignored.  The title's
; boot settle and auto-demo timer live in TitleUpdate.
    JSR ReadFire

    LDA GameState
    CMP #0
    BNE VblankNotTitle
    JSR TitleUpdate
    JMP VblankStateDone
VblankNotTitle:
    CMP #1
    BNE VblankStateDone
    JSR PlayUpdate
VblankStateDone:

; -----------------------------------------------------------------------------
; 2. THE SOUND ENGINE
; -----------------------------------------------------------------------------
    JSR SoundUpdate         ; advance both channels once per frame

; The collision latches are read in MoveItem (on the previous frame's
; overlap) and cleared here, so every frame starts with a fresh latch.
    LDA #0
    STA CXCLR

; -----------------------------------------------------------------------------
; 3. THE POSITIONERS — the ball in VBLANK, then the score's one HMOVE
; -----------------------------------------------------------------------------
; The ball is positioned before ScoreSetup; ScoreSetup's single HMOVE then
; applies P0, P1 and the ball in the same horizontal blank.  Do not touch
; HMP1/HMBL here: the TIA forbids motion-register writes for 24 cycles after
; an HMOVE.  They are zeroed much later, just before the second HMOVE.
    LDA ItemX
    CLC
    ADC #BALL_BIAS
    JSR SetCoarseBL
    JSR ScoreSetup

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
    STA NUSIZ0              ; one 8-pixel copy for the ship
    STA PF0
    STA PF1
    STA PF2
    STA ENABL
    LDA #C_PLAYER
    STA COLUP0              ; the score's pixels are already latched white
    STA WSYNC               ; consume picture line 9 -> line 10

; =============================================================================
; VISIBLE 10-14 — THE PLAY POSITIONER (five lines)
; =============================================================================
; Only P0 needs a coarse position here: the ball was positioned in VBLANK
; and the score's HMOVE applied it.  The six NOPs push the first WSYNC store
; past the start of the visible area (cycle ~23) so it really ends the line;
; +burn_line does the same for the following lines.  SetCoarseP0's divide is
; padded to a fixed length, so its body always ends on the second line; the
; trailing WSYNC then halts to the third line, where the HMOVE is strobed.
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    LDA PlayerX
    CLC
    ADC #PLAYER_BIAS
    JSR SetCoarseP0
    ; Zero HMP1/HMBL here, on the second line and many lines after the
    ; score's HMOVE, before the second HMOVE.  The TIA forbids HMPx/HMBL
    ; writes for 24 cycles after an HMOVE; doing this just after
    ; ScoreSetup's HMOVE would be inside that window.
    LDA #$00
    STA HMP1
    STA HMBL
    STA WSYNC               ; the second line -> the third line (HMOVE line)
    STA HMOVE               ; the third line's HBLANK
; COLUPF was chosen in VBLANK: gold for the title/play, white/dim for the
; over prompt.  Do not overwrite it here.
    +burn_line
    STA WSYNC               ; the HMOVE's stall ends on this line
    NOP                     ; the halt has taken effect; PlayStart is line 51

; =============================================================================
; VISIBLE 14 — THE PLAY-AREA DISPATCH (the checkpoint line)
; =============================================================================
PlayStart:                  ; checkpoint: scanline 51, picture line 14
    LDA GameState
    CMP #0
    BNE PlayNotTitle
    JMP TitleScreen
PlayNotTitle:
    CMP #2
    BNE PlayIsPlay
    JMP OverScreen
PlayIsPlay:
    JMP PlayScreen

; =============================================================================
; THE BLANK LAST LINE
; =============================================================================
; Every screen routine reaches here after its 176th line.  The last sprites
; are still latched, so clear them immediately; the colour restore and the
; 42-cycle fill push the final WSYNC past HBLANK, and the overscan starts on
; scanline 229.
PictureEnd:
    LDA #$00
    STA GRP0
    STA ENABL
    LDA #C_SCORE
    STA COLUP0
    STA COLUP1
    LDA #C_PLAYER
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
; THE STATE AND RESTART HELPERS (keep these)
; =============================================================================
; SetState is the one place that changes GameState after reset (Reset writes
; 0 directly), so the StateChange checkpoint reports every transition with
; A = the new state.
SetState:
StateChange:                ; checkpoint: A = the new state
    STA GameState
    RTS

; StartPlay is the restart path: fire from the title or the over screen, or
; the title's auto-demo.  It zeroes the score, restores three lives and the
; 30-second clock, recentres the ship, and spawns the first item.
StartPlay:
    LDA #1
    JSR SetState
    JSR ScoreClear          ; the display reads 000000
    LDA #0
    STA Score
    STA AutoTimer
    STA CurItem
    LDA #3
    STA Lives
    LDA #TIMER_FULL
    STA Timer
    LDA #TIMER_IDX_FULL
    STA TimerIdx
    LDA #STARTUP_FRAMES
    STA Startup
    LDA #76
    STA PlayerX
    JSR SpawnItem
    RTS

; ReadFire is the fire edge and the state gate.  INPT4 bit 7 is 0 when the
; button is pressed.  PrevFire starts at 0, so a button held at power-on is
; not an edge; a new press during the first second is accepted.
ReadFire:
    LDA INPT4
    AND #$80
    TAX
    EOR PrevFire
    AND #$80
    BEQ ReadFireNoEdge
    CPX #0
    BNE ReadFireNoEdge
    STX PrevFire            ; X = 0: the pressed level
    LDA GameState
    CMP #1
    BEQ ReadFireDone        ; play ignores fire
    CMP #0
    BNE ReadFireStart       ; state 2 (over) restarts at once
ReadFireStart:
    JSR StartPlay
    JMP ReadFireDone
ReadFireNoEdge:
    STX PrevFire
ReadFireDone:
    RTS

; TitleUpdate is the auto-demo timer (keep it).  Startup is the 60-frame
; boot settle; after it the title counts 120 frames with no fire.  At 120
; the demo starts play and sets AutoTimer = 120, so the first play frame is
; already under demo control.  The 3-second total keeps the title visible
; for the 2-second capture.
TitleUpdate:
    LDA Startup
    BEQ TitleCountAuto
    DEC Startup
    RTS
TitleCountAuto:
    INC AutoTimer
    LDA AutoTimer
    CMP #AUTO_START
    BCC TitleUpdateDone
    JSR StartPlay
    LDA #AUTO_START
    STA AutoTimer
TitleUpdateDone:
    RTS

; =============================================================================
; YOUR GAME — INPUT
; =============================================================================
; Replace the bodies of ReadJoystick and DemoFollow with your game's
; controls.  ReadJoystick is called once per frame in VBLANK while the game
; is in the play state.  It owns the joystick bits and the demo takeover.
; =============================================================================

; -----------------------------------------------------------------------------
; ReadJoystick — human left/right or the deterministic auto-demo
; -----------------------------------------------------------------------------
; SWCHA is active low.  P0's directions are bits 4-7; left is bit 6 and
; right is bit 7 (include/vcs.asm is the authority).  Any direction resets
; AutoTimer, so the reader takes over immediately.  With no direction for
; 120 frames the demo tracks the item at one pixel per frame.
ReadJoystick:
    LDA SWCHA
    AND #$F0                ; P0 up/down/left/right
    CMP #$F0
    BEQ JoyNoInput
    LDA #0
    STA AutoTimer           ; any direction takes over

    LDA SWCHA
    AND #$40                ; left, active low
    BNE JoyTryRight
    LDA PlayerX
    SEC
    SBC #PLAYER_SPEED
    CMP #PLAYER_MIN
    BCS JoyStoreLeft
    LDA #PLAYER_MIN
JoyStoreLeft:
    STA PlayerX
    JMP JoyDone

JoyTryRight:
    LDA SWCHA
    AND #$80                ; right, active low
    BNE JoyDone
    LDA PlayerX
    CLC
    ADC #PLAYER_SPEED
    CMP #(PLAYER_MAX + 1)
    BCC JoyStoreRight
    LDA #PLAYER_MAX
JoyStoreRight:
    STA PlayerX
    JMP JoyDone

JoyNoInput:
    INC AutoTimer
    LDA AutoTimer
    CMP #AUTO_START
    BCC JoyDone
    JSR DemoFollow
JoyDone:
    RTS

; -----------------------------------------------------------------------------
; DemoFollow — track the item at one pixel per frame while the demo runs
; -----------------------------------------------------------------------------
; The forced-miss item (ItemDir = 2) is not chased: it spawns on the far
; side of the player, so freezing the ship guarantees the miss that makes
; the over state reachable in the capture run.
DemoFollow:
    LDA ItemDir
    CMP #2
    BEQ DemoDone            ; a forced-miss item: do not chase
    LDA PlayerX
    CMP ItemX
    BEQ DemoDone
    BCC DemoRight
    DEC PlayerX
    JMP DemoClamp
DemoRight:
    INC PlayerX
DemoClamp:
    LDA PlayerX
    CMP #PLAYER_MIN
    BCS DemoHigh
    LDA #PLAYER_MIN
    STA PlayerX
    RTS
DemoHigh:
    CMP #(PLAYER_MAX + 1)
    BCC DemoDone
    LDA #PLAYER_MAX
    STA PlayerX
DemoDone:
    RTS

; =============================================================================
; YOUR GAME — UPDATE
; =============================================================================
; Replace TickTimer, MoveItem, CatchItem, MissItem and SpawnItem with your
; game's rules.  The score and sound calls are the interface to the kept
; libraries; the state change is the interface to the kept restart path.
; =============================================================================

; -----------------------------------------------------------------------------
; PlayUpdate — one frame of the game's rules
; -----------------------------------------------------------------------------
PlayUpdate:
    JSR TickTimer
    LDA GameState
    CMP #1
    BNE PlayUpdateDone      ; the clock may have ended the game
    JSR ReadJoystick        ; YOUR GAME — INPUT
    JSR MoveItem
PlayUpdateDone:
    RTS

; -----------------------------------------------------------------------------
; TickTimer — the 30-second clock and the bar's chunk count
; -----------------------------------------------------------------------------
; Startup is the 60-frame sub-second counter.  When it expires, Timer is
; decremented and Startup reloads.  2 * (Timer / 3) is the centered bar's
; half-width, 0..20 chunks; a full bar is the whole screen width.  Timer = 0
; ends the game.
TickTimer:
    DEC Startup
    BNE TickDone
    LDA #TIMER_TICK
    STA Startup
    DEC Timer
    BNE TickBar
    LDA #0
    STA TimerIdx
    LDA #2
    JSR SetState            ; time up: over
    RTS
TickBar:
    LDA Timer
    LDX #0
TickBarDiv:
    CMP #3
    BCC TickBarDone
    SBC #3
    INX
    JMP TickBarDiv
TickBarDone:
    TXA
    ASL                     ; 2 * (Timer / 3): the bar's half-width, 0..20
    STA TimerIdx
TickDone:
    RTS

; -----------------------------------------------------------------------------
; MoveItem — the catch latch, then the fall, then the miss line
; -----------------------------------------------------------------------------
; The catch latch is read first: it describes the previous frame's pixels.
; CXP0FB bit 6 is P0/ball.  A catch respawns and skips this frame's fall.
; Otherwise the item falls by FallSpeed[ItemDir] (2 or 1) and a top line past 180 is a
; miss.  ItemLine is the item's play-area line, rebuilt on every move.
MoveItem:
    LDA CXP0FB
    AND #$40                ; P0/ball collision latch
    BEQ MoveItemFall
    JSR CatchItem
    RTS

MoveItemFall:
    LDX ItemDir
    LDA FallSpeed,X
    CLC
    ADC ItemY
    STA ItemY
    SEC
    SBC #PLAY_TOP
    STA ItemLine
    CMP #(ITEM_MISS - PLAY_TOP + 1) ; 166: ItemY > 180
    BCC MoveItemDone
    JSR MissItem
MoveItemDone:
    RTS

; -----------------------------------------------------------------------------
; CatchItem — score one, play the blip, respawn
; -----------------------------------------------------------------------------
; Catch reports the score before the add; ScoreWrite reports it after.  The
; score library's ScoreAddOne owns the six-digit carry.  The catch blip is
; sound 0 on channel 0.
CatchItem:
    LDA Score
Catch:                      ; checkpoint: A = the score before this catch
    INC Score
    LDA Score
ScoreWrite:                 ; checkpoint: A = the new score
    JSR ScoreAddOne
    LDA #0                  ; sound 0: the catch blip
    LDX #0                  ; channel 0
    JSR SoundTrigger
    JSR SpawnItem
    RTS

; -----------------------------------------------------------------------------
; MissItem — lose a life, play the buzz, respawn or end the game
; -----------------------------------------------------------------------------
; Miss reports the new Lives.  The miss buzz is sound 1 on channel 1.  At
; zero lives the state changes to over; the final score stays in the band.
MissItem:
    DEC Lives
    LDA Lives
Miss:                       ; checkpoint: A = the new Lives
    PHA
    LDA #1                  ; sound 1: the miss buzz
    LDX #1                  ; channel 1
    JSR SoundTrigger
    PLA
    BNE MissRespawn
    LDA #2
    JSR SetState            ; three misses: over
    RTS
MissRespawn:
    JSR SpawnItem
    RTS

; -----------------------------------------------------------------------------
; SpawnItem — a new item at Y=24 with a deterministic pseudo-random X
; -----------------------------------------------------------------------------
; The X mixes Frame, Score and the old ItemX, so the sequence depends on
; when catches happen but is fully deterministic.  Every second item is the
; demo's forced miss: it falls at one pixel per frame and spawns on the far
; side of the player.  CurItem toggles 0/1; ItemSpawn reports the X.
SpawnItem:
    LDA #ITEM_TOP
    STA ItemY
    LDA #ITEM_LINE_TOP
    STA ItemLine
    LDA Frame
    EOR Score
    EOR ItemX
    AND #$7F
    CLC
    ADC #8                  ; 8..135
    LDX CurItem
    BEQ SpawnNormal
    LDA #2
    STA ItemDir             ; forced miss: fall one pixel per frame
    LDA PlayerX
    CMP #80
    BCC SpawnFarRight
    LDA #PLAYER_MIN         ; the player is on the right: spawn left
    JMP SpawnStore
SpawnFarRight:
    LDA #148                ; the player is on the left: spawn right
    JMP SpawnStore
SpawnNormal:
    LDY #1
    STY ItemDir             ; normal item: fall two pixels per frame
SpawnStore:
ItemSpawn:                  ; checkpoint: A = the item's new X
    STA ItemX
    LDA CurItem
    EOR #$01
    STA CurItem
    RTS

; =============================================================================
; YOUR GAME — DRAW
; =============================================================================
; Replace TitleScreen, PlayScreen, OverScreen and the graphics tables with
; your game's screen.  Each routine consumes exactly 176 picture lines and
; jumps to PictureEnd.  The score band, the positioner and the frame are
; kept.  The play screen's zones are:
;   status 5 + open A 148 + player 8 + open B 15 = 176.
; =============================================================================

; -----------------------------------------------------------------------------
; TitleScreen — a gold emblem and a blinking bar prompt
; -----------------------------------------------------------------------------
; P0 is the 8x12 emblem at PlayerX (76); the prompt is three PF bytes at
; play lines 100-103.  COLUPF blinks between gold and dark grey, so the
; prompt is always visible but changes brightness.  The score band above is
; blank because ScoreBuf is still the zeroed buffer from ScoreInit.
TitleScreen:
    LDX #0
    LDA #0
    STA GRP0
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC               ; consume picture line 14 -> line 15

TitleLoop:
    ; The prompt path writes PF early enough for the playfield's first pixel.
    ; COLUPF was already chosen in VBLANK (gold or dark grey), so the whole
    ; bar has one colour and the blink never tears it.
    CPX #100
    BCC TitleNotPrompt
    CPX #104
    BCS TitleNotPrompt
    LDA #$AA                ; a dashed 4-pixel-chunk bar
    STA PF0
    STA PF1
    STA PF2
    LDA #0
    STA GRP0
    JMP TitleLineDone

TitleNotPrompt:
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    CPX #30
    BCC TitleNoEmblem
    CPX #42
    BCS TitleNoEmblem
    TXA
    SEC
    SBC #30
    TAY
    LDA EmblemGfx,Y
    STA GRP0
    JMP TitleLineDone
TitleNoEmblem:
    LDA #0
    STA GRP0

TitleLineDone:
    STA WSYNC
    INX
    CPX #SCREEN_LINES
    BNE TitleLoop
    JMP PictureEnd

; -----------------------------------------------------------------------------
; PlayScreen — status, open A, player, open B
; -----------------------------------------------------------------------------
PlayScreen:
    STA WSYNC               ; consume picture line 14 -> line 15
    ; --- status zone: play lines 0-4 --------------------------------
    ; The five lines are written out instead of looped so the playfield
    ; stores land early: PF0 at cycle ~10, PF1 at ~17, PF2 at ~24, each
    ; before its own deadline.  A loop with three comparisons pushed PF1
    ; past its deadline and tore the bar.
    LDY TimerIdx            ; line 0: the timer bar
    LDA TimerBarPF0,Y
    STA PF0
    LDA TimerBarPF1,Y
    STA PF1
    LDA TimerBarPF2,Y
    STA PF2
    LDA #0
    STA GRP0
    STA ENABL
    STA WSYNC

    LDY TimerIdx            ; line 1: the timer bar
    LDA TimerBarPF0,Y
    STA PF0
    LDA TimerBarPF1,Y
    STA PF1
    LDA TimerBarPF2,Y
    STA PF2
    STA WSYNC

    LDA #0                  ; line 2: blank the playfield
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA ENABL
    STA WSYNC

    LDY Lives               ; line 3: one chunk per life
    LDA LivesPF,Y
    STA PF0
    LDA #0
    STA PF1
    STA PF2
    STA GRP0
    STA ENABL
    STA WSYNC

    LDA #0                  ; line 4: blank the playfield
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA ENABL
    STA WSYNC

    ; --- open zone A: play lines 5-152 (148 lines) -------------------
    LDX #5
    LDA #0
    STA GRP0
PlayOpenALoop:
    LDA #0
    CPX ItemLine
    BCC PlayOpenANoItem
    TXA
    SEC
    SBC ItemLine
    CMP #ITEM_HEIGHT
    BCS PlayOpenAClear
    LDA #2
    JMP PlayOpenANoItem
PlayOpenAClear:
    LDA #0
PlayOpenANoItem:
    STA ENABL
    STA WSYNC
    INX
    CPX #PLAYER_LINE
    BNE PlayOpenALoop

    ; --- player zone: play lines 153-160 (8 lines) -------------------
    LDY #0
PlayPlayerLoop:
    LDA PlayerGfx,Y
    STA GRP0                ; the first store, before P0's pixel time
    LDA #0
    CPX ItemLine
    BCC PlayPlayerNoItem
    TXA
    SEC
    SBC ItemLine
    CMP #ITEM_HEIGHT
    BCS PlayPlayerClear
    LDA #2
    JMP PlayPlayerNoItem
PlayPlayerClear:
    LDA #0
PlayPlayerNoItem:
    STA ENABL
    STA WSYNC
    INX
    INY
    CPY #PLAYER_HEIGHT
    BNE PlayPlayerLoop

    ; --- open zone B: play lines 161-175 (15 lines) ------------------
    LDA #0
    STA GRP0
PlayOpenBLoop:
    LDA #0
    CPX ItemLine
    BCC PlayOpenBNoItem
    TXA
    SEC
    SBC ItemLine
    CMP #ITEM_HEIGHT
    BCS PlayOpenBClear
    LDA #2
    JMP PlayOpenBNoItem
PlayOpenBClear:
    LDA #0
PlayOpenBNoItem:
    STA ENABL
    STA WSYNC
    INX
    CPX #SCREEN_LINES
    BNE PlayOpenBLoop
    JMP PictureEnd

; -----------------------------------------------------------------------------
; OverScreen — the red field and a blinking bar prompt
; -----------------------------------------------------------------------------
OverScreen:
    LDX #0
    LDA #0
    STA GRP0
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC               ; consume picture line 14 -> line 15
OverLoop:
    CPX #100
    BCC OverNotPrompt
    CPX #104
    BCS OverNotPrompt
    LDA #$AA
    STA PF0
    STA PF1
    STA PF2
    JMP OverLineDone
OverNotPrompt:
    LDA #0
    STA PF0
    STA PF1
    STA PF2
OverLineDone:
    STA WSYNC
    INX
    CPX #SCREEN_LINES
    BNE OverLoop
    JMP PictureEnd

; =============================================================================
; GRAPHICS TABLES (replace these with your game's shapes)
; =============================================================================
; The ship is 8x8, top row first, because the play kernel indexes it with
; the picture line.  (The score font is bottom-up because its kernel counts
; rows down.)
PlayerGfx:
    !byte $18, $3C, $7E, $FF, $FF, $E7, $C3, $81
    ;     ..##....  .####...  ######..  ########
    ;     ########  ###..###  ##....##  #......#

; The title emblem is 8x12, drawn at play lines 30-41.  The dashed bar at
; play lines 100-103 is the "PRESS FIRE" prompt; it has no letters.
EmblemGfx:
    !byte $18, $18, $3C, $3C, $7E, $FF, $FF, $7E, $3C, $3C, $18, $18

; The timer bar is centered: n chunks on each side of the screen centre, for
; n = 0..20.  The lit left-half chunks run from (20-n) to 19; reflect mode
; draws their mirror on the right half.  PF0 bit 4 is the leftmost chunk,
; PF1 bit 7 follows it, and PF2 bit 0 is chunk 12.
TimerBarPF0:
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $80, $C0, $E0, $F0
TimerBarPF1:
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $03
    !byte $07, $0F, $1F, $3F, $7F, $FF, $FF, $FF, $FF, $FF
TimerBarPF2:
    !byte $00, $80, $C0, $E0, $F0, $F8, $FC, $FE, $FF, $FF, $FF
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF

; The lives markers: 0..3 chunks lit from the left.  PF0 bit 4 is leftmost.
LivesPF:
    !byte $00, $10, $30, $70

; =============================================================================
; THE ITEM'S FALL SPEED (indexed by ItemDir)
; =============================================================================
; Normal items fall two pixels per frame; the demo's forced-miss items fall
; one, slowly, so the forced miss lands near the 180-frame design target.
; The slot at 0 is unused so ItemDir can be 1 or 2 directly.
FallSpeed:
    !byte 0, 2, 1

; =============================================================================
; THE SOUND TABLE (keep the table shape; change the two sounds)
; =============================================================================
; Each 8-byte record is AUDC, Rate, Steps|loop, Priority, FreqL/H, VolL/H.
; Sound 0 is the catch blip: a div-6 tone, four steps at four frames per step
; (16 frames).  Sound 1 is the miss buzz: white noise, five steps at eight
; frames per step (40 frames).
SoundTable:
    ; sound 0: the catch blip
    !byte $0C, 4, $04, 4
    !word CatchFreq, CatchVol
    ; sound 1: the miss buzz
    !byte $08, 8, $05, 6
    !word MissFreq, MissVol

CatchFreq:
    !byte 12, 8, 5, 3
CatchVol:
    !byte 15, 12, 8, 3
MissFreq:
    !byte 16, 22, 28, 31, 31
MissVol:
    !byte 12, 12, 10, 7, 0

; =============================================================================
; POSITIONING — the divide-by-15 routine from Lesson 26
; =============================================================================
; SetCoarseP0 is the visible-area player positioner.  The divide loop takes
; a variable number of cycles, so a fixed 60-cycle pad follows it.  The
; divide+pad is 88..138 cycles: it starts on the line after the WSYNC and
; ends 12..62 cycles into the second line.  The caller's HMP1/HMBL clear
; adds 8 cycles (20..70 into the second line) and its trailing WSYNC halts
; to the third line, where the HMOVE is strobed.  A = the target TIA X plus
; PLAYER_BIAS.
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
    ; A fixed 60-cycle pad keeps the routine's line count constant: the
    ; divide is 28..78 cycles, so 28+60 = 88 and 78+60 = 138.  The body
    ; starts on the line after the WSYNC and ends 12..62 cycles into the
    ; second line, never reaching the third.  The caller's clear adds 8
    ; cycles and its trailing WSYNC halts to the third line, where the
    ; HMOVE is strobed.
    +burn_line
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    RTS

; SetCoarseBL positions the ball in VBLANK.  It does not strobe HMOVE: the
; score's HMOVE applies the ball's fine offset together with P0 and P1.
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
; THE ROM VECTORS
; =============================================================================
    * = $FFFA
    !word Reset             ; NMI
    !word Reset             ; RESET
    !word Reset             ; IRQ
