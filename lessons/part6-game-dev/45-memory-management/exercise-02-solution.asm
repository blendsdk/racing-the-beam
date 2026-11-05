; =============================================================================
; LESSON 45 — EXERCISE 2 SOLUTION: Overlay by State — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; EXERCISE 2: reuse the title-screen variables for the play state.  The two
; states never run at the same time, so one pair of bytes can serve both:
;
;   $8B  TitleHold / PlayHold   a frame countdown
;   $8C  TitleStep / PlayStep   a 0-3 phase
;
; The !if asserts below prove that the two names really do land on the same
; addresses; if someone moves one of them, the build stops with a clear error.
;
; The changes from the main ROM:
;   1. GameState ($92) starts at 0 (title).  Fire starts play: the 0 -> 1
;      edge stores 1 and resets the timer.  There is no way back in this lab;
;      the overlay is the subject, not the full state machine.
;   2. The auto-demo's two bytes are named PlayHold/PlayStep in play and
;      TitleHold/TitleStep in title.  They are aliases, not copies.
;   3. In the title state the flags row blinks all four cells (on when the
;      phase is even) and the bar is fixed at seven cells.  In play the main
;      ROM's input, demo, flags row, and timer run.
;   4. The timer block is gated on GameState=1.  A title left on screen would
;      otherwise raise FlagOver after 240 frames and sound the overflow beep;
;      the title is silent until fire starts the game.
;   5. RamMap row 1 becomes $C0,$80,$00: cell 2 ($92, GameState) is now used.
;      FreeBytes reports 29 instead of 30.  The shared bytes were already lit.
;   6. StateOverlay = $8B documents the two-byte shared block; Scratch0/
;      Scratch1 name the reserved $8D-$8E pair that row 0 already lights.
;
; Checkpoints: the main ROM's, plus StateWrite (A=1).  StateWrite shares its
;   address with AlreadyPlaying, so it fires on every fire edge -- the title
;   store and the play branch both report A=1; it is not a one-shot.  The
;   state change itself is visible (title blink/bar 7 vs play flags/timer).
;   FreeBytes reports $1D = 29.
;
; Build: acme -f plain -o build/ex45-2.bin \
;        lessons/part6-game-dev/45-memory-management/exercise-02-solution.asm
; Run:   stella build/ex45-2.bin     (press fire to leave the title)
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36

TIMER_FULL     = $F0
BEEP_FRAMES    = 2
BEEP_PITCH     = $0C

DEMO_FRAMES    = 64

BAR_CELLS      = 15
BAR_LINES      = 6
BAR_CHUNK      = $20

TITLE_BAR      = 7       ; the title's fixed bar height

FLAG_FIRE_PF0  = $40
FLAG_LEFT_PF0  = $80
FLAG_RIGHT_PF1 = $80
FLAG_OVER_PF1  = $40

C_GOLD         = $1A
C_GREEN        = $C8
C_BG           = $02

; =============================================================================
; RAM ALLOCATION — two states, one block
; =============================================================================
FrameLo      = $80
FrameHi      = $81
PrevFire     = $82
NewFire      = $83
FlagFire     = $84
FlagLeft     = $85
FlagRight    = $86
FlagOver     = $87
PackedTimer  = $88
BeepTimer    = $89
BeepPitch    = $8A

; --- the shared title/play block -------------------------------------------
; Only one state runs at a time, so the same two bytes keep a countdown and a
; phase for both.  The !if asserts make the aliasing explicit and checkable.
TitleHold    = $8B   ; title: frames until the blink changes
TitleStep    = $8C   ; title: blink phase 0-3
PlayHold     = $8B   ; play: frames until the demo phase changes
PlayStep     = $8C   ; play: demo phase 0-3
StateOverlay = $8B   ; two bytes, $8B-$8C (documentation label)

!if TitleHold != PlayHold {
    !error "state overlay mismatch: TitleHold and PlayHold"
}
!if TitleStep != PlayStep {
    !error "state overlay mismatch: TitleStep and PlayStep"
}

Scratch0     = $8D   ; reserved scratch, $8D-$8E (not written by this ROM)
Scratch1     = $8E
FlagPF0      = $8F
FlagPF1      = $90
FreeCount    = $91
GameState    = $92   ; 0 = title, 1 = play

; $93-$9F free (13 bytes).
; $A0-$D7 the scoreboard reservation (56 bytes, not used by this lab).
; $D8-$E7 free (16 bytes).
BarBuf       = $E8   ; fifteen cell bytes ($E8-$F6)
BarLevel     = $F7   ; the bar height (0-15)
RamEnd       = BarLevel

; --- $F8-$FF: the stack ----------------------------------------------------

; =============================================================================
; ROM START
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA SWACNT

    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #C_BG
    STA COLUBK
    LDA #$01
    STA CTRLPF

    JSR CountFree
FreeBytes:                  ; checkpoint: A = the computed free-byte count
    STA FreeCount

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259
    +vsync

VblankStart:                ; checkpoint: scanline 0
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; 1. THE FRAME COUNTER AND THE BEEP CLOCK
; -----------------------------------------------------------------------------
    INC FrameLo
    BNE FrameCounted
    INC FrameHi
FrameCounted:

    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0
BeepClockDone:

; -----------------------------------------------------------------------------
; 2. INPUT — three level flags
; -----------------------------------------------------------------------------
    LDA #$00
    STA FlagFire
    LDA INPT4
FireRead:                   ; checkpoint: A = INPT4 (bit 7 = 0 while pressed)
    AND #$80
    BNE FireReadDone
    LDA #$01
    STA FlagFire
FireReadDone:

    LDA #$00
    STA FlagLeft
    LDA SWCHA
    AND #$40
    BNE LeftReadDone
    LDA #$01
    STA FlagLeft
LeftReadDone:

    LDA #$00
    STA FlagRight
    LDA SWCHA
    AND #$80
    BNE RightReadDone
    LDA #$01
    STA FlagRight
RightReadDone:

; -----------------------------------------------------------------------------
; 3. THE PLAY STATE'S AUTO-DEMO — PlayHold and PlayStep
; -----------------------------------------------------------------------------
; The title state reuses the same two bytes as TitleHold and TitleStep.  The
; countdown runs in both states; the meaning belongs to the active one.
    INC PlayHold
    LDA PlayHold
    CMP #DEMO_FRAMES
    BCC DemoStepDone
    LDA #$00
    STA PlayHold
    LDA PlayStep
    CLC
    ADC #$01
    AND #$03
    STA PlayStep
DemoStepDone:
    LDX PlayStep
    LDA DemoLeftTable,X
    ORA FlagLeft
    STA FlagLeft
    LDA DemoRightTable,X
    ORA FlagRight
    STA FlagRight

; -----------------------------------------------------------------------------
; 4. FIRE: START PLAY FROM THE TITLE, OR RESTART THE ROUND IN PLAY
; -----------------------------------------------------------------------------
; The 0 -> 1 edge is the event.  In the title it also moves GameState to 1;
; in play it only restarts the timer, exactly as the main ROM does.
    LDA FlagFire
    EOR PrevFire
    AND FlagFire
    STA NewFire
    LDA FlagFire
    STA PrevFire

    LDA NewFire
    BEQ NoRestart
    LDA GameState
    BNE AlreadyPlaying
    LDA #$01
    STA GameState
StateWrite:                 ; checkpoint: A=1 on every fire edge (see header)
AlreadyPlaying:
    LDA #$00
    STA PackedTimer
    STA FlagOver
NoRestart:

; -----------------------------------------------------------------------------
; 5. THE PACKED TIMER — play only
; -----------------------------------------------------------------------------
; The title reuses $8B/$8C for its blink, but the timer itself must not run
; before play: a title left on screen for 240 frames would otherwise raise
; FlagOver and sound the overflow beep.  Gating on GameState keeps the title
; silent until fire starts the game.
    LDA GameState
    BEQ TimerDone           ; title: no timer, no overflow beep
    LDA FlagOver
    BNE TimerDone
    INC PackedTimer
    LDA PackedTimer
PackTimer:                  ; checkpoint: A = the packed byte
    CMP #TIMER_FULL
    BNE TimerDone
    LDA #$01
    STA FlagOver
    JSR BeepStart
TimerDone:

; -----------------------------------------------------------------------------
; 6. THE BAR AND THE FLAGS ROW
; -----------------------------------------------------------------------------
    LDA PackedTimer
    LSR
    LSR
    LSR
    LSR
    STA BarLevel
    LDX #$00
FillBar:
    CPX BarLevel
    LDA #$00
    BCS FillBarDark
    LDA #BAR_CHUNK
FillBarDark:
    STA BarBuf,X
    INX
    CPX #BAR_CELLS
    BNE FillBar

    LDA #$00
    STA FlagPF0
    STA FlagPF1
    LDA FlagFire
    BEQ FireCellDone
    LDA #FLAG_FIRE_PF0
    STA FlagPF0
FireCellDone:
    LDA FlagLeft
    BEQ LeftCellDone
    LDA FlagPF0
    ORA #FLAG_LEFT_PF0
    STA FlagPF0
LeftCellDone:
    LDA FlagRight
    BEQ RightCellDone
    LDA #FLAG_RIGHT_PF1
    STA FlagPF1
RightCellDone:
    LDA FlagOver
    BEQ OverCellDone
    LDA FlagPF1
    ORA #FLAG_OVER_PF1
    STA FlagPF1
OverCellDone:

; --- the title's overlay: blink all four cells and fix the bar --------------
; This is the payoff of the shared block: the title reads TitleStep, which is
; PlayStep's byte, and does not need a second pair of variables.
    LDA GameState
    BNE TitleDone
    LDA #$00
    STA FlagPF0
    STA FlagPF1
    LDA TitleStep
    AND #$01
    BNE TitleDark
    LDA #$C0                ; all four flags lit
    STA FlagPF0
    STA FlagPF1
TitleDark:
    LDA #TITLE_BAR
    STA BarLevel
    LDX #$00
TitleBar:
    CPX #TITLE_BAR
    LDA #$00
    BCS TitleBarDark
    LDA #BAR_CHUNK
TitleBarDark:
    STA BarBuf,X
    INX
    CPX #BAR_CELLS
    BNE TitleBar
TitleDone:

    +wait_timer
    LDA #$00
    STA VBLANK

; =============================================================================
; VISIBLE — 192 lines, work-first
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37

; --- visible 0-7: the flags row --------------------------------------------
    LDA #C_GOLD
    STA COLUPF
    LDA FlagPF0
    STA PF0
    LDA FlagPF1
    STA PF1
    LDA #$00
    STA PF2
    LDY #8
FlagsRow:
    STA WSYNC
    DEY
    BNE FlagsRow

; --- visible 8-39: the 16x8 memory grid ------------------------------------
    LDA #C_GREEN
    STA COLUPF
    LDX #$00
MapRow:
    LDA RamMap+0,X
MapDraw:                    ; checkpoint: A = the row's PF0 byte
    STA PF0
    LDA RamMap+1,X
    STA PF1
    LDA RamMap+2,X
    STA PF2
    TXA
    CLC
    ADC #$03
    TAX
    LDY #4
MapLine:
    STA WSYNC
    DEY
    BNE MapLine
    CPX #24
    BNE MapRow

; --- visible 40-129: the timer bar -----------------------------------------
    LDA BarBuf+14
    STA PF1
    LDA #$00
    STA PF0
    STA PF2
    LDA #C_GOLD
    STA COLUPF
    LDX #14
MeterCell:
    LDA BarBuf,X
    STA PF1
    LDY #BAR_LINES
MeterLine:
    STA WSYNC
    DEY
    BNE MeterLine
    DEX
    BPL MeterCell

; --- visible 130-191: background -------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #62
RestZone:
    STA WSYNC
    DEY
    BNE RestZone
    JMP FrameEnd

; =============================================================================
; FRAME END — 30 overscan lines
; =============================================================================
FrameEnd:
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; CountFree — 128 - used
; =============================================================================
CountFree:
    LDA #$00
    STA FreeCount
    LDX #$00
CountRow:
    LDA RamMap+0,X
    AND #$C0
    JSR CountBits
    LDA RamMap+1,X
    JSR CountBits
    LDA RamMap+2,X
    AND #$3F
    JSR CountBits
    TXA
    CLC
    ADC #$03
    TAX
    CPX #24
    BNE CountRow
    LDA #128
    SEC
    SBC FreeCount
    RTS

CountBits:
    LDY #8
CountBit:
    ASL
    BCC CountBitNext
    INC FreeCount
CountBitNext:
    DEY
    BNE CountBit
    RTS

; =============================================================================
; BEEP
; =============================================================================
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
; TABLES
; =============================================================================
DemoLeftTable:
    !byte 1, 0, 1, 0
DemoRightTable:
    !byte 0, 1, 1, 0

; --- the memory map --------------------------------------------------------
; Row 1 cell 2 is GameState at $92; the shared $8B-$8C bytes were already lit
; in row 0, so the overlay itself does not change the picture.
RamMap:
    !byte $C0, $FF, $3F     ; row 0: $80-$8F  all used
    !byte $C0, $80, $00     ; row 1: $90-$9F  cells 0-2 used ($90-$92)
    !byte $C0, $FF, $3F     ; row 2: $A0-$AF  all used (score plan)
    !byte $C0, $FF, $3F     ; row 3: $B0-$BF  all used (score plan)
    !byte $C0, $FF, $3F     ; row 4: $C0-$CF  all used (score plan)
    !byte $C0, $FC, $00     ; row 5: $D0-$DF  cells 0-7 used
    !byte $00, $03, $3F     ; row 6: $E0-$EF  cells 8-15 used
    !byte $C0, $FF, $3F     ; row 7: $F0-$FF  all used (bar + stack)

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
