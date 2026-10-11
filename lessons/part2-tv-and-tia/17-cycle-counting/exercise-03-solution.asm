; =============================================================================
; LESSON 17 — EXERCISE 3 SOLUTION: The Full Ledger (Stretch Goal)
; =============================================================================
; Part 2: TV & TIA
;
; Exercise: write the full ledger for the kernel and verify two
;           consecutive lines' cycle gap with state logs.
;
; This is the instrumented ruler: the lesson ROM plus the junction
; checkpoint and the complete budget in one place.  The ledger:
;
;   FRAME SKELETON
;     VSYNC            3 lines (WSYNC-counted)
;     VBLANK          37 lines  (TIM64T = 44; poll -> zero)
;     section 1       96 lines  (loop below)
;     junction        +1 cycle  (the exit's spare cycle — see below)
;     section 2     103.6 lines (loop below)
;     overscan        30 lines  (TIM64T = 36; poll -> zero)
;     ------------------------------------------------
;     frame          270 lines (instead of 262 — the overrun grows it)
;
;   SECTION 1 LOOP — exactly 76 cycles per iteration, 96 iterations
;     LDA ColorRamp,X        4
;     STA COLUBK             3
;     31 x NOP              62
;     INX / CPX / BNE     2+2+3 = 7   (BNE is 2 on the exit iteration)
;     ------------------------------------------------
;     iteration             76
;     loop total            95 x 76 + 75 = 7,295
;     + prologue LDX        2
;     section 1 total       7,297 = 96 x 76 + 1 = 96 lines + 1 cycle
;     (the +1: the exit branch is one cycle cheaper than the loop
;     branch; padding cannot close a 1-cycle gap (no 1-cycle
;     instruction exists) — the cycle feeds the junction, where
;     section 2's first write still lands in HBLANK)
;
;   SECTION 2 LOOP — the same loop with a deliberate +6-cycle overrun
;     LDA / STA            7
;     34 x NOP              68   (6 more than section 1)
;     INX / CPX / BNE       7   (BNE is 2 on the exit iteration)
;     ------------------------------------------------
;     iteration             82
;     loop total            95 x 82 + 81 = 7,871
;     + prologue LDX        2
;     section 2 total       7,873 = 103.6 lines (the ~8-line stretch)
;
;   THE TWO-LINE GAP CHECK (the exercise's verification)
;     Breakpoint S1Tick: sequential hits are 76 cycles apart at a
;     constant in-line position — section 1 is aligned, line for line.
;     Breakpoint S2Tick: sequential hits are 82 cycles apart, and the
;     in-line position moves +6 per hit (the line advances 1, or 2
;     where a write is skipped) — the overrun, visible as data.
;
;   Section1End and Section2Start land on the same address: the
;   junction is exactly one point — where section 1's last iteration
;   ends and section 2's prologue begins, chained by cycles, no WSYNC.
;
; Build: acme -f plain -l build/lesson17-ex3.sym -o build/lesson17-ex3.bin \
;        lessons/part2-tv-and-tia/17-cycle-counting/exercise-03-solution.asm
; Run:   stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F037' build/lesson17-ex3.bin
;        stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F062' build/lesson17-ex3.bin
;        (S1Tick / S2Tick as assembled here; a symbol list prints them again)
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame and its two timer windows
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines (Lesson 15)
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines (Lesson 15)

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
; MAIN LOOP  —  one pass = one frame (this frame runs long: 270 lines)
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 267)
; -----------------------------------------------------------------------------
; VSYNC — exactly 3 lines (Lesson 12)
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

VblankWait:
    LDA INTIM               ; how much blanking is left?
VblankPoll:                 ; debugger checkpoint: A = the value just read
    BNE VblankWait          ; keep polling until it reads 0
    STA WSYNC               ; line up with the beam (parks the rest of the line)

    LDA #$00
    STA VBLANK              ; release the beam — visible line 1
VisibleStart:               ; debugger checkpoint: the picture's first line (Stella: 37)
; -----------------------------------------------------------------------------
; SECTION 1 — the exactly-76-cycle loop, no WSYNC inside
; -----------------------------------------------------------------------------
    LDX #0                  ; ramp index = line counter (0..95)
S1Loop:
    LDA ColorRamp,X         ; 4 |  4    this line's hue (page-safe abs,X)
    STA COLUBK              ; 3 |  7    paint from HBLANK onward
S1Tick:                     ; debugger checkpoint: one hit per line, constant cycle
    ; --- budget filler: 62 cycles (31 x NOP, 2 cycles each) ---
    NOP                     ; 2 |  9
    NOP                     ; 2 | 11
    NOP                     ; 2 | 13
    NOP                     ; 2 | 15
    NOP                     ; 2 | 17
    NOP                     ; 2 | 19
    NOP                     ; 2 | 21
    NOP                     ; 2 | 23
    NOP                     ; 2 | 25
    NOP                     ; 2 | 27
    NOP                     ; 2 | 29
    NOP                     ; 2 | 31
    NOP                     ; 2 | 33
    NOP                     ; 2 | 35
    NOP                     ; 2 | 37
    NOP                     ; 2 | 39
    NOP                     ; 2 | 41
    NOP                     ; 2 | 43
    NOP                     ; 2 | 45
    NOP                     ; 2 | 47
    NOP                     ; 2 | 49
    NOP                     ; 2 | 51
    NOP                     ; 2 | 53
    NOP                     ; 2 | 55
    NOP                     ; 2 | 57
    NOP                     ; 2 | 59
    NOP                     ; 2 | 61
    NOP                     ; 2 | 63
    NOP                     ; 2 | 65
    NOP                     ; 2 | 67
    NOP                     ; 2 | 69
    INX                     ; 2 | 71
    CPX #RAMP_LENGTH        ; 2 | 73   96 lines — one ramp entry per line
    BNE S1Loop              ; 3 | 76   (2 on the exit — the loop's last branch)

; -----------------------------------------------------------------------------
; JUNCTION — no WSYNC: the exit's spare cycle chains into section 2's
; prologue, whose first write still lands in HBLANK of the next line.
; Section1End and Section2Start share this address — the junction is
; exactly one point.
; -----------------------------------------------------------------------------
Section1End:                ; the end of section 1's loop (same address as below)
Section2Start:              ; debugger checkpoint: the junction (Stella: 133)
    LDX #0                  ; same ramp index; section 2 restarts the hues
S2Loop:
    LDA ColorRamp,X         ; 4 |  4    same read, same page — no penalty
    STA COLUBK              ; 3 |  7    now 6 cycles later and drifting
S2Tick:                     ; debugger checkpoint: +6-cycle drift, one hit per iteration
    ; --- budget filler: 68 cycles (34 x NOP — 6 more than section 1) ---
    NOP                     ; 2 |  9
    NOP                     ; 2 | 11
    NOP                     ; 2 | 13
    NOP                     ; 2 | 15
    NOP                     ; 2 | 17
    NOP                     ; 2 | 19
    NOP                     ; 2 | 21
    NOP                     ; 2 | 23
    NOP                     ; 2 | 25
    NOP                     ; 2 | 27
    NOP                     ; 2 | 29
    NOP                     ; 2 | 31
    NOP                     ; 2 | 33
    NOP                     ; 2 | 35
    NOP                     ; 2 | 37
    NOP                     ; 2 | 39
    NOP                     ; 2 | 41
    NOP                     ; 2 | 43
    NOP                     ; 2 | 45
    NOP                     ; 2 | 47
    NOP                     ; 2 | 49
    NOP                     ; 2 | 51
    NOP                     ; 2 | 53
    NOP                     ; 2 | 55
    NOP                     ; 2 | 57
    NOP                     ; 2 | 59
    NOP                     ; 2 | 61
    NOP                     ; 2 | 63
    NOP                     ; 2 | 65
    NOP                     ; 2 | 67
    NOP                     ; 2 | 69
    NOP                     ; 2 | 71
    NOP                     ; 2 | 73
    NOP                     ; 2 | 75
    INX                     ; 2 | 77
    CPX #RAMP_LENGTH        ; 2 | 79
    BNE S2Loop              ; 3 | 82   (2 on the exit)

OverscanStart:              ; debugger checkpoint: overscan's first line (Stella: 236)
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
    JMP StartFrame          ; the frame is done: next one

; =============================================================================
; COLOR RAMP — 96 bytes: the 16 hues at luminance 7, each repeated six times
;
; The table is page-aligned so that ColorRamp+X never crosses a page:
; an abs,X read that crosses a page boundary costs +1 cycle, which would
; silently break the 76-cycle ledger.
; =============================================================================
    !align 255, 0           ; the ramp stays inside one page (X reaches 95)
ColorRamp:
    !byte $0E,$0E,$0E,$0E,$0E,$0E    ; hue 0  — six lines
    !byte $1E,$1E,$1E,$1E,$1E,$1E    ; hue 1
    !byte $2E,$2E,$2E,$2E,$2E,$2E    ; hue 2
    !byte $3E,$3E,$3E,$3E,$3E,$3E    ; hue 3
    !byte $4E,$4E,$4E,$4E,$4E,$4E    ; hue 4
    !byte $5E,$5E,$5E,$5E,$5E,$5E    ; hue 5
    !byte $6E,$6E,$6E,$6E,$6E,$6E    ; hue 6
    !byte $7E,$7E,$7E,$7E,$7E,$7E    ; hue 7
    !byte $8E,$8E,$8E,$8E,$8E,$8E    ; hue 8
    !byte $9E,$9E,$9E,$9E,$9E,$9E    ; hue 9
    !byte $AE,$AE,$AE,$AE,$AE,$AE    ; hue 10
    !byte $BE,$BE,$BE,$BE,$BE,$BE    ; hue 11
    !byte $CE,$CE,$CE,$CE,$CE,$CE    ; hue 12
    !byte $DE,$DE,$DE,$DE,$DE,$DE    ; hue 13
    !byte $EE,$EE,$EE,$EE,$EE,$EE    ; hue 14
    !byte $FE,$FE,$FE,$FE,$FE,$FE    ; hue 15
RAMP_LENGTH = * - ColorRamp   ; 96 — one entry per visible line per section

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
