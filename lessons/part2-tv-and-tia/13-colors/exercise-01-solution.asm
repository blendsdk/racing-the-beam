; =============================================================================
; LESSON 13 — EXERCISE 1 SOLUTION: Axes Swapped — Luminance Bands, Hue Clock
; =============================================================================
;
; Challenge: swap the lesson's two axes.  The picture becomes EIGHT equal
; bands of 24 lines — band j is luminance level 7-j (brightest on top,
; darkest at the bottom) — and the HUE is what steps over time: one hue
; every 120 frames, wrapping 15 -> 0.  The whole picture changes color
; together instead of dimming together.
;
; Why this works:
;   - The lesson's hue table still supplies the high nibble; here the LOW
;     nibble varies band by band instead.  LevelFields holds each band's
;     luminance field ($0E down to $00), and HueField holds the current
;     hue nibble.  OR the two and the palette byte is complete.
;   - The hue clock is the lesson's frame counter with the roles changed:
;     HueCounter ticks once per frame; every 120th tick the index advances.
;     INC then AND #$0F wraps 15 -> 0 — the Lesson 09 mask trick.
;   - Band 0 (the release line) still counts inside its 24: Y = 23 after
;     its color is written in HBLANK.
;   - Counted waits: 23 + 7 x 24 = 191, plus the release line = 192.  The
;     frame around it is untouched: 3 + 37 + 192 + 30 = 262.
;
; Debugger: watch HueIndex ($81) tick 0...15 once every ~2 seconds, and
; HueField ($82) walk $00, $10, $20, ... $F0.  COLUBK reads
; "HueField | this band's field", so breaking inside the band loop shows
; eight different bytes in one frame — one luminance column of the wheel.
;
; Expected screen: eight equal 24-line bands, bright at the top fading to
; almost black at the bottom, all in ONE hue — gray at first, then gold,
; orange, peach, red, pink, light violet, ... around the wheel every
; couple of seconds, wrapping back to gray.
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame and the swapped axes
; =============================================================================
VBLANK_LINES   = 37     ; blanked lines between VSYNC and the picture
BANDS          = 8      ; one band per luminance level
LINES          = 24     ; scanlines per band (8 x 24 = 192 visible lines)
OVERSCAN_LINES = 30     ; blanked lines after the picture
STEP_FRAMES    = 120    ; frames per hue step (~2 seconds at ~60 Hz)

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
HueCounter = $80        ; frames left in this hue step: 120 -> 0
HueIndex   = $81        ; the current hue, 0-15
HueField   = $82        ; the hue as the palette byte's high nibble: hue x 16

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

    LDA #STEP_FRAMES
    STA HueCounter          ; 120 frames until the first hue step
    LDA #$00
    STA HueIndex            ; hue 0 first (light gray columns)
    STA HueField            ; hue x 16 = $00

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; THE HUE CLOCK — one tick per frame, one hue per 120 ticks
; -----------------------------------------------------------------------------
    DEC HueCounter
    BNE NoHueStep           ; still counting: the hue holds
    LDA #STEP_FRAMES
    STA HueCounter
    INC HueIndex
    LDA HueIndex
    AND #$0F                ; wrap 15 -> 0 (Lesson 09's mask)
    STA HueIndex
    TAX
    LDA HueNibbles,X        ; hue nibble = hue x 16
    STA HueField
NoHueStep:
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
; VISIBLE — 192 lines = eight luminance bands of 24
; -----------------------------------------------------------------------------
; Band j's color is the current hue at level 7-j: the luminance field comes
; out of a table, the hue nibble out of RAM.  OR them together.
    LDA #$00
    STA VBLANK              ; release the beam — visible line 1
    LDX #$00
    LDA LevelFields,X       ; top band: level 7 ($0E)
    ORA HueField            ; the current hue
    STA COLUBK              ; lands in HBLANK: the release line shows it
    LDY #LINES-1            ; Y = 23: release line + 23 painted = 24
    JSR PaintLines
    LDX #$01                ; bands 1...7 remain
BandLoop:
    LDA LevelFields,X       ; this band's luminance field
    ORA HueField            ; the current hue
    LDY #LINES              ; a full band of 24
    JSR PaintLines
    INX
    CPX #BANDS
    BNE BandLoop

    STA WSYNC               ; let the last band line finish before blanking
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
; SUBROUTINE: PaintLines — paint Y scanlines with the color in A
; =============================================================================
; How to call:   A = color byte, Y = scanline count, then JSR PaintLines
; What it does:  waits for the next scanline to start, then writes the color
;                to COLUBK once per line for Y lines — every write lands in
;                HBLANK, so band boundaries fall exactly on scanlines.
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
; DATA — per-band luminance fields, brightest first
; =============================================================================
LevelFields:
    !byte $0E, $0C, $0A, $08    ; band 0-3: levels 7, 6, 5, 4
    !byte $06, $04, $02, $00    ; band 4-7: levels 3, 2, 1, 0

; The 16 hue nibbles, read as HueNibbles,X (aligned: no page-crossing fetch)
    !align 15, 0, 0
HueNibbles:
    !byte $00, $10, $20, $30    ; hues 0-3  (0 = light gray)
    !byte $40, $50, $60, $70    ; hues 4-7  (4 = red, 7 = violet)
    !byte $80, $90, $A0, $B0    ; hues 8-11 (8 = blue, 11 = teal-green)
    !byte $C0, $D0, $E0, $F0    ; hues 12-15 (12 = green, 15 = yellow)

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
