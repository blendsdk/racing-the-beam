; =============================================================================
; LESSON 77 — EXERCISE 1 SOLUTION: Three Palettes, Reverse Order
; =============================================================================
; Part 11: Legendary Techniques
;
; The exercise: give the colour mosaic a THIRD palette pair and run the phases
; in reverse order.
;
; What this program does:
;   The main ROM has two palettes and counts the phase up: A, B, A, B, ...
;   This ROM has three palettes and counts the phase DOWN: C, B, A, C, B, A,
;   ...  Each band therefore cycles through three colours instead of two, at
;   20 Hz per colour instead of 30 Hz.
;
;   The kernel did not change at all.  It still writes COLUBK from the
;   ActiveBand array and holds the colour for 24 scanlines.  What changed is
;   the size of the table and the rule that picks the three bytes staged into
;   ActiveBand:
;
;     BandTable is 24 bytes: palette A (0-7), palette B (8-15),
;     palette C (16-23).  StagePalette still computes Phase*8 and copies
;     eight bytes from there, so Phase must be 0, 1 or 2.
;
;     The phase counter steps DOWN through a three-entry table:
;       NextPhase[0] = 2, NextPhase[1] = 0, NextPhase[2] = 1
;
;   The auto-demo holds one palette per two-second segment, and it holds them
;   in reverse order too: palette C from frame 120, palette B from frame 240,
;   palette A from frame 360, then it releases the freeze at frame 480 and the
;   six-second cycle becomes an eight-second one.
;
;   THE THIRD COLOUR IS NOT FREE.  With three palettes each colour is on
;   screen for one frame in three, so its repetition rate is 20 Hz.  That is
;   much closer to the rate at which the eye stops integrating, and the
;   flicker of the mosaic becomes visible — especially in the bright bands.
;   The extra colour is real; the flicker is the price.  Compare the ROM with
;   the main lesson: two palettes at 30 Hz read as a steady blend, three at
;   20 Hz read as a flicker.
;
;   Frame: 3 VSYNC + 37 VBLANK + 192 visible (8 bands x 24 lines) + 30
;   overscan = 262 lines.  ROM: 4,096 bytes.
;
; RAM map (the same map as the main ROM):
;   $80 Phase       0 = palette A, 1 = palette B, 2 = palette C
;   $81 Freeze      1 = hold the current phase
;   $82 AutoDemo    1 until SELECT is pressed; then 0
;   $83 FrameLo     frame counter low byte
;   $84 DemoTimer   frames inside the current two-second segment (0..119)
;   $85 PrevSelect  SELECT edge latch
;   $86 DemoStep    0 alternate, 1 hold C, 2 hold B, 3 hold A
;   $87 ActiveBand  8 bytes: the colour of each band this frame
;   $8F-$F7         free
;   $F8-$FF         the stack
;
; Build: acme -f plain -o build/exercise-01.bin \
;        lessons/part11-legendary/77-interlaced-flicker/exercise-01-solution.asm
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan

BAND_COUNT     = 8
BAND_LINES     = 24
VISIBLE_LINES  = BAND_COUNT * BAND_LINES   ; 192

DEMO_SEGMENT   = 120     ; 2 s per segment
DEMO_SEGMENTS  = 4       ; alternate, hold C, hold B, hold A

; --- palette bytes: every one at luminance level 5 ---------------------------
C_RED          = $4A
C_PEACH        = $3A
C_ORANGE       = $2A
C_PINK         = $5A
C_VIOLET       = $7A
C_BLUE         = $8A
C_LIGHT_BLUE   = $9A
C_AQUA         = $AA
C_TEAL         = $BA
C_GREEN        = $CA
C_YELLOW_GREEN = $EA

!if BAND_COUNT * BAND_LINES != 192 {
    !error "the eight bands must total 192 visible lines"
}

; =============================================================================
; RAM ALLOCATION
; =============================================================================
Phase        = $80   ; 0 = A, 1 = B, 2 = C
Freeze       = $81   ; 1 = hold the current phase
AutoDemo     = $82   ; 1 until SELECT is pressed
FrameLo      = $83
DemoTimer    = $84
PrevSelect   = $85
DemoStep     = $86
ActiveBand   = $87   ; 8 bytes: $87-$8E

    * = $F000

; =============================================================================
; RESET
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT
    STA NUSIZ0
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA CTRLPF
    STA COLUPF
    STA COLUP0
    STA COLUP1
    STA COLUBK

; --- start on the LAST palette: the reverse order begins at C -----------------
; Phase is 0 here, but the first frame's vertical blank steps it through
; NextPhase[0] = 2, so the first picture drawn is palette C, then B, then A.
    LDA #$00
    STA Phase
    LDA #$00
    STA Freeze
    STA FrameLo
    STA DemoTimer
    STA PrevSelect
    STA DemoStep
    LDA #$01
    STA AutoDemo
    JSR StagePalette

; =============================================================================
; FRAME
; =============================================================================
StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    INC FrameLo

; --- SELECT: freeze by hand and stop the auto-demo ---------------------------
    LDA SWCHB
    AND #$02
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA #$00
    STA AutoDemo
    LDA Freeze
    EOR #$01
    STA Freeze
    JMP SelectDone
SelectReleased:
    LDA #$00
    STA PrevSelect
SelectDone:

; --- the auto-demo: alternate, then hold C, B, A in that order ---------------
; The three holds are the REVERSE of the main ROM's order.  HoldPhase[0..2]
; is the phase each hold pins; the releases happen when DemoStep reaches
; DEMO_SEGMENTS.
    LDA AutoDemo
    BEQ DemoDone
    INC DemoTimer
    LDA DemoTimer
    CMP #DEMO_SEGMENT
    BCC DemoDone
    LDA #$00
    STA DemoTimer
    INC DemoStep
    LDA DemoStep
    CMP #DEMO_SEGMENTS
    BNE DemoHold
    LDA #$00
    STA Freeze              ; the cycle is over: release and restart
    STA DemoStep
    JMP DemoDone
DemoHold:
    TAX                     ; DemoStep is 1, 2 or 3
    DEX                     ; 0, 1 or 2
    LDA HoldPhase,X         ; 2, 1 or 0: palette C, then B, then A
    STA Phase
    LDA #$01
    STA Freeze              ; pin it for the next two seconds
DemoDone:

; --- the phase steps DOWN: 2 -> 1 -> 0 -> 2 ... ------------------------------
    LDA Freeze
    BNE PhaseFixed
    LDX Phase
    LDA NextPhase,X
    STA Phase
PhaseFixed:
    JSR StagePalette

    +wait_timer
    LDA #$00
    STA VBLANK

; =============================================================================
; THE KERNEL — unchanged from the main ROM: eight bands, 24 lines each
; =============================================================================
BodyStart:
    LDX #$00
BandLoop:
    LDA ActiveBand,X
    STA COLUBK
    LDY #BAND_LINES
BandLines:
    STA WSYNC
    DEY
    BNE BandLines
    INX
    CPX #BAND_COUNT
    BNE BandLoop

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; STAGEPALETTE — Phase*8 picks one of the three palettes
; =============================================================================
; Phase is 0, 1 or 2, so Phase*8 is 0, 8 or 16: the first byte of A, B or C.
StagePalette:
    LDA Phase
    ASL
    ASL
    ASL
    TAY
    LDX #$00
.copy:
    LDA BandTable,Y
    STA ActiveBand,X
    INY
    INX
    CPX #BAND_COUNT
    BNE .copy
    RTS

; =============================================================================
; THE PHASE STEP AND THE DEMO'S HOLD ORDER
; =============================================================================
; NextPhase counts DOWN: 0 -> 2, 1 -> 0, 2 -> 1.  Read the table as "the
; phase after this one".
NextPhase:
    !byte 2, 0, 1
; HoldPhase is the reverse demonstration order: C, B, A.
HoldPhase:
    !byte 2, 1, 0

; =============================================================================
; THE BAND TABLE — three palettes of eight bytes (index = Phase*8 + Band)
; =============================================================================
;   band  palette A          palette B          palette C
;     0   red        $4A     green      $CA     peach      $3A
;     1   blue       $8A     red        $4A     aqua       $AA
;     2   green      $CA     blue       $8A     pink       $5A
;     3   orange     $2A     blue       $8A     violet     $7A
;     4   violet     $7A     yellow-grn $EA     light blue $9A
;     5   aqua       $AA     pink       $5A     orange     $2A
;     6   peach      $3A     teal-green $BA     green      $CA
;     7   light blue $9A     violet     $7A     red        $4A
BandTable:
    ; --- palette A -----------------------------------------------------------
    !byte C_RED, C_BLUE, C_GREEN, C_ORANGE
    !byte C_VIOLET, C_AQUA, C_PEACH, C_LIGHT_BLUE
    ; --- palette B -----------------------------------------------------------
    !byte C_GREEN, C_RED, C_BLUE, C_BLUE
    !byte C_YELLOW_GREEN, C_PINK, C_TEAL, C_VIOLET
    ; --- palette C -----------------------------------------------------------
    !byte C_PEACH, C_AQUA, C_PINK, C_VIOLET
    !byte C_LIGHT_BLUE, C_ORANGE, C_GREEN, C_RED

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
