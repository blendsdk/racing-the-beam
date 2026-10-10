; =============================================================================
; LESSON 14 — EXERCISE 2 SOLUTION: Repairing the Late Mode (Budget Fix)
; =============================================================================
;
; Challenge: make the late mode's write land in HBLANK again — without
; deleting the work.  The fix is ORDERING, not speed:
;
;   before:  anchor -> mode check -> (late: 38 cycles of work) -> write
;   after:   mode check -> (late: 38 cycles of work) -> anchor -> write
;
; The work still happens — but it happens in visible line 96, which still has
; almost its whole 76-cycle budget free, instead of after the anchor,
; where only HBLANK's ~23 cycles are available.  The anchored write then
; stays immediate.
;
; Why this works:
;   - Line 95 is already painted red by the top loop; burning its spare
;     cycles changes nothing on screen.
;   - After the anchor, the only work is LDA #$84 + STA COLUBK (5
;     cycles), so the store lands at line-cycle 4 — deep inside HBLANK
;     (its write goes out around color clock 13, with more than 50
;     clocks of margin before the picture begins).
;   - Both modes now produce the identical clean 96/96 split; the ROM
;     still alternates modes every 120 frames, and on screen you cannot
;     tell.
;
; The discipline in one line: finish your line's work BEFORE the line
; you need the result on.
;
; Debugger: break at StoreDone — the instruction right after the store.
; The log reads scanline 133, cycle 5 in BOTH modes (let it run across a
; flip: frames 120-239 are the late mode), and the tear never appears.
; (Exercise 3 verifies this budget with two breakpoints.)
;
; Expected screen: two equal halves, red over blue, a clean boundary in
; BOTH modes — the tear is gone.
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
    EOR #$01                ; the modes still alternate: both are clean now
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
    ; --- visible line 96 is painted red; the CPU is still early in it, with
    ; --- almost the whole line budget free: THIS is where the work goes ---
    LDA Mode
    BEQ Anchor              ; aligned: no extra work to do
    JSR DelayBottom         ; late: the same 38 cycles — paid for in visible line 96
Anchor:
    STA WSYNC               ; the anchor: wait out visible line 96 -> line 97 starts
BoundaryWrite:              ; debugger checkpoint: in HBLANK in BOTH modes
    LDA #$84                ; the bottom half's blue
    STA COLUBK              ; store at line-cycle 4 — the tear is gone
StoreDone:                  ; debugger checkpoint: the store is complete

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
; visible line 96, before the anchor — where the line budget can afford it.
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
