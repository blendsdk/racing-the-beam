; =============================================================================
; LESSON 14 — EXERCISE 1 SOLUTION: Moving the Split (One Constant)
; =============================================================================
;
; Challenge: move the boundary to another line.  The whole answer is one
; constant:  TOP_LINES = 64  (was 96).  Everything else — the anchored
; per-line writes, the mode clock, the late mode's delay — is unchanged.
;
; Why this works:
;   - TOP_LINES drives both loops: after the release line, the top loop
;     paints TOP_LINES-1 = 63 more lines (visible lines 1-64), and the
;     bottom loop paints BOTTOM_LINES-1 = 127 more after the boundary
;     line (visible lines 65-192).  64 + 128 = 192 — the frame keeps
;     its exact shape, only the split moves.
;   - The boundary line is still far from the frame's edges, so the late
;     mode's tear still lands on it: red for its first 76 pixels, then
;     blue — now on visible line 65 instead of 97.
;
; Debugger: the anchor and boundary write now happen on visible line 65
; (Stella scanline 101); the late store still lands at line-cycle 47.
;
; Expected screen: the same anchored split, moved up — the top third red,
; the bottom two thirds blue.  Aligned mode: a clean edge just above visible line 65.
; Late mode: the static tear on visible line 65, identical every frame.
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame, the split, and the clock
; =============================================================================
VBLANK_LINES   = 37     ; blanked lines between VSYNC and the picture
VISIBLE_LINES  = 192    ; visible scanlines
TOP_LINES      = 64     ; THE ONE CHANGE: red lines at the top (was 96)
BOTTOM_LINES   = VISIBLE_LINES-TOP_LINES   ; blue lines below (128 now)
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
; VISIBLE — 64 red lines, one boundary line, 127 blue lines
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam — visible line 1
    LDA #$42                ; the top third's red
    STA COLUBK              ; lands in HBLANK: the release line shows it
    LDY #TOP_LINES-1        ; 63 more lines complete the top's 64
TopLoop:
    STA WSYNC
TopWrite:                   ; debugger checkpoint: every line, always in HBLANK
    STA COLUBK              ; paint it red
    DEY
    BNE TopLoop
    ; --- the last red line (visible line 64) is painted; the CPU is still early in it ---
    STA WSYNC               ; the anchor: wait out visible line 64 -> line 65 starts

    LDA Mode
    BEQ BoundaryWrite       ; aligned: write the boundary color immediately
    JSR DelayBottom         ; late: 38 cycles of work that HBLANK cannot hide
BoundaryWrite:              ; debugger checkpoint: where the two modes differ
    LDA #$84                ; the bottom's blue
    STA COLUBK              ; aligned: HBLANK; late: mid-picture — a static tear

    LDY #BOTTOM_LINES-1     ; 127 more lines complete the bottom's 128
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
; Burns a fixed 26 cycles (LDX + a five-pass DEX/BNE loop); with JSR and
; RTS that is 38 cycles between the anchor and the color load — more than
; HBLANK's ~23-cycle window, so the boundary write lands in the visible
; portion.  Exercise 2 shows the repair: move this work before the anchor.
; Registers: X is used up; A and Y are untouched.
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
