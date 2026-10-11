; =============================================================================
; LESSON 16: Horizontal Zones — Splitting the Screen
; =============================================================================
; Part 2: TV & TIA
;
; What this program does:
;   "Three-zone sky": the visible 192 lines are painted as four stacked
;   horizontal zones, each with its own background color, and the whole
;   picture is driven by a small table in the ROM — one (height, color)
;   pair per zone.  This is the multi-zone architecture every later part
;   fills in: different TIA setups for different strips of the screen.
;
;     - VSYNC: 3 lines, counted with WSYNC (the pulse must be exact).
;     - VBLANK: TIM64T = 44 (exactly 37 lines), then the INTIM poll.
;     - Visible: 192 lines = 24 + 72 + 48 + 48, painted top to bottom
;       from the table: a dark scoreboard strip, the sky, a dark red
;       horizon, and the ground.  A per-zone anchor WSYNC parks each
;       zone's last line, so every boundary sits on an exact line.
;     - Overscan: TIM64T = 36 (exactly 30 lines), polled the same way.
;
;   The picture: four zones, top to bottom —
;     zone 0:  24 lines, $02  (hue 0, level 1 — a dark neutral strip;
;                              later parts put the scoreboard here)
;     zone 1:  72 lines, $84  (hue 8, level 2 — the blue sky)
;     zone 2:  48 lines, $46  (hue 4, level 3 — the dark red horizon)
;     zone 3:  48 lines, $C4  (hue 12, level 2 — the dim green ground)
;
; What you'll learn:
;   - horizontal zones: strips stacked down the screen, each with its
;     own TIA setup — the screen changes as the beam travels, simply
;     because the CPU writes registers between the strips
;   - the zone table: one (height, color) row per zone in the ROM, and
;     a paint loop that walks it — change the table, not the kernel
;   - boundaries by construction: each zone counts its own painted
;     lines and anchors its last line, so zone 0 ends at painted line
;     24, zone 1 at 96, zone 2 at 144, zone 3 at 192
;   - the standard zone vocabulary (scoreboard / playfield / sprite
;     zones) as the shape later parts fill in
;
; The zone-entry ledger (why each zone's first line gets its own color):
;   a TIA color write takes effect for every pixel that has not been
;   drawn yet, so the first line of a zone is safe as long as its color
;   store completes inside HBLANK (68 color clocks ≈ 22.7 CPU cycles).
;   - zone 0 (the release line, Stella 37): the release path plus
;     LDX / LDA put the STA COLUBK store at about cycle 14 — inside.
;   - zones 1-3 (Stella 61 / 133 / 181): the anchor wakes the CPU at
;     the line start, and INX / INX / CPX / BNE / LDA put the store at
;     about cycle 16 — still inside.
;   - every later line repaints at line-cycle 2 (deep in HBLANK):
;     WSYNC parks the line, the store lands right after the beat.
;
; The paint-loop ledger (steady state, one line):
;   STA WSYNC          3    wake at the line start
;   STA COLUBK         3    the repaint — write at line-cycle 2
;   DEY                2
;   BNE ZoneLines      3    taken; 11 cycles of the 76 spent
;   The last line of each zone is parked by the anchor WSYNC instead,
;   and the next zone's entry code (13 cycles) runs in the new line's
;   HBLANK.  No line in the visible picture ever runs over budget.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), VblankPoll (A = the INTIM value
;   just read), VisibleStart (37), ZoneColor (A = the color just
;   loaded for this zone), ZoneHeight (Y = the height just loaded),
;   ZoneWrite (one hit per line — the anchor-hold position of Lessons
;   14-15), OverscanStart (229), OverscanPoll (A = the INTIM value
;   just read).
;
; Build: acme -f plain -o build/lesson16.bin \
;        lessons/part2-tv-and-tia/16-horizontal-zones/16-horizontal-zones.asm
; Run:   stella build/lesson16.bin
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

VblankWait:
    LDA INTIM               ; how much blanking is left?
VblankPoll:                 ; debugger checkpoint: A = the value just read
    BNE VblankWait          ; keep polling until it reads 0
    STA WSYNC               ; line up with the beam (parks the rest of the line)

    LDA #$00
    STA VBLANK              ; release the beam — visible line 1
VisibleStart:               ; debugger checkpoint: the picture's first line (Stella: 37)
; -----------------------------------------------------------------------------
; VISIBLE — four zones, painted from the (height, color) table below
; -----------------------------------------------------------------------------
    LDX #0                  ; table cursor: X = this entry's byte offset
ZoneBegin:
    LDA ZoneTable+1,X       ; this zone's color (stays in A for the repaints)
ZoneColor:                  ; debugger checkpoint: A = the color just loaded
    STA COLUBK              ; the zone's FIRST line — store lands in HBLANK
    LDY ZoneTable,X         ; this zone's height — into Y, so A keeps the color
ZoneHeight:                 ; debugger checkpoint: Y = the height just loaded
    DEY                     ; the first line is painted; H-1 remain
ZoneLines:
    STA WSYNC               ; wait out this line
ZoneWrite:                  ; debugger checkpoint: one hit per line, in HBLANK
    STA COLUBK              ; repaint this line (store at line-cycle 2)
    DEY
    BNE ZoneLines
    STA WSYNC               ; anchor: park out the zone's last line
    INX
    INX                     ; step to the next (height, color) entry
    CPX #ZONE_TABLE_LEN
    BNE ZoneBegin

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
; ZONE TABLE — one (height, color) pair per zone, painted top to bottom
;
; The paint loop walks this table as byte offsets 0, 2, 4, 6: the height
; at the even offset, the color at the next byte.  The heights must sum
; to 192 — the visible lines — and the cumulative sums are the zone
; boundaries (24 / 96 / 144 / 192 painted lines).  The release line
; counts as zone 0's first line, so zone 0's 24 lines are Stella
; scanlines 37-60; the anchors keep every later boundary line-exact.
; Each height must be at least 2 — the countdown loop decrements before
; it tests, so a height of 1 (or 0) wraps and the zone runs away.
; =============================================================================
ZoneTable:
    !byte 24, $02           ; zone 0: scoreboard strip (dark neutral)
    !byte 72, $84           ; zone 1: sky (blue, low luminance)
    !byte 48, $46           ; zone 2: horizon (dark red)
    !byte 48, $C4           ; zone 3: ground (dim green)
ZoneTableEnd:
ZONE_TABLE_LEN = ZoneTableEnd - ZoneTable    ; bytes to walk (8 = 4 zones x 2)

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
