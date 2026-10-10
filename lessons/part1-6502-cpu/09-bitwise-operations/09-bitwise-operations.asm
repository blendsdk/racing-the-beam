; =============================================================================
; LESSON 09: Bitwise Operations — The Power of Bits
; =============================================================================
; Part 1: The 6502 CPU
;
; What this program does:
;   The "bit ladder": EIGHT bands of 24 scanlines each.  Each band shows one
;   bit of the pattern byte at RAM $80: the TOP band shows bit 7, the BOTTOM
;   band shows bit 0.  Exactly one bit of the pattern is set, so exactly one
;   band is bright green ($C8) and the other seven are dark gray ($02).
;
;   The pattern starts at %00000001 — bit 0, the bottom band.  Every 30 frames
;   (~1/2 second) the pattern steps one place: ASL shifts it left, and when
;   the set bit finally leaves through bit 7 it arrives in the CARRY flag;
;   BCS sees that and reloads %00000001, so the bright band climbs from the
;   bottom to the top and then starts again at the bottom.
;
;   To test the bands the kernel needs a MOVING MASK: a byte with one bit set
;   that says which bit belongs to the band being painted.  It starts at
;   %10000000 (band 0, bit 7) and LSRs once per band, so band 1 tests bit 6,
;   band 2 bit 5, ... and band 7 tests bit 0.  AND combines mask and pattern:
;   nonzero means this band's bit is 1 -> bright green.
;
;   The picture is 192 non-blanked scanlines: 8 bands x 24 lines.  Band 0 is
;   painted partly by the beam-release line — its color is pre-loaded, so the
;   release line is band 0's FIRST line — and the other 23 lines come from
;   PaintBand.  The blank-on after the last band waits for HBLANK first
;   (STA WSYNC), so the last band line is painted whole.
;
; What you'll learn:
;   - AND masks a byte (keep some bits) and TESTS bits (AND + BEQ/BNE)
;   - ORA sets bits, EOR toggles bits — the three logic instructions
;   - AND / ORA / EOR set Z and N from the result, so a branch can read them
;   - ASL / LSR shift a byte left/right; the bit that falls off lands in C
;   - ROL / ROR rotate through the carry, so a bit can come back in
;   - The shifted-out bit is data, not garbage: BCS turns it into a decision
;   - Building a byte from two nibbles with AND / LSR / ORA
;   - A mask that shifts once per band: one byte, eight tests
;
; Build: acme -f plain -o build/lesson09.bin \
;        lessons/part1-6502-cpu/09-bitwise-operations/09-bitwise-operations.asm
; Run:   stella build/lesson09.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; COLOR CONSTANTS  (NTSC)
; =============================================================================
GRAY        = $02       ; a band whose bit is 0
GREEN       = $C8       ; the band whose bit is 1 — bright green

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
Pattern     = $80       ; the bit ladder: ONE bit set at all times,
                        ;   %00000001 ... %10000000
Mask        = $81       ; band-select mask: band 0 tests %10000000, band 1
                        ;   tests %01000000, ... band 7 tests %00000001.
                        ;   One LSR per band walks the set bit downwards.
StepTimer   = $82       ; frames left before the pattern takes its next step

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
BANDS       = 8         ; bands on the ladder — one per bit
LINES       = 24        ; scanlines per band (8 x 24 = 192 visible lines)
STEP_FRAMES = 30        ; frames between pattern steps (~1/2 second at 60 Hz)

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, set SP = $FF, CLD (Lesson 04)

    ; --- Starting state: bit 0 set -> the bright band sits at the BOTTOM ---
    LDA #%00000001          ; the pattern is binary: one set bit
    STA Pattern             ; Pattern = %00000001 (bit 0)
    LDA #STEP_FRAMES        ; A = 30
    STA StepTimer           ; 30 frames until the pattern steps

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame
; =============================================================================
StartFrame:
    +vsync                  ; 3-line VSYNC — "a new frame starts now"

    LDA #$02
    STA VBLANK              ; blank the beam while we set up
    +set_timer 43           ; ~37 scanlines of VBLANK

; -----------------------------------------------------------------------------
; BAND 0'S COLOR — tested while the beam is still blanked
; -----------------------------------------------------------------------------
; Band 0 is the TOP band and tests bit 7.  Its color has to be in COLUBK
; before the beam is released: the release line is band 0's first line, and
; nothing else gets a chance to write the color register in time.
;
; The test is the lesson's core pattern in two instructions: AND keeps only
; the bits both bytes share, so "Pattern AND Mask" is zero exactly when this
; band's bit is 0.  BEQ reads that zero — AND sets Z from its result.
    LDA #%10000000          ; A = the mask for band 0 (bit 7) ...
    STA Mask                ; ... which also starts every frame's mask ladder
TopBandTest:                ; debugger checkpoint: break here and A is the mask
    AND Pattern             ; A = bit 7 of the pattern (0 or %10000000)
    BEQ TopBandDark         ; Z = 1 -> bit 7 is 0 -> this band is dark
    LDA #GREEN              ; bit 7 is 1 -> bright green
    BNE TopBandColor        ; GREEN is never 0, so this is a join, not a test
TopBandDark:
    LDA #GRAY               ; band 0's bit is 0 -> dark gray
TopBandColor:
    TAY                     ; park the color in Y: +wait_timer clobbers A

    +wait_timer             ; finish the ~37 scanlines of VBLANK

    LDA #$00
    STA VBLANK              ; un-blank: A = 0 now, and the color comes back
                            ; out of Y right after this
    TYA                     ; A = band 0's color again
    STA COLUBK              ; written in HBLANK, before the beam draws this
                            ; line: the release line already carries it

; -----------------------------------------------------------------------------
; KERNEL — eight 24-line bands; the band whose bit is set is bright green
; -----------------------------------------------------------------------------
; Band 0's release line was line 1, so PaintBand only has to paint 23 more
; lines for band 0 — every band ends up exactly 24 lines tall.
    LDX #LINES-1            ; X = 23: release line + 23 = band 0's 24
    JSR PaintBand           ; paint X lines of the color in A
    LSR Mask                ; band 0 is done — band 1 tests the next bit

    LDY #1                  ; Y = band index: band 1 (bit 6) is next
BandLoop:
    LDA Mask                ; A = the mask for this band (%01000000 first)
BandTest:                   ; debugger checkpoint: break here and A is the mask
    AND Pattern             ; 0 when this band's bit is 0
    BEQ BandDark            ; Z = 1 -> dark gray
    LDA #GREEN              ; Z = 0 -> this band's bit is 1 -> bright green
    BNE BandColor           ; join (GREEN is never 0)
BandDark:
    LDA #GRAY
BandColor:                  ; A = this band's color
    LDX #LINES              ; X = 24: a full band
    JSR PaintBand           ; paint it — A and Y survive, X is used up
    LSR Mask                ; drop the mask's set bit down one place
    INY                     ; next band
    CPY #BANDS              ; have we tested all 8 bits?
    BNE BandLoop            ; no -> another band, another mask

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
; GAME LOGIC — the pattern steps once every STEP_FRAMES frames
; -----------------------------------------------------------------------------
; This countdown is the animation clock.  One pass of the frame loop takes
; exactly one frame, so the pattern moves every 30 frames — about half a
; second at the TV's ~60 frames per second.
    DEC StepTimer           ; one frame closer to the next step
    BNE NoStep              ; not 0 yet (Z = 0) -> the pattern stays put
    LDA #STEP_FRAMES        ; countdown reached 0 -> reload it ...
    STA StepTimer

    ; --- Advance the pattern one bit: left shift, with the carry as news ---
    LDA Pattern             ; A = the pattern: %00000001 ... %10000000
StepShift:                  ; debugger checkpoint: A is the pattern before ASL
    ASL                     ; A = A x 2; bit 7 falls out into the carry
    BCS ReloadPattern       ; C = 1 -> the set bit left the byte: start over
StepStore:                  ; debugger checkpoint: A = the stepped pattern
    STA Pattern             ; C = 0 -> all the set bit did was move one up
    JMP NoStep
ReloadPattern:
    LDA #%00000001          ; bit 7 was set -> the walk restarts at bit 0
ReloadStore:                ; debugger checkpoint: A = %00000001, C = 1
    STA Pattern
NoStep:
    JMP StartFrame          ; next frame

; =============================================================================
; SUBROUTINE: PaintBand  —  paint X scanlines of the color in A
; =============================================================================
; How to call:   A = color byte, X = scanline count, then JSR PaintBand
; What it does:  waits for the next scanline to start, then writes the color
;                to COLUBK once per line for X lines.  Writing the color
;                right after the WSYNC — instead of once before the loop —
;                puts the change in the first few cycles of the line, before
;                the TIA starts drawing on it, so band boundaries fall
;                exactly on a scanline instead of showing a notch where the
;                new color arrives mid-line.
; Registers:     A survives (still the color) and Y is never touched; X is
;                used up — the line counter counts it down to 0.  The band
;                loop keeps its band index in Y for exactly that reason.
; Stack:         JSR pushed the return address; the RTS pops it.  Nothing
;                else is pushed inside, so the band loop can call it safely.
; =============================================================================
PaintBand:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEX                     ; one line fewer to go: 24, 23, ... 1
    BNE -                   ; loop until the line counter reaches 0
    RTS                     ; return; the return address comes off the stack

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
