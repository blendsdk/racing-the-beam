; =============================================================================
; LESSON 68 — EXERCISE 1 SOLUTION: The Zone Gallery with a ball band
; =============================================================================
; Part 9: The DSL Path
;
; What this program does:
;   Three 192-line layouts are built from the same four zone macros in
;   include/kernel_framework.asm.  Each macro expands into a boundary line
;   (colour, table pointer, cleared objects, STA WSYNC) plus a call to one of
;   the four routines in include/kernel_patterns.asm.  The framework checks
;   the line budget at assembly time: every zone costs .dataLines + 1, and
;   +kf_end fails unless the sum is 192.  A one-byte Layout selects the
;   layout at run time with a branch dispatcher (never a ROM jump vector).
;
;   Layout 0 — STATUS:    fill 12 + PF 24 rows + strip 38 + ball 12 + ramp 77
;                         13 + 49 + 39 + 13 + 78 = 192
;   Layout 1 — STARFIELD: ramp 31 + strip 95 + PF 16 rows + fill 30
;                         32 + 96 + 33 + 31 = 192
;   Layout 2 — SPLIT:     PF 24 rows + strip 31 + PF 24 rows + ramp 61
;                         49 + 32 + 49 + 62 = 192
;
;   Every layout's last zone is black: the STATUS and SPLIT ramps end in $00,
;   and STARFIELD ends in +kf_fill 0, 30.  The dispatch/return chain reaches
;   the overscan at 229/19 instead of the usual 229/6, and the VBLANK store
;   completes at about cycle 24; black makes the first visible clocks of the
;   overscan line invisible.
;
; Motion:
;   The STATUS ramp is a 77-byte RAM working copy (RampDataA at $89-$D5),
;   seeded once from the ROM table RampSeedA.  Every other frame the VBLANK
;   code rotates the first 76 bytes by one line and forces the last byte to
;   $00, so the colour bands climb the screen.  Frame drives the auto-demo;
;   SpriteY divides the rotation clock.
;
; Exercise 1:
;   The STATUS layout's ball band uses the framework's +kf_custom escape
;   hatch.  The lesson clears the playfield and players, sets COLUPF and the
;   table pointer, then calls +kf_custom 12, BallBand; the framework sets
;   KernelRows and calls the routine.  BallBand reads KernelPtr/KernelRows
;   and writes ENABL per line.  The fill loses 3 lines (15 -> 12) and the
;   strip loses 10 (48 -> 38); the 12-line ball plus its boundary replace
;   them, so the budget stays 192.  The ball is positioned in VBLANK by the
;   same delay that places P0; its output delay is one clock less, so it is
;   at TIA x ~ 59.
;
; Auto-demo and SELECT:
;   The ROM advances Layout 0 -> 1 -> 2 -> 0 every 240 frames (about four
;   seconds), so the three screenshots are deterministic without keyboard
;   focus and without a synthetic key event.  SELECT also advances the layout
;   on a fresh press and resets Frame to 0, so a layout always opens on its
;   own frame 0.
;
; The zone framework (include/kernel_framework.asm):
;   +kf_begin                     reset the assembly-time budget
;   +kf_fill  .color, .dataLines  solid COLUBK band
;   +kf_pf    .color, .rows, .t   PF0/PF1/PF2 band, two lines per row
;   +kf_strip .color, .lines, .t  one GRP0 byte per line
;   +kf_ramp  .lines, .t          one COLUBK byte per line
;   +kf_custom .lines, .routine   a lesson-supplied band
;   +kf_end                       !error unless the budget is 192
;   +kf_dispatch .l0, .l1, .l2    branch on Layout = 0/1/2
;
; Frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines.
;   StartFrame    259/3   the first VSYNC instruction
;   VblankStart     0/5   the first VBLANK instruction
;   BodyStart      37/5   the first picture line (the first boundary line)
;   KernelEnd     229/19  the last zone's handler has returned
;   OverscanStart 229/19  the first overscan instruction (the 13-cycle tax)
;   LayoutRead    A = 0/1/2, the active layout
;   LayoutWrite   A = the new layout after a SELECT edge or the auto-demo
;   FrameRead     A = the frame counter after the increment
;
; RAM map (+clean_start zeroes every byte):
;   $80-$81 KernelPtr   the framework's table pointer (kernel_patterns.asm)
;   $82     KernelRows  the framework's row/line count
;   $83     Layout      0 = STATUS, 1 = STARFIELD, 2 = SPLIT
;   $84     Frame       the frame counter, 0..239 between auto-advances
;   $85     PrevSelect  SELECT state last frame
;   $86     NewSelect   SELECT state this frame
;   $87     Startup     1 until the first VBLANK's one-time ramp seed
;   $88     SpriteY     the ramp rotation phase (incremented every frame)
;   $89-$D5 RampDataA   the 77-byte RAM ramp (the STATUS motion)
;   $D6     Tmp         the rotation's saved first byte
;   $D7-$F7 free
;   $F8-$FF stack
;   The score library is not used; its usual $A0-$D7 window is part of the
;   ramp buffer and the free space above it.
;
; Build: acme -f plain -o build/exercise-01-solution.bin \
;        lessons/part9-dsl-path/68-kernel-architecture/exercise-01-solution.asm
; Run:   stella build/exercise-01-solution.bin
; The ROM is exactly 4,096 bytes; no mapper, no bankswitching.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; CONSTANTS
; =============================================================================
VBLANK_TIMER    = 44            ; the 37-line VBLANK (44 ticks)
OVERSCAN_TIMER  = 36            ; the 30-line overscan (36 ticks)
LAYOUT_COUNT    = 3             ; STATUS, STARFIELD, SPLIT
AUTO_FRAMES     = 240           ; about four seconds at 60 Hz
RAMP_LINES      = 77            ; the STATUS ramp's length
RAMP_ROTATE     = 75            ; the first 76 bytes rotate; byte 76 stays 0

C_BG            = $02           ; STATUS fill: dark grey
C_PF            = $1A           ; STATUS playfield: gold
C_FG            = $C8           ; STATUS strip: green
C_STAR          = $0E           ; STARFIELD strip: white
C_PF2           = $9A           ; STARFIELD playfield: light blue
C_BG2           = $02           ; SPLIT first-line background: dark grey
C_PF3           = $84           ; SPLIT upper playfield: blue
C_FG2           = $46           ; SPLIT strip: red
C_PF4           = $C8           ; SPLIT lower playfield: green
C_BALL          = $46           ; the exercise's ball: red

; =============================================================================
; RAM
; =============================================================================
; The framework owns $80-$82 through include/kernel_patterns.asm.  Every
; lesson variable starts at $83, the first byte the pattern library leaves
; free.
Layout      = $83
Frame       = $84
PrevSelect  = $85
NewSelect   = $86
Startup     = $87
SpriteY     = $88
RampDataA   = $89               ; 77 bytes: $89-$D5
Tmp         = $D6               ; the rotation's saved first byte
; $D7-$F7 free; $F8-$FF is the stack.

; =============================================================================
; THE PATTERN LIBRARY AND THE ZONE FRAMEWORK
; =============================================================================
; kernel_patterns.asm contains the four band routines and defines KernelPtr
; and KernelRows at $80-$82.  kernel_framework.asm contains macros only: it
; emits no code, sets no program counter and declares no vector.  Both are
; sourced after * = $F000 because the pattern library contains code.
    * = $F000

    !source "include/kernel_patterns.asm"
    !source "include/kernel_framework.asm"

; =============================================================================
; THE BALL BAND — the framework's +kf_custom escape hatch
; =============================================================================
; The framework's four built-in zones draw the background, the playfield and
; player 0.  The exercise's ball band is lesson code: the layout clears the
; playfield and players, sets COLUPF and the table pointer, and calls
; +kf_custom 12, BallBand.  The framework sets KernelRows, ends the boundary
; line and calls BallBand; the routine owns the ball object.

; =============================================================================
; RESET
; =============================================================================
Reset:
    +clean_start

    LDA #0
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
    STA COLUBK
    STA COLUPF
    STA COLUP0
    STA COLUP1

    LDA #$21                ; reflect the playfield (bit 0); 4-pixel ball
    STA CTRLPF
    LDA #$03                ; three close copies of player 0
    STA NUSIZ0
    LDA #0
    STA NUSIZ1

    ; --- the initial gallery state ---------------------------------------
    LDA #0
    STA Layout
    STA Frame
    STA PrevSelect
    STA NewSelect
    STA SpriteY
    LDA #1
    STA Startup             ; the first VBLANK seeds the ramp

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
; SELECT — one layout advance per fresh press
; -----------------------------------------------------------------------------
    LDA SWCHB
    AND #$02
    EOR #$02                 ; 1 = SELECT pressed
    STA NewSelect
    AND PrevSelect
    EOR NewSelect            ; new & ~previous: a fresh press
    BEQ NoLayoutSwitch

    INC Layout
    LDA Layout
    CMP #LAYOUT_COUNT
    BCC SelectStore
    LDA #0
SelectStore:
    JSR StoreLayout

NoLayoutSwitch:
    LDA NewSelect
    STA PrevSelect

; -----------------------------------------------------------------------------
; ONE-TIME RAMP SEED — the first VBLANK copies the ROM ramp into RAM
; -----------------------------------------------------------------------------
    LDA Startup
    BEQ RampSeeded
    LDA #0
    STA Startup
    JSR SeedRamp
RampSeeded:

; -----------------------------------------------------------------------------
; FRAME COUNTER AND AUTO-DEMO — 240 frames per layout
; -----------------------------------------------------------------------------
    INC Frame
    LDA Frame
FrameRead:                   ; checkpoint: A = the frame counter
    NOP
    CMP #AUTO_FRAMES
    BNE NoAutoAdvance
    INC Layout
    LDA Layout
    CMP #LAYOUT_COUNT
    BCC AutoStore
    LDA #0
AutoStore:
    JSR StoreLayout
NoAutoAdvance:

    LDA Layout
LayoutRead:                  ; checkpoint: A = the active layout
    NOP

; -----------------------------------------------------------------------------
; MOTION — rotate the STATUS ramp every other frame
; -----------------------------------------------------------------------------
    INC SpriteY
    LDA SpriteY
    AND #$01
    BNE NoRampRotate
    JSR RotateRamp
NoRampRotate:

; -----------------------------------------------------------------------------
; POSITION PLAYER 0 FOR THE STRIP
; -----------------------------------------------------------------------------
; The strip is GRP0.  Three close copies at TIA x ~ 60 put the band in the
; middle-left of the screen.  The delay loop writes RESP0 at about cycle 39,
; 49 colour clocks into the visible area; the player's output delay and the
; TIA's three-clock position quantization put the displayed left edge at
; x ~ 60.  The position latches for every following line, so one strobe per
; frame is enough.
    STA WSYNC
    LDX #7
PositionDelay:
    DEX
    BNE PositionDelay
    LDA #0
    STA RESP0

    ; The ball has its own horizontal position.  This delay block is byte-
    ; identical to the player's, but the ball's output delay is one clock
    ; less, so its left edge is at TIA x ~ 59.  CTRLPF bit 5 makes it four
    ; pixels wide.
    STA WSYNC
    LDX #7
BallPositionDelay:
    DEX
    BNE BallPositionDelay
    LDA #0
    STA RESBL

; -----------------------------------------------------------------------------
; FIRST-LINE PRELUDE — the colour BodyStart must already show
; -----------------------------------------------------------------------------
; The dispatcher and the first zone's setup run after pixel 0.  VBLANK
; therefore leaves the first zone's background in COLUBK, so the first
; picture line has no left-edge sliver:
;   STATUS    the fill's background
;   STARFIELD the first byte of the ROM ramp
;   SPLIT     the dark background behind the upper playfield
    LDA Layout
    CMP #1
    BEQ PreludeStar
    CMP #2
    BEQ PreludeSplit
    LDA #C_BG
    JMP PreludeStore
PreludeStar:
    LDA RampDataB
    JMP PreludeStore
PreludeSplit:
    LDA #C_BG2
PreludeStore:
    STA COLUBK

    ; Clear the objects and the playfield for the first boundary line.
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL

VblankWait:
    +wait_timer
    LDA #0
    STA VBLANK               ; picture on

; =============================================================================
; THE VISIBLE PICTURE — one dispatch, then the selected layout's zones
; =============================================================================
BodyStart:                   ; checkpoint: scanline 37, visible line 0
    JSR DrawKernel

; The last zone's handler returns here through the layout's RTS.  The label
; is the common point after the last zone of whichever layout ran.
KernelEnd:                   ; checkpoint: scanline 229, cycle 19
OverscanStart:               ; checkpoint: scanline 229, cycle 19
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; THE DISPATCHER — a branch on Layout, never a ROM jump vector
; =============================================================================
DrawKernel:
    +kf_dispatch Layout0, Layout1, Layout2

; =============================================================================
; LAYOUT 0 — STATUS: a solid band, a playfield, a sprite strip, a moving ramp
; =============================================================================
; Ledger: fill 12+1 = 13, PF 24x2+1 = 49, strip 38+1 = 39, ball 12+1 = 13,
; ramp 77+1 = 78; total 192.
Layout0:
    +kf_begin
    +kf_fill C_BG, 12
    +kf_pf C_PF, 24, PFDataA
    +kf_strip C_FG, 38, StripDataA

    ; The ball zone: clears first, then colour and pointer, then the
    ; framework's +kf_custom (KernelRows = 12, WSYNC, JSR BallBand).
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL
    LDA #C_BALL
    STA COLUPF
    LDA #<BallData
    STA KernelPtr
    LDA #>BallData
    STA KernelPtr+1
    +kf_custom 12, BallBand

    +kf_ramp RAMP_LINES, RampDataA
    +kf_end
    RTS

; =============================================================================
; LAYOUT 1 — STARFIELD: a ramp, a star strip, a star playfield, black
; =============================================================================
; Ledger: 31+1 = 32, 95+1 = 96, 16x2+1 = 33, 30+1 = 31; total 192.
Layout1:
    +kf_begin
    +kf_ramp 31, RampDataB
    +kf_strip C_STAR, 95, StripDataB
    +kf_pf C_PF2, 16, PFDataB
    +kf_fill 0, 30
    +kf_end
    RTS

; =============================================================================
; LAYOUT 2 — SPLIT: two playfield bands with a sprite strip between them
; =============================================================================
; Ledger: 24x2+1 = 49, 31+1 = 32, 24x2+1 = 49, 61+1 = 62; total 192.
Layout2:
    +kf_begin
    +kf_pf C_PF3, 24, PFDataC
    +kf_strip C_FG2, 31, StripDataC
    +kf_pf C_PF4, 24, PFDataD
    +kf_ramp 61, RampDataC
    +kf_end
    RTS

; =============================================================================
; StoreLayout — the one place that writes Layout
; =============================================================================
; The SELECT edge and the auto-demo both compute the next value in A and call
; this routine.  A = 0..LAYOUT_COUNT-1.  The checkpoint sits after the store,
; so a debugger sees the new layout on either path.  A layout change resets
; the frame and the motion phase, so a layout always opens on its first frame.
StoreLayout:
    STA Layout
LayoutWrite:                 ; checkpoint: A = the new layout
    NOP
    LDA #0
    STA Frame
    STA SpriteY
    RTS

; =============================================================================
; THE RAMP'S RAM WORKING COPY
; =============================================================================
; SeedRamp copies the 77-byte ROM seed into the RAM buffer.  It runs once, in
; the first VBLANK, after +clean_start has cleared the RAM.
SeedRamp:
    LDX #0
SeedRampLoop:
    LDA RampSeedA,X
    STA RampDataA,X
    INX
    CPX #RAMP_LINES
    BNE SeedRampLoop
    RTS

; RotateRamp moves the first 76 colours up one line: byte 1 becomes byte 0,
; ..., byte 75 becomes byte 74, and the saved old byte 0 becomes byte 75.
; Byte 76 is forced to black on every frame, so the last zone always ends
; black and the overscan's 13-cycle tax stays invisible.
RotateRamp:
    LDA RampDataA
    STA Tmp
    LDX #0
RotateRampLoop:
    LDA RampDataA+1,X
    STA RampDataA,X
    INX
    CPX #RAMP_ROTATE
    BNE RotateRampLoop
    LDA Tmp
    STA RampDataA+(RAMP_LINES-2)
    LDA #0
    STA RampDataA+(RAMP_LINES-1)
    RTS

; =============================================================================
; BallBand — the +kf_custom routine for the exercise's ball band
; =============================================================================
; +kf_custom sets KernelRows = 12 and calls this routine after the boundary
; line.  KernelPtr points at BallData; each byte is one line of ENABL ($02 =
; ball on, $00 = off).  The routine returns at cycle 13 of the line after its
; last data line, like the framework's built-in handlers.
BallBand:
    LDY #0
BallBandLine:
    LDA (KernelPtr),Y
    STA ENABL               ; $02 = ball on, $00 = ball off
BallWrite:                  ; checkpoint: A = the ball enable byte
    STA WSYNC
    INY
    CPY KernelRows
    BNE BallBandLine
    RTS

; =============================================================================
; DATA — the playfield rows (3 bytes per row, two scanlines per row)
; =============================================================================
; Each table is page-aligned so a row's three reads never cross a page: the
; KernelPFRows ledger is 57 cycles per row, and a page cross would add one.
; The bytes are in pixel-deadline order: PF0, then PF1, then PF2.

; STATUS: four repetitions of a six-row console motif (solid bar, side rails,
; a centre block, a gap).
    !align 255, 0, $EA
PFDataA:
    !byte $F0, $FF, $FF     ; row 0:  solid bar
    !byte $F0, $FF, $FF     ; row 1
    !byte $10, $00, $01     ; row 2:  side rails
    !byte $10, $00, $01     ; row 3
    !byte $10, $18, $01     ; row 4:  centre block
    !byte $00, $00, $00     ; row 5:  gap
    !byte $F0, $FF, $FF     ; row 6
    !byte $F0, $FF, $FF     ; row 7
    !byte $10, $00, $01     ; row 8
    !byte $10, $00, $01     ; row 9
    !byte $10, $18, $01     ; row 10
    !byte $00, $00, $00     ; row 11
    !byte $F0, $FF, $FF     ; row 12
    !byte $F0, $FF, $FF     ; row 13
    !byte $10, $00, $01     ; row 14
    !byte $10, $00, $01     ; row 15
    !byte $10, $18, $01     ; row 16
    !byte $00, $00, $00     ; row 17
    !byte $F0, $FF, $FF     ; row 18
    !byte $F0, $FF, $FF     ; row 19
    !byte $10, $00, $01     ; row 20
    !byte $10, $00, $01     ; row 21
    !byte $10, $18, $01     ; row 22
    !byte $00, $00, $00     ; row 23

; STARFIELD: 16 sparse rows; the same star pattern in both halves because
; CTRLPF bit 0 = 1 mirrors the left half.
    !align 255, 0, $EA
PFDataB:
    !byte $12, $48, $21     ; row 0
    !byte $84, $21, $04     ; row 1
    !byte $21, $04, $92     ; row 2
    !byte $48, $92, $48     ; row 3
    !byte $92, $04, $21     ; row 4
    !byte $04, $21, $84     ; row 5
    !byte $21, $48, $12     ; row 6
    !byte $84, $92, $48     ; row 7
    !byte $12, $04, $21     ; row 8
    !byte $48, $21, $84     ; row 9
    !byte $21, $92, $04     ; row 10
    !byte $92, $48, $12     ; row 11
    !byte $04, $21, $48     ; row 12
    !byte $21, $84, $92     ; row 13
    !byte $48, $12, $04     ; row 14
    !byte $92, $21, $48     ; row 15

; SPLIT upper: four repetitions of a three-row solid bar, two side-rail rows
; and a gap.
    !align 255, 0, $EA
PFDataC:
    !byte $F0, $FF, $FF     ; row 0
    !byte $F0, $FF, $FF     ; row 1
    !byte $F0, $FF, $FF     ; row 2
    !byte $10, $00, $01     ; row 3
    !byte $10, $00, $01     ; row 4
    !byte $00, $00, $00     ; row 5
    !byte $F0, $FF, $FF     ; row 6
    !byte $F0, $FF, $FF     ; row 7
    !byte $F0, $FF, $FF     ; row 8
    !byte $10, $00, $01     ; row 9
    !byte $10, $00, $01     ; row 10
    !byte $00, $00, $00     ; row 11
    !byte $F0, $FF, $FF     ; row 12
    !byte $F0, $FF, $FF     ; row 13
    !byte $F0, $FF, $FF     ; row 14
    !byte $10, $00, $01     ; row 15
    !byte $10, $00, $01     ; row 16
    !byte $00, $00, $00     ; row 17
    !byte $F0, $FF, $FF     ; row 18
    !byte $F0, $FF, $FF     ; row 19
    !byte $F0, $FF, $FF     ; row 20
    !byte $10, $00, $01     ; row 21
    !byte $10, $00, $01     ; row 22
    !byte $00, $00, $00     ; row 23

; SPLIT lower: a staircase that walks from the top-left pair of chunks to the
; middle of the field.  With reflect mode it becomes a V.
    !align 255, 0, $EA
PFDataD:
    !byte $F0, $00, $00     ; row 0
    !byte $F0, $00, $00     ; row 1
    !byte $70, $00, $00     ; row 2
    !byte $70, $00, $00     ; row 3
    !byte $30, $00, $00     ; row 4
    !byte $30, $00, $00     ; row 5
    !byte $10, $00, $00     ; row 6
    !byte $10, $00, $00     ; row 7
    !byte $10, $80, $00     ; row 8
    !byte $10, $80, $00     ; row 9
    !byte $10, $40, $00     ; row 10
    !byte $10, $40, $00     ; row 11
    !byte $10, $20, $00     ; row 12
    !byte $10, $20, $00     ; row 13
    !byte $10, $10, $00     ; row 14
    !byte $10, $10, $00     ; row 15
    !byte $10, $08, $00     ; row 16
    !byte $10, $08, $00     ; row 17
    !byte $10, $04, $00     ; row 18
    !byte $10, $04, $00     ; row 19
    !byte $10, $02, $00     ; row 20
    !byte $10, $02, $00     ; row 21
    !byte $10, $01, $00     ; row 22
    !byte $10, $01, $00     ; row 23

; =============================================================================
; DATA — the exercise's ball band (one ENABL byte per line)
; =============================================================================
; 12 lines: 3-on, 2-off, 3-on, 2-off, 2-on.  12 data lines + the boundary
; line = 13 of the layout's 192.
    !align 255, 0, $EA
BallData:
    !byte $02, $02, $02, $00, $00, $02
    !byte $02, $02, $00, $00, $02, $02

; =============================================================================
; DATA — the player-0 strips (one GRP0 byte per line)
; =============================================================================
; Each strip is page-aligned and shorter than 256 bytes, so the
; KernelSpriteStrip read never crosses a page (19 cycles per line, 18 on the
; last line).

; STATUS: six eight-line diamonds.
    !align 255, 0, $EA
StripDataA:
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18

; STARFIELD: 95 sparse bytes.  Every byte is one line of an eight-pixel-wide
; slice; the three close copies repeat the slice at x, x+16 and x+32.
    !align 255, 0, $EA
StripDataB:
    !byte $00, $08, $00, $22, $00, $41, $00, $14
    !byte $00, $82, $00, $28, $00, $44, $00, $91
    !byte $00, $20, $00, $0A, $00, $50, $00, $84
    !byte $00, $12, $00, $40, $00, $21, $00, $08
    !byte $00, $44, $00, $82, $00, $11, $00, $24
    !byte $00, $48, $00, $90, $00, $05, $00, $22
    !byte $00, $80, $00, $14, $00, $41, $00, $08
    !byte $00, $22, $00, $84, $00, $10, $00, $42
    !byte $00, $08, $00, $21, $00, $84, $00, $12
    !byte $00, $40, $00, $08, $00, $22, $00, $44
    !byte $00, $81, $00, $10, $00, $42, $00, $24
    !byte $00, $08, $00, $41, $00, $82, $00

; SPLIT: three diamonds and seven extra rows.
    !align 255, 0, $EA
StripDataC:
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C

; =============================================================================
; DATA — the ramps (one COLUBK byte per line)
; =============================================================================

; The STATUS seed: a 16-colour cycle repeated four times, then 12 colours and
; the black last line.  77 bytes.  SeedRamp copies it into RampDataA.
    !align 255, 0, $EA
RampSeedA:
    !byte $02, $04, $06, $08, $0A, $0C, $0E, $1A
    !byte $2A, $3A, $4A, $5A, $6A, $7A, $8A, $9A
    !byte $02, $04, $06, $08, $0A, $0C, $0E, $1A
    !byte $2A, $3A, $4A, $5A, $6A, $7A, $8A, $9A
    !byte $02, $04, $06, $08, $0A, $0C, $0E, $1A
    !byte $2A, $3A, $4A, $5A, $6A, $7A, $8A, $9A
    !byte $02, $04, $06, $08, $0A, $0C, $0E, $1A
    !byte $2A, $3A, $4A, $5A, $6A, $7A, $8A, $9A
    !byte $02, $04, $06, $08, $0A, $0C, $0E, $1A
    !byte $2A, $3A, $4A, $5A, $00

; STARFIELD: a blue-to-black fade.  It is not the last zone (the black fill
; is), so its last byte need not be black.
    !align 255, 0, $EA
RampDataB:
    !byte $9A, $98, $96, $94, $92, $90, $8E, $8C
    !byte $8A, $88, $86, $84, $82, $80, $7A, $78
    !byte $76, $74, $72, $70, $6E, $6C, $6A, $68
    !byte $66, $64, $62, $60, $5A, $58, $00

; SPLIT: a sunset from gold to violet, then black.  61 bytes; the last byte
; is $00 because this is the layout's last zone.
    !align 255, 0, $EA
RampDataC:
    !byte $1A, $1A, $2A, $2A, $3A, $3A, $4A, $4A
    !byte $5A, $5A, $6A, $6A, $7A, $7A, $8A, $8A
    !byte $9A, $9A, $AA, $AA, $1A, $1A, $2A, $2A
    !byte $3A, $3A, $4A, $4A, $5A, $5A, $6A, $6A
    !byte $7A, $7A, $8A, $8A, $9A, $9A, $AA, $AA
    !byte $1A, $1A, $2A, $2A, $3A, $3A, $4A, $4A
    !byte $5A, $5A, $6A, $6A, $7A, $7A, $8A, $8A
    !byte $9A, $9A, $AA, $AA, $00

; =============================================================================
; VECTORS — the 6507 reads RESET at $FFFC and jumps to Reset
; =============================================================================
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
