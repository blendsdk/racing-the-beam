; =============================================================================
; LESSON 16 — EXERCISE 3 SOLUTION: The Zone Table in RAM (Stretch Goal)
; =============================================================================
; Part 2: TV & TIA
;
; Exercise: move the zone table into RAM so the boundaries can be
;           edited live in the debugger.
;
; What changed from the lesson ROM:
;   - the table bytes moved to RAM at $80-$87 (the label ZoneTable
;     points there), and the ROM's copy is now just the initializer,
;     ZoneTableInit;
;   - Reset copies the 8 bytes into RAM once, before the first frame;
;   - the paint loop is UNCHANGED — it still reads (ZoneTable+1),X and
;     ZoneTable,X.  A zero-page indexed load costs the same 4 cycles
;     as the ROM version, so not a single cycle moved.
;
;   Because the kernel re-reads the table every frame, whatever is in
;   RAM at $80-$87 is what gets painted: edit a height or a color in
;   Stella's debugger (the RAM view shows $80-$87; type new values
;   into the cells) and the picture re-draws on the next frame.  Try
;   cutting the sky from $48 (72) to $30 (48) and the ground from $30
;   (48) to $18 (24), and giving the horizon $60 (96): the horizon
;   takes 24 lines from each neighbour, the heights still sum to 192,
;   and the frame stays 262 lines — or change a color, e.g. zone 2's
;   from $46 to $48.  (Keep every height at 2 or more: a height of 1
;   or 0 wraps the countdown and the zone runs away for 250+ lines.)
;
;   zone 0:  24 lines, $02  (dark neutral — the scoreboard strip)
;   zone 1:  72 lines, $84  (blue sky)
;   zone 2:  48 lines, $46  (dark red horizon)
;   zone 3:  48 lines, $C4  (dim green ground)
;
;   The frame is untouched: 259/0/37/229, 262 lines.
;
; Debugger checkpoints: StartFrame (259), VblankStart (0), ZoneColor
;   (A = the color just loaded — from RAM), ZoneHeight (Y = the height
;   just loaded — from RAM), ZoneWrite (one hit per line),
;   VisibleStart (37), OverscanStart (229).  The copy pass is visible
;   too: a breakpoint on CopyTable fires eight times on the boot
;   frame only — one hit per copied byte — and never again.
;
; Build: acme -f plain -o build/lesson16-ex3.bin \
;        lessons/part2-tv-and-tia/16-horizontal-zones/exercise-03-solution.asm
; Run:   stella build/lesson16-ex3.bin
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
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
ZoneTable = $80         ; 8 bytes: four (height, color) pairs — the whole
                        ; picture's zone layout, now live and editable

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

; -----------------------------------------------------------------------------
; Copy the initial zone table into RAM ($80-$87).  From here on the
; picture is driven entirely by RAM — the ROM table is only a seed.
; -----------------------------------------------------------------------------
    LDX #0
CopyTable:
    LDA ZoneTableInit,X
    STA ZoneTable,X         ; RAM $80-$87 — the live table
    INX
    CPX #ZONE_TABLE_LEN
    BNE CopyTable            ; eight stores, once, at boot — then never again

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
; VISIBLE — four zones, painted from the RAM table at $80
; -----------------------------------------------------------------------------
    LDX #0                  ; table cursor: X = this entry's byte offset
ZoneBegin:
    LDA ZoneTable+1,X       ; this zone's color (RAM, $80-$87) — stays in A
ZoneColor:                  ; debugger checkpoint: A = the color just loaded
    STA COLUBK              ; the zone's FIRST line — store lands in HBLANK
    LDY ZoneTable,X         ; this zone's height (RAM) — into Y, so A keeps the color
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
; ZONE TABLE INITIALIZER — copied to RAM ($80-$87) at boot
;
; The live table is the RAM copy.  Nothing else re-reads this block:
; edit RAM, not ROM, to reshape the picture.
; =============================================================================
ZoneTableInit:
    !byte 24, $02           ; zone 0: scoreboard strip (dark neutral)
    !byte 72, $84           ; zone 1: sky (blue)
    !byte 48, $46           ; zone 2: horizon (dark red)
    !byte 48, $C4           ; zone 3: ground (dim green)
ZoneTableInitEnd:
ZONE_TABLE_LEN = ZoneTableInitEnd - ZoneTableInit    ; bytes to copy/walk (8)

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
