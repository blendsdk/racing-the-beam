; =============================================================================
; LESSON 15 — EXERCISE 2 SOLUTION: The Overscan Timer, and a Moved Computation
; =============================================================================
;
; Challenge: compute the overscan timer value yourself, and move one
; computation out of the VBLANK into the newly-freed overscan window.
;
; Computing the value (36):
;   - the overscan is 30 lines = 30 x 76 = 2,280 cycles;
;   - the timer write lands at cycle 16 of the first overscan line, so
;     2,264 cycles remain to cover;
;   - the timer's first tick lands one cycle after the write, then one
;     every 64: 36 ticks cover 1 + 35 x 64 = 2,241 cycles — inside the
;     window;
;   - 37 ticks would cover 2,305 — one line late.
;   (The classic 35 covers only 1 + 34 x 64 = 2,177 cycles: 29 lines.)
;
; The moved computation: the hue clock (DEC StepCounter / reload /
; advance n) — about 24 cycles on step frames — now runs in the
; overscan, after the frame it belongs to has already been drawn.
; The VBLANK keeps only the four-color compute.  One consequence is
; visible only in the debugger: the step now applies to the NEXT
; frame's colors, so the first n = 1 picture is frame 31 instead of
; frame 30 — a one-frame phase shift no eye can catch.
;
; Ledgers:
;   - VBLANK:   timer 44; compute ~135 cycles; first poll reads ~41.
;   - Overscan: timer 36; the step block ~24 cycles; first poll reads ~35;
;               the last tick lands at ~cycle 2,257 (line 258, cycle 53);
;               the anchor parks the rest of line 258 — VSYNC at 259.
;
; Debugger checkpoints: StartFrame (259), VblankStart (0),
; VblankCompute (A = 44), VblankPoll (A = the INTIM just read),
; VisibleStart (37), BandWrite, OverscanStart (229),
; OverscanCompute (A = 36), HueStep (now fires in the overscan),
; OverscanPoll (A = the INTIM just read).
;
; Expected screen: the same four bands advancing in step every half
; second — the moved step changes nothing you can see.
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame, both timer budgets, and the hue clock
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines (see the ledger)
BAND_LINES     = 48     ; each of the four bands' height
BANDS          = 4      ; bands across the visible 192 lines
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines (see the ledger)
STEP_FRAMES    = 30     ; the hue advances every 30 frames (~0.5 s)
LUMINANCE_7    = $0E    ; luminance nibble: level 7 = %1110

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
HueBase     = $80       ; n: the top band's hue (0-15), stepped every 30 frames
StepCounter = $81       ; frames until the next hue step: 30 -> 0
Temp        = $82       ; scratch: keeps the running hue in the color builder
BandColors  = $83       ; 4 bytes: precomputed colors for the four bands

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

    LDA #$00
    STA HueBase
    LDA #STEP_FRAMES
    STA StepCounter

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; VSYNC — exactly 3 lines
; -----------------------------------------------------------------------------
    LDA #$02
    STA VSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    LDA #$00
    STA VSYNC

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
; -----------------------------------------------------------------------------
; VBLANK — 37 lines via TIM64T = 44; the freed time now holds the colors
; -----------------------------------------------------------------------------
    LDA #$02
    STA VBLANK
    LDA #VBLANK_TIMER
    STA TIM64T

VblankCompute:              ; debugger checkpoint: A = the timer value just written
; --- the four band colors (the hue clock moved to the overscan) ---
    LDA HueBase
    LDX #0
ComputeLoop:
    STA Temp
    AND #$0F
    ASL
    ASL
    ASL
    ASL
    ORA #LUMINANCE_7
    STA BandColors,X
    LDA Temp
    CLC
    ADC #4
    INX
    CPX #BANDS
    BNE ComputeLoop

VblankWait:
    LDA INTIM
VblankPoll:                 ; debugger checkpoint: A = the value just read
    BNE VblankWait
    STA WSYNC               ; line up with the beam
    LDA #$00
    STA VBLANK              ; release the beam — visible line 1
VisibleStart:               ; debugger checkpoint: the picture's first line (Stella: 37)
; -----------------------------------------------------------------------------
; VISIBLE — four equal 48-line bands (unchanged)
; -----------------------------------------------------------------------------
    LDX #0
BandBegin:
    LDA BandColors,X
    STA COLUBK
    LDY #BAND_LINES-1
BandLines:
    STA WSYNC
BandWrite:                  ; debugger checkpoint: one hit per line, in HBLANK
    STA COLUBK
    DEY
    BNE BandLines
    STA WSYNC               ; anchor
    INX
    CPX #BANDS
    BNE BandBegin

OverscanStart:              ; debugger checkpoint: overscan's first line (Stella: 229)
; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines via TIM64T = 36, and the MOVED computation: the hue
; clock now ticks here, in the frame's other blanking window.
; -----------------------------------------------------------------------------
    LDA #$02
    STA VBLANK
    LDA #OVERSCAN_TIMER
    STA TIM64T              ; the computed value: 36 ticks for 30 lines

OverscanCompute:            ; debugger checkpoint: A = the timer value just written
; --- the moved computation: advance the hue clock for the next frame ---
    DEC StepCounter
    BNE NoStep
    LDA #STEP_FRAMES
    STA StepCounter
    LDA HueBase
    CLC
    ADC #1
    AND #$0F
HueStep:                    ; debugger checkpoint: fires every 30 frames, in the overscan
    STA HueBase
NoStep:
OverscanWait:
    LDA INTIM
OverscanPoll:               ; debugger checkpoint: A = the value just read
    BNE OverscanWait
    STA WSYNC               ; line up with the beam for VSYNC's first line
    JMP StartFrame

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
