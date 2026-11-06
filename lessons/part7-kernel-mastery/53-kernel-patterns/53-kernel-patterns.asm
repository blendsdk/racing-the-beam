; =============================================================================
; LESSON 53: Kernel Design Patterns — The Pattern Sampler — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; What this program does:
;   "the pattern sampler": four 48-line bands, each drawn by one routine from
;   include/kernel_patterns.asm.  The library packages the four kernel shapes
;   the course has built:
;
;     KernelFill         a solid background band        A = colour, X = lines
;     KernelPFRows       a 2-line playfield band        KernelPtr = 3 bytes/row
;     KernelSpriteStrip  a 1-line sprite band           KernelPtr = 1 byte/line
;     KernelColorRamp    a per-line background ramp     KernelPtr = 1 colour/line
;
;   The four bands are 48 lines each = 192:
;     visible 0-47     KernelFill:        solid teal-green ($B8)
;     visible 48-95    KernelPFRows:      24 rows x 2 lines of a checkerboard
;     visible 96-143   KernelSpriteStrip: a dark band with an 8-line diamond
;     visible 144-191  KernelColorRamp:   a red-to-blue gradient
;
;   The band boundary is the lesson's contract.  Each routine writes only its
;   own object, so the boundary clears the objects the next routine does not
;   write and sets the next band's colours.  The order inside a boundary is
;   chosen so the store that affects the first line's left edge completes
;   before the TIA draws pixel 0 (cycle 22.7).
;
;   The library owns $80-$82: KernelPtr ($80/$81) and KernelRows ($82).  The
;   lesson uses $83-$93 for its counters and $A0-$CF for the 48-byte sprite
;   strip.  $94-$9F and $D0-$F7 are free; the stack is $F8-$FF.
;
; Controls:
;   Fire cycles the palette 0 -> 1 -> 2 -> 0 and beeps.  A palette is five
;   bytes: the fill colour, the PF colour, the sprite colour, and the ramp
;   pointer.  SELECT resets to palette 0 and beeps.  The auto-demo advances
;   the palette every 240 frames, so every palette is reachable without a key
;   press.  Palette 1 also reverses the ramp: its gradient runs blue at the
;   top to red at the bottom.
;
;   The sprite band's diamond sweeps 1 -> 40 -> 1, one strip row per frame.
;   The clamp keeps the 8-byte shape inside the 48-byte strip; row 0 is always
;   blank, which is the band's top margin.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;
; The library's cycle ledgers (steady state):
;   KernelFill         11 cycles/line
;   KernelPFRows       57 cycles per row = 28.5/line (95 cycles of margin)
;   KernelSpriteStrip  19 cycles/line
;   KernelColorRamp    19 cycles/line
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), BodyStart (37), OverscanStart (229);
;   PatternStart (A = each band index in the frame's plan: 0, 1, 2, 3);
;   PatternCount (A = 4); PatternWrite (A = the first band's fill colour);
;   Band2Setup (A = KernelRows, X/Y = the PF pointer), Band3Setup and
;   Band4Setup (the same three values for their bands); PaletteRead (A = the
;   palette index); PaletteStep (A = the new palette); SelectReset (A = 0);
;   SpriteRowWrite (A = the diamond's top strip row); HmoveApply (the WSYNC
;   stall), HmoveDone (the store has executed).
;
; Build: acme -f plain -o build/lesson53.bin \
;        lessons/part7-kernel-mastery/53-kernel-patterns/53-kernel-patterns.asm
; Run:   stella build/lesson53.bin     (click the screen to unmute the beep)
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan
POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

BAND_LINES     = 48      ; each of the four bands
BAND_COUNT     = 4       ; the band-count checkpoint
PF_ROWS        = 24      ; KernelPFRows draws two lines per row
SPRITE_LINES   = 48      ; the strip is one byte per line
SPRITE_SHAPE   = 8       ; the diamond is eight bytes tall
SPRITE_MIN     = 1       ; the top strip row (row 0 stays blank)
SPRITE_MAX     = 40      ; row + 8 <= 48, so the shape never leaves the strip
SPRITE_X       = 76      ; the diamond's left edge: centred on the 160-px field

DEMO_PERIOD    = 240     ; frames per palette in the auto-demo
PALETTE_COUNT  = 3       ; palettes 0, 1, 2
BEEP_FRAMES    = 2       ; a two-frame tick
BEEP_PITCH     = $08     ; AUDF 8 on AUDC $0C: a short, bright beep

C_BG           = $02     ; the dark background behind the sprite band

; The band arithmetic is a build-time assertion, not a comment: four 48-line
; bands must fill the 192-line picture exactly.
!if BAND_LINES * BAND_COUNT != 192 {
    !error "the four bands must total 192 visible lines"
}

; =============================================================================
; RAM ALLOCATION ($83-$93; +clean_start zeroes every byte)
; =============================================================================
; The library owns $80-$82 (KernelPtr and KernelRows); this lesson starts at
; $83.  The sprite strip is the 48-byte RAM block at $A0-$CF.
Palette      = $83   ; the current palette, 0..2
PaletteTimer = $84   ; frames left before the auto-demo advances the palette
PrevFire     = $85   ; fire state last frame (1 = pressed)
PrevSelect   = $86   ; SELECT state last frame (1 = pressed)
BeepTimer    = $87   ; frames of beep remaining
BeepPitch    = $88   ; AUDF for the beep
SpriteRow    = $89   ; the diamond's top strip row, 1..40
SpriteDir    = $8A   ; the auto-demo's sweep direction: 0 = up, 1 = down
Startup      = $8B   ; frames left before the fire edge is trusted
FillColor    = $8C   ; the palette's fill colour
PFColor      = $8D   ; the palette's playfield colour
SpriteColor  = $8E   ; the palette's sprite colour
RampLo       = $8F   ; the ramp pointer's low byte
RampHi       = $90   ; the ramp pointer's high byte
RampFirst    = $91   ; the ramp's first colour (the band-4 boundary store)
NewFire      = $92   ; this frame's fire 0 -> 1 edge
Scratch      = $93   ; SELECT's pressed state
;
; $94-$9F are free (12 bytes).  The sprite strip occupies $A0-$CF; $D0-$F7
; are free (40 bytes).  The stack lives at $F8-$FF; the call depth stays at
; one level (SetCoarseP0, AdvancePalette, BeepStart).
SpriteStrip  = $A0   ; 48 bytes: one GRP0 byte per line of the sprite band

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; THE PATTERN LIBRARY
; =============================================================================
; kernel_patterns.asm emits code, so it is sourced after * = $F000 (and after
; include/vcs.asm, whose register names it uses).  It defines the four
; routines and the zero-page control bytes before the lesson's own code, so
; every KernelPtr/KernelRows reference is a zero-page access: an absolute
; access would be one byte and one cycle too long, and the band budgets would
; be wrong.
    !source "include/kernel_patterns.asm"

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

    LDA #$00
    STA Palette             ; power on with palette 0
    LDA #DEMO_PERIOD
    STA PaletteTimer
    LDA #$01
    STA SpriteDir           ; the diamond sweeps down first
    LDA #SPRITE_MIN
    STA SpriteRow
    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #$08
    STA Startup             ; ignore the fire line while the console settles

; --- the TIA's fixed state ---------------------------------------------------
    LDA #C_BG
    STA COLUBK              ; the sprite band's dark background
    LDA #$01
    STA CTRLPF              ; reflect the playfield: the right half mirrors
    LDA #$00
    STA NUSIZ0              ; one 8-pixel copy of P0
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    STA ENAM0
    STA ENAM1
    STA ENABL

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
; The same two-byte beep the rest of Part 6 and Part 7 uses: BeepTimer counts
; down every frame and channel 0 goes silent at zero.
    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0
BeepClockDone:

; -----------------------------------------------------------------------------
; 2. FIRE — advance the palette on the 0 -> 1 edge
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  EOR turns that into a 1, and the
; EOR/AND pair keeps only a new press, so holding the button advances once.
; The first eight frames are not trusted: INPT4 can read low while the console
; settles, so Startup forces the edge clear until it reaches zero.
    LDA INPT4
    AND #$80
    EOR #$80                ; 1 = pressed
    STA NewFire
    EOR PrevFire
    AND NewFire
    STA NewFire             ; NewFire = pressed & ~wasPressed
    LDA Startup
    BEQ FireEdgeReady
    DEC Startup
    LDA #$00
    STA NewFire
FireEdgeReady:
    LDA NewFire
    BEQ NoFireEdge
    JSR AdvancePalette
    LDA #DEMO_PERIOD        ; a manual change restarts the auto-demo window
    STA PaletteTimer
    JSR BeepStart
NoFireEdge:
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire

; -----------------------------------------------------------------------------
; 3. SELECT — reset to palette 0
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  The edge, not the level, resets the
; palette.  SELECT is also the capture helper: a capture can start from
; palette 0 without waiting for the auto-demo.
    LDA SWCHB
    AND #$02
    EOR #$02                ; 1 = pressed
    STA Scratch
    EOR PrevSelect
    AND Scratch
    BEQ NoSelectEdge
    LDA #$00
SelectReset:                ; checkpoint: A = 0, the new palette
    STA Palette
    LDA #DEMO_PERIOD
    STA PaletteTimer
    JSR BeepStart
NoSelectEdge:
    LDA Scratch
    STA PrevSelect

; -----------------------------------------------------------------------------
; 4. THE AUTO-DEMO'S PALETTE CLOCK — one palette every 240 frames
; -----------------------------------------------------------------------------
    DEC PaletteTimer
    BNE NoAutoPalette
    JSR AdvancePalette
    LDA #DEMO_PERIOD
    STA PaletteTimer
NoAutoPalette:

; -----------------------------------------------------------------------------
; 5. THE PALETTE TABLE AND THE FRAME'S BAND PLAN
; -----------------------------------------------------------------------------
; The palette table is five bytes per entry: fill, PF, sprite, ramp low, ramp
; high.  The index math is 5 * Palette = 4 * Palette + Palette.
    LDA #BAND_COUNT
PatternCount:               ; checkpoint: A = 4
    NOP
    LDA Palette
PaletteRead:                ; checkpoint: A = the palette index (0..2)
    ASL
    ASL
    CLC
    ADC Palette             ; A = 5 * Palette
    TAX
    LDA PaletteTable+0,X
    STA FillColor
    LDA PaletteTable+1,X
    STA PFColor
    LDA PaletteTable+2,X
    STA SpriteColor
    LDA PaletteTable+3,X
    STA RampLo
    LDA PaletteTable+4,X
    STA RampHi

; The band-4 boundary needs the ramp's first colour before the TIA draws the
; band's first pixel.  Compute it here, where there is time, and store it.
    LDY #0
    LDA (RampLo),Y
    STA RampFirst

; The frame's band plan.  The visible kernel's boundaries cannot spare the
; seventeen cycles of a debug call (that is why the four band bodies are
; inlined), so PatternStart is reported here: four hits, A = 0, 1, 2, 3.
    LDX #0
PlanBands:
    TXA
PatternStart:               ; checkpoint: A = each band index in the plan
    NOP
    INX
    CPX #BAND_COUNT
    BNE PlanBands

; -----------------------------------------------------------------------------
; 6. THE SPRITE'S ROW — 1..40, bouncing one strip row per frame
; -----------------------------------------------------------------------------
    LDA SpriteDir
    BNE SpriteDown
    LDA SpriteRow
    CMP #SPRITE_MIN
    BEQ SpriteFlipDown
    DEC SpriteRow
    JMP SpriteRowDone
SpriteDown:
    LDA SpriteRow
    CMP #SPRITE_MAX
    BEQ SpriteFlipUp
    INC SpriteRow
    JMP SpriteRowDone
SpriteFlipDown:
    LDA #$01
    STA SpriteDir
    INC SpriteRow
    JMP SpriteRowDone
SpriteFlipUp:
    LDA #$00
    STA SpriteDir
    DEC SpriteRow
SpriteRowDone:

; -----------------------------------------------------------------------------
; 7. REBUILD THE SPRITE STRIP — clear 48 bytes, then stamp the 8-byte shape
; -----------------------------------------------------------------------------
; The strip lives in RAM and is rebuilt every frame: clearing it makes the
; diamond's old row disappear, so the picture can move without erasing a
; previous position.  The stamp starts at SpriteRow (1..40), so the shape's
; last byte is at index 47 at most.  X is the strip index; Y walks the shape.
    LDA #$00
    LDX #SPRITE_LINES
ClearStrip:
    DEX
    STA SpriteStrip,X
    BNE ClearStrip

    LDA SpriteRow
SpriteRowWrite:             ; checkpoint: A = the diamond's top strip row
    TAX
    LDY #0
StampShape:
    LDA SpriteShape,Y
    STA SpriteStrip,X       ; zero-page,X: $A0-$CF
    INX
    INY
    CPY #SPRITE_SHAPE
    BNE StampShape

; -----------------------------------------------------------------------------
; 8. PRELOAD BAND 2'S LIBRARY STATE
; -----------------------------------------------------------------------------
; KernelFill (band 1) never touches KernelPtr or KernelRows, so the values for
; band 2 can be loaded here, where there is plenty of time.  Loading them at
; the band-2 boundary would push the first WSYNC past the line and make the band a line too long.
    LDA #PF_ROWS
    LDX #<PFTable
    LDY #>PFTable
Band2Setup:                 ; checkpoint: A = KernelRows, X/Y = the PF pointer
    STA KernelRows
    STX KernelPtr
    STY KernelPtr+1

; -----------------------------------------------------------------------------
; 9. POSITION P0 FOR THE SPRITE BAND, THEN STROBE ONE HMOVE
; -----------------------------------------------------------------------------
; The diamond is the only player object in the frame.  SetCoarseP0 has set
; HMP0 and strobed RESP0; one WSYNC starts a fresh line and one HMOVE applies
; the fine offset in its HBLANK.  The HMOVE is inside VBLANK, so its left-edge
; blanking is invisible.
    LDA #(SPRITE_X + POS_BIAS)
    JSR SetCoarseP0
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA WSYNC
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed
    NOP                     ; keep HmoveDone distinct from the timer poll

; -----------------------------------------------------------------------------
; 10. PRELOAD BAND 1 — its colour is latched before the picture turns on
; -----------------------------------------------------------------------------
    LDA FillColor
    STA COLUBK              ; band 1's solid colour from visible line 0
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines in four 48-line bands, work-first
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0

; =============================================================================
; BAND 1 — KernelFill: 48 solid lines (visible 0-47)
; =============================================================================
; The colour was preloaded in VBLANK, so the boundary's only job is to pass
; the colour and the line count.  PatternWrite reports the fill colour.
    LDA FillColor
PatternWrite:               ; checkpoint: A = the first band's fill colour
    LDX #BAND_LINES
    JSR KernelFill

; =============================================================================
; BAND 2 — KernelPFRows: 24 rows x 2 lines (visible 48-95)
; =============================================================================
; KernelFill's last WSYNC releases the CPU at scanline 85 (visible line 48).
; The background store (COLUBK) must beat pixel 0, and the playfield colour
; should be ready before the first pattern row; both are stored here, and both
; complete before cycle 22.7.  PF0-PF2 and GRP0/GRP1 are already zero (band 1
; wrote only COLUBK), so a redundant clear is skipped: it would push the
; routine's first WSYNC past the end of the line and lengthen the band by one
; scanline.  Row 0 of the table is blank, so the boundary's own late first-row
; stores land on a blank line.
    LDA PFColor
    STA COLUPF              ; the checkerboard's colour
    LDA #C_BG
    STA COLUBK              ; the gaps show the background
    JSR KernelPFRows

; =============================================================================
; BAND 3 — KernelSpriteStrip: 48 lines (visible 96-143)
; =============================================================================
; KernelPFRows' last WSYNC releases the CPU at scanline 133 (visible line 96).
; Band 2 leaves the playfield dirty, so the PF clear comes first: PF0's field
; starts at pixel 0, PF1's at pixel 16, PF2's at pixel 48.  GRP0/GRP1 are
; still zero because band 2 never wrote them.  The strip's row 0 is zero, so
; the band's first line is blank by construction.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA SpriteColor
    STA COLUP0              ; the diamond's colour
    LDA #C_BG
    STA COLUBK              ; the band stays dark around the diamond
    LDA #SPRITE_LINES
    LDX #<SpriteStrip
    LDY #>SpriteStrip
Band3Setup:                 ; checkpoint: A = KernelRows, X/Y = the strip pointer
    STA KernelRows
    STX KernelPtr
    STY KernelPtr+1
    JSR KernelSpriteStrip

; =============================================================================
; BAND 4 — KernelColorRamp: 48 lines (visible 144-191)
; =============================================================================
; KernelSpriteStrip's last WSYNC releases the CPU at scanline 181 (visible
; line 144).  The ramp's first colour is the store that must beat pixel 0, so
; it goes first.  Band 3 leaves GRP0 dirty (its last strip row may hold shape
; bytes); clear it, but leave PF0-PF2 alone: band 3's boundary already
; cleared them and its routine writes only GRP0.  GRP1 is cleared too:
; nothing ever writes it, but the pair costs only six cycles and keeps the
; boundary symmetric.
    LDA RampFirst
    STA COLUBK              ; the ramp's top colour, before pixel 0
    LDA #$00
    STA GRP0                ; the diamond must not leak into the ramp
    STA GRP1
    LDA #BAND_LINES
    LDX RampLo
    LDY RampHi
Band4Setup:                 ; checkpoint: A = KernelRows, X/Y = the ramp pointer
    STA KernelRows
    STX KernelPtr
    STY KernelPtr+1
    JSR KernelColorRamp
; 48 lines x 1 colour = visible 144-191.  The last WSYNC releases the CPU at
; scanline 229, the first overscan line.

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; AdvancePalette — the next palette, wrapping 2 -> 0
; =============================================================================
; A is the new palette when the routine returns.  PaletteStep is after the
; store, so a breakpoint there reports the value the rest of the frame uses.
AdvancePalette:
    LDA Palette
    CLC
    ADC #$01
    CMP #PALETTE_COUNT
    BCC AdvanceStore
    LDA #$00
AdvanceStore:
    STA Palette
PaletteStep:                ; checkpoint: A = the new palette
    RTS

; =============================================================================
; SetCoarseP0 — the Lesson 26 divide-by-15 positioning dance
; =============================================================================
; A = the desired left edge + POS_BIAS.  The first WSYNC starts a fresh line;
; each iteration of the loop is 5 cycles = 15 colour clocks, which is why
; dividing by 15 works.  The remainder becomes HMP0's fine value and RESP0
; strobes the coarse position.  The caller's HMOVE applies the fine offset.
SetCoarseP0:
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
; THE PALETTE TABLE — five bytes per palette
; =============================================================================
;   0 fill colour
;   1 playfield colour
;   2 sprite colour
;   3 ramp pointer low
;   4 ramp pointer high
;
; Palette 0 is the sampler's default: teal-green, gold, white, red-to-blue.
; Palette 1 changes every colour and reverses the ramp.  Palette 2 returns the
; ramp to red-to-blue and changes the colours again.
PaletteTable:
    !byte $B8, $1A, $0E, <RampFwd, >RampFwd
    !byte $84, $C8, $1A, <RampRev, >RampRev
    !byte $42, $0E, $C8, <RampFwd, >RampFwd

; =============================================================================
; THE PLAYFIELD TABLE — 24 rows x 3 bytes (PF0, PF1, PF2)
; =============================================================================
; Row 0 is blank: it is the band's top margin, and it lets the boundary's late
; first-row stores land without a visible tear.  Rows 1-23 alternate two
; four-pixel checkerboard phases:
;
;   A: chunks 0,2 / 6,8,10 / 12,14,16,18
;   B: chunks 1,3 / 5,7,9,11 / 13,15,17,19
;
; Chunk 4 is dark in both phases on purpose.  Its field starts at pixel 16
; (cycle 28), one cycle after PF1's store completes at cycle 27, so a bit that
; changed there would be a one-cycle race; keeping it constant makes the late
; store safe.  CTRLPF=$01 reflects the left half, so the right half mirrors
; this pattern.
;
; The table is page-aligned: KernelPtr advances 0,3,6,...,69, so the low byte
; never carries and (KernelPtr),Y never crosses a page.
    !align 255, 0
PFTable:
    !byte $00,$00,$00       ; row 0: the boundary line stays blank
    !byte $50,$2A,$55       ; row  1: chunks 0,2 / 6,8,10 / 12,14,16,18
    !byte $A0,$55,$AA       ; row  2: chunks 1,3 / 5,7,9,11 / 13,15,17,19
    !byte $50,$2A,$55       ; row  3
    !byte $A0,$55,$AA       ; row  4
    !byte $50,$2A,$55       ; row  5
    !byte $A0,$55,$AA       ; row  6
    !byte $50,$2A,$55       ; row  7
    !byte $A0,$55,$AA       ; row  8
    !byte $50,$2A,$55       ; row  9
    !byte $A0,$55,$AA       ; row 10
    !byte $50,$2A,$55       ; row 11
    !byte $A0,$55,$AA       ; row 12
    !byte $50,$2A,$55       ; row 13
    !byte $A0,$55,$AA       ; row 14
    !byte $50,$2A,$55       ; row 15
    !byte $A0,$55,$AA       ; row 16
    !byte $50,$2A,$55       ; row 17
    !byte $A0,$55,$AA       ; row 18
    !byte $50,$2A,$55       ; row 19
    !byte $A0,$55,$AA       ; row 20
    !byte $50,$2A,$55       ; row 21
    !byte $A0,$55,$AA       ; row 22
    !byte $50,$2A,$55       ; row 23

; =============================================================================
; THE SPRITE SHAPE — eight bytes, one per scanline
; =============================================================================
; A diamond two, four, six and eight pixels wide, then narrowing again.  The
; stamp copies these bytes into the 48-byte strip in VBLANK.
SpriteShape:
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18

; =============================================================================
; THE COLOUR RAMPS — 48 entries, stored twice
; =============================================================================
; Six 8-line steps: red $46, pink $56, light violet $66, violet $76, blue $86,
; deeper blue $84.  The second copy is not decoration: a 48-line window that
; starts at offset 24 (the phase exercise) must stay contiguous, so the ramp
; is stored twice and `RampFwd`/`RampRev` + 24 is still a valid 48-byte window.
RampFwd:
    !fill 8, $46            ; visible 0-7 of the ramp: red
    !fill 8, $56            ; pink
    !fill 8, $66            ; light violet
    !fill 8, $76            ; violet
    !fill 8, $86            ; blue
    !fill 8, $84            ; deeper blue
    !fill 8, $46            ; the second copy starts here
    !fill 8, $56
    !fill 8, $66
    !fill 8, $76
    !fill 8, $86
    !fill 8, $84

RampRev:
    !fill 8, $84            ; blue at the top
    !fill 8, $86
    !fill 8, $76
    !fill 8, $66
    !fill 8, $56
    !fill 8, $46            ; red at the bottom
    !fill 8, $84            ; the second copy
    !fill 8, $86
    !fill 8, $76
    !fill 8, $66
    !fill 8, $56
    !fill 8, $46

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
