; =============================================================================
; LESSON 16 — EXERCISE 1 SOLUTION: Five Zones (Split the Sky)
; =============================================================================
; Part 2: TV & TIA
;
; Exercise: split the sky zone into a fifth zone via the table —
;           five zones, total 192 lines (here: 24 / 48 / 24 / 48 / 48).
;
; What changed from the lesson ROM: the TABLE — and nothing else.
;   The sky's 72 lines become two bands: 48 lines of $84 (blue at
;   level 2) with 24 lines of $86 (the same blue one level brighter)
;   below it, where the sky meets the horizon.  A fifth (height,
;   color) row was inserted, the end label moved with it, and
;   ZONE_TABLE_LEN grew from 8 to 10 — the paint loop's CPX bound
;   follows the table automatically, so not one instruction of the
;   kernel changed.
;
;   zone 0:  24 lines, $02  (dark neutral — the scoreboard strip)
;   zone 1:  48 lines, $84  (upper sky)
;   zone 2:  24 lines, $86  (lower sky, brighter toward the horizon)
;   zone 3:  48 lines, $46  (dark red horizon)
;   zone 4:  48 lines, $C4  (dim green ground)
;
;   Cumulative boundaries: 24 / 72 / 96 / 144 / 192 painted lines
;   (the release line is inside zone 0).  The frame is untouched:
;   259/0/37/229, 262 lines.
;
; Debugger checkpoints: StartFrame (259), VblankStart (0), ZoneColor
;   (A = the color just loaded — now five hits per frame), ZoneHeight
;   (Y = the height just loaded), ZoneWrite (one hit per line),
;   VisibleStart (37), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson16-ex1.bin \
;        lessons/part2-tv-and-tia/16-horizontal-zones/exercise-01-solution.asm
; Run:   stella build/lesson16-ex1.bin
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
; VISIBLE — five zones, painted from the (height, color) table below
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
; ZONE TABLE — five (height, color) pairs; heights sum to 192
;
; The sky (72 lines in the lesson) is split into 48 + 24: the paint
; loop walks whatever this table holds, so the fifth zone costs one
; row — and ZONE_TABLE_LEN's CPX bound follows the end label.
; =============================================================================
ZoneTable:
    !byte 24, $02           ; zone 0: scoreboard strip (dark neutral)
    !byte 48, $84           ; zone 1: upper sky (blue)
    !byte 24, $86           ; zone 2: lower sky (blue, one level brighter)
    !byte 48, $46           ; zone 3: horizon (dark red)
    !byte 48, $C4           ; zone 4: ground (dim green)
ZoneTableEnd:
ZONE_TABLE_LEN = ZoneTableEnd - ZoneTable    ; bytes to walk (10 = 5 zones x 2)

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
