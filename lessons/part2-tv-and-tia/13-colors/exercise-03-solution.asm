; =============================================================================
; LESSON 13 — EXERCISE 3 SOLUTION: One Hue Breathing (Stretch Goal)
; =============================================================================
;
; Challenge: a one-hue fade — the whole picture is a SINGLE band of 192 lines
; in one hue (red, hue 4), and it breathes through all eight luminance levels:
; dark to bright to dark, over and over.
;
; Why this works:
;   - The breath is a 14-step sequence of luminance fields, held in a table:
;     $00, $02, ..., $0E (the eight levels, rising), then $0C, $0A, ..., $02
;     (falling).  Wrapping from the last entry back to the first continues
;     the cycle: level 1 -> level 0 -> level 1 ... The eight levels are all
;     there; the endpoints are visited once per breath.
;   - FadeIndex walks the table; FadeColor caches the finished byte,
;     "hue 4 x 16 | field" — so the visible area needs no computation at all.
;   - The step is faster than the lesson's: one table entry every 30 frames
;     (about half a second), so a full breath takes about seven seconds.
;   - One band means one color write: the release line's write in HBLANK
;     already carries the color, and COLUBK stays latched all 192 lines.
;     Counted waits: 192 for the visible lines, then the frame's usual
;     3 + 37 + 30 — 262 in all.
;
; Debugger: break at FadeStep (one hit per breath step) and watch A walk
; $40, $42, ... $4E, then back down $4C, $4A, ... $42 — the byte is stored
; at FadeColor ($82) right after.  $4E is red at its brightest; $40 is red
; at its darkest — still red, not black.
;
; Expected screen: one solid field of red that slowly brightens from
; its darkest shade to its brightest, then fades back down, endlessly.
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame, the hue, and the breath
; =============================================================================
VBLANK_LINES   = 37     ; blanked lines between VSYNC and the picture
VISIBLE_LINES  = 192    ; the whole picture is one band of 192 lines
OVERSCAN_LINES = 30     ; blanked lines after the picture
FADE_STEP      = 30     ; frames per breath step (~0.5 second at ~60 Hz)
FADE_STEPS     = 14     ; entries in the breath: 8 up + 6 down
FADE_HUE       = $40    ; hue 4 (red) x 16 — the high nibble, constant here

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
FadeCounter = $80       ; frames left in this breath step: 30 -> 0
FadeIndex   = $81       ; position in the breath: 0...13
FadeColor   = $82       ; the finished byte: hue 4 + this step's field

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

    LDA #FADE_STEP
    STA FadeCounter         ; 30 frames until the first breath step
    LDA #$00
    STA FadeIndex           ; start at the breath's darkest end
    LDA #FADE_HUE           ; field $00: red at level 0
    STA FadeColor

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; THE BREATH CLOCK — one tick per frame, one breath step per 30 ticks
; -----------------------------------------------------------------------------
    DEC FadeCounter
    BNE NoFade              ; still counting: the color holds
    LDA #FADE_STEP
    STA FadeCounter
    INC FadeIndex
    LDX FadeIndex
    CPX #FADE_STEPS         ; 14 entries: after the last, back to the first
    BNE NoWrap
    LDX #$00
    STX FadeIndex
NoWrap:
    LDA FadeTable,X         ; this step's luminance field
    ORA #FADE_HUE           ; hue 4 << 4
FadeStep:                   ; debugger checkpoint: one hit per breath step
    STA FadeColor
NoFade:
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
; VISIBLE — one band of 192 lines, one latched color
; -----------------------------------------------------------------------------
; The color write lands in HBLANK of the release line; after that COLUBK is
; simply left alone while the beam sweeps all 192 lines.
    LDA #$00
    STA VBLANK              ; release the beam — visible line 1
    LDA FadeColor           ; the current breath step's byte
    STA COLUBK              ; lands in HBLANK: the release line shows it
    LDX #VISIBLE_LINES      ; wait out all 192 visible lines
SolidLines:
    STA WSYNC
    DEX
    BNE SolidLines

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
; DATA — the breath: 14 luminance fields, up then down
; =============================================================================
FadeTable:
    !byte $00, $02, $04, $06    ; rising: levels 0, 1, 2, 3
    !byte $08, $0A, $0C, $0E    ; rising: levels 4, 5, 6, 7
    !byte $0C, $0A, $08, $06    ; falling: levels 6, 5, 4, 3
    !byte $04, $02              ; falling: levels 2, 1 — wraps to level 0

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
