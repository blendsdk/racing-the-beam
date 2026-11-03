; =============================================================================
; LESSON 21: Asymmetric Playfield — Different Left and Right — Racing the Beam
; =============================================================================
; Part 3: Playfield
;
; What this program does:
;   Draws a wall whose left and right halves hold DIFFERENT data.  The left
;   half is a solid green wall with a two-chunk doorway beside the center;
;   the right half is a gapped field of one-chunk stripes.  The two halves
;   are not mirror images — they are separate patterns.
;
; How the TIA draws a playfield line, in repeat mode:
;   - The 20 bits are read once for the LEFT half: PF0 (chunks 0-3),
;     PF1 (4-11), PF2 (12-19), each register sampled at its own slot;
;   - then the SAME registers are read again for the RIGHT half, in the
;     same order (PF0, PF1, PF2), because CTRLPF bit 0 (REF) is clear.
;
;   The trick: the TIA re-reads a register for the second half.  If you
;   rewrite PF0/PF1/PF2 after their left-half slots have been displayed
;   and before their right-half slots begin, only the right half changes.
;   The left half is already painted; the new bytes are waiting for the
;   second pass.
;
;   The slot map (color clocks from the start of the visible line):
;
;     left  PF0  68-84     left  PF1  84-116    left  PF2 116-148
;     right PF0 148-164    right PF1 164-196    right PF2 196-228
;
;   This program's per-line ledger (body entered at cycle 5 on every line):
;
;     cycles   instruction            note
;     5-9      LDA #LEFT0 / STA PF0   effect 10 (clock 30)  - before left PF0 (68)
;     10-14    LDA #LEFT1 / STA PF1   effect 15 (clock 45)  - before left PF1 (84)
;     15-19    LDA #LEFT2 / STA PF2   effect 20 (clock 60)  - before left PF2 (116)
;     20-29    NOP x 5                burn 10 cycles; left PF0 slot (68-84) is past
;     30-34    LDA #RIGHT0 / STA PF0  effect 35 (clock 105) - before right PF0 (148)
;     35-40    NOP x 3                left PF1 slot (84-116) is past
;     41-45    LDA #RIGHT1 / STA PF1  effect 46 (clock 138) - before right PF1 (164)
;     46-51    NOP x 3                left PF2 slot (116-148) is past
;     52-56    LDA #RIGHT2 / STA PF2  effect 57 (clock 171) - before right PF2 (196)
;     57-59    STA WSYNC              write 59, park 60-75
;     next 0-4 DEX / BNE taken       wake 5; the body is entered at cycle 5
;
;   The release (LDA #$00 / STA VBLANK) is also 5 cycles, and X is loaded
;   before the timer wait, so line 37's body starts at cycle 5 exactly like
;   every later line.  The left half is painted on line 37 just as on 228.
;
; The patterns (bit order: PF0 bit 4 leftmost, PF1 bit 7, PF2 bit 0):
;   LEFT0  = $F0  chunks 0-3 on
;   LEFT1  = $FF  chunks 4-11 on
;   LEFT2  = $3F  chunks 12-17 on, 18-19 off  (bits 6-7 clear)
;   RIGHT0 = $00  chunks 20-23 off
;   RIGHT1 = $AA  chunks 24/26/28/30 on, 25/27/29/31 off
;   RIGHT2 = $55  chunks 32/34/36/38 on, 33/35/37/39 off
;
;   The central gap is six chunks: the left half's 18-19 plus the right
;   half's 20-23 (x = 457-600, 144 px; transitions at 457 and 601).  The
;   right half then alternates every
;   chunk to the edge.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), VisibleStart (37), OverscanStart
;   (229); the six write ticks Left0/Left1/Left2 at hit cycles 10/15/20 and
;   Right0/Right1/Right2 at 35/46/57, 192 hits per frame each.
;
; Build: acme -f plain -o build/lesson21.bin \
;        lessons/part3-playfield/21-asymmetric-playfield/21-asymmetric-playfield.asm
; Run:   stella build/lesson21.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines (Lesson 15)
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines (Lesson 15)
VISIBLE_LINES  = 192

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
    +vsync

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- one setup for the whole frame: repeat mode, colors ---
    LDA #$00
    STA CTRLPF              ; REF = 0: repeat the left half on the right
    LDA #$C8
    STA COLUPF              ; green
    LDA #$02
    STA COLUBK              ; dark neutral

; --- X is the line counter; load it before the wait so line 37 starts at
;     cycle 5 exactly like every later line ---
    LDX #VISIBLE_LINES
    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — every line rewrites the registers for its right half
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam on line 37
VisibleStart:               ; debugger checkpoint: the picture's first line (37)
    LDA #$F0                ; 5-6    left PF0
    STA PF0                 ; 7-9
Left0:                      ; checkpoint: hit cycle 10
    LDA #$FF                ; 10-11  left PF1
    STA PF1                 ; 12-14
Left1:                      ; checkpoint: hit cycle 15
    LDA #$3F                ; 15-16  left PF2: chunks 12-17 on, 18-19 off
    STA PF2                 ; 17-19
Left2:                      ; checkpoint: hit cycle 20
    NOP                     ; 20-21  burn the rest of the left PF0 slot
    NOP
    NOP
    NOP
    NOP                     ; 28-29
    LDA #$00                ; 30-31  right PF0
    STA PF0                 ; 32-34
Right0:                     ; checkpoint: hit cycle 35
    NOP                     ; 35-36  left PF1 slot (84-116) is past
    NOP
    NOP                     ; 39-40
    LDA #$AA                ; 41-42  right PF1
    STA PF1                 ; 43-45
Right1:                     ; checkpoint: hit cycle 46
    NOP                     ; 46-51  left PF2 slot (116-148) is past
    NOP
    NOP
    LDA #$55                ; 52-53  right PF2
    STA PF2                 ; 54-56
Right2:                     ; checkpoint: hit cycle 57
    STA WSYNC               ; 57-59  write 59, park 60-75
    DEX                     ; next line, cycle 0-1
    BNE VisibleStart        ; 2-4 taken; body re-entered at cycle 5

; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines; blank-on lands in line 229's HBLANK
; -----------------------------------------------------------------------------
OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
