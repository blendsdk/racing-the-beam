; =============================================================================
; LESSON 43 — EXERCISE 2 SOLUTION: A Random Ball — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; EXERCISE 2: use RandomMask with the mask $07 to place a ball at one of eight
; columns: X = 24 + 16 * (RandomSeed AND 7).  The ball is an 8-pixel-wide,
; 8-line block on visible lines 150-157; the rest of the display (seed row,
; history grid, meter) is the main ROM.
;
; Why a mask?
;   The 6502 has no divide instruction.  A general "seed modulo 8" would need
;   a loop of subtracts; a power-of-two range is one AND.  RandomMask returns
;   RandomSeed AND the mask, so $07 gives exactly the eight values 0-7.
;
; The ball:
;   CTRLPF bits 4-5 = 11 select the 8-pixel ball; bit 0 keeps the playfield
;   mirrored.  The ball shares COLUPF with the playfield and is gold.
;   RESBL and HMBL position it: the coarse strobe sets the 15-pixel block and
;   the fine nibble corrects the remainder.  The ball's output delay is one
;   clock shorter than a player's, so the target gets POS_BIAS+1 (4) and the
;   measured left edge lands on the requested X.
;   One HMOVE applies the fine offset; this is the only sprite in the ROM,
;   so the one-HMOVE rule is easy to keep.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), RandomStep (A = the new seed),
;   BallMask (A = seed AND $07), RandomPush, RandomMaskDone (A = seed AND $01),
;   BodyStart (37), HmoveApply/HmoveDone (one HMOVE per frame),
;   OverscanStart (229).
;
; Build: acme -f plain -o build/exercise-02-solution.bin \
;        lessons/part6-game-dev/43-random-numbers/exercise-02-solution.asm
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

BALL_MIN_X     = 24      ; the first of the eight columns
BALL_LINES     = 8       ; the ball is eight lines tall
BALL_BIAS      = POS_BIAS + 1 ; the ball's one-clock-shorter output delay

SEED_DEFAULT   = $5A     ; the nonzero seed used at reset and for a zero reseed
RANDOM_FRAMES  = 4       ; one LFSR step every fourth frame (FrameLo & 3 == 0)

BEEP_FRAMES    = 2       ; a two-frame tick, shorter than the four-frame step
BEEP_PITCH     = $04     ; AUDF 4 on AUDC $0C: a short, bright tick

METER_CELLS    = 15      ; the meter shows a nibble: 0-15 lit cells
METER_LINES    = 6       ; six visible lines per cell
METER_CHUNK    = $20     ; PF1 bit 5 = chunk 6 = X=24-27

C_GOLD         = $1A
C_GREEN        = $C8
C_BG           = $02

; --- Lesson variables (RAM $80-$88; +clean_start zeroes them) --------------
FrameLo      = $80   ; 16-bit frame counter, low byte (also the step clock)
FrameHi      = $81   ; frame counter, high byte (fire reseeds with both)
PrevFire     = $82   ; fire state last frame (1 = pressed)
NewFire      = $83   ; this frame's fire 0 -> 1 edge
BeepTimer    = $84   ; frames of beep remaining
BeepPitch    = $85   ; AUDF for the beep
MeterCount   = $86   ; RandomSeed >> 4, computed in VBLANK
BallX        = $87   ; EXERCISE 2: the ball's left edge, 24..136
MeterFirst   = $88   ; the first meter cell's PF1 byte ($20 or $00)
;
; $89-$9F are free for exercises.
; include/random.asm owns $A0-$A8 (RandomSeed + RandomHistory).
; $A9-$D7 are free; the stack lives at $F8-$FF.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; --- the shared random library ---------------------------------------------
; The library is assembled first, so its RAM symbols (RandomSeed at $A0 and
; RandomHistory at $A1-$A8) are known to this source before the first use.
; The RESET vector at $FFFC points at Reset, which follows the library.
    !source "include/random.asm"

; =============================================================================
; RESET — the program's entry point (it need not be the first ROM byte)
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the LFSR starts from a nonzero seed -----------------------------------
; clean_start has already zeroed $A0, so RandomInit's zero guard matters if
; an exercise or a warm reset ever leaves it zero.  The lesson uses $5A.
    LDA #SEED_DEFAULT
    JSR RandomInit
    LDA #BEEP_PITCH
    STA BeepPitch

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
; 1. THE 16-BIT FRAME COUNTER AND THE BEEP'S CLOCK
; -----------------------------------------------------------------------------
; FrameLo is the fast byte; every 256 frames it wraps and FrameHi advances.
; The low byte also gates the LFSR step (its low two bits), so the step lands
; on frames 4, 8, 12, ...  Fire uses both bytes to make a fresh seed.
    INC FrameLo
    BNE FrameCounted
    INC FrameHi
FrameCounted:

    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0               ; silence at the end of the tick
BeepClockDone:

; -----------------------------------------------------------------------------
; 2. FIRE — one reseed per 0 -> 1 edge
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while the fire button is pressed.  The EOR turns that into
; a 1, and the EOR/AND pair keeps only the new press, so holding the button
; does not reseed on every frame.
    LDA INPT4
FireRead:                   ; checkpoint: A = INPT4
    AND #$80
    EOR #$80                ; 1 = pressed
    STA NewFire
    EOR PrevFire
    AND NewFire
    STA NewFire             ; NewFire = pressed & ~wasPressed
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire

    LDA NewFire
    BEQ NoFireReseed
    JSR FireReseed
NoFireReseed:

; -----------------------------------------------------------------------------
; 3. JOYSTICK UP/DOWN — nudge the seed by one, but never to zero
; -----------------------------------------------------------------------------
; SWCHA is active low: 0 means the direction is pressed.  Bit 4 is P0 up and
; bit 5 is P0 down.  The code runs every VBLANK, so a held direction moves the
; seed once per frame (60 times a second), not once per press.  A result of
; zero is replaced by $FF; that keeps the LFSR out of its fixed point and
; makes the wrap visible as a full meter.
    LDA SWCHA
    AND #$10                ; P0 up
    BNE JoyUpDone
    INC RandomSeed
    BNE JoyUpDone           ; $FF + 1 = $00: use $FF instead
    LDA #$FF
    STA RandomSeed
JoyUpDone:

    LDA SWCHA
    AND #$20                ; P0 down
    BNE JoyDownDone
    DEC RandomSeed
    BNE JoyDownDone         ; $01 - 1 = $00: use $FF instead
    LDA #$FF
    STA RandomSeed
JoyDownDone:

; -----------------------------------------------------------------------------
; 4. THE LFSR STEP — every fourth frame
; -----------------------------------------------------------------------------
; The low two bits of FrameLo count 0..3; the branch skips the step while they
; are nonzero.  FrameLo is incremented at the top of VBLANK, so the first step
; is on frame 4.  RandomPush moves the new seed into the history grid, and
; RandomMask selects bit 0 for the beep.
    LDA FrameLo
    AND #(RANDOM_FRAMES - 1)
    BNE NoRandomStep
    JSR Random
RandomStep:                 ; checkpoint: A = the new seed
    JSR RandomPush
    LDA #$01
    JSR RandomMask
    BEQ NoRandomBeep
    LDA #BEEP_PITCH
    STA BeepPitch
    JSR BeepStart
NoRandomBeep:
NoRandomStep:

; --- the meter's count and first cell, computed in VBLANK -------------------
; Four LSRs give the high nibble.  MeterFirst is cell 14's PF1 byte ($20 when
; the count is 15, else $00); the kernel writes it before the first meter
; line's playfield slot.
    LDA RandomSeed
    LSR
    LSR
    LSR
    LSR                     ; A = RandomSeed >> 4 (0-15)
    STA MeterCount
    LDA #$00
    STA MeterFirst
    LDA MeterCount
    CMP #15
    BNE MeterFirstDone
    LDA #METER_CHUNK
    STA MeterFirst
MeterFirstDone:

; -----------------------------------------------------------------------------
; 5. EXERCISE 2: THE MASKED SEED CHOOSES THE BALL'S COLUMN
; -----------------------------------------------------------------------------
; RandomMask returns seed AND $07: one of eight columns.  Four ASLs multiply
; the column by 16, so the ball sits at 24, 40, 56, ..., 136.  The ball is
; repositioned every frame, so a new seed is a new column on the next frame.
    LDA #$07
    JSR RandomMask
BallMask:                   ; checkpoint: A = RandomSeed AND $07
    ASL
    ASL
    ASL
    ASL                     ; column * 16
    CLC
    ADC #BALL_MIN_X
    STA BallX

; -----------------------------------------------------------------------------
; 6. COLORS, CONTROL, AND THE FIRST LINE'S PRELOAD
; -----------------------------------------------------------------------------
; The seed row and the history grid are gold; the meter is green.  PF0 and
; PF2 stay zero, so only PF1's chunks 4-11 (and their mirror copies) are lit.
; The seed is stored in PF1 here as well as at BodyStart.  The kernel's first
; write lands at cycles 8-11 of visible line 0, well before PF1's first slot,
; so the preload is belt-and-braces rather than a necessity.
    LDA #C_GOLD
    STA COLUPF
    LDA #C_BG
    STA COLUBK
    LDA #$31                ; mirror + 8-pixel ball (CTRLPF bits 4-5 = 11)
    STA CTRLPF
    LDA #$00
    STA PF0
    STA PF2
    LDA RandomSeed
    STA PF1

; --- EXERCISE 2: position the ball, then one HMOVE -------------------------
; SetCoarseBL leaves the fine value in HMBL; the WSYNC below puts the HMOVE
; in the next HBLANK.  The ball's target gets BALL_BIAS (4), one more than a
; player's +3, because the ball's output delay is one clock shorter.
    LDA BallX
    CLC
    ADC #BALL_BIAS
    JSR SetCoarseBL
    STA WSYNC
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed (next line, cycle 3)

    +wait_timer

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
    LDA #$00
    STA VBLANK

BodyStart:                  ; checkpoint: scanline 37, visible line 0

; --- visible 0-7: the seed row ---------------------------------------------
; PF1 = RandomSeed for eight lines.  The preload above already put the byte
; in PF1; the reload here makes the loop's A explicit.
    LDA RandomSeed
    STA PF1
    LDY #8
SeedRow:
    STA WSYNC
    DEY
    BNE SeedRow

; --- visible 8-39: the history grid, 8 rows x 4 lines ----------------------
; Row 0 is the newest seed.  Each row is one PF1 byte held for four lines,
; so a lit cell is a 4-pixel-wide, 4-line-tall block.
    LDX #0
GridRow:
    LDA RandomHistory,X
    STA PF1
    LDY #4
GridLine:
    STA WSYNC
    DEY
    BNE GridLine
    INX
    CPX #8
    BNE GridRow

; --- visible 40-129: the meter, 15 cells x 6 lines -------------------------
; MeterCount and MeterFirst were computed in VBLANK.  The first store below
; puts cell 14's byte in PF1 at cycles 14-16 of visible line 40, before the
; playfield's first PF1 slot; the loop's first iteration rewrites the same
; byte.  The loop then walks cell 14 down to cell 0; a cell is lit when its
; index is below the count, so the bar grows from the bottom.  A lit cell
; writes PF1=$20 (chunk 6, X=24).
    LDA MeterFirst
    STA PF1
    LDA #C_GREEN
    STA COLUPF
    LDX #METER_CELLS        ; X = 15; the first DEX makes it cell 14
MeterCell:
    DEX
    CPX MeterCount
    LDA #$00
    BCS MeterDark           ; X >= count: this cell is dark
    LDA #METER_CHUNK        ; chunk 6: X=24-27
MeterDark:
    STA PF1
    LDY #METER_LINES
MeterLine:
    STA WSYNC
    DEY
    BNE MeterLine
    TXA
    BNE MeterCell
    ; the last cell (X=0) ends here; its six lines are lines 124-129

; --- visible 130-149: background (20 lines) -------------------------------
    LDA #C_GOLD
    STA COLUPF              ; the ball shares COLUPF with the playfield
    LDA #$00
    STA PF1
    STA ENABL               ; the ball is off outside its eight rows
    LDY #20
RestTop:
    STA WSYNC
    DEY
    BNE RestTop

; --- visible 150-157: the ball at BallX (8 rows) ---------------------------
; ENABL=2 turns the ball on; the write lands in HBLANK, before the ball's
; first pixel at X>=24, so the first visible row is 150.  The clear at line
; 158 lands before that row's pixel, so the last visible row is 157.
    LDA #$02
    STA ENABL
    LDY #BALL_LINES
BallZone:
    STA WSYNC
    DEY
    BNE BallZone

; --- visible 158-191: background (34 lines) -------------------------------
    LDA #$00
    STA ENABL
    LDY #34
RestBottom:
    STA WSYNC
    DEY
    BNE RestBottom
    JMP FrameEnd

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
FrameEnd:
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; FireReseed — one fresh seed from the two frame-counter bytes
; =============================================================================
; The EOR mixes the fast and slow bytes: FrameHi changes only every 256
; frames, so the XOR still gives a different byte for presses 256 frames
; apart.  RandomInit replaces a zero result with $5A, because a zero seed
; would freeze the LFSR.
FireReseed:
    LDA FrameLo
    EOR FrameHi             ; two frame bytes -> one fresh seed byte
    JSR RandomInit
SeedWrite:                  ; checkpoint: A = the seed actually stored
    RTS

; =============================================================================
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
; Called when the new seed's bit 0 is one.  AUDC 0C is the div-6 tone from
; Lesson 35; AUDV 0A is audible but not loud.  The timer silences the channel
; two frames later, so consecutive steps produce a short tick.
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
; SetCoarseBL — the divide-by-15 ball positioning from Lesson 26/39
; =============================================================================
; A = the target TIA X plus the ball's bias.  The low three bits of the
; remainder become the fine value; EOR #7 reverses them for HMBL's signed
; offset.  The coarse strobe and the fine value are set here; the caller's
; single HMOVE applies the offset.
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
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
