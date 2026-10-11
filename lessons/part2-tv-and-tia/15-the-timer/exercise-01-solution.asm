; =============================================================================
; LESSON 15 — EXERCISE 1 SOLUTION: Converting the VBLANK to a Timer
; =============================================================================
;
; Challenge: take the VBLANK wait from Lesson 12's 37-iteration WSYNC
; loop and convert it to a TIM64T wait — then show the freed time.
;
; What changed:
;   - before:  LDX #37 / STA WSYNC / DEX / BNE  x 37
;              (every line individually anchored; any work had to be
;              sliced to fit inside a single line's free cycles)
;   - after:   LDA #44 / STA TIM64T ... poll INTIM ... one WSYNC anchor
;              (one straight block of up to ~2,750 cycles: the whole
;              VBLANK belongs to the CPU, not to the beam)
;
; The freed time, in numbers:
;   - the loop version spent 8 cycles per line on overhead (WSYNC 3 +
;     DEX 2 + BNE 3) = 296 cycles of overhead, and the CPU's free time
;     came in 37 separate slices of at most ~65 cycles each.
;   - the timer version spends one ~7-cycle poll per check; the compute
;     block (~150 cycles) runs in one piece, tracked by a single rule:
;     finish before INTIM reaches zero.  The first poll reads INTIM
;     around 41 — three ticks spent on the compute, forty-one still counting.
;
; The overscan deliberately stays a WSYNC loop here: converting it is
; Exercise 2's job.  Everything else — the four 48-line bands, the hue
; clock, the four-color compute — is the main ROM's.
;
; Debugger checkpoints: StartFrame (259), VblankStart (0),
; VblankCompute (A = 44), HueStep, VblankPoll (A = the INTIM just read),
; VisibleStart (37), BandWrite, OverscanStart (229), OverscanLines.
;
; Expected screen: identical to the main ROM — the timer swap is
; invisible; it only buys the CPU time back.
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame, the timer budget, and the hue clock
; =============================================================================
VBLANK_TIMER  = 44      ; TIM64T ticks for exactly 37 lines (see the ledger)
BAND_LINES    = 48      ; each of the four bands' height
BANDS         = 4       ; bands across the visible 192 lines
OVERSCAN_LINES = 30     ; overscan, still counted by hand in this version
STEP_FRAMES   = 30      ; the hue advances every 30 frames (~0.5 s)
LUMINANCE_7   = $0E     ; luminance nibble: level 7 = %1110

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
; VBLANK — 37 lines, NOW COUNTED BY TIM64T = 44 (the exercise's change)
; -----------------------------------------------------------------------------
    LDA #$02
    STA VBLANK
    LDA #VBLANK_TIMER
    STA TIM64T              ; the converted wait: one timer, not 37 WSYNCs

VblankCompute:              ; debugger checkpoint: A = the timer value just written
; --- the freed time: the same compute the main ROM runs ---
    DEC StepCounter
    BNE NoStep
    LDA #STEP_FRAMES
    STA StepCounter
    LDA HueBase
    CLC
    ADC #1
    AND #$0F
HueStep:                    ; debugger checkpoint: fires every 30 frames
    STA HueBase
NoStep:
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
    LDA INTIM               ; how much blanking is left?
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
; OVERSCAN — 30 lines, still counted by hand (the before picture)
; -----------------------------------------------------------------------------
    LDA #$02
    STA VBLANK
    LDX #OVERSCAN_LINES
OverscanLines:
    STA WSYNC
    DEX
    BNE OverscanLines
    JMP StartFrame

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
