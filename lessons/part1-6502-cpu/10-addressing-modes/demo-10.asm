; =============================================================================
; LESSON 10 — DEMO: demo-10.asm  —  The Mode Ladder
; =============================================================================
; Part 1: The 6502 CPU
;
; What this program does:
;   The visual companion to Lesson 10's addressing-mode catalog: TWELVE equal
;   bands of 16 scanlines forming the fixed ramp
;
;       $1A + $0A x k   (k = 0 ... 11)
;       $1A, $24, $2E, $38, $42, $4C, $56, $60, $6A, $74, $7E, $88
;
;   Band k is painted by code that EXERCISES the k-th DATA mode in catalog
;   order (relative excepted — it has no band, so the list jumps from #9 to
;   #11):
;
;     band 0   implied       TXA          (X was seeded with LDX #$1A)
;     band 1   accumulator   ASL          (A = $12 doubled = $24)
;     band 2   immediate     LDA #$2E     the value is in the instruction
;     band 3   zero page     LDA $83      one-byte address, 3 cycles
;     band 4   zero page,X   LDA $80,X    X = 4; wraps inside page $00
;     band 5   zero page,Y   LDX $80,Y    Y = 5 (LDX/STX only, then TXA)
;     band 6   absolute      LDA Ramp+6   sixteen-bit address, 4 cycles
;     band 7   absolute,X    LDA Ramp,X   X = 7; 4 cycles (+1 on page cross)
;     band 8   absolute,Y    LDA Ramp,Y   Y = 8
;     band 9   indirect      JMP (IndPtr) the target address comes from RAM
;     band 10  (zp,X)        LDA (PtrTab,X)   X = 2 selects the second pointer
;     band 11  (zp),Y        LDA (PtrTab),Y   Y = 11 offsets what it points at
;
;   The lesson document maps every band to its mode, instruction, and the
;   debugger value to expect at the checkpoint label.  Note which mode has NO
;   band: RELATIVE, the branch mode (catalog #10).  Branches do not fetch
;   data — they change where the code runs — so the only relative operands in
;   this program are the loop branches (BNE) that walk the ladder, each
;   reaching +/-127 bytes from the next instruction.  (The CPY that feeds
;   each branch is a compare, not a branch.)
;
;   The picture is static: the ramp never changes, because every mode reads
;   fixed data.  What changes is only the ROUTE each band's byte takes.
;
; Frame geometry: 192 non-blanked scanlines — 12 EQUAL bands of 16 lines.
;   Band 0's color is pre-loaded while the beam is blanked, so the
;   beam-release line is band 0's FIRST line and PaintBand paints the other
;   15; every other band is one PaintBand call of 16 lines.  The blank-on
;   after the last band waits for HBLANK first (STA WSYNC), so the last band
;   line is painted whole.  Same skeleton as Lesson 09.
;
; Build: acme -f plain -o build/demo-10.bin \
;        lessons/part1-6502-cpu/10-addressing-modes/demo-10.asm
; Run:   stella build/demo-10.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
RampCopy    = $80       ; $80-$8B: a RAM copy of the 12 ramp bytes.
                        ;   Indexed directly by bands 3, 4, and 5.
PtrTable    = $8C       ; $8C/$8D: pointer 0 -> $0080 (the RAM copy).
                        ;   $8E/$8F: pointer 1 -> Ramp+10 (a ROM address).
                        ;   (zp,X) indexes THESE pointer slots; (zp),Y
                        ;   offsets the address pointer 0 contains.
IndPtr      = $90       ; $90/$91: the indirect JMP's target — the address
                        ;   of DemoBand9Load, three bytes after the jump.

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
BANDS       = 12        ; bands on the ladder — one per mode
LINES       = 16        ; scanlines per band (12 x 16 = 192 visible lines)

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

    ; --- Copy the ramp table into RAM $80-$8B -----------------------------
    ; Bands 3, 4, and 5 read the ramp through zero-page modes, so the bytes
    ; must live in RAM.  LDA Ramp,X / STA RampCopy,X copies all twelve, one
    ; per pass; the loop ends when X reaches BANDS.
    LDX #$00                ; X = copy index: 0 ... 11
CopyRamp:
    LDA Ramp,X              ; ABSOLUTE,X: read the ROM table ...
    STA RampCopy,X          ; ... ZERO PAGE,X: write the RAM copy
    INX
    CPX #BANDS
    BNE CopyRamp

    ; --- The pointer table for the two indirect modes ---------------------
    ; Entry 0 at $8C/$8D: the RAM copy's address, $0080.  (zp),Y uses this
    ; pointer and adds Y to it, so it can walk the copy with one pointer.
    LDA #$80                ; low byte of $0080 ...
    STA PtrTable
    LDA #$00                ; ... and its high byte: RAM lives in page 0
    STA PtrTable+1

    ; Entry 1 at $8E/$8F: the ROM address that holds ramp[10] = $7E.
    ; (zp,X) with X = 2 selects THIS slot — X indexes the pointer table.
    LDA #<Ramp+10           ; low byte of the ROM address of ramp[10]
    STA PtrTable+2
    LDA #>Ramp+10
    STA PtrTable+3

    ; --- The indirect jump's target ---------------------------------------
    ; JMP (IndPtr) below reads its destination from these two bytes.
    LDA #<DemoBand9Load     ; where band 9's loader starts ...
    STA IndPtr
    LDA #>DemoBand9Load     ; ... as a full 16-bit address
    STA IndPtr+1

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame; the ladder is static
; =============================================================================
StartFrame:
    +vsync                  ; 3-line VSYNC — "a new frame starts now"

    LDA #$02
    STA VBLANK              ; blank the beam while we set up
    +set_timer 43           ; ~37 scanlines of VBLANK

; -----------------------------------------------------------------------------
; BAND 0 — IMPLIED  (TXA)
; -----------------------------------------------------------------------------
; An implied-mode instruction names no operand at all: the CPU already knows
; what to act on.  TXA copies X into A; X is the seed, loaded here so the
; transfer has something to move.  Band 0's color must be in COLUBK before
; the beam is released, so the transfer happens during VBLANK and the color
; waits in Y across the timer (+wait_timer leaves its own value in A).
    LDX #$1A                ; the seed: ramp[0] = $1A
    TXA                     ; IMPLIED: no operand — X is the operand
DemoBand0:                  ; debugger checkpoint: break here, A = $1A
    TAY                     ; park the color: +wait_timer clobbers A

    +wait_timer             ; finish the ~37 scanlines of VBLANK

    LDA #$00
    STA VBLANK              ; un-blank: this line is band 0's FIRST line
    TYA                     ; A = band 0's color again
    STA COLUBK              ; written in HBLANK, so the release line shows it

    LDX #LINES-1            ; X = 15: release line + 15 painted = band 0
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 1 — ACCUMULATOR  (ASL)
; -----------------------------------------------------------------------------
; Accumulator mode is the one where the operand is the accumulator itself.
; The shifts and rotates are the instructions that use it (written with no
; operand in ACME: bare ASL/LSR/ROL/ROR).  ASL doubles A in place: $12 x 2
; = $24, and the old bit 7 — 0 here — lands in the carry.
    LDA #$12                ; A = $12 = $24 / 2 ...
    ASL                     ; ACCUMULATOR: A = A x 2 = $24, C = old bit 7
DemoBand1:                  ; debugger checkpoint: break here, A = $24, C = 0
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 2 — IMMEDIATE  (LDA #$2E)
; -----------------------------------------------------------------------------
; The operand is the value.  No memory read happens: the byte is part of the
; instruction stream, so it is already on the CPU's bus when the instruction
; runs.  2 bytes, 2 cycles — the fastest way to get a constant into A.
    LDA #$2E                ; IMMEDIATE: the # means "literal", not "address"
DemoBand2:                  ; debugger checkpoint: break here, A = $2E
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 3 — ZERO PAGE  (LDA $83)
; -----------------------------------------------------------------------------
; $83 is a one-byte address, so the whole instruction is 2 bytes and the
; access takes 3 cycles.  RampCopy+3 is the fourth ramp byte, $38.
    LDA RampCopy+3          ; ZERO PAGE: the operand is the address ($83)
DemoBand3:                  ; debugger checkpoint: break here, A = $38
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 4 — ZERO PAGE,X  (LDA $80,X)
; -----------------------------------------------------------------------------
; The index is added to the one-byte base, and the sum stays inside page $00.
; Here X = 4 walks from RampCopy to ramp[4] = $42.  (The wrap is a hazard at
; the top of the page — see the lesson's stretch exercise.)
    LDX #$04                ; X = 4: ramp[4] lives at RampCopy+4 = $84
    LDA RampCopy,X          ; ZERO PAGE,X: 2 bytes, 4 cycles
DemoBand4:                  ; debugger checkpoint: break here, A = $42, X = $04
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 5 — ZERO PAGE,Y  (LDX $80,Y)
; -----------------------------------------------------------------------------
; The mirror of band 4 with Y as the index — except that the instruction is
; LDX, not LDA.  There is no LDA zero page,Y on the 6502: that mode exists
; only for LDX and STX.  So this band's byte arrives through X, and TXA (an
; implied-mode instruction) moves it into A for the painter.  The two index
; registers are close to interchangeable, but the instruction sets are not.
    LDY #$05                ; Y = 5: the sixth ramp byte
    LDX RampCopy,Y          ; ZERO PAGE,Y: 2 bytes, 4 cycles — LDX only
    TXA                     ; implied: move the byte into A for PaintBand
DemoBand5:                  ; debugger checkpoint: break here, A = $4C, Y = $05
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 6 — ABSOLUTE  (LDA Ramp+6)
; -----------------------------------------------------------------------------
; Sixteen bits of address, spelled as three bytes in the instruction: 4
; cycles.  The address is outside the zero page, so absolute is the only
; mode that reaches the ROM table with a fixed address.
    LDA Ramp+6              ; ABSOLUTE: base + 6 = ramp[6] = $56
DemoBand6:                  ; debugger checkpoint: break here, A = $56
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 7 — ABSOLUTE,X  (LDA Ramp,X)
; -----------------------------------------------------------------------------
; The true 16-bit indexed read: base + X with the carry propagated into the
; high byte.  The table is page-aligned, so X = 7 cannot cross a page and the
; load costs exactly 4 cycles (a crossing would make it 5).
    LDX #$07                ; X = 7: ramp[7]
    LDA Ramp,X              ; ABSOLUTE,X: one instruction, twelve possible bytes
DemoBand7:                  ; debugger checkpoint: break here, A = $60, X = $07
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 8 — ABSOLUTE,Y  (LDA Ramp,Y)
; -----------------------------------------------------------------------------
; The same indexed read, indexed by Y instead.  PaintBand preserves Y, so a
; loop that walks a table with LDA table,Y can call the painter without
; saving and restoring the index.
    LDY #$08                ; Y = 8: ramp[8]
    LDA Ramp,Y              ; ABSOLUTE,Y: 3 bytes, 4 cycles
DemoBand8:                  ; debugger checkpoint: break here, A = $6A, Y = $08
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 9 — INDIRECT  (JMP (IndPtr))
; -----------------------------------------------------------------------------
; JMP is the ONLY instruction with an indirect mode on the 6502.  The operand
; names two bytes in zero page; the CPU reads a 16-bit address out of them and
; jumps there.  That makes the destination DATA: change $90/$91 in the
; debugger and the same program goes somewhere else.
;
; The NMOS 6502 has a famous bug in this mode: if the pointer's low byte is
; $FF, the CPU fetches the high byte from the same page (e.g. JMP ($F0FF)
; reads its target's high byte from $F000).  The pointer here is at $90/$91,
; nowhere near a page boundary, so the bug cannot apply — the lesson explains
; it rather than exploiting it.
    JMP (IndPtr)            ; INDIRECT: target = the address stored at $90/$91
DemoBand9Load:              ; the indirect jump lands here every frame
    LDA Ramp+9              ; ramp[9] = $74, fetched once the jump has landed
DemoBand9:                  ; debugger checkpoint: break here, A = $74
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 10 — (zp,X)  —  INDEXED INDIRECT  (LDA (PtrTab,X))
; -----------------------------------------------------------------------------
; The operand names a zero-page slot; X is added to THAT SLOT NUMBER, not to
; an address.  X = 2 points at the SECOND pointer in the table — the one at
; $8E/$8F holding Ramp+10 — and the CPU then reads through it.  This is how
; one instruction picks both a pointer and returns what it points at.
    LDX #$02                ; X = 2: select pointer table entry 1 ($8E/$8F)
    LDA (PtrTable,X)        ; INDEXED INDIRECT: 2 bytes, 6 cycles
DemoBand10:                 ; debugger checkpoint: break here, A = $7E, X = $02
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 11 — (zp),Y  —  INDIRECT INDEXED  (LDA (PtrTab),Y)
; -----------------------------------------------------------------------------
; The fixed pointer at $8C/$8D holds $0080; the CPU reads that 16-bit address
; and adds Y to it.  Y = 11 walks to RampCopy+11 = $88 — the last ramp byte.
; Because the add is sixteen bits wide, Y may cross a page (that costs one
; extra cycle); the pointer's target does not have to be in zero page at all.
    LDY #$0B                ; Y = 11: the twelfth ramp byte
    LDA (PtrTable),Y        ; INDIRECT INDEXED: 2 bytes, 5 cycles
DemoBand11:                 ; debugger checkpoint: break here, A = $88, Y = $0B
    LDX #LINES
    JSR PaintBand

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

    JMP StartFrame          ; next frame — the ladder never changes

; =============================================================================
; SUBROUTINE: PaintBand  —  paint X scanlines of the color in A
; =============================================================================
; How to call:   A = color byte, X = scanline count, then JSR PaintBand
; What it does:  waits for the next scanline to start, then writes the color
;                to COLUBK once per line for X lines.  Writing the color
;                right after the WSYNC puts the change in the first few
;                cycles of the line, so band boundaries fall exactly on a
;                scanline.
; Registers:     A survives (still the color) and Y is never touched; X is
;                used up — the line counter counts it down to 0.
; Stack:         JSR pushed the return address; the RTS pops it.
; =============================================================================
PaintBand:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEX                     ; one line fewer to go: 16, 15, ... 1
    BNE -                   ; loop until the line counter reaches 0
    RTS                     ; return; the return address comes off the stack

; =============================================================================
; DATA — the ramp, one byte per band
; =============================================================================
; Page-aligned so that the X and Y indexes used on it cannot cross a page:
; LDA abs,X and LDA abs,Y cost exactly 4 cycles here instead of 4+1.
    !align 255, 0, 0
Ramp:
    !byte $1A, $24, $2E, $38    ; bands 0-3
    !byte $42, $4C, $56, $60    ; bands 4-7
    !byte $6A, $74, $7E, $88    ; bands 8-11

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
