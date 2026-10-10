; =============================================================================
; LESSON 12 — EXERCISE 1 SOLUTION: Four Bands from RAM
; =============================================================================
;
; Challenge: keep the four 48-line bands exactly as they are, but move the
; colors into RAM — four bytes written once at startup and read by the
; kernel every frame.
;
; Why this works:
;   - The colors are the lesson's four bytes — $42, $84, $C8, $1A — but
;     they now live at $80-$83 (RIOT RAM) instead of in the cartridge.
;   - The copy at startup is a small count-down loop: X runs 3, 2, 1, 0 and
;     moves RomColors[X] into BandColors[X].  DEX past 0 wraps to $FF and
;     sets N, so BPL exits — Lesson 07's count-down shape.
;   - The kernel's reads change with the data's home: the non-indexed
;     band-0 read drops from absolute to zero-page addressing (4 cycles ->
;     3), while the indexed reads stay at 4 cycles either way (zp,X and
;     abs,X cost the same).  The frame is one cycle faster in total — the
;     point of the move is that the colors are now data the program can
;     edit, not that it is faster.
;   - The frame is untouched: still 3 + 37 + 192 + 30 = 262 counted
;     scanlines per pass of the loop.
;
; Debugger: run, open the memory view, and edit $80-$83 — change $42 to
; $E8 and the top band turns pink on the very next frame.  A ROM byte
; cannot do that; RAM can, and this is why anything that changes lives
; there.
;
; Expected screen: the lesson's four equal 48-line bands — red, blue,
; green, gold — with identical geometry, now sourced from RAM.
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the phase lengths, summing to 262
; =============================================================================
VBLANK_LINES   = 37     ; blanked lines between VSYNC and the picture
BANDS          = 4      ; visible bands, top to bottom
LINES          = 48     ; scanlines per band (4 x 48 = 192 visible lines)
OVERSCAN_LINES = 30     ; blanked lines after the picture

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
BandColors = $80        ; four bytes, one per band: 0 (top) ... 3 (bottom)

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

; -----------------------------------------------------------------------------
; COPY THE COLORS INTO RAM — once, at startup
; -----------------------------------------------------------------------------
; Four moves, X = 3 down to 0.  After this the kernel never looks at
; RomColors again: the picture is driven by $80-$83.
    LDX #BANDS-1            ; X = 3: the bottom band's byte first
CopyColors:
    LDA RomColors,X         ; read the color out of the cartridge...
    STA BandColors,X        ; ...and store it at $80 + X
    DEX                     ; 3, 2, 1, 0, then wraps to $FF (N set)
    BPL CopyColors          ; done after the four copies
ColorsReady:                ; debugger checkpoint: $80-$83 now hold $42 $84 $C8 $1A

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; VSYNC — exactly 3 lines
; -----------------------------------------------------------------------------
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
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    LDX #VBLANK_LINES       ; 37 lines to wait out
VblankLines:
    STA WSYNC               ; wait out one blanked line
    DEX
    BNE VblankLines

VisibleStart:               ; debugger checkpoint: visible's first line (Stella: 37)
; -----------------------------------------------------------------------------
; VISIBLE — 192 lines = four equal bands of 48, colors from RAM
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam — this line is visible line 1
    LDA BandColors          ; band 0's color — a ZERO-PAGE read this time ($80)
    STA COLUBK              ; lands in HBLANK: the release line shows it
    LDY #LINES-1            ; Y = 47: release line + 47 painted = band 0's 48
    JSR PaintLines
    LDX #$01                ; bands 1...3 remain
BandLoop:
    LDA BandColors,X        ; this band's color, out of RAM ($80 + X)
    LDY #LINES
    JSR PaintLines
    INX
    CPX #BANDS
    BNE BandLoop

    STA WSYNC               ; let the last band line finish before blanking
    LDA #$02
OverscanStart:              ; debugger checkpoint: overscan's first line (Stella: 229)
    STA VBLANK              ; blank the screen for overscan
    LDX #OVERSCAN_LINES     ; 30 lines to wait out
OverscanLines:
    STA WSYNC
    DEX
    BNE OverscanLines

    JMP StartFrame          ; 262 lines done: next frame

; =============================================================================
; SUBROUTINE: PaintLines — paint Y scanlines with the color in A
; =============================================================================
; How to call:   A = color byte, Y = scanline count, then JSR PaintLines
; What it does:  waits for the next scanline to start, then writes the color
;                to COLUBK once per line for Y lines — the color write lands
;                in HBLANK, so band boundaries fall exactly on a scanline.
; Registers:     A survives, X is never touched (the band index lives there),
;                Y is used up counting lines down to 0.
; Stack:         JSR pushed the return address; the RTS pops it.
; =============================================================================
PaintLines:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEY                     ; one line fewer to go
    BNE -
    RTS

; =============================================================================
; DATA — the startup copy's source bytes
; =============================================================================
RomColors:
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
