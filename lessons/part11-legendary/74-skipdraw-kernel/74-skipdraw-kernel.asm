; =============================================================================
; LESSON 74: Skipdraw — The Classic Sprite Kernel Idiom
; =============================================================================
; Part 11: Legendary Techniques
;
; What this program does:
;   "the elevator": a vertical rocket scene.  Player 0 is an 8x16 rocket;
;   missile 0 is its 2x8 exhaust, drawn directly under the rocket.  The
;   playfield gives the scene three bands: a 24-line star band at the top,
;   a 144-line flight region, and a 24-line ground band at the bottom.  A
;   64-entry auto-demo table raises and lowers the rocket so the screen is
;   alive without a controller; SELECT restarts the table.
;
;   The rocket is drawn by SKIPDRAW, the classic one-line sprite idiom:
;
;       LDY #0
;       TXA
;       SEC
;       SBC RocketY
;       CMP #ROCKET_HEIGHT
;       BCC .draw
;       <padding>
;       JMP .store
;   .draw:
;       TAY
;       LDA RocketGfx,Y
;       TAY
;   .store:
;       STY GRP0
;
;   X is the visible-line counter (0..191).  The subtraction is unsigned:
;   on the lines before the sprite it wraps to a value of 112 or more, and
;   on the lines after it the plain difference is 16 or more.  Only the 16
;   rows inside the sprite give a difference of 0..15, so only those rows
;   load a graphic byte.  The carry from CMP is the unsigned "before the
;   sprite" test.  The store is UNCONDITIONAL: on a skipped line Y is still
;   zero, so STY GRP0 writes 0 and the sprite disappears.  That is what
;   lets the idiom use one branch and one store.
;
;   The two paths are cycle-equal.  The draw path pays the taken branch
;   (+1) and the 8-cycle TAY/LDA/TAY; the skip path pays 6 cycles of NOP
;   padding and a 3-cycle JMP.  9 = 9, so both paths are 25 cycles.  The
;   ledger is in the comments at the macro.
;
;   The exhaust uses the BRANCHLESS carry form:
;
;       TXA
;       SEC
;       SBC ExhaustY
;       CMP #EXHAUST_HEIGHT
;       ROL
;       ROL
;       EOR #2
;       STA ENAM0
;
;   CMP leaves carry clear when the line is inside the 8 exhaust rows.
;   The first ROL moves that bit into bit 0, the second into bit 1, and
;   EOR #2 inverts it: bit 1 of A is now 1 exactly on the exhaust rows.
;   ENAM0's enable is bit 1, so the store both enables and disables the
;   missile with no branch at all.  18 cycles, always.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 content + 30 overscan = 262.
;   The 192 content lines are three bands:
;
;     visible   0-23    the star band      24 lines   PF stars, one row/line
;     visible  24-167   the flight region 144 lines   the rocket + exhaust
;     visible 168-191   the ground band    24 lines   a solid PF band
;                       ----------------
;                       24 + 144 + 24 = 192
;
;   Measured schedule (Stella breakpoints): the star bodies run on
;   absolute lines 37-60, the flight bodies on 61-204, the ground band on
;   205-228, the overscan on 229-258 and the VSYNC on 259-261.  The
;   picture is 37-228 (192 lines) and the frame gate is StartFrame 259/3,
;   VblankStart 0/5: 3 + 37 + 192 + 30 = 262.
;
;   Measurement convention: a checkpoint's line/cycle is the instruction's
;   start line and start cycle, with the line's cycle 0 being the first
;   instruction after the WSYNC release.  A breakpoint on the first
;   instruction after a STA WSYNC fires during the stall and reports the
;   WSYNC's own line/cycle; the instruction itself starts on the next line
;   at cycle 0.  The store cycles are start cycles: STY GRP0 starts at 22
;   (completes 25), STA ENAM0 at 40 (completes 43) and STA WSYNC at 50
;   (completes 53).
;
;   The star band writes a 24-entry playfield column (three bytes per line)
;   on every line, so the
;   stars are single scanlines (4 pixels wide; the playfield's chunk is 4
;   pixels).  The flight region and the ground band write the playfield
;   once at their band boundary and leave it static.  The flight line's
;   work is 25 + 18 + 7 = 50 cycles (the WSYNC write completes at 53);
;   the star line's is 21 + 25 + 7 = 53 (56 with the WSYNC), and the very
;   first star line adds the LDX/JMP prologue.  All are inside 76.
;
;   The rocket's vertical position is the table's value plus FLIGHT_START
;   (24), so RocketY is a screen line in 32..144 and the exhaust is
;   ExhaustY = RocketY + 16 in 48..160.  The rocket can never reach the
;   star band or the ground band: the table's range is 8..120, so the
;   sprite's rows are 32..159 and the exhaust's rows are 48..167.  The
;   exhaust's last row (167) meets the ground band's first row (168).
;
;   The screen X positions are set ONCE at reset: P0's left edge at
;   ROCKET_X = 76, and M0 at EXHAUST_X = 79 (the missile is 2 pixels wide
;   and sits under the rocket's centre).  Nothing in the kernel writes
;   RESP0 or RESM0, so the horizontal position cannot drift.
;
;   The missile enable is cleared twice on purpose.  The flight loop
;   recomputes ENAM0 on every line, but the star band and the ground band
;   do not run the missile code: they would inherit the last flight line's
;   value.  At the low hold the last flight line is X=167 and
;   ExhaustY=160, so the difference is 7 and the missile is ENABLED; left
;   alone it would streak through the ground band and the next frame's
;   star band.  ENAM0 is therefore cleared in VBLANK (before the star
;   band) and again at GroundLine (before the ground band).
;
;   GRP0 needs no such clear in the ground band.  The last flight line is
;   X=167 and RocketY never exceeds 144, so 167 - RocketY is at least 23:
;   the skipdraw always takes the skip path on the last flight line and
;   stores 0.  GRP0 is therefore already blank when the ground band
;   starts.  This invariant is tied to the table's 8..120 range; widening
;   the table so the rocket can reach line 152 or lower would put a real
;   row on the last flight line and require an explicit GRP0 clear at the
;   ground boundary.
;
; The auto-demo:
;   Frame counts every frame.  The table index is (Frame >> 2) & 63, so
;   the rocket steps once every 4 frames and the table repeats every 256
;   frames (about 4.3 seconds).  The table holds the rocket high on screen
;   (table 8, screen 32) for indices 0-5 and 42-63, and low (table 120,
;   screen 144) for indices 14-33.  The holds are wide: a 2-second capture
;   lands in the low hold and a 5-second capture in the high hold even
;   when Stella's window takes a second to open.
;
;   SELECT (SWCHB bit 1, active low) restarts the table by zeroing Frame.
;   PrevSelect makes the reset happen once per press.
;
; Checkpoints (the values are the state at the label):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5); the first
;   flight body is on line 61 (its first STY GRP0 fires at 61/22), the
;   first ground line is 205 and the first blanked line is 229;
;   DemoRead (A = the table value + 24, i.e. the new RocketY),
;   SelectReset (A = 0, the new Frame).  See the measurement-convention
;   note above for the WSYNC breakpoint artifact.
;
; RAM map (the exact map; +clean_start zeroes every byte):
;   $80 Frame         frame counter for the auto-demo
;   $81 PrevSelect    SELECT edge latch (0 = released, 1 = pressed)
;   $82 RocketY       the rocket's top screen line (32..144)
;   $83 ExhaustY      the exhaust's top screen line (RocketY + 16)
;   $84-$F7           free (116 bytes)
;   $F8-$FF           stack
;
; Build: acme -f plain -o build/lesson74.bin \
;        lessons/part11-legendary/74-skipdraw-kernel/74-skipdraw-kernel.asm
; Run:   stella build/lesson74.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan

VISIBLE_LINES  = 192     ; the picture
STAR_LINES     = 24      ; visible 0-23
FLIGHT_LINES   = 144     ; visible 24-167
GROUND_LINES   = 24      ; visible 168-191
FLIGHT_START   = STAR_LINES                  ; 24: the flight region's first line
FLIGHT_END     = STAR_LINES + FLIGHT_LINES   ; 168: the ground band's first line

ROCKET_HEIGHT  = 16      ; the player sprite is 8 x 16
EXHAUST_HEIGHT = 8       ; the missile is 2 x 8
ROCKET_X       = 76      ; the rocket's left edge (fixed)
EXHAUST_X      = 79      ; the exhaust's left edge (the rocket's centre)

POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

DEMO_LEN       = 64      ; 64 entries = a 256-frame loop

; --- colours -----------------------------------------------------------------
C_SKY          = $82     ; the night sky: dark blue
C_STAR         = $0E     ; the playfield stars: white
C_ROCKET       = $1A     ; the rocket and its exhaust: gold
C_GROUND       = $26     ; the ground: brown
C_HORIZON      = $2A     ; the ground's top line: a lighter brown

; The band arithmetic is a build-time assertion, not a comment: the three
; bands must fill the 192-line picture exactly.
!if STAR_LINES + FLIGHT_LINES + GROUND_LINES != VISIBLE_LINES {
    !error "the three bands must total 192 visible lines"
}

; =============================================================================
; RAM ALLOCATION ($80-$83; +clean_start zeroes every byte)
; =============================================================================
Frame        = $80   ; the auto-demo's frame counter
PrevSelect   = $81   ; SELECT edge latch: 0 = released, 1 = pressed
RocketY      = $82   ; the rocket's top screen line, 0..191
ExhaustY     = $83   ; the exhaust's top screen line, RocketY + 16
;
; $84-$F7 are free (116 bytes).  The stack lives at $F8-$FF; the call depth
; stays at one level (the two positioners at reset only).

; =============================================================================
; ROCKETSKIPDRAW — one line of the rocket, 25 cycles on both paths
; =============================================================================
; X is the visible line (0..191).  The subtraction X - RocketY is unsigned:
;
;   X <  RocketY        wraps to 112..255   -> CMP #16 sets carry -> skip
;   RocketY <= X < +16  gives   0..15       -> carry clear         -> draw
;   X >= RocketY + 16   gives  16..159      -> carry set           -> skip
;
; The wrap is the "before the sprite" test: a negative difference becomes a
; large unsigned one, so one CMP covers both edges of the sprite.  The two
; bounds cannot alias an in-range row because RocketY never exceeds 144
; and 256 - 144 = 112 is far above 15.
;
; The store is unconditional.  On a skipped line Y is still 0 (set at the
; top), so STY GRP0 writes a blank line.  On a drawn line Y is the row.
;
; Cycle ledger (both paths total 25):
;   shared:    LDY #0      2
;              TXA         2
;              SEC         2
;              SBC RocketY 3   (zero page)
;              CMP #16     2
;   draw:      BCC .draw   3   (taken)      skip: BCC .draw   2  (not taken)
;              TAY         2                    NOP            2
;              LDA Gfx,Y   4   (page-aligned)  NOP            2
;              TAY         2                    NOP            2
;              -                             JMP .store      3
;              -                                (9 cycles)      (9 cycles)
;   both:      STY GRP0     3
;              ------------------------------
;              11 (through CMP) + 2 (branch base) + 9 (extra) + 3 = 25
;
; The ledger counts from cycle 0, the first instruction after the WSYNC
; release.  STY GRP0 starts at cycle 22 and completes at 25 (measured with
; a Stella breakpoint at the store: 61/22 on the first flight line (a skip
; line; the first drawn row fires at 69/22).  The
; rocket's left edge is X=76, drawn at cycle 22.67 + 76/3 = 48.0, so the
; store has 23 cycles of margin.
!macro RocketSkipdraw {
    LDY #$00                ; 2  Y = 0 is the "not on this line" value
    TXA                     ; 2  A = the visible line
    SEC                     ; 2
    SBC RocketY             ; 3  A = line - RocketY (unsigned)
    CMP #ROCKET_HEIGHT      ; 2  carry set when the row is outside 0..15
    BCC .draw               ; 3 taken inside the sprite, 2 outside
    NOP                     ; 2  \
    NOP                     ; 2   | 6 cycles of padding plus the JMP:
    NOP                     ; 2   | 9 cycles, equal to the draw path's
    JMP .store              ; 3  /  taken branch (+1) plus TAY/LDA/TAY (8)
.draw:
    TAY                     ; 2  Y = the sprite row 0..15
    LDA RocketGfx,Y         ; 4  the row's 8 pixels (RocketGfx is aligned)
    TAY                     ; 2  move the shape into Y for the store
.store:
    STY GRP0                ; 3  unconditional: 0 above and below, the row inside
}

; =============================================================================
; EXHAUSTBRANCHLESS — one line of the missile, 18 cycles, no branch
; =============================================================================
; CMP #8 leaves carry clear when the unsigned difference is 0..7, i.e. on
; the exhaust's eight rows.  Two ROLs move that carry into bit 1; EOR #2
; inverts it, so bit 1 is 1 exactly on the exhaust rows.  ENAM0's enable
; is bit 1, so one store sets the whole missile state for the line.  The
; other bits of A are rotated leftovers; the TIA ignores everything but
; bit 1 in ENAM0.
;
;   TXA 2 + SEC 2 + SBC 3 + CMP 2 + ROL 2 + ROL 2 + EOR 2 + STA 3 = 18
;
; The block is 18 cycles from its own start.  In the flight line it runs
; after the 25-cycle rocket block, so STA ENAM0 starts at cycle 40 and
; completes at 43 (measured at 61/40); the exhaust at X=79 is drawn at
; cycle 22.67 + 79/3 = 49.0, leaving 6 cycles of margin.  Run first, the
; same block would complete at cycle 18 and have 31 cycles of margin.
!macro ExhaustBranchless {
    TXA                     ; 2  A = the visible line
    SEC                     ; 2
    SBC ExhaustY            ; 3  A = line - ExhaustY (unsigned)
    CMP #EXHAUST_HEIGHT     ; 2  carry clear on the eight exhaust rows
    ROL                     ; 2  carry -> bit 0
    ROL                     ; 2  bit 0 -> bit 1 (1 = outside)
    EOR #$02                ; 2  invert bit 1 (1 = inside)
    STA ENAM0               ; 3  bit 1 enables missile 0
}

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
    STA SWACNT              ; port A is an input port

; --- the TIA's fixed state ---------------------------------------------------
    LDA #C_SKY
    STA COLUBK              ; dark blue sky for every band
    LDA #C_STAR
    STA COLUPF              ; the star band's playfield colour
    LDA #C_ROCKET
    STA COLUP0              ; the rocket and (later) the exhaust
    LDA #$01
    STA CTRLPF              ; reflect the playfield; 1-pixel ball
    LDA #$10
    STA NUSIZ0              ; missile 0 is 2 pixels wide; P0 one normal copy
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
; Each routine is the Lesson 26 divide-by-15 dance: 5 cycles per iteration
; = 15 color clocks, the remainder becomes the fine motion, and the coarse
; stroke lands on the beam.  Both routines end with a WSYNC, then the single
; HMOVE applies both fine values.  Nothing after this touches RESP0, RESM0
; or the motion registers, so the X positions stay put for every frame.
    LDA #(ROCKET_X + POS_BIAS)
    JSR SetHorizPosP0
    LDA #(EXHAUST_X + POS_BIAS + 1)
    JSR SetHorizPosM0
    STA HMOVE               ; apply HMP0 and HMM0 together (A is ignored)

; --- the first frame's state -------------------------------------------------
    LDA #$00
    STA Frame
    STA PrevSelect
    LDA #(8 + FLIGHT_START) ; the table's first value: high on screen
    STA RocketY
    CLC
    ADC #ROCKET_HEIGHT
    STA ExhaustY

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    INC Frame

; -----------------------------------------------------------------------------
; 1. SELECT — a new press restarts the auto-demo table
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is pressed.  PrevSelect makes the reset
; happen on the falling edge, once per press.
    LDA SWCHB
    AND #$02
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA #$00
SelectReset:                ; checkpoint: A = 0, the new Frame
    STA Frame
    JMP SelectDone
SelectReleased:
    LDA #$00
    STA PrevSelect
SelectDone:

; -----------------------------------------------------------------------------
; 2. THE AUTO-DEMO — one 64-entry table step every 4 frames
; -----------------------------------------------------------------------------
; The index is (Frame >> 2) & 63.  The table's value is relative to the
; flight region, so FLIGHT_START (24) turns it into a screen line.
    LDA Frame
    LSR                     ; Frame >> 1
    LSR                     ; Frame >> 2: one step every 4 frames
    AND #(DEMO_LEN - 1)     ; wrap the 64-entry table
    TAY
    LDA RocketTable,Y
    CLC
    ADC #FLIGHT_START
DemoRead:                   ; checkpoint: A = the table value + 24 = RocketY
    STA RocketY
    CLC
    ADC #ROCKET_HEIGHT
    STA ExhaustY

; -----------------------------------------------------------------------------
; 3. THE BAND COLOURS — the star band is white on the dark sky
; -----------------------------------------------------------------------------
    LDA #C_STAR
    STA COLUPF
    LDA #C_ROCKET
    STA COLUP0
    LDA #$00
    STA ENAM0               ; the star band does not run the missile code

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
BodyStart:                  ; checkpoint: scanline 37/5, visible line 0

; =============================================================================
; VISIBLE LINES 0-23: THE STAR BAND (one playfield row per line)
; =============================================================================
; X is both the line counter and the star table index: the band is exactly
; 24 lines, so StarPFx,X reads row X.  The rocket cannot reach this band
; (its first row is 32), but the skipdraw still runs here and stores 0 on
; every line: GRP0 stays blank because X - RocketY wraps to a large value.
;
; The loop is rotated so its first body runs on the first visible line.
; Line 37 is drawn immediately after VBLANK (the label is at 37/5 and the
; body starts at cycle 10); every later line starts at a WSYNC.
; Store completions: on the first line PF0/PF1/PF2 complete at 17/24/31
; (the body starts at cycle 10); on every later line they complete at
; 7/14/21 (the body starts at cycle 0).  All are inside the chunk
; deadlines 22.67/28.0/38.67.
    LDX #$00
    JMP StarBody
StarLoop:
    STA WSYNC               ; line X, X = 1..23
StarBody:
    LDA StarPF0,X           ; 4  chunks 0-3  (page-aligned: no page cross)
    STA PF0                 ; 3  PF0 deadline: cycle 22.67 (pixel 0)
    LDA StarPF1,X           ; 4  chunks 4-11
    STA PF1                 ; 3  PF1 deadline: cycle 28.0 (pixel 16)
    LDA StarPF2,X           ; 4  chunks 12-19
    STA PF2                 ; 3  PF2 deadline: cycle 38.67 (pixel 48)
    +RocketSkipdraw         ; 25 GRP0 = 0 on every star line
    INX                     ; 2
    CPX #STAR_LINES         ; 2
    BNE StarLoop            ; 3 taken

; -----------------------------------------------------------------------------
; The flight boundary runs at the end of line 23.  Star row 23 is empty on
; purpose: the PF clear lands after the line's visible part, where an empty
; row hides it.  COLUPF becomes black (the flight region has no playfield).
; -----------------------------------------------------------------------------
    LDA #$00
    STA COLUPF
    STA PF0
    STA PF1
    STA PF2
    JMP FlightLoop          ; skip the page-alignment fill (never execute it)

; =============================================================================
; VISIBLE LINES 24-167: THE FLIGHT REGION (the rocket and the exhaust)
; =============================================================================
; The loop is page-aligned so the ledgers below are true on hardware.  A
; taken branch that crosses a page boundary costs one extra cycle: if the
; rocket block's BCC or the loop's BNE straddled $F0xx -> $F1xx, the draw
; path would be 26 and the loop 8, and the 25/25 equality would be false.
; With FlightLoop on a page boundary, the BCC at +10, its .draw target at
; +18 and the BNE target at +0 are all in the same page.
;
; A flight line is 25 (rocket) + 18 (exhaust) + 7 (loop) = 50 cycles; the
; WSYNC write completes at 53, inside the 76-cycle line.  Nothing is
; written to the playfield here, so the band stays a clean sky.
    !align 255, 0
FlightLoop:
    STA WSYNC               ; line X
FlightStart:                ; checkpoint: the first flight body is on line 61
    +RocketSkipdraw         ; 25 cycles: GRP0 = the row or 0
    +ExhaustBranchless      ; 18 cycles: ENAM0 = 2 on the 8 exhaust rows
    INX                     ; 2
    CPX #FLIGHT_END         ; 2
    BNE FlightLoop          ; 3 taken (same page: no branch page cross)

; =============================================================================
; VISIBLE LINES 168-191: THE GROUND BAND (a static playfield band)
; =============================================================================
; GroundStart is the band's first line.  The PF stores complete at cycles
; 15/18/21 (PF0/PF1/PF2), all inside the chunk deadlines 22.67/28.0/38.67,
; so the band is full width from its first pixel.  The first line uses the
; lighter horizon colour; the loop rewrites COLUPF with the ground colour
; on the following lines.  The ENAM0 clear is here and in VBLANK: the last
; flight line can end with the exhaust enabled, and the ground and star
; bands do not run the missile code.
GroundStart:                ; checkpoint: the first ground line is 205
    STA WSYNC               ; line 205
GroundLine:                 ; checkpoint: the ground setup line (205)
    LDA #C_HORIZON
    STA COLUPF              ; the horizon line's colour (completes at cycle 5)
    LDA #$00
    STA ENAM0               ; the last flight line can end with the exhaust on
    LDA #$FF
    STA PF0                 ; chunks 0-3   (completes at cycle 15)
    STA PF1                 ; chunks 4-11  (completes at cycle 18)
    STA PF2                 ; chunks 12-19 (completes at cycle 21)
    LDY #(GROUND_LINES - 1) ; 23 more ground lines: 169-191
GroundLoop:
    STA WSYNC               ; line 169 ... 191
    LDA #C_GROUND
    STA COLUPF              ; the ground colour from the second line down
    DEY                     ; 2
    BNE GroundLoop          ; 3 taken
    STA WSYNC               ; finish line 191

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: the first blanked line is 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SETHORIZPOSP0 / SETHORIZPOSM0 — the Lesson 26 dance, one object each
; =============================================================================
; A = the desired left edge + the output-delay bias.  Each routine starts a
; fresh line, divides by 15 (5 cycles = 15 color clocks per iteration), stores
; the remainder as the signed fine value, and strokes the coarse reset.  The
; caller's single HMOVE applies both fine values.
    !align 31, 0
SetHorizPosP0:
    STA WSYNC
    SEC
DivP0:
    SBC #15
    BCS DivP0
    EOR #7                  ; the negative remainder -> the signed fine value
    ASL                     ; bits 0-3 -> HMP0's high nibble
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0               ; the coarse strobe
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
; THE ROCKET — 16 rows, eight pixels wide, page-aligned
; =============================================================================
; The skipdraw loads a row with LDA RocketGfx,Y.  The table is page-aligned
; so the load is always 4 cycles and never pays the page-cross penalty: the
; cycle ledger depends on it.
    !align 255, 0
RocketGfx:
    !byte %00011000         ; 0   ..##....
    !byte %00111100         ; 1   .####...
    !byte %01111110         ; 2   .######.
    !byte %01111110         ; 3   .######.
    !byte %11111111         ; 4   ########
    !byte %11111111         ; 5   ########
    !byte %11100111         ; 6   ###..###  the porthole
    !byte %11111111         ; 7   ########
    !byte %11111111         ; 8   ########
    !byte %11111111         ; 9   ########
    !byte %11111111         ; 10  ########
    !byte %11111111         ; 11  ########
    !byte %11111111         ; 12  ########
    !byte %11100111         ; 13  ###..###  the fins
    !byte %11100111         ; 14  ###..###
    !byte %11000011         ; 15  ##....##

; =============================================================================
; THE AUTO-DEMO TABLE — 64 entries, relative to the flight region
; =============================================================================
; Screen line = value + 24.  The rocket is high on screen (8 -> 32) for
; indices 0-5 and 42-63, and low (120 -> 144) for 14-33.  The holds are
; wide on purpose: a capture's frame number depends on how long Stella
; takes to open its window, so the 2-second capture lands somewhere in
; 16-23 (the low hold) and the 5-second capture in 60-63 or 0-3 (the high
; hold).  Indices 6-13 descend and 34-41 rise: about 14 pixels every 4
; frames.
RocketTable:
    !byte  8,  8,  8,  8,  8,  8                   ;  0-5   high hold
    !byte 16, 30, 44, 58, 72, 86,100,114           ;  6-13  descend
    !fill 20, 120                                  ; 14-33  low hold
    !byte 114,100, 86, 72, 58, 44, 30, 16          ; 34-41  rise
    !fill 22,  8                                   ; 42-63  high hold

; =============================================================================
; THE STAR BAND — one playfield row per visible line
; =============================================================================
; Chunk-to-register: chunks 0-3 are PF0 bits 4-7, chunks 4-11 are PF1
; bits 7-0, chunks 12-19 are PF2 bits 0-7.  CTRLPF reflects the playfield,
; so each 4-pixel chunk appears twice, mirrored about the centre.  Row 23
; is empty: it hides the flight-boundary PF clear (see the kernel).
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
