; =============================================================================
; LESSON 17 — EXERCISE 2 SOLUTION: The Trimmed Ruler
; =============================================================================
; Part 2: TV & TIA
;
; Exercise: trim section 2 back to exactly 76 cycles per iteration and
;           watch the drift disappear.
;
; What changed from the lesson ROM: section 2's budget filler — 34 NOPs
; (68 cycles) become 31 NOPs (62 cycles), matching section 1.  Every
; iteration is now exactly 76 cycles, so section 2 rides the beam like
; section 1: no drifting writes, no staircase, no stretch.  The ~8-line
; overflow is gone and the frame snaps back to a textbook 262 lines
; (3 + 37 + 192 + 30), even though the junction still chains by cycle
; count: both sections end one cycle late and the spare cycles land in
; HBLANK, where they cost nothing.
;
; The per-iteration ledger (both sections — exactly 76 cycles):
;   LDA ColorRamp,X        4
;   STA COLUBK             3
;   31 x NOP              62
;   INX                    2
;   CPX #RAMP_LENGTH       2
;   BNE
;   ------------------------------------------------
;   total                 76       (75 on each exit iteration)
;
; Debugger checkpoints: StartFrame (259 — the frame is standard again),
;   VblankStart (0), VblankPoll, VisibleStart (37), S1Tick (constant
;   cycle, one hit per line), Section2Start (133), S2Tick (one hit per
;   line at the same constant cycle — the drift is gone), OverscanStart
;   (229), OverscanPoll.
;
; Build: acme -f plain -o build/lesson17-ex2.bin \
;        lessons/part2-tv-and-tia/17-cycle-counting/exercise-02-solution.asm
; Run:   stella build/lesson17-ex2.bin
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
; MAIN LOOP  —  one pass = one frame = 262 scanlines again
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
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
; JUNCTION — no WSYNC: the exit's spare cycle chains into section 2
; -----------------------------------------------------------------------------
Section2Start:              ; debugger checkpoint: the junction (Stella: 133)
    LDX #0                  ; same ramp index; section 2 restarts the hues
S2Loop:
    LDA ColorRamp,X         ; 4 |  4    same read, same page — no penalty
    STA COLUBK              ; 3 |  7    trimmed: back on the beat
S2Tick:                     ; debugger checkpoint: one hit per line, same cycle
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
    CPX #RAMP_LENGTH        ; 2 | 73
    BNE S2Loop              ; 3 | 76   (2 on the exit)

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
; COLOR RAMP — 96 bytes: the 16 hues at luminance 7, each repeated six times
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
