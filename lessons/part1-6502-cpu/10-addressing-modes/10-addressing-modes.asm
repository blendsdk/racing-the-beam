; =============================================================================
; LESSON 10: Addressing Modes — How the CPU Finds Data
; =============================================================================
; Part 1: The 6502 CPU
;
; What this program does:
;   "Same byte, several ways": TWELVE bands of 16 scanlines each.  The TOP
;   six bands all show the SAME value — the byte at RAM $82, which holds $42
;   — but each band FETCHES it with a different addressing mode:
;
;     band 0   LDA #$42       immediate      the value is in the instruction
;     band 1   LDA $82        zero page      1-byte address; 2 bytes, 3 cycles
;     band 2   LDA $0082      absolute       16-bit address; 3 bytes, 4 cycles
;     band 3   LDA $82,X      zero page,X    X = 0; base wraps in page $00
;     band 4   LDA $0082,X    absolute,X     X = 0; a true 16-bit address
;     band 5   LDA ($80),Y    (zp),Y         Y = 0; pointer $80/$81 = $0082
;
;   All six bands look identical on screen, because all six arrive with $42
;   in the accumulator.  That is the point: addressing modes are different
;   ROUTES to the same data.  The bottom six bands are different: they show
;   the ramp $42, $4C, $56, $60, $6A, $74, fetched from the 6-byte ROM table
;   at Ramp with LDA Ramp,Y — the mode that lets ONE instruction read MANY
;   values, with Y choosing which.
;
;   The program also uses the only indirect instruction on the 6502: band 0's
;   paint call goes through JMP (BandPtr), a pointer at $83/$84 that holds
;   PaintBand's address.  Change those two bytes and the same program jumps
;   somewhere else — the jump's destination is data.
;
; What you'll learn:
;   - The full mode catalog: implied, accumulator, immediate, zero page,
;     zero page,X/,Y, absolute, absolute,X/,Y, relative, indirect,
;     (zp,X), and (zp),Y
;   - Length and cycle differences: the same byte, cheaper or dearer
;   - The zero-page wrap hazard: LDA $80,X with X = $80 reads TIA $00
;   - Branches are relative: +/-127 bytes from the next instruction
;   - JMP ($xxFF): the NMOS page-boundary bug (explained, not used)
;   - Index registers select table entries: LDA Ramp,Y
;
; Frame geometry: 192 non-blanked scanlines — 12 EQUAL bands of 16 lines.
;   Band 0's color is pre-loaded while the beam is blanked, so the
;   beam-release line is band 0's FIRST line and PaintBand paints the other
;   15; every other band is one PaintBand call of 16 lines.  The blank-on
;   after the last band waits for HBLANK first (STA WSYNC), so the last band
;   line is painted whole.  Same skeleton as Lesson 09.
;
; Build: acme -f plain -o build/lesson10.bin \
;        lessons/part1-6502-cpu/10-addressing-modes/10-addressing-modes.asm
; Run:   stella build/lesson10.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
Ptr         = $80       ; $80/$81: the (zp),Y pointer.  Its two bytes are
                        ;   $82 and $00, so it points at RAM address $0082.
Shared      = $82       ; the byte every MEMORY-mode band reads: $42.
                        ;   Written once at startup and never again.
BandPtr     = $83       ; $83/$84: the indirect-jump pointer.  Holds the
                        ;   address of PaintBand — the subroutine that sits
                        ;   immediately before the trampoline that reads it.

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
BANDS       = 12        ; bands on the screen
LINES       = 16        ; scanlines per band (12 x 16 = 192 visible lines)
RAMP_BANDS  = 6         ; the bottom half: one entry per ramp band

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

    ; --- The shared byte: stored ONCE, read six different ways per frame ---
    LDA #$42                ; the byte every memory-mode band will fetch
    STA Shared              ; $82 = $42 — no instruction below writes it again

    ; --- The (zp),Y pointer: $80/$81 = $0082 ---
    LDA #<Shared            ; A = $82 — the LOW byte of the target address
PtrLow:                     ; debugger checkpoint: break here, A = $82
    STA Ptr                 ; $80 = $82: writing the pointer's low first
    LDA #>Shared            ; A = $00 — the HIGH byte: RAM $82 sits in page 0
PtrHigh:                    ; debugger checkpoint: break here, A = $00
    STA Ptr+1               ; $81 = $00: together, $80/$81 read as $0082

    ; --- The indirect-jump pointer: $83/$84 = PaintBand ---
    LDA #<PaintBand         ; the painter's address, low byte ...
    STA BandPtr
    LDA #>PaintBand         ; ... and high byte.  Low byte $83 is nowhere
    STA BandPtr+1           ; near $FF, so the JMP ($xxFF) bug cannot bite.

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame
; =============================================================================
StartFrame:
    +vsync                  ; 3-line VSYNC — "a new frame starts now"

    LDA #$02
    STA VBLANK              ; blank the beam while we set up
    +set_timer 43           ; ~37 scanlines of VBLANK

; -----------------------------------------------------------------------------
; BAND 0 — IMMEDIATE  (LDA #$42)
; -----------------------------------------------------------------------------
; Band 0 is the TOP band, and its color must be in COLUBK BEFORE the beam is
; released — the release line is band 0's first line.  So this fetch happens
; during VBLANK, and the color is parked in Y across the timer wait (the
; +wait_timer macro leaves its own value in A).
;
; Immediate mode: the operand lives inside the instruction.  There is no
; memory read at all — the CPU already has $42 before the instruction ends.
    LDA #$42                ; IMMEDIATE: 2 bytes, 2 cycles, no memory access
FetchImmediate:             ; debugger checkpoint: break here, A = $42
    TAY                     ; park the color: +wait_timer clobbers A

    +wait_timer             ; finish the ~37 scanlines of VBLANK

    LDA #$00
    STA VBLANK              ; un-blank: this line is band 0's FIRST line
    TYA                     ; A = band 0's color again
    STA COLUBK              ; written in HBLANK, so the release line shows it

    LDX #LINES-1            ; X = 15: release line + 15 painted = band 0
    JSR PaintBandViaPtr     ; paint it — reached through the $83/$84 pointer

; -----------------------------------------------------------------------------
; BAND 1 — ZERO PAGE  (LDA $82)
; -----------------------------------------------------------------------------
; The address of the data fits in ONE byte, so the instruction is 2 bytes
; long and the access takes 3 cycles.  All 2600 RAM is zero page, so every
; variable access is a zero-page access.
    LDA Shared              ; ZERO PAGE: the $82 in the operand is the address
FetchZeroPage:              ; debugger checkpoint: break here, A = $42
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 2 — ABSOLUTE  (LDA $0082)
; -----------------------------------------------------------------------------
; The SAME address, spelled with sixteen bits.  ACME chooses the length from
; the way the address is written: leading zeros mean "use absolute".  Three
; bytes long, 4 cycles — one byte and one cycle more for the same value.
    LDA $0082               ; ABSOLUTE: 3 bytes, 4 cycles
FetchAbsolute:              ; debugger checkpoint: break here, A = $42
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 3 — ZERO PAGE,X  (LDA $82,X)
; -----------------------------------------------------------------------------
; The index is added to the base BEFORE the access.  X = 0 here, so this
; band reads $82 — but the important property is the WRAP: the sum stays
; inside page $00.  With X = $80 the address would be $02, not $102.  The
; lesson's stretch exercise shows how that silently lands on the TIA.
    LDX #$00                ; X = 0: the base index; $82 + 0 = $82
    LDA Shared,X            ; ZERO PAGE,X: 2 bytes, 4 cycles
FetchZeroPageX:             ; debugger checkpoint: break here, A = $42, X = $00
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 4 — ABSOLUTE,X  (LDA $0082,X)
; -----------------------------------------------------------------------------
; The same indexed read with a sixteen-bit base.  Now the sum is a real
; 16-bit add: base + X can leave the page, and if it does, the access takes
; one extra cycle (4+1).  With X = 0 it does not, so this band costs 4.
    LDX #$00                ; X = 0 again
    LDA $0082,X             ; ABSOLUTE,X: 3 bytes, 4 cycles (+1 on page cross)
FetchAbsoluteX:             ; debugger checkpoint: break here, A = $42, X = $00
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 5 — (zp),Y  —  INDIRECT INDEXED  (LDA ($80),Y)
; -----------------------------------------------------------------------------
; The operand names a ZERO-PAGE PAIR ($80/$81), not an address.  The CPU
; reads a 16-bit address out of those two bytes — here $0082 — and then adds
; Y to it.  This is the mode for walking a buffer at a run-time-chosen base.
    LDY #$00                ; Y = 0: the offset added to the pointer's target
    LDA (Ptr),Y             ; INDIRECT INDEXED: 2 bytes, 5 cycles (+1 on page
                            ;   cross); pointer $80/$81 = $0082, so it reads $82
FetchIndirectY:             ; debugger checkpoint: break here, A = $42, Y = $00
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BANDS 6-11 — THE RAMP  (LDA Ramp,Y)
; -----------------------------------------------------------------------------
; One instruction, six values: Y is added to the table's 16-bit address and
; the load returns that entry.  The table is page-aligned (see !align below),
; so Y = 0...5 never crosses a page and the load is always exactly 4 cycles.
    LDY #$00                ; Y = the table index: entry 0 is the first band
RampLoop:
    LDA Ramp,Y              ; ABSOLUTE,Y: one instruction reads six colors
RampFetch:                  ; debugger checkpoint: break here, A = Ramp[Y]
    LDX #LINES
    JSR PaintBand           ; PaintBand preserves Y: it can index the table
    INY                     ; next table entry
    CPY #RAMP_BANDS         ; 0 ... 5 — the loop stops at the table's edge
    BNE RampLoop

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

    JMP StartFrame          ; next frame — the picture is static

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
; Registers:     A survives (still the color) and Y is never touched — the
;                ramp loop relies on that; X is used up: the line counter
;                counts it down to 0.
; Stack:         JSR pushed the return address; the RTS pops it.  Nothing
;                else is pushed inside, so callers can use the stack freely.
; =============================================================================
PaintBand:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEX                     ; one line fewer to go: 16, 15, ... 1
    BNE -                   ; loop until the line counter reaches 0
    RTS                     ; return; the return address comes off the stack

; =============================================================================
; CALLING A SUBROUTINE THROUGH A POINTER  —  JMP (indirect)
; =============================================================================
; The 6502 has no "JSR (indirect)".  To call through a pointer you JSR to a
; two-byte trampoline that does the indirect JMP: the JSR has already pushed
; the return address, so when PaintBand finishes, its RTS pops that address
; and control comes back to the instruction after the JSR.
;
; Band 0's call uses this path every frame, with the target address read from
; the pointer at $83/$84.  The pointer's low byte is $83 — not $FF — so the
; NMOS JMP ($xxFF) bug (documented in the lesson text) cannot apply.
PaintBandViaPtr:
    JMP (BandPtr)           ; INDIRECT: read the target address from $83/$84

; =============================================================================
; DATA — the six ramp colors, read as Ramp,Y
; =============================================================================
; Page-aligned so that Y = 0...5 cannot cross a page: LDA abs,Y costs exactly
; 4 cycles here instead of 4+1.  (!align pads to the next page with zeros.)
    !align 255, 0, 0
Ramp:
    !byte $42, $4C, $56     ; bands 6-8
    !byte $60, $6A, $74     ; bands 9-11

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
