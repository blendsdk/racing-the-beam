; =============================================================================
; LESSON 53, EXERCISE 3: Reorder the Bands — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; The exercise drives the band order from a PatternOrder table.  The order is
;
;     ORDER0..3 = 1, 3, 0, 2
;
; so the sampler becomes: playfield first, then the colour ramp, then the
; solid fill, then the sprite strip.  The same four library routines run; only
; their order changed.  The band count and the line budget do not change:
; four 48-line bands = 192.
;
; The order is applied at assembly time.  The four band bodies are macros
; (BandFill, BandPF, BandSprite, BandRamp), a four-way selector macro picks
; one from a slot's order value, and an ACME !for loop walks the four slots.
; That keeps the boundary code exactly as fast as the base lesson: a runtime
; dispatch would add about 25 cycles before every boundary and push each
; band's first WSYNC past its line, so the line counts would have to change.
; The PatternOrder table is also emitted as data; the VBLANK plan loop reads
; it, so the state log reports the order (1, 3, 0, 2) the build used.
;
; Two data details follow from the order:
;   - The first band is the playfield, so its KernelPtr/KernelRows are loaded
;     in VBLANK (Band1Setup) exactly as the base lesson preloads band 2.
;   - The playfield table's last row is blank.  The ramp follows the playfield,
;     and the ramp's first boundary store (COLUBK) must beat pixel 0; clearing
;     PF0 afterwards can be one pixel late, so a blank last row keeps even
;     that pixel invisible.
;
; Checkpoints: the base lesson's checkpoints remain, with Band1Setup in VBLANK.
;   Band3Setup and Band4Setup keep their base-lesson names but report the
;   sprite and ramp slots; PatternStart reports A=1, 3, 0, 2 in the VBLANK
;   plan loop.
;
; Build: acme -f plain -o build/exercise-03.bin \
;        lessons/part7-kernel-mastery/53-kernel-patterns/exercise-03-solution.asm
; Run:   stella build/exercise-03.bin
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

; The build's band order: 1 = playfield, 3 = ramp, 0 = fill, 2 = sprite.
; The PatternOrder table below is emitted from the same four symbols, so the
; build and the VBLANK plan report cannot disagree.
ORDER0         = 1
ORDER1         = 3
ORDER2         = 0
ORDER3         = 2
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
; inlined), so PatternStart is reported here: four hits, A = 1, 3, 0, 2.
    LDX #0
PlanBands:
    LDA PatternOrder,X
PatternStart:               ; checkpoint: A = 1, 3, 0, 2 (the build's order)
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
; 8. PRELOAD THE FIRST BAND'S LIBRARY STATE
; -----------------------------------------------------------------------------
; The order puts the playfield first (ORDER0 = 1).  Its boundary is at
; BodyStart, so the pointer and row count are loaded here, where there is
; plenty of time.  Loading them at the boundary would push the first
; playfield store past the line's WSYNC and make the band a line too long.
    LDA #PF_ROWS
    LDX #<PFTable
    LDY #>PFTable
Band1Setup:                 ; checkpoint: A = KernelRows, X/Y = the PF pointer
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
; 10. CLEAR THE FIRST BAND'S OBJECTS
; -----------------------------------------------------------------------------
; The playfield band writes PF0-PF2; GRP0/GRP1 must be zero from visible line
; 0 and COLUBK is set by the band's own boundary, which runs before pixel 0.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    LDA #C_BG
    STA COLUBK

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines in four 48-line bands, work-first
; =============================================================================
; =============================================================================
; THE BAND BODIES — four macros, one per library routine
; =============================================================================
; Each macro is the base lesson's band boundary: the stores that must beat
; pixel 0 first, then the library call.  A macro (rather than a JSR) keeps
; the boundary's cycle count identical to the base lesson.
!macro BandFill {
    LDA FillColor
    STA COLUBK              ; beat pixel 0 on this band's first line
PatternWrite:               ; checkpoint: A = the fill band's colour
    LDX #BAND_LINES
    JSR KernelFill
}

!macro BandPF {
    LDA PFColor
    STA COLUPF              ; the checkerboard's colour, before pixel 0
    LDA #C_BG
    STA COLUBK              ; the gaps, before pixel 0
    JSR KernelPFRows         ; KernelPtr/KernelRows were set in VBLANK
}

!macro BandSprite {
    LDA #C_BG
    STA COLUBK              ; the dark band, before pixel 0
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA SpriteColor
    STA COLUP0
    LDA #SPRITE_LINES
    LDX #<SpriteStrip
    LDY #>SpriteStrip
Band3Setup:                 ; checkpoint: A = KernelRows, X/Y = the strip pointer
    STA KernelRows
    STX KernelPtr
    STY KernelPtr+1
    JSR KernelSpriteStrip
}

!macro BandRamp {
    LDA RampFirst
    STA COLUBK              ; the ramp's top colour, before pixel 0
    LDA #$00
    STA PF0                 ; the playfield band's last row is blank, so a
    STA PF1                 ; one-pixel-late clear cannot show a sliver
    STA PF2
    STA GRP0
    STA GRP1
    LDA #BAND_LINES
    LDX RampLo
    LDY RampHi
Band4Setup:                 ; checkpoint: A = KernelRows, X/Y = the ramp pointer
    STA KernelRows
    STX KernelPtr
    STY KernelPtr+1
    JSR KernelColorRamp
}

; The four-way selector: slot value -> band body.
!macro BandSlot .n {
    !if .n == 0 { +BandFill }
    !if .n == 1 { +BandPF }
    !if .n == 2 { +BandSprite }
    !if .n == 3 { +BandRamp }
}

BodyStart:                  ; checkpoint: scanline 37, visible line 0
; The loop walks the four slots; each slot's order value selects one band.
; ORDER0..3 is the table; the same values are emitted below as PatternOrder,
; which the VBLANK plan loop reads for the state log.
!for .slot, 0, 3 {
    !if .slot == 0 { +BandSlot ORDER0 }
    !if .slot == 1 { +BandSlot ORDER1 }
    !if .slot == 2 { +BandSlot ORDER2 }
    !if .slot == 3 { +BandSlot ORDER3 }
}
; 1 (playfield) + 3 (ramp) + 0 (fill) + 2 (sprite) = four 48-line bands = 192
; visible lines.  The last WSYNC releases the CPU at scanline 229.

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
; PATTERNORDER — the build's band order, emitted from the ORDER symbols
; =============================================================================
; 0 = fill, 1 = playfield, 2 = sprite strip, 3 = colour ramp.  The VBLANK
; plan loop reads this copy so the state log reports the same order the
; assembly-time !for loop used.
PatternOrder:
    !byte ORDER0, ORDER1, ORDER2, ORDER3

; =============================================================================
; THE PLAYFIELD TABLE — 24 rows x 3 bytes (PF0, PF1, PF2)
; =============================================================================
; Row 0 is blank: it is the band's top margin, and it lets the boundary's late
; first-row stores land without a visible tear.  Rows 1-22 alternate two
; four-pixel checkerboard phases; row 23 is blank so the ramp boundary's
; late PF0 clear cannot show a one-pixel sliver:
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
    !byte $00,$00,$00       ; row 23: blank, so the ramp boundary is safe

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
