; =============================================================================
; LESSON 49, EXERCISE 2: Two Pixels per Frame — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; The exercise moves the figure two pixels per frame instead of one.  The
; clamp is unchanged (TIA X 8..144), and P0_STEP = 2 keeps every position
; even, so the clamp lands exactly on the limits.  The joystick branch uses
; SEC/SBC #2 on the left and CLC/ADC #2 on the right; the auto-demo uses the
; same step, so its sweep from 8 to 144 takes 68 frames each way.
;
; The kernel, the tables, the colours, the one-HMOVE positioning, and the
; 62/63 two-line ledger are the lesson's; this layout's BNE stays page-local,
; so its effective body is 62; only the movement code changes.
; P0XRead reports the value before the positioning dance, and HmoveDone
; fires once per frame because the frame still has one HMOVE.
;
; Checkpoints: StartFrame / VblankStart / BodyStart / OverscanStart /
; P0XRead / P1XRead / HmoveApply / HmoveDone / KernelRow / RowWrite /
; BirdWrite / JoyLeft / JoyRight.  Under the joystick the P0XRead A column
; moves by 2 per frame.
;
; Build: acme -f plain -o build/exercise-02.bin \
;        lessons/part7-kernel-mastery/49-two-line-kernel/exercise-02-solution.asm
; Run:   stella build/exercise-02.bin
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
P0_STEP        = 2       ; the exercise moves two pixels per frame
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
    SEC
    SBC #P0_STEP
    CMP #P0_MIN
    BCS LeftStore
    LDA #P0_MIN
LeftStore:
    STA P0X
    JMP MoveDone
MoveRight:
    LDA P0X
JoyRight:                   ; checkpoint: A = P0X on the right branch
    CLC
    ADC #P0_STEP
    CMP #(P0_MAX + 1)
    BCC RightStore
    LDA #P0_MAX
RightStore:
    STA P0X
    JMP MoveDone

; The auto-demo steps two pixels per frame between the same limits.  The
; sweep is 68 frames each way; the turn frames park the figure at 142/10
; and the next frame continues, so the extremes 144 and 8 are each shown
; for one frame.
AutoMove:
    LDA DemoDir
    BNE AutoRight
    LDA P0X
    CMP #P0_MIN
    BEQ AutoFlipRight
    SEC
    SBC #P0_STEP
    CMP #P0_MIN
    BCS AutoLeftStore
    LDA #P0_MIN
AutoLeftStore:
    STA P0X
    JMP MoveDone
AutoRight:
    LDA P0X
    CMP #P0_MAX
    BEQ AutoFlipLeft
    CLC
    ADC #P0_STEP
    CMP #(P0_MAX + 1)
    BCC AutoRightStore
    LDA #P0_MAX
AutoRightStore:
    STA P0X
    JMP MoveDone
AutoFlipLeft:
    LDA #$00
    STA DemoDir
    LDA #(P0_MAX - P0_STEP)
    STA P0X
    JMP MoveDone
AutoFlipRight:
    LDA #$01
    STA DemoDir
    LDA #(P0_MIN + P0_STEP)
    STA P0X
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
