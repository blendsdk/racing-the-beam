; =============================================================================
; LESSON 15: The Timer — RIOT Counts for You
; =============================================================================
; Part 2: TV & TIA
;
; What this program does:
;   "Time to think": the frame's two blanking periods are counted by the
;   RIOT's interval timer instead of by WSYNC loops, and the cycles that
;   frees up are spent computing the picture while the beam is blanked.
;
;     - VSYNC: 3 lines, counted with WSYNC (the pulse must be exact).
;     - VBLANK: TIM64T = 44 (exactly 37 lines).  During the countdown
;       the CPU advances the hue clock and precomputes the four band
;       colors for this frame; then it polls INTIM until it reads 0.
;     - Visible: 192 lines = four equal 48-line bands, painted from the
;       precomputed colors (per-line writes, anchored by WSYNC).
;     - Overscan: TIM64T = 36 (exactly 30 lines), polled the same way.
;
;   The picture: four bands at hues (n, n+4, n+8, n+12) mod 16, all at
;   luminance 7 (byte low nibble $E).  n starts at 0 and advances by 1
;   every 30 frames (~0.5 s) — the whole picture shifts one hue step at
;   a time, all four bands in step.
;
; What you'll learn:
;   - the 6532's interval timer: TIM1T / TIM8T / TIM64T / T1024T set the
;     count; INTIM reads it; one tick = 1, 8, 64, or 1024 CPU cycles
;   - counting whole TV lines in timer ticks (64 cycles ~ 0.84 lines)
;   - why VBLANK's value is 44 and overscan's is 36 — and why the
;     timer's first tick comes one cycle early (the classic 43/35 in
;     include/macro.asm run a line short)
;   - the freed time: thousands of consecutive cycles for real work,
;     with a single rule — finish before the timer reaches zero
;   - the visible proof: the picture animates correctly only because the
;     compute fits inside the blanking budget
;
; The VBLANK ledger (cycles counted from the start of frame line 0):
;   STA TIM64T writes at cycle 15     (timer = 44)
;   the first decrement lands one cycle after the write — the prescaler
;   restarts full, so a fresh timer ticks almost immediately — and then
;   every 64 cycles
;   compute (hue clock + 4 colors)    ~150 cycles, done before cycle 180
;   first poll reads INTIM = 41       (still counting: the work fits)
;   the last tick (0) lands at cycle 2768   (line 36, cycle 32)
;   poll exits, WSYNC parks the rest of line 36
;   release runs at line 37           -> exactly 37 lines
;   why 44: 1 + 43 x 64 = 2753 cycles after the write — inside line 36,
;   which ends at cycle 2812; 45 ticks would tick 64 cycles later, into
;   line 37 — one line late.
;   (43, the classic value, covers one tick less: the release would land
;   at line 36 — 36 lines.  include/macro.asm's note records the outcome
;   — "43 ticks x 64 = 2752 cycles ~ 36 scanlines" — while its "use for
;   37-line VBLANK" is the classic convention this ledger refines: 44 is
;   what makes the period actually 37 lines.)
;
; The overscan ledger (cycles from the start of frame line 229):
;   STA TIM64T writes at cycle 16     (timer = 36)
;   first decrement one cycle later, then every 64:
;   the last tick (0) lands at cycle 2257   (line 258, cycle 53)
;   poll exits, WSYNC parks the rest of line 258
;   VSYNC starts at line 259          -> exactly 30 lines
;   why 36: 1 + 35 x 64 = 2241 cycles after the write — inside line 258
;   (2264 cycles remain after the write); 37 would overshoot into
;   line 259 — one line late.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), VblankCompute (A = the value
;   just written to TIM64T), HueStep, VblankPoll (A = the INTIM value
;   just read), VisibleStart (37), BandWrite, OverscanStart (229),
;   OverscanPoll (A = the INTIM value just read).
;
; Build: acme -f plain -o build/lesson15.bin \
;        lessons/part2-tv-and-tia/15-the-timer/15-the-timer.asm
; Run:   stella build/lesson15.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame, the timer budgets, and the hue clock
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines (see the ledger)
BAND_LINES     = 48     ; each of the four bands' height
BANDS          = 4      ; bands across the visible 192 lines
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines (see the ledger)
STEP_FRAMES    = 30     ; the hue advances every 30 frames (~0.5 s)
LUMINANCE_7    = $0E    ; luminance nibble: level 7 = %1110 (bit 0 unused)

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
    STA HueBase             ; n = 0: the first picture's hues are 0, 4, 8, 12
    LDA #STEP_FRAMES
    STA StepCounter

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; VSYNC — exactly 3 lines (Lesson 12): the pulse itself still wants WSYNC,
; because it must start and end on exact lines.
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = start VSYNC
    STA VSYNC
    STA WSYNC               ; VSYNC line 1
    STA WSYNC               ; VSYNC line 2
    STA WSYNC               ; VSYNC line 3
    LDA #$00
    STA VSYNC               ; pulse off — exactly 3 lines

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
; -----------------------------------------------------------------------------
; VBLANK — 37 lines, counted by the RIOT timer (TIM64T = 44)
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    LDA #VBLANK_TIMER
    STA TIM64T              ; start the countdown: 44 ticks for 37 lines

VblankCompute:              ; debugger checkpoint: A = the timer value just written
; --- the freed time: advance the hue clock, then precompute the picture ---
    DEC StepCounter
    BNE NoStep
    LDA #STEP_FRAMES
    STA StepCounter
    LDA HueBase
    CLC
    ADC #1
    AND #$0F                ; hues wrap 15 -> 0
HueStep:                    ; debugger checkpoint: fires every 30 frames, A = new n
    STA HueBase
NoStep:
    ; --- precompute the four band colors for this frame ---
    LDA HueBase
    LDX #0
ComputeLoop:
    STA Temp                ; keep the running hue
    AND #$0F                ; mod 16 (n + 4k can pass 15)
    ASL                     ; build the byte: %HHHHLLL0
    ASL
    ASL
    ASL                     ; hue << 4
    ORA #LUMINANCE_7        ; luminance 7 = %1110
    STA BandColors,X        ; the band's color, ready for the kernel
    LDA Temp
    CLC
    ADC #4                  ; the next band is four hues around the wheel
    INX
    CPX #BANDS
    BNE ComputeLoop

    ; --- wait out the rest of the countdown ---
VblankWait:
    LDA INTIM               ; how much blanking is left?
VblankPoll:                 ; debugger checkpoint: A = the value just read
    BNE VblankWait          ; keep polling until it reads 0
    STA WSYNC               ; line up with the beam (parks the rest of the line)

    LDA #$00
    STA VBLANK              ; release the beam — visible line 1
VisibleStart:               ; debugger checkpoint: the picture's first line (Stella: 37)
; -----------------------------------------------------------------------------
; VISIBLE — four equal 48-line bands, painted from the precomputed colors
; -----------------------------------------------------------------------------
    LDX #0                  ; band 0
BandBegin:
    LDA BandColors,X        ; this band's precomputed color
    STA COLUBK              ; its first line, in HBLANK
    LDY #BAND_LINES-1       ; 47 more lines complete the band's 48
BandLines:
    STA WSYNC               ; wait for the next line to start
BandWrite:                  ; debugger checkpoint: one hit per line, in HBLANK
    STA COLUBK              ; repaint (the store lands at line-cycle 2)
    DEY
    BNE BandLines
    STA WSYNC               ; anchor: park out the band's last line
    INX
    CPX #BANDS
    BNE BandBegin

OverscanStart:              ; debugger checkpoint: overscan's first line (Stella: 229)
; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines, counted by the RIOT timer (TIM64T = 36)
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    LDA #OVERSCAN_TIMER
    STA TIM64T              ; start the countdown: 36 ticks for 30 lines

OverscanWait:
    LDA INTIM               ; how much blanking is left?
OverscanPoll:               ; debugger checkpoint: A = the value just read
    BNE OverscanWait        ; keep polling until it reads 0
    STA WSYNC               ; line up with the beam for VSYNC's first line
    JMP StartFrame          ; 262 lines done: next frame

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
