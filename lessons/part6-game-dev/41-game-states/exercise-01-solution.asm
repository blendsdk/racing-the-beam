; =============================================================================
; LESSON 41 — EXERCISE 1 SOLUTION: Pause
; =============================================================================
; Part 6: Game Development
;
; The exercise:
;   Add a fourth state, PAUSE (3), toggled by SELECT during play.  The game
;   freezes (P0 and the ball keep their positions) and the status bar blinks.
;   Expected: StateChange A=3, then A=1 on the next SELECT; BallY does not
;   change while the state is 3.
;
; The changes from the main ROM:
;   1. Read SWCHB bit 1 (SELECT, 0 = pressed) and edge-detect it into
;      NewSelect ($A6), the same way the fire edge is built.
;   2. The play state checks the SELECT edge first: a press enters state 3.
;   3. PauseState runs no game logic; its SELECT edge resumes with state 1.
;   4. SetState takes a second argument in X.  X=0 is a fresh entry: reset
;      Hits, the ball, and P0's column.  X=1 is a resume: keep them.  The
;      pause exit uses X=1, so the frozen ball continues where it stopped.
;   5. With GameState=3 the visible kernel is still the play layout, but the
;      status bar's PF bytes are zeroed while Frame bit 5 is clear, which is
;      the blink.
;   6. The resume path clears PrevColl.  The VBLANK collision reader kept
;      running during the pause and consumed the pause frame's edge; clearing
;      the tracker lets the frozen ball's contact score as a fresh hit after
;      the resume.
;
; What stays the same:
;   The title/play/over layouts, the auto-demo, the collision logic, the
;   beep, and the 262-line frame skeleton are the main ROM's.
;
; Checkpoints: the main ROM's, plus StateChange A=3 on pause and A=1 on
;   resume.  BallStep stops while paused and resumes at the same BallY.
;
; Build: acme -f plain -o build/ex41-1.bin \
;        lessons/part6-game-dev/41-game-states/exercise-01-solution.asm
; Run:   stella build/ex41-1.bin
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

TITLE_DEMO_FRAMES = 180  ; title frames before the auto-demo starts play
PLAY_DEMO_DELAY   = 30   ; frames after the first hit before P0 slides away

P0_Y           = 140     ; P0's top visible row
P0_HEIGHT      = 16
P0_MIN_X       = 8
P0_MAX_X       = 144
BALL_START_Y   = 24      ; the ball's first visible row at spawn
BALL_HEIGHT    = 8
BALL_MISS_Y    = 181     ; the first Y past the play area
BALL_START_X   = 80

TITLE_BLOCK    = $F0     ; PF2 bits 4-7: chunks 16-19, a 32-px center block

BEEP_FRAMES    = 8
BEEP_PITCH     = $0A     ; AUDF 10 on AUDC $0C: a short, bright hit

C_GOLD         = $1A
C_RED          = $42
C_WHITE        = $0E
C_BG           = $02

; --- Lesson variables (RAM $80-$9F; +clean_start zeroes them) ---
GameState   = $80   ; 0=title, 1=play, 2=over
StateTimer  = $81   ; the state's countdown: title auto-start / play slide
Hits        = $82   ; new contacts this game, clamped at 15
PlayerX     = $83   ; P0's left edge, 8..144
BallY       = $84   ; the ball's top row, 24..181
BallX       = $85   ; the ball's left edge, set when it spawns
BeepTimer   = $86   ; frames of beep remaining
BeepPitch   = $87   ; AUDF for the beep
Frame       = $88   ; free-running 8-bit frame counter (blinks use bit 5)
PrevFire    = $89   ; fire state last frame (1 = pressed)
PrevColl    = $8A   ; last frame's P0-ball latch bit ($40 or 0)
AutoMove    = $8B   ; 1 after the demo timer expires: P0 slides right
BallEn      = $8C   ; $8C-$9C: 17 ball-enable bytes for lines 140-156
HitPF0      = $9D   ; the hit bar's three playfield bytes for this frame
HitPF1      = $9E
HitPF2      = $9F
NewFire     = $A0   ; this frame's fire 0 -> 1 edge
CollTmp     = $A1   ; the P0-ball latch and then its 0 -> 1 edge
FirePF0     = $A2   ; the over screen's blinking fire bar, precomputed
FirePF1     = $A3
FirePF2     = $A4
PrevSelect  = $A5   ; SELECT state last frame (1 = pressed)
NewSelect   = $A6   ; this frame's SELECT 0 -> 1 edge
;
; The shared score library is not used in this lesson, so the rest of
; $A7-$D7 is free.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the first scene: title, with the play positions already sensible ------
    LDA #BALL_START_X
    STA PlayerX
    STA BallX
    LDA #BALL_START_Y
    STA BallY
    LDA #BEEP_PITCH
    STA BeepPitch
    LDX #0                  ; X=0: a fresh state entry
    LDA #0
    JSR SetState            ; A=0: title; SetState starts its timer

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
; 1. THE FRAME COUNTER — the blink clock
; -----------------------------------------------------------------------------
; Bit 5 toggles every 32 frames, so Frame & $20 is high for 32 frames and low
; for 32.  It drives the title's bottom bar and the over screen's fire bar.
    INC Frame

; -----------------------------------------------------------------------------
; 2. THE BEEP'S CLOCK — the last frame writes silence
; -----------------------------------------------------------------------------
    LDA BeepTimer
    BEQ BeepDone
    DEC BeepTimer
    BNE BeepDone
    LDA #$00
    STA AUDV0
BeepDone:

; -----------------------------------------------------------------------------
; 3. READ FIRE — one action per 0 -> 1 edge
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  EOR flips it to 1 = pressed; NewFire
; keeps only the press edge so holding the button does not repeat a
; transition.
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
; 3b. READ SELECT — the pause toggle's 0 -> 1 edge
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  The same EOR/edge pattern turns it
; into one action per press.  The bit table is in include/vcs.asm.
    LDA SWCHB
    AND #$02
    EOR #$02                ; 1 = pressed
    STA NewSelect
    EOR PrevSelect
    AND NewSelect
    STA NewSelect
    LDA SWCHB
    AND #$02
    EOR #$02
    STA PrevSelect

; -----------------------------------------------------------------------------
; 4. READ THE COLLISION LATCH — the previous visible frame's P0-ball contact
; -----------------------------------------------------------------------------
; A latch stays set until CXCLR; reading it here describes frame N while the
; program builds frame N+1 (the one-frame latency from Lesson 38).  The mask
; keeps bit 6 ($40) and the edge is a 0 -> 1 change against last frame.
    LDA CXP0FB
ReadCX:                     ; checkpoint: A = CXP0FB
    AND #$40                ; bit 6 = P0-ball
    STA CollTmp             ; the current latch bit
    EOR PrevColl
    AND CollTmp
    TAX                     ; X = the 0 -> 1 edge ($40 or 0)
    LDA CollTmp
    STA PrevColl
    STX CollTmp             ; CollTmp = the new-contact bit
    LDA #$00
    STA CXCLR
CXClear:                    ; checkpoint: the latches are cleared

; -----------------------------------------------------------------------------
; 5. DISPATCH THE STATE — one of three per-frame programs
; -----------------------------------------------------------------------------
    LDA GameState
    CMP #1
    BEQ DoPlayState
    CMP #2
    BEQ DoOverState
    CMP #3
    BEQ DoPauseState
    JMP TitleState
DoPlayState:
    JMP PlayState
DoOverState:
    JMP OverState
DoPauseState:
    JMP PauseState
StateDone:

; -----------------------------------------------------------------------------
; 6. THE HIT BAR'S THREE BYTES — computed once, drawn by the play/over kernel
; -----------------------------------------------------------------------------
    LDA Hits
    ASL                     ; Hits * 3: three playfield bytes per entry
    CLC
    ADC Hits
    TAX
    LDA HitBarPF,X
    STA HitPF0
    LDA HitBarPF+1,X
    STA HitPF1
    LDA HitBarPF+2,X
    STA HitPF2

; -----------------------------------------------------------------------------
; 6a. THE PAUSE SCREEN'S BLINK — the status bar goes dark every other phase
; -----------------------------------------------------------------------------
; The paused play kernel uses HitPF0/1/2 unchanged; zeroing them here is the
; blink.  Frame bit 5 is the same clock as the title bar and the fire bar.
    LDA GameState
    CMP #3
    BNE PauseBarDone
    LDA Frame
    AND #$20
    BNE PauseBarDone
    LDA #$00
    STA HitPF0
    STA HitPF1
    STA HitPF2
PauseBarDone:

; -----------------------------------------------------------------------------
; 6b. THE OVER SCREEN'S FIRE BAR — precomputed, so its first line is solid
; -----------------------------------------------------------------------------
; The 15-chunk pattern is either present or dark, depending on Frame bit 5.
; Computing it here leaves the visible kernel with three short stores.
    LDA Frame
    AND #$20
    BEQ FireBarOff
    LDA HitBarPF+45
    STA FirePF0
    LDA HitBarPF+46
    STA FirePF1
    LDA HitBarPF+47
    STA FirePF2
    JMP FireBarDone
FireBarOff:
    LDA #$00
    STA FirePF0
    STA FirePF1
    STA FirePF2
FireBarDone:

; -----------------------------------------------------------------------------
; 7. THE BALL-ENABLE BYTES FOR LINES 140-156
; -----------------------------------------------------------------------------
; The play kernel's middle zone draws P0 and the ball on the same 17 lines.
; Precomputing the ball's enable byte keeps that loop to two stores, so both
; land in HBLANK (the timing note is in the walkthrough).  $02 enables the
; ball; $00 leaves it off.
    LDX #0
BallEnLoop:
    TXA
    CLC
    ADC #P0_Y               ; the line number, 140 + X
    SEC
    SBC BallY
    CMP #BALL_HEIGHT
    LDA #$00
    BCS BallEnOff
    LDA #$02
BallEnOff:
    STA BallEn,X
    INX
    CPX #(P0_HEIGHT + 1)    ; 17 entries: lines 140 through 156
    BNE BallEnLoop

; -----------------------------------------------------------------------------
; 8. POSITION P0 AND THE BALL, THEN STROBE ONE HMOVE
; -----------------------------------------------------------------------------
; Both coarse resets happen here in VBLANK; the fine values sit in HMP0/HMBL
; until the single HMOVE applies them.  The ball's output delay is one clock
; shorter than a player's (Lesson 29), so its target needs one extra pixel.
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA BallX
    CLC
    ADC #(POS_BIAS + 1)
    JSR SetCoarseBL
    STA WSYNC
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed (next line, cycle 3)

; -----------------------------------------------------------------------------
; 9. COLORS, SIZES, AND PLAYFIELD CONTROL
; -----------------------------------------------------------------------------
    LDA #C_RED
    STA COLUP0              ; P0 is red
    LDA #C_GOLD
    STA COLUPF              ; the emblem, bars, and the ball are gold
    LDA #C_BG
    STA COLUBK
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP1
    STA ENAM0
    STA ENAM1
    LDA #$01
    STA CTRLPF              ; reflect the playfield; ball one pixel wide

; --- the over state preloads its first visible line -------------------------
; BodyStart is scanline 37 cycle 5, but the left-half playfield slots are
; already being drawn before the over kernel's first stores could reach them.
; Loading the background and the top bar here, in VBLANK, makes line 0 as
; solid as lines 1-15.  The other states keep the $02 background and dark PF.
    LDA GameState
    CMP #2
    BNE OverPreloadDone
    LDA #C_RED
    STA COLUBK
    LDA HitPF0
    STA PF0
    LDA HitPF1
    STA PF1
    LDA HitPF2
    STA PF2
OverPreloadDone:

    +wait_timer

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
    LDA #$00
    STA VBLANK

BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDA GameState
    CMP #1
    BEQ DoPlayVisible
    CMP #2
    BEQ DoOverVisible
    CMP #3
    BEQ DoPlayVisible       ; pause draws the play layout, frozen
    JMP TitleVisible
DoPlayVisible:
    JMP PlayVisible
DoOverVisible:
    JMP OverVisible

; =============================================================================
; TITLE KERNEL — 192 lines: 64 + 16 + 8 + 16 + 8 + 16 + 32 + 8 + 24
; =============================================================================
TitleVisible:
    LDA #$00
    STA GRP0                ; the title is playfield only
    STA GRP1
    STA ENABL
    STA ENAM0
    STA ENAM1
    STA PF0
    STA PF1
    STA PF2

; --- visible 0-63: background ---
    LDY #64
TitleTop:
    STA WSYNC
    DEY
    BNE TitleTop

; --- visible 64-79: block 1 ---
    LDA #TITLE_BLOCK
    STA PF2                 ; chunks 16-19 (mirrored: a 32-px center block)
    LDY #16
TitleBlock1:
    STA WSYNC
    DEY
    BNE TitleBlock1

; --- visible 80-87: gap ---
    LDA #$00
    STA PF2
    LDY #8
TitleGap1:
    STA WSYNC
    DEY
    BNE TitleGap1

; --- visible 88-103: block 2 ---
    LDA #TITLE_BLOCK
    STA PF2
    LDY #16
TitleBlock2:
    STA WSYNC
    DEY
    BNE TitleBlock2

; --- visible 104-111: gap ---
    LDA #$00
    STA PF2
    LDY #8
TitleGap2:
    STA WSYNC
    DEY
    BNE TitleGap2

; --- visible 112-127: block 3 ---
    LDA #TITLE_BLOCK
    STA PF2
    LDY #16
TitleBlock3:
    STA WSYNC
    DEY
    BNE TitleBlock3

; --- visible 128-159: background ---
    LDA #$00
    STA PF2
    LDY #32
TitleMiddle:
    STA WSYNC
    DEY
    BNE TitleMiddle

; --- visible 160-167: the blinking 15-chunk bar ---
    LDA Frame
    AND #$20                ; high for 32 frames, low for 32
    BEQ TitleBarOff
    LDA HitBarPF+45         ; entry 15: PF0=$F0, PF1=$FF, PF2=$07
    STA PF0
    LDA HitBarPF+46
    STA PF1
    LDA HitBarPF+47
    STA PF2
    JMP TitleBarLines
TitleBarOff:
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
TitleBarLines:
    LDY #8
TitleBottomBar:
    STA WSYNC
    DEY
    BNE TitleBottomBar

; --- visible 168-191: background ---
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #24
TitleBottom:
    STA WSYNC
    DEY
    BNE TitleBottom
    JMP FrameEnd

; =============================================================================
; PLAY KERNEL — 192 lines: 16 status + 1 + 123 + 16 + 1 + 35
; =============================================================================
PlayVisible:
; --- visible 0-15: the 16-line status bar (N chunks per half) ---
    LDA HitPF0
    STA PF0
    LDA HitPF1
    STA PF1
    LDA HitPF2
    STA PF2
    LDY #16
PlayStatus:
    STA WSYNC
    DEY
    BNE PlayStatus

; --- visible 16: the status bar ends; clear the playfield and sprites ------
; All five stores happen before PF0's first visible slot (cycle 22.7), so
; line 16 shows the play area, not a partial status line.
    LDA #$00
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA WSYNC               ; end visible line 16

; --- visible 17-139: the ball alone; P0 is off ---
    LDX #(P0_Y - 123)       ; 17: one line was drawn above
PlayTop:
    TXA
    SEC
    SBC BallY
    CMP #BALL_HEIGHT
    LDA #$00
    BCS PlayTopOff
    LDA #$02
PlayTopOff:
    STA ENABL
    STA WSYNC
    INX
    CPX #P0_Y
    BNE PlayTop

; --- visible 140-155: P0 (16 rows) and the ball share these lines ---
    LDA #$FF
    STA GRP0                ; P0 is on for its 16 rows
    LDX #0
PlayBoth:
    LDA BallEn,X            ; precomputed: $02 where the ball is present
    STA ENABL
    STA WSYNC
    INX
    CPX #P0_HEIGHT
    BNE PlayBoth

; --- visible 156: P0's last row is over; clear it and draw the ball once --
    LDA #$00
    STA GRP0                ; before P0's first visible clock
    LDA BallEn+P0_HEIGHT    ; entry 16 covers line 156
    STA ENABL
    STA WSYNC               ; end visible line 156

; --- visible 157-191: the ball alone again ---
    LDX #(P0_Y + P0_HEIGHT + 1)   ; 157
PlayBottom:
    TXA
    SEC
    SBC BallY
    CMP #BALL_HEIGHT
    LDA #$00
    BCS PlayBottomOff
    LDA #$02
PlayBottomOff:
    STA ENABL
    STA WSYNC
    INX
    CPX #192
    BNE PlayBottom
    JMP FrameEnd

; =============================================================================
; OVER KERNEL — 192 lines: 16 bar + 144 red + 8 fire bar + 24 red
; =============================================================================
OverVisible:
    LDA #$00
    STA GRP0                ; the over screen is playfield only
    STA GRP1
    STA ENABL
    STA ENAM0
    STA ENAM1

; --- visible 0-15: the final hit bar (PF and COLUBK preloaded in VBLANK) ---
    LDY #16
OverBar:
    STA WSYNC
    DEY
    BNE OverBar

; --- visible 16-159: the red field; COLUPF changes to white for the fire bar
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA #C_WHITE
    STA COLUPF
    LDY #(160 - 16)
OverField:
    STA WSYNC
    DEY
    BNE OverField

; --- visible 160-167: the blinking "fire" bar (precomputed, 15 chunks) ---
    LDA FirePF0
    STA PF0
    LDA FirePF1
    STA PF1
    LDA FirePF2
    STA PF2
    LDY #8
OverFire:
    STA WSYNC
    DEY
    BNE OverFire

; --- visible 168-191: the red field again ---
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #24
OverBottom:
    STA WSYNC
    DEY
    BNE OverBottom
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
; TITLE STATE — the auto-demo clock and the fire transition
; =============================================================================
; Any joystick direction restarts the countdown, so an untouched console
; enters play after TITLE_DEMO_FRAMES; fire enters play at once.  The
; transition goes through SetState, which resets the play variables.
TitleState:
    LDA SWCHA
    AND #$F0                ; P0 up/down/left/right (0 = pressed)
    CMP #$F0
    BEQ TitleNoInput
    LDA #TITLE_DEMO_FRAMES
    STA StateTimer
TitleNoInput:
    LDA StateTimer
TimerRead:                  ; checkpoint: A = StateTimer, the state's clock
    BEQ TitleStart
    DEC StateTimer
    BNE TitleCheckFire
    ; The decrement reached zero: 180 title frames have passed.
    JMP TitleStart
TitleCheckFire:
    LDA NewFire
    BNE TitleStart
    JMP StateDone
TitleStart:
    LDX #0                  ; X=0: a fresh play entry resets the game
    LDA #1
    JSR SetState
    JMP StateDone

; =============================================================================
; PLAY STATE — movement, the hit, the fall, and the miss
; =============================================================================
PlayState:
; --- SELECT first: the pause toggle ------------------------------------------
    LDA NewSelect
    BEQ PlayNoPause
    LDX #0                  ; X=0: pause entry has no reset work
    LDA #3
    JSR SetState
    JMP StateDone
PlayNoPause:

; --- the auto-demo's slide timer: armed by the first hit ---
    LDA StateTimer
    BEQ PlayTimerDone
    DEC StateTimer
    BNE PlayTimerDone
    LDA #1
    STA AutoMove
PlayTimerDone:

; --- P0's motion: the joystick, or the auto-demo's slide ---
    LDA SWCHA
    AND #$C0                ; P0 left (bit 6) and right (bit 7)
    CMP #$C0
    BNE PlayManual
    LDA AutoMove
    BEQ PlayMoveDone
    JMP MoveRight
PlayManual:
    LDA #$00
    STA AutoMove            ; a manual direction takes control
    LDA SWCHA
    AND #$40                ; left
    BNE PlayNoLeft
    JMP MoveLeft
PlayNoLeft:
    LDA SWCHA
    AND #$80                ; right
    BNE PlayMoveDone
    JMP MoveRight
PlayMoveDone:

; --- a new P0-ball contact: score, beep, respawn ---
    LDA CollTmp
    BEQ NoHit
    INC Hits
    LDA Hits
    CMP #16
    BCC HitsStored
    LDA #15                 ; the bar has only 15 chunks
HitsStored:
    STA Hits
HitStep:                    ; checkpoint: A = the new hit count
    JSR BeepStart
    LDA #BALL_START_Y       ; respawn at the top...
    STA BallY
    LDA PlayerX             ; ...in P0's column
    STA BallX
    LDA Hits
    CMP #1
    BNE NoHit
    LDA #PLAY_DEMO_DELAY    ; after the first hit, arm the slide
    STA StateTimer
NoHit:

; --- the ball falls one pixel per frame; past 180 ends the game ---
    INC BallY
    LDA BallY
BallStep:                   ; checkpoint: A = the new BallY
    CMP #BALL_MISS_Y
    BCC PlayDone
    LDX #0                  ; X=0: a fresh over entry
    LDA #2
    JSR SetState
PlayDone:
    JMP StateDone

MoveLeft:
    DEC PlayerX
    LDA PlayerX
    CMP #P0_MIN_X
    BCS MoveDone
    LDA #P0_MIN_X
    STA PlayerX
    JMP MoveDone
MoveRight:
    INC PlayerX
    LDA PlayerX
    CMP #(P0_MAX_X + 1)
    BCC MoveDone
    LDA #P0_MAX_X
    STA PlayerX
MoveDone:
    JMP PlayMoveDone

; =============================================================================
; OVER STATE — fire returns to the title
; =============================================================================
OverState:
    LDA NewFire
    BEQ OverDone
    LDX #0                  ; X=0: a fresh title entry restarts its timer
    LDA #0
    JSR SetState
OverDone:
    JMP StateDone

; =============================================================================
; PAUSE STATE — SELECT resumes exactly where the game stopped
; =============================================================================
; No timer, no movement, no fall, no collision: the state's only job is to
; wait for the next SELECT edge.  The visible kernel still draws the play
; layout, so the frozen P0 and ball stay on screen.
PauseState:
    LDA NewSelect
    BEQ PauseDone
    LDX #1                  ; X=1: resume; keep Hits, BallY, and PlayerX
    LDA #1
    JSR SetState
PauseDone:
    JMP StateDone

; =============================================================================
; SetState — the one door into a state
; =============================================================================
; A = the new state, X = the entry flavour:
;   X=0  fresh entry.  Entering play resets the game: Hits, the timers, the
;        ball, and P0's column all start fresh.
;   X=1  resume.  Entering play keeps those values, which is what the pause
;        exit needs: the ball continues from the row where it stopped.
; Every other state ignores X.
SetState:
    STA GameState
StateChange:                ; checkpoint: A = the new state
    CMP #1
    BEQ SetPlay
    CMP #2
    BEQ EnterOver
    CMP #3
    BEQ EnterPause
    ; --- state 0: title ---
    LDA #TITLE_DEMO_FRAMES
    STA StateTimer
    RTS
SetPlay:
    CPX #1
    BEQ EnterPlayResume
    ; --- a fresh game ---
    LDA #$00
    STA Hits
    STA StateTimer
    STA AutoMove
    STA PrevColl
    LDA #BALL_START_X
    STA PlayerX
    STA BallX
    LDA #BALL_START_Y
    STA BallY
EnterPlayResume:
    ; The VBLANK latch reader already consumed the pause frame's contact:
    ; PrevColl holds $40, so the frozen ball's still-set latch would look
    ; like an old edge on the first resumed frame.  Clearing PrevColl lets
    ; the next read register that contact as a fresh hit.
    LDA #$00
    STA PrevColl
    RTS
EnterPause:
    RTS
EnterOver:
    LDA #$00
    STA StateTimer
    RTS

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
; COARSE POSITIONING — P0 and the ball, one HMOVE at the end
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
; HIT-BAR TABLE — N chunks from the left, three playfield bytes per entry
; =============================================================================
; PF0 bits 4-7 are the first four chunks (bit 4 leftmost); PF1 bits 7-0 are
; the next eight (bit 7 leftmost); PF2 bits 0-2 are the last three (bit 0 is
; leftmost, because PF2's bit order is reversed).  CTRLPF=$01 mirrors the
; same chunks from the right edge, so every count is "per half".
HitBarPF:
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
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
