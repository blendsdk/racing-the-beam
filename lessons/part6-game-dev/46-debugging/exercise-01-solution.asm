; =============================================================================
; LESSON 46 — EXERCISE 1 SOLUTION: Fix the Sticky Collision — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; EXERCISE 1: the mode-0 buggy path reads CXP0FB and skips CXCLR, so the
; TIA's sticky latch keeps the red collision band lit after P0 leaves the
; wall.  This solution writes CXCLR after every read, in every mode, and
; starts with BugOn=0 so the green bug/fix cell matches the clear band.
;
; The changes from the main ROM:
;   1. The collision block is unconditional: after CXP0FB is read and bit 7
;      is stored in CollisionBit, the program strobes CXCLR every frame.
;      The ModeVal/BugOn test and the skip branch are gone.
;   2. Reset stores BugOn=0 instead of 1.  The band is clear from the first
;      frame after the auto-demo's contact, and the bug/fix cell is green.
;   3. Modes 1 and 2 are otherwise unchanged; their bugs are exercises 2
;      and 3.
;
; Checkpoints: ReadCX (A = CXP0FB) at $F12F; CXClear (A = 0, every frame) at
;   $F137; OverscanStart 229 at $F32C; StartFrame 259 at $F031.  The labels
;   are the main ROM's; the addresses move because this file has less code.
;
; Build: acme -f plain -o build/ex46-1.bin \
;        lessons/part6-game-dev/46-debugging/exercise-01-solution.asm
; Run:   stella build/ex46-1.bin
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

PLAYER_Y       = 140     ; P0's first visible row (game logic)
PLAYER_START_X = 88      ; P0's left edge at power-on and in demo phase 3
PLAYER_HOLD_X  = 88      ; the auto-demo's right-hand resting place
PLAYER_MIN_X   = 8       ; deep enough into the 16-pixel wall to collide
PLAYER_MAX_X   = 136     ; the joystick's right limit
P1_X           = 80      ; P1's left edge (fixed)
BALL_X         = 80      ; the ball's left edge (fixed)
BALL_Y         = 140     ; the ball's first row (fixed)

DEMO_LEFT_HOLD = 8       ; frames parked at the left wall
DEMO_HOLD      = 240     ; frames parked at PLAYER_HOLD_X (the capture window)
BEEP_FRAMES    = 2       ; a two-frame tick
BEEP_PITCH     = $08     ; AUDF 8 on AUDC $0C: a short, bright beep

MODE0_PF0      = $C0     ; PF0 bits 6-7: chunks 2-3, X=8-15
MODE1_PF1      = $C0     ; PF1 bits 6-7: chunks 4-5, X=16-23
MODE2_PF1      = $30     ; PF1 bits 4-5: chunks 6-7, X=24-31
BUG_PF0        = $C0     ; the bug/fix cell: chunks 2-3, X=8-15

C_RED          = $42
C_GOLD         = $1A
C_GREEN        = $C8
C_BG           = $02

; =============================================================================
; RAM ALLOCATION ($80-$FF; +clean_start zeroes every byte)
; =============================================================================
ModeVal      = $80   ; 0 = sticky collision, 1 = frame overrun, 2 = off-by-one
BugOn        = $81   ; 1 = the faulty path is selected, 0 = the fixed path
PlayerX      = $82   ; P0's left edge, 8..136
PlayerY      = $83   ; P0's game-logic first row (140)
CollisionBit = $84   ; CXP0FB bit 7 as read this frame ($80 or 0)
BallHit      = $85   ; the P0-ball AABB result (1 = the boxes overlap)
PrevFire     = $86   ; fire state last frame (1 = pressed)
NewFire      = $87   ; this frame's fire 0 -> 1 edge
PrevLeft     = $88   ; left state last frame
NewLeft      = $89   ; this frame's left 0 -> 1 edge
PrevRight    = $8A   ; right state last frame
NewRight     = $8B   ; this frame's right 0 -> 1 edge
BeepTimer    = $8C   ; frames of beep remaining
BeepPitch    = $8D   ; AUDF for the beep
DemoPhase    = $8E   ; 0 = left, 1 = hold left, 2 = right, 3 = hold right
DemoTimer    = $8F   ; frames left in phases 1 and 3
ModePF0      = $90   ; the mode row's PF0 byte for this frame
ModePF1      = $91   ; the mode row's PF1 byte for this frame
BugColor     = $92   ; red (BugOn=1) or green (BugOn=0)
BandPF       = $93   ; $FF = the collision band is lit, $00 = dark
BandColor    = $94   ; red when lit, background when dark
ExtraWsync   = $95   ; 1 = mode 1 bug: BodyStart adds the extra WSYNC
P0Delay      = $96   ; 1 = mode 2 bug: P0 starts one line below PlayerY
Startup      = $97   ; frames left before the fire edge is trusted
;
; $98-$F7 are free (96 bytes).  The score and random libraries are not used.
; The stack lives at $F8-$FF; the call depth stays at one level.

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
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the lab starts in mode 0 with the fixed path selected -----------------
; Exercise 1's fix is unconditional, and BugOn=0 makes the green bug/fix
; cell agree with the clear band.  Fire still toggles the indicator and
; modes 1/2, but mode 0 has no sticky latch left to show.
    LDA #$00
    STA ModeVal
    STA BugOn

    LDA #PLAYER_START_X
    STA PlayerX
    LDA #PLAYER_Y
    STA PlayerY
    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #$08
    STA Startup             ; ignore the fire line while it settles

    LDA #C_BG
    STA COLUBK              ; the background and the dark band are $02
    LDA #$21
    STA CTRLPF              ; reflect the playfield; ball is 4 pixels wide

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
; 1. THE BEEP'S CLOCK
; -----------------------------------------------------------------------------
; BeepTimer counts down every frame and silences channel 0 at zero.
    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0               ; silence at the end of the tick
BeepClockDone:

; -----------------------------------------------------------------------------
; 2. FIRE — toggle BugOn on the 0 -> 1 edge
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  EOR turns that into a 1, and the
; EOR/AND pair keeps only a new press, so holding the button toggles once.
    LDA INPT4
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

; The first frames after power-on are not trusted: INPT4 can read low
; while the console settles.  Startup counts eight frames.  Until it reaches
; zero the fire edge is forced clear; a held direction arms PrevFire so the
; shared F in a longer hold string cannot toggle the bug by accident.
    LDA Startup
    BEQ FireEdgeReady
    DEC Startup
    LDA #$00
    STA NewFire
; A held direction is a menu selection, not a fire press.  Stella parses the
; hold value letter by letter, so a value such as LEFT also contains F
; (fire); the gate suppresses that fire while a direction is held.  A lone
; held fire becomes exactly one edge after the gate.
    LDA SWCHA
    AND #$C0
    CMP #$C0
    BEQ StartupNoDirection
    LDA #$80
    STA PrevFire
    JMP NoBugToggle
StartupNoDirection:
    LDA #$00
    STA PrevFire
    JMP NoBugToggle
FireEdgeReady:
    LDA NewFire
    BEQ NoBugToggle
    LDA BugOn
    EOR #$01                ; 0 <-> 1
    STA BugOn
BugToggle:                  ; checkpoint: A = the new BugOn
    JSR BeepStart
NoBugToggle:

; -----------------------------------------------------------------------------
; 3. MODE SELECTION — left and right edges, wrapping
; -----------------------------------------------------------------------------
; The SWCHA bits are active low.  The same pair also cancels the auto-demo
; in section 7; here they only change ModeVal on their 0 -> 1 edges.
    LDA SWCHA
    AND #$40                ; P0 left
    EOR #$40                ; 1 = pressed
    STA NewLeft
    EOR PrevLeft
    AND NewLeft
    STA NewLeft
    LDA SWCHA
    AND #$40
    EOR #$40
    STA PrevLeft

    LDA SWCHA
    AND #$80                ; P0 right
    EOR #$80                ; 1 = pressed
    STA NewRight
    EOR PrevRight
    AND NewRight
    STA NewRight
    LDA SWCHA
    AND #$80
    EOR #$80
    STA PrevRight

    LDA ModeVal
Mode:                       ; checkpoint: A = the selected mode
    CMP #$01
    BEQ ModeLeftFrom1
    CMP #$02
    BEQ ModeLeftFrom2
; --- mode 0: left wraps to 2 ----------------------------------------------
    LDA NewLeft
    BEQ CheckModeRight
    LDA #$02
    STA ModeVal
    JSR ArmBug
    JSR BeepStart
    JMP ModeSelectionDone
ModeLeftFrom1:
    LDA NewLeft
    BEQ CheckModeRight
    LDA #$00                ; 1 -> 0
    STA ModeVal
    JSR ArmBug
    JSR BeepStart
    JMP ModeSelectionDone
ModeLeftFrom2:
    LDA NewLeft
    BEQ CheckModeRight
    LDA #$01                ; 2 -> 1
    STA ModeVal
    JSR ArmBug
    JSR BeepStart
    JMP ModeSelectionDone
; --- right wraps 0 -> 1 -> 2 -> 0 -----------------------------------------
CheckModeRight:
    LDA ModeVal
    CMP #$02
    BEQ ModeRightFrom2
    LDA NewRight
    BEQ ModeSelectionDone
    LDA ModeVal
    CLC
    ADC #$01                ; 0 -> 1, 1 -> 2
    STA ModeVal
    JSR ArmBug
    JSR BeepStart
    JMP ModeSelectionDone
ModeRightFrom2:
    LDA NewRight
    BEQ ModeSelectionDone
    LDA #$00                ; 2 -> 0
    STA ModeVal
    JSR ArmBug
    JSR BeepStart
ModeSelectionDone:

; -----------------------------------------------------------------------------
; 4. THE P0-PLAYFIELD COLLISION LATCH
; -----------------------------------------------------------------------------
; CXP0FB bit 7 is P0-playfield; bit 6 is P0-ball and is masked out.  The read
; happens in VBLANK and therefore describes the previous visible frame.
; Exercise 1 clears the latches after every read, in every mode, so the next
; frame sees only the current contact.
    LDA CXP0FB
ReadCX:                     ; checkpoint: A = CXP0FB
    AND #$80
    STA CollisionBit
; --- Exercise 1's one-line fix: clear after the read, every mode ----------
; The read above describes the previous visible frame; the strobe below
; throws that history away, so the next frame sees only the current contact.
    LDA #$00
    STA CXCLR
CXClear:                    ; checkpoint: the latches are cleared
    NOP                     ; keeps CollisionDone a distinct breakpoint address
CollisionDone:

; -----------------------------------------------------------------------------
; 5. THE STATUS BYTES — mode cells, bug/fix colour, collision band
; -----------------------------------------------------------------------------
; The three mode cells are precomputed: only the selected cell is lit, so
; the row costs four stores per line instead of a compare per line.
    LDA #$00
    STA ModePF0
    STA ModePF1
    LDA ModeVal
    CMP #$01
    BEQ ModeCell1
    CMP #$02
    BEQ ModeCell2
    LDA #MODE0_PF0
    STA ModePF0
    JMP ModeCellsDone
ModeCell1:
    LDA #MODE1_PF1
    STA ModePF1
    JMP ModeCellsDone
ModeCell2:
    LDA #MODE2_PF1
    STA ModePF1
ModeCellsDone:

; --- the bug/fix cell is red for the buggy path and green for the fix ------
    LDA #C_RED
    LDX BugOn
    BNE BugColorDone
    LDA #C_GREEN
BugColorDone:
    STA BugColor

; --- the collision band is a full-width bar when the latch is set ----------
    LDA CollisionBit
    BEQ BandOff
    LDA #$FF
    STA BandPF
    LDA #C_RED
    STA BandColor
    JMP BandDone
BandOff:
    LDA #$00
    STA BandPF
    LDA #C_BG
    STA BandColor
BandDone:

; -----------------------------------------------------------------------------
; 6. THE P0-BALL CHECK — the game-logic rows, not the drawn rows
; -----------------------------------------------------------------------------
; An axis-aligned overlap of the 8x16 P0 box against the 4x8 ball box.  The
; game logic uses PlayerY, which is the fixed row where P0 is supposed to
; start.  Mode 2's bug draws the sprite one line lower; the check does not
; move, which is exactly the disagreement the debugger exposes.
    LDA #$00
    STA BallHit

; --- Y overlap: PlayerY < BallY+8 AND BallY < PlayerY+16 -------------------
    LDA PlayerY
PlayerYRead:                ; checkpoint: A = PlayerY (140)
    CMP #(BALL_Y + 8)       ; PlayerY > 147?
    BCS BallCheckDone
    CLC
    ADC #15                 ; PlayerY + 15 (the last P0 row)
    CMP #BALL_Y             ; PlayerY+15 < 140?
    BCC BallCheckDone

; --- X overlap: PlayerX < BallX+4 AND BallX < PlayerX+8 --------------------
    LDA PlayerX
PlayerXRead:                ; checkpoint: A = PlayerX
    CMP #(BALL_X + 4)       ; PlayerX > 83?
    BCS BallCheckDone
    CLC
    ADC #7                  ; PlayerX + 7 (the last P0 pixel)
    CMP #BALL_X             ; PlayerX+7 < 80?
    BCC BallCheckDone
    LDA #$01
    STA BallHit
BallCheckDone:
    LDA BallHit
P0BallCheck:                ; checkpoint: A = BallHit (0 or 1)

; -----------------------------------------------------------------------------
; 7. PLAYER MOVEMENT — the joystick, or the deterministic auto-demo
; -----------------------------------------------------------------------------
; A held direction stops the demo and keeps P0 where the player put it for
; DEMO_HOLD frames.  With no direction held, AutoMove runs the 410-frame
; phase cycle described in the header.
    LDA SWCHA
    AND #$C0                ; P0 left (bit 6) and right (bit 7)
    CMP #$C0
    BEQ AutoPlayer
ManualPlayer:
    LDA #$03
    STA DemoPhase           ; park the demo after the manual move
    LDA #DEMO_HOLD
    STA DemoTimer
    LDA SWCHA
    AND #$40                ; left
    BNE ManualNoLeft
    LDA PlayerX
    CMP #PLAYER_MIN_X
    BEQ ManualLeftDone
    DEC PlayerX
ManualLeftDone:
    JMP MovementDone
ManualNoLeft:
    LDA SWCHA
    AND #$80                ; right
    BNE MovementDone
    LDA PlayerX
    CMP #PLAYER_MAX_X
    BEQ MovementDone
    INC PlayerX
    JMP MovementDone
AutoPlayer:
    JSR AutoMove
MovementDone:

; -----------------------------------------------------------------------------
; 8. THE TWO BUG FLAGS THE KERNEL READS
; -----------------------------------------------------------------------------
; ExtraWsync = mode 1 + BugOn: the WSYNC-first line.
; P0Delay    = mode 2 + BugOn: the one-line-late P0 row.
    LDA #$00
    STA ExtraWsync
    STA P0Delay
    LDA ModeVal
    CMP #$01
    BNE CheckP0Delay
    LDA BugOn
    BEQ CheckP0Delay
    LDA #$01
    STA ExtraWsync
CheckP0Delay:
    LDA ModeVal
    CMP #$02
    BNE BugFlagsDone
    LDA BugOn
    BEQ BugFlagsDone
    LDA #$01
    STA P0Delay
BugFlagsDone:

; -----------------------------------------------------------------------------
; 9. POSITION ALL THREE OBJECTS, THEN STROBE ONE HMOVE
; -----------------------------------------------------------------------------
; Every coarse RESxx and every HMxx is set first; one WSYNC and one HMOVE
; apply all three fine offsets in the same HBLANK (the one-HMOVE rule from
; Lesson 28).
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA #P1_X
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
    LDA #BALL_X
    CLC
    ADC #(POS_BIAS + 1)     ; the ball's output delay is one clock shorter
    JSR SetCoarseBall
    STA WSYNC
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed (next line)

; -----------------------------------------------------------------------------
; 10. COLOURS, SIZES, AND A CLEAN FIRST LINE
; -----------------------------------------------------------------------------
; The playfield registers are cleared so the mode-1 bug's lost line shows
; background, not a stale row from the previous frame.
    LDA #C_RED
    STA COLUP0              ; P0 is red
    LDA #C_GREEN
    STA COLUP1              ; P1 is green
    LDA #C_BG
    STA COLUBK
    LDA #C_GOLD
    STA COLUPF              ; the wall and the ball are gold
    LDA #$00
    STA NUSIZ0              ; both players are one 8-pixel copy
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    LDA #$21
    STA CTRLPF              ; reflect; the ball is 4 pixels wide

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0

; --- BUG 1: the WSYNC-first habit costs the first visible line -------------
; BodyStart is already line 37 cycle 5.  A WSYNC here waits for the end of
; line 37, so the first line's writes and every later zone land one line
; late.  The frame grows to 263 lines and OverscanStart reports 230.
    LDA ExtraWsync
    BEQ BodyNoWsync
    STA WSYNC               ; BUG 1: WSYNC before the line's writes
BodyNoWsync:

; --- visible 0-7: the mode row --------------------------------------------
; The mode row's bytes and colour are precomputed in VBLANK.  In the fixed
; path the stores complete before PF1's first visible slot.
    LDA #C_GOLD
    STA COLUPF
    LDA ModePF0
    STA PF0
    LDA ModePF1
    STA PF1
    LDA #$00
    STA PF2
    LDY #8
ModeRow:
    STA WSYNC
    DEY
    BNE ModeRow

; --- visible 8-15: the bug/fix cell ---------------------------------------
    LDA BugColor
    STA COLUPF
    LDA #BUG_PF0
    STA PF0
    LDA #$00
    STA PF1
    STA PF2
    LDY #8
BugRow:
    STA WSYNC
    DEY
    BNE BugRow

; --- visible 16-39: the top of the play area, wall only -------------------
    LDA #C_GOLD
    STA COLUPF
    LDA #$F0                ; PF0 bits 4-7: a 16-pixel wall at each edge
    STA PF0
    LDA #$00
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    LDY #24
TopWall:
    STA WSYNC
    DEY
    BNE TopWall

; --- visible 40-55: P1, 16 rows -------------------------------------------
; P1 is at X=80.  The GRP1 store completes before P1's first pixel.
    LDA #$FF
    STA GRP1
    LDY #16
P1Rows:
    STA WSYNC
    DEY
    BNE P1Rows

; --- visible 56-139: the middle of the play area, wall only ---------------
    LDA #$00
    STA GRP1
    STA GRP0
    LDY #84
MidWall:
    STA WSYNC
    DEY
    BNE MidWall

; --- visible 140-155: P0 and the ball -------------------------------------
; P0's first row is the one the off-by-one bug moves.  GRP0 is set at the
; top of the zone in the fixed path, before P0's first pixel even at X=8.
; In the bug path GRP0 stays 0 for line 140 and is set at the top of line
; 141, so the drawn sprite starts one line below PlayerY.  The ball is
; enabled for its eight fixed rows in both paths.
    LDA P0Delay
    BEQ P0DrawNow
    JMP P0Colors            ; BUG 2: line 140 stays blank
P0DrawNow:
    LDA #$FF
P0RowFixed:                 ; checkpoint: fixed path's first GRP0 store
    STA GRP0
P0Colors:
    LDA #C_RED
    STA COLUP0
    LDA #$02
    STA ENABL               ; the ball's first row
    LDA #C_GOLD
    STA COLUPF
    STA WSYNC               ; the end of visible line 140

; Line 141: in the fixed path this is P0's second row; in the bug path it is
; the first.  The store completes before the visible area; the P0RowBug
; checkpoint reports scanline 178, cycle 5.
    LDA #$FF
    STA GRP0
P0RowBug:                   ; checkpoint: the line-141 GRP0 store
    LDY #7
P0BallRows:
    STA WSYNC
    DEY
    BNE P0BallRows

; --- line 148: the ball is over; P0 continues to row 155 ------------------
    LDA #$00
    STA ENABL
    LDY #8
P0Rows:
    STA WSYNC
    DEY
    BNE P0Rows

; --- line 156: the fixed path ends P0 here; the bug path needs one more ---
; In the bug the sprite's 16 rows are 141-156, so line 156 must keep GRP0
; set.  The WSYNC below holds it for that line, and the lower wall loses one
; line to keep the total at 192.
    LDA P0Delay
    BEQ P0ClearNow
    STA WSYNC               ; BUG 2: line 156 is P0's last row
P0ClearNow:
    LDA #$00
    STA GRP0
    LDY #20                 ; 20 lines fixed, 19 in the bug path
    LDX P0Delay
    BEQ BottomCountReady
    LDY #19
BottomCountReady:
    LDA #$F0
    STA PF0
    LDA #$00
    STA PF1
    STA PF2
    LDA #C_GOLD
    STA COLUPF
BottomWall:
    STA WSYNC
    DEY
    BNE BottomWall

; --- visible 176-183: the collision band ----------------------------------
; The band is the visible proof of bug 0.  A full-width playfield bar in red
; means the latch was set; the fixed path turns the playfield off and the
; background shows through.
    LDA BandColor
    STA COLUPF
    LDA BandPF
    STA PF0
    STA PF1
    STA PF2
    LDY #8
BandRow:
    STA WSYNC
    DEY
    BNE BandRow

; --- visible 184-191: background ------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL
    LDY #8
RestZone:
    STA WSYNC
    DEY
    BNE RestZone
    JMP FrameEnd

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
FrameEnd:
OverscanStart:              ; checkpoint: scanline 229 fixed / 230 bug
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; ArmBug — selecting a mode shows that mode's bug
; =============================================================================
; The selector is a bug selector: arriving at a mode re-arms BugOn so the
; chosen failure is visible.  Fire then flips to the fixed path.
ArmBug:
    LDA #$01
    STA BugOn
    RTS

; =============================================================================
; AutoMove — the deterministic 410-frame phase cycle
; =============================================================================
; Phase 0 walks left to the wall, phase 1 holds for eight frames, phase 2
; walks right past the ball to X=88, and phase 3 holds for 240 frames.  The
; long hold is the screenshot window.
AutoMove:
    LDA DemoPhase
DemoPhaseRead:              ; checkpoint: A = DemoPhase
    CMP #$01
    BEQ AutoHoldLeft
    CMP #$02
    BEQ AutoRight
    CMP #$03
    BEQ AutoHoldRight

; --- phase 0: left until the wall -----------------------------------------
    LDA PlayerX
    CMP #PLAYER_MIN_X
    BEQ AutoToHoldLeft
    DEC PlayerX
    RTS
AutoToHoldLeft:
    LDA #$01
    STA DemoPhase
    LDA #DEMO_LEFT_HOLD
    STA DemoTimer
    RTS

; --- phase 1: park at the wall --------------------------------------------
AutoHoldLeft:
    DEC DemoTimer
    BNE AutoDone
    LDA #$02
    STA DemoPhase
AutoDone:
    RTS

; --- phase 2: right until the resting place ------------------------------
AutoRight:
    LDA PlayerX
    CMP #PLAYER_HOLD_X
    BEQ AutoToHoldRight
    INC PlayerX
    RTS
AutoToHoldRight:
    LDA #$03
    STA DemoPhase
    LDA #DEMO_HOLD
    STA DemoTimer
    RTS

; --- phase 3: the long hold ----------------------------------------------
AutoHoldRight:
    DEC DemoTimer
    BNE AutoDone
    LDA #$00
    STA DemoPhase
    RTS

; =============================================================================
; SetCoarseP0 / SetCoarseP1 / SetCoarseBall — the Lesson 26 divide-by-15
; =============================================================================
; A = the desired left edge + POS_BIAS.  Each routine starts on a fresh line,
; divides by 15 with repeated SBC, turns the remainder into the HMxx fine
; value, and strobes the matching RESxx.  The caller applies all three with
; one HMOVE.
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

SetCoarseBall:
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
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
; AUDC 0C is the div-6 tone from Lesson 35; AUDV 0A is audible but not loud.
; The VBLANK clock silences the channel two frames later.
BeepStart:
    LDA #BEEP_FRAMES
    STA BeepTimer
    LDA #$0C
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0
    RTS

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
