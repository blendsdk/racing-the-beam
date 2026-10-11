; =============================================================================
; LESSON 18: Mid-Scanline Changes — Racing the Beam
; =============================================================================
; Part 2: TV & TIA
;
; What this program does:
;   "Color columns": every one of the 192 visible lines paints four vertical
;   color columns — $42 (red), $84 (blue), $C8 (green), $1A (gold) — by
;   writing COLUBK four times per line at hand-placed cycles.  The beam
;   crosses one line in 228 color clocks (76 CPU cycles): a store whose next
;   instruction runs at cycle N paints from color clock 3N onward.  The
;   ledger below places the three boundaries at the visible quarter points.
;
;   Every ~2 seconds the three boundary writes shift +4 cycles each, so the
;   widths animate: the first column grows, the last shrinks, the middle two
;   hold.  Nothing else on screen moves.
;
;     - VSYNC: 3 lines, counted with WSYNC.
;     - VBLANK: TIM64T = 44 (exactly 37 lines), the INTIM poll, and the
;       animation tick (a 120-frame counter flips the state).
;     - Visible: one exact 76-cycle line, repeated 192 times.  Each line is
;       an anchor WSYNC plus four writes; no drifting, no waiting between
;       the writes — the count is the geometry.
;     - Overscan: TIM64T = 36 (exactly 30 lines).
;
; The per-line ledger (default state — exactly 76 cycles):
;   DEX                      2    0-1   line counter (192 lines)
;   BNE VarDefaultBody       3    2-4   taken
;   LDA #COL1                2    5-6
;   BIT FrameCounter         3    7-9   the 3-cycle odd-gap tuner
;   STA COLUBK               3   10-12  base color: hit 13 -> clock 39 (HBLANK)
;   NOP x 9                 18   13-30
;   LDA #COL2                2   31-32
;   STA COLUBK               3   33-35  boundary 1: hit 36 -> clock 108
;   NOP x 4                  8   36-43
;   LDA #COL3                2   44-45
;   STA COLUBK               3   46-48  boundary 2: hit 49 -> clock 147
;   NOP x 3 + BIT            9   49-57  (6 + 3: the odd tuner again)
;   LDA #COL4                2   58-59
;   STA COLUBK               3   60-62  boundary 3: hit 63 -> clock 189
;   STA WSYNC                3   63-65  the anchor: write 65, park 66-75
;   ----------------------------------------------------------------
;   total                   76
;
;   The shifted state is the same ring with NOP x 11 in the first gap
;   instead of NOP x 9: every write after the base lands 4 cycles later —
;   hits 40 / 53 / 67, boundaries at clocks 120 / 159 / 201 — and the
;   anchor is written at cycle 69.  The line is still exactly 76 cycles.
;
;   Why "hit cycles"?  A store takes effect from the color clock three times
;   the cycle number of the NEXT instruction — the number the debugger
;   prints and the ledger counts.  Lesson 17 verified this rule against
;   twelve measured boundaries; the same math places these columns:
;   boundary x (in the capture) = 25 + (3 x hit - 68) x 6.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259 — a standard 262-line frame), VblankStart (0),
;   VblankPoll (A = the INTIM value just read; zero at line 36),
;   VisibleStart (the release; logged (36, 46) at the anchor's first parked
;   cycle, executing from (37, 0) — its phase equals the loop's steady
;   state, so line 37 carries the columns too), the per-write ticks
;   DefaultBase/DefaultB1/DefaultB2/DefaultB3 at cycles 13/36/49/63 (192
;   hits per frame each while the default state is showing) and
;   ShiftBase/ShiftB1/ShiftB2/ShiftB3 at 13/40/53/67 (the shifted state;
;   A = the color just written), OverscanStart (229), OverscanPoll (A =
;   the INTIM value just read).
;
; Build: acme -f plain -o build/lesson18.bin \
;        lessons/part2-tv-and-tia/18-mid-scanline-changes/18-mid-scanline-changes.asm
; Run:   stella build/lesson18.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame, the columns, the animation
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines (Lesson 15)
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines (Lesson 15)

COL1           = $42    ; the lesson-12 palette, left to right
COL2           = $84
COL3           = $C8
COL4           = $1A

VISIBLE_LINES  = 192    ; the standard NTSC picture height
ANIM_FRAMES    = 120    ; ~2 seconds per animation state at ~60 Hz

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
FrameCounter   = $80    ; counts up to ANIM_FRAMES, then resets
AnimState      = $81    ; 0 = default widths, 1 = shifted widths

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
; MAIN LOOP  —  one pass = one frame = 262 scanlines
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

; --- the animation tick: flip the state every ANIM_FRAMES frames ---
    INC FrameCounter        ; 5 cycles — one frame's worth of time
    LDA FrameCounter
    CMP #ANIM_FRAMES        ; 120 frames elapsed?
    BNE VblankTickDone
    LDA #$00
    STA FrameCounter        ; wrap the counter
    LDA AnimState
    EOR #$01
    STA AnimState           ; 0 <-> 1: the widths will shift this frame
VblankTickDone:

VblankWait:
    LDA INTIM               ; how much blanking is left?
VblankPoll:                 ; debugger checkpoint: A = the value just read
    BNE VblankWait          ; keep polling until it reads 0 (line 36)

; -----------------------------------------------------------------------------
; STATE SELECT — pick the kernel for this frame's 192 lines
; -----------------------------------------------------------------------------
    LDA AnimState
    BNE VbShifted           ; 1 = the shifted widths

; -----------------------------------------------------------------------------
; VISIBLE — DEFAULT STATE: boundaries at clocks 108 / 147 / 189
; -----------------------------------------------------------------------------
    LDX #VISIBLE_LINES      ; 192 lines to paint
    STA WSYNC               ; park the rest of line 36
VisibleStart:               ; debugger checkpoint: the picture's first line (Stella: 37, 0)
    LDA #$00
    STA VBLANK              ; release the beam (cycles 0-4)
VarDefaultBody:             ; the release + these 5 cycles = the steady-state top, so
                            ; line 37 lands on the same cycle grid as every other line
    LDA #COL1               ; 5-6    base color
    BIT FrameCounter        ; 7-9    the 3-cycle odd-gap tuner (reads, changes nothing)
    STA COLUBK              ; 10-12
DefaultBase:                ; checkpoint: hit cycle 13  -> paints from clock 39
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2      (18 cycles to the next write)
    LDA #COL2               ; 31-32
    STA COLUBK              ; 33-35
DefaultB1:                  ; checkpoint: hit cycle 36  -> boundary 1 at clock 108
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2      (8 cycles)
    LDA #COL3               ; 44-45
    STA COLUBK              ; 46-48
DefaultB2:                  ; checkpoint: hit cycle 49  -> boundary 2 at clock 147
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2      (6 cycles)
    BIT FrameCounter        ; 3      (the odd tuner: 6 + 3 = 9)
    LDA #COL4               ; 58-59
    STA COLUBK              ; 60-62
DefaultB3:                  ; checkpoint: hit cycle 63  -> boundary 3 at clock 189
    STA WSYNC               ; 63-65  anchor: write 65, park 66-75
VarDefaultNext:
    DEX                     ; 2      next line
    BNE VarDefaultBody      ; 3 taken
    JMP OverscanStart       ; 192 lines done

; -----------------------------------------------------------------------------
; VISIBLE — SHIFTED STATE: boundaries at clocks 120 / 159 / 201
; -----------------------------------------------------------------------------
VbShifted:
    LDX #VISIBLE_LINES      ; 192 lines to paint
    STA WSYNC               ; park the rest of line 36
    LDA #$00
    STA VBLANK              ; release the beam — same 5-cycle phase
VarShiftBody:
    LDA #COL1               ; 5-6    base color (unchanged)
    BIT FrameCounter        ; 7-9
    STA COLUBK              ; 10-12
ShiftBase:                  ; checkpoint: hit cycle 13  -> paints from clock 39
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2      (22 cycles now — two more than the default: the shift)
    LDA #COL2               ; 35-36
    STA COLUBK              ; 37-39
ShiftB1:                    ; checkpoint: hit cycle 40  -> boundary 1 at clock 120
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2      (8 cycles)
    LDA #COL3               ; 48-49
    STA COLUBK              ; 50-52
ShiftB2:                    ; checkpoint: hit cycle 53  -> boundary 2 at clock 159
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2      (6 cycles)
    BIT FrameCounter        ; 3
    LDA #COL4               ; 62-63
    STA COLUBK              ; 64-66
ShiftB3:                    ; checkpoint: hit cycle 67  -> boundary 3 at clock 201
    STA WSYNC               ; 67-69  anchor: write 69, park 70-75
VarShiftNext:
    DEX                     ; 2
    BNE VarShiftBody        ; 3 taken
                            ; fall through when the 192 lines are done

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
    JMP StartFrame          ; the frame is done: next one

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
