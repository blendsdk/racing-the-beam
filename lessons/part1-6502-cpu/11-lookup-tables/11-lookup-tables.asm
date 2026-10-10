; =============================================================================
; LESSON 11: Lookup Tables — Data-Driven Programming
; =============================================================================
; Part 1: The 6502 CPU
;
; What this program does:
;   The "color wave": SIXTEEN equal bands of 12 scanlines each — 192
;   non-blanked lines.  Every band's color is read out of ONE 16-byte table
;   in ROM, as a cyclic rotation of that table:
;
;     band k  ->  Wave[(offset + k) AND $0F]      k = 0 (top) ... 15 (bottom)
;
;   `offset` is a single byte in RAM ($80).  Every 16 frames — about a
;   quarter second at 60 Hz — it advances by one, and every color in the
;   picture moves one band UP the screen: the entry that leaves the top band
;   reappears at the bottom.  When the offset passes 15, the AND $0F wraps it
;   back to 0, so the picture never blanks, never repeats a band, and can
;   never show anything the table does not contain.
;
;   The table is the ramp $1A + $0E x k, k = 0...15:
;
;     $1A $28 $36 $44 $52 $60 $6E $7C $8A $98 $A6 $B4 $C2 $D0 $DE $EC
;
;   Hue and luminance both step as you read down it, so the wave is a slow
;   rainbow sweep — with two dark notches: the entries $60 and $D0 land on
;   luminance 0, the palette's darkest step, and read as very dark purple and
;   very dark green.  Those two bands make the scroll easy to follow.
;
;   Nothing here computes a color and nothing branches on one: the picture is
;   ONE instruction — LDA Wave,X — applied to a moving index, and the index
;   mask (AND $0F) is what keeps that index inside the table's 16 bytes.
;
; What you'll learn:
;   - Storing data in ROM with !byte, and reading it back with LDA table,X
;   - Base + index: one instruction, any entry — no branch tree, no math
;   - Bounds discipline: AND #$0F keeps the index in 0...15 (Lesson 09's mask)
;   - Tables over time: the offset in RAM turns a fixed table into an animation
;   - The scroll math (offset + k) AND $0F and the seamless wrap it gives
;   - What a table buys: 16 bytes of ROM against color arithmetic or a
;     branch tree — and 4 cycles for the read
;
; Frame geometry: 192 non-blanked scanlines — 16 EQUAL bands of 12 lines.
;   Band 0's color is fetched during VBLANK, so the beam-release line is band
;   0's FIRST line and PaintLines paints the other 11; every other band is one
;   PaintLines call of 12 lines.  The blank-on after the last band waits for
;   HBLANK first (STA WSYNC), so the last band line is painted whole.
;   Same skeleton as Lesson 09.
;
; Build: acme -f plain -o build/lesson11.bin \
;        lessons/part1-6502-cpu/11-lookup-tables/11-lookup-tables.asm
; Run:   stella build/lesson11.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
Offset      = $80       ; the wave position: 0...15.  It is the table index
                        ;   of the TOP band; every band below it is the next
                        ;   table entry, so band k = Wave[(offset + k) AND $0F]
WaveTimer   = $81       ; frames left before the wave takes its next step
BandsLeft   = $82       ; bands still to paint this frame: 15 after band 0

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
BANDS       = 16        ; bands on the screen — one per table entry
LINES       = 12        ; scanlines per band (16 x 12 = 192 non-blanked lines)
STEP_FRAMES = 16        ; frames between wave steps (~1/4 second at 60 Hz)
INDEX_MASK  = $0F       ; keeps (offset + k) inside the 16-byte table: the
                        ;   table has 16 entries, numbered 0...15, and any
                        ;   index AND $0F lands on one of them

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

    ; --- The wave starts at offset 0: the table in the order it is written ---
    LDA #$00
    STA Offset              ; TOP band = Wave[0] = $1A, next band = Wave[1] ...
    LDA #STEP_FRAMES
    STA WaveTimer           ; the first step comes after one full cadence

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame
; =============================================================================
StartFrame:
    +vsync                  ; 3-line VSYNC — "a new frame starts now"

    LDA #$02
    STA VBLANK              ; blank the beam while we set up
    +set_timer 43           ; ~37 scanlines of VBLANK

; -----------------------------------------------------------------------------
; BAND 0 — fetched while the beam is still blanked
; -----------------------------------------------------------------------------
; Band 0 is the TOP band, and its color has to be in COLUBK before the release
; line's visible portion starts — the release line is band 0's first line, so
; the store lands in HBLANK right after VBLANK is cleared.
;
; Band 0's index is (offset + 0) AND $0F.  Offset is already kept in 0...15 by
; the code that writes it, so the mask here is a no-op — it is written anyway
; because every index in this program goes through the same mask, and one
; extra instruction during VBLANK is cheaper than one index that escapes.
    LDX Offset              ; X = the wave position, 0...15
    TXA                     ; A = the offset, so the mask below can act on it
OffsetLoaded:               ; debugger checkpoint: break here, A = X = offset
    AND #INDEX_MASK         ; (offset + 0) AND $0F — an index the table has
    TAX
    LDA Wave,X              ; band 0's color: the table does the looking up
WaveFetch0:                 ; debugger checkpoint: break here, A = color, X = index
    TAY                     ; park the color: +wait_timer clobbers A

    +wait_timer             ; finish the ~37 scanlines of VBLANK

    LDA #$00
    STA VBLANK              ; release the beam: this line is band 0's FIRST line
    TYA                     ; A = band 0's color again
    STA COLUBK              ; written in HBLANK, so the release line shows it
    LDY #LINES-1            ; Y = 11: release line + 11 painted = band 0's 12
    JSR PaintLines          ; paint them — A survives, X is never touched

; -----------------------------------------------------------------------------
; BANDS 1-15 — one table read per band, with a moving index
; -----------------------------------------------------------------------------
; Each band is two ideas: step the index once and fold it back into the table
; with the mask, then let the table supply the color.  There is no color
; arithmetic and no branch tree anywhere in this kernel — the table IS the
; picture, and the offset decides where in it the screen starts.
    LDA #BANDS-1            ; 15 bands left after band 0
    STA BandsLeft
BandLoop:
    INX                     ; X = offset + k for the band about to be painted
    TXA                     ; A = offset + k, which can be 16...30
    AND #INDEX_MASK         ; 16...30 comes back as 0...14 — that is the wrap ...
    TAX                     ;   ... and X is never allowed past 15
    LDA Wave,X              ; band k's color, straight out of the table
WaveFetch:                  ; debugger checkpoint: break here, A = color, X = index
    LDY #LINES              ; Y = 12: a full band
    JSR PaintLines          ; paint it — A and X survive, Y is used up
    DEC BandsLeft           ; one band fewer to go
    BNE BandLoop

; -----------------------------------------------------------------------------
; OVERSCAN
; -----------------------------------------------------------------------------
    STA WSYNC               ; wait for HBLANK before blanking: the last band
                            ; line is being drawn right now, so writing VBLANK
                            ; here would clip it partway across.  WSYNC lets the
                            ; line finish; the blank-on starts on the next line
    LDA #$02
    STA VBLANK
    +set_timer 35           ; ~30 scanlines of overscan
    +wait_timer

; -----------------------------------------------------------------------------
; THE ANIMATION CLOCK — the wave steps once every STEP_FRAMES frames
; -----------------------------------------------------------------------------
; This countdown is what turns a fixed table into a moving picture.  It runs
; once per frame because the frame loop runs once per frame: 16 frames is
; about a quarter second, so the whole picture walks up one band per step and
; the table's 16 entries take a little over four seconds to come full circle.
    DEC WaveTimer           ; one frame closer to the next step
    BNE NoStep              ; not 0 yet -> the offset stays put
    LDA #STEP_FRAMES        ; countdown reached 0 -> reload it ...
    STA WaveTimer
    INC Offset              ; ... and move the wave one entry up the screen
    LDA Offset              ; A = offset + 1
    AND #INDEX_MASK         ; wrap 16 back to 0 — the same mask as the kernel
    STA Offset              ; Offset is 0...15 again
NoStep:
    JMP StartFrame          ; next frame

; =============================================================================
; SUBROUTINE: PaintLines — paint Y scanlines of the color in A
; =============================================================================
; How to call:   A = color byte, Y = scanline count, then JSR PaintLines
; What it does:  waits for the next scanline to start, then writes the color
;                to COLUBK once per line for Y lines.  Writing the color
;                right after the WSYNC — instead of once before the loop —
;                puts the change in the first few cycles of the line, before
;                the TIA starts drawing on it, so band boundaries fall
;                exactly on a scanline instead of showing a notch where the
;                new color arrives mid-line.
; Registers:     A survives (still the color) and X is never touched — the
;                wave index lives in X, so the kernel depends on that — and
;                Y is used up: the line counter counts it down to 0.
; Stack:         JSR pushed the return address; the RTS pops it.  Nothing
;                else is pushed inside, so callers can use the stack freely.
; =============================================================================
PaintLines:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEY                     ; one line fewer to go: 12, 11, ... 1
    BNE -                   ; loop until the line counter reaches 0
    RTS                     ; return; the return address comes off the stack

; =============================================================================
; DATA — the 16 wave colors, read as Wave,X
; =============================================================================
; Entry k is $1A + $0E x k: the hue nibble climbs while the luminance nibble
; steps down, so reading the table in order sweeps the color wheel with a
; light-to-dark ramp inside it.  Two entries — $60 and $D0 — land on
; luminance 0, the darkest step the palette has: they read as very dark purple
; and very dark green, and they mark the scroll clearly.
Wave:
    !byte $1A, $28, $36, $44    ; k = 0...3
    !byte $52, $60, $6E, $7C    ; k = 4...7
    !byte $8A, $98, $A6, $B4    ; k = 8...11
    !byte $C2, $D0, $DE, $EC    ; k = 12...15

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
