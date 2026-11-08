; =============================================================================
; LESSON 73 — EXERCISE 1 SOLUTION: A Denser Walk Field and Per-Band Colour
; =============================================================================
; This is the lesson ROM's HMOVE walk with a denser line mask (73 star
; lines instead of 34) and a per-band star colour.  The star band is split
; into five 32-line bands; the group-first line reads the band index from
; MaskIdx: (MaskIdx - 1) >> 2, leaving X (the 0-159 line cursor) intact,
; and loads COLUP0/COLUPF from StarBandColours: white, bright blue, yellow,
; green, orange.  The second strobe is removed;
; this solution keeps the single-strobe walk.  The eight-pixel HMOVE bar is
; on every star-band line.  The frame, the planet band and the ship are
; unchanged; the frame stays 262.
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

SHIP_ROW       = 10      ; the ship's first planet row (4 rows = 8 lines)
SHIP_ROWS      = 4
PLANET_COLOUR  = 6       ; rows 0-5 green, rows 6-15 brown

STAR_START     = 73      ; the table's design point
BALL_START     = 83      ; the ball's design position before line 0


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
; RAM ALLOCATION ($80-$9D; +clean_start zeroes every byte)
; =============================================================================
Frame        = $80   ; frame counter, 8 bits
MaskByte     = $83   ; the current eight-line mask byte
MaskIdx      = $84   ; the current group's mask byte index, 0-19
Groups       = $85   ; groups left in this frame, 20..1
MaskBuf      = $86   ; 24 bytes: 20 star bytes + 4 zero horizon bytes
;
; $9E-$F7 are free (90 bytes).  The stack lives at $F8-$FF; the call depth
; stays at one level (SetCoarseM0, SetCoarseBL and RotateMask).

; =============================================================================
; WALKLINE — one eight-line group's first line, then seven masked lines
; =============================================================================
; The group's first line is always blank (mask bit 0 is zero).  It moves the
; objects with the first HMOVE, reloads the mask byte for the next seven
; lines, consumes bit 0, disables the objects, and loads the next line's
; motion.  The seven bodies test bits 1-7.
;
; The motion is pipelined: A and Y hold this line's HMM0/HMBL bytes, which
; the previous line loaded.  The stores and STA HMOVE are the first work of
; the line, so the HMOVE lands at about cycle 9 (and ~13 on the group-first
; line with its three stores) and the leftmost eight pixels are blanked on
; every line.  At the end of the line the kernel loads the NEXT line's
; bytes into A and Y.
;
; The star line's enable must land before the star's first pixel.  The
; ball is the leftmost object: the table's design walk reaches X=9 on
; line 19 (X=12 with the positioner's +3 bias), pixel cycle 25.7.  The
; capture's visible leftmost is X=9-11 depending on the scroll phase; the
; enable is in time.  The star's own table walk never goes left of X=24.
!macro WalkBody {
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
; loads the next line's motion, and ends the line.  Group 0's line 0 is the
; only caller that does not do the two motion stores, which is why its HMOVE
; lands at ~cycle 8.  X is the walk cursor; the band code must use Y.
!macro GroupFirstBody {
    LDY MaskIdx
    LDA MaskBuf,Y
    STA MaskByte
    INC MaskIdx
    LSR MaskByte            ; consume bit 0 (the ROM table's bit 0 is 0)
    LDA MaskIdx             ; the band index: (group - 1) >> 2
    SEC
    SBC #$01
    LSR
    LSR
    TAY                     ; X is the 0-159 line cursor: do not clobber it
    LDA StarBandColours,Y
    STA COLUP0
    STA COLUPF
    LDA #$00
    STA ENAM0
    STA ENABL
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

; --- start the walk ----------------------------------------------------------
    STA HMM0
    STA HMBL
    STA Frame

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
; X=97-105 (left edge 97).
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
OverscanStart:              ; checkpoint: label 228/3; first blanked line 229
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
; of every byte of the ROM table is zero: the group's first line is blank and carries the
; mask-byte reload.  The other bits are the sparse field; adjacent bits are
; legal because the objects do not need to be re-positioned.  73 star
; lines, up to 292 star pixels.  Bytes 20-23 cover the planet band and
; stay zero: no star below the horizon.  The ROM table's bit 0 is zero in
; every byte, but the ROL can move bit 7 into bit 0; the group-first line
; consumes that bit unconditionally, so a star crossing a byte boundary is
; dropped for one scroll phase (8 frames) (a blink that lasts that phase).
MaskRom:
    !byte $7C, $5C, $46, $40, $9C, $2A, $BE, $26, $4E, $4C, $B8, $EE
    !byte $28, $F6, $64, $7E, $1C, $96, $02, $88
    !byte $00, $00, $00, $00

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
; THE STAR BAND COLOURS — five 32-line bands
; =============================================================================
StarBandColours:
    !byte C_STAR, C_STAR_BALL, $1E, $CE, $2E

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
