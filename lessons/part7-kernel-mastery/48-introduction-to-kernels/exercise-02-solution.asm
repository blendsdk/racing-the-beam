; =============================================================================
; LESSON 48, EXERCISE 2: A Rectangle, Not a Diamond — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; The exercise replaces the diamond data with a solid rectangle, keeping the
; lesson's three modes and the same 96-row / 48-row kernels.  The rectangle
; is 96 pixels wide (24 playfield chunks, chunks 8-31) and 64 lines tall,
; centred in every 96-line zone: data rows 16-79 are $00/$0F/$FF and every
; other row is $00/$00/$00.
;
; The point is the edge test:
;   - the 1-line zone draws rows 16-79, one scanline per row, so the
;     rectangle's top and bottom edges are one scanline thick;
;   - the 2-line zone samples rows 0, 2, ..., 94, so the same rectangle is
;     64 lines tall but each row covers two scanlines: its edges are two
;     scanlines thick.
; The left and right edges are vertical and identical in both zones; the
; vertical detail is what the kernel resolution changes.  Shape reports 1.
;
; Build: acme -f plain -o build/exercise-02.bin \
;        lessons/part7-kernel-mastery/48-introduction-to-kernels/exercise-02-solution.asm
; Run:   stella build/exercise-02.bin
; =============================================================================

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

LINE_ROWS      = 96      ; rows in the 1-line table
PAIR_ROWS      = 48      ; rows in the 2-line table
MODE_COUNT     = 3       ; modes 0, 1, 2
DEMO_PERIOD    = 240     ; frames per mode in the auto-demo
DASH_MIN       = 8       ; the dash's left limit (TIA X)
DASH_MAX       = 144     ; the dash's right limit (TIA X)
DASH_START     = 72      ; the dash's power-on X

BEEP_FRAMES    = 2       ; a two-frame tick
BEEP_PITCH     = $08     ; AUDF 8 on AUDC $0C: a short, bright beep

C_GREEN        = $C8     ; the 1-line zones
C_GOLD         = $1A     ; the 2-line zones
C_WHITE        = $0E     ; both dashes
C_BG           = $02     ; the background
SHAPE          = 1       ; 1 = the exercise's rectangle (0 = the diamond)

; =============================================================================
; RAM ALLOCATION ($80-$8F; +clean_start zeroes every byte)
; =============================================================================
Mode         = $80   ; 0 = split, 1 = full 1-line, 2 = full 2-line
DemoTimer    = $81   ; frames left before the auto-demo advances the mode
DashX        = $82   ; both dashes' left edge, 8..144
DashDir      = $83   ; the auto-demo's sweep direction: 0 = left, 1 = right
PrevFire     = $84   ; fire state last frame (1 = pressed)
PrevSelect   = $85   ; SELECT state last frame (1 = pressed)
BeepTimer    = $86   ; frames of beep remaining
BeepPitch    = $87   ; AUDF for the beep
ZoneCount    = $88   ; 2 in the split, 1 in the full modes (the checkpoint)
LineCount    = $89   ; 96 in the split, 192 in the full 1-line mode
PairCount    = $8A   ; 48 in the split, 96 in the full 2-line mode
Pass         = $8B   ; 0/1: which copy of the table the full modes draw
Scratch      = $8C   ; SELECT's pressed state, then general scratch
NewFire      = $8D   ; this frame's fire 0 -> 1 edge
Startup      = $8E   ; frames left before the fire edge is trusted
Shape        = $8F   ; the Shape checkpoint: 1 for the rectangle
;
; $90-$F7 are free (104 bytes).  The stack lives at $F8-$FF; the call depth
; stays at one level (JSR SetCoarseP0 / SetCoarseP1 / AdvanceMode / BeepStart).

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
    STA SWACNT              ; port A is an input port (the joysticks)

    LDA #$00
    STA Mode                ; power on in the split view
    LDA #DEMO_PERIOD
    STA DemoTimer
    LDA #DASH_START
    STA DashX
    LDA #$01
    STA DashDir             ; sweep right first
    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #$08
    STA Startup             ; ignore the fire line while the console settles
    LDA #SHAPE
ShapeRead:                  ; checkpoint: A = 1 (the rectangle)
    STA Shape

    LDA #C_BG
    STA COLUBK              ; the background is $02
    LDA #$01
    STA CTRLPF              ; reflect the playfield: the right half mirrors the left
    LDA #C_WHITE
    STA COLUP0              ; both dashes are white
    STA COLUP1
    LDA #C_GREEN
    STA COLUPF              ; the first frame is mode 0's green top zone
    LDA #$00
    STA NUSIZ0              ; one 8-pixel copy of each player
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
; BeepTimer counts down every frame and silences channel 0 at zero.  The
; sound itself is not the lesson's subject; it is the same two-byte beep the
; rest of Part 6 and Part 7 uses.
    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0               ; silence at the end of the tick
BeepClockDone:

; -----------------------------------------------------------------------------
; 2. FIRE — cycle the mode on the 0 -> 1 edge
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  EOR turns that into a 1, and the
; EOR/AND pair keeps only a new press, so holding the button advances once.
    LDA INPT4
    AND #$80
    EOR #$80                ; 1 = pressed
    STA NewFire
    EOR PrevFire
    AND NewFire
    STA NewFire             ; NewFire = pressed & ~wasPressed

; The first frames after power-on are not trusted: INPT4 can read low while
; the console settles.  Startup counts eight frames; until it reaches zero
; the edge is forced clear.
    LDA Startup
    BEQ FireEdgeReady
    DEC Startup
    LDA #$00
    STA NewFire
FireEdgeReady:
    LDA NewFire
    BEQ NoFireEdge
    JSR AdvanceMode
    LDA #DEMO_PERIOD        ; a manual change restarts the auto-demo window
    STA DemoTimer
    JSR BeepStart
NoFireEdge:
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire

; -----------------------------------------------------------------------------
; 3. SELECT — reset to mode 0
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  The edge, not the level, resets the
; zoo.  SELECT is also the screenshot helper: a capture can start from mode 0
; without waiting for the auto-demo.
    LDA SWCHB
    AND #$02
    EOR #$02                ; 1 = pressed
    STA Scratch
    EOR PrevSelect
    AND Scratch
    BEQ NoSelectEdge
    LDA #$00
SelectReset:                ; checkpoint: A = 0, the new mode
    STA Mode
    LDA #DEMO_PERIOD
    STA DemoTimer
    JSR BeepStart
NoSelectEdge:
    LDA Scratch
    STA PrevSelect

; -----------------------------------------------------------------------------
; 4. THE AUTO-DEMO'S MODE CLOCK — one mode every 240 frames
; -----------------------------------------------------------------------------
; The auto-demo is what makes both screenshots reachable without a key press:
; mode 0 is the first 240 frames, mode 1 the next 240, mode 2 the next 240.
    DEC DemoTimer
    BNE NoAutoMode
    JSR AdvanceMode
    LDA #DEMO_PERIOD
    STA DemoTimer
NoAutoMode:

; -----------------------------------------------------------------------------
; 5. THE DASHES — joystick left/right, or the auto-demo's sweep
; -----------------------------------------------------------------------------
; SWCHA's P0 direction bits are active low.  The raw masks are $40 (left)
; and $80 (right); after AND #$C0, a left press reads $80 and a right press
; reads $40 (the other bit stays high).  $C0 is neither; $00 (both) is ignored.
; The clamp keeps the 8-pixel dash inside TIA X 8..144.
    LDA SWCHA
    AND #$C0
    CMP #$C0
    BEQ AutoDash
    CMP #$80
    BEQ DashLeft
    CMP #$40
    BEQ DashRight
    JMP AutoDash
DashLeft:
    LDA DashX
    CMP #DASH_MIN
    BEQ DashDone
    DEC DashX
    JMP DashDone
DashRight:
    LDA DashX
    CMP #DASH_MAX
    BEQ DashDone
    INC DashX
    JMP DashDone
AutoDash:
    LDA DashDir
    BNE AutoDashRight
    LDA DashX
    CMP #DASH_MIN
    BEQ AutoDashFlip
    DEC DashX
    JMP DashDone
AutoDashRight:
    LDA DashX
    CMP #DASH_MAX
    BEQ AutoDashFlip
    INC DashX
    JMP DashDone
AutoDashFlip:
    LDA DashDir
    EOR #$01
    STA DashDir
DashDone:

; -----------------------------------------------------------------------------
; 6. THE MODE'S COUNTERS — three bytes from one table
; -----------------------------------------------------------------------------
; ModeStates holds three bytes per mode: ZoneCount, LineCount, PairCount.
; The state log reads the three labels below; each reports A before its
; store, so the value is visible without watching RAM.
    LDA Mode
ModeRead:                   ; checkpoint: A = Mode
    ASL
    CLC
    ADC Mode                ; A = 3 * Mode
    TAX
    LDA ModeStates,X
ZoneCountRead:              ; checkpoint: A = ZoneCount
    STA ZoneCount
    LDA ModeStates+1,X
LineCountRead:              ; checkpoint: A = LineCount
    STA LineCount
    LDA ModeStates+2,X
PairCountRead:              ; checkpoint: A = PairCount
    STA PairCount

; -----------------------------------------------------------------------------
; 7. THE PLAYFIELD COLOUR — green for modes 0/1, gold for mode 2
; -----------------------------------------------------------------------------
; Mode 0 changes to gold again at the zone boundary, inside the kernel.
    LDA Mode
    CMP #$02
    BEQ ModeColorGold
    LDA #C_GREEN
    JMP ModeColorStore
ModeColorGold:
    LDA #C_GOLD
ModeColorStore:
    STA COLUPF

; -----------------------------------------------------------------------------
; 8. THE FIRST VISIBLE ROW'S PLAYFIELD — written before the picture turns on
; -----------------------------------------------------------------------------
; Every mode's first row is blank in the rectangle: PF0=0, PF1=0, PF2=$00
; (no chunks lit; the diamond tip's $80 would light chunks 19-20).  Writing
; it here means the mode dispatch and the first row's late stores cannot
; corrupt the first row: they write the same byte.
    LDA #$00
    STA PF0
    STA PF1
    LDA #$00
    STA PF2

; -----------------------------------------------------------------------------
; 9. POSITION BOTH PLAYERS, THEN STROBE ONE HMOVE
; -----------------------------------------------------------------------------
; Every coarse RESxx and every HMxx is set first; one WSYNC and one HMOVE
; apply both fine offsets in the same HBLANK (the one-HMOVE rule from
; Lesson 28).  The HMOVE blanks the left 8 pixels of the next line, which is
; still inside VBLANK, so the visible picture is unaffected.
    LDA DashX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA DashX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA WSYNC
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed (next line)

; -----------------------------------------------------------------------------
; 10. A CLEAN FIRST LINE
; -----------------------------------------------------------------------------
; The playfield was preloaded above; clear the two player graphics so the
; first row's dash slots are empty.  The dash rows are 24 and 36, far below
; the first row, so an empty GRP at the top is always correct.
    LDA #$00
    STA GRP0
    STA GRP1

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0

; --- the mode dispatch -----------------------------------------------------
; The branch chain costs 6-12 cycles, which is why the first row's playfield
; was preloaded in VBLANK.  Every target is a kernel with its own row loop.
    LDA Mode
    BEQ SplitKernel
    CMP #$01
    BEQ FullOneLineKernel
    JMP FullTwoLineKernel

; -----------------------------------------------------------------------------
; MODE 0 — THE SPLIT: 96 one-line rows, then 48 two-line rows
; -----------------------------------------------------------------------------
SplitKernel:
    LDY #0
SplitTopRow:
LineRow:                    ; checkpoint: Y = 0..95, the visible row
    LDA P0Strip1,Y          ; P0's one-byte-tall dash (row 24)
    STA GRP0
    LDA Rect1PF1,Y       ; the rectangle, one byte per scanline
    STA PF1
    LDA Rect1PF2,Y
    STA PF2
    LDA Rect1PF0,Y       ; $00 for this centred shape; written last
    STA PF0
    STA WSYNC               ; work-first: the row is complete, then wait
    INY
    CPY #LINE_ROWS
    BNE SplitTopRow
; 96 rows x 1 line = visible 0-95.  The CPU is now at the start of line 133.

; --- the zone boundary: visible 96 ------------------------------------------
; The colour changes to gold here, at the start of the 2-line zone.  The
; first 2-line row's top row is preloaded ($00/$00/$00) for the same reason
; the frame's first row was: the zone setup costs a few cycles.
    LDA #$00
    STA GRP0                ; P0 is not used in the bottom zone
    LDA #C_GOLD
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF1
    LDA #$00
    STA PF2

    LDY #0
SplitBottomRow:
PairRow:                    ; checkpoint: Y = 0..47, the 2-line row
    LDA P1Strip2,Y          ; P1's two-line dash (row 36 = visible 168-169)
    STA GRP1
    LDA Rect2PF1,Y       ; the same rectangle, one byte per two scanlines
    STA PF1
    LDA Rect2PF2,Y
    STA PF2
    LDA Rect2PF0,Y
    STA PF0
    STA WSYNC               ; line 1 of the pair
    STA WSYNC               ; line 2 of the pair
    INY
    CPY #PAIR_ROWS
    BNE SplitBottomRow
    JMP KernelDone
; 48 rows x 2 lines = visible 96-191.

; -----------------------------------------------------------------------------
; MODE 1 — FULL 1-LINE: the 96-row table twice
; -----------------------------------------------------------------------------
FullOneLineKernel:
    LDA #$00
    STA Pass
    LDY #0
Full1Row:
LineRow2:                   ; checkpoint: Y = 0..95, then 0..95 again
    LDA P0Strip1,Y
    STA GRP0
    LDA P1Strip1,Y          ; P1's one-line dash (row 72)
    STA GRP1
    LDA Rect1PF1,Y
    STA PF1
    LDA Rect1PF2,Y
    STA PF2
    LDA Rect1PF0,Y
    STA PF0
    STA WSYNC
    INY
    CPY #LINE_ROWS
    BNE Full1Row
    INC Pass
    LDA Pass
    CMP #$02
    BEQ KernelDone
    LDY #0
    JMP Full1Row
; 2 passes x 96 rows x 1 line = 192 lines.

; -----------------------------------------------------------------------------
; MODE 2 — FULL 2-LINE: the 48-row table twice
; -----------------------------------------------------------------------------
FullTwoLineKernel:
    LDA #$00
    STA Pass
    LDY #0
Full2Row:
PairRow2:                   ; checkpoint: Y = 0..47, then 0..47 again
    LDA P0Strip2,Y
    STA GRP0
    LDA P1Strip2,Y
    STA GRP1
    LDA Rect2PF1,Y
    STA PF1
    LDA Rect2PF2,Y
    STA PF2
    LDA Rect2PF0,Y
    STA PF0
    STA WSYNC
    STA WSYNC
    INY
    CPY #PAIR_ROWS
    BNE Full2Row
    INC Pass
    LDA Pass
    CMP #$02
    BEQ KernelDone
    LDY #0
    JMP Full2Row
; 2 passes x 48 rows x 2 lines = 192 lines.

KernelDone:

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
; AdvanceMode — the next mode, wrapping 2 -> 0
; =============================================================================
; A is the new mode when the routine returns.  ModeStep is after the store,
; so a breakpoint there reports the value the rest of the frame will use.
; Fire calls this and then BeepStart; the auto-demo calls it silently.
AdvanceMode:
    LDA Mode
    CLC
    ADC #$01
    CMP #MODE_COUNT
    BCC AdvanceStore
    LDA #$00
AdvanceStore:
    STA Mode
ModeStep:                   ; checkpoint: A = the new mode
    RTS

; =============================================================================
; SetCoarseP0 / SetCoarseP1 — the Lesson 26 divide-by-15 positioning dance
; =============================================================================
; A = the desired left edge + POS_BIAS.  Each routine starts on a fresh line,
; divides by 15 with repeated SBC, turns the remainder into the HMxx fine
; value, and strobes the matching RESxx.  The caller applies both with one
; HMOVE.
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

SetCoarseP1:
    STA WSYNC
    SEC
DivP1:
    SBC #15
    BCS DivP1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
    STA RESP1
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
; THE MODE TABLE — three bytes per mode
; =============================================================================
; ModeStates[3*Mode + 0] = ZoneCount
; ModeStates[3*Mode + 1] = LineCount
; ModeStates[3*Mode + 2] = PairCount
ModeStates:
    !byte 2, 96, 48         ; mode 0: two zones, 96 one-line rows, 48 pairs
    !byte 1, 192, 0         ; mode 1: one zone, 192 one-line rows, no pairs
    !byte 1, 0, 96          ; mode 2: one zone, no one-line rows, 96 pairs

; =============================================================================
; THE RECTANGLE DATA
; =============================================================================
; The shape is generated as data, not by the kernel.  Each row is three
; playfield bytes: PF0 (chunks 0-3), PF1 (chunks 4-11) and PF2 (chunks
; 12-19).  CTRLPF=$01 reflects the left half, so lighting chunks 8-19 draws
; a centred 96-pixel-wide rectangle.  PF0 stays $00 for this centred shape
; (nothing below chunk 8 is lit), but the plane is kept so the table really
; is 96 rows x 3 bytes = 288 bytes.
;
; The 2-line table is the 1-line table sampled at rows 0, 2, 4, ..., 94.
; That is the whole trade-off in one sentence: the same picture, half the
; data and half the vertical detail.  For the rectangle the sampled rows
; 16..78 still span 64 visible lines, but the top and bottom edges now cover
; two scanlines each.
    !align 255, 0
Rect1PF0:
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

Rect1PF1:
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
    !byte $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
    !byte $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
    !byte $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

Rect1PF2:
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

; ---------- exercise 2: 48-row rectangle (2-line) ----------
Rect2PF0:
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

Rect2PF1:
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
    !byte $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
    !byte $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $00, $00, $00, $00, $00, $00, $00, $00

Rect2PF2:
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00, $00, $00, $00, $00, $00, $00, $00

; --- the player strips: one byte per line (1-line) or per two lines (2-line)
; The dash is a solid 8-pixel byte ($FF).  P0's one-line dash is at row 24;
; P1's one-line dash is at row 72.  In the 2-line strips P0's dash is at row
; 24 and P1's at row 36.  Each strip is mostly $00; !fill builds the gaps.
P0Strip1:
    !fill 24, $00
    !byte $FF
    !fill 71, $00
P1Strip1:
    !fill 72, $00
    !byte $FF
    !fill 23, $00
P0Strip2:
    !fill 24, $00
    !byte $FF
    !fill 23, $00
P1Strip2:
    !fill 36, $00
    !byte $FF
    !fill 11, $00

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
