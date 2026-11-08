; =============================================================================
; LESSON 77: Interlaced Flicker — Faking More Colours & Resolution
; =============================================================================
; Part 11: Legendary Techniques
;
; What this program does:
;   "the colour mosaic": eight horizontal bands, 24 scanlines each
;   (8 x 24 = 192 visible lines).  Each band is ONE flat colour written to
;   COLUBK at the band's first line.  The whole frame is a single TIA colour
;   register, rewritten eight times.
;
;   THE PICTURE IS DRAWN TWICE.  Palette A and palette B hold eight
;   DIFFERENT colours at the same eight positions, one pair per band.  On one
;   frame the mosaic is palette A; on the next frame it is palette B; then A
;   again.  Each palette is on screen 30 times a second, and the eye
;   integrates the alternation into a third colour per band:
;
;     band 0   red        $4A  +  green        $CA   -> yellow
;     band 1   blue       $8A  +  red          $4A   -> magenta
;     band 2   green      $CA  +  blue         $8A   -> cyan
;     band 3   orange     $2A  +  blue         $8A   -> white-ish
;     band 4   violet     $7A  +  yellow-green $EA   -> pale grey
;     band 5   aqua       $AA  +  pink         $5A   -> pale lavender
;     band 6   peach      $3A  +  teal-green   $BA   -> warm grey
;     band 7   light blue $9A  +  violet       $7A   -> pale blue-violet
;
;   Every byte above sits at luminance level 5 ($xA: hue in the high nibble,
;   level in bits 3-1).  Equal luminance is the design rule: the two frames
;   are at the same TIA luminance level; the composite luma stays close to constant
;   on real hardware, but the rendered brightness still varies with hue, so the
;   alternation is mildly flickery, not perfectly steady
;   of light.  A pair with different levels would flicker in brightness at
;   30 Hz and be much easier to see as flicker.
;
;   THE MECHANISM IS ONE BYTE.  Phase is 0 or 1.  Phase 0 draws palette A,
;   Phase 1 draws palette B.  Phase is advanced once per frame in the
;   vertical blank, before the picture starts, so a frame is never half one
;   palette and half the other: the band boundaries are at exactly the same
;   scanlines in both phases and only the colour bytes differ.  That exact
;   frame sync is what makes the blend clean; a phase change in the middle
;   of the picture would tear the mosaic.
;
;   THE BAND TABLE IS INDEXED Phase*8 + Band.  BandTable is sixteen bytes:
;   palette A then palette B.  The eight bytes the phase selects are copied
;   into the RAM array ActiveBand during VBLANK, and the kernel reads the
;   RAM copy.  Staging is not decoration: the beam reaches pixel 0 at cycle
;   22.67 of a scanline, and the staged read/write pair completes its store
;   at cycle 18.  Indexing the ROM table directly inside the band loop would
;   need Phase*8 + Band recomputed per band and would complete the store at
;   cycle 27 — after the beam has drawn the line's first 13 colour clocks,
;   a seam of the previous band's colour at every boundary.
;
;   THE KERNEL IS ONE LOOP, EIGHT TIMES.  Write COLUBK, hold it for 24
;   scanlines with WSYNC, advance to the next band.  The band is a flat
;   colour, so the TIA needs no more than the one write; the 24 WSYNCs are
;   the whole "graphics" of the row.
;
;   THE AUTO-DEMO exists so that two STILL screenshots can show both
;   phases (a still can only ever show one).  Counting the frames after
;   power-on from 1:
;
;     frames   1-119   the phase alternates every frame  (2 s of flicker)
;     frame  120       Freeze = 1, Phase = 0            (palette A held)
;     frame  240       Phase = 1                        (palette B held)
;     frame  360       Freeze = 0, the cycle restarts
;
;   The demo's own timer counts 120 frames per segment, so the three
;   boundaries are exactly 2 s, 4 s and 6 s after power-on: the phase-A
;   window is frames 120-239 and the phase-B window is frames 240-359.
;
;   SELECT toggles Freeze by hand and switches the auto-demo off: press it
;   once to hold whichever phase is showing, again to resume the flicker.
;   That is how a reader can put palette A and palette B side by side on
;   the same television, one after the other.
;
;   A STILL SHOWS ONE PHASE.  Stella's screenshot key, and any camera,
;   catches a single frame: all eight bands in palette A, or all eight in
;   palette B.  The blended third colour is never in the frame buffer; it
;   happens in the eye, over two frames.  The two committed captures are
;   the same ROM held on each phase, and they differ in every band.
;
;   THE FRAME (NTSC): 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262.
;   Measured schedule (the cycle-accurate model in the lesson text; the
;   convention is the instruction's start line and start cycle, cycle 0
;   being the first instruction after a WSYNC release):
;
;     StartFrame      259/3    the first VSYNC line
;     VblankStart       0/5    the first VBLANK line
;     BodyStart        37/5    visible line 0
;     BandLoop         37/7    the first band's colour load
;     OverscanStart   229/10   the first blanked line; the VBLANK store
;                              completes at 229/15, before pixel 0 at 22.67
;
;   The model reports every frame at exactly 19,912 cycles = 262 lines.
;
;   RAM map (the exact map; +clean_start zeroes every byte):
;     $80 Phase       0 = palette A, 1 = palette B
;     $81 Freeze      1 = hold the current phase (SELECT or the auto-demo)
;     $82 AutoDemo    1 until SELECT is pressed; then 0
;     $83 FrameLo     frame counter low byte, one increment per frame
;     $84 DemoTimer   frames inside the current 2-second demo segment (0..119)
;     $85 PrevSelect  SELECT edge latch: 0 = released, 1 = pressed
;     $86 DemoStep    the segment: 0 alternate, 1 hold A, 2 hold B
;     $87 ActiveBand  8 bytes: the colour of each band, staged this frame
;     $8F-$F7         free (105 bytes)
;     $F8-$FF         the stack (the deepest call is one level: 2 bytes)
;
; Build: acme -f plain -o build/lesson77.bin \
;        lessons/part11-legendary/77-interlaced-flicker/77-interlaced-flicker.asm
; Run:   stella build/lesson77.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK (Lesson 15)
OVERSCAN_TIMER = 36      ; 30-line overscan (Lesson 15)

BAND_COUNT     = 8       ; eight horizontal bands
BAND_LINES     = 24      ; 24 scanlines each
VISIBLE_LINES  = BAND_COUNT * BAND_LINES   ; 192

; The auto-demo's segment length and count (60 frames = 1 s):
DEMO_SEGMENT   = 120     ; 2 s per segment: alternate, hold A, hold B

; --- the palette bytes -------------------------------------------------------
; The TIA colour byte is %HHHHLLL0: hue in bits 7-4, luminance in bits 3-1.
; Every byte below is level 5 ($xA) so a pair is equal in brightness; only the
; hue changes between the two phases.  The hue names are the course's
; named-colour table from Lesson 13; the RGB triples in the lesson text are
; what Stella actually draws for these bytes.
C_RED          = $4A     ; hue 4,  level 5   (226,100, 99)
C_PEACH        = $3A     ; hue 3,  level 5
C_ORANGE       = $2A     ; hue 2,  level 5   (205,155, 62)
C_PINK         = $5A     ; hue 5,  level 5
C_VIOLET       = $7A     ; hue 7,  level 5   (139,100,223)
C_BLUE         = $8A     ; hue 8,  level 5   ( 90,100,224)
C_LIGHT_BLUE   = $9A     ; hue 9,  level 5
C_AQUA         = $AA     ; hue 10, level 5   ( 90,176,212)
C_TEAL         = $BA     ; hue 11, level 5
C_GREEN        = $CA     ; hue 12, level 5   (100,205, 99)
C_YELLOW_GREEN = $EA     ; hue 14, level 5

; The band arithmetic is a build-time assertion, not a comment.
!if BAND_COUNT * BAND_LINES != 192 {
    !error "the eight bands must total 192 visible lines"
}

; =============================================================================
; RAM ALLOCATION ($80-$8E; +clean_start zeroes every byte)
; =============================================================================
Phase        = $80   ; 0 = palette A, 1 = palette B
Freeze       = $81   ; 1 = hold the current phase
AutoDemo     = $82   ; 1 until SELECT is pressed
FrameLo      = $83   ; frame counter, one increment per frame
DemoTimer    = $84   ; frames inside the current demo segment (0..119)
PrevSelect   = $85   ; SELECT edge latch
DemoStep     = $86   ; the auto-demo segment: 0 alternate, 1 hold A, 2 hold B
ActiveBand   = $87   ; 8 bytes: $87-$8E, the colour of each band this frame
;
; $8F-$F7 are free (105 bytes).  The stack lives at $F8-$FF; the deepest call
; is StagePalette, one level, two bytes.

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
    STA ENAM0
    STA ENAM1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA CTRLPF              ; no playfield, no priority, a 1-pixel ball
    STA COLUPF
    STA COLUP0
    STA COLUP1
    STA COLUBK              ; a black screen until the first band write

; --- the first phase and the first staged palette ----------------------------
; Phase starts at 1, but the first frame's vertical blank steps it to 0, so
; the first picture drawn is palette A.  StagePalette copies the eight bytes
; of the selected palette out of the ROM table and into ActiveBand, so the
; first frame already has a full mosaic to draw.
    LDA #$01
    STA Phase
    LDA #$00
    STA Freeze              ; 0: the phase alternates from the first frame
    STA FrameLo
    STA DemoTimer
    STA PrevSelect
    STA DemoStep
    LDA #$01
    STA AutoDemo            ; 1: the frame-120/240/360 clock owns the phase
    JSR StagePalette

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    INC FrameLo

; -----------------------------------------------------------------------------
; 1. SELECT — freeze the phase by hand, and switch the auto-demo off
; -----------------------------------------------------------------------------
; SELECT is SWCHB bit 1, active low.  A NEW press toggles Freeze: from a
; running alternation it holds whichever phase is on screen; from a hold it
; starts the alternation again.  The edge latch (PrevSelect) is what makes it
; one toggle per press instead of one per frame.
    LDA SWCHB
    AND #$02                ; SELECT is active low
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA #$00
    STA AutoDemo            ; the reader owns the phase from now on
    LDA Freeze
    EOR #$01                ; toggle the hold
    STA Freeze
    JMP SelectDone
SelectReleased:
    LDA #$00
    STA PrevSelect
SelectDone:

; -----------------------------------------------------------------------------
; 2. THE AUTO-DEMO — alternate for 2 s, hold A for 2 s, hold B for 2 s, restart
; -----------------------------------------------------------------------------
; DemoTimer counts frames inside one two-second segment (0..119), and
; DemoStep counts which segment is running: 0 = alternate, 1 = hold palette A,
; 2 = hold palette B.  When the timer reaches 120 the segment is over: it
; resets and the next segment's action is applied.  The segment boundaries
; are therefore game frames 120, 240 and 360 — the same numbers a reader can
; watch in Stella as the three labels below.
    LDA AutoDemo
    BEQ DemoDone
    INC DemoTimer
    LDA DemoTimer
    CMP #DEMO_SEGMENT
    BCC DemoDone            ; still inside this segment
    LDA #$00
    STA DemoTimer           ; the next segment starts now
    INC DemoStep
    LDA DemoStep
    CMP #$01
    BNE DemoStep2
    LDA #$01
    STA Freeze              ; segment 1: pin the phase ...
    LDA #$00
    STA Phase               ; ... to palette A
    JMP DemoDone
DemoStep2:
    CMP #$02
    BNE DemoStep3
    LDA #$01
    STA Phase               ; segment 2: palette B (Freeze is already 1)
    JMP DemoDone
DemoStep3:
    LDA #$00
    STA Freeze              ; segment 3: release the hold ...
    STA DemoStep            ; ... and start the cycle again at segment 0
DemoDone:

; -----------------------------------------------------------------------------
; 3. ADVANCE THE PHASE — one step per frame, and only when it is not held
; -----------------------------------------------------------------------------
; This is the whole interlace: Phase 0 -> 1 -> 0 -> 1 ..., one step per
; frame, decided in VBLANK and staged below before the picture starts.  With
; Freeze set the step is skipped and the same palette is drawn again.
    LDA Freeze
    BNE PhaseFixed
    LDA Phase
    EOR #$01
    STA Phase
PhaseFixed:
    JSR StagePalette

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
BodyStart:                  ; checkpoint: scanline 37/5, visible line 0
    LDX #$00                ; start at band 0

; =============================================================================
; VISIBLE LINES 0-191: EIGHT BANDS OF 24 LINES, ONE COLUBK WRITE EACH
; =============================================================================
; The band loop is eight instructions of bookkeeping, one WSYNC per band line
; per band.
; Cycle ledger for the eight instructions that open a band, counted from the
; WSYNC release of the previous band's last line:
;
;   DEY              2     0- 1   the band's last line: Y reaches 0
;   BNE BandLines    2     2- 3   not taken at the end of the band
;   INX              2     4- 5
;   CPX #BAND_COUNT  2     6- 7
;   BNE BandLoop     3     8-10   taken for bands 0-6
;   LDA ActiveBand,X 4    11-14
;   STA COLUBK       3    15-17   completes at cycle 18
;
; The beam reaches pixel 0 at cycle 22.67, so the colour is in place with
; 4.67 cycles (14 colour clocks) to spare.  The first band of the frame is
; even earlier: BodyStart runs at 37/5 directly after the VBLANK store, so
; its LDA starts at cycle 7 and its store completes at cycle 14.
BandLoop:
    LDA ActiveBand,X        ; the colour this phase puts in this band
    STA COLUBK              ; the frame's only graphics register
    LDY #BAND_LINES
BandLines:
    STA WSYNC               ; hold the band for one scanline
    DEY
    BNE BandLines
    INX
    CPX #BAND_COUNT
    BNE BandLoop

; --- the last band has been drawn (visible line 191); the blank starts -------
OverscanStart:              ; checkpoint: scanline 229, the first blanked line
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; STAGEPALETTE — copy the selected palette out of the ROM table into RAM
; =============================================================================
; The table index is Phase*8 + Band: Phase*8 is the palette's first byte
; (0 for A, 8 for B), and the eight stores walk from there to the end of the
; palette.  Y counts the source index, X the destination band.
;
; Why stage at all?  The kernel could index BandTable directly if it
; recomputed Phase*8 + Band per band, but TXA/CLC/ADC/TAY/LDA abs,Y/STA costs
; 16 cycles after the eleven that reach the band's colour load, so the store
; would complete at cycle 27 — 4.33 cycles after the beam has started drawing
; pixel 0 at 22.67, leaving a seam of the previous band's colour at each
; boundary.  Eight bytes of RAM buy the difference.
StagePalette:
    LDA Phase
    ASL                     ; Phase * 2
    ASL                     ; Phase * 4
    ASL                     ; Phase * 8
    TAY                     ; Y = the palette's first table index
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
; THE BAND TABLE — palette A, then palette B (index = Phase*8 + Band)
; =============================================================================
; Each row of the comment above is one BandTable offset in both palettes.
; The two bytes of a pair are equal in luminance and far apart in hue; the eye
; adds them over two frames.  Read the pairs down the columns:
;
;   band  offset  palette A                palette B
;     0     0     red        $4A (hue  4)  green        $CA (hue 12)
;     1     1     blue       $8A (hue  8)  red          $4A (hue  4)
;     2     2     green      $CA (hue 12)  blue         $8A (hue  8)
;     3     3     orange     $2A (hue  2)  blue         $8A (hue  8)
;     4     4     violet     $7A (hue  7)  yellow-green $EA (hue 14)
;     5     5     aqua       $AA (hue 10)  pink         $5A (hue  5)
;     6     6     peach      $3A (hue  3)  teal-green   $BA (hue 11)
;     7     7     light blue $9A (hue  9)  violet       $7A (hue  7)
BandTable:
    ; --- palette A: the even frames ------------------------------------------
    !byte C_RED, C_BLUE, C_GREEN, C_ORANGE
    !byte C_VIOLET, C_AQUA, C_PEACH, C_LIGHT_BLUE
    ; --- palette B: the odd frames -------------------------------------------
    !byte C_GREEN, C_RED, C_BLUE, C_BLUE
    !byte C_YELLOW_GREEN, C_PINK, C_TEAL, C_VIOLET

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
