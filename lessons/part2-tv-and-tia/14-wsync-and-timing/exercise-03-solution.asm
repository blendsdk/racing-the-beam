; =============================================================================
; LESSON 14 — EXERCISE 3 SOLUTION: Budget Check with Two Breakpoints (Stretch)
; =============================================================================
;
; Challenge: verify the repaired kernel's budget with two state-log
; breakpoints and record the cycle ledger.
;
; The critical section is everything between the anchor and the color
; store that follows it.  Two labels mark its edges:
;
;   BudgetStart   right after the anchor — the line's first cycle
;   BudgetEnd     the instruction after the store — the write is done
;
; The ledger (static — count it in the listing):
;
;   the anchor releases the CPU at line-cycle 0
;   LDA #$84                2 cycles   (0-1)
;   STA COLUBK              3 cycles   (2-4, the store latches on cycle 4)
;   BudgetEnd                -> budget used: 5 cycles of the line's
;   ~23-cycle HBLANK window (15 of its 68 color clocks)
;
; How to verify (the two-breakpoint recipe):
;
;   acme -f plain -l build/ex3-l14.sym -o build/ex3-l14.bin \
;     lessons/part2-tv-and-tia/14-wsync-and-timing/exercise-03-solution.asm
;   grep -E "BudgetStart|BudgetEnd" build/ex3-l14.sym
;
;   then, one breakpoint per run (the same ROM both times; the addresses
;   below are as shipped — grep the symbol file to confirm):
;   stella -sound 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F057' build/ex3-l14.bin
;   stella -sound 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F05B' build/ex3-l14.bin
;
;   Expected log (measured):
;     BudgetStart:  scanline 132 — the anchor taking hold of the CPU
;                   (cycle 16 while aligned; later in late mode, because
;                   the work runs first).  Either way, the anchor releases
;                   the CPU at scanline 133, cycle 0.
;     BudgetEnd:    scanline 133  cycle 5  pixel -53 — the store is done,
;                   5 cycles after the line-133 release — IDENTICALLY in
;                   both modes.  That identical BudgetEnd is the proof
;                   the repair works: the write never leaves HBLANK.
;
;   (Stella numbers the frame's lines absolutely: visible line 97 is
;   scanline 133; each line is 76 cycles: 0-22 blanked, 23-75 visible.
;   A breakpoint on the instruction right after STA WSYNC is reported at
;   the moment the anchor takes hold — one line before it starts drawing.)
;
; Expected screen: the repaired split, clean in both modes — plus the
; numbers above, which are the point of the exercise: 5 of HBLANK's ~23
; cycles used, with ~18 to spare for real work.
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame, the split, and the clock
; =============================================================================
VBLANK_LINES   = 37     ; blanked lines between VSYNC and the picture
VISIBLE_LINES  = 192    ; visible scanlines: two halves of 96
TOP_LINES      = 96     ; red lines at the top
BOTTOM_LINES   = VISIBLE_LINES-TOP_LINES   ; blue lines below (96)
OVERSCAN_LINES = 30     ; blanked lines after the picture
MODE_FRAMES    = 120    ; frames per mode (~2 seconds at ~60 Hz)

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
ModeCounter = $80       ; frames left in this mode: 120 -> 0
Mode        = $81       ; $00 = aligned, $01 = late (flips every 120 frames)

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

    LDA #MODE_FRAMES
    STA ModeCounter
    LDA #$00
    STA Mode                ; start aligned

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; THE MODE CLOCK — one tick per frame, a flip every 120 ticks
; -----------------------------------------------------------------------------
    DEC ModeCounter
    BNE NoFlip
    LDA #MODE_FRAMES
    STA ModeCounter
    LDA Mode
    EOR #$01
    STA Mode
NoFlip:
; -----------------------------------------------------------------------------
; VSYNC — exactly 3 lines
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = start VSYNC
    STA VSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    LDA #$00
    STA VSYNC               ; exactly 3 lines

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
; -----------------------------------------------------------------------------
; VBLANK — 37 blanked lines
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    LDX #VBLANK_LINES
VblankLines:
    STA WSYNC
    DEX
    BNE VblankLines

VisibleStart:               ; debugger checkpoint: visible's first line (Stella: 37)
; -----------------------------------------------------------------------------
; VISIBLE — 96 red lines, one boundary line, 95 blue lines
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam — visible line 1
    LDA #$42                ; the top half's red
    STA COLUBK              ; lands in HBLANK: the release line shows it
    LDY #TOP_LINES-1        ; 95 more lines complete the top half's 96
TopLoop:
    STA WSYNC
TopWrite:                   ; debugger checkpoint: every line, always in HBLANK
    STA COLUBK              ; paint it red
    DEY
    BNE TopLoop
    ; --- visible line 96 is painted red; the work goes here, before the anchor ---
    LDA Mode
    BEQ Anchor
    JSR DelayBottom         ; late: 38 cycles, paid for in visible line 96
Anchor:
    STA WSYNC               ; the anchor: wait out visible line 96 -> line 97 starts
BudgetStart:                ; BREAKPOINT 1: the critical section begins
    LDA #$84                ; 2 cycles
    STA COLUBK              ; 3 cycles — the store latches on the 3rd
BudgetEnd:                  ; BREAKPOINT 2: 5 cycles later, the write is done
    LDY #BOTTOM_LINES-1     ; 95 more lines complete the bottom half's 96
BottomLoop:
    STA WSYNC
BottomWrite:                ; debugger checkpoint: every line, in HBLANK
    STA COLUBK              ; paint it blue
    DEY
    BNE BottomLoop

    STA WSYNC               ; let the last line finish before blanking
    LDA #$02
OverscanStart:              ; debugger checkpoint: overscan's first line (Stella: 229)
    STA VBLANK
    LDX #OVERSCAN_LINES
OverscanLines:
    STA WSYNC
    DEX
    BNE OverscanLines
    JMP StartFrame          ; 262 lines done: next frame

; =============================================================================
; SUBROUTINE: DelayBottom — the same 26-cycle work, moved off the critical line
; =============================================================================
; Burns a fixed 26 cycles (LDX + a five-pass DEX/BNE loop).  Called from
; visible line 96, before the anchor — outside the critical section the two
; breakpoints measure.  Registers: X is used up; A and Y are untouched.
; =============================================================================
DelayBottom:
    LDX #$05                ; 2 cycles
DelayLoop:
    DEX                     ; 2 cycles
    BNE DelayLoop           ; 3 cycles taken / 2 on the last pass
    RTS                     ; 6 cycles

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
