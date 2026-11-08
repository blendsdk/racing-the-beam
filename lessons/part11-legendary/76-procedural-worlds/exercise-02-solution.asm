; =============================================================================
; LESSON 76 — EXERCISE 2 SOLUTION: The World Behind the Player
; =============================================================================
; Part 11: Legendary Techniques
;
; Exercise 2 adds the REVERSE LFSR step and uses it to rebuild the sixteen
; rows behind the player's window.  The forward step shifts right and XORs
; $B8 when the old bit 0 was 1; the reverse step reads that bit back out of
; bit 7 of the new state, undoes the XOR and shifts left:
;
;     RevStep:  LDA LFSRState
;               ASL             ; carry = the old bit 0; A = state << 1
;               BCC .low0
;               EOR #$70        ; ($B8 << 1) & $FF, the inverse feedback
;               ADC #0          ; carry is still set: restore the old bit 0
;     .low0:    STA LFSRState
;               RTS
;
; At frame 200 the ROM reverses 16 steps from the current state, then
; encodes the ring backwards: row 15 gets the state 16 steps back, row 14
; the state before it, ..., row 0 the state 31 steps back.  The saved state
; is restored afterwards, so forward scrolling resumes where it left off.
; The rebuilt ring is exactly the window that was on screen 128 frames
; earlier (16 scroll steps x 8 frames).  The auto-demo's seed change is
; disabled in this solution (AutoDemo = 0) so the comparison is like for
; like; SELECT still cycles the seed.
;
; What this program does:
;   "the world": a top-down terrain map that scrolls upward through a fixed
;   16-row window.  The picture is 192 scanlines in two bands:
;
;     visible   0- 31    the status band   32 lines   the 8-bit seed, as bars
;     visible  32-191    the world        160 lines   16 terrain rows x 10 lines
;                       ----------------
;                       32 + 160 = 192
;
;   Each terrain row is 10 scanlines tall and 160 pixels wide.  A row is a
;   20-chunk playfield pattern (three bytes: PF0 = chunks 0-3, PF1 = chunks
;   4-11, PF2 = chunks 12-19) plus ONE colour.  The playfield is in REFLECT
;   mode, so the right half of the screen is the mirror of the left half;
;   the world data is still 20 chunks, and the mirror is free.
;
;   There are four terrain types:
;
;     open     black   empty: no playfield chunks at all
;     jungle   green   checkers, stripes and blocks
;     river    blue    a water band centred in the 20-chunk field;
;                       REFLECT mirrors it into two matching bands
;     wall     grey    block walls, eight arrangements
;
;   The type and the pattern both come from one byte: an 8-bit Galois LFSR.
;   The low two bits choose the TYPE through a four-entry map; bits 2-4
;   choose one of eight PATTERNS for that type.  One LFSR step generates
;   one terrain row.  The row is encoded into four parallel 16-byte arrays:
;   RowColor, RowPF0, RowPF1 and RowPF2.
;
;   THE WORLD IS A RING.  Sixteen rows live in RAM (16 x 4 bytes = 64
;   bytes).  The screen always shows rows 0..15, top to bottom.  Every
;   eighth frame the ring shifts one row toward the top of the screen:
;   row 1 -> row 0, row 2 -> row 1, ..., row 15 -> row 14, and the LFSR
;   steps once to fill the new bottom row 15.  The old row 0 falls off the
;   top of the window.  The world therefore scrolls UP: terrain appears at
;   the bottom and moves toward the player.
;
;   THE SAME SEED ALWAYS BUILDS THE SAME WORLD.  The seed is one byte.  The
;   LFSR starts at the seed and the first step produces the first row.  A
;   maximal 8-bit LFSR visits 255 nonzero bytes before it repeats, so one
;   seed describes 255 terrain rows.  Stored as raw playfield data they
;   would need 1,020 bytes — a quarter of the 4K cartridge — before any
;   code or graphics; the generator needs one byte of state and a 96-byte
;   pattern table.
;
;   The auto-demo changes the seed at frames 240, 480, 720, ... so the two
;   captures (2 s and 5 s) show two different worlds; the second change
;   (frame 480, seed A again) proves the replay: the world at 8 s is the
;   world at 0 s.
;
;   THE LFSR (Galois, right-shifting, taps $B8):
;
;       LDA LFSRState
;       LSR             ; bit 0 -> carry
;       BCC .noTap      ; no feedback when the bit was 0
;       EOR #$B8        ; taps at bits 3, 4, 5 and 7 of the shifted byte
;   .noTap:
;       STA LFSRState
;
;   $B8 = %10111000.  The XOR is the feedback polynomial; the shift is the
;   register.  Starting from any nonzero byte, this step visits all 255
;   nonzero bytes and then returns to the start.  Zero is the one fixed
;   point: 0 shifts to 0 and the carry is clear, so a zero seed freezes the
;   generator.  Every seed path in this ROM replaces zero with one.
;
;   The reverse step exists too, and the stretch exercise uses it.  Because
;   $B8 has bit 7 set, the old bit 0 is the only thing that can set bit 7
;   of the new state: bit 7 of the new state IS the old bit 0.  Read it,
;   undo the XOR, shift the other way:
;
;       LDA LFSRState
;       ASL             ; carry = old bit 0; A = state << 1
;       BCC .low0       ; old bit 0 = 0: no inverse tap
;       EOR #$70        ; the taps shifted left: ($B8 << 1) & $FF
;       ADC #0          ; carry is still set: put the old bit 0 back
;   .low0:
;       STA LFSRState
;
;   The forward and reverse steps are exact inverses on all 255 nonzero
;   states; the host model in the lesson text checks every one of them.
;
;   THE FRAME (NTSC): 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262.
;   Measured schedule (cycle-accurate model + Stella instruction trace): the
;   status band runs on absolute lines 37-68, the world on 69-228, the
;   overscan on 229-258 and the VSYNC on 259-261.  StartFrame is 259/3,
;   VblankStart 0/5, BodyStart 37/5, and the STA VBLANK at OverscanStart
;   completes at 229/4.
;
;   Measurement convention: a checkpoint's line/cycle is the instruction's
;   start line and start cycle, with the line's cycle 0 being the first
;   instruction after the WSYNC release.  A breakpoint on the first
;   instruction after a STA WSYNC fires during the stall and reports the
;   WSYNC's own line/cycle; the instruction itself starts on the next line
;   at cycle 0.
;
;   THE KERNEL IS A ROW LOOP, NOT A LINE LOOP.  Each row is written once
;   and then held for 10 scanlines; the TIA re-reads PF0/PF1/PF2 on every
;   line, so the pattern stays until the next row's header rewrites it.
;   The header writes four registers and must finish before the beam
;   reaches the left chunks:
;
;     COLUPF  pixels   0-159  cycle 10 (or 7)     background colour
;     PF0     pixels   0- 15  before cycle 22.67
;     PF1     pixels  16- 47  before cycle 28.00
;     PF2     pixels  48- 79  before cycle 38.67
;
;   The header is 28 cycles, plus the loop's 3-cycle JMP: on a normal row
;   the PF0 write completes at cycle 17, PF1 at 24 and PF2 at 31.  The
;   tightest is PF1, four cycles before its deadline; the first row of the
;   frame starts one cycle later (18/25/32) because it follows the status
;   loop's DEX/BNE instead of the 3-cycle JMP.  For that to be true the
;   row's last line does its bookkeeping (INX/CPX) BEFORE the WSYNC that
;   ends the row: the next header then starts at cycle 3, not cycle 10.
;
;   The player is P0, a white 8x8 sprite on row 14 of the world (the
;   second row from the bottom).  It is drawn on eight of that row's ten
;   lines; the first and last lines of the row are blank.  Its horizontal
;   position is re-strobed once per frame in VBLANK with the Lesson 26
;   divide-by-15 routine, so the position cannot drift.  The auto-demo
;   moves it one pixel every two frames between X=40 and X=120, with a
;   bounce at each end; the joystick's left/right bits (SWCHA bits 6/7,
;   active low) take over whenever either is pressed.
;
;   SELECT cycles the seed by one (skipping zero) and rebuilds the ring.
;   Pressing SELECT also stops the auto-demo's seed changes, so the player
;   can explore the seed space; the eight bars in the status band show the
;   current seed.
;
; RAM map (the exact map; +clean_start zeroes every byte):
;   $80 LFSRState    the current generator byte (never zero)
;   $81 Seed         the seed shown in the status band and rebuilt on change
;   $82 ScrollTimer  frames to the next ring shift (0..7)
;   $83 FrameLo      frame counter, used for the auto-demo's 2-frame parity
;   $84 DemoTimer    frames since the last seed change (0..239)
;   $85 AutoDemo     1 until SELECT is pressed; then 0
;   $86 PlayerX      the player's left edge (40..120)
;   $87 PlayerDir    0 = left, 1 = right
;   $88 PrevSelect   SELECT edge latch: 0 = released, 1 = pressed
;   $89 TempBase     scratch: type * 24 in the row encoder
;   $8A TempVar      scratch: variant * 3 in the row encoder
;   $8B TempType     scratch: the mapped terrain type
;   $8C TempSeed     scratch: the shifting copy of the seed
;   $8D StatusPF0    the status band's PF0 byte (seed bars)
;   $8E StatusPF1    the status band's PF1 byte
;   $8F StatusPF2    the status band's PF2 byte
;   $90-$9F RowColor 16 bytes, one colour per ring row
;   $A0-$AF RowPF0   16 bytes, chunks 0-3 per row
;   $B0-$BF RowPF1   16 bytes, chunks 4-11 per row
;   $C0-$CF RowPF2   16 bytes, chunks 12-19 per row
;   $D0 RewindSave    the state to resume from after the reverse build
;   $D1 RewindDone    1 = this frame has already shown the rewind
;   $D2 RewindTimer   frames since power-on, for the one-shot rewind
;   $D3-$F7          free (37 bytes)
;   $F8-$FF          the stack
;
; Build: acme -f plain -o build/exercise-02.bin \
;        lessons/part11-legendary/76-procedural-worlds/exercise-02-solution.asm
; Run:   stella build/exercise-02.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK (Lesson 15)
OVERSCAN_TIMER = 36      ; 30-line overscan (Lesson 15)

VISIBLE_LINES  = 192
STATUS_LINES   = 32      ; visible 0-31: the seed readout
WORLD_ROWS     = 16      ; 16 terrain rows in the ring
ROW_LINES      = 10      ; each row is 10 scanlines tall
WORLD_LINES    = WORLD_ROWS * ROW_LINES   ; 160
PLAYER_ROW     = 14      ; the player's row: the second from the bottom

PLAYER_MIN     = 40      ; the sprite never touches the status band's columns
PLAYER_MAX     = 120     ; 120 + 8 = 128, well inside the 160-pixel screen

POS_BIAS       = 3       ; the Lesson 26 output-delay bias

SEED_A         = $FA     ; the power-on seed
SEED_B         = $D0     ; unused by the auto-demo in this solution
DEMO_PERIOD    = 240     ; the auto-demo's seed period (not used here)
REWIND_FRAME   = 200     ; 3.3 s at 60 Hz: rebuild the previous 16-row window

; --- colours -----------------------------------------------------------------
C_STATUS       = $0E     ; the seed bars: white
C_OPEN         = $00     ; open terrain: black (the pattern is empty too)
C_JUNGLE       = $C6     ; jungle: green
C_RIVER        = $96     ; river: blue
C_WALL         = $0A     ; wall: grey
C_PLAYER       = $0E     ; the player sprite: white

; The band arithmetic is a build-time assertion, not a comment.
!if STATUS_LINES + WORLD_LINES != VISIBLE_LINES {
    !error "the status band and the world must total 192 visible lines"
}

; =============================================================================
; RAM ALLOCATION ($80-$CF; +clean_start zeroes every byte)
; =============================================================================
LFSRState    = $80   ; the current generator byte, never zero
Seed         = $81   ; the seed the status band displays
ScrollTimer  = $82   ; frames to the next ring shift
FrameLo      = $83   ; frame parity for the auto-demo's movement
DemoTimer    = $84   ; frames since the last seed change
AutoDemo     = $85   ; 1 = the seed changes at frame 240; 0 after SELECT
PlayerX      = $86   ; the player's left edge, 40..120
PlayerDir    = $87   ; 0 = left, 1 = right
PrevSelect   = $88   ; SELECT edge latch
TempBase     = $89   ; scratch: type * 24
TempVar      = $8A   ; scratch: variant * 3
TempType     = $8B   ; scratch: the mapped type
TempSeed     = $8C   ; scratch: the shifting copy of the seed
StatusPF0    = $8D   ; the status band's three playfield bytes
StatusPF1    = $8E
StatusPF2    = $8F
RowColor     = $90   ; 16 bytes: $90-$9F, one colour per row
RewindSave   = $D0   ; the state to resume from after the reverse build
RewindDone   = $D1   ; 1 = this frame has already shown the rewind
RewindTimer  = $D2   ; frames since power-on, for the one-shot rewind
RowPF0       = $A0   ; 16 bytes: $A0-$AF, chunks 0-3 per row
RowPF1       = $B0   ; 16 bytes: $B0-$BF, chunks 4-11 per row
RowPF2       = $C0   ; 16 bytes: $C0-$CF, chunks 12-19 per row
;
; $D3-$F7 are free (37 bytes).  The stack lives at $F8-$FF; the deepest
; call is BuildWorld -> EncodeRow (two levels, six bytes).

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
    STA SWACNT              ; port A is an input port
    STA NUSIZ0
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA ENAM0
    STA ENAM1

    LDA #$01
    STA CTRLPF              ; REFLECT the playfield (bit 0); no priority;
                            ; a 1-pixel ball (unused)
    LDA #$00
    STA COLUBK              ; open ground and every gap: black
    LDA #C_STATUS
    STA COLUPF              ; the status band's bars
    LDA #C_PLAYER
    STA COLUP0              ; the player is white

; --- the first world ---------------------------------------------------------
; The seed is one byte.  BuildWorld steps the LFSR 16 times and encodes the
; 16 resulting states into the ring; BuildStatus turns the seed into the
; eight bars of the status band.
    LDA #SEED_A
    STA Seed
    LDA #$00
    STA AutoDemo            ; this solution keeps seed A for the rewind proof
    STA DemoTimer
    STA ScrollTimer
    STA PrevSelect
    STA FrameLo
    STA RewindDone
    STA RewindTimer
    LDA #PLAYER_MIN
    STA PlayerX
    LDA #$01
    STA PlayerDir

    JSR BuildWorld
    JSR BuildStatus

; --- position the player once before the first frame -------------------------
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetHorizPosP0

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    INC FrameLo
    INC DemoTimer

; -----------------------------------------------------------------------------
; 0. THE ONE-SHOT REWIND — at frame 200, rebuild the previous 16-row window
; -----------------------------------------------------------------------------
; The reverse step is exact on all 255 nonzero states.  RewindWorld reverses
; 16 steps to the state of the row that sat 16 rows behind the current
; bottom row, saves that state, then walks backwards through the ring: row
; 15, row 14, ..., row 0.  The saved state is restored so the next forward
; scroll step produces the row that followed the rebuilt window.  The
; rewind starts before SELECT so it has the whole blank; its frame skips
; the player move, the positioner and the scroll so BodyStart stays on 37.
    INC RewindTimer
    LDA RewindDone
    BNE RewindCheckDone
    LDA RewindTimer
    CMP #REWIND_FRAME
    BCC RewindCheckDone
    LDA #$01
    STA RewindDone
    JSR RewindWorld
    JMP VblankDone          ; the rewind frame skips the player and scroll
RewindCheckDone:

; -----------------------------------------------------------------------------
; 1. SELECT — cycle the seed, and hand control to the player
; -----------------------------------------------------------------------------
    LDA SWCHB
    AND #$02                ; SELECT is active low
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA #$00
    STA AutoDemo            ; the player's seed is no longer overridden
    LDA Seed
    CLC
    ADC #$01                ; the next seed
    BNE HaveSeed
    LDA #$01                ; skip the LFSR's fixed point
HaveSeed:
    STA Seed
    JSR BuildWorld
    JSR BuildStatus
    LDA #$00
    STA ScrollTimer         ; a new seed starts a fresh ring at once
    JMP SelectDone
SelectReleased:
    LDA #$00
    STA PrevSelect
SelectDone:

; -----------------------------------------------------------------------------
; 2. THE AUTO-DEMO'S SEED — A for 240 frames, B for 240, A again ...
; -----------------------------------------------------------------------------
; The 2-second capture (game frames 64-71) is seed A; the 5-second capture
; (game frames 256-263) is seed B; the second change at frame 480 rebuilds
; seed A's first 16 rows, which is the power-on world.  Pressing SELECT
; sets AutoDemo to 0 and the whole mechanism is skipped from then on.
    LDA DemoTimer
    CMP #DEMO_PERIOD
    BCC DemoDone
    LDA #$00
    STA DemoTimer
    LDA AutoDemo
    BEQ DemoDone
    LDA Seed
    CMP #SEED_A
    BNE SeedToA
    LDA #SEED_B
    JMP SetSeed
SeedToA:
    LDA #SEED_A
SetSeed:
    STA Seed
    JSR BuildWorld
    JSR BuildStatus
    LDA #$00
    STA ScrollTimer
DemoDone:

; -----------------------------------------------------------------------------
; 4. THE PLAYER — joystick left/right, or the auto-demo's slow oscillation
; -----------------------------------------------------------------------------
; SWCHA bit 6 is left and bit 7 is right, both active low.  If either is
; pressed the player moves one pixel per frame; otherwise the auto-demo
; moves one pixel every second frame and bounces between the limits.
    LDA SWCHA
    AND #$C0
    CMP #$C0                ; both bits high: no direction pressed
    BEQ AutoMove

    LDA SWCHA
    AND #$40                ; left?
    BNE CheckRight
    LDA PlayerX
    CMP #PLAYER_MIN
    BEQ PlayerMoved
    DEC PlayerX
    LDA #$00
    STA PlayerDir
    JMP PlayerMoved
CheckRight:
    LDA SWCHA
    AND #$80                ; right?
    BNE PlayerMoved
    LDA PlayerX
    CMP #PLAYER_MAX
    BEQ PlayerMoved
    INC PlayerX
    LDA #$01
    STA PlayerDir
    JMP PlayerMoved

AutoMove:
    LDA FrameLo
    AND #$01                ; one pixel every two frames
    BNE PlayerMoved
    LDA PlayerDir
    BNE AutoRight
    LDA PlayerX
    CMP #PLAYER_MIN
    BEQ BounceRight
    DEC PlayerX
    JMP PlayerMoved
BounceRight:
    LDA #$01
    STA PlayerDir
    JMP PlayerMoved
AutoRight:
    LDA PlayerX
    CMP #PLAYER_MAX
    BEQ BounceLeft
    INC PlayerX
    JMP PlayerMoved
BounceLeft:
    LDA #$00
    STA PlayerDir
PlayerMoved:

; --- re-establish the player's horizontal position every frame --------------
; The divide-by-15 routine is the Lesson 26 dance: RESP0 lands the coarse
; position, HMP0 carries the remainder, and HMOVE applies it in HBLANK.
; Re-strobing every frame is deliberate: there is no drift and no need to
; track whether X changed.
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetHorizPosP0

; -----------------------------------------------------------------------------
; 5. THE SCROLL — one row every 8 frames, and one LFSR step per new row
; -----------------------------------------------------------------------------
; The ring shifts up by one row (row 1 -> 0, ...), then the LFSR steps and
; the new state is encoded into the bottom row (index 15).  The step is
; exactly one LFSR step per generated row, so scrolling and generation stay
; locked together: the seed alone determines the entire future world.
    INC ScrollTimer
    LDA ScrollTimer
    CMP #$08
    BCC ScrollDone
    LDA #$00
    STA ScrollTimer
    JSR ShiftRing
    JSR StepLFSR
    LDX #(WORLD_ROWS - 1)
    JSR EncodeRow
ScrollDone:
VblankDone:

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
BodyStart:                  ; checkpoint: scanline 37/5, visible line 0

; =============================================================================
; VISIBLE LINES 0-31: THE STATUS BAND (the seed as eight bars)
; =============================================================================
; The three status bytes are built whenever the seed changes.  The bars sit
; at chunks 2, 4, 6, ..., 16: one chunk on, one off.  REFLECT mode mirrors
; them into the right half, so the display is symmetric; the left-hand copy
; is the seed, most significant bit first.
    LDA #C_STATUS
    STA COLUPF
    LDA StatusPF0
    STA PF0
    LDA StatusPF1
    STA PF1
    LDA StatusPF2
    STA PF2
    LDX #STATUS_LINES
StatusLoop:
    STA WSYNC               ; end one status line
    DEX
    BNE StatusLoop
    ; X is now 0 and the CPU is at cycle 4 of visible line 32.

; =============================================================================
; VISIBLE LINES 32-191: THE WORLD (16 rows x 10 lines)
; =============================================================================
; X is the row index.  The header writes the row's colour and three
; playfield bytes; the row's ten lines then need only WSYNCs.  The last
; line of every row does the loop bookkeeping before its WSYNC, so the
; next header starts at cycle 3 and every register write meets its chunk
; deadline.
RowHeader:
    LDA RowColor,X          ; 4   4- 8  the row's terrain colour
    STA COLUPF              ; 3   8-11  before pixel 0 (22.67)
    LDA RowPF0,X            ; 4  11-15  chunks 0-3
    STA PF0                 ; 3  15-18  before 22.67
    LDA RowPF1,X            ; 4  18-22  chunks 4-11
    STA PF1                 ; 3  22-25  before 28.00
    LDA RowPF2,X            ; 4  25-29  chunks 12-19
    STA PF2                 ; 3  29-32  before 38.67
    CPX #PLAYER_ROW
    BEQ PlayerRow

; --- a plain terrain row: nine WSYNCs, then line 10 does the bookkeeping -----
    LDY #(ROW_LINES - 1)    ; 9
RowLines:
    STA WSYNC               ; end lines 1..9 of this row
    DEY
    BNE RowLines
    ; Visible line 10 of the row.  The PF registers still hold this row's
    ; bytes, so the last line is drawn correctly while X advances.
    INX
    CPX #WORLD_ROWS
    BEQ WorldEnd
    STA WSYNC               ; end line 10
    JMP RowHeader           ; the next header starts at cycle 3

; --- the player's row: eight sprite lines and two blank lines ----------------
PlayerRow:
    LDY #$00
PlayerLines:
    LDA PlayerGfx,Y         ; 4  blank, then the 8 sprite rows, then blank
    STA GRP0                ; 3
    STA WSYNC               ; end one line of the row
    INY
    CPY #(ROW_LINES - 1)    ; lines 1..9 carry Gfx 0..8
    BNE PlayerLines
    ; Line 10: draw the last (blank) player row, then close the row.
    LDA PlayerGfx+9
    STA GRP0
    INX
    CPX #WORLD_ROWS
    BEQ WorldEnd
    STA WSYNC               ; end line 10
    JMP RowHeader

; --- the last row has been drawn (visible line 191); begin the overscan ------
WorldEnd:
    STA WSYNC               ; end visible line 191
WorldDone:

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229, the first blanked line
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; STEPLFSR — the 8-bit Galois LFSR, taps $B8, maximal period 255
; =============================================================================
; A right shift moves bit 0 into the carry.  When that bit is 1 the feedback
; polynomial is XORed into the shifted byte.  $B8 = %10111000, so the taps
; are bits 7, 5, 4 and 3 of the shifted value.  Bit 7 becomes the old bit 0
; (shifted in as 0, then XORed); bits 5, 4 and 3 are pre-shift bits 6, 5
; and 4.  A nonzero seed visits every nonzero byte and returns to itself
; after 255 steps; zero is the fixed point and never enters the cycle.
StepLFSR:
    LDA LFSRState
    LSR                     ; bit 0 -> carry
    BCC .noTap
    EOR #$B8                ; the feedback: taps 7, 5, 4 and 3
.noTap:
    STA LFSRState
    RTS

; =============================================================================
; REVSTEP — the exact inverse of StepLFSR
; =============================================================================
; Forward: y = (x >> 1) ^ ($B8 if x & 1).  Because $B8 has bit 7 set,
; bit 7 of y is exactly x's old bit 0: the shift leaves bit 7 zero, and
; only the feedback can set it.  So the reverse step recovers the bit,
; undoes the feedback, shifts left and puts the bit back.
;
; The forward and reverse steps are inverses on all 255 nonzero states:
; the host model checks every one, and the exercise's red build checks the
; ring bytes after the rewind.
RevStep:
    LDA LFSRState
    ASL                     ; carry = old bit 0; A = state << 1
    BCC .low0
    EOR #$70                ; ($B8 << 1) & $FF, the inverse tap pattern
    ADC #0                  ; carry is still set: add the old bit 0 back
.low0:
    STA LFSRState
    RTS

; =============================================================================
; REWINDWORLD — rebuild the 16 rows behind the player's window
; =============================================================================
; The ring before the call holds the 16 rows ending at row 15's state.  We
; reverse 16 steps to reach the state of the row 16 rows back: the bottom
; row of the previous window, which becomes row 15 of the rebuilt window.
; Each reverse step moves one row up the screen.  The state at the end is
; the row above the rebuilt window; RewindSave restores the state that
; forward scrolling must continue from.
RewindWorld:
    LDX #WORLD_ROWS
.reverse:
    JSR RevStep
    DEX
    BNE .reverse
    LDA LFSRState
    STA RewindSave
    LDX #(WORLD_ROWS - 1)
.rwbuild:
    JSR EncodeRow           ; row X = the current (older) state
    CPX #$00
    BEQ .rwdone
    JSR RevStep
    DEX
    JMP .rwbuild
.rwdone:
    LDA RewindSave
    STA LFSRState
    RTS

; =============================================================================
; SHIFTRING — move every row one place toward the top of the screen
; =============================================================================
; Row 1 -> row 0, row 2 -> row 1, ..., row 15 -> row 14.  The four arrays
; are parallel, so one loop moves all four bytes of a row.  Fifteen rows
; because row 15 is about to be overwritten by the new bottom row.
ShiftRing:
    LDX #$00
.shift:
    LDA RowColor+1,X
    STA RowColor,X
    LDA RowPF0+1,X
    STA RowPF0,X
    LDA RowPF1+1,X
    STA RowPF1,X
    LDA RowPF2+1,X
    STA RowPF2,X
    INX
    CPX #(WORLD_ROWS - 1)
    BNE .shift
    RTS

; =============================================================================
; BUILDWORLD — rebuild all 16 rows from the seed
; =============================================================================
; The seed is loaded into the generator, then 16 steps produce the 16 rows.
; This is the determinism proof in code: the same seed always produces the
; same 16 states, and therefore the same 16 rows.
BuildWorld:
    LDA Seed
    STA LFSRState
    LDX #$00
.build:
    JSR StepLFSR
    JSR EncodeRow           ; X is the destination row
    INX
    CPX #WORLD_ROWS
    BNE .build
    RTS

; =============================================================================
; ENCODEROW — turn the current LFSR state into the row at index X
; =============================================================================
; state bits 0-1 -> a type through TypeMap (4 entries)
; state bits 2-4 -> one of 8 pattern variants
; The pattern is three bytes in PatternTable, indexed by type * 24 + variant * 3.
EncodeRow:
    LDA LFSRState
    AND #$03
    TAY
    LDA TypeMap,Y           ; the density control: slot -> terrain type
    STA TempType
    TAY
    LDA TypeColor,Y
    STA RowColor,X

    LDA TempType
    ASL                     ; type * 2
    CLC
    ADC TempType            ; type * 3
    ASL
    ASL
    ASL                     ; type * 24
    STA TempBase

    LDA LFSRState
    LSR
    LSR                     ; bits 2-4 now in bits 0-2
    AND #$07
    STA TempVar
    ASL                     ; variant * 2
    CLC
    ADC TempVar             ; variant * 3
    CLC
    ADC TempBase
    TAY

    LDA PatternTable,Y
    STA RowPF0,X
    LDA PatternTable+1,Y
    STA RowPF1,X
    LDA PatternTable+2,Y
    STA RowPF2,X
    RTS

; =============================================================================
; BUILDSTATUS — encode the 8-bit seed as eight playfield bars
; =============================================================================
; Block i sits at chunk 2 + 2i, so the eight bars span chunks 2..16.
; The masks are one bit each: PF0 bit 6, then four PF1 bits, then three
; PF2 bits.  The seed is shifted MSB first; a 1 lights the bar.
BuildStatus:
    LDA #$00
    STA StatusPF0
    STA StatusPF1
    STA StatusPF2
    LDA Seed
    STA TempSeed
    LDX #$00
.bar:
    ASL TempSeed            ; carry = the next seed bit, bit 7 first
    BCC .next
    LDA StatusPF0
    ORA BlockPF0,X
    STA StatusPF0
    LDA StatusPF1
    ORA BlockPF1,X
    STA StatusPF1
    LDA StatusPF2
    ORA BlockPF2,X
    STA StatusPF2
.next:
    INX
    CPX #$08
    BNE .bar
    RTS

; =============================================================================
; SETHORIZPOSP0 — the Lesson 26 divide-by-15 dance, for the player
; =============================================================================
; A = the desired left edge + the output-delay bias.  Each subtraction is
; 5 cycles = 15 color clocks; the remainder becomes the signed fine motion
; in HMP0 and the coarse strobe lands on the beam.  The final WSYNC and
; HMOVE put the fine motion inside HBLANK.
    !align 31, 0
SetHorizPosP0:
    STA WSYNC
    SEC
.divide:
    SBC #15
    BCS .divide
    EOR #7                  ; the negative remainder -> the signed fine value
    ASL                     ; bits 0-3 -> HMP0's high nibble
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0               ; the coarse strobe
    STA WSYNC
    STA HMOVE               ; apply HMP0 in HBLANK
    RTS

; =============================================================================
; THE PLAYER — 8x8, white, with a blank row above and below
; =============================================================================
; PlayerGfx[0] and PlayerGfx[9] are blank.  The row's first line is drawn
; after the header's 28 cycles; its GRP0 write lands at cycle 44, too late
; for a sprite at X=40, so keeping that line blank hides the late write.
; On each later line the INY/CPY/BNE take 7 cycles, the LDA starts at cycle
; 7 and the GRP0 write lands at cycle 13 (12 on the last real line), well
; before the beam reaches X=40.
PlayerGfx:
    !byte %00000000         ; line 1 of the row: blank
    !byte %00011000         ; line 2   ..##....
    !byte %00111100         ; line 3   .####...
    !byte %01111110         ; line 4   .######.
    !byte %11011011         ; line 5   ##.##.##
    !byte %11111111         ; line 6   ########
    !byte %01111110         ; line 7   .######.
    !byte %00111100         ; line 8   .####...
    !byte %00011000         ; line 9   ..##....
    !byte %00000000         ; line 10 of the row: blank

; =============================================================================
; THE TYPE MAP — four LFSR slots -> four terrain types
; =============================================================================
; The main ROM is the identity map: each terrain type gets one quarter of
; the rows.  Exercise 1 changes these four bytes to weight the generator
; toward water: the same LFSR sequence then produces a wetter world.
TypeMap:
    !byte 0, 1, 2, 3        ; slot 0 open, 1 jungle, 2 river, 3 wall

; =============================================================================
; THE TERRAIN PALETTE — one byte per type
; =============================================================================
TypeColor:
    !byte C_OPEN, C_JUNGLE, C_RIVER, C_WALL

; =============================================================================
; THE PATTERN TABLE — 4 types x 8 variants x 3 playfield bytes
; =============================================================================
; Index = type * 24 + variant * 3.  Each entry is PF0, PF1, PF2, i.e. chunks
; 0-3, 4-11 and 12-19 in the left half.  The right half is the REFLECT
; mirror, so these 20 chunks fill the 40-chunk line.
;
; Chunk-to-bit: chunks 0-3 are PF0 bits 4-7 (chunk 0 = bit 4); chunks 4-11
; are PF1 bits 7-0 (chunk 4 = bit 7); chunks 12-19 are PF2 bits 0-7
; (chunk 12 = bit 0).
PatternTable:
    ; --- type 0: open.  All eight variants are empty; the type's colour is
    ; --- black, so an open row is a clean gap in the world.
    !byte $00, $00, $00     ; open   0
    !byte $00, $00, $00     ; open   1
    !byte $00, $00, $00     ; open   2
    !byte $00, $00, $00     ; open   3
    !byte $00, $00, $00     ; open   4
    !byte $00, $00, $00     ; open   5
    !byte $00, $00, $00     ; open   6
    !byte $00, $00, $00     ; open   7

    ; --- type 1: jungle.  Checkers, stripes, solid and sparse growth.
    !byte $50, $AA, $55     ; jungle 0  even-chunk checker
    !byte $A0, $55, $AA     ; jungle 1  odd-chunk checker
    !byte $F0, $FF, $FF     ; jungle 2  solid
    !byte $30, $CC, $33     ; jungle 3  dense pairs
    !byte $C0, $33, $CC     ; jungle 4  offset pairs
    !byte $10, $88, $11     ; jungle 5  sparse every fourth chunk
    !byte $40, $22, $44     ; jungle 6  sparse offset
    !byte $70, $73, $39     ; jungle 7  diagonal blocks

    ; --- type 2: river.  A water band centred in the 20-chunk field;
    ; --- REFLECT mirrors it into two matching bands.  Eight widths: 20,
    ; --- 16, 12, 10, 8, 6, 4 and 2 chunks.  The banks are black.
    !byte $F0, $FF, $FF     ; river  0  full width (20 chunks)
    !byte $C0, $FF, $3F     ; river  1  chunks 2-17  (16)
    !byte $00, $FF, $0F     ; river  2  chunks 4-15  (12)
    !byte $00, $7F, $07     ; river  3  chunks 5-14  (10)
    !byte $00, $3F, $03     ; river  4  chunks 6-13  (8)
    !byte $00, $1F, $01     ; river  5  chunks 7-12  (6)
    !byte $00, $0F, $00     ; river  6  chunks 8-11  (4)
    !byte $00, $06, $00     ; river  7  chunks 9-10  (2)

    ; --- type 3: wall.  Solid segments, pairs, and sparse pillars.
    !byte $30, $CC, $33     ; wall   0  pairs at 0,4,8,12,16
    !byte $C0, $33, $CC     ; wall   1  pairs offset by 2
    !byte $F0, $FF, $FF     ; wall   2  solid
    !byte $70, $38, $C7     ; wall   3  three-chunk blocks
    !byte $E0, $1C, $8E     ; wall   4  three-chunk blocks offset
    !byte $10, $88, $11     ; wall   5  pillars every fourth chunk
    !byte $40, $22, $44     ; wall   6  pillars offset
    !byte $F0, $80, $F8     ; wall   7  two thick walls

; =============================================================================
; THE STATUS BAND'S BAR MASKS — one bit per seed bit
; =============================================================================
; Block i is chunk 2 + 2i.  These tables give the one register bit each
; block needs; BuildStatus ORs the ones whose seed bit is set.
BlockPF0:
    !byte $40, $00, $00, $00, $00, $00, $00, $00   ; chunk 2
BlockPF1:
    !byte $00, $80, $20, $08, $02, $00, $00, $00   ; chunks 4,6,8,10
BlockPF2:
    !byte $00, $00, $00, $00, $00, $01, $04, $10   ; chunks 12,14,16

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
