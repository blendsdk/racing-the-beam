; =============================================================================
; LESSON 43: Random Numbers — Unpredictable Fun — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; What this program does:
;   "the random lab": an 8-bit Galois LFSR runs in the background.  Every four
;   frames it takes one step, pushes the new byte into an eight-byte history,
;   and beeps when the new bit 0 is set.  The screen shows the current seed,
;   the last eight seeds, and a meter of seed >> 4.
;
; The screen (192 visible lines, CTRLPF=$01 so the playfield is mirrored):
;   visible 0-7     the seed row: PF1 = RandomSeed.  Eight 4-pixel cells
;                   (chunks 4-11, X=16-47); the mirror copy is at X=112-143.
;                   PF1 bit 7 is the leftmost cell, so the byte reads left to
;                   right as bit 7 ... bit 0.
;   visible 8-39    the history grid: eight rows of four lines.  Row 0 is
;                   RandomHistory+0 (the newest seed) and row 7 is +7 (the
;                   oldest).  PF1 = RandomHistory[row]; the same 4-pixel
;                   cells, so the grid is 32 pixels wide per half.
;   visible 40-129  the meter: fifteen 6-line cells.  Cell 14 is the top cell
;                   and cell 0 the bottom; the number of lit cells is
;                   RandomSeed >> 4 (0-15).  A lit cell writes PF1=$20, which
;                   is chunk 6 (X=24-27); the mirror copy is at X=132-135.
;   visible 130-191 background.
;   The zones total 8+32+90+62 = 192 lines; OverscanStart is scanline 229.
;
; The LFSR (include/random.asm):
;   RandomSeed = $A0, RandomHistory = $A1-$A8.
;   Random      LDA seed / ASL / BCC / EOR #$1D / STA seed.  One step visits
;               all 255 nonzero bytes before returning to the start; zero is
;               the fixed point, which is why RandomInit and the joystick
;               control both keep the seed nonzero.
;   RandomPush  shift the eight history bytes down and store the seed at +0.
;   RandomMask  A = mask, returns seed AND mask (the beep uses mask $01).
;   RandomInit  A = seed; zero becomes $5A.
;
; The controls:
;   Fire reseeds the generator from FrameLo EOR FrameHi.
;   Joystick up/down changes the seed by +1/-1 every frame while held; a
;   change that would produce zero stores $FF instead, because zero would
;   freeze the LFSR.
;   With no input the LFSR keeps stepping every four frames, so the captures
;   need no controller.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), FireRead (A = INPT4),
;   SeedWrite (A = the seed after a fire reseed),
;   RandomStep (A = the new seed), RandomPush (A = the seed pushed),
;   RandomMaskDone (A = seed AND $01), BodyStart (37),
;   OverscanStart (229).
;   This is a playfield-only lesson: there are no sprites, so there is no
;   HMOVE in this ROM.  The exercise-2 solution adds a ball and therefore
;   adds HmoveApply/HmoveDone.
;
; Build: acme -f plain -o build/lesson43.bin \
;        lessons/part6-game-dev/43-random-numbers/43-random-numbers.asm
; Run:   stella build/lesson43.bin     (click the screen to hear the beep)
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

; -----------------------------------------------------------------------------
; 5. THE METER'S COUNT, COMPUTED ONCE PER FRAME
; -----------------------------------------------------------------------------
; The high nibble is the meter's value.  Computing it here, in VBLANK, keeps
; the kernel's first meter line short: MeterFirst's PF1 store lands at cycles
; 14-16 of visible line 40, before PF1's first slot.  With the four LSRs and
; the setup inside the kernel, that first store would land at cycle ~30,
; after the slot, and line 40 would still show the last grid row.
    LDA RandomSeed
    LSR
    LSR
    LSR
    LSR                     ; A = RandomSeed >> 4 (0-15)
    STA MeterCount
; Cell 14 is the first meter cell (the top one).  It is lit only when the
; count is 15; precomputing its PF1 byte lets the kernel write it before the
; first meter line's playfield slot.
    LDA #$00
    STA MeterFirst
    LDA MeterCount
    CMP #15
    BNE MeterFirstDone
    LDA #METER_CHUNK
    STA MeterFirst
MeterFirstDone:

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
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
