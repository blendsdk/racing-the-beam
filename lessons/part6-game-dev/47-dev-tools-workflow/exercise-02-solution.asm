; =============================================================================
; LESSON 47 EXERCISE 2: A Conditional Build Border — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; What this program does:
;   The main lesson's build dashboard with the debug border turned into a
;   visible build flag.  The release build paints the background blue and
;   the debug build paints it red; a ninth cell at chunk 11 of the checksum
;   row is lit gold only in the debug build.  The rest of the dashboard is the
;   main ROM: five stage blocks, the fifteen-cell progress bar, the eight
;   checksum cells, the beep, the stage clock, fire and SELECT.
;
;   The exercise shows the two ways a build flag can reach the screen:
;   !if selects the border byte while ACME assembles, and BuildValue carries
;   the same DEBUG symbol into RAM so BuildFlag can report it to the debugger.
;
; The screen (192 visible lines, CTRLPF=$01 mirrors the playfield):
;   visible 0-79    five stage blocks (fifteen lit lines and a one-line
;                   separator).  Completed = dim gold ($16), active = green
;                   ($C8), future = $02.
;   visible 80-87   a background gap.  The background is the build border:
;                   blue ($84) for DEBUG=0, red ($42) for DEBUG=1.
;   visible 88-177  the progress bar: fifteen cells of six lines at chunk 6,
;                   bottom-up; the mirror is X=132-135.
;   visible 178-183 a background gap.
;   visible 184-191 the checksum row: eight cells at chunks 2-9 (bit 7 first),
;                   plus the BuildFlag cell at chunk 11 (X=44-47).  The cell
;                   is gold when BuildValue=1 and shows the field colour
;                   (blue in release, red in debug) when BuildValue=0.  The
;                   mirror is at X=120-151.
;   The zones total 80 + 8 + 90 + 6 + 8 = 192 lines; OverscanStart is 229.
;
; The stage cycle:
;   Stage 1 (EDIT) through 5 (COMMIT); 30 frames per stage, 60 on COMMIT,
;   then wrap to 1.  Fire advances; SELECT resets.  StageStep reports 2, 3,
;   4, 5, 1, ...
;
; The checksum:
;       CheckData[i] = ((i * 7 + 3) + ((i * i) >> 8)) & $FF
;       CheckSum = sum(CheckData) & $FF = $EC
;   The eight checksum cells are unchanged; the BuildFlag cell is PF1 bit 0,
;   one of the two bits the checksum mapping leaves free.
;
; The two builds:
;   acme -f plain -o release.bin exercise-02-solution.asm       -> DEBUG=0,
;       blue border, BuildFlag A=0, the cell shows the blue field.
;   acme -f plain -D DEBUG=1 -o debug.bin exercise-02-solution.asm
;       -> DEBUG=1, red border, BuildFlag A=1, the cell gold.
;   Both outputs are 4,096 bytes; cmp shows exactly two differing bytes: the
;   LDA #DEBUG immediate and the border color immediate.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   BuildFlag (A = DEBUG, once at reset), StageStep (A = the new stage, once
;   per transition), CheckSum (A = $EC, once at reset), BodyStart (37),
;   OverscanStart (229).  Stage is $80, StageTimer $81, BuildValue $82,
;   SumByte $83.
;
; Build:
;   acme -f plain -o build/exercise-02.bin \
;        lessons/part6-game-dev/47-dev-tools-workflow/exercise-02-solution.asm
; Run:
;   stella build/exercise-02.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan

STAGE_COUNT    = 5       ; EDIT, ASSEMBLE, RUN, VERIFY, COMMIT
STAGE_PERIOD   = 30      ; frames per stage (0.5 s at 60 Hz)
STAGE_HOLD     = 60      ; frames held on the last stage before the restart
STAGE_LINES    = 16      ; visible lines per stage block

BAR_CELLS      = 15      ; the progress bar's fifteen cells
BAR_LINES      = 6       ; six visible lines per cell
BAR_CHUNK      = $20     ; PF1 bit 5 = chunk 6 = X=24-27

CHECK_CELLS    = 8       ; the checksum row's eight cells
CHECK_BYTES    = 256     ; CheckData is one page

BEEP_FRAMES    = 2       ; a two-frame tick
BEEP_PITCH     = $08     ; AUDF 8 on AUDC $0C: a short, bright beep

C_GREEN        = $C8     ; the active stage
C_BLUE         = $84     ; the release build's border
C_GOLD         = $1A     ; the progress and checksum cells
C_DIM_GOLD     = $16     ; a completed stage: a dimmer gold than $1A
C_RED          = $42     ; the debug build's border
C_BG           = $02     ; a future stage

; =============================================================================
; BUILD FLAGS — ACME's assembler-time symbols
; =============================================================================
; The source defines DEBUG=0 only when the command line did not.  That is the
; difference between:
;   acme -f plain -o release.bin demo-47.asm          -> DEBUG=0
;   acme -f plain -D DEBUG=1 -o debug.bin demo-47.asm -> DEBUG=1
; !if reads the symbol while ACME assembles; the branch is resolved before a
; single ROM byte is written.
!ifndef DEBUG {
    DEBUG = 0
}

; =============================================================================
; RAM ALLOCATION ($80-$9F; +clean_start zeroes every byte)
; =============================================================================
Stage        = $80   ; the active stage, 1..STAGE_COUNT
StageTimer   = $81   ; frames left in the current stage
BuildValue   = $82   ; DEBUG as a runtime byte (BuildFlag checkpoint)
SumByte      = $83   ; the 8-bit checksum (CheckSum checkpoint)
CheckPF0     = $84   ; the checksum row's PF0 byte
CheckPF1     = $85   ; the checksum row's PF1 byte
PrevFire     = $86   ; fire state last frame (1 = pressed)
PrevSelect   = $87   ; SELECT state last frame (1 = pressed)
BeepTimer    = $88   ; frames of beep remaining
BeepPitch    = $89   ; AUDF for the beep
BarLevel     = $8A   ; lit progress cells, 1..BAR_CELLS
BarBuf       = $8B   ; fifteen cell bytes, $8B-$99 ($20 lit, $00 dark)
StageColors  = $9A   ; five stage colors, $9A-$9E
Scratch      = $9F   ; reset-time bit shifter, then the input-edge byte
;
; $80-$9F is the full Lesson 45 lesson block.  The score and random libraries
; are not used.  The stack lives at $F8-$FF; the call depth stays shallow.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; StageBlock — one 16-line stage block
; =============================================================================
; ACME gives every macro call its own local-label scope, so the anonymous
; "backward" label below is resolved inside each expansion.  The parameter
; .index is substituted into the StageColors expression; the color itself is
; a runtime value because the active stage changes every 30 frames.
!macro StageBlock .index {
    LDA StageColors + .index
    STA COLUPF
    LDA #$FF
    STA PF0
    STA PF1
    STA PF2
    LDY #(STAGE_LINES - 1)
-   STA WSYNC
    DEY
    BNE -
    LDA #$00                ; the block's last line is a dark separator
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
}


; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the build flag is a runtime copy of the assembler symbol --------------
; BuildFlag is the checkpoint: a breakpoint there stops before the store, with
; A already holding DEBUG.  The value also lets the debugger answer "which
; build is this?" without reading the source or the border color.
    LDA #DEBUG
BuildFlag:                  ; checkpoint: A = DEBUG
    STA BuildValue

; --- the border: an assembly-time !if, not a runtime branch ----------------
; The release build paints the background blue; the debug build paints it
; red.  Both builds are exactly 4,096 bytes; only the LDA #DEBUG immediate
; and the border color immediate differ.  BuildValue is the runtime copy that
; lights the BuildFlag cell.
    !if DEBUG {
        LDA #C_RED
    } else {
        LDA #C_BLUE           ; exercise 2: the release border is blue
    }
    STA COLUBK

    LDA #$01
    STA CTRLPF              ; mirror the playfield; the left half is the reference
    LDA #BEEP_PITCH
    STA BeepPitch

    LDA #$01
    STA Stage               ; start on EDIT
    LDA #STAGE_PERIOD
    STA StageTimer

; --- the checksum is computed once, before the first frame ----------------
; 256 adds are free at reset; doing them every frame would spend VBLANK time
; for a number that never changes.
    JSR ComputeCheckSum

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
; BeepTimer counts down every frame and silences channel 0 at zero.  The
; sound itself is not the lesson's subject; it is the same two-byte beep the
; rest of Part 6 uses.
    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0
BeepClockDone:

; -----------------------------------------------------------------------------
; 2. FIRE — advance one stage on the 0 -> 1 edge
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  EOR turns that into a 1, and the
; EOR/AND pair keeps only a new press.  Fire is a manual StageStep: the same
; AdvanceStage routine the clock calls, so the checkpoint reports both kinds
; of transition.
    LDA INPT4
    AND #$80
    EOR #$80                ; 1 = pressed
    STA Scratch
    EOR PrevFire
    AND Scratch
    BEQ NoFireEdge
    JSR AdvanceStage
    JSR BeepStart
NoFireEdge:
    LDA Scratch
    STA PrevFire

; -----------------------------------------------------------------------------
; 3. SELECT — reset the dashboard to stage 1
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  The edge, not the level, restarts
; the cycle.  SELECT is also the screenshot helper: a capture can start from
; a known stage without waiting for the 180-frame cycle.
    LDA SWCHB
    AND #$02
    EOR #$02                ; 1 = pressed
    STA Scratch
    EOR PrevSelect
    AND Scratch
    BEQ NoSelectEdge
    LDA #$01
    STA Stage
    LDA #STAGE_PERIOD
    STA StageTimer
    JSR BeepStart
NoSelectEdge:
    LDA Scratch
    STA PrevSelect

; -----------------------------------------------------------------------------
; 4. THE STAGE CLOCK — one stage every 30 frames, 60 on the last
; -----------------------------------------------------------------------------
; AdvanceStage increments Stage and reloads StageTimer.  At stage 5 the
; routine wraps to stage 1; the 60-frame hold is set when the clock reaches
; stage 5, so the COMMIT block stays green for one second before the cycle
; starts again.
    DEC StageTimer
    BNE StageTickDone
    JSR AdvanceStage
StageTickDone:

; -----------------------------------------------------------------------------
; 5. THE STATUS BYTES — five stage colours and fifteen bar cells
; -----------------------------------------------------------------------------
; Both tables are rebuilt in VBLANK from the single Stage byte.  The kernel
; then reads them without a comparison per line: the stage blocks take their
; color from StageColors, and the bar takes its lit/dark byte from BarBuf.
    LDX #$00
StageColorLoop:
    TXA
    CLC
    ADC #$01                ; the block's 1-based number
    CMP Stage
    BEQ StageColorActive
    BCS StageColorFuture
    LDA #C_DIM_GOLD         ; i + 1 < Stage: completed
    JMP StageColorStore
StageColorActive:
    LDA #C_GREEN
    JMP StageColorStore
StageColorFuture:
    LDA #C_BG               ; i + 1 > Stage: not started
StageColorStore:
    STA StageColors,X
    INX
    CPX #STAGE_COUNT
    BNE StageColorLoop

; --- the bar level is the stage number, clamped to the fifteen cells ------
    LDA Stage
    CMP #BAR_CELLS
    BCC BarLevelOk
    LDA #BAR_CELLS
BarLevelOk:
    STA BarLevel

; --- build the fifteen cell bytes bottom-up ------------------------------
; Cell 0 is the bottom cell and cell 14 is the top cell.  A cell below the
; level is lit with BAR_CHUNK; a cell at or above it is dark.  The kernel
; draws cell 14 first, so the bar grows from the bottom of the zone.
    LDX #$00
BarFill:
    CPX BarLevel
    BCS BarDark
    LDA #BAR_CHUNK
    JMP BarStore
BarDark:
    LDA #$00
BarStore:
    STA BarBuf,X
    INX
    CPX #BAR_CELLS
    BNE BarFill

; --- a clean first visible line ------------------------------------------
; The stage macro writes every playfield byte, but clearing them here makes
; the gap after the last stage start from a known state and keeps the first
; line's stores before the playfield slots.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0

; --- visible 0-79: the five stage blocks ---------------------------------
; StageBlock is an ACME !macro: the five calls below expand to the same
; stores with a different table index.  Each block holds its color for
; STAGE_LINES scanlines.  The first block is line 37; after five blocks the
; CPU is at cycle 5 of line 117, ready for the gap.
    +StageBlock 0
    +StageBlock 1
    +StageBlock 2
    +StageBlock 3
    +StageBlock 4

; --- visible 80-87: the first gap ----------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #8
GapRow:
    STA WSYNC
    DEY
    BNE GapRow

; --- visible 88-177: the progress bar ------------------------------------
; Fifteen cells of six lines.  The cell bytes are precomputed in VBLANK, so
; the per-cell cost is one load and three stores before the six WSYNCs.  The
; PF1 store completes by cycle 18 (first cell) / 16 (later cells), before
; the first playfield slot at about 22.7; PF0 and PF2 follow before their
; own slots.
    LDA #C_GOLD
    STA COLUPF
    LDX #(BAR_CELLS - 1)    ; cell 14, the top cell
BarCell:
    LDA BarBuf,X
    STA PF1
    LDA #$00
    STA PF0
    STA PF2
    LDY #BAR_LINES
BarLine:
    STA WSYNC
    DEY
    BNE BarLine
    DEX
    BPL BarCell

; --- visible 178-183: the second gap -------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #6
Gap2Row:
    STA WSYNC
    DEY
    BNE Gap2Row

; --- visible 184-191: the eight checksum cells and the build cell ----------
; The two bytes were built at reset from SumByte.  Bit 7 is cell 0 at chunk 2
; and bit 0 is cell 7 at chunk 9; PF0 carries cells 0-1 and PF1 carries cells
; 2-7.  PF1 bit 0 is the BuildFlag cell at chunk 11.  A set bit is a gold
; cell; a clear bit shows the blue (release) or red (debug) border.
    LDA #C_GOLD
    STA COLUPF
    LDA CheckPF0
    STA PF0
    LDA CheckPF1
    STA PF1
    LDA #$00
    STA PF2
    LDY #CHECK_CELLS
ChecksumRow:
    STA WSYNC
    DEY
    BNE ChecksumRow

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
; AdvanceStage — move to the next stage and reload the stage clock
; =============================================================================
; A is the new stage when the routine returns.  StageStep is placed after the
; store, so a breakpoint there reports the value the rest of the frame will
; use.  Stage 5 wraps to 1; when the clock reaches 5 it sets the long hold.
AdvanceStage:
    LDA Stage
    CMP #STAGE_COUNT
    BCC AdvanceIncrement
    LDA #$01                ; COMMIT -> EDIT
    JMP AdvanceStore
AdvanceIncrement:
    CLC
    ADC #$01
AdvanceStore:
    STA Stage
StageStep:                  ; checkpoint: A = the new stage
    CMP #STAGE_COUNT
    BNE AdvanceNormalTimer
    LDA #STAGE_HOLD
    JMP AdvanceTimerStore
AdvanceNormalTimer:
    LDA #STAGE_PERIOD
AdvanceTimerStore:
    STA StageTimer
    RTS

; =============================================================================
; ComputeCheckSum — the 8-bit sum of CheckData, once at reset
; =============================================================================
; A starts at 0 and takes 256 ADC steps; the carry is cleared before each
; add, so the sum wraps at 256 exactly as an 8-bit checksum should.  After
; the loop A holds the low byte.  CheckSum is the checkpoint: a breakpoint
; there reports that byte before it is stored.
; The second half maps the eight bits to the two playfield bytes:
;   bit 7 -> cell 0 -> PF0 bit 6 (chunk 2)
;   bit 6 -> cell 1 -> PF0 bit 7 (chunk 3)
;   bit 5 -> cell 2 -> PF1 bit 7 (chunk 4)
;   ...
;   bit 0 -> cell 7 -> PF1 bit 2 (chunk 9)
ComputeCheckSum:
    LDA #$00
    LDX #$00
SumLoop:
    CLC
    ADC CheckData,X
    INX
    BNE SumLoop
CheckSum:                   ; checkpoint: A = the 8-bit sum
    STA SumByte

    LDA SumByte
    STA Scratch
    LDA #$00
    STA CheckPF0
    STA CheckPF1
    LDX #$00
BitLoop:
    ASL Scratch             ; the next bit falls into carry, MSB first
    BCC NoCheckBit
    LDA CheckPF0
    ORA CheckMask0,X
    STA CheckPF0
    LDA CheckPF1
    ORA CheckMask1,X
    STA CheckPF1
NoCheckBit:
    INX
    CPX #CHECK_CELLS
    BNE BitLoop

; --- the BuildFlag cell at chunk 11 ---------------------------------------
; PF1 bit 0 is one of the two bits the checksum row leaves free; bit 1
; (chunk 10) is the other.  A debug build lights the cell; the release
; build leaves it dark, so the blue border shows through.  The cell is
; eight lines tall, like the checksum cells.
    LDA CheckPF1
    ORA BuildValue
    STA CheckPF1
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
; CHECKSUM BIT MASKS — one entry per cell, 0 where the cell is in the other
; playfield register
; =============================================================================
CheckMask0:
    !byte $40, $80, $00, $00, $00, $00, $00, $00
CheckMask1:
    !byte $00, $00, $80, $40, $20, $10, $08, $04

; =============================================================================
; CheckData — 256 bytes generated at assembly time
; =============================================================================
; !align 255, 0 puts the table on a page boundary.  The alignment is not
; needed for a sum, but it makes the table easy to find in a debugger and it
; demonstrates the directive.  !for emits the 256 bytes; the Python one-liner
; in the lesson document produces the same table and the same checksum.
    !align 255, 0
CheckData:
    !for i, 0, 255 {
        !byte ((i * 7 + 3) + ((i * i) >> 8)) & $FF
    }

; --- an end-of-table marker: !fill writes a fixed byte instead of code ----
; The sixteen $EA bytes mark the end of CheckData and demonstrate !fill.
; They are never executed; the 4,096-byte image comes from the * = $FFFA
; vector block and the padding before it.
    !fill 16, $EA

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
