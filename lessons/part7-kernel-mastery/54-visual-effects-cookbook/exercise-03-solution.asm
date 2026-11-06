; =============================================================================
; LESSON 54, EXERCISE 3: The Ball Centre Line — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; The exercise adds a one-pixel centre line to the road effect, drawn with
; the ball at CenterLine.  Two hardware facts shape the solution:
;
;   1. The ball and the playfield share COLUPF.  A ball pixel over a lit
;      playfield chunk is therefore the same colour as the chunk and
;      invisible.  The road kernel clears PF2 bit 7 (chunk 19, and its
;      mirror chunk 20) so an 8-pixel centre gap shows the background, and
;      the ball line sits in that gap.
;
;   2. The reflected playfield cannot move its centre, so the line cannot
;      follow a lateral road curve.  It follows the width pulse instead:
;      CenterLine = 80 + PulseAmt, so the line drifts 0-2 pixels with the
;      road's breathing while the road itself stays centred.
;
; The ball is enabled for the whole road effect (ENABL=$02 in the road
; setup).  P0 has priority over the ball, so the car covers the line at the
; bottom.  The starfield still uses the ball as its leftmost one-pixel star.
;
; The only kernel change is the AND #$7F before the PF2 store (two
; cycles); the road's worst line measures 49 cycles, under the 76-cycle
; budget.
;
; What this program does:
;   "the effects reel": three full-screen effects, one per 192-line frame.
;
;     Effect 0 — the starfield.  Three page-aligned 256-byte star planes
;       (StarPF0/1/2).  Every visible line reads one byte from each plane at
;       the same world row (StarScroll + the visible row), so scrolling is
;       just incrementing StarScroll every two frames.  P0 draws a 16-line
;       ship at the bottom, and the ball and the two missiles add three
;       one-pixel stars at fixed rows.  The star colour alternates white $0E
;       and gold $1A every 32 frames (Twinkle).
;
;     Effect 1 — the rainbow.  A 192-entry COLUBK ramp (16 hues x 12 lines,
;       stored with a 64-byte repeat so a shifted 192-line window is always
;       contiguous) is written one line per line.  A centred playfield sun
;       block covers visible rows 40-88 (PF2=$F0 -> 32 pixels after the
;       reflection), and a black horizon covers rows 160-191 (all three PF
;       bytes $FF, so the band is full width).
;       RainbowShift advances the window one entry every four frames.
;
;     Effect 2 — the pseudo-3D road.  One page-aligned 192-byte playfield
;       plane (RoadPF2) holds a centred road whose base half-width grows
;       from 2 to 6 chunks (4 to 12 chunks wide) from the horizon to the
;       bottom.  A 64-entry width pulse (WidthIndex) adds up to two chunks
;       per half, so the widest bottom rows are the full 16 chunks wide.  P0
;       draws a 16-line car at the bottom.  The playfield is reflected
;       (CTRLPF=$01), so the road is symmetric about the screen centre and
;       cannot move sideways; the "3D" is the width profile.
;
;   EffectTimer 240: at zero the effect advances 0 -> 1 -> 2 -> 0 and the
;   timer reloads.  Fire advances immediately; SELECT returns to effect 0.
;   The auto-demo cycles every 240 frames, so every effect is reachable
;   without a key press.  A two-byte beep (BeepTimer/BeepPitch) sounds on
;   both manual changes.
;
;   All three animation clocks run every frame, whichever effect is on
;   screen, so a return to an effect finds it where it would have been.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;
; The kernels (work-first, one line per row, forward top-down):
;
;   Starfield   writes PF0/PF1/PF2 from the three planes at the same X,
;               then one 192-byte enable table per one-pixel star.  The
;               ship's GRP0 is written only in the bottom 16-row loop.  The
;               measured ledger is 54 cycles on a plain or star row and 62
;               on a ship row.  The enable stores complete at cycles
;               37/44/51 (before X=112/128/144 at 60/65/71), and the ship
;               store completes at cycle 39 (before X=76 at 48).
;
;   Rainbow     LDA (RampLo),Y / STA COLUBK / WSYNC / INY / CPY / BNE =
;               18 cycles per line.  The sun-start, sun-end and horizon
;               boundary lines cost 27, 22 and 33 cycles; all are inside 76.
;
;   Road        PF2 with up to two widening shifts of the 64-entry pulse,
;               then the car in a 16-row bottom loop, WSYNC and the tail.
;               The measured ledger is 28/37/41 cycles (pulse 0/1/2) on a
;               plain line and 36/45/49 on a car line.
;
;   Every plane is page-aligned: the star X wraps 255 -> 0 inside its page;
;   the road/rainbow indices stay inside a page because their windows are
;   at most 192 + 63 = 255 entries long, and the enable tables are
;   192 bytes each on their own page.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), BodyStart (37), OverscanStart (229);
;   EffectRead (A = 0/1/2); EffectTimerRead (A = 240 down to 0);
;   StarScrollRead, RoadScrollRead, WidthIndexRead, RainbowShiftRead (A =
;   the counter); TwinkleStep (A = the new 0/1 flag); StarRow (Y =
;   0..175); StarShipRow (Y = 176..191); RoadRow (Y = 0..175);
;   RoadCarRow (Y = 176..191); RainbowRowA (Y = the row); StarBallWrite/
;   StarM0Write/StarM1Write and ShipWrite (the object writes are latched);
;   HmoveApply (the WSYNC stall), HmoveDone (the store has executed).
;
; RAM map (+clean_start zeroes every byte):
;   $80 Effect        the current effect, 0..2
;   $81 EffectTimer   frames left before the auto-demo advances
;   $82 PrevFire      fire state last frame (1 = pressed)
;   $83 PrevSelect    SELECT state last frame (1 = pressed)
;   $84 BeepTimer     frames of beep remaining
;   $85 BeepPitch     AUDF for the beep
;   $86 Startup       frames left before the fire edge is trusted
;   $87 NewFire       this frame's fire 0 -> 1 edge
;   $88 Scratch       SELECT's pressed state
;   $89 StarScroll    the star world row at the top, 0..255
;   $8A StarTimer     the two-frame star scroll divider
;   $8B Twinkle       0 = white stars, 1 = gold stars
;   $8C TwinkleTimer  frames left before the star colour flips
;   $8D RainbowShift  the ramp window's first entry, 0..63
;   $8E RainbowTimer  frames left before the ramp shifts
;   $8F RoadScroll    the road's animation clock, 0..255
;   $90 WidthIndex    the pulse-table index, 0..63
;   $91 PulseAmt      the pulse shift count, 0..2
;   $92 RampLo        the rainbow window's low byte
;   $93 RampHi        the rainbow window's high byte
;   $94 StarColor     COLUPF for the stars: $0E or $1A
;   $95 PFTemp        the road's unshifted PF2 byte
;   $97-$F7 free (97 bytes)
;   $F8-$FF stack
;
; Build: acme -f plain -o build/exercise-03.bin \
;        lessons/part7-kernel-mastery/54-visual-effects-cookbook/exercise-03-solution.asm
; Run:   stella build/exercise-03.bin     (click the screen to unmute the beep)
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

SCREEN_LINES   = 192     ; every kernel draws 192 lines
EFFECT_STAR    = 0
EFFECT_RAINBOW = 1
EFFECT_ROAD    = 2
EFFECT_COUNT   = 3
EFFECT_PERIOD  = 240     ; frames per effect in the auto-demo

SHIP_TOP       = 176     ; the ship's first visible row
SHIP_LINES     = 16      ; 16 bytes, one line per byte
SHIP_X         = 76      ; the ship's left edge: the centre of the field

STAR0_ROW      = 32      ; the ball's one-pixel star
STAR1_ROW      = 96      ; missile 0's star
STAR2_ROW      = 160     ; missile 1's star
STAR0_X        = 112     ; all three sit right of the late enable store
STAR1_X        = 128
STAR2_X        = 144

SUN_TOP        = 40      ; the sun block's first row
SUN_BOTTOM     = 89      ; exclusive: rows 40..88
HORIZON_TOP    = 160     ; the black horizon's first row
SUN_PF         = $F0     ; PF2 chunks 16-19: 32 pixels after reflection
HORIZON_PF     = $FF     ; all three PF bytes: the full screen width

CAR_TOP        = 176     ; the car's first visible row
CAR_LINES      = 16
CAR_X          = 76
WIDTH_STEPS    = 64      ; the width-pulse table's length

TWINKLE_PERIOD = 32      ; frames per star colour
RAINBOW_PERIOD = 4       ; frames per rainbow step

C_BG           = $02     ; the space/field background
C_STAR_WHITE   = $0E
C_STAR_GOLD    = $1A
C_SHIP         = $0E     ; the ship and the car are white
C_ROAD         = $0C     ; the road surface: light grey
C_SUN          = $1A     ; the sun block: gold
C_BLACK        = $00     ; the horizon

BEEP_FRAMES    = 2       ; a two-frame tick
BEEP_PITCH     = $08     ; AUDF 8 on AUDC $0C: a short, bright beep

; The region arithmetic is a build-time assertion, not a comment.
!if SUN_TOP >= SUN_BOTTOM {
    !error "the sun block must have at least one row"
}
!if SUN_BOTTOM >= HORIZON_TOP {
    !error "the sun must end before the horizon starts"
}
!if HORIZON_TOP >= SCREEN_LINES {
    !error "the horizon must start inside the picture"
}
!if SHIP_TOP + SHIP_LINES > SCREEN_LINES {
    !error "the ship must fit inside the picture"
}
!if CAR_TOP + CAR_LINES > SCREEN_LINES {
    !error "the car must fit inside the picture"
}

; =============================================================================
; RAM ALLOCATION ($80-$95; +clean_start zeroes every byte)
; =============================================================================
Effect        = $80   ; the current effect, 0..2
EffectTimer   = $81   ; frames left before the auto-demo advances
PrevFire      = $82   ; fire state last frame (1 = pressed)
PrevSelect    = $83   ; SELECT state last frame (1 = pressed)
BeepTimer     = $84   ; frames of beep remaining
BeepPitch     = $85   ; AUDF for the beep
Startup       = $86   ; frames left before the fire edge is trusted
NewFire       = $87   ; this frame's fire 0 -> 1 edge
Scratch       = $88   ; SELECT's pressed state
StarScroll    = $89   ; the star world row at the top, 0..255
StarTimer     = $8A   ; the two-frame star scroll divider
Twinkle       = $8B   ; 0 = white stars, 1 = gold stars
TwinkleTimer  = $8C   ; frames left before the star colour flips
RainbowShift  = $8D   ; the ramp window's first entry, 0..63
RainbowTimer  = $8E   ; frames left before the ramp shifts
RoadScroll    = $8F   ; the road's animation clock, 0..255
WidthIndex    = $90   ; the pulse-table index, 0..63
PulseAmt      = $91   ; the pulse shift count, 0..2
RampLo        = $92   ; the rainbow window's low byte
RampHi        = $93   ; the rainbow window's high byte
StarColor     = $94   ; COLUPF for the stars: $0E or $1A
PFTemp        = $95   ; the road's unshifted PF2 byte
CenterLine    = $96   ; the ball line's left edge: 80 + the pulse amount
;
; $97-$F7 are free (97 bytes).  The stack lives at $F8-$FF; the call depth
; stays at one level (SetCoarseP0/BL/M0/M1, AdvanceEffect, BeepStart).

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
    STA SWACNT              ; port A is an input port (the joystick/fire)

    LDA #EFFECT_STAR
    STA Effect              ; power on with the starfield
    LDA #EFFECT_PERIOD
    STA EffectTimer
    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #$08
    STA Startup             ; ignore the fire line while the console settles
    LDA #TWINKLE_PERIOD
    STA TwinkleTimer
    LDA #RAINBOW_PERIOD
    STA RainbowTimer

    LDA #$00
    STA StarScroll
    STA StarTimer
    STA Twinkle
    STA RainbowShift
    STA RoadScroll
    STA WidthIndex
    STA PulseAmt
    LDA #C_STAR_WHITE
    STA StarColor           ; the first 32 frames are white
    LDA #80
    STA CenterLine          ; the line starts on the road's centre

; --- the TIA's fixed state ---------------------------------------------------
    LDA #C_BG
    STA COLUBK              ; space is dark
    LDA #$01
    STA CTRLPF              ; reflect: the right half mirrors the left
    LDA #C_SHIP
    STA COLUP0              ; the ship and the car are white
    LDA #$00
    STA NUSIZ0              ; one 8-pixel P0; the missiles are 1 pixel
    STA NUSIZ1
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
; 2. FIRE — advance the effect on the 0 -> 1 edge
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
    JSR AdvanceEffect
    LDA #EFFECT_PERIOD      ; a manual change restarts the auto-demo window
    STA EffectTimer
    JSR BeepStart
NoFireEdge:
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire

; -----------------------------------------------------------------------------
; 3. SELECT — return to the starfield
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  The edge, not the level, resets the
; effect.  SELECT is also the capture helper: a capture can start from effect
; 0 without waiting for the auto-demo.
    LDA SWCHB
    AND #$02
    EOR #$02                ; 1 = pressed
    STA Scratch
    EOR PrevSelect
    AND Scratch
    BEQ NoSelectEdge
    LDA #EFFECT_STAR
SelectReset:                ; checkpoint: A = 0, the new effect
    STA Effect
    LDA #EFFECT_PERIOD
    STA EffectTimer
    JSR BeepStart
NoSelectEdge:
    LDA Scratch
    STA PrevSelect

; -----------------------------------------------------------------------------
; 4. THE AUTO-DEMO'S EFFECT CLOCK — one effect every 240 frames
; -----------------------------------------------------------------------------
    DEC EffectTimer
    BNE NoAutoEffect
    JSR AdvanceEffect
    LDA #EFFECT_PERIOD
    STA EffectTimer
NoAutoEffect:
    LDA EffectTimer
EffectTimerRead:            ; checkpoint: A = 240 down to 0
    NOP

; -----------------------------------------------------------------------------
; 5. THE ANIMATION CLOCKS — all three run every frame
; -----------------------------------------------------------------------------
; Each effect keeps its own state, so switching away and back does not reset
; the motion.  The clocks are cheap and the VBLANK has room for all of them.
    INC StarTimer
    LDA StarTimer
    AND #$01
    BNE NoStarStep
    INC StarScroll
NoStarStep:
    LDA StarScroll
StarScrollRead:             ; checkpoint: A = the star world row
    NOP

    DEC TwinkleTimer
    BNE NoTwinkle
    LDA #TWINKLE_PERIOD
    STA TwinkleTimer
    LDA Twinkle
    EOR #$01
    STA Twinkle
    TAX
    LDA TwinkleColors,X
    STA StarColor
    TXA
TwinkleStep:                ; checkpoint: A = the new 0/1 flag
    NOP
NoTwinkle:

    DEC RainbowTimer
    BNE NoRainbowStep
    LDA #RAINBOW_PERIOD
    STA RainbowTimer
    INC RainbowShift
    LDA RainbowShift
    AND #$3F
    STA RainbowShift
NoRainbowStep:
    LDA RainbowShift
RainbowShiftRead:           ; checkpoint: A = the ramp window's first entry
    NOP

    INC RoadScroll
    LDA RoadScroll
    LSR                     ; one pulse step every two frames
    AND #WIDTH_STEPS - 1
    STA WidthIndex
    TAX
    LDA PulseTable,X
    STA PulseAmt
    LDA WidthIndex
WidthIndexRead:             ; checkpoint: A = the pulse-table index, 0..63
    NOP
    LDA #80
    CLC
    ADC PulseAmt            ; the line follows the road's width pulse
    STA CenterLine
    LDA CenterLine
CenterLineRead:             ; checkpoint: A = 80, 81 or 82
    NOP
    LDA RoadScroll
RoadScrollRead:             ; checkpoint: A = the road's animation clock
    NOP

; -----------------------------------------------------------------------------
; 6. DISPATCH — one setup path per effect
; -----------------------------------------------------------------------------
; Every path ends with its own +wait_timer / VBLANK-off / kernel entry, so
; the VBLANK-off store completes at cycle 5 of scanline 37; the first data stores follow at cycle 9 (star) or 7 (road).  GRP0
; is cleared here every frame: the ship and the car write only the bottom 16
; rows, so without this clear the last byte would show at the top of the
; next frame as a thin vertical line.
    LDA #$00
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL
    LDA Effect
EffectRead:                 ; checkpoint: A = the current effect, 0/1/2
    CMP #EFFECT_RAINBOW
    BEQ SetupRainbow
    CMP #EFFECT_ROAD
    BEQ SetupRoad

; --- effect 0: the starfield -------------------------------------------------
SetupStar:
    LDA #C_BG
    STA COLUBK
    LDA StarColor
    STA COLUPF              ; the playfield stars and the ball
    STA COLUP1              ; missile 1's one-pixel star
    LDA #C_SHIP
    STA COLUP0              ; the ship and missile 0's star are white
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    ; One HMOVE applies every object's fine offset.  The four coarse resets
    ; come first; the ship and the three one-pixel stars are positioned here.
    LDA #(SHIP_X + POS_BIAS)
    JSR SetCoarseP0
    LDA #(STAR0_X + POS_BIAS)
    JSR SetCoarseBL
    LDA #(STAR1_X + POS_BIAS)
    JSR SetCoarseM0
    LDA #(STAR2_X + POS_BIAS)
    JSR SetCoarseM1
    JMP DoHmove

; --- effect 2: the road ------------------------------------------------------
SetupRoad:
    LDA #C_BG
    STA COLUBK
    LDA #C_ROAD
    STA COLUPF              ; the road surface is light grey
    LDA #C_SHIP
    STA COLUP0
    LDA #$00
    STA PF0                 ; the road never lights PF0
    STA PF1                 ; or PF1: both planes are zero on every row
    STA PF2
    ; Preload the first row's PF2.  The kernel stores PF2 first, so its
    ; first store also beats chunk 12; the preload keeps the very first
    ; line unambiguous and gives the setup a single path for the pulse.
    LDA RoadPF2
    STA PFTemp
    LDX PulseAmt
    BEQ RoadPreloadDone
    LSR
    ORA PFTemp
    DEX
    BEQ RoadPreloadDone
    LSR
    ORA PFTemp
RoadPreloadDone:
    AND #$7F                ; the same centre gap as the kernel store
    STA PF2
    LDA #(CAR_X + POS_BIAS)
    JSR SetCoarseP0
    ; The centre line: one ball, positioned at CenterLine and enabled for
    ; the whole effect.  P0 has priority, so the car covers it at the bottom.
    LDA CenterLine
    CLC
    ADC #POS_BIAS
    JSR SetCoarseBL
    LDA #$02
    STA ENABL
    JMP DoHmove

; --- effect 1: the rainbow ---------------------------------------------------
; No player objects are used, so there is no HMOVE in this effect.  The sun
; and the horizon are playfield blocks, which is why they cost no sprite.
SetupRainbow:
    LDA #C_BG
    STA COLUBK
    LDA #C_SUN
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    ; The ramp window: a 192-entry read starting at Rainbow + RainbowShift.
    ; The table is page-aligned and 192 + 63 = 255 entries long, so the
    ; indirect load never crosses a page.
    LDA #<Rainbow
    CLC
    ADC RainbowShift
    STA RampLo
    LDA #>Rainbow
    ADC #$00
    STA RampHi
    JMP PictureRainbow

; --- the one HMOVE for the effects that position P0 --------------------------
DoHmove:
    STA WSYNC               ; a fresh line for the HMOVE's HBLANK
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed
    NOP
    LDA Effect
    CMP #EFFECT_ROAD
    BEQ PictureRoad
    ; fall through to the starfield
PictureStar:
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; EFFECT 0 — THE STARFIELD (visible lines 0-191)
; =============================================================================
; Two top-down loops share one X index: LDY #0 draws rows 0-175, then
; the same loop shape draws rows 176-191 and adds the ship.  X is the world
; row: it starts at StarScroll and wraps 255 -> 0 inside the page-aligned
; planes.  Y is the visible row and also the index into the enable tables.
BodyStart:                  ; checkpoint: scanline 37, visible line 0
StarField:
    LDX StarScroll
    LDY #0
StarRow:                    ; checkpoint: Y = 0..175
    ; Three playfield load/store pairs: 21 cycles.
    LDA StarPF0,X
    STA PF0                 ; chunks 0-3
    LDA StarPF1,X
    STA PF1                 ; chunks 4-11
    LDA StarPF2,X
    STA PF2                 ; chunks 12-19
    ; One 192-byte enable table per one-pixel star.  Every row writes all
    ; three enables: $02 on the star's own row, $00 everywhere else.  The
    ; three stores complete at cycles 37, 44 and 51, before the stars'
    ; pixels at X=112, 128 and 144 (cycles 60, 65 and 71).
    LDA StarBall,Y
    STA ENABL
StarBallWrite:              ; checkpoint: the ball enable is latched
    LDA StarM0,Y
    STA ENAM0
StarM0Write:                ; checkpoint: missile 0's enable is latched
    LDA StarM1,Y
    STA ENAM1
StarM1Write:                ; checkpoint: missile 1's enable is latched
StarWait:                   ; checkpoint: the WSYNC's first cycle
    STA WSYNC               ; the line is complete; wait for the next
    INX                     ; next world row (255 -> 0 inside the page)
    INY                     ; next visible row
    CPY #SHIP_TOP
    BNE StarRow

; --- rows 176-191: the ship ------------------------------------------------
; The split drops the ship gate from the 176 plain rows and lets this loop
; write GRP0 unconditionally.  The store completes by cycle 39 (the first
; ship row at 37), before the ship's left edge at X=76 (cycle 48).
StarShipRow:                ; checkpoint: Y = 176..191
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    LDA ShipShape - SHIP_TOP,Y
    STA GRP0
ShipWrite:                  ; checkpoint: the ship byte is latched
    LDA StarBall,Y
    STA ENABL
    LDA StarM0,Y
    STA ENAM0
    LDA StarM1,Y
    STA ENAM1
StarShipWait:               ; checkpoint: the ship loop's WSYNC
    STA WSYNC
    INX
    INY
    CPY #SCREEN_LINES
    BNE StarShipRow
    JMP OverscanStart       ; 176 + 16 = 192 lines: visible 0-191

; =============================================================================
; EFFECT 2 — THE PSEUDO-3D ROAD (visible lines 0-191)
; =============================================================================
; PF2 carries the whole road and is stored first: its field starts at
; pixel 48, and the pulse's longest path is latched by cycle 36 (38 in
; exercise 3 with the centre-gap mask).  The car is written only in the
; bottom 16-row loop, after PF2; its GRP0 store completes at cycle 43 (45
; in exercise 3), before its left edge at X=76 (cycle 48).
PictureRoad:
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
RoadStart:                  ; checkpoint: scanline 37, visible line 0
RoadField:
    LDY #0
RoadRow:                    ; checkpoint: Y = 0..175
    ; PF2 is the whole road.  Compute and store it first; the centre-gap
    ; mask adds two cycles, so the store is latched by cycle 25/34/38.
    LDA RoadPF2,Y
    STA PFTemp
    LDX PulseAmt
    BEQ RoadPulseDone
    LSR
    ORA PFTemp
    DEX
    BEQ RoadPulseDone
    LSR
    ORA PFTemp
RoadPulseDone:
    AND #$7F                ; clear chunk 19 (and its mirror): the centre gap
    STA PF2
RoadWait:                   ; checkpoint: the WSYNC's first cycle
    STA WSYNC
    INY
    CPY #CAR_TOP
    BNE RoadRow

; --- rows 176-191: the car ------------------------------------------------
; The split drops the car gate from the 176 road rows and lets this loop
; write GRP0 unconditionally.  The centre-gap mask adds two cycles, so the
; car's store completes at cycle 45, before its left edge at X=76 (cycle 48).
RoadCarRow:                 ; checkpoint: Y = 176..191
    LDA RoadPF2,Y
    STA PFTemp
    LDX PulseAmt
    BEQ RoadCarPulseDone
    LSR
    ORA PFTemp
    DEX
    BEQ RoadCarPulseDone
    LSR
    ORA PFTemp
RoadCarPulseDone:
    AND #$7F                ; the same gap on the car rows
    STA PF2
    LDA CarShape - CAR_TOP,Y
    STA GRP0
RoadCarWait:                ; checkpoint: the car loop's WSYNC
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE RoadCarRow
    JMP OverscanStart       ; 176 + 16 = 192 lines: visible 0-191

; =============================================================================
; EFFECT 1 — THE RAINBOW (visible lines 0-191)
; =============================================================================
; Four forward loops: plain 0-39, sun 40-88, plain 89-159, horizon 160-191.
; Each boundary draws its first row with the boundary stores, then the loop
; continues.  The COLUBK store always comes first: it is the store that must
; beat pixel 0.  PF2's field does not start until pixel 48, so the sun and
; horizon PF stores have the rest of HBLANK.
PictureRainbow:
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
RainbowStart:               ; checkpoint: scanline 37, visible line 0
    LDY #0
RainbowRowA:                ; checkpoint: Y = 0..39
    LDA (RampLo),Y
    STA COLUBK
RainbowWaitA:               ; checkpoint: the WSYNC's first cycle
    STA WSYNC
    INY
    CPY #SUN_TOP
    BNE RainbowRowA
; --- row 40: the sun block starts (PF2 chunks 16-19 -> 32 pixels) ------------
    LDA (RampLo),Y
    STA COLUBK
    LDA #SUN_PF
    STA PF2
    LDA #C_SUN
    STA COLUPF
RainbowSunWait:             ; checkpoint: the sun boundary line's WSYNC
    STA WSYNC
    INY
RainbowRowB:                ; checkpoint: Y = 41..88
    LDA (RampLo),Y
    STA COLUBK
    STA WSYNC
    INY
    CPY #SUN_BOTTOM
    BNE RainbowRowB
; --- row 89: the sun ends ----------------------------------------------------
    LDA (RampLo),Y
    STA COLUBK
    LDA #$00
    STA PF2
RainbowEndWait:             ; checkpoint: the sun-end line's WSYNC
    STA WSYNC
    INY
RainbowRowC:                ; checkpoint: Y = 90..159
    LDA (RampLo),Y
    STA COLUBK
    STA WSYNC
    INY
    CPY #HORIZON_TOP
    BNE RainbowRowC
; --- row 160: the black horizon starts (the full half-width) -----------------
; The horizon is a full-width black band, so all three playfield bytes are
; $FF.  COLUPF goes first: it must beat pixel 0.  PF0's store lands after
; pixel 0, so the very first horizon line shows about seven pixels of the
; previous line's colour at the far left; from the next line the band is solid.
    LDA (RampLo),Y
    STA COLUBK
    LDA #C_BLACK
    STA COLUPF
    LDA #HORIZON_PF
    STA PF0
    STA PF1
    STA PF2
RainbowHorizonWait:         ; checkpoint: the horizon boundary line's WSYNC
    STA WSYNC
    INY
RainbowRowD:                ; checkpoint: Y = 161..191
    LDA (RampLo),Y
    STA COLUBK
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE RainbowRowD
; 40 + 1 + 48 + 1 + 70 + 1 + 31 = 192 lines.  The last WSYNC releases the CPU
; at scanline 229, the first overscan line.

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
; AdvanceEffect — the next effect, wrapping 2 -> 0
; =============================================================================
; A is the new effect when the routine returns.  EffectStep is after the
; store, so a breakpoint there reports the value the rest of the frame uses.
AdvanceEffect:
    LDA Effect
    CLC
    ADC #$01
    CMP #EFFECT_COUNT
    BCC AdvanceStore
    LDA #$00
AdvanceStore:
    STA Effect
EffectStep:                 ; checkpoint: A = the new effect
    RTS

; =============================================================================
; SetCoarseP0 — the Lesson 26 divide-by-15 positioning dance
; =============================================================================
; A = the desired left edge + POS_BIAS.  The first WSYNC starts a fresh line;
; each iteration of the loop is 5 cycles = 15 colour clocks, which is why
; dividing by 15 works.  The remainder becomes the fine value and RESxx
; strobes the coarse position.  The caller's HMOVE applies the fine offset.
; Align the routine so the divide loop's taken BCS stays inside one page:
; a page-crossing branch costs one extra cycle per iteration, and 6 cycles
; would shift the object 15 colour clocks (one wrong coarse step).
    !align 31, 0
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
; SetCoarseBL — the same dance for the ball (HMBL / RESBL)
; =============================================================================
; Align the routine so the divide loop's taken BCS stays inside one page:
; a page-crossing branch costs one extra cycle per iteration, and 6 cycles
; would shift the object 15 colour clocks (one wrong coarse step).
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
    RTS

; =============================================================================
; SetCoarseM0 — the same dance for missile 0 (HMM0 / RESM0)
; =============================================================================
; Align the routine so the divide loop's taken BCS stays inside one page:
; a page-crossing branch costs one extra cycle per iteration, and 6 cycles
; would shift the object 15 colour clocks (one wrong coarse step).
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
    RTS

; =============================================================================
; SetCoarseM1 — the same dance for missile 1 (HMM1 / RESM1)
; =============================================================================
; Align the routine so the divide loop's taken BCS stays inside one page:
; a page-crossing branch costs one extra cycle per iteration, and 6 cycles
; would shift the object 15 colour clocks (one wrong coarse step).
    !align 31, 0
SetCoarseM1:
    STA WSYNC
    SEC
DivM1:
    SBC #15
    BCS DivM1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMM1
    STA RESM1
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
; THE TABLES
; =============================================================================
; The star, road and rainbow tables are the lesson's data.  Every plane is
; page-aligned so the indexed loads never cross a page:
;
;   StarPF0/1/2   256 bytes each; X wraps 255 -> 0 inside the page.
;   StarBall/M0/M1 192 bytes each; Y is 0..191, so a table never crosses
;                 the page when it starts on one.
;   RoadPF2       192 bytes; Y is 0..191, so the plane never crosses a page.
;   Rainbow       192 ramp entries plus the first 64 repeated, so a 192-entry
;                 window starting at 0..63 is contiguous.
;
; The road's width arithmetic:
;   base half-width h(row) = 2 + round(4*row/191)    (2 -> 6)
;   The base road is therefore 4 chunks wide at the horizon and 12 at the
;   bottom.  The kernel then applies the 64-entry pulse: it shifts the PF2
;   mask 0, 1 or 2 times and ORs the shifted value with the unshifted one.
;   Each shift adds one chunk at the outer edge, so the widest bottom rows
;   reach the full 16 chunks.  Chunk 19 is the screen centre (the reflection
;   axis); chunk 12 is the leftmost PF2 chunk.  PF2 bit 7 is chunk 19 and
;   bit 0 is chunk 12, so a half-width h sets bits (8-h)..7.
;
;   At these widths the road lives entirely in PF2: PF0 and PF1 are $00 on
;   every row, so the setup clears them once and the kernel never stores
;   them.  The 16-chunk maximum is exactly PF2's eight chunks per half.

    !align 255, 0
StarPF0:
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 0-15
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$10,$00,$00,$00   ; rows 16-31
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 32-47
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 48-63
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$00,$00,$00   ; rows 64-79
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$00,$00,$00,$00   ; rows 80-95
    !byte $00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 96-111
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 112-127
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 128-143
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$10,$00,$00,$00,$20,$00,$00,$00   ; rows 144-159
    !byte $80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 160-175
    !byte $00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 176-191
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 192-207
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$00   ; rows 208-223
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 224-239
    !byte $00,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$80,$00,$00   ; rows 240-255

    !align 255, 0
StarPF1:
    !byte $40,$00,$00,$00,$08,$00,$00,$00,$00,$00,$00,$00,$20,$00,$00,$00   ; rows 0-15
    !byte $00,$40,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 16-31
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$00,$00,$A0,$00,$00,$00   ; rows 32-47
    !byte $00,$00,$00,$00,$04,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00   ; rows 48-63
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 64-79
    !byte $00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 80-95
    !byte $00,$00,$00,$00,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 96-111
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 112-127
    !byte $00,$00,$00,$00,$10,$00,$00,$00,$00,$00,$00,$08,$00,$00,$00,$00   ; rows 128-143
    !byte $00,$02,$00,$00,$00,$00,$00,$00,$00,$09,$00,$00,$00,$00,$20,$00   ; rows 144-159
    !byte $00,$00,$02,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00   ; rows 160-175
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$00,$00,$00   ; rows 176-191
    !byte $00,$00,$00,$00,$00,$00,$20,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 192-207
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$08,$00,$80,$00,$00,$00,$00,$00   ; rows 208-223
    !byte $00,$00,$00,$00,$00,$00,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 224-239
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$00,$00,$00,$00   ; rows 240-255

    !align 255, 0
StarPF2:
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$08,$00,$80,$80   ; rows 0-15
    !byte $00,$00,$00,$00,$00,$00,$04,$00,$00,$00,$10,$04,$00,$00,$00,$00   ; rows 16-31
    !byte $00,$00,$00,$00,$00,$00,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 32-47
    !byte $00,$00,$00,$00,$00,$00,$20,$00,$00,$00,$00,$02,$00,$00,$00,$00   ; rows 48-63
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$00,$00,$00,$00,$00,$00   ; rows 64-79
    !byte $00,$00,$00,$03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 80-95
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 96-111
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 112-127
    !byte $40,$00,$08,$01,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 128-143
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 144-159
    !byte $40,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 160-175
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 176-191
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00   ; rows 192-207
    !byte $00,$00,$08,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00   ; rows 208-223
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 224-239
    !byte $00,$00,$00,$00,$00,$00,$00,$10,$00,$00,$00,$00,$00,$00,$00,$80   ; rows 240-255

    !align 255, 0
RoadPF2:
    !byte $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0   ; rows 0-23
    !byte $E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0   ; rows 24-47
    !byte $E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0   ; rows 48-71
    !byte $F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0   ; rows 72-95
    !byte $F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0   ; rows 96-119
    !byte $F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8   ; rows 120-143
    !byte $F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8   ; rows 144-167
    !byte $FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC   ; rows 168-191

; =============================================================================
; THE RAINBOW — 16 hues x 12 lines at luminance 7, plus a 64-byte repeat
; =============================================================================
; Hue 0 is $0E (white), hue 1 $1E (gold), and so on to hue 15 $FE.  The
; 64 bytes after the ramp repeat the ramp's first 64 entries, so a window
; that starts at RainbowShift (0..63) and runs 192 rows stays contiguous.
    !align 255, 0
Rainbow:
    !fill 12, $0E           ; hue 0
    !fill 12, $1E           ; hue 1
    !fill 12, $2E           ; hue 2
    !fill 12, $3E           ; hue 3
    !fill 12, $4E           ; hue 4
    !fill 12, $5E           ; hue 5
    !fill 12, $6E           ; hue 6
    !fill 12, $7E           ; hue 7
    !fill 12, $8E           ; hue 8
    !fill 12, $9E           ; hue 9
    !fill 12, $AE           ; hue 10
    !fill 12, $BE           ; hue 11
    !fill 12, $CE           ; hue 12
    !fill 12, $DE           ; hue 13
    !fill 12, $EE           ; hue 14
    !fill 12, $FE           ; hue 15
    ; the repeat: the first 64 entries (5 bands of 12 plus 4 of the sixth)
    !fill 12, $0E
    !fill 12, $1E
    !fill 12, $2E
    !fill 12, $3E
    !fill 12, $4E
    !fill 4, $5E

; =============================================================================
; THE WIDTH PULSE — 64 entries of 0, 1 or 2 widening steps
; =============================================================================
; WidthIndex walks this table once every 128 frames (one step per two
; frames).  Each step widens the road by one chunk per half; the peak adds
; two chunks per half, so the widest bottom row is the full 16 chunks wide.
PulseTable:
    !fill 8, 0
    !fill 16, 1
    !fill 16, 2
    !fill 16, 1
    !fill 8, 0

; =============================================================================
; THE SHIP — sixteen bytes, one per scanline
; =============================================================================
; The same 16-line ship Lesson 52 uses: a pointed nose, a widening body,
; engine gaps and two tail fins.  Drawn on P0 at SHIP_X=76.
    !align 15, 0
ShipShape:
    !byte $18, $18, $3C, $3C, $7E, $7E, $FF, $FF
    !byte $E7, $E7, $C3, $C3, $81, $81, $18, $18

; =============================================================================
; THE CAR — sixteen bytes, one per scanline
; =============================================================================
; A rounded rear view: a narrow roof, a wide body, and a dark window band.
; Drawn on P0 at CAR_X=76, at the bottom of the road.
    !align 15, 0
CarShape:
    !byte $18, $3C, $7E, $FF, $FF, $E7, $C3, $C3
    !byte $C3, $C3, $E7, $FF, $FF, $7E, $3C, $18

; =============================================================================
; THE STAR COLOURS — indexed by Twinkle (0 = white, 1 = gold)
; =============================================================================
TwinkleColors:
    !byte C_STAR_WHITE, C_STAR_GOLD

; =============================================================================
; THE STAR ENABLE TABLES — one 192-byte table per one-pixel star
; =============================================================================
; Row r is $02 on the star's row and $00 everywhere else.  The kernel writes
; all three enables every line, so a table replaces both the clear and the
; compare chain.  Each table is page-aligned: Y is 0..191, so a 192-byte
; table never crosses a page.
    !align 255, 0
StarBall:
    !fill STAR0_ROW, $00
    !byte $02
    !fill SCREEN_LINES - STAR0_ROW - 1, $00

    !align 255, 0
StarM0:
    !fill STAR1_ROW, $00
    !byte $02
    !fill SCREEN_LINES - STAR1_ROW - 1, $00

    !align 255, 0
StarM1:
    !fill STAR2_ROW, $00
    !byte $02
    !fill SCREEN_LINES - STAR2_ROW - 1, $00

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
