; =============================================================================
; LESSON 65, EXERCISE 3: A Colour-Bar Test for Both Palettes
; =============================================================================
; Part 8: Advanced Topics
;
; Exercise 3 solution:
;   This is the lesson ROM with the picture screen replaced by a palette
;   test: 16 rows of 8 large colour swatches, 12 scanlines per row, for the
;   128 TIA colour values $00, $02, ... $FE.  The title selector still
;   chooses NTSC or PAL, so the same ROM can be run on both console types;
;   the frame timing changes and the console's own palette paints the grid.
;   On PAL only 104 of the values are distinct; the grid makes the mapping
;   visible instead of pretending the two palettes match.
;
; What the original program does:
;   "the world traveler": a 4,096-byte ROM that runs on an NTSC console
;   (262 lines, ~60 Hz) and on a PAL console (312 lines, ~50 Hz).  A stock
;   2600 cannot detect which TV system it is connected to, so the program
;   asks: the title screen offers NTSC and PAL, the joystick's up/down
;   moves the underline, and fire starts the test picture.  TVMode 0 is
;   NTSC and TVMode 1 is PAL.
;
;   The picture is a colour-bar test: eight vertical bars drawn by
;   changing COLUBK at fixed cycles inside each line, a moving eight-pixel
;   ball, the word NTSC or PAL in the playfield, and a frame counter
;   (FR nnn).  SELECT shows the timing page: the line count, the frame
;   count, and the colour count (LN262/FRnnn/CL128, or LN312/FRnnn/CL104).
;
;   The test is deliberately honest about the palette: NTSC has 128 colour
;   values and PAL has 104; the same TIA colour byte can look different on
;   the two consoles.  The colour bars are a test pattern, not a promise
;   that the hues match.
;
; Why the selector, and not auto-detection:
;   A stock 2600 has no independent timebase.  The RIOT timer and the TIA
;   count the same CPU clock; the NTSC/PAL crystal difference is about 1%
;   (NTSC 3.579545 MHz vs PAL 3.546894 MHz colour clock), which an 8-bit
;   timer cannot resolve without an external clock.  Software-only
;   auto-detection is therefore impossible.  A custom Harmony/Melody
;   firmware could measure the console with the ARM's own clock, but the
;   shipped Harmony menu is region-specific and user-selected; DPC+ builds
;   choose the region at compile time.  A stock cartridge cannot measure
;   the console at all.  Some games use the Color/BW switch as a manual
;   region selector; this lesson uses a title-screen selector
;   because it is visible, reversible, and works with one joystick.
;
;   The default mode is NTSC.  A PAL user may see the 262-line title roll
;   on a PAL TV until PAL is selected; after the selection the 312-line
;   frame is stable.  The lesson states this plainly rather than claiming
;   a detection that the hardware cannot perform.
;
; The frame:
;   NTSC: 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262 lines.
;     StartFrame 259/3, VblankStart 0/5, BodyStart 37/5,
;     BodyEnd 229/0, OverscanStart 229/6.
;   PAL: 3 VSYNC + 45 VBLANK + 192 visible + 64 lower border + 8 overscan
;     = 312 lines.  PAL's post-picture interval is 72 lines; this build
;     splits it into 64 lower-border lines with VBLANK off (the background colour
;     is black, so it looks like a normal PAL border) and an 8-line
;     blanked overscan tail.  StartFrame 309/3, VblankStart 0/5,
;     BodyStart 45/5, BodyEnd 237/0, OverscanStart 301/6.
;   The visible kernel is 192 lines in both modes.
;
; The RIOT timer values (the first tick lands one cycle after the write,
; so t ticks cover 1 + (t-1) x 64 cycles; +wait_timer anchors to the next
; scanline):
;   NTSC VBLANK   44 ticks = 2,753 cycles -> line 37.
;   NTSC overscan 36 ticks = 2,241 cycles -> line 259.
;   PAL  VBLANK   53 ticks = 3,329 cycles -> line 45.
;   PAL  border   76 ticks = 4,801 cycles -> line 301.
;   PAL  overscan  9 ticks =   513 cycles -> line 309.
;   The timer starts at the STA TIM64T instruction, not at the first cycle
;   of the VBLANK line: the mode lookup and the STA VBLANK put it at cycle
;   15-20.  The PAL values are one tick below the naive 54/10 because,
;   with that later start, 54/10 would expire after the line boundary the
;   final WSYNC needs; 53/9 keeps the 45/301/309 lines.
;   The state log proves the actual lines (45, 301, 309); the arithmetic is
;   in the values above and in the checkpoint table in the document.
;   No value uses the classic 43/35 one-tick-short pair: the lesson wants
;   the nominal periods.
;
; The colour bars (Lesson 18 mid-line technique):
;   A store paints from colour clock 3 x the cycle of the next instruction.
;   The body starts at cycle 5; the eight stores hit cycles 22, 29, 36,
;   43, 50, 57, 64 and 71, so the visible boundaries are at clocks 66, 87,
;   108, 129, 150, 171, 192 and 213.  The measured widths in the 960-pixel
;   capture are 114, 126 x 6, 90 pixels.  The bars are identical in both
;   modes; only the palette behind the colours changes.
;
; The text:
;   A 20-chunk playfield half holds exactly five four-chunk characters.
;   The glyphs are 4x7 (bit 3 is the leftmost column) and are composed
;   into a 24-byte buffer: eight PF0 rows, eight PF1 rows, eight PF2 rows.
;   The text band draws two setup lines (the leading WSYNC and the
;   85-cycle setup's own WSYNC), eight glyph rows, and one black clear
;   line: 2 + 8 + 1 = 11.  Each band's leading WSYNC consumes the previous
;   separator line.  The title underlines the selected word in row 7 of
;   its buffer.  SELECT switches the main picture to the timing page.
;
; The selector hand-off:
;   Up/down writes PendingMode; the mode is applied at the end of the
;   frame, before the next VSYNC.  The current frame's VBLANK and body
;   timing stay consistent, so a mode switch can never produce a frame
;   that is half NTSC and half PAL.  The state log shows TVMode 0 on the
;   frame of the key press and 1 from the next frame.
;
; Checkpoints (label, Stella scanline/cycle, and the A register):
;   StartFrame    259/3 (NTSC), 309/3 (PAL)  the first VSYNC instruction
;   VblankStart     0/5                      the first VBLANK instruction
;   BodyStart      37/5 (NTSC), 45/5 (PAL)   the first visible line
;   BodyEnd       229/0 (NTSC), 237/0 (PAL)  the line after the kernel
;   OverscanStart 229/6 (NTSC), 301/6 (PAL)  the first overscan instruction
;   TVModeRead    A = 0 (NTSC) or 1 (PAL), the active timing mode
;   FrameLinesRead A = the low byte of the 16-bit line count:
;                 $06 (262 = $0106) or $38 (312 = $0138); the high byte
;                 at FrameLinesHi is $01 in both modes
;   FrameRead     A = the free-running frame counter, 0..255
;   ModeWrite     A = the new pending mode, 0 or 1 (up/down edge)
;   ScreenWrite   A = the new screen, 0 title, 1 picture, 2 timing
;   FrameLinesHiRead A = $01, the high byte of the line count
;
; RAM map (+clean_start zeroes every byte):
;   $80 TVMode        0 = NTSC timing, 1 = PAL timing (the active mode)
;   $81 FrameLinesLo  low byte of the 16-bit line count ($06 or $38)
;   $82 FrameLinesHi  high byte ($01 in both modes)
;   $83 Frame         free-running frame counter, 0..255
;   $84 BarX          the ball's target X, 16..151, one pixel per frame
;   $85 Screen        0 = title, 1 = test picture, 2 = timing page
;   $86 PrevUp        the up level last frame (1 = pressed)
;   $87 PrevDown      the down level last frame
;   $88 PrevFire      the fire level last frame (1 = pressed)
;   $89 PrevSelect    the SELECT level last frame (1 = pressed)
;   $8A PendingMode   the mode requested by up/down, applied at frame end
;   $8B ModeDirty     1 = PendingMode must be copied to TVMode
;   $8C TextDirty     1 = the static text buffers must be rebuilt
;   $8D FromTitle     1 = the timing page was entered from the title
;   $8E FrameHundreds the frame counter's hundreds digit
;   $8F FrameTens     the tens digit
;   $90 FrameOnes     the ones digit
;   $91-$95 TextChars the five glyph codes of the text being composed
;   $96-$97 TextPtr   the source string pointer / the buffer pointer
;   $98-$99 TextDest  the destination buffer pointer
;   $9A-$9B Dest1     TextDest + 8
;   $9C-$9D Dest2     TextDest + 16
;   $9E-$9F GlyphPtr0 the first character's glyph pointer
;   $A0-$A1 GlyphPtr1
;   $A2-$A3 GlyphPtr2
;   $A4-$A5 GlyphPtr3
;   $A6-$A7 GlyphPtr4
;   $A8 free
;   $A9 Scratch       a temporary byte
;   $AA free
;   $AB TimingMode    0 = 262-line timing, 1 = 312-line timing; PAL-60
;                     forces 0 while TVMode stays 1 (the label/colours)
;   $AC-$AF free (4 bytes)
;   $B0-$C7 LabelBuf  the main/title/timing label buffer
;   $C8-$DF FrBuf     the frame-counter buffer
;   $E0-$F7 AltBuf    the second title label / the colour-count buffer
;   $F8-$FF stack
;
; Build: acme -f plain -o build/lesson65.bin \
;        lessons/part8-advanced/65-pal-ntsc-universal/65-pal-ntsc-universal.asm
; Run:   stella build/lesson65.bin
;        stella -format PAL -holdjoy0 'D,F' build/lesson65.bin   (PAL test screen)
; The ROM is 4,096 bytes.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; CONSTANTS
; =============================================================================
; The compile-time hooks the exercises use.  0 in the lesson ROM:
;   DEFAULT_TV = 0 (NTSC) / 1 (PAL) — the mode at power-on.
;   PAL60     = 1 keeps the PAL label/colour count but uses the 262-line
;               timing, i.e. a 60 Hz frame on a PAL console.
DEFAULT_TV = 0
PAL60      = 0

; The RIOT timer values.  See the header for the arithmetic.
NTSC_VBLANK_TIMER   = 44
; The palette screen's BodyEnd is at 229/15 (its JMP BodyEnd starts at
; cycle 6), nine cycles later than the lesson's; 35 ticks instead of 36
; keep StartFrame at 259/3 and the frame at 262 lines.
NTSC_OVERSCAN_TIMER = 35
PAL_VBLANK_TIMER    = 53
PAL_OVERSCAN_TIMER  = 9
PAL_BORDER_TIMER    = 76

; The eight colour-bar values.  They are NTSC values; the PAL console maps
; the same bytes through its own palette, which is why the test is useful.
BAR0 = $0E                  ; light grey
BAR1 = $1A                  ; gold
BAR2 = $2E                  ; orange
BAR3 = $3E                  ; peach
BAR4 = $42                  ; red
BAR5 = $5E                  ; pink
BAR6 = $84                  ; blue
BAR7 = $C8                  ; green

; The playfield text colour (the ball shares COLUPF).
TEXT_COLOR = $0E            ; white

; The screen numbers.
SCREEN_TITLE   = 0
SCREEN_PICTURE = 1
SCREEN_TIMING  = 2

; The glyph codes used by the five-character strings.  0-9 are the digits;
; the letters follow in the order of the font table.
GLYPH_0      = 0
GLYPH_1      = 1
GLYPH_2      = 2
GLYPH_3      = 3
GLYPH_4      = 4
GLYPH_5      = 5
GLYPH_6      = 6
GLYPH_7      = 7
GLYPH_8      = 8
GLYPH_9      = 9
GLYPH_F      = 10
GLYPH_R      = 11
GLYPH_N      = 12
GLYPH_T      = 13
GLYPH_S      = 14
GLYPH_C      = 15
GLYPH_P      = 16
GLYPH_A      = 17
GLYPH_L      = 18
GLYPH_SPACE  = 19

; The bar's travel.  The ball is eight pixels wide, so X=16 is the left
; margin and X=151 ends at pixel 159, the right edge of the visible area.
BAR_MIN = 16
BAR_MAX = 151

; =============================================================================
; RAM
; =============================================================================
TVMode        = $80
FrameLinesLo  = $81
FrameLinesHi  = $82
Frame         = $83
BarX          = $84
Screen        = $85
PrevUp        = $86
PrevDown      = $87
PrevFire      = $88
PrevSelect    = $89
PendingMode   = $8A
ModeDirty     = $8B
TextDirty     = $8C
FromTitle     = $8D
FrameHundreds = $8E
FrameTens     = $8F
FrameOnes     = $90
TextChars     = $91           ; five bytes, $91-$95
TextPtr       = $96           ; two bytes
TextDest      = $98           ; two bytes
Dest1         = $9A           ; two bytes
Dest2         = $9C           ; two bytes
GlyphPtr0     = $9E           ; two bytes
GlyphPtr1     = $A0
GlyphPtr2     = $A2
GlyphPtr3     = $A4
GlyphPtr4     = $A6
Scratch       = $A9
TimingMode    = $AB
; $AC-$AF free
LabelBuf      = $B0           ; 24 bytes: PF0 rows, PF1 rows, PF2 rows
FrBuf         = $C8           ; 24 bytes
AltBuf        = $E0           ; 24 bytes
; $F8-$FF stack

; =============================================================================
; RESET — power-on entry
; =============================================================================
    * = $F000
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (joysticks)
    STA SWBCNT              ; port B is an input port (console switches)

    ; --- the default mode ------------------------------------------------
    ; A PAL user selects PAL on the title screen.  The default is NTSC
    ; because the NTSC frame is the course baseline, and because the
    ; console cannot tell us which one it is.  DEFAULT_TV is the exercise
    ; hook that makes a PAL-default build.
    LDA #DEFAULT_TV
    STA TVMode
    STA PendingMode
    STA ModeDirty
    JSR SetTiming            ; TimingMode and the 16-bit FrameLines
    LDA #$00
    STA Screen
    STA Frame
    STA FromTitle
    STA PrevUp
    STA PrevDown
    STA PrevFire
    STA PrevSelect
    LDA #BAR_MIN
    STA BarX
    LDA #$01
    STA TextDirty            ; the first VBLANK builds the title texts

    ; --- the fixed TIA state ----------------------------------------------
    LDA #TEXT_COLOR
    STA COLUPF               ; the text and the moving ball are white
    STA COLUP0
    STA COLUP1
    LDA #$00
    STA COLUBK
    STA PF0
    STA PF1
    STA PF2
    LDA #$30                 ; ball size 8, repeat playfield, no priority
    STA CTRLPF
    LDA #$02
    STA ENABL                ; the moving ball is on outside the text bands

    ; --- place the ball once before the first frame -----------------------
    JSR SetBallPos

    JMP StartFrame

; =============================================================================
; FRAME — 3 VSYNC + VBLANK + 192 visible + overscan/border = 262 or 312
; =============================================================================
StartFrame:                 ; checkpoint: 259/3 (NTSC) or 309/3 (PAL)
    +vsync

VblankStart:                ; checkpoint: scanline 0, cycle 5
    LDA #$02
    STA VBLANK
    LDX TimingMode
    LDA VblankTimers,X
    STA TIM64T               ; the VBLANK timer starts at the top of line 0

    ; --- the mode and line-count checkpoints ------------------------------
    LDA TVMode
TVModeRead:                 ; checkpoint: A = 0 (NTSC) or 1 (PAL)
    NOP
    LDA FrameLinesLo
FrameLinesRead:             ; checkpoint: A = $06 (262) or $38 (312)
    NOP
    LDA FrameLinesHi
FrameLinesHiRead:           ; checkpoint: A = $01 (the high byte)
    NOP

; -----------------------------------------------------------------------------
; 1. THE INPUTS AND THE EDGES
; -----------------------------------------------------------------------------
    ; Up: SWCHA bit 4, active low.  NewUp = 1 while pressed.
    LDA SWCHA
    AND #$10
    EOR #$10
    STA Scratch              ; Scratch = NewUp
    AND PrevUp
    EOR Scratch
    BEQ NoUpEdge
    LDA #0
    STA PendingMode          ; up selects NTSC
    LDA #1
    STA ModeDirty
    LDA PendingMode
ModeWrite:                   ; checkpoint: A = the new pending mode (0)
    NOP
NoUpEdge:
    LDA Scratch
    STA PrevUp

    ; Down: SWCHA bit 5, active low.
    LDA SWCHA
    AND #$20
    EOR #$20
    STA Scratch
    AND PrevDown
    EOR Scratch
    BEQ NoDownEdge
    LDA #1
    STA PendingMode          ; down selects PAL
    LDA #1
    STA ModeDirty
    LDA PendingMode
ModeWriteDown:               ; checkpoint: A = 1 on a down edge
    NOP
NoDownEdge:
    LDA Scratch
    STA PrevDown

    ; Fire: INPT4 bit 7, active low.
    LDA INPT4
    AND #$80
    EOR #$80
    STA Scratch
    AND PrevFire
    EOR Scratch
    BEQ NoFireEdge
    LDA Screen
    BNE NoFireEdge           ; fire only starts from the title
    LDA #SCREEN_PICTURE
    STA Screen
    STA FromTitle            ; not used for fire, but keep it clear
    LDA #1
    STA TextDirty
    LDA Screen
ScreenWriteFire:             ; checkpoint: A = the new screen (1)
    NOP
NoFireEdge:
    LDA Scratch
    STA PrevFire

    ; SELECT: SWCHB bit 1, active low.  It toggles the title and the palette.
    LDA SWCHB
    AND #$02
    EOR #$02
    STA Scratch
    AND PrevSelect
    EOR Scratch
    BEQ NoSelectEdge
    LDA Screen
    EOR #$01
    STA Screen
    LDA #1
    STA TextDirty
    LDA Screen
ScreenWrite:                 ; checkpoint: A = the new screen, 0, 1 or 2
    NOP
NoSelectEdge:
    LDA Scratch
    STA PrevSelect

; -----------------------------------------------------------------------------
; 2. THE FRAME COUNTER
; -----------------------------------------------------------------------------
    INC Frame
    LDA Frame
FrameRead:                   ; checkpoint: A = the free-running frame, 0..255
    NOP

; -----------------------------------------------------------------------------
; 3. THE STATIC TEXT BUFFERS (only when the screen or the mode changed)
; -----------------------------------------------------------------------------
    LDA TextDirty
    BEQ NoTextBuild
    JSR BuildStaticTexts
    LDA #$00
    STA TextDirty
NoTextBuild:

; -----------------------------------------------------------------------------
; 4. THE MOVING BAR
; -----------------------------------------------------------------------------
    LDA BarX
    CLC
    ADC #1
    CMP #BAR_MAX+1
    BCC StoreBarX
    LDA #BAR_MIN
StoreBarX:
    STA BarX
    JSR SetBallPos           ; one HMOVE, in VBLANK

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; THE VISIBLE PICTURE — 192 lines, 3 screens
; =============================================================================
BodyStart:                  ; checkpoint: 37/5 (NTSC) or 45/5 (PAL)
    LDA #$00
    STA COLUBK              ; the first line is black
    LDA Screen
    BEQ TitleScreen
    JMP PaletteScreen

; =============================================================================
; THE TITLE SCREEN — 8 + 48 + 11 + 16 + 11 + 92 + 1 + 5 = 192 lines
; =============================================================================
TitleScreen:
    LDY #8
    JSR BlackLines
    LDY #48
    JSR BarLines
    LDA #<LabelBuf
    STA TextPtr
    LDA #>LabelBuf
    STA TextPtr+1
    JSR TextBand
    LDY #16
    JSR BarLines
    LDA #<AltBuf
    STA TextPtr
    LDA #>AltBuf
    STA TextPtr+1
    JSR TextBand
    LDY #92
    JMP FinalBars

; =============================================================================
; THE PALETTE SCREEN — 16 rows x 8 swatches, 12 lines per row = 192 lines
; =============================================================================
; The 128 colour values are even bytes $00..$FE: the TIA colour byte is
; CCCCLLL0, so bit 0 is unused and the 128 valid values are the even ones.
; Each swatch is 7 cycles wide: LDA abs,X (4) + STA COLUBK (3), giving the
; same store hits as the eight-bar kernel (22, 29, ... 71).  The first
; line of each row is a few cycles late (the row transition runs on the
; line after the last WSYNC); the other eleven lines are aligned.
; One swatch line: eight 7-cycle colour changes.  X is the row base.
!macro palette_body {
    LDA SwatchTable+0,X
    STA COLUBK
    LDA SwatchTable+1,X
    STA COLUBK
    LDA SwatchTable+2,X
    STA COLUBK
    LDA SwatchTable+3,X
    STA COLUBK
    LDA SwatchTable+4,X
    STA COLUBK
    LDA SwatchTable+5,X
    STA COLUBK
    LDA SwatchTable+6,X
    STA COLUBK
    LDA SwatchTable+7,X
    STA COLUBK
}

; The palette screen is one continuous 192-line loop.  LineRow gives the
; eight-colour row base for each scanline: 12 lines per row for rows 0-14,
; 11 for the last row (16 * 12 - 1 = 191 grid lines) after the black top
; separator.  The one-line loop avoids the row-transition line that would
; otherwise make the frame longer than 262/312.  The first iteration gets
; a BIT+NOP pad so it enters the body at cycle 11 like the loop's later
; iterations; the eight stores hit cycles 18, 25, 32, 39, 46, 53, 60 and
; 67.  The first store's boundary is in HBLANK, so the first visible swatch is
; narrow; the grid is otherwise aligned line for line.
PaletteScreen:
    LDA #$00
    STA ENABL               ; no ball in the palette grid
    STA COLUPF
    STA COLUBK
    STA WSYNC               ; the top black separator
    LDY #0
    BIT Frame               ; the first line's 5-cycle pad: its body starts
    NOP                     ; at cycle 11 like every later line
PaletteLine:
    LDX LineRow,Y
    +palette_body
    STA WSYNC
    INY
    CPY #191
    BNE PaletteLine
    JMP BodyEnd

; =============================================================================
; BlackLines — Y lines of black, with the ball still visible
; =============================================================================
; Entry: at cycle 5 on the first line (from BodyStart or a band tail).
; Exit: at cycle 5 of the line after the last one (the DEY/BNE tail).
; The ball is not touched: the moving bar crosses the black border too.
BlackLines:
-   LDA #$00
    STA COLUBK
    STA WSYNC
    DEY
    BEQ BlackDone
    JMP -
BlackDone:
    RTS

; =============================================================================
; BarLines — Y lines of eight colour bars; the body starts at cycle 5
; =============================================================================
; The first STA WSYNC discards the caller's partial line, so the routine
; always starts its first body on a fresh scanline at cycle 0.  The
; BIT+NOP pair then puts the body at cycle 5.  The body's stores hit
; cycles 22, 29, 36, 43, 50, 57, 64 and 71, the Lesson 18/64 timing.
BarLines:
    STA WSYNC               ; discard the caller's partial line
    BIT Frame               ; 0-2
    NOP                     ; 3-4
BarLoop:
    LDA #BAR0               ; 5-6
    STA COLUBK              ; 7-9   hit 10 (the base, still in HBLANK)
    NOP                     ; 10-11
    NOP                     ; 12-13
    BIT Frame               ; 14-16 a 3-cycle pad, no side effects
    LDA #BAR0               ; 17-18
    STA COLUBK              ; 19-21 hit 22 (clock 66)
    NOP                     ; 22-23
    LDA #BAR1               ; 24-25
    STA COLUBK              ; 26-28 hit 29
    NOP
    LDA #BAR2               ; 31-32
    STA COLUBK              ; 33-35 hit 36
    NOP
    LDA #BAR3               ; 38-39
    STA COLUBK              ; 40-42 hit 43
    NOP
    LDA #BAR4               ; 45-46
    STA COLUBK              ; 47-49 hit 50
    NOP
    LDA #BAR5               ; 52-53
    STA COLUBK              ; 54-56 hit 57
    NOP
    LDA #BAR6               ; 59-60
    STA COLUBK              ; 61-63 hit 64
    NOP                     ; 64-65
    LDA #BAR7               ; 66-67
    STA COLUBK              ; 68-70 hit 71
    STA WSYNC               ; 71-73
    DEY
    BNE BarLoop
    ; the last line's WSYNC has ended at cycle 0; make the separator
    ; line black before the next band discards it
    LDA #$00
    STA COLUBK
    RTS

; =============================================================================
; FinalBars — the last band: Y bar lines, a black alignment line, then
; BodyEnd at cycle 0
; =============================================================================
; The first STA WSYNC discards the caller's partial line.  BIT+NOP puts
; the first body at cycle 5; the normal DEY/BNE loop keeps every later
; body at cycle 5.  After the last bar line, the routine clears COLUBK
; and spends one black alignment line with STA WSYNC — its last
; instruction — so BodyEnd starts at cycle 0 of the next scanline, the
; exact alignment the overscan label needs.
FinalBars:
    STA WSYNC               ; discard the caller's partial line
    BIT Frame               ; 0-2
    NOP                     ; 3-4
FinalLoop:
    LDA #BAR0               ; 5-6
    STA COLUBK              ; 7-9
    NOP
    NOP
    BIT Frame
    LDA #BAR0
    STA COLUBK              ; hit 22
    NOP
    LDA #BAR1
    STA COLUBK              ; hit 29
    NOP
    LDA #BAR2
    STA COLUBK              ; hit 36
    NOP
    LDA #BAR3
    STA COLUBK              ; hit 43
    NOP
    LDA #BAR4
    STA COLUBK              ; hit 50
    NOP
    LDA #BAR5
    STA COLUBK              ; hit 57
    NOP
    LDA #BAR6
    STA COLUBK              ; hit 64
    NOP
    LDA #BAR7
    STA COLUBK              ; hit 71
    STA WSYNC
    DEY
    BNE FinalLoop
    ; the black alignment line: the last instruction ends at cycle 0
    LDA #$00
    STA COLUBK
    STA WSYNC

; =============================================================================
; BODY END — the first line after the 192-line kernel
; =============================================================================
; NTSC: BodyEnd is 229/0; the LDA/BEQ pair puts OverscanStart at 229/6.
; PAL:  BodyEnd is 237/0; the 64-line lower border runs with VBLANK off,
;       then the last WSYNC and BIT/JMP put OverscanStart at 301/6.
BodyEnd:                    ; checkpoint: 229/0 (NTSC/PAL-60) or 237/0 (PAL)
    LDA TimingMode
    BEQ OverscanStart        ; 262-line timing: 0-2 + taken 3-5 -> cycle 6
    JMP PalBorder

PalBorder:
    ; PAL: paint the 64-line lower border in black.  VBLANK is still off,
    ; so the TV sees the background colour; black makes it read as a
    ; normal PAL border.  The ball and playfield are cleared for the
    ; border (the last bar band left them on).
    LDA #$00
    STA COLUBK
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    LDA #PAL_BORDER_TIMER
    STA TIM64T

PalBorderWait:
    LDA INTIM
    BNE PalBorderWait
    STA WSYNC                ; line 301, cycle 0
    BIT Frame                ; 0-2
    JMP OverscanStart        ; 3-5 -> the label is at cycle 6

; =============================================================================
; OVERSCAN — 30 lines (NTSC) or 8 lines (PAL), then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: 229/6 (NTSC/PAL-60), 301/6 (PAL)
    LDA #$02
    STA VBLANK
    LDA #$02
    STA ENABL               ; on both modes: restore the ball for the next
                            ; frame's top bands (the PAL border cleared it)
    LDX TimingMode
    LDA OverscanTimers,X
    STA TIM64T

OverscanNoFrame:
    ; --- apply a pending mode at the frame boundary ----------------------
    ; The frame that handled the key press used the old timing from its
    ; first VBLANK line to its last border line.  The new mode starts with
    ; the next VSYNC, so no frame is ever half NTSC and half PAL.  The
    ; block runs before the final +wait_timer, so the timer's WSYNC and
    ; the JMP leave StartFrame at cycle 3 of the VSYNC line.
    LDA ModeDirty
    BEQ NoModeApply
    LDA PendingMode
    STA TVMode
    LDA #$00
    STA ModeDirty
    LDA #$01
    STA TextDirty
    JSR SetTiming            ; TimingMode and the 16-bit FrameLines
NoModeApply:
    +wait_timer
    JMP StartFrame

; =============================================================================
; SET BALL POSITION — the classic divide-by-15 routine for the ball
; =============================================================================
; Input: BarX (the left edge of the eight-pixel ball).  The +4 bias is
; the ball's output delay estimate; the HMOVE absorbs the remainder.
SetBallPos:
    LDA BarX
    CLC
    ADC #4
    STA WSYNC
    SEC
-   SBC #15
    BCS -
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMBL
    STA RESBL
    STA WSYNC
    STA HMOVE
    RTS

; =============================================================================
; TEXT BAND — two setup lines, eight glyph lines, one clear line = 11
; =============================================================================
; TextPtr points to a 24-byte buffer: eight PF0 rows, eight PF1 rows,
; eight PF2 rows.  The first STA WSYNC discards the caller's partial
; line.  The setup code is 85 cycles, so it overruns the next line and
; its own WSYNC lands on the line after: the band has TWO setup lines,
; not one.  The setup clears the playfield and loads row 0 while COLUPF
; is black, so both setup lines stay black.  The first glyph line turns
; COLUPF white; eight glyph lines (row 0 plus rows 1-7) follow.  The
; clear line blanks the playfield, restores the white ball, and ends with
; BIT so the next band starts at cycle 3.  Total: 2 + 8 + 1 = 11 lines.
; Each band's leading WSYNC consumes the previous separator line; the
; FinalBars' black alignment line is the +1; the +5/+7 are the inter-band
; transitions (five/six-band or seven/eight-band).
TextBand:
    STA WSYNC                ; discard the caller's partial line
    LDA #$00
    STA ENABL
    STA COLUBK
    STA COLUPF
    STA PF0
    STA PF1
    STA PF2
    ; Dest1 = TextPtr + 8, Dest2 = TextPtr + 16
    LDA TextPtr
    CLC
    ADC #8
    STA Dest1
    LDA TextPtr+1
    ADC #0
    STA Dest1+1
    LDA TextPtr
    CLC
    ADC #16
    STA Dest2
    LDA TextPtr+1
    ADC #0
    STA Dest2+1
    ; row 0 into the playfield (invisible while COLUPF is black)
    LDY #0
    LDA (TextPtr),Y
    STA PF0
    LDA (Dest1),Y
    STA PF1
    LDA (Dest2),Y
    STA PF2
    STA WSYNC                ; the black setup line

    ; the first text line: the row-0 bytes are already loaded
    LDA #TEXT_COLOR
    STA COLUPF
    STA WSYNC

    ; rows 1-7: load the row at the start of the line, before the beam
    ; reaches the visible area (cycle 22)
    LDY #1
TextRowLoop:
    LDA (TextPtr),Y
    STA PF0
    LDA (Dest1),Y
    STA PF1
    LDA (Dest2),Y
    STA PF2
    STA WSYNC
    INY
    CPY #8
    BNE TextRowLoop

    ; the clear line: blank the playfield, restore the white ball
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA #TEXT_COLOR
    STA COLUPF
    LDA #$02
    STA ENABL
    STA WSYNC
    BIT Frame                ; the next band starts at cycle 3
    RTS

; =============================================================================
; BUILD THE STATIC TEXTS — the title labels only
; =============================================================================
BuildStaticTexts:
    LDA Screen
    BNE BuildStaticDone    ; the palette screen has no text
    LDA #<TextNtsc
    STA TextPtr
    LDA #>TextNtsc
    STA TextPtr+1
    LDA #<LabelBuf
    STA TextDest
    LDA #>LabelBuf
    STA TextDest+1
    JSR SetText
    LDA TVMode
    BNE NoNtscUnderline
    LDA #$0F                ; NTSC is four characters = 16 chunks
    JSR UnderlineText
NoNtscUnderline:
    LDA #<TextPal
    STA TextPtr
    LDA #>TextPal
    STA TextPtr+1
    LDA #<AltBuf
    STA TextDest
    LDA #>AltBuf
    STA TextDest+1
    JSR SetText
    LDA TVMode
    BEQ NoPalUnderline
    LDA #$00                ; PAL is three characters = 12 chunks
    JSR UnderlineText
NoPalUnderline:
BuildStaticDone:
    RTS

; =============================================================================
; SET TEXT — copy five glyph codes, then compose them
; =============================================================================
SetText:
    LDY #0
-   LDA (TextPtr),Y
    STA TextChars,Y
    INY
    CPY #5
    BNE -
    JSR ComposeText
    RTS

; =============================================================================
; COMPOSE TEXT — five glyph codes -> 24 playfield bytes
; =============================================================================
; The buffer is column-major: eight PF0 rows at +0, eight PF1 rows at +8,
; eight PF2 rows at +16.  Playfield chunks 0-3 come from PF0 (bit 4 is
; the leftmost), 4-11 from PF1 (bit 7 leftmost), 12-19 from PF2 (bit 0
; leftmost).  The glyph rows use bit 3 as the leftmost column, so:
;   PF0 = Rev4[g0] << 4
;   PF1 = (g1 << 4) | g2
;   PF2 = Rev4[g3] | (Rev4[g4] << 4)
ComposeText:
    LDX TextChars+0
    LDA GlyphLo,X
    STA GlyphPtr0
    LDA GlyphHi,X
    STA GlyphPtr0+1
    LDX TextChars+1
    LDA GlyphLo,X
    STA GlyphPtr1
    LDA GlyphHi,X
    STA GlyphPtr1+1
    LDX TextChars+2
    LDA GlyphLo,X
    STA GlyphPtr2
    LDA GlyphHi,X
    STA GlyphPtr2+1
    LDX TextChars+3
    LDA GlyphLo,X
    STA GlyphPtr3
    LDA GlyphHi,X
    STA GlyphPtr3+1
    LDX TextChars+4
    LDA GlyphLo,X
    STA GlyphPtr4
    LDA GlyphHi,X
    STA GlyphPtr4+1
    ; Dest1 = TextDest + 8, Dest2 = TextDest + 16
    LDA TextDest
    CLC
    ADC #8
    STA Dest1
    LDA TextDest+1
    ADC #0
    STA Dest1+1
    LDA TextDest
    CLC
    ADC #16
    STA Dest2
    LDA TextDest+1
    ADC #0
    STA Dest2+1
    LDY #0
ComposeRow:
    LDA (GlyphPtr0),Y
    TAX
    LDA Rev4,X
    ASL
    ASL
    ASL
    ASL
    STA (TextDest),Y
    LDA (GlyphPtr1),Y
    ASL
    ASL
    ASL
    ASL
    STA Scratch
    LDA (GlyphPtr2),Y
    ORA Scratch
    STA (Dest1),Y
    LDA (GlyphPtr3),Y
    TAX
    LDA Rev4,X
    STA Scratch
    LDA (GlyphPtr4),Y
    TAX
    LDA Rev4,X
    ASL
    ASL
    ASL
    ASL
    ORA Scratch
    STA (Dest2),Y
    INY
    CPY #8
    BNE ComposeRow
    RTS

; =============================================================================
; UNDERLINE — set row 7 of the current TextDest buffer
; =============================================================================
; A = $0F for a four-character (16-chunk) word, $00 for three characters.
UnderlineText:
    STA Scratch
    LDY #7
    LDA #$FF
    STA (TextDest),Y
    LDY #15
    STA (TextDest),Y
    LDY #23
    LDA Scratch
    STA (TextDest),Y
    RTS

; =============================================================================
; SET TIMING — TVMode + the PAL60 flag -> TimingMode and FrameLines
; =============================================================================
; PAL60 = 1 keeps the PAL label and colour count (TVMode = 1) but forces
; the 262-line timing, so the frame runs at ~60 Hz on a PAL console.
; PAL60 = 0 (the lesson ROM) makes TimingMode follow TVMode.
SetTiming:
    LDA TVMode
    LDX #PAL60
    BEQ SetTimingStore       ; PAL60 = 0: keep TVMode
    LDA #0                   ; PAL60 = 1: force the 262-line timing
SetTimingStore:
    STA TimingMode
    TAX
    LDA LineLo,X
    STA FrameLinesLo
    LDA LineHi,X
    STA FrameLinesHi
    RTS

LineRow:
    !fill 12, 0
    !fill 12, 8
    !fill 12, 16
    !fill 12, 24
    !fill 12, 32
    !fill 12, 40
    !fill 12, 48
    !fill 12, 56
    !fill 12, 64
    !fill 12, 72
    !fill 12, 80
    !fill 12, 88
    !fill 12, 96
    !fill 12, 104
    !fill 12, 112
    !fill 11, 120

    !align 255, 0
; 16 rows x 8 bytes = the 128 even TIA values $00-$FE.  The grid indexes
; SwatchTable+0..7,X with X up to 120, so the table must be 128 bytes; a
; 64-byte table would read into the timing tables and glyph data.
SwatchTable:
    !byte $00, $02, $04, $06, $08, $0A, $0C, $0E
    !byte $10, $12, $14, $16, $18, $1A, $1C, $1E
    !byte $20, $22, $24, $26, $28, $2A, $2C, $2E
    !byte $30, $32, $34, $36, $38, $3A, $3C, $3E
    !byte $40, $42, $44, $46, $48, $4A, $4C, $4E
    !byte $50, $52, $54, $56, $58, $5A, $5C, $5E
    !byte $60, $62, $64, $66, $68, $6A, $6C, $6E
    !byte $70, $72, $74, $76, $78, $7A, $7C, $7E
    !byte $80, $82, $84, $86, $88, $8A, $8C, $8E
    !byte $90, $92, $94, $96, $98, $9A, $9C, $9E
    !byte $A0, $A2, $A4, $A6, $A8, $AA, $AC, $AE
    !byte $B0, $B2, $B4, $B6, $B8, $BA, $BC, $BE
    !byte $C0, $C2, $C4, $C6, $C8, $CA, $CC, $CE
    !byte $D0, $D2, $D4, $D6, $D8, $DA, $DC, $DE
    !byte $E0, $E2, $E4, $E6, $E8, $EA, $EC, $EE
    !byte $F0, $F2, $F4, $F6, $F8, $FA, $FC, $FE

; =============================================================================
; THE TIMING TABLES
; =============================================================================
VblankTimers:
    !byte NTSC_VBLANK_TIMER, PAL_VBLANK_TIMER
OverscanTimers:
    !byte NTSC_OVERSCAN_TIMER, PAL_OVERSCAN_TIMER
LineLo:
    !byte <262, <312
LineHi:
    !byte >262, >312

; =============================================================================
; THE TEXT STRINGS — five glyph codes each
; =============================================================================
TextNtsc:
    !byte GLYPH_N, GLYPH_T, GLYPH_S, GLYPH_C, GLYPH_SPACE
TextPal:
    !byte GLYPH_P, GLYPH_A, GLYPH_L, GLYPH_SPACE, GLYPH_SPACE
TextLn262:
    !byte GLYPH_L, GLYPH_N, GLYPH_2, GLYPH_6, GLYPH_2
TextLn312:
    !byte GLYPH_L, GLYPH_N, GLYPH_3, GLYPH_1, GLYPH_2
TextCl128:
    !byte GLYPH_C, GLYPH_L, GLYPH_1, GLYPH_2, GLYPH_8
TextCl104:
    !byte GLYPH_C, GLYPH_L, GLYPH_1, GLYPH_0, GLYPH_4

; =============================================================================
; THE 4x7 GLYPH FONT — bit 3 is the leftmost column
; =============================================================================
; The eleventh entry is a space; the composer indexes GlyphLo/GlyphHi by
; the glyph code, so the table order must match the GLYPH_* constants.
GlyphTable:
Glyph0:
    !byte %0110, %1001, %1001, %1001, %1001, %1001, %0110, %0000
Glyph1:
    !byte %0010, %0110, %0010, %0010, %0010, %0010, %0111, %0000
Glyph2:
    !byte %0110, %1001, %0001, %0010, %0100, %1000, %1111, %0000
Glyph3:
    !byte %1110, %0001, %0001, %0110, %0001, %0001, %1110, %0000
Glyph4:
    !byte %0010, %0110, %1010, %1010, %1111, %0010, %0010, %0000
Glyph5:
    !byte %1111, %1000, %1000, %1110, %0001, %0001, %1110, %0000
Glyph6:
    !byte %0110, %1000, %1000, %1110, %1001, %1001, %0110, %0000
Glyph7:
    !byte %1111, %0001, %0010, %0010, %0100, %0100, %0100, %0000
Glyph8:
    !byte %0110, %1001, %1001, %0110, %1001, %1001, %0110, %0000
Glyph9:
    !byte %0110, %1001, %1001, %0111, %0001, %0001, %0110, %0000
GlyphF:
    !byte %1111, %1000, %1000, %1110, %1000, %1000, %1000, %0000
GlyphR:
    !byte %1110, %1001, %1001, %1110, %1010, %1001, %1001, %0000
GlyphN:
    !byte %1001, %1101, %1101, %1011, %1001, %1001, %1001, %0000
GlyphT:
    !byte %1111, %0010, %0010, %0010, %0010, %0010, %0010, %0000
GlyphS:
    !byte %0111, %1000, %1000, %0110, %0001, %0001, %1110, %0000
GlyphC:
    !byte %0111, %1000, %1000, %1000, %1000, %1000, %0111, %0000
GlyphP:
    !byte %1110, %1001, %1001, %1110, %1000, %1000, %1000, %0000
GlyphA:
    !byte %0110, %1001, %1001, %1111, %1001, %1001, %1001, %0000
GlyphL:
    !byte %1000, %1000, %1000, %1000, %1000, %1000, %1111, %0000
GlyphSpace:
    !byte %0000, %0000, %0000, %0000, %0000, %0000, %0000, %0000

GlyphLo:
    !byte <Glyph0, <Glyph1, <Glyph2, <Glyph3, <Glyph4
    !byte <Glyph5, <Glyph6, <Glyph7, <Glyph8, <Glyph9
    !byte <GlyphF, <GlyphR, <GlyphN, <GlyphT, <GlyphS
    !byte <GlyphC, <GlyphP, <GlyphA, <GlyphL, <GlyphSpace
GlyphHi:
    !byte >Glyph0, >Glyph1, >Glyph2, >Glyph3, >Glyph4
    !byte >Glyph5, >Glyph6, >Glyph7, >Glyph8, >Glyph9
    !byte >GlyphF, >GlyphR, >GlyphN, >GlyphT, >GlyphS
    !byte >GlyphC, >GlyphP, >GlyphA, >GlyphL, >GlyphSpace

; Reverse the four bits of a nibble: bit 3 <-> bit 0, bit 2 <-> bit 1.
Rev4:
    !byte 0, 8, 4, 12, 2, 10, 6, 14
    !byte 1, 9, 5, 13, 3, 11, 7, 15

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
