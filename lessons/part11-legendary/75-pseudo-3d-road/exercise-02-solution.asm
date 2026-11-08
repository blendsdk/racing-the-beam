; =============================================================================
; LESSON 75, EXERCISE 2 SOLUTION: three demo phases
; =============================================================================
; Part 11: Legendary Techniques
;
; This is the Exercise 2 solution.  The demo cycles through THREE phases:
;
;     phase 0  straight    150 frames (2.5 s)  CurveMask = $00
;     phase 1  curve right 120 frames (2.0 s)  CurveMask = $FF, CurveBase = 0
;     phase 2  curve left  120 frames (2.0 s)  CurveMask = $FF, CurveBase = 32
;
;   The cycle is 390 frames (6.5 s).  Phase 0 is longer than the other two so
;   that a two-second capture is comfortably inside the straight phase
;   instead of on a boundary; a five-second capture lands 30 frames into
;   phase 2.  Phase 1 uses the curve table as written and phase 2 the same
;   wave negated, so the road's centre moves the other way.  (The wave is an
;   S, so one frame shows both bends; what the phase changes is which half of
;   the table each row reads.)
;
;   The curve table is twice as long: entries 0-31 hold the wave and entries
;   32-63 the same values negated.  Selecting a phase is one addition after
;   the 32-entry wrap: SBC Scroll / AND #31 / CLC / ADC CurveBase / TAY.
;
;   SELECT advances to the next phase by calling the same NextPhase routine
;   the timer uses, so the phase counter, the wrap, CurveMask, CurveBase and
;   both rebuild flags are always set together.
;
;   Build: acme -f plain -o build/exercise-02.bin \
;          lessons/part11-legendary/75-pseudo-3d-road/exercise-02-solution.asm
;
;   The picture is 192 scanlines in three bands:
;
;     visible   0-79    the sky        40 rows x 2 lines   blue + a gold sun
;     visible  80       the horizon    one gold line, full width
;     visible  81       the verge      one green line below it
;     visible  82-191   the road       22 rows x 5 lines   grey road, green grass
;                       -------------------
;                       80 + 1 + 1 + 110 = 192
;
;   The road is the PLAYFIELD.  Its left edge and its right edge are looked
;   up in two 20-entry mask tables, one for the left half of the screen and
;   one for the right half.  The playfield registers are written TWICE on
;   every road scanline: first with THIS line's left-half bytes, while the
;   beam is still in horizontal blank, then with THIS line's right-half
;   bytes, after the left half has been drawn and before the beam reaches
;   the right half.  That is the Lesson 21 asymmetric-playfield technique,
;   and it is what lets the road sit off-centre when it curves.
;
;   The write does NOT survive to the next scanline.  The TIA reads the
;   playfield registers again on every line, so the left and right pair has
;   to be re-established 76 cycles at a time.  That single fact sets the
;   budget and the instruction order.
;
;   Per road row:
;     Half[r]   the road's half-width in playfield chunks (1..10)
;     Curve     a signed per-row offset from a 32-entry table (-6..+6),
;               masked to 0 in the straight demo phase
;     c         Curve clamped to +/- (Half - 1) so the road always crosses
;               the chunk 19/20 boundary (the two mask tables need it)
;     L         the left edge chunk  = 20 - Half + c     (1..19)
;     Ridx      the right edge index =      Half + c     (1..19)
;               the right edge chunk is Ridx + 20        (21..39)
;     g         the road's centre chunk = (L + Ridx + 20) / 2 = 20 + c
;
;   The road therefore spans chunks L..(Ridx+20), which is 4L..4(Ridx+20)+3
;   in pixels.  The chunk at g is blanked on the "dash" rows to make the
;   dashed centre line; the green background shows through.  Because g
;   follows c, the line follows the road: 20 + c is chunk 14 at one end of
;   the curve and chunk 26 at the other.
;
;   Each playfield chunk is 4 pixels.  The road is 3 chunks wide at the
;   horizon and 21 at the bottom of the screen.
;
; WHERE THE PLAYFIELD IS LATCHED, AND WHY THAT SETS THE INSTRUCTION ORDER
;   The TIA does not latch the whole playfield at one instant.  Each
;   register is read as the beam arrives at its chunks, so a write only
;   affects the chunks the beam has not reached yet.  The visible area
;   starts 68 color clocks -- 22.67 CPU cycles -- after the WSYNC release,
;   so pixel x is drawn at cycle 22.67 + x/3:
;
;     left  PF0  pixels   0- 15   cycles 22.67 - 27.67
;     left  PF1  pixels  16- 47   cycles 28.00 - 38.33
;     left  PF2  pixels  48- 79   cycles 38.67 - 49.00
;     right PF0  pixels  80- 95   cycles 49.33 - 54.33
;     right PF1  pixels  96-127   cycles 54.67 - 65.00
;     right PF2  pixels 128-159   cycles 65.33 - 75.67
;
;   To change the RIGHT half of a line, a register must be rewritten after
;   its LEFT chunks have been drawn and before its RIGHT chunks arrive:
;
;     right PF0   after 27.67 and before 49.33   -> write at 36
;     right PF1   after 38.33 and before 54.67   -> write at 43
;     right PF2   after 49.00 and before 65.33   -> write at 54
;
;   and the LEFT half of the same line must be in the registers before the
;   visible area starts drawing it:
;
;     left PF0    before 22.67                   -> write at 11
;     left PF1    before 28.00                   -> write at 18
;     left PF2    before 38.67                   -> write at 25
;
;   Both groups therefore live on the same scanline, left group first:
;
;     0  LDY LTable,X      4      25  LDY RidxTable,X   4
;     4  LDA LeftPF0,Y     4      29  LDA SzR0,X        4
;     8  STA PF0           3  11  33  STA PF0           3  36
;    11  LDA LeftPF1,Y     4      36  LDA RightPF1,Y     4
;    15  STA PF1           3  18  40  STA PF1           3  43
;    18  LDA SzL2,X        4      43  LDA RightPF2,Y     4
;    22  STA PF2           3  25  47  NOP               2
;                                49  NOP               2
;                                51  STA PF2           3  54
;                                 54 cycles
;
;   SzL2 and SzR0 are the two playfield bytes the centre-line gap can fall
;   in, already masked, built in the vertical blank.  The left PF0 and PF1
;   bytes and the right PF1 and PF2 bytes never take the gap, so they are
;   plain table lookups.
;
;   THE 22.67-CYCLE OFFSET IS EASY TO LOSE.  Dividing a pixel number by
;   three gives the cycle measured from the start of the VISIBLE area, not
;   from the WSYNC release; a schedule built on those numbers writes
;   everything one horizontal blank too early and the halves come out
;   swapped.  The offset was measured, not assumed.  A probe ROM writes
;   PF1 = $FF at cycle 5 and PF1 = $00 at cycle 32 and shows white on the
;   left half only from x 16 to x 31.  The changeover is between the last
;   chunk drawn before the write and the first chunk drawn after it, which
;   is the statement the schedule needs; the arithmetic that predicts it
;   is only good to a cycle or two because the write lands in the middle of
;   a four-pixel chunk.
;
; THE KERNEL BUDGET
;   A drawing line is 54 cycles plus the WSYNC, so 19 cycles are spare.
;   Everything else per row is precomputed: the vertical blank rebuilds
;   LTable and RidxTable (about 81-85 cycles a row, 1870 for 22 rows) when
;   the scroll or the curve changes, and SzL2/SzR0 (113 cycles a row, 2486
;   for 22 rows) when the curve changes or the dash steps.  The two passes
;   never run on the same frame: the mask pass waits for a frame where the
;   edges were not rebuilt, so it can lag by up to two frames, and a frame
;   carries at most 2486 cycles of work plus the demo's ~180, well inside the
;   2812-cycle blank.
;
;   Why a road row is five scanlines: it is a deliberate choice, not a
;   hardware limit.  A row could be two lines (the kernel is 54 of 76
;   cycles on every line), but 22 rows x 5 = 110 lines is what makes the
;   band split land on exactly 192 with an 80-line sky, and five lines per
;   width step keeps the road's edge from stepping too fast.  That is the
;   one accepted deviation from a two-line row, and the price is paid in
;   vertical resolution, not in the kernel.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262.
;   Measured schedule (Stella breakpoints): the sky bodies run on absolute
;   lines 37-116, the horizon line on 117, the verge on 118, the road rows
;   on 119-228 (22 rows x 5), the overscan on 229-258 and the VSYNC on
;   259-261.
;
;   Measurement convention: a checkpoint's line/cycle is the instruction's
;   start line and start cycle, with the line's cycle 0 being the first
;   instruction after the WSYNC release.  A breakpoint on the first
;   instruction after a STA WSYNC fires during the stall and reports the
;   WSYNC's own line/cycle; the instruction itself starts on the next line
;   at cycle 0.
;
; The demo (no controller needed):
;   PhaseTimer counts 150 frames in phase 0 and 120 in each curve phase, so
;   the cycle is 390 frames (6.5 s).  Scroll advances once every 8 frames and Dash
;   once every 2.  Both count DOWN against the row index, so as they rise
;   the pattern they index moves toward the viewer: a dash or a bend
;   appears at row (index + phase) and slides down the screen.
;
;   The dashed line is suppressed on the narrow rows (Half < 4, rows 0-7).
;   A four-pixel gap is a third of the twelve-pixel road at row 0, which
;   reads as a pothole; from row 8 down the road is at least 36 pixels wide
;   and the same gap reads as a centre mark.  With a four-row dash period
;   and only 22 rows, a single frame shows three or four dashes (three in
;   the captured images).
;
; Checkpoints (the values are the state at the label; addresses are in the
; symbol file, which is the authority):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   SkyEnd (116/9, the WSYNC that ends the sky), RoadBody (119, the first
;   road row's first line), OverscanStart (228/64; the first blanked line
;   is 229), EdgeDone (the edge rebuild's last instruction), MaskDone (the
;   mask rebuild's last instruction), BuildOne (A = a row's clamped curve).
;
; RAM map (the exact map; +clean_start zeroes every byte):
;   $80 PhaseTimer   frames elapsed in the current demo phase
;   $81 CurveMask    $00 straight, $FF curved
;   $82 Scroll       the curve table's phase (0..31)
;   $83 ScrollTimer  frames to the next Scroll step
;   $84 Dash         the centre-line phase (0..7)
;   $85 DashTimer    frames to the next Dash step
;   $86 PrevSelect   the SELECT edge latch
;   $87 MaxOff       the curve clamp, and the rebuild's scratch byte
;   $88 GapIx        the mask rebuild's table index for the current row
;   $89 MaskDirty    1 = rebuild SzL2/SzR0 in this vertical blank
;   $8A CurveDirty   1 = rebuild LTable and RidxTable in this vertical blank
;   $8B-$A0 LTable   the road's left edge chunk for each row (22 bytes)
;   $A1-$B6 RidxTable the road's right edge index for each row (22 bytes)
;   $B7-$CC SzL2     the left PF2 byte per row, centre gap applied (22)
;   $CD-$E2 SzR0     the right PF0 byte per row, centre gap applied (22)
;   $E3 CurveBase    0 for the wave, 32 for the negated copy
;   $E4 Phase        the demo phase: 0 straight, 1 right, 2 left
;   $E5-$F7          free (19 bytes)
;   $F8-$FF          the stack
;
; Build: acme -f plain -o build/lesson75.bin \
;        lessons/part11-legendary/75-pseudo-3d-road/75-pseudo-3d-road.asm
; Run:   stella build/lesson75.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK (Lesson 15)
OVERSCAN_TIMER = 36      ; 30-line overscan (Lesson 15)

VISIBLE_LINES  = 192

SKY_ROWS       = 40      ; visible rows 0-39, two scanlines each
HORIZON_LINES  = 2       ; one gold horizon line and one green verge line
ROAD_ROWS      = 22      ; the road's rows, five scanlines each
ROAD_LINES     = 110     ; 22 x 5

BALL_X         = 116     ; the sun's left edge (TIA x)
POS_BIAS       = 3       ; the Lesson 26 output-delay bias

PHASE_LEN      = 120     ; frames in phases 1 and 2 (2 s at 60 Hz)
PHASE_LEN_0    = 150     ; frames in phase 0 (2.5 s): keeps the 2 s capture
                         ; well inside the straight phase
SCROLL_STEP    = 8       ; frames per curve-table step
DASH_STEP      = 2       ; frames per dash-row step
DASH_MIN_HALF  = 4       ; no centre line until the road is 9 chunks wide

; --- colours -----------------------------------------------------------------
C_SKY          = $9A     ; daylight blue
C_GOLD         = $1A     ; the sun and the horizon band
C_GRASS        = $C6     ; the grass verges
C_ROAD         = $0A     ; the road surface: grey

; The band arithmetic is a build-time assertion, not a comment.
!if SKY_ROWS * 2 + HORIZON_LINES + ROAD_ROWS * 5 != VISIBLE_LINES {
    !error "the sky, horizon and road bands must total 192 visible lines"
}

; =============================================================================
; RAM ALLOCATION ($80-$F7; +clean_start zeroes every byte)
; =============================================================================
PhaseTimer   = $80   ; frames elapsed in the current demo phase
CurveMask    = $81   ; $00 = straight, $FF = curved
Scroll       = $82   ; the curve table's phase, 0..31
ScrollTimer  = $83   ; frames to the next Scroll step
Dash         = $84   ; the centre-line phase, 0..7
DashTimer    = $85   ; frames to the next Dash step
PrevSelect   = $86   ; the SELECT edge latch
MaxOff       = $87   ; the curve clamp, and the rebuild's scratch byte
GapIx        = $88   ; the mask rebuild's table index for the current row
MaskDirty    = $89   ; 1 = rebuild SzL2 and SzR0
CurveDirty   = $8A   ; 1 = rebuild LTable and RidxTable
LTable       = $8B   ; 22 bytes: $8B-$A0, the left edge chunk per row
RidxTable    = $A1   ; 22 bytes: $A1-$B6, the right edge index per row
SzL2         = $B7   ; 22 bytes: $B7-$CC, left PF2, gap applied
SzR0         = $CD   ; 22 bytes: $CD-$E2, right PF0, gap applied
CurveBase    = $E3   ; 0 for the wave, 32 for the negated copy
Phase        = $E4   ; the demo phase: 0 straight, 1 right, 2 left
;
; The stack lives at $F8-$FF; the call depth stays at one level (the ball
; positioner at reset only).  Used: 99 bytes of variables and tables
; ($80-$E2); 21 bytes ($E3-$F7) are free.

; =============================================================================
; DRAWROADROW — one road scanline, 54 cycles
; =============================================================================
; The left group is in the registers before the visible area starts; the
; right group lands after the left half's chunks for each register have
; gone by and before the right half's arrive.  SzL2 and SzR0 already have
; the centre-line gap applied; the two registers that never carry the gap
; (left PF0/PF1's first chunks, and all of right PF1/PF2) are plain table
; lookups.  54 cycles.
!macro DrawRoadRow {
    LDY LTable,X            ; 4   0- 4  the left edge chunk for this row
    LDA LeftPF0,Y           ; 4   4- 8  chunks L..3   (never takes the gap)
    STA PF0                 ; 3   8-11  write 11  (before 22.67)
    LDA LeftPF1,Y           ; 4  11-15  chunks 4..11  (never takes the gap)
    STA PF1                 ; 3  15-18  write 18  (before 28.00)
    LDA SzL2,X              ; 4  18-22  chunks 12..19, gap applied
    STA PF2                 ; 3  22-25  write 25  (before 38.67)
    LDY RidxTable,X         ; 4  25-29  the right edge index for this row
    LDA SzR0,X              ; 4  29-33  chunks 20..23, gap applied
    STA PF0                 ; 3  33-36  write 36  (after 27.67, before 49.33)
    LDA RightPF1,Y          ; 4  36-40  chunks 24..31 (gap saturates in PF0)
    STA PF1                 ; 3  40-43  write 43  (after 38.33, before 54.67)
    LDA RightPF2,Y          ; 4  43-47  chunks 32..39 (never takes the gap)
    NOP                     ; 2  47-49
    NOP                     ; 2  49-51
    STA PF2                 ; 3  51-54  write 54  (after 49.00, before 65.33)
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
    STA NUSIZ0
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2

    LDA #$30
    STA CTRLPF              ; an 8-pixel ball; REPEAT playfield; no priority
                            ; bit 0 = 0 is essential: repeat mode puts the
                            ; right half in the same PF0/PF1/PF2 order as the
                            ; left half, which is what the mask tables assume

; --- the sun: the ball, positioned once ---------------------------------------
    LDA #(BALL_X + POS_BIAS)
    JSR SetHorizPosBL
    STA HMOVE               ; apply HMBL inside HBLANK

; --- the first frame's state -------------------------------------------------
    LDA #$00
    STA PhaseTimer
    STA Scroll
    STA ScrollTimer
    STA Dash
    STA DashTimer
    STA PrevSelect
    STA CurveMask           ; start in the straight phase
    STA Phase
    STA CurveBase
    LDA #$01
    STA CurveDirty          ; build the edge tables on frame 0
    STA MaskDirty           ; and the masked bytes on frame 1

; --- seed the four tables for the first frame --------------------------------
; The first visible frame is drawn before either rebuild has run, so the
; tables are seeded from HalfTable with c = 0 — the straight phase's row
; shape.  Both edges and both masked bytes are seeded, so the first frame is
; consistent; seeding only the edges would leave the row-0 masks on a
; widening road and punch holes in its left half.  The seed also works for a
; different HalfTable, which is why exercise 1 needs no change here.
    LDX #$00
SeedRow:
    LDA BaseLTable,X        ; L = 20 - Half
    STA LTable,X
    TAY
    LDA LeftPF2,Y           ; the left PF2 byte for that edge, no gap yet
    STA SzL2,X
    LDA HalfTable,X         ; Ridx = Half
    STA RidxTable,X
    TAY
    LDA RightPF0,Y          ; the right PF0 byte for that edge
    STA SzR0,X
    INX
    CPX #ROAD_ROWS
    BNE SeedRow

    LDA #C_SKY
    STA COLUBK
    LDA #C_GOLD
    STA COLUPF

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
; 1. SELECT — advance to the next phase and rebuild everything
; -----------------------------------------------------------------------------
    LDA SWCHB
    AND #$02
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA #$00
    STA PhaseTimer
    JMP NextPhase           ; the same advance the timer uses: Phase, the
                            ; wrap, CurveMask, CurveBase and both flags
SelectReleased:
    LDA #$00
    STA PrevSelect
SelectDone:

; -----------------------------------------------------------------------------
; 2. THE PHASE TIMER — straight, curve right, curve left
; -----------------------------------------------------------------------------
    LDA Phase
    BNE PhaseShort
    LDA #PHASE_LEN_0
    BNE PhaseLimit          ; always taken: A is 150 here
PhaseShort:
    LDA #PHASE_LEN
PhaseLimit:
    STA MaxOff              ; the limit for this phase
    INC PhaseTimer
    LDA PhaseTimer
    CMP MaxOff
    BCC PhaseDone
    LDA #$00
    STA PhaseTimer
NextPhase:
    INC Phase
    LDA Phase
    CMP #3
    BCC SetPhase
    LDA #$00
    STA Phase
SetPhase:
    LDA #$00
    STA CurveMask           ; phase 0 is straight
    STA CurveBase
    LDA Phase
    BEQ PhaseDirty
    LDA #$FF
    STA CurveMask           ; phases 1 and 2 curve
    LDA Phase
    CMP #2
    BNE PhaseDirty
    LDA #32
    STA CurveBase           ; phase 2 reads the negated half of the table
PhaseDirty:
    LDA #$01                ; rebuild both passes, both ways
    STA CurveDirty
    STA MaskDirty
PhaseDone:

; -----------------------------------------------------------------------------
; 3. THE SCROLL — one curve-table step every 8 frames, toward the viewer
; -----------------------------------------------------------------------------
    INC ScrollTimer
    LDA ScrollTimer
    CMP #SCROLL_STEP
    BCC ScrollDone
    LDA #$00
    STA ScrollTimer
    INC Scroll
    LDA Scroll
    AND #31
    STA Scroll
    LDA #$01
    STA CurveDirty
ScrollDone:

; -----------------------------------------------------------------------------
; 4. THE DASH — one row of centre-line dashes every 2 frames, toward the viewer
; -----------------------------------------------------------------------------
    INC DashTimer
    LDA DashTimer
    CMP #DASH_STEP
    BCC DashDone
    LDA #$00
    STA DashTimer
    INC Dash
    LDA Dash
    AND #7
    STA Dash
    LDA #$01
    STA MaskDirty
DashDone:

; -----------------------------------------------------------------------------
; 5. THE SKY COLOURS AND A CLEAN PLAYFIELD
; -----------------------------------------------------------------------------
; The previous frame ended with road bytes in the registers.  Clearing them
; here keeps the sky free of road fragments, and re-setting the two colours
; undoes the road's colour change.
    LDA #C_SKY
    STA COLUBK
    LDA #C_GOLD
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF1
    STA PF2

; -----------------------------------------------------------------------------
; 6. REBUILD THE EDGE TABLES, IF THE CURVE CHANGED
; -----------------------------------------------------------------------------
; 22 rows of width, curve, clamp and two edge lookups: 81-85 cycles each,
; about 1870 cycles for the whole table.  Both tables are rebuilt inside one
; vertical blank, so the picture never shows a row from one curve next to a
; row from another.  The index is (row - Scroll), so a bend enters at row 0
; and moves DOWN the screen as Scroll rises.
    LDA CurveDirty
    BEQ EdgesBuilt
    LDA #$00
    STA CurveDirty
    STA MaskDirty           ; defer the mask pass by one frame: the two
                            ; passes together would not fit the blank
    LDX #$00
BuildRow:
    LDA HalfTable,X         ; 4  the road's half-width for this row
    STA MaxOff              ; 3
    SEC                     ; 2
    SBC #1                  ; 2  MaxOff = Half - 1
    STA MaxOff              ; 3
    TXA                     ; 2
    SEC                     ; 2
    SBC Scroll              ; 3  row - Scroll: features move down
    AND #31                 ; 2  wrap the 32-entry wave
    CLC                     ; 2
    ADC CurveBase           ; 3  0 for the wave, 32 for the mirrored copy
    TAY                     ; 2
    LDA CurveTable,Y        ; 4  the signed curve byte, -6..+6
    AND CurveMask           ; 3  $00 masks it to zero in the straight phase
    CMP #$80                ; 2  carry set when the byte is negative
    BCS .neg                ; 3 taken when negative
    CMP MaxOff              ; 3
    BCC .done               ; 3 taken when 0 <= c <= MaxOff
    LDA MaxOff              ; 3  clamp a large positive curve
    JMP .done               ; 3
.neg:
    EOR #$FF                ; 2  two's complement: A = -c
    CLC                     ; 2
    ADC #1                  ; 2
    CMP MaxOff              ; 3
    BCC .negok              ; 3 taken when |c| <= MaxOff
    LDA MaxOff              ; 3  clamp a large negative curve
.negok:
    EOR #$FF                ; 2  two's complement back to a negative value
    CLC                     ; 2
    ADC #1                  ; 2
.done:
BuildOne:                   ; checkpoint: A = this row's clamped curve
    STA MaxOff              ; 3  c, kept for the second lookup
    CLC                     ; 2
    ADC HalfTable,X         ; 4  Ridx = c + Half
    STA RidxTable,X         ; 4
    LDA BaseLTable,X        ; 4  20 - Half
    CLC                     ; 2
    ADC MaxOff              ; 3  L = 20 - Half + c
    STA LTable,X            ; 4
    INX                     ; 2
    CPX #ROAD_ROWS          ; 2
    BNE BuildRow            ; 3 taken
EdgesBuilt:
EdgeDone:                   ; checkpoint: the edge rebuild has finished

; -----------------------------------------------------------------------------
; 7. REBUILD THE THREE MASKED BYTES, IF THE CURVE OR THE DASH MOVED
; -----------------------------------------------------------------------------
; 22 rows of: the road centre g = (L + Ridx + 20)/2, one 13-entry lookup per
; register, and the dash bit folded into the table index.  113 cycles a row,
; 2486 for the whole table.
; The gap follows the road: g is chunk 14 at one end of the curve and chunk
; 26 at the other, so the line stays on the road's centre instead of on the
; screen's.
    LDA MaskDirty
    BEQ MasksBuilt
    LDA #$00
    STA MaskDirty
    LDX #$00
MaskRow:
    TXA                     ; 2
    SEC                     ; 2
    SBC Dash                ; 3  row - Dash: dashes move down
    AND #3                  ; 2  the four-row dash period
    LSR                     ; 2  0 on a dash row, 1 on a plain row
    STA MaxOff              ; 3  the dash bit
    LDA HalfTable,X         ; 4  a four-pixel gap is a third of the road at
    CMP #DASH_MIN_HALF      ; 2  the horizon, so the narrow rows get none
    BCS .wide               ; 3
    LDA #$01                ; 2
    STA MaxOff              ; 3  force the plain entry
.wide:
    LDA LTable,X            ; 4
    CLC                     ; 2
    ADC RidxTable,X         ; 4
    CLC                     ; 2
    ADC #20                 ; 2  L + Ridx + 20 = 40 + 2c
    LSR                     ; 2  /2 = 20 + c, the road's centre chunk
    SEC                     ; 2
    SBC #14                 ; 2  the gap table starts at chunk 14
    ASL                     ; 2  two entries per chunk: gap on, gap off
    ORA MaxOff              ; 3
    STA GapIx               ; 3
    LDY LTable,X            ; 4  Y = L
    LDA LeftPF2,Y           ; 4  chunks 12..19
    STA MaxOff              ; 3
    LDY GapIx               ; 3
    LDA GapL2Tab,Y          ; 4
    AND MaxOff              ; 3
    STA SzL2,X              ; 4
    LDY RidxTable,X         ; 4  Y = Ridx
    LDA RightPF0,Y          ; 4  chunks 20..23
    STA MaxOff              ; 3
    LDY GapIx               ; 3
    LDA GapR0Tab,Y          ; 4
    AND MaxOff              ; 3
    STA SzR0,X              ; 4
    INX                     ; 2
    CPX #ROAD_ROWS          ; 2
    BNE MaskRow             ; 3 taken
MasksBuilt:
MaskDone:                   ; checkpoint: the mask rebuild has finished

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
BodyStart:                  ; checkpoint: scanline 37/5, visible line 0

; =============================================================================
; VISIBLE LINES 0-79: THE SKY (40 rows x 2 lines)
; =============================================================================
; One job per row: enable or disable the sun.  The loop is rotated so its
; first body runs on visible line 0 instead of eating a WSYNC line.
    LDX #$00
    JMP SkyBody
SkyLoop:
    STA WSYNC               ; line 2X
SkyBody:
    LDA SunTable,X          ; 4  $02 on the sun's eight rows, $00 elsewhere
    STA ENABL               ; 3  the ball is the sun
    STA WSYNC               ; line 2X+1
    INX                     ; 2
    CPX #SKY_ROWS           ; 2
    BNE SkyLoop             ; 3 taken

; =============================================================================
; VISIBLE LINES 80-81: THE HORIZON LINE AND THE VERGE
; =============================================================================
; Both are the BACKGROUND, not the playfield: COLUBK is gold for one line and
; green for the next, and the playfield stays clear, so neither line needs a
; mask.  Doing it this way also lets COLUPF change to the road's grey here,
; hidden behind the band.
    STA WSYNC               ; end the sky's last line (visible 79)
SkyEnd:                     ; checkpoint: the WSYNC that ends the sky
    LDA #C_GOLD
    STA COLUBK              ; visible line 80: the gold horizon line
    LDA #C_ROAD
    STA COLUPF              ; the road's colour, hidden behind it
    STA WSYNC               ; end visible 80
    LDA #C_GRASS
    STA COLUBK              ; visible line 81: the verge
    LDX #$00                ; row 0; the road loop draws line 82
    STA WSYNC               ; end visible 81

; =============================================================================
; VISIBLE LINES 82-191: THE ROAD (22 rows x 5 lines)
; =============================================================================
; Each road row is five identical lines: 54 cycles of stores plus WSYNC.
; The row's edges are constant across its five lines, so the first line of a
; row draws exactly what the fifth does.
;
; The very first road line is entered with a JMP and so starts three cycles
; late, which moves its stores to 14/21/28/39/46/57.  Every one of those is
; still inside its window, and row 0's right half is a single PF0 chunk, so
; even a late PF1 write there would cost nothing.
    JMP RoadBody            ; X is already 0
RoadLoop:
    STA WSYNC               ; line 1 of row X
RoadBody:
    +DrawRoadRow            ; 54
    STA WSYNC               ; line 2 of row X
    +DrawRoadRow
    STA WSYNC               ; line 3 of row X
    +DrawRoadRow
    STA WSYNC               ; line 4 of row X
    +DrawRoadRow
    STA WSYNC               ; line 5 of row X
    +DrawRoadRow
    INX                     ; 2
    CPX #ROAD_ROWS          ; 2
    BEQ RoadDone            ; 2/3
    JMP RoadLoop            ; 3  (the loop body is longer than a branch can reach)
RoadDone:
    STA WSYNC               ; finish visible line 191

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229, the first blanked line
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SETHORIZPOSBL — the Lesson 26 divide-by-15 dance, for the ball
; =============================================================================
; A = the desired left edge + the output-delay bias.  Subtracting 15 costs
; 5 cycles = 15 color clocks per iteration; the remainder becomes the signed
; fine motion in HMBL and the coarse store lands on the beam.
    !align 31, 0
SetHorizPosBL:
    STA WSYNC
    SEC
DivBL:
    SBC #15
    BCS DivBL
    EOR #7                  ; the negative remainder -> the signed fine value
    ASL                     ; bits 0-3 -> HMBL's high nibble
    ASL
    ASL
    ASL
    STA HMBL
    STA RESBL               ; the coarse strobe
    STA WSYNC
    RTS

; =============================================================================
; THE ROAD'S HALF-WIDTH — one byte per road row, in playfield chunks
; =============================================================================
; Row 0 is the horizon row: a 3-chunk road (12 pixels).  The half-width grows
; to 10 chunks at row 21, so the road is 21 chunks (84 pixels) at the bottom.
; The growth follows a mild perspective curve: slow near the horizon, faster
; near the viewer.
    !align 255, 0
HalfTable:
    !byte  1,  1,  1,  2,  2,  2,  3,  3,  4,  4   ; rows  0- 9
    !byte  5,  5,  5,  6,  6,  7,  7,  8,  8,  9   ; rows 10-19
    !byte  9, 10                                   ; rows 20-21

; The left edge with no curve: 20 - Half.
    !align 255, 0
BaseLTable:
    !byte 19, 19, 19, 18, 18, 18, 17, 17, 16, 16   ; rows  0- 9
    !byte 15, 15, 15, 14, 14, 13, 13, 12, 12, 11   ; rows 10-19
    !byte 11, 10                                   ; rows 20-21

; =============================================================================
; THE CURVE — 32 signed bytes, one full wave, -6..+6
; =============================================================================
; Row r reads entry ((r - Scroll) & 31) + CurveBase, so the pattern crawls
; DOWN the road as Scroll advances — toward the viewer — and CurveBase picks
; the wave or its mirror.  The clamp is what turns
; this constant amplitude into a perspective curve: the narrow rows near the
; horizon cannot take the full +/-6, so they flatten out by themselves.
    !align 255, 0
CurveTable:
    !byte   0,   1,   2,   3,   4,   5,   6,   6   ; entries  0- 7
    !byte   6,   6,   6,   5,   4,   3,   2,   1   ; entries  8-15
    !byte   0,  -1,  -2,  -3,  -4,  -5,  -6,  -6   ; entries 16-23
    !byte  -6,  -6,  -6,  -5,  -4,  -3,  -2,  -1   ; entries 24-31
    !byte   0,  -1,  -2,  -3,  -4,  -5,  -6,  -6   ; entries 32-39
    !byte  -6,  -6,  -6,  -5,  -4,  -3,  -2,  -1   ; entries 40-47
    !byte   0,   1,   2,   3,   4,   5,   6,   6   ; entries 48-55
    !byte   6,   6,   6,   5,   4,   3,   2,   1   ; entries 56-63

; =============================================================================
; THE CENTRE-LINE GAP — 13 chunks x 2 dash states, one table per register
; =============================================================================
; Indexed by ((g - 14) * 2 + dashBit), where g is the road's centre chunk and
; dashBit is 0 on a dash row and 1 on a plain one.  Each entry ANDs with the
; register: everything on except the one bit for chunk g.  g is 14-19 in the
; left half (PF2, bit g-12) and 20-23 in right PF0 (bit g-16).  The register
; that does not hold g keeps $FF, and so does every plain row.
;
; The road's centre can reach chunk 26 on the strongest right-hand curves, and
; right PF1 (chunks 24-31) is written in the same group as PF0, where there is
; no room for a third masked byte.  The table therefore saturates: g = 24, 25
; and 26 all clear chunk 23, so on the extreme right the line stops three
; chunks short of the centre.  Everywhere else it is the true centre.
    !align 255, 0
GapL2Tab:
    !byte $FB, $FF                                  ; g = 14  (dash on, off)
    !byte $F7, $FF                                  ; g = 15
    !byte $EF, $FF                                  ; g = 16
    !byte $DF, $FF                                  ; g = 17
    !byte $BF, $FF                                  ; g = 18
    !byte $7F, $FF                                  ; g = 19
    !byte $FF, $FF, $FF, $FF, $FF, $FF              ; g = 20-22: gap is in PF0
    !byte $FF, $FF, $FF, $FF, $FF, $FF              ; g = 23-25
    !byte $FF, $FF                                  ; g = 26
    !align 255, 0
GapR0Tab:
    !byte $FF, $FF, $FF, $FF, $FF, $FF              ; g = 14-16
    !byte $FF, $FF, $FF, $FF, $FF, $FF              ; g = 17-19: gap is in PF2
    !byte $EF, $FF                                  ; g = 20
    !byte $DF, $FF                                  ; g = 21
    !byte $BF, $FF                                  ; g = 22
    !byte $7F, $FF                                  ; g = 23
    !byte $7F, $FF                                  ; g = 24: saturates at 23
    !byte $7F, $FF                                  ; g = 25: saturates at 23
    !byte $7F, $FF                                  ; g = 26: saturates at 23

; =============================================================================
; THE SUN — one ENABL value per sky row
; =============================================================================
SunTable:
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows  0- 7
    !byte $00, $00, $00, $00, $02, $02, $02, $02   ; rows  8-15
    !byte $02, $02, $02, $02, $00, $00, $00, $00   ; rows 16-23 (12-19 sun)
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 24-31
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 32-39

; =============================================================================
; THE LEFT-HALF MASK TABLES — 20 entries each, indexed by the left edge L
; =============================================================================
; LeftPF0[L] = chunks L..3 on  (PF0 bits 4-7; bit 4 is chunk 0)
; LeftPF1[L] = chunks L..3 and 4..11 on (see the table)
; LeftPF2[L] = chunks L..19 on (PF2 bits 0-7; bit 0 is chunk 12)
; The road always starts at chunk L and runs to the centre of the screen.
    !align 255, 0
LeftPF0:
    !byte $F0, $E0, $C0, $80, $00, $00, $00, $00   ; L =  0- 7
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; L =  8-15
    !byte $00, $00, $00, $00                       ; L = 16-19

    !align 255, 0
LeftPF1:
    !byte $FF, $FF, $FF, $FF, $FF, $7F, $3F, $1F   ; L =  0- 7
    !byte $0F, $07, $03, $01, $00, $00, $00, $00   ; L =  8-15
    !byte $00, $00, $00, $00                       ; L = 16-19

    !align 255, 0
LeftPF2:
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF   ; L =  0- 7
    !byte $FF, $FF, $FF, $FF, $FF, $FE, $FC, $F8   ; L =  8-15
    !byte $F0, $E0, $C0, $80                       ; L = 16-19

; =============================================================================
; THE RIGHT-HALF MASK TABLES — 20 entries each, indexed by Ridx = R - 20
; =============================================================================
; RightPF0[R] = chunks 20..20+R on (bit 4 is chunk 20)
; RightPF1[R] = chunks 24..20+R on
; RightPF2[R] = chunks 32..20+R on
; The right half runs from the centre of the screen to the road's right edge.
    !align 255, 0
RightPF0:
    !byte $10, $30, $70, $F0, $F0, $F0, $F0, $F0   ; R =  0- 7
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0   ; R =  8-15
    !byte $F0, $F0, $F0, $F0                       ; R = 16-19

    !align 255, 0
RightPF1:
    !byte $00, $00, $00, $00, $80, $C0, $E0, $F0   ; R =  0- 7
    !byte $F8, $FC, $FE, $FF, $FF, $FF, $FF, $FF   ; R =  8-15
    !byte $FF, $FF, $FF, $FF                       ; R = 16-19

    !align 255, 0
RightPF2:
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; R =  0- 7
    !byte $00, $00, $00, $00, $01, $03, $07, $0F   ; R =  8-15
    !byte $1F, $3F, $7F, $FF                       ; R = 16-19

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
