; =============================================================================
; LESSON 52 — EXERCISE 1 SOLUTION: Reverse the Scroll — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; EXERCISE 1: reverse the scroll.  The only change from the lesson source is
;   the scroll step: ScrollY is decremented once per frame instead of
;   incremented.  DEC wraps $00 to $FF, so the world scrolls down smoothly
;   without a special case; the 32-row sine makes the seam invisible.
;
; What this program does:
;   "the tunnel": a full-screen vertical scroller.  The world is three
;   page-aligned 256-byte playfield planes (WorldPF0, WorldPF1, WorldPF2).
;   Every visible line reads one byte from each plane at the same world row
;   (ScrollY + the visible row), so scrolling the world one line is just
;   changing ScrollY.  The playfield is reflected (CTRLPF=$01); the lit
;   chunks are the green walls and the unlit centre is the background gap.
;   The gap's half-width follows a 32-row sine: 4 + round(sin(2*pi*row/32)),
;   so the gap is 6, 8 or 10 chunks wide.  The 32-row period divides 256, so
;   world row 255 joins world row 0 cleanly.
;
;   The picture is one 1-line kernel for all 192 visible lines:
;
;     LDX ScrollY
;     LDY #0
;   Loop:
;     LDA WorldPF0,X / STA PF0
;     LDA WorldPF1,X / STA PF1
;     LDA WorldPF2,X / STA PF2
;     LDA ShipStrip,Y / STA GRP0
;     STA WSYNC
;     INX / INY / CPY #192 / BNE Loop
;
;   That is 40 cycles per line: three playfield load/store pairs (3 x 7 = 21),
;   the ship load/store (7), WSYNC (3) and the loop tail (INX 2 + INY 2 +
;   CPY 2 + BNE 3 = 9).  The 76-cycle line leaves 36 cycles of margin.  Every
;   plane is page-aligned and the ship strip is page-aligned, so X 255 -> 0
;   stays inside its plane and Y 0..191 stays inside the strip: no indexed
;   load pays a page cross.  This layout's BNE is page-local ($F0 -> $F0),
;   so the body stays 40; the base lesson and exercises 2/3 pay one page
;   cross and run at 41 effective.
;
;   The ship is a 16-byte (16-line) strip at rows 150-165, drawn on P0.  ShipX
;   moves one pixel per frame with the divide-by-15 + HMOVE positioning dance
;   and is clamped to 24..136.  The joystick's left/right overrides the
;   auto-demo; with no input the ship sweeps 24 -> 136 -> 24 at one pixel per
;   frame.
;
;   THE LATCH WINDOW.  The GRP0 store is the last register store before
;   WSYNC.  The base lesson's measured log puts its store at 35/37; this
;   layout's page-local BNE makes the tail 9 instead of 10, so the store runs
;   one cycle earlier at 34/36 and the new byte applies from TIA pixel
;   ~40-41.  A ship at X<=33 is entirely left of that point;
;   X=34..40 straddles; from X>=41 it is current.  These are derived from
;   this source's 40-cycle layout; the base lesson's X<=36/37..43/>=44 values
;   are the measured ones.  This is the same beam-race
;   trade-off Lesson 49 measures for its late stores; the lesson document
;   records the measured window.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), BodyStart (37), OverscanStart (229);
;   ScrollYWrite (A = the new ScrollY, counting down); WorldRead (A = a
;   WorldPF0 byte, $F0); ShipXRead (A = the ship's left edge); ShipWrite
;   (A = the ship byte at the GRP0 store); HmoveApply (the WSYNC stall),
;   HmoveDone (the NOP after the HMOVE store; the store completes at 3/2).
;
; RAM map (+clean_start zeroes every byte):
;   $80   ScrollY    the world row at the top of the screen, 0..255
;   $81   ShipX      the ship's left edge, TIA X 24..136
;   $82   ShipDir    the auto-demo's direction: 0 = left, 1 = right
;   $83   ShipHalf   the ship's step this frame: 1 here, 0/1 half speed
;   $84-$F7 free
;   $F8-$FF stack
;
; Build: acme -f plain -o build/exercise-01.bin \
;        lessons/part7-kernel-mastery/52-fine-scrolling/exercise-01-solution.asm
; Run:   stella build/exercise-01.bin
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

SCREEN_LINES   = 192     ; the 1-line kernel draws every visible line
WORLD_ROWS     = 256     ; each plane has one byte per world row
WORLD_PERIOD   = 32      ; the gap's sine repeats every 32 rows
SHIP_TOP       = 150     ; the ship's first visible row
SHIP_LINES     = 16      ; 16 bytes, one line per byte
SHIP_MIN       = 24      ; the ship's left limit (TIA X)
SHIP_MAX       = 136     ; the ship's right limit (8 pixels wide)
SHIP_START     = 80      ; power-on position; the auto-demo takes it from here

C_WALL         = $C8     ; the playfield walls: green
C_BG           = $02     ; the gap and the borders: the background
C_SHIP         = $0E     ; the ship: white

; The 32-row sine must divide the 256-row world exactly.  The !if turns
; that arithmetic into a build-time check rather than a comment.
!if WORLD_PERIOD * 8 != WORLD_ROWS {
    !error "the 32-row sine must fit eight times into the 256-row world"
}

; =============================================================================
; RAM ALLOCATION ($80-$83; +clean_start zeroes every byte)
; =============================================================================
ScrollY      = $80   ; the world row drawn at visible line 0, 0..255
ShipX        = $81   ; the ship's left edge, 24..136
ShipDir      = $82   ; the auto-demo's direction: 0 = left, 1 = right
ShipHalf     = $83   ; the per-frame step: 1 (0 or 1 in the half-speed lab)
;
; $84-$F7 are free (116 bytes).  The stack lives at $F8-$FF; the call depth
; stays at one level (SetCoarseP0).

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
    STA SWACNT              ; port A is an input port (the joystick)

    LDA #$00
    STA ScrollY             ; the first VBLANK step makes it 1
    LDA #SHIP_START
    STA ShipX               ; the ship starts in the middle
    LDA #$01
    STA ShipDir             ; the auto-demo sweeps right first
    STA ShipHalf            ; one pixel per frame

; --- the TIA's fixed state ---------------------------------------------------
    LDA #C_BG
    STA COLUBK              ; the gap shows the background
    LDA #C_WALL
    STA COLUPF              ; the walls are green
    LDA #C_SHIP
    STA COLUP0              ; the ship is white
    LDA #$01
    STA CTRLPF              ; reflect: the right half mirrors the left
    LDA #$00
    STA NUSIZ0              ; one 8-pixel copy of P0
    STA GRP0
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
; 1. THE SCROLL — one world row per frame, backwards; DEC wraps 0 -> 255
; -----------------------------------------------------------------------------
; ScrollY is the world row drawn at visible line 0.  Decrementing it moves
; every wall feature DOWN one scanline.  The 6502's DEC wraps $00 to $FF, so
; world row -1 is world row 255; the 32-row sine makes that seam invisible
; (row 255 and row 0 have the same half-width).
    DEC ScrollY
    LDA ScrollY
ScrollYWrite:               ; checkpoint: A = the new ScrollY

; -----------------------------------------------------------------------------
; 2. THE SHIP — joystick left/right, or the auto-demo's sweep
; -----------------------------------------------------------------------------
; SWCHA's P0 direction bits are active low.  The raw masks are $40 (left)
; and $80 (right); after AND #$C0, a left press reads $80 and a right press
; reads $40 (the other bit stays high).  $C0 is neither; $00 (both) is
; ignored.  The clamp keeps the 8-pixel ship inside TIA X 24..136.
    LDA SWCHA
    AND #$C0
    CMP #$C0
    BEQ AutoShip
    CMP #$80
    BEQ MoveLeft
    CMP #$40
    BEQ MoveRight
    JMP AutoShip            ; both directions held: treat as no input

MoveLeft:
    LDA ShipX
    CMP #SHIP_MIN
    BEQ MoveDone
    SEC
    SBC ShipHalf
    STA ShipX
    JMP MoveDone

MoveRight:
    LDA ShipX
    CMP #SHIP_MAX
    BEQ MoveDone
    CLC
    ADC ShipHalf
    STA ShipX
    JMP MoveDone

; The auto-demo: one pixel per frame between the limits.  At a limit the
; direction flips and the same frame steps back, so a full 24 -> 136 -> 24
; cycle is 112 + 112 = 224 frames.  (The first cycle is shorter because the
; ship powers on at SHIP_START.)
AutoShip:
    LDA ShipDir
    BNE AutoRight
    LDA ShipX
    CMP #SHIP_MIN
    BEQ AutoFlipRight
    SEC
    SBC ShipHalf
    STA ShipX
    JMP MoveDone
AutoRight:
    LDA ShipX
    CMP #SHIP_MAX
    BEQ AutoFlipLeft
    CLC
    ADC ShipHalf
    STA ShipX
    JMP MoveDone
AutoFlipLeft:
    LDA #$00
    STA ShipDir
    LDA ShipX
    SEC
    SBC ShipHalf
    STA ShipX
    JMP MoveDone
AutoFlipRight:
    LDA #$01
    STA ShipDir
    LDA ShipX
    CLC
    ADC ShipHalf
    STA ShipX
MoveDone:
    LDA ShipX
ShipXRead:                  ; checkpoint: A = the ship's left edge
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0

; -----------------------------------------------------------------------------
; 3. ONE HMOVE — the coarse reset is set, then one strobe
; -----------------------------------------------------------------------------
; SetCoarseP0 has set HMP0 and strobed RESP0.  The WSYNC starts a fresh line
; and HMOVE applies the fine offset in its HBLANK.  This is the only HMOVE in
; the frame, and it falls inside VBLANK, so its left-edge blanking is unseen.
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA WSYNC
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed
    NOP                     ; keep HmoveDone distinct from the timer poll

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines, one line per row, work-first
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0

; The row loop is the course's top-down form: LDY #0, draw row Y, then
; INY / CPY #192 / BNE.  Y is both the row counter and the ship-strip index,
; so row 0 is the top of the screen and row 191 is the bottom.  X is the
; world row: it starts at ScrollY and wraps 255 -> 0 inside the page-aligned
; planes.  There is no sentinel; the ship strip is exactly 192 bytes.
    LDX ScrollY
    LDY #0
KernelRow:                  ; checkpoint: Y = 0..191, the visible row
    LDA WorldPF0,X
WorldRead:                  ; checkpoint: A = the WorldPF0 byte ($F0)
    STA PF0                 ; chunks 0-3
    LDA WorldPF1,X
    STA PF1                 ; chunks 4-11
    LDA WorldPF2,X
    STA PF2                 ; chunks 12-19: the breathing inner edge
    LDA ShipStrip,Y
ShipWrite:                  ; checkpoint: A = the ship byte, at the GRP0 store
    STA GRP0                ; the ship's line for this row
    STA WSYNC               ; the line is complete; wait for the next
    INX                     ; next world row
    INY                     ; next visible row
    CPY #SCREEN_LINES
    BNE KernelRow
; 192 rows x 1 line = visible 0-191.  The last WSYNC releases the CPU on
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
; THE WORLD — three page-aligned 256-byte planes
; =============================================================================
; A playfield row is chunks 0-3 (PF0), 4-11 (PF1) and 12-19 (PF2); the
; reflection draws the mirror on the right.  The wall always covers chunks
; 0..14, so PF0 is $F0 and PF1 is $FF on every row; only PF2's inner edge
; moves.  The gap's half-width is 4 + round(sin(2*pi*row/32)):
;
;   half  gap   left wall  PF2     gap chunks
;   3     6     0..16      $1F     17..22
;   4     8     0..15      $0F     16..23
;   5     10    0..14      $07     15..24
;
; The 32-row period divides 256, so the table below is the same 32-byte
; period eight times.  Every plane is page-aligned: X 255 -> 0 wraps inside
; the plane, so no indexed load crosses a page.
    !align 255, 0
WorldPF0:
    !fill WORLD_ROWS, $F0

    !align 255, 0
WorldPF1:
    !fill WORLD_ROWS, $FF

    !align 255, 0
WorldPF2:
    ; world rows 0-15: half 4, 4, 4, then 5 from row 3
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    ; world rows 16-31: half 4, 4, 4, then 3 from row 19
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F
    ; rows 32-63: the same period again
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F
    ; rows 64-95
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F
    ; rows 96-127
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F
    ; rows 128-159
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F
    ; rows 160-191
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F
    ; rows 192-223
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F
    ; rows 224-255
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F

; =============================================================================
; THE SHIP STRIP — 192 bytes, one per visible line
; =============================================================================
; The 16 shape bytes sit at rows 150-165.  Each byte is one scanline (this is
; a 1-line kernel), so the ship is 16 lines tall: a pointed nose, a widening
; body, engine gaps and two tail fins.  The strip is page-aligned so Y 0..191
; never crosses a page.
    !align 255, 0
ShipStrip:
    !fill SHIP_TOP, $00
    !byte $18, $18, $3C, $3C, $7E, $7E, $FF, $FF
    !byte $E7, $E7, $C3, $C3, $81, $81, $18, $18
    !fill SCREEN_LINES - SHIP_TOP - SHIP_LINES, $00

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
