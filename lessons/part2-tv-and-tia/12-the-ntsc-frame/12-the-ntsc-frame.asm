; =============================================================================
; LESSON 12: The NTSC Frame — 262 Scanlines of Precision
; =============================================================================
; Part 2: TV & TIA
;
; What this program does:
;   Draws the canonical NTSC frame EXPLICITLY, line by line, with no frame
;   macros — so every phase of a television frame is visible in the source:
;
;     VSYNC   3 lines    tell the TV "a new frame starts now"
;     VBLANK  37 lines   blanked — the picture is suppressed
;     visible 192 lines  four equal bands of 48: $42 $84 $C8 $1A
;     overscan 30 lines  blanked again
;     -----------------
;     total   262 lines  one TV frame at ~60 Hz
;
;   There is nothing to "draw" into: the 2600 has no frame buffer.  Every
;   line of the picture is produced by waiting the right amount of time.
;   The ruler is STA WSYNC — it halts the CPU until the current scanline
;   ends — so each write costs exactly one line.  Count them: 3 + 37 + 192
;   + 30 = 262 writes of WSYNC per pass of the frame loop, and the loop
;   runs once per frame.  That is the whole trick, and it is stable.
;
;   The visible area is four bands of 48 lines: red $42, blue $84, green
;   $C8, gold $1A, top to bottom.  Band 0's color is written into COLUBK in
;   HBLANK right after VBLANK is cleared, so the beam-release line is the
;   top band's FIRST line — that is what makes "four equal 48-line bands"
;   literally true.  Every other line is one WSYNC plus one COLUBK write.
;
; What you'll learn:
;   - The vertical structure of an NTSC frame and what each phase is for
;   - Why VSYNC must be exactly 3 lines; what VBLANK and overscan are
;   - STA WSYNC as the line ruler: one write = one scanline of waiting
;   - A frame written out by hand — the same frame +vsync / +set_timer /
;     +wait_timer have been building since Lesson 04, opened up
;   - Where the numbers come from: 228 color clocks = 76 CPU cycles per
;     line; 3 + 37 + 192 + 30 = 262 lines; 262 x 228 clocks gives ~59.9 Hz
;
; Frame geometry: the release line is counted inside band 0's 48 lines, and
;   the frame loop waits out exactly 262 scanlines per pass (3 + 37 + 191
;   + 1 + 30 counted waits: band 0 paints its release line without a wait,
;   the post-visible WSYNC lets the last band line finish).
;
; Build: acme -f plain -o build/lesson12.bin \
;        lessons/part2-tv-and-tia/12-the-ntsc-frame/12-the-ntsc-frame.asm
; Run:   stella build/lesson12.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; only +clean_start is used this time ---
; The frame itself is written out below, so the frame macros have nothing
; left to do here — comparing it against them is half the point (see the
; walkthrough in docs/part2-tv-and-tia/12-the-ntsc-frame.md).
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the phase lengths, summing to 262
; =============================================================================
VBLANK_LINES   = 37     ; blanked lines between VSYNC and the picture
BANDS          = 4      ; visible bands, top to bottom
LINES          = 48     ; scanlines per band (4 x 48 = 192 visible lines)
OVERSCAN_LINES = 30     ; blanked lines after the picture
                        ;   (VSYNC is the three STA WSYNCs below — there is no
                        ;    number to name because the code IS the count)

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame = 262 scanlines
; =============================================================================
; The frame is four counted waits.  Each phase begins on the FIRST line it
; describes, and the four checkpoints below mark those lines for the
; debugger: break at each label and read the scanline it reports — the
; values advance 3, 37, 192, 30, and then wrap back to the start every
; frame (the loop waits out exactly 262 lines).  Stella numbers the
; frame from the VSYNC-off boundary, so the four values read 259, 0,
; 37 and 229 — the differences are the phase lengths.
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; VSYNC — exactly 3 lines
; -----------------------------------------------------------------------------
; VSYNC is the "new frame starts here" pulse the TV locks onto.  Three lines
; is not a style choice: two or four can make real televisions lose color.
    LDA #$02                ; bit 1 = start VSYNC
    STA VSYNC               ; pulse on — the 3 VSYNC lines begin here
    STA WSYNC               ; VSYNC line 1 ends
    STA WSYNC               ; VSYNC line 2 ends
    STA WSYNC               ; VSYNC line 3 ends
    LDA #$00
    STA VSYNC               ; pulse off — VSYNC covered exactly 3 lines

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
; -----------------------------------------------------------------------------
; VBLANK — 37 blanked lines
; -----------------------------------------------------------------------------
; VBLANK suppresses the picture while the TV's beam re-traces to the top of
; the screen.  On a game this is where the logic runs; here it is a counted
; wait, one STA WSYNC per line.  (+set_timer / +wait_timer measure this same
; period with the RIOT timer — the reader has used them since Lesson 04.)
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    LDX #VBLANK_LINES       ; 37 lines to wait out
VblankLines:
    STA WSYNC               ; wait out one blanked line
    DEX
    BNE VblankLines

VisibleStart:               ; debugger checkpoint: visible's first line (Stella: 37)
; -----------------------------------------------------------------------------
; VISIBLE — 192 lines = four equal bands of 48
; -----------------------------------------------------------------------------
; Releasing VBLANK turns the beam loose.  The release line belongs to band
; 0, so band 0's color goes into COLUBK first — written in HBLANK, before
; the visible portion of the line starts — and the loop settles into one
; color write per line.
    LDA #$00
    STA VBLANK              ; release the beam — this line is visible line 1
    LDA BandColors          ; band 0's color: $42 (red)
    STA COLUBK              ; lands in HBLANK: the release line shows $42
    LDY #LINES-1            ; Y = 47: release line + 47 painted = band 0's 48
    JSR PaintLines          ; paint them — A survives, X is never touched
    LDX #$01                ; bands 1...3 remain
BandLoop:
    LDA BandColors,X        ; this band's color, out of the table
    LDY #LINES              ; a full band of 48
    JSR PaintLines
    INX                     ; next band
    CPX #BANDS              ; 1, 2, 3 — stop after the bottom band
    BNE BandLoop

    STA WSYNC               ; let the last band line finish before blanking:
                            ; the beam is still drawing it, so blanking now
                            ; would clip it partway across
    LDA #$02
OverscanStart:              ; debugger checkpoint: overscan's first line (Stella: 229)
    STA VBLANK              ; blank the screen for overscan
    LDX #OVERSCAN_LINES     ; 30 lines to wait out
OverscanLines:
    STA WSYNC               ; wait out one blanked line
    DEX
    BNE OverscanLines

    JMP StartFrame          ; 3 + 37 + 192 + 30 = 262 lines done: next frame

; =============================================================================
; SUBROUTINE: PaintLines — paint Y scanlines with the color in A
; =============================================================================
; How to call:   A = color byte, Y = scanline count, then JSR PaintLines
; What it does:  waits for the next scanline to start, then writes the color
;                to COLUBK once per line for Y lines.  Writing the color
;                right after the WSYNC puts the change in the first few
;                cycles of the line — while the beam is still in HBLANK —
;                so band boundaries fall exactly on a scanline instead of
;                showing a notch where a new color arrives mid-line.
; Registers:     A survives (still the color) and X is never touched — the
;                band index lives in X, so the kernel depends on that — and
;                Y is used up: the line counter counts it down to 0.
; Stack:         JSR pushed the return address; the RTS pops it.  Nothing
;                else is pushed inside, so callers can use the stack freely.
; =============================================================================
PaintLines:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEY                     ; one line fewer to go
    BNE -                   ; loop until the line counter reaches 0
    RTS                     ; return; the return address comes off the stack

; =============================================================================
; DATA — the four band colors, read as BandColors,X
; =============================================================================
; One byte per band, top to bottom.  The bytes ARE the picture: there is no
; computation anywhere in this program that turns one value into another.
BandColors:
    !byte $42               ; band 0 (top)    — red
    !byte $84               ; band 1          — blue
    !byte $C8               ; band 2          — green
    !byte $1A               ; band 3 (bottom) — gold

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
