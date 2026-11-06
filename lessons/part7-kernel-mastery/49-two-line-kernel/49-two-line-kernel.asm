; =============================================================================
; LESSON 49: The 2-Line Kernel — The Mountain Pass — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; What this program does:
;   "the mountain pass": a full-screen 2-line kernel.  Every byte of picture
;   data covers two scanlines, so 96 rows fill the 192-line visible area.
;   Each row writes seven values:
;
;     PF0/PF1/PF2   the mountain silhouette (three 96-byte planes)
;     COLUPF        the mountain colour ramp (96 bytes)
;     COLUBK        the sky colour ramp (96 bytes)
;     GRP0          the figure strip (96 bytes, 8 shape bytes at rows 75-82)
;     GRP1          the bird strip   (96 bytes, 8 shape bytes at rows 30-37)
;
;   The mountain body fills playfield chunks 0..e-1 of the left half, where
;   e grows from 3 chunks at the top row to 20 at row 84.  CTRLPF=$01 reflects
;   the left half, so the same row draws two mountain walls with a sky pass
;   between them.  The pass narrows from 34 chunks at the top to 0 at row 84:
;   the top is a wide sunset sky, the bottom is the mountain floor.
;
;   P0 is a 16-line figure (8 bytes x 2) at strip rows 75-82, visible lines
;   150-165.  P1 is a 16-line bird at strip rows 30-37, visible lines 60-75.
;   The figure moves one pixel per frame with the joystick (left/right),
;   clamped to TIA X 8..144.  With no input a 272-frame auto-demo sweeps it
;   8 -> 144 -> 8 at one pixel per frame, so both extremes are reachable
;   without a key press.  The bird is fixed at X=104.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame is scanline 259, VblankStart 0, BodyStart 37, OverscanStart
;   229.  The kernel is work-first: write the row's registers, then wait.
;
; The kernel ledger (cycles; no page cross, the tables are page-aligned):
;   3 PF pairs        3 x 7 = 21
;   COLUPF                   7
;   COLUBK                   7
;   GRP0                     7
;   GRP1                     7
;   two STA WSYNC            6
;   INY + CPY #96 + BNE      7   (nominal; BNE 3)
;   taken-branch page cross +1  (BNE KernelRow crosses $F1 -> $F0)
;   ---------------------------------
;   total per two lines     62 nominal / 63 effective (31.5/line)
;   The two-line budget is 152 cycles, so the pair leaves 89 cycles of
;   margin (44.5 per line).  The second line is idle: its WSYNC waits it out.
;   Every 96-byte table below is page-aligned, so the indexed loads do not
;   add a page cross; the branch's page cross is counted above.
;
; Why the stores are in this order (it is not the order of the register
; list above):
;   The first line of a pair starts at cycle 0, but the loop tail of the
;   previous pair has already spent 8 cycles in steady state, so the first
;   store lands at cycle 15 (cycle 14 on the first row).  The TIA draws the
;   visible area from cycle 22.67.  GRP0 goes first because the figure's
;   left edge can be at X=8 (cycle 25.3): a late GRP0 (at about cycle 50 in
;   a playfield-first order) would put the previous row's byte on the first
;   line for any figure left of X=82.  PF0 and PF1 follow because chunks
;   0-11 start at cycles 22.7-28.  In steady state PF0 lands at 22 (pixel
;   -2, 2 px of margin); PF1 lands at 29 (pixel 19, 3 px into its chunk-4
;   field), and only the first PF1 step (row 8) shows a 3-px sky notch
;   because the later steps change a chunk at X>=20, after the store.
;   COLUPF is written at 36, so the first ~40 pixels of the mountain keep
;   the previous row's colour on the first scanline of a ramp step; PF2 is
;   next: chunk 12 starts at X=48 (cycle 38.7), and the store at 43 applies
;   from pixel 61, so the first ~13 px of the PF2 field keep the old byte
;   on the rows where the edge crosses chunks 12-19; COLUBK is written at
;   50, so the left part of the sky (up to ~70 pixels at the top rows)
;   keeps the old colour at a sky step; GRP1 is safe last because the
;   bird's fixed X=104 starts at cycle 57.3, one pixel of margin.  The
;   first row is one cycle earlier throughout (14/21/28/35/42/49/56); the
;   steady-state values above are the operative ones.  The second scanline
;   of every pair is always current: all seven latches hold until the next
;   row's stores.  The measured mountain edge matches the edge table exactly
;   on 74 of 84 rows and is within one chunk on the other 10; the model's
;   visible windows are row 8 and the PF2 rows 42/48/54, so the extra
;   measured rows sit at the capture's one-chunk threshold.
;   This is the beam-race trade-off the lesson measures; the 62/63 ledger
;   is unchanged by the order.
;
; Controls:
;   Joystick left/right moves the figure one pixel per frame, clamped to
;   X=8..144.  With no input the auto-demo sweeps the figure.  There is no
;   fire or SELECT action: this is a pure kernel lab.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), BodyStart (37), OverscanStart (229),
;   P0XRead / P1XRead (A = the players' left edges), JoyLeft / JoyRight
;   (A = P0X on the joystick branch), HmoveApply (the WSYNC stall),
;   HmoveDone (the store has executed), KernelRow (Y = 0..95),
;   RowWrite (A = the first row's P0 strip byte), BirdWrite (A = the first
;   row's P1 strip byte).  The RAM map is below.
;
; Build: acme -f plain -o build/lesson49.bin \
;        lessons/part7-kernel-mastery/49-two-line-kernel/49-two-line-kernel.asm
; Run:   stella build/lesson49.bin
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

ROW_COUNT      = 96      ; 96 rows x 2 scanlines = 192 visible lines

P0_MIN         = 8       ; the figure's left limit (TIA X)
P0_MAX         = 144     ; the figure's right limit (8 pixels wide)
P0_START       = 72      ; power-on position; the auto-demo takes it from here
P1_X           = 104     ; the bird's fixed left edge

C_FIGURE       = $42     ; P0: red
C_BIRD         = $0E     ; P1: white
C_BG           = $02     ; the borders before the first row is preloaded

; =============================================================================
; RAM ALLOCATION ($80-$82; +clean_start zeroes every byte)
; =============================================================================
P0X          = $80   ; the figure's left edge, 8..144
P1X          = $81   ; the bird's left edge (fixed at P1_X)
DemoDir      = $82   ; the auto-demo's direction: 0 = left, 1 = right
;
; $83-$F7 are free (117 bytes).  The stack lives at $F8-$FF; the call depth
; stays at one level (SetCoarseP0 / SetCoarseP1).

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

    LDA #P0_START
    STA P0X                 ; the figure starts in the middle
    LDA #P1_X
    STA P1X
    LDA #$01
    STA DemoDir             ; the auto-demo sweeps right first

    LDA #C_BG
    STA COLUBK
    LDA #C_FIGURE
    STA COLUP0
    LDA #C_BIRD
    STA COLUP1
    LDA #$01
    STA CTRLPF              ; reflect the playfield: the right half mirrors
    LDA #$00                ; the left half
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
; 1. THE FIGURE — joystick left/right, or the auto-demo's sweep
; -----------------------------------------------------------------------------
; SWCHA's P0 direction bits are active low.  The raw masks are $40 (left)
; and $80 (right); after AND #$C0, a left press reads $80 and a right press
; reads $40 (the other bit stays high).  $C0 is neither; $00 (both) is
; ignored.  The clamp keeps the 8-pixel figure inside TIA X 8..144.
    LDA SWCHA
    AND #$C0
    CMP #$C0
    BEQ AutoMove
    CMP #$80
    BEQ MoveLeft
    CMP #$40
    BEQ MoveRight
    JMP AutoMove            ; both directions held: treat as no input
MoveLeft:
    LDA P0X
JoyLeft:                    ; checkpoint: A = P0X on the left branch
    CMP #P0_MIN
    BEQ MoveDone
    DEC P0X
    JMP MoveDone
MoveRight:
    LDA P0X
JoyRight:                   ; checkpoint: A = P0X on the right branch
    CMP #P0_MAX
    BEQ MoveDone
    INC P0X
    JMP MoveDone

; The auto-demo: one pixel per frame between the limits.  At a limit the
; direction flips and the same frame steps back, so a full 8 -> 144 -> 8
; cycle is 136 + 136 = 272 frames.  (The first cycle is shorter because the
; figure powers on at P0_START; from then on the cycle is exactly 272.)
AutoMove:
    LDA DemoDir
    BNE AutoRight
    LDA P0X
    CMP #P0_MIN
    BEQ AutoFlipRight
    DEC P0X
    JMP MoveDone
AutoRight:
    LDA P0X
    CMP #P0_MAX
    BEQ AutoFlipLeft
    INC P0X
    JMP MoveDone
AutoFlipLeft:
    LDA #$00
    STA DemoDir
    DEC P0X
    JMP MoveDone
AutoFlipRight:
    LDA #$01
    STA DemoDir
    INC P0X
MoveDone:

; -----------------------------------------------------------------------------
; 2. POSITION BOTH PLAYERS, THEN STROBE ONE HMOVE
; -----------------------------------------------------------------------------
; Every coarse RESxx and every HMxx is set first; one WSYNC and one HMOVE
; apply both fine offsets in the same HBLANK (the one-HMOVE rule from
; Lesson 28).  The HMOVE blanks the left 8 pixels of the next line, which is
; still inside VBLANK, so the visible picture is unaffected.
    LDA P0X
P0XRead:                    ; checkpoint: A = P0X
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA P1X
P1XRead:                    ; checkpoint: A = P1X (104)
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA WSYNC
    STA HMOVE
HmoveDone:                  ; checkpoint: the HMOVE store has executed

; -----------------------------------------------------------------------------
; 3. PRELOAD THE FIRST ROW
; -----------------------------------------------------------------------------
; The previous frame left the TIA holding the last row's values.  The first
; row's colours and playfield are written here, before the picture turns on,
; so the first visible line is correct even though the kernel's later stores
; land a few cycles into it.  The kernel's own first-row stores repeat the
; same bytes.
    LDA P0Strip
    STA GRP0
    LDA P1Strip
    STA GRP1
    LDA MtnPF0
    STA PF0
    LDA MtnPF1
    STA PF1
    LDA MtnPF2
    STA PF2
    LDA MtnColor
    STA COLUPF
    LDA SkyColor
    STA COLUBK

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines, 96 rows x 2 scanlines, work-first
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0

; The row loop is the course's top-down form: LDY #0, draw row Y, then
; INY / CPY #96 / BNE.  Y is both the row counter and the table index, so
; row 0 is the top of the screen and row 95 is the bottom.  There is no
; sentinel: the tables are exactly 96 bytes.
    LDY #0
KernelRow:                  ; checkpoint: Y = 0..95, the visible row
    LDA P0Strip,Y
RowWrite:                   ; checkpoint: A = this row's figure byte
    STA GRP0                ; the figure: write before its X=8 deadline
    LDA MtnPF0,Y
    STA PF0                 ; chunks 0-3
    LDA MtnPF1,Y
    STA PF1                 ; chunks 4-11
    LDA MtnColor,Y
    STA COLUPF              ; the mountain colour for this row
    LDA MtnPF2,Y
    STA PF2                 ; chunks 12-19 (the inner edge)
    LDA SkyColor,Y
    STA COLUBK              ; the sky colour for this row
    LDA P1Strip,Y
BirdWrite:                  ; checkpoint: A = this row's bird byte
    STA GRP1                ; the bird at its fixed X
    STA WSYNC               ; line 1 of the pair ends here
    STA WSYNC               ; line 2 displays the same bytes
    INY
    CPY #ROW_COUNT
    BNE KernelRow
; 96 rows x 2 lines = visible 0-191.  The last WSYNC releases the CPU at
; the start of scanline 229, which is the first overscan line.

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
; THE TABLES — seven 96-byte planes, one byte per two scanlines
; =============================================================================
; Every table is page-aligned so a 96-row index (Y=0..95) never crosses a
; page: the kernel ledger needs no page-cross allowance.
;
; The mountain shape.  The body fills playfield chunks 0..e-1 of the left
; half; the reflection draws the mirror on the right.  e by row:
;
;   rows  0- 3  e=3    rows  4- 7  e=4    rows  8-11  e=5
;   rows 12-15  e=6    rows 16-19  e=7    rows 20-23  e=9  (a cliff)
;   rows 24-29  e=10   rows 30-35  e=11   rows 36-41  e=12
;   rows 42-47  e=13   rows 48-53  e=14   rows 54-59  e=15
;   rows 60-65  e=16   rows 66-71  e=17   rows 72-77  e=18
;   rows 78-83  e=19   rows 84-95  e=20 (the pass is closed)
;
; The sky pass is chunks e..(39-e): 34 chunks at the top, 2 at row 83, none
; from row 84.  The mountain colour is grey at the peaks and green at the
; floor; the sky is blue at the top and gold at the pass floor.
    !align 255, 0
MtnPF0:
    !byte $70, $70, $70, $70, $F0, $F0, $F0, $F0      ; rows  0- 7
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows  8-15
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 16-23
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 24-31
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 32-39
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 40-47
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 48-55
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 56-63
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 64-71
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 72-79
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 80-87
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 88-95

    !align 255, 0
MtnPF1:
    !byte $00, $00, $00, $00, $00, $00, $00, $00      ; rows  0- 7
    !byte $80, $80, $80, $80, $C0, $C0, $C0, $C0      ; rows  8-15
    !byte $E0, $E0, $E0, $E0, $F8, $F8, $F8, $F8      ; rows 16-23
    !byte $FC, $FC, $FC, $FC, $FC, $FC, $FE, $FE      ; rows 24-31
    !byte $FE, $FE, $FE, $FE, $FF, $FF, $FF, $FF      ; rows 32-39
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 40-47
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 48-55
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 56-63
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 64-71
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 72-79
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 80-87
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 88-95

    !align 255, 0
MtnPF2:
    !byte $00, $00, $00, $00, $00, $00, $00, $00      ; rows  0- 7
    !byte $00, $00, $00, $00, $00, $00, $00, $00      ; rows  8-15
    !byte $00, $00, $00, $00, $00, $00, $00, $00      ; rows 16-23
    !byte $00, $00, $00, $00, $00, $00, $00, $00      ; rows 24-31
    !byte $00, $00, $00, $00, $00, $00, $00, $00      ; rows 32-39
    !byte $00, $00, $01, $01, $01, $01, $01, $01      ; rows 40-47
    !byte $03, $03, $03, $03, $03, $03, $07, $07      ; rows 48-55
    !byte $07, $07, $07, $07, $0F, $0F, $0F, $0F      ; rows 56-63
    !byte $0F, $0F, $1F, $1F, $1F, $1F, $1F, $1F      ; rows 64-71
    !byte $3F, $3F, $3F, $3F, $3F, $3F, $7F, $7F      ; rows 72-79
    !byte $7F, $7F, $7F, $7F, $FF, $FF, $FF, $FF      ; rows 80-87
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 88-95

; The mountain colour: grey $0A at the top, dark green $C6 at the floor.
; Six 16-row bands: $0A, $0C, $C0, $C2, $C4, $C6.  Each row's COLUPF is a
; 96-byte table entry, written once per two scanlines.
    !align 255, 0
MtnColor:
    !byte $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A      ; rows  0- 7
    !byte $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A      ; rows  8-15
    !byte $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C      ; rows 16-23
    !byte $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C      ; rows 24-31
    !byte $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0      ; rows 32-39
    !byte $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0      ; rows 40-47
    !byte $C2, $C2, $C2, $C2, $C2, $C2, $C2, $C2      ; rows 48-55
    !byte $C2, $C2, $C2, $C2, $C2, $C2, $C2, $C2      ; rows 56-63
    !byte $C4, $C4, $C4, $C4, $C4, $C4, $C4, $C4      ; rows 64-71
    !byte $C4, $C4, $C4, $C4, $C4, $C4, $C4, $C4      ; rows 72-79
    !byte $C6, $C6, $C6, $C6, $C6, $C6, $C6, $C6      ; rows 80-87
    !byte $C6, $C6, $C6, $C6, $C6, $C6, $C6, $C6      ; rows 88-95

; The sky: dark blue $84 at the top, stepping through violet and red to
; gold $1A at the pass floor.  Ten 8-row bands plus a 16-row gold floor:
; $84, $86, $88, $78, $6E, $5E, $4E, $3E, $2E, $26, then $1A.
    !align 255, 0
SkyColor:
    !byte $84, $84, $84, $84, $84, $84, $84, $84      ; rows  0- 7
    !byte $86, $86, $86, $86, $86, $86, $86, $86      ; rows  8-15
    !byte $88, $88, $88, $88, $88, $88, $88, $88      ; rows 16-23
    !byte $78, $78, $78, $78, $78, $78, $78, $78      ; rows 24-31
    !byte $6E, $6E, $6E, $6E, $6E, $6E, $6E, $6E      ; rows 32-39
    !byte $5E, $5E, $5E, $5E, $5E, $5E, $5E, $5E      ; rows 40-47
    !byte $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E      ; rows 48-55
    !byte $3E, $3E, $3E, $3E, $3E, $3E, $3E, $3E      ; rows 56-63
    !byte $2E, $2E, $2E, $2E, $2E, $2E, $2E, $2E      ; rows 64-71
    !byte $26, $26, $26, $26, $26, $26, $26, $26      ; rows 72-79
    !byte $1A, $1A, $1A, $1A, $1A, $1A, $1A, $1A      ; rows 80-87
    !byte $1A, $1A, $1A, $1A, $1A, $1A, $1A, $1A      ; rows 88-95

; The figure strip: eight shape bytes at rows 75-82, so visible lines
; 150-165.  Each byte covers two scanlines.  The shape is a small person:
; head, shoulders, arms, body, and two legs.
    !align 255, 0
P0Strip:
    !fill 75, $00
    !byte $18, $3C, $7E, $5A, $18, $3C, $66, $C3
    !fill 13, $00

; The bird strip: eight shape bytes at rows 30-37, so visible lines 60-75.
; The wings are spread; the body is centred.
    !align 255, 0
P1Strip:
    !fill 30, $00
    !byte $00, $44, $6C, $7E, $3C, $18, $00, $00
    !fill 58, $00

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
