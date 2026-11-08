; =============================================================================
; LESSON 74 — EXERCISE 2 SOLUTION: The Fully Branchless Player
; =============================================================================
; Part 11: Legendary Techniques
;
; The exercise: replace P0's skip branch with the fully branchless carry
; form — a full 8-bit mask/index for the player.
;
; The lesson's skipdraw still has one branch.  This solution removes even
; that.  The unsigned difference X - RocketY is used DIRECTLY as an 8-bit
; index into a 256-byte row table:
;
;       TXA
;       SEC
;       SBC RocketY
;       TAY
;       LDA RocketRows,Y
;       STA GRP0
;
;   - On the 16 sprite rows the difference is 0..15, so the table returns
;     RocketRows[0..15]: the rocket's graphic.
;   - On the lines before the sprite the subtraction wraps to 112..255;
;     on the lines after it the difference is 16..159.  Every one of those
;     240 entries is $00, so GRP0 is written blank.
;
; The table IS the mask: RocketRows = the 16 graphic bytes followed by 240
; zeros, page-aligned so LDA RocketRows,Y is always 4 cycles.  No branch,
; no cycle ledger with two paths: the block is 2+2+3+2+4+3 = 16 cycles on
; every line.  That is 9 cycles less than the lesson's padded skipdraw.
;
; The price is ROM: 256 bytes for one sprite instead of 16.  In a 4,096-
; byte cartridge with this little data that is affordable; games with
; many sprites usually keep the branch instead.  That trade — 9 cycles
; against 240 bytes — is the exercise's lesson.
;
; The exhaust (M0) keeps the lesson's branchless carry form, 18 cycles, so
; the flight line is 16 + 18 + 7 = 41 cycles of work and the WSYNC write
; completes at 44.  The frame stays 262.
;
; Checkpoints: StartFrame (259/3), VblankStart (0/5), BodyStart (37/5);
;   the first flight line is 61, the first ground line 205, the first
;   blanked line 229.
;
; The bands, colours, star table, ground and auto-demo are the lesson's.
; RAM: $80 Frame, $81 PrevSelect, $82 RocketY, $83 ExhaustY; $84-$F7
; free; the stack is $F8-$FF.
;
; Build: acme -f plain -o build/exercise-02.bin \
;        lessons/part11-legendary/74-skipdraw-kernel/exercise-02-solution.asm
; Run:   stella build/exercise-02.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36

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

POS_BIAS       = 3

DEMO_LEN       = 64

; --- colours -----------------------------------------------------------------
C_SKY          = $82
C_STAR         = $0E
C_ROCKET       = $1A
C_GROUND       = $26
C_HORIZON      = $2A

!if STAR_LINES + FLIGHT_LINES + GROUND_LINES != VISIBLE_LINES {
    !error "the three bands must total 192 visible lines"
}

; =============================================================================
; RAM ALLOCATION ($80-$83)
; =============================================================================
Frame        = $80
PrevSelect   = $81
RocketY      = $82
ExhaustY     = $83
;
; $84-$F7 are free; the stack is $F8-$FF.

; =============================================================================
; ROCKETBRANCHLESS — the player in 16 cycles, no branch at all
; =============================================================================
; The 8-bit difference indexes RocketRows directly.  The first 16 entries
; are the graphic; the remaining 240 are zero, so the wrapped difference
; above the sprite (112..255) and the difference below it (16..159) both
; land in the blank part.  There is no compare, no branch and no padding:
;
;   TXA 2 + SEC 2 + SBC 3 + TAY 2 + LDA 4 + STA 3 = 16 cycles, always.
;
; The store is unconditional in the strongest sense: every line executes
; the same seven instructions and writes GRP0 once.
!macro RocketBranchless {
    TXA                     ; 2  A = the visible line
    SEC                     ; 2
    SBC RocketY             ; 3  A = line - RocketY, used as an 8-bit index
    TAY                     ; 2
    LDA RocketRows,Y        ; 4  the graphic inside 0..15, zero everywhere else
    STA GRP0                ; 3
}

; =============================================================================
; EXHAUSTBRANCHLESS — the lesson's 18-cycle missile form
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
    LDA #$01
    STA CTRLPF
    LDA #$10
    STA NUSIZ0              ; M0 is 2 pixels wide
    LDA #$00
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    STA ENAM0
    STA ENAM1
    STA ENABL

; --- position P0 and M0 ONCE ------------------------------------------------
    LDA #(ROCKET_X + POS_BIAS)
    JSR SetHorizPosP0
    LDA #(EXHAUST_X + POS_BIAS + 1)
    JSR SetHorizPosM0
    STA HMOVE

; --- the first frame's state -------------------------------------------------
    LDA #$00
    STA Frame
    STA PrevSelect
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
; The branchless player runs here too: X is 0..23, well below RocketY, so
; the difference wraps into the zero part of RocketRows and GRP0 is blank.
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
    +RocketBranchless
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
; VISIBLE LINES 24-167: THE FLIGHT REGION
; =============================================================================
; Page-aligned so the loop's BNE never crosses a page: a taken branch that
; crosses a page costs one extra cycle and would make the loop 8, not 7.
;
; 16 (player) + 18 (exhaust) + 7 (loop) = 41 cycles of work per line;
; the WSYNC write completes at 44 of 76.
    !align 255, 0
FlightLoop:
    STA WSYNC
FlightStart:
    +RocketBranchless       ; 16 cycles, no branch
    +ExhaustBranchless      ; 18 cycles, no branch
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
; SETHORIZPOSP0 / M0 — the Lesson 26 dance
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

; =============================================================================
; ROCKETROWS — the 256-byte table that replaces the branch
; =============================================================================
; Entries 0-15 are the rocket's rows.  Entries 16-255 are zero.  The table
; is page-aligned so the indexed load never crosses a page: 4 cycles for
; every index.  The 240 zeros cost 240 bytes of ROM; that is the price of
; removing the branch.
    !align 255, 0
RocketRows:
    !byte %00011000         ; row 0
    !byte %00111100         ; row 1
    !byte %01111110         ; row 2
    !byte %01111110         ; row 3
    !byte %11111111         ; row 4
    !byte %11111111         ; row 5
    !byte %11100111         ; row 6
    !byte %11111111         ; row 7
    !byte %11111111         ; row 8
    !byte %11111111         ; row 9
    !byte %11111111         ; row 10
    !byte %11111111         ; row 11
    !byte %11111111         ; row 12
    !byte %11100111         ; row 13
    !byte %11100111         ; row 14
    !byte %11000011         ; row 15
    !fill 240, $00          ; 16-255: every skipped line lands here

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
