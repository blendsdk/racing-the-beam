; =============================================================================
; LESSON 73: The HMOVE Comb & the Cosmic Ark Starfield
; =============================================================================
; Part 11: Legendary Techniques
;
; What this program does:
;   "the starfield": a 192-line night sky over a planet limb.  The upper 160
;   lines are a sparse field of one-pixel stars; the bottom 32 lines are a
;   green/brown planet arc with a small red ship.
;
;   The stars are not positioned per line.  Missile 0 and the ball are
;   positioned ONCE, then every visible line writes a motion value to HMM0
;   and HMBL and strokes HMOVE.  The TIA re-applies the motion, so the
;   objects walk across the screen: their X is the accumulated motion.  A
;   pseudo-random motion table makes the walk scatter instead of tracing a
;   single diagonal.  NUSIZ0=3 gives three 1-pixel M0 copies at X, X+16 and
;   X+32; the ball is the fourth star.  A line mask decides which lines
;   show the objects.  Adjacent star lines are allowed: the objects keep
;   their position, so there is no "position-ahead" rule.
;
;   Every star-band line strokes HMOVE in HBLANK, which blanks the leftmost
;   eight pixels.  The eight-pixel bar is therefore present on all 160
;   star-band lines in BOTH captures; it is the real HMOVE signature, not a
;   mode.  The two states are:
;
;     starfield.png  one HMOVE per line: the walk and the bar.
;     comb.png       a second HMOVE about 44 cycles into the visible line with
;                    HMM0=HMBL=$40.  In the visible area the extra clocks
;                    plug MOTCK and delay the not-yet-drawn pixels rightward;
;                    the stall is bounded by the line and depends on where
;                    each star's pixel falls relative to the strobe.
;
;   The auto-demo switches the second strobe on once, at frame 240.
;   SELECT toggles it at any time.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   The 192 visible lines are two bands:
;
;     visible   0-159   the star band    160 lines   20 groups x 8 lines
;     visible 160-191   the planet band   32 lines   16 rows x 2 lines
;                       ----------------
;                       160 + 32 = 192
;
;   Absolute scanlines: BodyStart 37/5, PlanetStart 197/5, OverscanStart
;   228/3 label (the first blanked line is 229).  The frame gate is
;   StartFrame 259/3 and VblankStart 0/5.
;
; The star band (visible 0-159):
;   The motion is pipelined.  The first line's bytes are preloaded into
;   HMM0/HMBL in VBLANK and the first strobe is the first instruction at
;   BodyStart; each later line's motion is loaded into A and Y at the end
;   of the previous line.  The HMOVE lands at about cycle 11 on the body
;   lines and ~13 on the group-first line, early enough in HBLANK for the
;   eight-pixel bar (measured 160/160 star-band lines in both captures).
;   The group's eighth line loads the next group's first-line motion into
;   A/Y; the next GroupTop writes HMM0/HMBL and strokes HMOVE, outside the
;   24-cycle motion-register window after the eighth line's comb strobe.
;   Then the kernel tests the mask bit, sets the enables, and (in comb
;   mode) strokes the second HMOVE.
;
;   The motion table gives the per-line displacement.  A positive value in
;   the high nibble moves left (1-7 pixels), a negative value moves right
;   (1-8 pixels).  The star table uses $00 (no move), $10-$50 (left 1-5)
;   and $B0-$F0 (right 5-1); the ball table uses $20-$60 (left 6-2) and
;   $A0-$E0 (right 6-2).  The table is 160 entries, one per visible line,
;   plus a sentinel for the last +1 load.  The two tables are page-aligned,
;   so LDA/LDY abs,X is four cycles and never crosses a page.  The walks
;   are closed: the initial position is the last line's position, so the
;   object returns to the start at the end of every frame and no per-frame
;   RESxx is needed.  The relative walk spans about 96 pixels; the three
;   copies add +16 and +32, and the ball has its own walk.  The main ROM's
;   measured start is M0 X=78 and ball X=83; the table's design points are
;   STAR_START = 73 and BALL_START = 83.  The +5 on M0 is the positioner's
;   calibration; the relative walk is the table's job.
;
;   The line mask is 24 bytes: bit 0 of byte 0 is visible line 0, bit 7 of
;   byte 19 is line 159.  Bit 0 of every byte is zero: the group's first
;   line is always blank and carries the mask-byte reload.  The other bits
;   are the sparse field; adjacent bits are legal because the objects do not
;   need to be re-positioned.  The last four bytes are zero, so no star is
;   drawn below the horizon.  34 star lines, up to 136 star pixels.
;
; The two states (visible 0-159):
;   Both states stroke HMOVE on every star-band line.  The single-strobe
;   state is the walk: the eight-pixel bar and the accumulated motion.
;   The second-strobe state writes HMM0=HMBL=$40 after the enables and
;   strokes HMOVE again about 44 cycles into the visible line.  In the visible
;   area the extra clocks plug MOTCK: they delay the pixels that have not
;   yet been drawn, rightward.  The stall is bounded by the line and depends
;   on where each star's pixel falls relative to the strobe; a full-mask
;   probe measures rightward shifts of 36-133 pixels (mod 160), not a
;   4-pixel left move and not a uniform median.  The bar is unchanged and
;   the frame length stays 262.
;
; The planet band (visible 160-191):
;   Sixteen rows x two lines.  PF2 is filled first from the centre out,
;   then PF1, then PF0, so the limb grows from an 8-pixel cap to the full
;   160-pixel width.  CTRLPF=$01 reflects the playfield.  COLUPF is green
;   on the first six rows and brown on the rest.  P0 is the ship: eight
;   pixels wide, eight scanlines tall, drawn as four two-line rows at
;   planet rows 10-13; the ship spans X=57-65 (left edge 57; a fixed
;   coarse delay, not an HMOVE).  COLUP0 is red here; missile 0 is
;   disabled, so the change from the star colour is safe.
;
; Input and the auto-demo:
;   SWCHB bit 1 SELECT (active low) toggles CombMode on a new press.
;   The auto-demo sets CombMode=1 in the VBLANK whose Frame value is 240
;   (about four seconds), so a two-second capture is the single-strobe
;   walk and a five-second capture (after the toggle) shows the second
;   strobe.
;
;   The mask scrolls: every eight frames the 20 star bytes are rotated left
;   by one bit, so the sampled points on the walk drift down one line per
;   eight frames.  The last four mask bytes stay zero.  The sky colour
;   cycles through four blues ($82/$84/$86/$88), eight frames each.
;
; Checkpoints (the values are the state at the label):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   PlanetStart (197/5), OverscanStart (228/3 label; line 229);
;   CombWrite (A = the new CombMode, 0/1), SkyRead (A = the sky colour),
;   MaskRotate (A = the new first mask byte), GroupTop (X = the line,
;   A/Y = the next line's motion).
;
; RAM map (the exact map; +clean_start zeroes every byte):
;   $80 Frame         frame counter, 8 bits
;   $81 CombMode      0 = single strobe, 1 = second strobe
;   $82 PrevSelect    SELECT edge latch (0 = released, 1 = pressed)
;   $83 MaskByte      the current eight-line mask byte
;   $84 MaskIdx       the current group's byte index (0-19)
;   $85 Groups        groups left in this frame (20..1)
;   $86-$9D MaskBuf   24-byte RAM mask (20 star bytes + 4 zero bytes)
;   $9E               AutoFired  0 = the frame-240 auto has not fired
;   $9F-$F7           free (89 bytes)
;   $F8-$FF           stack
;
; Build: acme -f plain -o build/lesson73.bin \
;        lessons/part11-legendary/73-cosmic-ark-starfield/73-cosmic-ark-starfield.asm
; Run:   stella build/lesson73.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan
POS_BIAS       = 3       ; the SetHorizPos calibration bias from Lesson 26

STAR_GROUPS    = 20      ; 160 visible lines / 8 lines per group
PLANET_ROWS    = 16      ; 16 rows x 2 lines = 32 visible lines
SCROLL_FRAMES  = 8       ; rotate the mask once every 8 frames
AUTO_COMB      = 240     ; the auto-demo turns the second strobe on here

SHIP_ROW       = 10      ; the ship's first planet row (4 rows = 8 lines)
SHIP_ROWS      = 4
PLANET_COLOUR  = 6       ; rows 0-5 green, rows 6-15 brown

STAR_START     = 73      ; the table's design point
BALL_START     = 83      ; the ball's design position before line 0

COMB_MOTION    = $40     ; HMM0/HMBL: +4 pixels left, second strobe

; --- colours -----------------------------------------------------------------
C_SKY0         = $82     ; dark blue
C_SKY1         = $84     ; medium blue
C_SKY2         = $86     ; bright blue
C_SKY3         = $88     ; light blue
C_STAR         = $0E     ; the three missile copies: white
C_STAR_BALL    = $8E     ; the ball: bright blue
C_SHIP         = $42     ; the ship: red
C_PLANET_GREEN = $C6     ; the planet's limb
C_PLANET_BROWN = $26     ; the planet's body

; =============================================================================
; RAM ALLOCATION ($80-$9E; +clean_start zeroes every byte)
; =============================================================================
Frame        = $80   ; frame counter, 8 bits
CombMode     = $81   ; 0 = one HMOVE per line, 1 = second visible HMOVE
PrevSelect   = $82   ; SELECT edge latch (0 = released, 1 = pressed)
MaskByte     = $83   ; the current eight-line mask byte
MaskIdx      = $84   ; the current group's mask byte index, 0-19
Groups       = $85   ; groups left in this frame, 20..1
MaskBuf      = $86   ; 24 bytes: 20 star bytes + 4 zero horizon bytes
AutoFired    = $9E   ; 0 = the frame-240 auto-demo has not fired; 1 = fired
;
; $9F-$F7 are free (89 bytes).  The stack lives at $F8-$FF; the call depth
; stays at one level (SetCoarseM0, SetCoarseBL and RotateMask).

; =============================================================================
; WALKLINE — one eight-line group's first line, then seven masked lines
; =============================================================================
; The group's first line is always blank (mask bit 0 is zero).  It moves the
; objects with the first HMOVE, reloads the mask byte for the next seven
; lines, consumes bit 0, disables the objects, and (in comb mode) strokes
; the second HMOVE.  The seven bodies test bits 1-7.
;
; The motion is pipelined: A and Y hold this line's HMM0/HMBL bytes, which
; the previous line loaded.  The line starts with a 2-cycle NOP, then the
; stores and STA HMOVE; the HMOVE lands at about cycle 11 and the leftmost
; eight pixels are blanked on every line.  The NOP puts the group-first
; line's comb strobe at least 25 cycles before this line's HMM0 stores.
; At the end of the line the kernel loads the NEXT line's bytes into A
; and Y.
;
; The star line's enable must land before the star's first pixel.  The
; ball is the leftmost object: its table walk from BALL_START=83 reaches
; X=9 on line 19 (X=12 with the positioner's +3 bias), pixel cycle 25.7.
; The capture's visible leftmost is X=9-11 depending on the scroll phase;
; the enable is in time (the capture shows the ball).  The star's own
; table walk never goes left of X=24.
!macro WalkBody {
    NOP                     ; the group-first comb's 24-cycle window
    STA HMM0
    STY HMBL
    STA HMOVE
    LSR MaskByte
    BCS .star
    LDA #$00
    STA ENAM0
    STA ENABL
    JMP .comb
.star:
    LDA #$02
    STA ENAM0
    STA ENABL
.comb:
    LDA CombMode
    BEQ .noComb
    LDA #COMB_MOTION
    STA HMM0
    STA HMBL
    STA HMOVE
.noComb:
    LDA HmmStar+1,X
    LDY HmmBall+1,X
    STA WSYNC
    INX
}

; =============================================================================
; GROUPFIRSTBODY — the eight-line group's blank first line
; =============================================================================
; The caller has already stroked this line's HMOVE: the first group from the
; preloaded registers at BodyStart, the later groups from the pipelined A/Y.
; This body reloads the mask byte, consumes bit 0, disables the objects,
; strokes the second HMOVE in comb mode, loads the next line's motion, and
; ends the line.  The first group's line 0 is the only caller that does not
; do the two motion stores, which is why its HMOVE lands at ~cycle 8.
!macro GroupFirstBody {
    LDY MaskIdx
    LDA MaskBuf,Y
    STA MaskByte
    INC MaskIdx
    LSR MaskByte            ; consume bit 0 (the ROM table's bit 0 is 0)
    LDA #$00
    STA ENAM0
    STA ENABL
    LDA CombMode
    BEQ .noComb
    LDA #COMB_MOTION
    STA HMM0
    STA HMBL
    STA HMOVE               ; the second strobe, visible line
.noComb:
    LDA HmmStar+1,X
    LDY HmmBall+1,X
    STA WSYNC
    INX
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
    LDA #C_SKY0
    STA COLUBK              ; the first sky colour; VBLANK cycles it
    LDA #C_STAR
    STA COLUP0              ; missile 0 and (later) the ship
    LDA #C_STAR_BALL
    STA COLUPF              ; the ball star and (later) the planet
    LDA #$01
    STA CTRLPF              ; reflect the playfield; 1-pixel ball
    LDA #$03
    STA NUSIZ0              ; missile 0: three close 1-pixel copies
    LDA #$00
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    STA ENAM0
    STA ENABL

; --- copy the mask to RAM ----------------------------------------------------
    LDX #$00
CopyMask:
    LDA MaskRom,X
    STA MaskBuf,X
    INX
    CPX #24
    BNE CopyMask

; --- position M0 and the ball ONCE -------------------------------------------
; The walk moves the stars from here on.  Each routine is the Lesson 26
; divide-by-15 dance; the single HMOVE applies both fine offsets.  The
; star's initial point is STAR_START, the ball's is BALL_START.  P0 (the
; ship) is positioned every frame in VBLANK instead: the walk's HMOVEs
; re-apply HMP0 160 times a frame, so HMP0 must be 0 or P0 drifts; the
; ship's coarse-only positioner avoids a second HMOVE that would shift the
; stars too.
    LDA #(STAR_START + POS_BIAS)
    JSR SetCoarseM0
    LDA #(BALL_START + POS_BIAS + 1)
    JSR SetCoarseBL
    LDA #$00
    STA HMP0
    STA HMOVE

; --- single-strobe mode at power-on -----------------------------------------
    STA CombMode
    STA HMM0
    STA HMBL
    STA Frame
    STA PrevSelect

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
; 1. SELECT — a new press toggles the second strobe
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is pressed.  PrevSelect makes the toggle
; happen on the falling edge (one toggle per press).  CombWrite is the
; SELECT path's store; the auto-demo has its own direct path so it cannot
; loop back into the frame-240 check.
    LDA SWCHB
    AND #$02
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA CombMode
    EOR #$01
CombWrite:                  ; checkpoint: A = the new CombMode (0/1)
    STA CombMode
    JMP SelectDone
SelectReleased:
    LDA #$00
    STA PrevSelect
SelectDone:

; -----------------------------------------------------------------------------
; 2. THE AUTO-DEMO — the second strobe on at frame 240
; -----------------------------------------------------------------------------
; AutoFired latches the auto-demo off after its one firing at frame 240.
    LDA Frame
    CMP #AUTO_COMB
    BNE AutoDone
    LDA AutoFired
    BNE AutoDone
    LDA #$01
    STA AutoFired
    STA CombMode
AutoDone:

; -----------------------------------------------------------------------------
; 3. THE SKY COLOUR — four blues, eight frames each
; -----------------------------------------------------------------------------
    LDA Frame
    LSR                     ; one phase every 8 frames
    LSR
    LSR
    AND #$03
    TAX
    LDA SkyColours,X
SkyRead:                    ; checkpoint: A = the sky colour
    STA COLUBK

; -----------------------------------------------------------------------------
; 4. THE STAR COLOURS — white missile copies, cyan ball
; -----------------------------------------------------------------------------
    LDA #C_STAR
    STA COLUP0
    LDA #C_STAR_BALL
    STA COLUPF
    LDA #$03
    STA NUSIZ0              ; three close missile copies (and P0 copies)
    LDA #$00
    STA PF0                 ; the planet's full-width PF ends here
    STA PF1
    STA PF2
    STA GRP0                ; the ship's last row ends here
    STA GRP1

; -----------------------------------------------------------------------------
; 5. THE SCROLL — rotate the 20 star mask bytes once every 8 frames
; -----------------------------------------------------------------------------
    LDA Frame
    AND #(SCROLL_FRAMES - 1)
    BNE NoRotate
    JSR RotateMask
NoRotate:

; -----------------------------------------------------------------------------
; 6. THE SHIP — a coarse-only fixed-delay positioner every frame
; -----------------------------------------------------------------------------
; No HMOVE: the walk's HMOVEs must not get an extra fine offset from HMP0.
; 22 NOPs = 44 cycles; RESP0 writes at ~cycle 46; the measured ship spans
; X=57-65 (left edge 57).
    STA WSYNC
    !fill 22, $EA
    STA RESP0
    LDA #$00
    STA HMP0

; -----------------------------------------------------------------------------
; 7. THE WALK'S START — reset the cursor and the group count
; -----------------------------------------------------------------------------
    LDA #$00
    STA MaskIdx
    LDA #STAR_GROUPS
    STA Groups
    LDA #$00
    STA HMP0                ; the walk's HMOVEs must not move P0
    LDA HmmStar
    STA HMM0                ; preload the first line's motion
    LDA HmmBall
    STA HMBL
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
BodyStart:                  ; checkpoint: scanline 37/5, visible line 0
    STA HMOVE               ; the first line's strobe, ~cycle 8

; =============================================================================
; VISIBLE LINES 0-159: THE STAR BAND (20 groups x 8 lines)
; =============================================================================
; BodyStart is visible line 0.  A/Y hold the first line's motion; the loop
; then pipelines each line's motion into the next.  The objects were
; positioned once at reset, so no RESM0/RESBL appears in this band.
    LDX #$00
StarField:
    ; --- group 0's first line: HMOVE first, then the blank-line body ------
    +GroupFirstBody
    +WalkBody
    +WalkBody
    +WalkBody
    +WalkBody
    +WalkBody
    +WalkBody
; --- the eighth line carries the group tail, before its WSYNC -------------
    STA HMM0
    STY HMBL
    STA HMOVE
    LSR MaskByte
    BCS Body7Star
    LDA #$00
    STA ENAM0
    STA ENABL
    JMP Body7Comb
Body7Star:
    LDA #$02
    STA ENAM0
    STA ENABL
Body7Comb:
    LDA CombMode
    BEQ Body7NoComb
    LDA #COMB_MOTION
    STA HMM0
    STA HMBL
    STA HMOVE
Body7NoComb:
    LDA HmmStar+1,X
    LDY HmmBall+1,X
    DEC Groups
    BNE GroupNext
    STA WSYNC               ; the last group's eighth line
    INX
    JMP PlanetStart
GroupNext:
    STA WSYNC               ; the eighth line ends; the next group starts
    INX
    JMP GroupTop

GroupTop:
    ; --- groups 1-19's first line: A/Y hold the next group's motion ------
    STA HMM0
    STY HMBL
    STA HMOVE               ; the write completes at ~cycle 13
    +GroupFirstBody
    +WalkBody
    +WalkBody
    +WalkBody
    +WalkBody
    +WalkBody
    +WalkBody
; --- the eighth line carries the group tail, before its WSYNC -------------
    STA HMM0
    STY HMBL
    STA HMOVE
    LSR MaskByte
    BCS Body7Star2
    LDA #$00
    STA ENAM0
    STA ENABL
    JMP Body7Comb2
Body7Star2:
    LDA #$02
    STA ENAM0
    STA ENABL
Body7Comb2:
    LDA CombMode
    BEQ Body7NoComb2
    LDA #COMB_MOTION
    STA HMM0
    STA HMBL
    STA HMOVE
Body7NoComb2:
    LDA HmmStar+1,X
    LDY HmmBall+1,X
    DEC Groups
    BNE GroupNext2
    STA WSYNC
    INX
    JMP PlanetStart
GroupNext2:
    STA WSYNC
    INX
    JMP GroupTop

; =============================================================================
; VISIBLE LINES 160-191: THE PLANET BAND (16 rows x 2 lines)
; =============================================================================
; PlanetStart is scanline 197.  The star objects are disabled; the
; playfield draws the limb and P0 draws the ship.
PlanetStart:                ; checkpoint: scanline 197, visible line 160
    LDA #C_PLANET_GREEN
    STA COLUPF              ; the PF colour must be set before the first chunk
    LDY #$00
    LDA PlanetPF0,Y         ; the first row's PF goes first: the PF0 chunk 0
    STA PF0                 ; deadline is cycle 22.7
    LDA PlanetPF1,Y
    STA PF1
    LDA PlanetPF2,Y
    STA PF2
    LDA #$00
    STA ENAM0
    STA ENABL
    STA GRP0                ; the ship is blank on row 0
    JMP PlanetAfterPF
PlanetRow:
    LDA PlanetPF0,Y
    STA PF0
    LDA PlanetPF1,Y
    STA PF1
    LDA PlanetPF2,Y
    STA PF2
PlanetAfterPF:
; --- the ship: four rows, eight scanlines -----------------------------------
    CPY #SHIP_ROW
    BCC NoShip
    CPY #(SHIP_ROW + SHIP_ROWS)
    BCS NoShip
    LDA #C_SHIP
    STA COLUP0              ; the ship is red; missile 0 is off
    LDA #$00
    STA NUSIZ0              ; one 8-pixel ship copy on the ship rows
    LDA ShipShape-SHIP_ROW,Y
    STA GRP0
    JMP ShipDone
NoShip:
    LDA #$00
    STA GRP0
ShipDone:
; --- the planet's two colours -----------------------------------------------
    CPY #PLANET_COLOUR
    BNE ColourDone
    LDA #C_PLANET_BROWN
    STA COLUPF
ColourDone:
    INY
    CPY #PLANET_ROWS
    BEQ PlanetLast
    STA WSYNC               ; the row's first line
    STA WSYNC               ; the row's second line
    JMP PlanetRow
PlanetLast:
    STA WSYNC               ; the last row's first line
    STA WSYNC               ; the last row's second line

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: the line the label reports (228/3 after the trim)
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SETCOARSEM0 / SETCOARSEBL — the Lesson 26 dance for the stars
; =============================================================================
; A = the desired left edge + POS_BIAS.  Each routine starts a fresh line,
; divides by 15 (5 cycles per iteration = 15 colour clocks), stores the
; remainder as the fine value, strobes the coarse reset, and ends with a
; WSYNC.  The caller's single HMOVE applies the fine offsets.
    !align 31, 0
SetCoarseM0:
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
    STA WSYNC
    RTS

; =============================================================================
; ROTATEMASK — rotate the 20 star mask bytes left by one bit
; =============================================================================
; The star bits are consumed bit 0 first, so a left rotation moves each
; star down one line.  The carry out of byte 19 wraps into bit 0 of byte 0.
; The four horizon bytes are not rotated: they stay zero.
RotateMask:
    CLC
    LDX #$00
    LDY #20                 ; DEY keeps the carry: CPX would destroy it
RotateLoop:
    LDA MaskBuf,X
    ROL                     ; carry in = the previous byte's bit 7
    STA MaskBuf,X
    INX                     ; INX and DEY do not touch the carry
    DEY
    BNE RotateLoop
    BCC RotateDone
    LDA MaskBuf
    ORA #$01
    STA MaskBuf
RotateDone:
    LDA MaskBuf
MaskRotate:                 ; checkpoint: A = the new first mask byte
    RTS

; =============================================================================
; THE MOTION TABLES — one byte per visible line, plus a sentinel
; =============================================================================
; The byte is the HMM signed offset: $10-$70 move left 1-7 pixels,
; $F0-$80 move right 1-8 pixels, $00 does not move.  This ROM's star table
; uses $00/$10-$50/$B0-$F0; the ball table uses $20-$60/$A0-$E0.  The walks are closed
; (the last line returns to the initial position), and the initial position
; is the last line's point: STAR_START = 73, BALL_START = 83.  Page-aligned, so
; LDA/LDY abs,X is four cycles; the +1 load of the last line reads the
; sentinel, still inside the page.
    !align 255, 0
HmmStar:
    !byte $50, $50, $50, $10, $30, $10, $20, $40, $20, $50, $40, $30, $20, $40, $20, $10
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $F0, $B0, $C0, $B0, $B0, $F0, $C0, $B0
    !byte $F0, $E0, $D0, $B0, $D0, $C0, $C0, $B0, $B0, $B0, $D0, $C0, $B0, $D0, $F0, $F0
    !byte $20, $20, $10, $50, $10, $40, $30, $40, $50, $20, $20, $30, $10, $20, $50, $10
    !byte $40, $40, $20, $20, $20, $50, $30, $50, $E0, $D0, $C0, $D0, $B0, $F0, $C0, $C0
    !byte $F0, $E0, $B0, $D0, $C0, $D0, $B0, $C0, $C0, $C0, $B0, $E0, $B0, $E0, $E0, $C0
    !byte $10, $20, $10, $20, $10, $40, $10, $50, $30, $40, $30, $20, $10, $30, $10, $20
    !byte $40, $20, $20, $30, $30, $30, $20, $10, $B0, $D0, $D0, $C0, $C0, $C0, $E0, $E0
    !byte $C0, $C0, $B0, $B0, $E0, $C0, $F0, $F0, $C0, $00, $00, $00, $00, $00, $00, $00
    !byte $30, $50, $10, $50, $10, $20, $30, $30, $20, $40, $30, $40, $20, $40, $30, $20
    !byte $00

    !align 255, 0
HmmBall:
    !byte $50, $20, $50, $30, $30, $20, $30, $60, $40, $50, $60, $30, $50, $40, $20, $30
    !byte $20, $60, $20, $30, $D0, $A0, $C0, $B0, $A0, $D0, $B0, $B0, $D0, $A0, $B0, $B0
    !byte $B0, $D0, $B0, $B0, $D0, $A0, $D0, $A0, $30, $20, $20, $30, $20, $40, $60, $30
    !byte $20, $30, $50, $30, $20, $60, $60, $50, $30, $60, $20, $30, $B0, $B0, $A0, $A0
    !byte $E0, $C0, $D0, $E0, $B0, $C0, $E0, $A0, $C0, $B0, $D0, $C0, $C0, $A0, $D0, $C0
    !byte $40, $40, $60, $50, $60, $40, $30, $60, $40, $30, $20, $50, $50, $60, $50, $60
    !byte $30, $60, $50, $30, $C0, $B0, $E0, $D0, $E0, $E0, $E0, $E0, $E0, $E0, $B0, $C0
    !byte $B0, $E0, $E0, $D0, $C0, $E0, $E0, $C0, $60, $20, $20, $20, $50, $20, $20, $40
    !byte $30, $40, $40, $60, $30, $60, $20, $40, $50, $20, $30, $50, $B0, $E0, $B0, $A0
    !byte $E0, $B0, $C0, $B0, $E0, $E0, $C0, $D0, $B0, $C0, $B0, $D0, $E0, $E0, $C0, $C0
    !byte $00

; =============================================================================
; THE LINE MASK — 24 bytes, one bit per visible line
; =============================================================================
; Bit 0 of byte 0 is visible line 0, bit 7 of byte 19 is line 159.  Bit 0
; of every byte is zero: the group's first line is blank and carries the
; mask-byte reload.  The other bits are the sparse field; adjacent bits are
; legal because the objects do not need to be re-positioned.  34 star
; lines, up to 136 star pixels.  Bytes 20-23 cover the planet band and
; stay zero: no star below the horizon.  The ROM table's bit 0 is zero in
; every byte, but the ROL can move bit 7 into bit 0; the group-first line
; consumes that bit unconditionally, so a star crossing a byte boundary is
; dropped for one scroll phase (8 frames) (a blink that lasts that phase).
MaskRom:
    !byte $28, $80, $54, $40, $92, $00, $4C, $08, $C0, $C0, $08, $82, $E0, $58, $40, $40
    !byte $48, $20, $40, $40, $00, $00, $00, $00

; =============================================================================
; THE PLANET — 16 rows, one byte per playfield register per row
; =============================================================================
    !align 255, 0
PlanetPF0:
    !fill 12, $00           ; rows 0-11: PF2 and PF1 only
    !byte $80, $C0, $E0, $F0 ; rows 12-15: chunks 3, 2-3, 1-3, 0-3

    !align 255, 0
PlanetPF1:
    !fill 8, $00            ; rows 0-7: PF2 only
    !byte $01, $03, $07, $0F ; rows 8-11: chunks 11, 10-11, 9-11, 8-11
    !byte $FF, $FF, $FF, $FF ; rows 12-15: chunks 4-11 (contiguous with PF0)

    !align 255, 0
PlanetPF2:
    !byte $80, $C0, $E0, $F0 ; rows 0-3
    !byte $F8, $FC, $FE, $FF ; rows 4-7
    !fill 8, $FF            ; rows 8-15

; =============================================================================
; THE SHIP — four two-line rows, eight pixels wide
; =============================================================================
ShipShape:
    !byte $18, $3C, $7E, $DB

; =============================================================================
; THE SKY COLOURS — four blues, indexed by Frame >> 3 & 3
; =============================================================================
SkyColours:
    !byte C_SKY0, C_SKY1, C_SKY2, C_SKY3

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
