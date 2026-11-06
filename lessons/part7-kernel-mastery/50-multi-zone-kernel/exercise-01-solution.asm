; =============================================================================
; LESSON 50, EXERCISE 1: Resize the Status Zone — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; The exercise keeps the dashboard's four zones and gives the status zone four
; more lines, taken from the play zone:
;
;     visible   0-  8   score     9 lines
;     visible   9- 20   status   12 lines   (the gold level bar, 4 lines taller)
;     visible  21-190   play    170 lines   (85 rows x 2)
;     visible 191       ground    1 line
;                       ----------------
;                       9 + 12 + 170 + 1 = 192
;
;   StatusStart is unchanged at 46 (37+9).  PlayStart moves from 54 to 58
;   (37+21), and GroundStart stays 228 (37+191).  Only two constants change:
;   STATUS_LINES 8 -> 12 and PLAY_ROWS 87 -> 85; FIELD_END, P0_TOP and the
;   strip sizes follow.  STATUS_WAIT becomes STATUS_LINES - 5 = 7, so the wait
;   loop after GameHmove covers seven status lines instead of three.
;
;   The positioning dance is untouched.  SetGameP0 and SetGameP1 each consume
;   exactly two scanlines because each ends with a WSYNC (the divide-by-15
;   loop's length cannot move PlayStart), the caller's WSYNC ends status line
;   50, and GameHmove applies the fine offsets on status line 51.  The bar's
;   PF values stay latched through the wait loop.
;
;   The play zone keeps its three sub-bands: ceiling 4 rows (8 lines), field
;   77 rows (154 lines), floor 4 rows (8 lines).  P0's sixteen strip bytes
;   start at P0_TOP = FIELD_END - 16 = 65 and cover 32 scanlines (visible
;   151-182), so its feet stay just above the floor at row 81.  The ball
;   still falls from top 24 to 158; the last top line 158 covers play lines
;   158-165, inside the 170-line play zone, and the player's head is at
;   row 65.
;
; Checkpoints: the base's StartFrame (259), VblankStart (0), BodyStart (37),
; StatusStart (46), PlayStart (58), GroundStart (228), OverscanStart (229),
; ScoreDraw, ScoreAdd, ScoreHmove, ScoreHmoveDone, GameHmove (status line
; 51), LevelWrite, BallYRead, JoyLeft and JoyRight.
;
; Build: acme -f plain -o build/exercise-01.bin \
;        lessons/part7-kernel-mastery/50-multi-zone-kernel/exercise-01-solution.asm
; Run:   stella build/exercise-01.bin     (click the screen to hear the beep)
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

; --- the zone line counts (they must total 192) ------------------------------
STATUS_LINES   = 12       ; visible 9-20
PLAY_ROWS      = 85      ; visible 21-190: 85 rows x 2 scanlines = 170 lines
CEIL_ROWS      = 4       ; play rows 0-3: the ceiling
FLOOR_ROWS     = 4       ; play rows 81-84: the floor
FIELD_END      = PLAY_ROWS - FLOOR_ROWS   ; first floor row (81)
P0_TOP         = FIELD_END - 16           ; P0's first strip byte (65)
STATUS_WAIT    = STATUS_LINES - 5         ; the WSYNCs after GameHmove

; --- the level clock ---------------------------------------------------------
LEVEL_FRAMES   = 120     ; frames per level step
LEVEL_MAX      = 15      ; the bar is full at level 15

; --- the ball -----------------------------------------------------------------
BALL_START_Y   = 24      ; the ball's top line at respawn
BALL_END_Y     = 158     ; the last top line before a miss
BALL_X         = 80      ; the ball's fixed TIA X

; --- the players --------------------------------------------------------------
P0_MIN         = 8       ; the player's left limit (TIA X)
P0_MAX         = 144     ; the player's right limit (8 pixels wide)
P0_START       = 76      ; power-on: the ball at 80 is centred on the player
PLAYER_CENTRE  = 4       ; the ball's column inside the 8-pixel player
P1_MIN         = 48      ; the enemy's left limit (GRP1 is safe before 38.7)
P1_MAX         = 112     ; the enemy's right limit
P1_START       = 48

; --- the beep -----------------------------------------------------------------
BEEP_FRAMES    = 8
BEEP_PITCH     = $08

; --- colours ------------------------------------------------------------------
C_PLAYER       = $42     ; P0: red
C_ENEMY        = $C8     ; P1: green
C_WHITE        = $0E     ; the score digits
C_GOLD         = $1A     ; the status bar, the ball, the field, the floor
C_CEILING      = $0C     ; the ceiling: light grey
C_GROUND       = $C4     ; the ground line: dark green
C_BG           = $02     ; the background

; =============================================================================
; RAM ALLOCATION ($80-$88; +clean_start zeroes every byte)
; =============================================================================
P0X          = $80   ; the player's left edge, 8..144
P1X          = $81   ; the enemy's left edge, 48..112
P1Dir        = $82   ; 0 = sweeping left, 1 = sweeping right
BallY        = $83   ; the ball's top visible line in the play zone
BallRow      = $84   ; BallY >> 1: the first of the ball's four kernel rows
Level        = $85   ; 0..15
LevelTimer   = $86   ; frames since the last level step
BeepTimer    = $87   ; frames of beep remaining
BeepPitch    = $88   ; AUDF0 for the beep
;
; $89-$9F are free.  The score library owns $A0-$D7; $D8-$F7 is free.

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

    JSR ScoreInit           ; zero the six digits and the 48-byte buffer
    JSR ScoreClear          ; build the six zero glyphs: the score reads 000000

    LDA #P0_START
    STA P0X                 ; the player starts centred under the ball
    LDA #P1_START
    STA P1X
    LDA #$01
    STA P1Dir               ; the enemy sweeps right first
    LDA #BALL_START_Y
    STA BallY
    LDA #BEEP_PITCH
    STA BeepPitch

    LDA #C_BG
    STA COLUBK
    LDA #C_GOLD
    STA COLUPF
    LDA #$01
    STA CTRLPF              ; reflect the playfield; the ball is one pixel
    LDA #$00                ; the left half
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL
    STA NUSIZ0
    STA NUSIZ1

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
; 1. THE BEEP'S CLOCK — the last beep frame writes silence
; -----------------------------------------------------------------------------
    LDA BeepTimer
    BEQ BeepDone
    DEC BeepTimer
    BNE BeepDone
    LDA #$00
    STA AUDV0
BeepDone:

; -----------------------------------------------------------------------------
; 2. THE LEVEL CLOCK — every 120 frames Level++ (cap 15)
; -----------------------------------------------------------------------------
; LevelTimer counts 0..119 and wraps.  When the level is already 15 the clock
; keeps running but the level stays there: the bar is full.
    INC LevelTimer
    LDA LevelTimer
    CMP #LEVEL_FRAMES
    BCC LevelDone
    LDA #$00
    STA LevelTimer
    LDA Level
    CMP #LEVEL_MAX
    BEQ LevelDone
    INC Level
    LDA Level
LevelWrite:                 ; checkpoint: A = the new level
    NOP                     ; the label sits on the change path only
LevelDone:

; -----------------------------------------------------------------------------
; 3. THE BALL'S FALL — one visible line per frame, respawn at the bottom
; -----------------------------------------------------------------------------
; BallY is in visible play-zone lines and runs 24..158.  The kernel draws a
; 2-line row, so BallRow = BallY >> 1 quantises the top: the ball steps two
; lines every second frame, which is the vertical resolution of the kernel.
; At 158 the ball has reached its last top line; without a hit it respawns.
    LDA BallY
BallYRead:                  ; checkpoint: A = BallY before the step
    CMP #BALL_END_Y
    BCC BallStep
    LDA #BALL_START_Y
    STA BallY
    JMP BallMoved
BallStep:
    INC BallY
BallMoved:
    LDA BallY
    LSR
    STA BallRow

; -----------------------------------------------------------------------------
; 4. THE COLLISION — CXP0FB bit 6 (P0-ball), read in the next VBLANK
; -----------------------------------------------------------------------------
; The latch describes the visible frame that just ended, so the hit is always
; one frame late by construction.  CXCLR clears every latch after the read.
    LDA CXP0FB
    AND #$40                ; bit 6: player 0 met the ball
    BEQ NoHit
    JSR ScoreAddOne         ; add one, with a decimal carry
    JSR BeepStart           ; AUDC/AUDF/AUDV and the beep timer
    LDA #BALL_START_Y
    STA BallY               ; respawn at the top of the field
    LDA #BALL_START_Y
    LSR
    STA BallRow
NoHit:
    LDA #$00
    STA CXCLR               ; the latches have done their job for this frame

; -----------------------------------------------------------------------------
; 5. P0 — the joystick, or the auto-demo seeking the ball
; -----------------------------------------------------------------------------
; SWCHA's P0 direction bits are active low.  The raw masks are $40 (left) and
; $80 (right); after AND #$C0 a left press reads $80 and a right press reads
; $40.  Map $80 to DEC and $40 to INC; clamp TIA X 8..144.
    LDA SWCHA
    AND #$C0
    CMP #$C0
    BEQ AutoSeek            ; neither pressed: run the demo
    CMP #$80
    BEQ MoveLeft
    CMP #$40
    BEQ MoveRight
    JMP AutoSeek            ; both directions held: treat as no input
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

; The auto-demo: aim four pixels left of the ball, so the ball's column falls
; inside the player's 8-pixel top row, then step one pixel per frame.  The
; seek target is clamped to the player's travel.
AutoSeek:
    LDA #BALL_X
    SEC
    SBC #PLAYER_CENTRE      ; the ball's column inside the player
    CMP #P0_MIN
    BCS AutoSeekHigh
    LDA #P0_MIN
AutoSeekHigh:
    CMP #(P0_MAX + 1)
    BCC AutoSeekCompare
    LDA #P0_MAX
AutoSeekCompare:
    CMP P0X
    BEQ MoveDone
    BCC AutoSeekLeft
    INC P0X
    JMP MoveDone
AutoSeekLeft:
    DEC P0X
MoveDone:

; -----------------------------------------------------------------------------
; 6. P1 — the sweep, 48 -> 112 -> 48, one pixel per frame
; -----------------------------------------------------------------------------
    LDA P1Dir
    BNE P1Right
    LDA P1X
    CMP #P1_MIN
    BEQ P1FlipRight
    DEC P1X
    JMP P1Done
P1Right:
    LDA P1X
    CMP #P1_MAX
    BEQ P1FlipLeft
    INC P1X
    JMP P1Done
P1FlipLeft:
    LDA #$00
    STA P1Dir
    DEC P1X
    JMP P1Done
P1FlipRight:
    LDA #$01
    STA P1Dir
    INC P1X
P1Done:

; -----------------------------------------------------------------------------
; 7. POSITION THE BALL AND THE SCORE — ONE HMOVE IN VBLANK
; -----------------------------------------------------------------------------
; The ball's reset is one colour clock shorter than a player's, so its target
; carries one extra pixel (Lesson 29/39).  SetCoarseBL leaves HMBL and RESBL
; ready; ScoreSetup sets HMP0/HMP1 and ends with ONE HMOVE that applies the
; ball's fine offset and both players' score positions together (ScoreHmove).
    LDA #BALL_X
    CLC
    ADC #(POS_BIAS + 1)
    JSR SetCoarseBL
    JSR ScoreSetup          ; the score's HMOVE = ScoreHmove (the library's HmoveApply)

; -----------------------------------------------------------------------------
; 8. THE SCORE ZONE'S COLOURS AND CONTROLS
; -----------------------------------------------------------------------------
; The score digits are white; the status bar that follows is gold; the
; background is $02.  PF and ENABL are blank: the score kernel draws only the
; players.  NUSIZ/VDEL were set by ScoreSetup for the 48-pixel score.
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    LDA #C_GOLD
    STA COLUPF
    LDA #C_BG
    STA COLUBK
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA ENABL
    STA GRP0
    STA GRP1
    LDA #$01
    STA CTRLPF              ; reflect the playfield; the ball is one pixel

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE LINE 0-8: THE SCORE ZONE (9 lines)
; =============================================================================
; ScoreDraw consumes nine visible lines: line 0 is the setup/blank line, the
; rows are displayed on lines 1-8, and the cleanup shares line 8.  The kernel
; is WSYNC-first by design (the Staugas 48-pixel kernel, Lesson 39).  The
; library's entry label is the ScoreDraw checkpoint.
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    JSR ScoreDraw

; =============================================================================
; VISIBLE LINE 9-20: THE STATUS ZONE (12 lines)
; =============================================================================
; ScoreDraw's cleanup spills five cycles into visible line 9, so the status
; writes start at scanline 46 cycle ~5.  Their pixel deadlines are chunk 0 at
; cycle 22.7 (PF0), chunk 4 at 28.0 (PF1) and chunk 12 at 38.7 (PF2); the
; stores land at about 16, 23 and 30, so the first bar line is clean.
StatusStart:                ; checkpoint: scanline 46, visible line 9
    LDX Level
    LDA LevelPF0,X
    STA PF0                 ; chunks 0-3 of the bar
    LDA LevelPF1,X
    STA PF1                 ; chunks 4-11 of the bar
    LDA LevelPF2,X
    STA PF2                 ; chunks 12-19 of the bar

    LDA #C_PLAYER
    STA COLUP0              ; the game's player is red
    LDA #C_ENEMY
    STA COLUP1              ; the enemy is green
    LDA #$00
    STA NUSIZ0              ; one 8-pixel copy each (the score used three)
    STA NUSIZ1

; --- reposition P0 and P1 for the game, one player per line -----------------
; Each routine ends with a WSYNC, so it consumes exactly two scanlines no
; matter how long the divide-by-15 loop runs.  That keeps the status zone's
; line count fixed for every player X.
    LDA P0X
    CLC
    ADC #POS_BIAS
    JSR SetGameP0           ; status line 46: WSYNC, line 47: the P0 division
    LDA P1X
    CLC
    ADC #POS_BIAS
    JSR SetGameP1           ; status line 48: WSYNC, line 49: the P1 division
    LDA #$00
    STA HMBL                ; >24 cycles after ScoreHmove; GameHmove must not shift it


    STA WSYNC               ; status line 50 ends here
    NOP                     ; the WSYNC releases the CPU on status line 51
GameHmove:                  ; checkpoint: status line 51, the game's HMOVE
    STA HMOVE               ; applies HMP0/HMP1; HMBL is zero
; The HMOVE blanks the left 8 pixels of line 51.  The bar starts at chunk 2
; (pixel 8), so the blanking falls on background.

; The rest of the status zone: the bar's registers are latched and no writes
; change them.  STATUS_WAIT ends the remaining status lines and releases the
; CPU on PlayStart.
    LDX #STATUS_WAIT
StatusWait:
    STA WSYNC
    DEX
    BNE StatusWait

; =============================================================================
; PlayRow — one play row (two scanlines), work-first
; =============================================================================
; The macro is expanded once per sub-band.  Y is both the row counter and the
; table index; the caller owns INY / CPY / BNE.
;
;   GRP0  7   the player: first (P0's left edge can be TIA X=8)
;   GRP1  7   the enemy: P1's left limit is X=48, first pixel 38.7
;   ENABL 5   start with the ball off
;   test  9+2/7  Y - BallRow < 4 turns the ball on for its four rows
;   WSYNC 6   line 1 and line 2 of the row
;
; The ball test is a plain zero-page SBC and a carry test, not a table: the
; ball's four rows move every frame, so a ROM table cannot hold them and an
; 85-byte RAM table does not fit beside the 48-byte score buffer.
!macro PlayRow {
    LDA P0Strip,Y
    STA GRP0
    LDA P1Strip,Y
    STA GRP1
    LDA #$00
    STA ENABL
    TYA
    SEC
    SBC BallRow
    CMP #$04
    BCS .NoBall
    LDA #$02
    STA ENABL
.NoBall:
    STA WSYNC
    STA WSYNC
}

; =============================================================================
; VISIBLE LINE 21-190: THE PLAY ZONE (170 lines = 85 rows x 2)
; =============================================================================
; The play zone has three sub-bands with constant registers.  The playfield
; bytes and COLUPF are written once at each band's first line, before chunk
; 0's cycle 22.7, so no band boundary bleeds into the visible area.
PlayStart:                  ; checkpoint: scanline 58, visible line 21
    LDY #0

; --- the ceiling: play rows 0-3 (visible 21-28) ------------------------------
    LDA #C_CEILING
    STA COLUPF              ; the ceiling is grey
    LDA #$F0
    STA PF0                 ; chunks 0-3
    LDA #$FF
    STA PF1                 ; chunks 4-11
    STA PF2                 ; chunks 12-19
CeilingLoop:
    +PlayRow
    INY
    CPY #CEIL_ROWS
    BNE CeilingLoop

; --- the field: play rows 4-80 (visible 29-182) ------------------------------
    LDA #C_GOLD
    STA COLUPF              ; the ball is gold in the field
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
FieldLoop:
    +PlayRow
    INY
    CPY #FIELD_END
    BNE FieldLoop

; --- the floor: play rows 81-84 (visible 183-190) ----------------------------
; COLUPF is already gold, so the ball keeps its colour if it ever reaches the
; floor; only the playfield bytes change.
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
FloorLoop:
    +PlayRow
    INY
    CPY #PLAY_ROWS
    BNE FloorLoop
; 85 rows x 2 lines = visible 21-190.  The last WSYNC releases the CPU at
; scanline 228, the first ground line.

; =============================================================================
; VISIBLE LINE 191: THE GROUND LINE (1 line)
; =============================================================================
; The floor left PF0/PF1/PF2 set; clear them before the ground line's pixels
; (chunk 0 at cycle 22.7) and paint the whole line with the background colour.
GroundStart:                ; checkpoint: scanline 228, visible line 191
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA #C_GROUND
    STA COLUBK              ; a solid dark green line, full width
    STA WSYNC
    NOP                     ; the WSYNC releases the CPU on scanline 229

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
; SETGAMEP0 / SETGAMEP1 — the Lesson 26 divide-by-15 dance, fixed to two lines
; =============================================================================
; A = the desired left edge + POS_BIAS.  The first WSYNC starts a fresh line;
; the divide loop and the stores run on that line; the final WSYNC ends it.
; The worst case (A=147) is 70 cycles, inside the 76-cycle line, so each call
; costs exactly two scanlines for every X.  That is what keeps PlayStart fixed.
SetGameP0:
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
    STA WSYNC
    RTS

SetGameP1:
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
    STA WSYNC
    RTS

; =============================================================================
; BALL COARSE POSITIONING — one RESBL, one HMBL, no HMOVE here
; =============================================================================
; A = the ball's TIA X plus POS_BIAS + 1 (the ball's reset is shorter).
; ScoreSetup's HMOVE applies HMBL in the same HBLANK as the players' fine
; offsets, which is Lesson 39's arrangement.
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
; THE STATUS BAR'S LEVEL MASKS — 16 levels x 3 playfield bytes
; =============================================================================
; The bar's left half covers playfield chunks 2..16 (15 chunks).  Level N
; lights chunks 2..(1+N): the bar grows from the outer edges toward the
; centre, and CTRLPF's reflection draws the right half's mirror.  PF0 carries
; chunks 0-3 (bit 4 = chunk 0), PF1 chunks 4-11 (bit 7 = chunk 4) and PF2
; chunks 12-19 (bit 0 = chunk 12).
LevelPF0:
    !byte $00, $40, $C0, $C0, $C0, $C0, $C0, $C0      ; levels 0-7
    !byte $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0      ; levels 8-15
LevelPF1:
    !byte $00, $00, $00, $80, $C0, $E0, $F0, $F8      ; levels 0-7
    !byte $FC, $FE, $FF, $FF, $FF, $FF, $FF, $FF      ; levels 8-15
LevelPF2:
    !byte $00, $00, $00, $00, $00, $00, $00, $00      ; levels 0-7
    !byte $00, $00, $00, $01, $03, $07, $0F, $1F      ; levels 8-15

; =============================================================================
; THE PLAY ZONE'S SPRITE STRIPS — one byte per 2-line row
; =============================================================================
; Every strip is page-aligned so LDA strip,Y never crosses a page.
;
; P0: a player 16 kernel rows tall (32 scanlines): sixteen strip bytes
; starting at P0_TOP, so the feet sit just above the floor at FIELD_END.
; The top byte is solid $FF, so the falling ball meets the player as soon as
; it reaches the head; the rest is a small person.
    !align 255, 0
P0Strip:
    !fill P0_TOP, $00
    !byte $FF, $18, $18, $3C, $3C, $7E, $7E, $5A
    !byte $5A, $18, $18, $3C, $3C, $66, $66, $C3
    !fill (PLAY_ROWS - P0_TOP - 16), $00

; P1: an enemy of the same height at rows 6-21 (visible 33–64), below the
; ceiling.  Each byte covers two scanlines.
    !align 255, 0
P1Strip:
    !fill 6, $00
    !byte $3C, $3C, $7E, $7E, $DB, $DB, $FF, $FF
    !byte $FF, $FF, $DB, $DB, $66, $66, $3C, $3C
    !fill (PLAY_ROWS - 22), $00

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreInit, ScoreClear, ScoreSetup, ScoreSetDigit, ScoreAddOne, ScoreDraw,
; and ScoreFont live here.  The library must be sourced inside the ROM area
; (after * = $F000) and after include/vcs.asm.
    !source "include/score.asm"

; The lesson's names for the score's HMOVE.  The library's HmoveApply label sits
; on the STA HMOVE inside ScoreSetup; HmoveDone sits after it.  A breakpoint on
; ScoreHmove reports the WSYNC stall one line early (a Stella logging artefact
; for an instruction that immediately follows a WSYNC); ScoreHmoveDone reports
; the state just after the store, which is the HMOVE's real line and cycle.
ScoreHmove     = HmoveApply
ScoreHmoveDone = HmoveDone

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
