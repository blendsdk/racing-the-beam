; =============================================================================
; LESSON 14: WSYNC and Timing — Synchronizing with the Beam
; =============================================================================
; Part 2: TV & TIA
;
; What this program does:
;   The "anchored split": the picture is two equal halves — red ($42) on
;   top, blue ($84) below — with the color boundary sitting on the middle
;   line (visible line 97).  The ROM draws it TWO ways, alternating the
;   mode every 120 frames (~2 seconds):
;
;     - aligned mode:  the boundary color is written right after a WSYNC
;       anchor, so the write lands in HBLANK (the line's first ~23 CPU
;       cycles) and the boundary line is entirely blue: a clean edge.
;
;     - late mode:     the boundary color write is deliberately late — a
;       short delay routine runs AFTER the anchor, so the write lands
;       about 24 CPU cycles into the visible portion.  The boundary
;       line paints red for its first 76 of 160 pixels, then blue:
;       a static tear, identical every frame.
;
;   Every per-line write in both modes is anchored by WSYNC and lands in
;   HBLANK; the only difference is what happens after the boundary's
;   anchor.  That is the lesson: WSYNC pins your code to the line, and
;   HBLANK is the ~23-cycle window where a write is invisible.
;
; What you'll learn:
;   - the 76-cycle scanline: 68 color clocks of HBLANK + 160 visible
;     (3 color clocks per CPU cycle)
;   - what WSYNC actually waits for: the END of the current line
;   - why a write that misses HBLANK tears the line it lands on
;   - why fixed late work gives a STATIC tear, and varying work moves it
;     (the movement real games show — Lesson 17 counts those cycles)
;   - the discipline: finish your line's work in the line
;
; The boundary ledgers (cycles counted from the anchor that starts visible line 97):
;   aligned: LDA Mode 3 + BEQ 3 (taken) + LDA #$84 2 + STA COLUBK 3
;            -> store at cycle 10, still in HBLANK (pixel -38)
;   late:    LDA Mode 3 + BEQ 2 + JSR 6 + delay loop 26 + RTS 6 +
;            LDA #$84 2 + STA COLUBK 3
;            -> store at cycle 47: ~24 CPU cycles into the visible
;               portion — the boundary line paints red for its first
;               76 of 160 pixels, then blue
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), VisibleStart (37),
;   TopWrite, BoundaryWrite, BottomWrite, OverscanStart (229).
;
; Build: acme -f plain -o build/lesson14.bin \
;        lessons/part2-tv-and-tia/14-wsync-and-timing/14-wsync-and-timing.asm
; Run:   stella build/lesson14.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame, the split, and the clock
; =============================================================================
VBLANK_LINES   = 37     ; blanked lines between VSYNC and the picture
VISIBLE_LINES  = 192    ; visible scanlines: two halves of 96
TOP_LINES      = 96     ; red lines at the top (Exercise 1 moves this split)
BOTTOM_LINES   = VISIBLE_LINES-TOP_LINES   ; blue lines below (96 here)
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
    STA ModeCounter         ; 120 frames until the first mode flip
    LDA #$00
    STA Mode                ; start aligned — the first frames are the clean ones

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; THE MODE CLOCK — one tick per frame, a flip every 120 ticks
; -----------------------------------------------------------------------------
    DEC ModeCounter
    BNE NoFlip              ; still counting: the mode holds
    LDA #MODE_FRAMES
    STA ModeCounter
    LDA Mode
    EOR #$01                ; $00 <-> $01: swap the boundary discipline
    STA Mode
NoFlip:
; -----------------------------------------------------------------------------
; VSYNC — exactly 3 lines (Lesson 12)
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = start VSYNC
    STA VSYNC
    STA WSYNC               ; VSYNC line 1 ends
    STA WSYNC               ; VSYNC line 2 ends
    STA WSYNC               ; VSYNC line 3 ends
    LDA #$00
    STA VSYNC               ; pulse off — exactly 3 lines

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
; -----------------------------------------------------------------------------
; VBLANK — 37 blanked lines (Lesson 12)
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
; VISIBLE — 96 red lines, one boundary line (clean or torn), 95 blue lines
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam — visible line 1
    LDA #$42                ; the top half's red
    STA COLUBK              ; lands in HBLANK: the release line shows it
    LDY #TOP_LINES-1        ; 95 more lines complete the top half's 96
TopLoop:
    STA WSYNC               ; wait for the next line to start
TopWrite:                   ; debugger checkpoint: every line, always in HBLANK
    STA COLUBK              ; paint it red (store lands at line-cycle 2)
    DEY
    BNE TopLoop
    ; --- the last red line (visible line 96) is painted; the CPU is still early in it ---
    STA WSYNC               ; THIS is the anchor: wait out visible line 96 -> line 97

    LDA Mode
    BEQ BoundaryWrite       ; aligned: write the boundary color immediately
; -----------------------------------------------------------------------------
; LATE MODE — do extra work first, and pay for it with a torn line
; -----------------------------------------------------------------------------
    JSR DelayBottom         ; 38 cycles of "work" that HBLANK cannot hide
BoundaryWrite:              ; debugger checkpoint: where the two modes differ
    LDA #$84                ; the bottom half's blue
    STA COLUBK              ; aligned: HBLANK; late: mid-picture — a static tear

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
; SUBROUTINE: DelayBottom — the late mode's deliberate overrun (26 cycles)
; =============================================================================
; What it does:  burns a fixed 26 cycles: LDX (2) + five loop passes
;                (4 x (DEX+BNE) + the final DEX+BNE = 24).  With the JSR
;                and RTS around it (12 more), the late path spends 38
;                cycles of work between the anchor and the color load —
;                far more than HBLANK's ~23-cycle window, so the write
;                that follows lands in the visible portion.  Any real
;                kernel does work like this (state updates, sprite math);
;                the lesson is to do it BEFORE the anchor, not after it.
; Registers:     X is used up; A and Y are untouched.
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
