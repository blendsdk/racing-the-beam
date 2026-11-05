; =============================================================================
; LESSON 43 — EXERCISE 1 SOLUTION: A 16-Bit LFSR — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; EXERCISE 1: extend the LFSR state to two bytes with
;     ASL lo / ROL hi / BCC done / EOR #$2D on the low byte,
; and show that the period grows to 65,535 steps.  The screen still draws the
; low byte in the seed row and the history grid, and the meter still shows the
; low byte's high nibble.
;
; The 16-bit state:
;   RandomSeed   = $A0   the low byte (the library owns it; RandomPush pushes
;                        this byte into RandomHistory)
;   RandomSeedHi = $A9   the high byte, in free RAM just after the library
;
; Why 65,535?
;   The register has 2^16 = 65,536 states.  Zero is the fixed point, so the
;   longest possible cycle is 65,535.  The $2D polynomial is primitive for
;   the 16-bit Galois form, so the cycle is the full 65,535: every nonzero
;   16-bit value appears exactly once before the start value returns.
;   (The 8-bit $1D polynomial is the same story with 255.)
;
; The fire reseed now builds both bytes from the frame counters and replaces
; a zero pair with $5A/$00.  Joystick up/down still changes the low byte by
; one every frame while held.  Its zero guard is unconditional: a result of
; zero becomes $FF even when the high byte is nonzero, so the user can skip
; a valid low-byte-$00 state.  The generator itself can still reach low-byte
; $00 naturally; the guard only applies to user nudges.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), FireRead (A = INPT4),
;   SeedWrite (A = the low byte after a fire reseed),
;   RandomStep (A = the new low byte), RandomPush (A = the low byte pushed),
;   RandomMaskDone (A = low byte AND $01), BodyStart (37),
;   OverscanStart (229).  This is a playfield-only ROM: no HMOVE.
;
; Build: acme -f plain -o build/exercise-01-solution.bin \
;        lessons/part6-game-dev/43-random-numbers/exercise-01-solution.asm
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36

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

; --- Lesson variables (RAM $80-$87; +clean_start zeroes them) --------------
FrameLo      = $80   ; 16-bit frame counter, low byte (also the step clock)
FrameHi      = $81   ; frame counter, high byte (fire reseeds with both)
PrevFire     = $82   ; fire state last frame (1 = pressed)
NewFire      = $83   ; this frame's fire 0 -> 1 edge
BeepTimer    = $84   ; frames of beep remaining
BeepPitch    = $85   ; AUDF for the beep
MeterCount   = $86   ; RandomSeed >> 4, computed in VBLANK
MeterFirst   = $87   ; the first meter cell's PF1 byte ($20 or $00)
;
; $88-$9F are free for exercises.
; include/random.asm owns $A0-$A8 (RandomSeed + RandomHistory).
; $A9 is this exercise's high byte; $AA-$D7 are free; the stack is $F8-$FF.
RandomSeedHi = $A9   ; EXERCISE 1: the 16-bit seed's high byte

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
    LDA #$00
    STA RandomSeedHi        ; EXERCISE 1: the state starts at $005A
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
    JSR Random16
RandomStep:                 ; checkpoint: A = the new low byte
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
; 5. COLORS, CONTROL, AND THE FIRST LINE'S PRELOAD
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
    LDA #$01
    STA CTRLPF              ; mirror the playfield; ball one pixel wide
    LDA #$00
    STA PF0
    STA PF2
    LDA RandomSeed
    STA PF1

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

; --- visible 130-191: background ------------------------------------------
    LDA #$00
    STA PF1
    LDY #62
RestZone:
    STA WSYNC
    DEY
    BNE RestZone
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
; FireReseed — a fresh 16-bit seed from the two frame-counter bytes
; =============================================================================
; The low byte is FrameLo EOR FrameHi (the main ROM's mix); the high byte is
; FrameHi.  If both are zero, the pair becomes $005A, because the all-zero
; state is the 16-bit fixed point.  The checkpoint reloads the low byte so A
; always reports the value the display will show.
FireReseed:
    LDA FrameLo
    EOR FrameHi
    STA RandomSeed
    LDA FrameHi
    STA RandomSeedHi
    LDA RandomSeed
    ORA RandomSeedHi
    BNE Seed16Ready
    LDA #SEED_DEFAULT
    STA RandomSeed
Seed16Ready:
    LDA RandomSeed
SeedWrite:                  ; checkpoint: A = the new low byte
    RTS

; =============================================================================
; Random16 — one step of the 16-bit Galois LFSR; A = the new low byte
; =============================================================================
; ASL low shifts the low byte and puts its old bit 7 in the carry.  ROL high
; shifts the high byte through that carry (so the low bit of the high byte is
; the old bit 7 of the low byte) and puts the high byte's old bit 7 in the
; carry.  If that bit is one, the feedback XORs $2D into the low byte.  The
; final LDA makes the checkpoint's A the low byte regardless of the branch.
Random16:
    LDA RandomSeed
    ASL
    STA RandomSeed
    LDA RandomSeedHi
    ROL
    STA RandomSeedHi
    BCC Random16Done
    LDA RandomSeed
    EOR #$2D
    STA RandomSeed
Random16Done:
    LDA RandomSeed
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
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
