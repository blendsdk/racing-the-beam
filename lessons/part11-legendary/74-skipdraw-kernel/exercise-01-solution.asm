; =============================================================================
; LESSON 74 — EXERCISE 1 SOLUTION: A Second Skipdraw Sprite
; =============================================================================
; Part 11: Legendary Techniques
;
; The exercise: add P1 as a second skipdraw sprite with its own Y.
;
; This solution adds a moon: an 8x8 shape drawn by P1 at the fixed screen
; line MOON_Y = 56 and the fixed horizontal position MOON_X = 144.  The
; moon uses the same unsigned difference, as a direct table index, with its own Y
; its own graphic table.  It is a complete 4,096-byte ROM; the frame stays
; 262 lines.
;
; The budget is the point of the exercise.  Three objects with the
; branch form cannot be given real margin.  The lesson's padded rocket is
; 25; adding the 18-cycle exhaust and a 24-cycle branch-form moon gives
; 25 + 18 + 24 + 7 = 74 cycles of work, and with the WSYNC's 3 cycles that
; is 77 — past the 76-cycle line.  Even the unpadded branch forms are
; 24 + 18 + 24 + 7 = 73, exactly the 76-cycle line with zero margin.
;
; The moon therefore uses the BRANCHLESS 256-byte table, the form the
; second exercise develops for P0: the unsigned difference X - MoonY is
; used directly as an 8-bit index into a page-aligned table whose first
; eight entries are the moon and whose other 248 are zero.  Its block is
; 16 cycles, and the flight line becomes:
;
;   rocket (P0)   24   (the unpadded branch form)
;   exhaust (M0)  18   (the branchless carry form)
;   moon (P1)     16   (the branchless table form)
;   loop           7   (INX, CPX, BNE taken)
;   -----------------
;   worst case    65   cycles of work; the WSYNC write completes at 68
;
; That is eight cycles of margin.  The exercise's subject is the second
; sprite; the table is the budget tool that makes it fit.
;
; Deadline check (the line's cycle 0 is the start of HBLANK; the visible
; area begins at cycle 22.67 and pixel X is drawn at 22.67 + X/3):
;
;   P0's store: the unpadded draw path ends at cycle 24.  The rocket's
;   left edge is X=76, drawn at cycle 48.0.  In time by 24 cycles.
;
;   M0's store: 24 + 18 = 42.  The exhaust at X=79 is drawn at cycle
;   49.0.  In time by 7 cycles.
;
;   P1's store: 24 + 18 + 16 = 58.  The moon's left edge is X=144, drawn
;   at cycle 70.67.  In time by 12.7 cycles, so the moon's first column
;   is not clipped.
;
; The horizontal positions are set once at reset: the two positioners for
; P0 and M0 are the lesson's, and a third (SetHorizPosP1) sets HMP1 and
; RESP1 for the moon.  One HMOVE applies all three fine values.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   The bands, the star table, the ground and the auto-demo are the
;   lesson's.  The moon never enters the star or ground bands (Y=56..63).
;
; Checkpoints: StartFrame (259/3), VblankStart (0/5), BodyStart (37/5);
;   the first flight line is 61, the first ground line 205, the first
;   blanked line 229.
;
; RAM: $80 Frame, $81 PrevSelect, $82 RocketY, $83 ExhaustY, $84 MoonY.
;   $85-$F7 free; the stack is $F8-$FF.
;
; Build: acme -f plain -o build/exercise-01.bin \
;        lessons/part11-legendary/74-skipdraw-kernel/exercise-01-solution.asm
; Run:   stella build/exercise-01.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan

VISIBLE_LINES  = 192
STAR_LINES     = 24
FLIGHT_LINES   = 144
GROUND_LINES   = 24
FLIGHT_START   = STAR_LINES                  ; 24
FLIGHT_END     = STAR_LINES + FLIGHT_LINES   ; 168

ROCKET_HEIGHT  = 16
EXHAUST_HEIGHT = 8
ROCKET_X       = 76
EXHAUST_X      = 79
MOON_X         = 144
MOON_Y         = 56      ; the moon's fixed top screen line

POS_BIAS       = 3

DEMO_LEN       = 64

; --- colours -----------------------------------------------------------------
C_SKY          = $82
C_STAR         = $0E
C_ROCKET       = $1A
C_GROUND       = $26
C_HORIZON      = $2A
C_MOON         = $86     ; the moon: pale blue-grey

!if STAR_LINES + FLIGHT_LINES + GROUND_LINES != VISIBLE_LINES {
    !error "the three bands must total 192 visible lines"
}

; =============================================================================
; RAM ALLOCATION ($80-$84; +clean_start zeroes every byte)
; =============================================================================
Frame        = $80
PrevSelect   = $81
RocketY      = $82
ExhaustY     = $83
MoonY        = $84
;
; $85-$F7 are free (115 bytes).  The stack lives at $F8-$FF; the call depth
; stays at one level (the three positioners at reset only).

; =============================================================================
; ROCKETSKIPDRAW — the unpadded canonical form, 24 draw / 17 skip
; =============================================================================
; The lesson's padded form makes both paths 25 cycles.  This solution drops
; the padding so a second sprite fits: the draw path is 24 and the skip
; path is 17.  The store is still unconditional and there is still only
; one branch; only the line time varies.
;
;   shared: LDY 2 + TXA 2 + SEC 2 + SBC 3 + CMP 2 = 11
;   draw:   BCS 2 (not taken) + TAY 2 + LDA 4 + TAY 2 + STY 3 = 13 -> 24
;   skip:   BCS 3 (taken) + STY 3 = 6 -> 17
!macro RocketSkipdraw {
    LDY #$00                ; 2  the blank value
    TXA                     ; 2  A = the visible line
    SEC                     ; 2
    SBC RocketY             ; 3  A = line - RocketY (unsigned)
    CMP #ROCKET_HEIGHT      ; 2  carry set when the row is outside 0..15
    BCS .skip               ; 3 taken above/below, 2 inside
    TAY                     ; 2  Y = the sprite row
    LDA RocketGfx,Y         ; 4  the row (page-aligned)
    TAY                     ; 2
.skip:
    STY GRP0                ; 3  0 on a skipped line, the row on a drawn one
}

; =============================================================================
; MOONBRANCHLESS — the branchless skipdraw for P1, 16 cycles
; =============================================================================
; X - MoonY is used directly as an 8-bit index.  Inside the moon's eight
; rows the difference is 0..7 and the table returns the graphic; above the
; moon the difference wraps to 249..255 and below it is 8..159, and every
; one of those 248 entries is zero.  No branch, no padding:
;
;   TXA 2 + SEC 2 + SBC 3 + TAY 2 + LDA 4 + STA 3 = 16 cycles, always.
!macro MoonBranchless {
    TXA                     ; 2  A = the visible line
    SEC                     ; 2
    SBC MoonY               ; 3  A = line - MoonY
    TAY                     ; 2
    LDA MoonRows,Y          ; 4  the moon's 8 rows, zero everywhere else
    STA GRP1                ; 3
}

; =============================================================================
; EXHAUSTBRANCHLESS — unchanged from the lesson: 18 cycles, no branch
; =============================================================================
!macro ExhaustBranchless {
    TXA
    SEC
    SBC ExhaustY
    CMP #EXHAUST_HEIGHT
    ROL
    ROL
    EOR #$02
    STA ENAM0
}

; =============================================================================
; ROM START
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA SWACNT

; --- the TIA's fixed state ---------------------------------------------------
    LDA #C_SKY
    STA COLUBK
    LDA #C_STAR
    STA COLUPF
    LDA #C_ROCKET
    STA COLUP0
    LDA #C_MOON
    STA COLUP1              ; the moon's colour
    LDA #$01
    STA CTRLPF
    LDA #$10
    STA NUSIZ0              ; M0 is 2 pixels wide
    LDA #$00
    STA NUSIZ1              ; P1 is one normal copy
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    STA ENAM0
    STA ENAM1
    STA ENABL

; --- position P0, M0 and P1 ONCE --------------------------------------------
    LDA #(ROCKET_X + POS_BIAS)
    JSR SetHorizPosP0
    LDA #(EXHAUST_X + POS_BIAS + 1)
    JSR SetHorizPosM0
    LDA #(MOON_X + POS_BIAS)
    JSR SetHorizPosP1
    STA HMOVE               ; apply HMP0, HMM0 and HMP1 together

; --- the first frame's state -------------------------------------------------
    LDA #$00
    STA Frame
    STA PrevSelect
    LDA #MOON_Y
    STA MoonY
    LDA #(8 + FLIGHT_START)
    STA RocketY
    CLC
    ADC #ROCKET_HEIGHT
    STA ExhaustY

; =============================================================================
; FRAME — 262 lines
; =============================================================================
StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    INC Frame

; --- SELECT restarts the demo (unchanged) ------------------------------------
    LDA SWCHB
    AND #$02
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA #$00
    STA Frame
    JMP SelectDone
SelectReleased:
    LDA #$00
    STA PrevSelect
SelectDone:

; --- the auto-demo table (unchanged) ----------------------------------------
    LDA Frame
    LSR
    LSR
    AND #(DEMO_LEN - 1)
    TAY
    LDA RocketTable,Y
    CLC
    ADC #FLIGHT_START
    STA RocketY
    CLC
    ADC #ROCKET_HEIGHT
    STA ExhaustY

; --- the bands' colours ------------------------------------------------------
    LDA #C_STAR
    STA COLUPF
    LDA #C_ROCKET
    STA COLUP0
    LDA #$00
    STA ENAM0               ; the star band does not run the missile code

    +wait_timer
    LDA #$00
    STA VBLANK
BodyStart:

; =============================================================================
; VISIBLE LINES 0-23: THE STAR BAND
; =============================================================================
    LDX #$00
    JMP StarBody
StarLoop:
    STA WSYNC
StarBody:
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    +RocketSkipdraw
    INX
    CPX #STAR_LINES
    BNE StarLoop

; --- flight boundary ---------------------------------------------------------
    LDA #$00
    STA COLUPF
    STA PF0
    STA PF1
    STA PF2
    JMP FlightLoop          ; skip the page-alignment fill (never execute it)

; =============================================================================
; VISIBLE LINES 24-167: THE FLIGHT REGION (rocket, exhaust, moon)
; =============================================================================
; Page-aligned so the rocket's BCS and the loop's BNE never cross
; a page: a taken branch that crosses a page costs one extra cycle and
; would break the 24/17 and 7-cycle ledgers above.
    !align 255, 0
FlightLoop:
    STA WSYNC
FlightStart:
    +RocketSkipdraw         ; 24/17: P0
    +ExhaustBranchless      ; 18: M0
    +MoonBranchless         ; 16: P1 (store completes at 58 before pixel 70.67)
    INX
    CPX #FLIGHT_END
    BNE FlightLoop

; =============================================================================
; VISIBLE LINES 168-191: THE GROUND BAND
; =============================================================================
GroundStart:
    STA WSYNC
GroundLine:
    LDA #C_HORIZON
    STA COLUPF
    LDA #$00
    STA ENAM0               ; the last flight line can end with the exhaust on
    LDA #$FF
    STA PF0
    STA PF1
    STA PF2
    LDY #(GROUND_LINES - 1)
GroundLoop:
    STA WSYNC
    LDA #C_GROUND
    STA COLUPF
    DEY
    BNE GroundLoop
    STA WSYNC

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SETHORIZPOSP0 / M0 / P1 — the Lesson 26 dance, one object each
; =============================================================================
    !align 31, 0
SetHorizPosP0:
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
    STA WSYNC
    RTS

    !align 31, 0
SetHorizPosM0:
    STA WSYNC
    SEC
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
    STA WSYNC
    RTS

    !align 31, 0
SetHorizPosP1:
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
    STA WSYNC
    RTS

; =============================================================================
; THE SPRITES — both tables page-aligned for the 4-cycle loads
; =============================================================================
    !align 255, 0
RocketGfx:
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %01111110
    !byte %11111111
    !byte %11111111
    !byte %11100111
    !byte %11111111
    !byte %11111111
    !byte %11111111
    !byte %11111111
    !byte %11111111
    !byte %11111111
    !byte %11100111
    !byte %11100111
    !byte %11000011

    !align 255, 0
MoonRows:
    !byte %00111100         ; row 0
    !byte %01111110         ; row 1
    !byte %11111111         ; row 2
    !byte %11111111         ; row 3
    !byte %11111111         ; row 4
    !byte %11111111         ; row 5
    !byte %01111110         ; row 6
    !byte %00111100         ; row 7
    !fill 248, $00          ; 8-255: the skipped lines land here

; =============================================================================
; THE AUTO-DEMO TABLE — the lesson's 64 entries
; =============================================================================
RocketTable:
    !byte  8,  8,  8,  8,  8,  8
    !byte 16, 30, 44, 58, 72, 86,100,114
    !fill 20, 120
    !byte 114,100, 86, 72, 58, 44, 30, 16
    !fill 22,  8

; =============================================================================
; THE STAR BAND — the lesson's tables
; =============================================================================
    !align 255, 0
StarPF0:
    !byte $80, $00, $20, $00, $00, $00, $40, $00, $10, $00, $00, $80
    !byte $00, $20, $00, $00, $00, $40, $00, $10, $00, $00, $80, $00

    !align 255, 0
StarPF1:
    !byte $04, $20, $00, $09, $80, $00, $10, $00, $02, $40, $00, $04
    !byte $20, $00, $08, $81, $00, $10, $00, $42, $00, $20, $04, $00

    !align 255, 0
StarPF2:
    !byte $00, $00, $04, $00, $00, $20, $00, $01, $08, $00, $02, $00
    !byte $10, $00, $04, $00, $20, $00, $09, $00, $40, $02, $00, $00

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
