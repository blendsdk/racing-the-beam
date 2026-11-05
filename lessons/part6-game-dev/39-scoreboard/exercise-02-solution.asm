; =============================================================================
; LESSON 39 — EXERCISE 2 SOLUTION: Double Score
; =============================================================================
; Part 6: Game Development
;
; The exercise:
;   Call ScoreAddOne twice per hit, so every contact adds two points.
;
; The change:
;   The hit path calls ScoreAddOne twice instead of once.  The two calls are
;   independent: the first may carry through several digits and the second
;   starts again at the rightmost digit, so the carry still works when the
;   units digit passes through 9 (000098 + 2 = 000100).  The score starts at
;   000000; the first two captures read 000002 and 000004.
;
; What stays the same:
;   The kernel, the collision read, the respawn, the beep, and the auto-demo
;   are the main ROM's.  The hit still happens once per pass: the VBLANK read
;   plus CXCLR is the once-per-contact guard, so one contact produces one pair
;   of adds.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), ScoreInit (once at reset),
;   ScoreDigitWrite (A = position, X = digit), ScoreAdd (A = the digit after
;   the add; twice per hit), BallHit (A = $80), BodyStart (37),
;   ScoreDraw (the call), ScoreDrawRow (the first drawn row),
;   HmoveApply/HmoveDone (once per frame), OverscanStart (229).
;
; Build: acme -f plain -o build/ex39-2.bin \
;        lessons/part6-game-dev/39-scoreboard/exercise-02-solution.asm
; =============================================================================
;
; The two players make six digits:
;   NUSIZ0 = NUSIZ1 = 3  three copies, close spacing (16 pixels apart)
;   P0 at TIA X=56 -> copies at 56, 72, 88
;   P1 at TIA X=64 -> copies at 64, 80, 96
;   The copies interleave into six 8-pixel columns: 56..103.
;   VDELP0/VDELP1 = 1    a write stages a pending byte; the other player's
;                        write commits it, so each column can be placed just
;                        before its copy is drawn.
;
; The score zone (9 visible lines, visible 0-8):
;   line 0  setup/blank: the first row's bytes are loaded, then WSYNC
;   lines 1-8  the eight glyph rows, top (font byte 7) to bottom (byte 0)
;   the cleanup (GRP0/GRP1=0, VDEL off) shares line 8
;   Every glyph's bottom row is blank, so the lit block is seven lines tall.
;   include/score.asm owns ScoreDigits ($A0-$A5), ScoreBuf ($A8-$D7), and the
;   two scratch bytes $A6-$A7.
;
; The game zone (183 visible lines, visible 9-191):
;   visible 9-149    background (141 lines)
;   visible 150-157  the target (PF2=$F0 with CTRLPF=$01 -> X=64-95) and the
;                    ball (ENABL=2, one pixel wide, gold) on the same rows
;   visible 158-191  background (34 lines)
;   The target and the ball share COLUPF=$1A; the collision still latches
;   because ball and playfield are separate TIA objects.
;
; The score:
;   ScoreInit clears the digits and the buffer; ScoreClear draws 000000.
;   A hit calls ScoreAddOne, which carries 9 -> 0 across the six digits.
;   ScoreSetDigit copies one 8-byte glyph (bottom-up) into its column.
;
; The ball:
;   X starts at 24, moves 2 pixels per frame with the joystick, and clamps to
;   24..136.  With no joystick input it sweeps 24 -> 136 -> 24 by itself.
;   CXBLPF bit 7 (ball-playfield) is read in VBLANK, one frame after the
;   contact; the read is followed by CXCLR.  A hit adds one, beeps, and
;   respawns the ball at X=24.
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

BALL_MIN_X     = 24      ; the ball's left clamp
BALL_MAX_X     = 136     ; the ball's right clamp
BALL_Y         = 150     ; the ball's first visible row (8 rows tall)
TARGET_LINES   = 8       ; the target and the ball share these eight rows
TARGET_PF2     = $F0     ; PF2 bits 4-7: the center 32 pixels when reflected
BALL_ENABLE    = $02     ; ENABL bit 1
BEEP_FRAMES    = 8
BEEP_PITCH     = $08     ; AUDF 8 on AUDC $0C: a short, bright hit

C_WHITE        = $0E
C_GOLD         = $1A
C_BG           = $02

; --- Lesson variables (RAM $80-$9F; +clean_start zeroes them) ---
BallX       = $80   ; the ball's left edge, 24..136
BallDir     = $81   ; 1 = sweeping right, 0 = sweeping left
InputBits   = $82   ; this frame's SWCHA read
BeepTimer   = $83   ; frames of beep remaining
BeepPitch   = $84   ; AUDF for the beep
;
; The score library owns $A0-$D7:
;   ScoreDigits $A0-$A5, ScoreRow $A6, ScoreTmp $A7, ScoreBuf $A8-$D7.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start

    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the score starts at 000000 ---
    JSR ScoreInit           ; zero the digits and the 48-byte buffer
    JSR ScoreClear          ; build the six zero glyphs

; --- the ball starts at the left, sweeping right ---
    LDA #BALL_MIN_X
    STA BallX
    LDA #1
    STA BallDir
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
; 1. THE BEEP'S CLOCK — the last frame writes silence
; -----------------------------------------------------------------------------
    LDA BeepTimer
    BEQ BeepDone
    DEC BeepTimer
    BNE BeepDone
    LDA #$00
    STA AUDV0
BeepDone:

; -----------------------------------------------------------------------------
; 2. READ THE BALL-PLAYFIELD LATCH — the previous visible frame's contact
; -----------------------------------------------------------------------------
; CXBLPF bit 7 sets while the ball's drawn pixel and a playfield pixel share
; a color clock.  The read is in the next VBLANK, so it describes frame N
; while the program builds frame N+1: one frame of latency by construction.
    LDA CXBLPF              ; bit 7 only; the low bits are not defined
    AND #$80
    BEQ NoBallHit
BallHit:                    ; checkpoint: A = $80 when the ball hit the target
    JSR ScoreAddOne         ; add one, with a decimal carry
    JSR ScoreAddOne         ; exercise 2: and a second one
    JSR BeepStart           ; AUDC/AUDF/AUDV and the timer
    LDA #BALL_MIN_X
    STA BallX               ; respawn at the left edge
    LDA #1
    STA BallDir             ; and sweep right again
NoBallHit:
    LDA #$00
    STA CXCLR               ; the latches have done their job for this frame

; -----------------------------------------------------------------------------
; 3. THE BALL'S MOTION — the joystick, or the automatic sweep
; -----------------------------------------------------------------------------
    LDA SWCHA
    STA InputBits
    AND #$C0                ; P0 left (bit 6) and right (bit 7)
    CMP #$C0
    BEQ AutoSweep           ; neither pressed: run the demo

; --- manual: two pixels per frame, clamped to 24..136 ---
    LDA InputBits
    AND #$40                ; left
    BNE ManualRight
    LDA BallX
    SEC
    SBC #2
    CMP #BALL_MIN_X
    BCS ManualStore
    LDA #BALL_MIN_X
    JMP ManualStore
ManualRight:
    LDA InputBits
    AND #$80                ; right
    BNE ManualDone
    LDA BallX
    CLC
    ADC #2
    CMP #(BALL_MAX_X + 1)
    BCC ManualStore
    LDA #BALL_MAX_X
ManualStore:
    STA BallX
    JMP ManualDone

; --- auto-demo: 24 -> 136 -> 24, two pixels per frame ---
AutoSweep:
    LDA BallDir
    BNE AutoRight
    LDA BallX
    SEC
    SBC #2
    CMP #BALL_MIN_X
    BCS AutoStore
    LDA #BALL_MIN_X
    LDX #1
    STX BallDir             ; bounce off the left clamp
    JMP AutoStore
AutoRight:
    LDA BallX
    CLC
    ADC #2
    CMP #(BALL_MAX_X + 1)
    BCC AutoStore
    LDA #BALL_MAX_X
    LDX #0
    STX BallDir             ; bounce off the right clamp
AutoStore:
    STA BallX
ManualDone:

; -----------------------------------------------------------------------------
; 4. POSITION THE BALL AND THE SCORE, THEN ONE HMOVE
; -----------------------------------------------------------------------------
; The ball's reset is one color clock shorter than a player's, so its target
; needs one extra pixel (Lesson 29/38).  SetCoarseBL leaves HMBL ready;
; ScoreSetup sets HMP0/HMP1 and ends with the single HMOVE that applies all
; three fine offsets in one HBLANK.
    LDA BallX
    CLC
    ADC #(POS_BIAS + 1)
    JSR SetCoarseBL
    JSR ScoreSetup

; -----------------------------------------------------------------------------
; 5. COLORS AND PLAYFIELD CONTROL
; -----------------------------------------------------------------------------
    LDA #C_WHITE
    STA COLUP0              ; the score is white
    STA COLUP1
    LDA #C_GOLD
    STA COLUPF              ; the target and the ball are gold
    LDA #C_BG
    STA COLUBK
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA ENABL               ; the ball is off outside its eight rows
    LDA #$01
    STA CTRLPF              ; reflect the playfield; ball one pixel wide

    +wait_timer

; =============================================================================
; VISIBLE — 192 lines: the score zone (9) then the game zone (183)
; =============================================================================
    LDA #$00
    STA VBLANK

BodyStart:                  ; checkpoint: scanline 37, visible line 0
    JSR ScoreDraw           ; 9 lines: line 0 setup, lines 1-8 rows

; -----------------------------------------------------------------------------
; THE GAME ZONE — visible 9-191 (183 lines).  ScoreDraw returns on visible 9.
; -----------------------------------------------------------------------------
; The first game-zone line writes the blank playfield.  The same values are
; already in the registers; writing them here is the work-first line.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA ENABL

; --- visible 9-149: BALL_Y - 9 = 141 background lines ---
    LDY #(BALL_Y - 9)
TopBackground:
    STA WSYNC
    DEY
    BNE TopBackground

; --- visible 150-157: the target and the ball share these eight lines ---
; PF2=$F0 with CTRLPF bit 0 (reflect) is the center 32 pixels, X=64-95.
; ENABL=2 draws the ball's one-pixel column at BallX.
    LDA #TARGET_PF2
    STA PF2
    LDA #BALL_ENABLE
    STA ENABL
    LDY #TARGET_LINES
TargetLines:
    STA WSYNC
    DEY
    BNE TargetLines

; --- visible 158-191: 192 - BALL_Y - TARGET_LINES = 34 background lines ---
    LDA #$00
    STA PF2
    STA ENABL
    LDY #(192 - BALL_Y - TARGET_LINES)
BottomBackground:
    STA WSYNC
    DEY
    BNE BottomBackground

; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines
; -----------------------------------------------------------------------------
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
BeepStart:
    LDA #BEEP_FRAMES
    STA BeepTimer
    LDA #$0C                ; AUDC 0C: the div-6 tone from Lesson 35
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0
    RTS

; =============================================================================
; BALL COARSE POSITIONING — one RESBL, one HMBL, no HMOVE
; =============================================================================
; A = the target TIA X plus POS_BIAS + 1.  The +1 corrects the ball's
; one-clock-shorter reset.  ScoreSetup's single HMOVE applies HMBL.
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
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreInit, ScoreClear, ScoreSetup, ScoreSetDigit, ScoreAddOne, ScoreDraw,
; and ScoreFont live here.  The library must be sourced inside the ROM area
; (after * = $F000) and after include/vcs.asm.
    !source "include/score.asm"

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
