; =============================================================================
; LESSON 17: Cycle Counting — The Heart of Beam Racing
; =============================================================================
; Part 2: TV & TIA
;
; What this program does:
;   "The cycle ruler": two 96-line sections that put the cycle budget on
;   screen.  Section 1 is a hand-counted loop of exactly 76 cycles per
;   iteration — one scanline's worth — with no WSYNC inside: if the count
;   is right, the loop rides the beam line for line.  Section 2 is the
;   same loop with a deliberate +6-cycle overrun per iteration: the CPU
;   falls 6 cycles behind every line, and the picture shows it.
;
;     - VSYNC: 3 lines, counted with WSYNC (the pulse must be exact).
;     - VBLANK: TIM64T = 44 (exactly 37 lines), then the INTIM poll.
;     - Visible: section 1 (96 iterations x 76 cycles = 96 lines) then
;       section 2 (95 x 82 + 81 = 7,871 loop cycles ≈ 103.6 lines).  The
;       junction chains by cycle count — no WSYNC — and the exit's
;       spare cycle lands harmlessly in the next line's HBLANK.
;     - Overscan: TIM64T = 36 (exactly 30 lines), polled the same way.
;
;   The picture: section 1 — 16 horizontal bands, the 16 hues at
;   luminance 7 ($0E, $1E, ... $FE), one hue change every 6 lines,
;   rock-steady because every iteration costs exactly 76 cycles.
;   Section 2 — the same ramp with the overrun: each line's color write
;   lands 6 cycles later than the last, so the hue changes arrive as a
;   drifting staircase (see the capture), and the section itself
;   stretches ~8 lines (7,873 cycles with its prologue ≈ 103.6 lines).
;
; What you'll learn:
;   - the 76-cycle scanline is a budget you spend, not a clock you
;     follow: cycles translate to beam position directly
;   - instruction cycle costs and their categories
;   - counting a loop by hand — including the two traps: the exit
;     branch is 1 cycle cheaper than the loop branch, and an abs,X
;     read costs +1 when it crosses a page
;   - what over-budget work does to a picture: every extra cycle moves
;     the write — and so the boundary — three color clocks later
;
; The per-iteration ledger (section 1 — exactly 76 cycles):
;   LDA ColorRamp,X        4       the line's hue (page-safe abs,X)
;   STA COLUBK             3       paint from HBLANK onward
;   31 x NOP              62       the budget filler (2 cycles each)
;   INX                    2
;   CPX #RAMP_LENGTH       2
;   BNE S1Loop             3       (taken; 2 on the exit iteration)
;   ------------------------------------------------
;   total                 76       (75 on the exit iteration)
;
;   Section 2 is identical with 34 NOPs (68 cycles of filler):
;   4 + 3 + 68 + 2 + 2 + 3 = 82 cycles per iteration.
;
; The section arithmetic (the ledger in full):
;   section 1: 2 (LDX) + 95 x 76 + 75 = 7,297 cycles = 96 lines + 1
;              cycle — the exit branch is 1 cycle cheaper than the loop
;              branch; padding cannot close a 1-cycle gap (no 1-cycle
;              instruction exists), so the ROM leaves it to land in
;              HBLANK, where it costs nothing
;   junction:  section 2's prologue starts immediately; its first write
;              still lands in HBLANK of the next line, so the boundary
;              between the sections is exact (no WSYNC needed)
;   section 2: 2 (LDX) + 95 x 82 + 81 = 7,873 cycles = 103.6 lines —
;              the ~8-line stretch, and the frame grows with it
;              (270 lines instead of 262)
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (267 — the grown frame), VblankStart (0), VblankPoll
;   (A = the INTIM value just read), VisibleStart (37), S1Tick (one hit
;   per line at a constant cycle — section 1 is aligned), Section2Start
;   (133 — the junction), S2Tick (96 hits per frame; consecutive hits
;   82 cycles apart, in-line position +6 per hit — the line advances 1,
;   or 2 where a write is skipped), OverscanStart (236), OverscanPoll
;   (A = the INTIM value just read).
;
; Build: acme -f plain -o build/lesson17.bin \
;        lessons/part2-tv-and-tia/17-cycle-counting/17-cycle-counting.asm
; Run:   stella build/lesson17.bin
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
;   alignment: the release + this prologue put every write in HBLANK;
;   the loop then rides the beam for 96 lines by cycle count alone.
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
; -----------------------------------------------------------------------------
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
