; =============================================================================
; LESSON 15 — EXERCISE 3 SOLUTION: Split the Work, Prove Both Windows (Stretch)
; =============================================================================
;
; Challenge: split the per-frame work across both blanking windows and
; prove with the ledger that each fits.
;
; The split:
;   - VBLANK (timer 44): the hue clock (~24 cycles on step frames) and
;     bands 0-1's colors (two ComputeBand calls, ~80 cycles including
;     the JSR/RTS overhead) — about 110 cycles of work; the first poll
;     reads ~42.
;   - Overscan (timer 36): bands 2-3's colors (~89 cycles) — the first
;     poll reads ~34 (two ticks pass during the compute).
;   Both windows keep thousands of cycles in reserve.  The proof is
;   each window's first poll value: a poll that read zero immediately
;   would mean the work had overrun the window; neither ever does.
;
; Shared subroutine: ComputeBand — A = the band's hue, X = its index;
; stores the color byte and returns with A advanced by 4 and X by 1.
; It is called four times per frame, twice in each blanking window.
;
; The two-breakpoint recipe:
;   acme -f plain -l build/ex3-l15.sym -o build/ex3-l15.bin \
;     lessons/part2-tv-and-tia/15-the-timer/exercise-03-solution.asm
;   grep -E "VblankCompute|OverscanCompute|VblankPoll|OverscanPoll" build/ex3-l15.sym
;
;   then one breakpoint per run on the committed ROM.  The shipped
;   addresses (grep the symbol file to confirm):  VblankCompute $F02D,
;   VblankPoll $F04B, OverscanCompute $F072, OverscanPoll $F082.
;   - VblankCompute   right after STA TIM64T: A = 44 (the written value);
;   - OverscanCompute right after STA TIM64T: A = 36 (the written value);
;   - VblankPoll:   A = the INTIM just read — first hit ~42, down to 0;
;   - OverscanPoll: A = the INTIM just read — first hit ~34, down to 0.
;
; Expected screen: the same four bands advancing in step every half
; second — the work is just spread across both blanking periods now.
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
; VBLANK — 37 lines via TIM64T = 44: the hue clock and bands 0-1 here
; -----------------------------------------------------------------------------
    LDA #$02
    STA VBLANK
    LDA #VBLANK_TIMER
    STA TIM64T

VblankCompute:              ; debugger checkpoint: A = the timer value just written
; --- first half of the work: the hue clock, then bands 0 and 1 ---
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
    JSR ComputeBand         ; band 0
    JSR ComputeBand         ; band 1

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
; OVERSCAN — 30 lines via TIM64T = 36: the second half of the work
; -----------------------------------------------------------------------------
    LDA #$02
    STA VBLANK
    LDA #OVERSCAN_TIMER
    STA TIM64T

OverscanCompute:            ; debugger checkpoint: A = the timer value just written
; --- second half: bands 2 and 3, in the other blanking window ---
    LDA HueBase
    CLC
    ADC #8                  ; band 2's hue is n + 8
    LDX #2
    JSR ComputeBand         ; band 2
    JSR ComputeBand         ; band 3

OverscanWait:
    LDA INTIM
OverscanPoll:               ; debugger checkpoint: A = the value just read
    BNE OverscanWait
    STA WSYNC               ; line up with the beam for VSYNC's first line
    JMP StartFrame

; =============================================================================
; SUBROUTINE: ComputeBand — build one band's color byte and store it
; =============================================================================
; In:      A = the band's hue, X = the band's index (0-3)
; Out:     A = the next band's hue (+4), X = the next index
; Uses:    Temp (scratch).  The byte built is %HHHHLLL0 with luminance 7.
; Cycles:  34 for the body (including its RTS); 40 per call (34 + 6 for the JSR).
; =============================================================================
ComputeBand:
    STA Temp                ; keep the hue
    AND #$0F                ; mod 16 (n + 4k can pass 15)
    ASL
    ASL
    ASL
    ASL                     ; hue << 4
    ORA #LUMINANCE_7        ; luminance 7 = %1110
    STA BandColors,X        ; the band's color, ready for the kernel
    LDA Temp
    CLC
    ADC #4                  ; the next band is four hues around the wheel
    INX
    RTS

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
