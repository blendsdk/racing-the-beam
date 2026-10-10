; =============================================================================
; LESSON 08: The Stack and Subroutines — Functions in Assembly
; =============================================================================
; Part 1: The 6502 CPU
;
; What this program does:
;   The "subroutine bands": FOUR bands, red ($42), green ($C8), blue ($96) and
;   gold ($1A), top to bottom.  Each band is one 48-line PaintBand call — the
;   beam-release line already carries the top band's color, so the top band is
;   one scanline taller; the picture is 193 non-blanked scanlines.  Every band
;   is painted by the SAME subroutine — PaintBand — called four times per
;   frame by DrawScreen.  The picture is steady on purpose: the interesting
;   activity happens on the stack, where you can watch it in the debugger.
;
;   DrawScreen keeps its own loop counter in X, and PaintBand needs X for its
;   line count, so every call is wrapped in a push/pull round trip:
;
;       TXA / PHA        save the band counter on the stack
;       JSR PaintBand    call the shared painter (it uses up X)
;       PLA / TAX        pull the band counter back
;
;   The frame top is the one moment per frame when the stack is empty again:
;   SP = $FF.  If that were not true, every frame would start one byte deeper
;   and the stack would slowly eat its way down through RAM.
;
; What you'll learn:
;   - The stack: 128 bytes of page $01, growing DOWN from $01FF
;   - PHA / PLA push and pull one byte; PHP / PLP do the same for the flags
;   - JSR pushes the return address MINUS 1; RTS adds 1 back
;   - Every JSR costs 2 stack bytes, so a call chain is 2 bytes per level
;   - TXA / PHA ... PLA / TAX: save a register a callee would clobber
;   - Nested calls: frame loop -> DrawScreen -> PaintBand
;   - Page $01 mirrors RAM $80-$FF: a deep stack overwrites your variables
;
; Build: acme -f plain -o build/lesson08.bin \
;        lessons/part1-6502-cpu/08-stack-and-subroutines/08-stack-and-subroutines.asm
; Run:   stella build/lesson08.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; COLOR CONSTANTS  (NTSC)
; =============================================================================
RED         = $42       ; top band
GREEN       = $C8       ; second band
BLUE        = $96       ; third band
GOLD        = $1A       ; bottom band

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
; This ROM deliberately declares NO variables: every value that has to survive
; a call lives on the stack instead.  That is not a rule to follow forever —
; it is the safe choice for a lesson about the stack.  The rule that IS worth
; remembering is the other way round: whatever variables you do declare, keep
; them away from the top of RAM, because the stack grows down into the same
; 128 bytes (the document walks through the collision in detail).

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
BANDS       = 4         ; bands on the screen: 4 calls of 48 painted lines
LINES       = 48        ; scanlines per PaintBand call (top band + the release
                        ; line; 4 x 48 + 1 = 193 non-blanked scanlines)

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, set SP = $FF, CLD (Lesson 04)

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame
; =============================================================================
; The stack is empty here on every pass: everything the previous frame pushed
; has been pulled again.  That is what "balanced" means, and SP = $FF at this
; label is the proof.  (In the debugger: set a breakpoint on StartFrame and
; watch SP never move.)
; =============================================================================
StartFrame:
    +vsync                  ; 3-line VSYNC — "a new frame starts now"

    LDA #$02
    STA VBLANK              ; blank the beam while we set up
    +set_timer 43           ; ~37 scanlines of VBLANK
    +wait_timer

    LDA BandColors          ; pre-load the top band's color BEFORE the beam
    STA COLUBK              ; is released.  A call costs cycles, so the shared
                            ; painter cannot write its first line until the
                            ; next WSYNC — without this, the first visible
                            ; line would show last frame's bottom color.
    LDA #$00
    STA VBLANK              ; un-blank — the visible picture starts now

; -----------------------------------------------------------------------------
; KERNEL — the whole picture is painted by one call
; -----------------------------------------------------------------------------
; SP is $FF here.  JSR pushes the address to come back to (two bytes), so
; inside DrawScreen SP is $FD — and every return unwinds it again.
    JSR DrawScreen          ; SP: $FF -> $FD ... and back to $FF on return

    STA WSYNC               ; wait for HBLANK before blanking.  Unwinding home
                            ; from DrawScreen costs ~28 cycles, which would put
                            ; the blank-on ~12 cycles into the VISIBLE part of
                            ; the last band line and clip it partway across;
                            ; WSYNC moves the blank-on into HBLANK instead.

; -----------------------------------------------------------------------------
; OVERSCAN
; -----------------------------------------------------------------------------
    LDA #$02
    STA VBLANK
    +set_timer 35           ; ~30 scanlines of overscan
    +wait_timer

    JMP StartFrame          ; next frame; the stack is empty again

; =============================================================================
; SUBROUTINE: DrawScreen  —  paint the whole picture, one band at a time
; =============================================================================
; How to call:   JSR DrawScreen
; What it does:  paints BANDS bands of LINES scanlines each, in the colors of
;                the BandColors table, top to bottom.  Nothing on screen
;                changes from frame to frame; the picture is a steady ladder.
; Registers:     Y is never touched — by this routine or by PaintBand.  A and
;                X do not survive: X is this routine's own counter, and on
;                return A = the last band's index and X = BANDS.  A subroutine
;                promises only what its contract says it does; here the
;                promise is Y.
; Stack:         enters with SP = $FD, returns with SP = $FD (plus the caller's
;                own return address below it); each PaintBand call adds and
;                removes its own two bytes.
;
; X is this routine's own counter: the index of the band it is about to paint.
; PaintBand needs X for its line count, so before every call we push the
; counter onto the stack and after the call we pull it back.  That is the
; whole point of the lesson: a subroutine call does not save anything for you.
; =============================================================================
DrawScreen:
    LDX #0                  ; X = band index: 0 = top band, 3 = bottom band
BandLoop:
    TXA                     ; A = the band index...
    PHA                     ; ...saved on the stack   (SP: $FD -> $FC)

    LDA BandColors,X        ; A = this band's color (PHA did not touch X)
    LDX #LINES              ; X = 48: the line count PaintBand wants
    JSR PaintBand           ; paint the band          (SP: $FC -> $FA inside)

    PLA                     ; A = the band index back (SP: $FC -> $FD)
    TAX                     ; X = our counter again
    INX                     ; next band
    CPX #BANDS              ; have we painted all four?
    BNE BandLoop            ; no -> another push / call / pull round trip
    RTS                     ; back to the frame loop  (SP: $FD -> $FF)

; =============================================================================
; SUBROUTINE: PaintBand  —  paint X scanlines of the color in A
; =============================================================================
; How to call:   A = color byte, X = scanline count, then JSR PaintBand
; What it does:  waits for the next scanline to start, then writes the color to
;                COLUBK once per line for X lines.  Writing the color right
;                after the WSYNC — instead of once before the loop — puts the
;                change in the first few cycles of the line, before the TIA
;                starts drawing on it, so band boundaries fall exactly on a
;                scanline instead of showing a notch where the new color
;                arrives mid-line.
; Registers:     A survives (still the color) and Y is never touched; X is
;                used up — the line counter counts it down to 0.  Saying which
;                registers survive is part of a subroutine's contract; here
;                the contract is "I leave A and Y alone and use up X", which
;                is why DrawScreen saves its counter before every call.
; Stack:         JSR pushed the return address; the RTS pops it.  Nothing else
;                is pushed inside, so the band loop can nest safely.
;
; One copy of this code paints all four bands.  Without a subroutine you would
; either repeat the painter four times (inlining) or write one loop that knows
; all four colors — the call lets the loop stay simple and the painter stay
; written once.  That is when a subroutine earns its keep.
; =============================================================================
PaintBand:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEX                     ; one line fewer to go: 48, 47, ... 1
    BNE -                   ; loop until the scanline counter reaches 0
    RTS                     ; return; the return address comes off the stack

; =============================================================================
; DATA — the band palette, addressed as BandColors,X (X = band index)
; =============================================================================
BandColors:
    !byte RED, GREEN, BLUE, GOLD    ; band 0 = top ... band 3 = bottom

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
