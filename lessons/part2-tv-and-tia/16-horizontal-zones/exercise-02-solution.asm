; =============================================================================
; LESSON 16 — EXERCISE 2 SOLUTION: Rebalanced Zones
; =============================================================================
; Part 2: TV & TIA
;
; Exercise: rebalance the zones (e.g. 48 / 96 / 24 / 24) keeping the
;           total — the picture's shape changes, the kernel does not.
;
; What changed from the lesson ROM: four numbers in the TABLE.
;   The dark strip grows to 48 lines, the sky to 96, and the horizon
;   and ground shrink to 24 each — same four colors, same paint loop,
;   same frame.  The new cumulative boundaries are 48 / 144 / 168 /
;   192 painted lines; zone 0 now ends at Stella scanline 84.
;
;   zone 0:  48 lines, $02  (dark neutral — the scoreboard strip)
;   zone 1:  96 lines, $84  (sky)
;   zone 2:  24 lines, $46  (dark red horizon)
;   zone 3:  24 lines, $C4  (dim green ground)
;
;   The frame is untouched: 259/0/37/229, 262 lines.
;
; Debugger checkpoints: StartFrame (259), VblankStart (0), ZoneColor
;   (A = the color just loaded), ZoneHeight (Y = the height just
;   loaded — 48 / 96 / 24 / 24), ZoneWrite (one hit per line),
;   VisibleStart (37), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson16-ex2.bin \
;        lessons/part2-tv-and-tia/16-horizontal-zones/exercise-02-solution.asm
; Run:   stella build/lesson16-ex2.bin
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
; ZONE TABLE — four (height, color) pairs; heights sum to 192
;
; Only these numbers changed: 24/72/48/48 became 48/96/24/24.  The
; paint loop reads any table it is given; rebalancing a picture is
; editing data, not code.
; =============================================================================
ZoneTable:
    !byte 48, $02           ; zone 0: scoreboard strip (dark neutral)
    !byte 96, $84           ; zone 1: sky (blue)
    !byte 24, $46           ; zone 2: horizon (dark red)
    !byte 24, $C4           ; zone 3: ground (dim green)
ZoneTableEnd:
ZONE_TABLE_LEN = ZoneTableEnd - ZoneTable    ; bytes to walk (8 = 4 zones x 2)

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
