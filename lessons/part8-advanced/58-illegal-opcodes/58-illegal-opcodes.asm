; =============================================================================
; LESSON 58: Illegal Opcodes — Undocumented Power — Racing the Beam
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "the opcode laboratory": a 4,096-byte cartridge that runs the four stable
;   undocumented NMOS 6502 instructions — LAX, SAX, DCP and ISB — once per
;   frame in VBLANK on known inputs, stores the result bytes, the processor
;   flags and an XOR checksum in RAM, and draws a 192-line instrument panel
;   that shows the results as playfield bars.  SELECT switches to a second
;   screen: the documented-versus-illegal cycle table for eight stable
;   opcodes, drawn as bars.  An auto-demo toggles the screen every 240 frames
;   and walks the P0 marker down the four result rows every 60 frames.
;
; The four operations (zero-page forms):
;   LAX zp  $A7  A = M and X = M; N and Z from M.        illegal 3 cycles
;                documented: LDA zp (3) + TAX (2) = 5
;   SAX zp  $87  M = A AND X; no flags change.           illegal 3 cycles
;                documented: STX zp (3) + AND zp (3) + STA zp (3) = 9
;                (7 if the mask is an immediate: TXA + AND #mask + STA zp)
;   DCP zp  $C7  M = M - 1; then CMP A,M (A - M).        illegal 5 cycles
;                documented: DEC zp (5) + CMP zp (3) = 8
;   ISB zp  $E7  M = M + 1; then SBC A,M.                illegal 5 cycles
;                documented: INC zp (5) + SBC zp (3) = 8
;   (ISB is also written ISC in some references.  The byte is the same.)
;
; The inputs and the results:
;   LAX  $90 = $12                  -> A = X = $12
;   SAX  A = $12, X = $34, $91      -> $91 = $12 & $34 = $10
;   DCP  $92 = $20, A = $1F         -> $92 = $1F; A - M = 0: Z=1, C=1
;   ISB  $93 = $10, A = $20, SEC    -> $93 = $11; A = $20-$11 = $0F, C=1
;   The four result bytes are $12, $10, $1F, $11.  Their XOR is $0C.
;
; ACME 0.97 and the illegal mnemonics:
;   ACME has no 6502i type.  Under !cpu 6502 the undocumented mnemonics are
;   rejected; under !cpu 6510 the assembler accepts them (LAX, SAX, DCP and
;   ISC, the 6510 spelling of ISB).  This course keeps !cpu 6502 and
;   emits the bytes with the four named macros below, so every opcode byte
;   stays visible in the listing.  The emitted bytes are identical:
;       !macro LAX_ZP .addr { !byte $A7, .addr }
;   Every use is a +LAX_ZP / +SAX_ZP / +DCP_ZP / +ISB_ZP line.  This is not
;   a workaround hidden from the reader: it is the honest toolchain answer,
;   and it makes the opcode table in the lesson document exact.
;
; Why these four and not the unstable ones:
;   LAX, SAX, DCP, ISB, SLO, RLA, SRE and RRA are the stable undocumented
;   instructions: their behaviour is the same on every NMOS 6502/6507 die.
;   The unstable group (ANE, LXA, SHA, SHX, SHY, TAS, LAS, the KIL/JAM
;   opcodes) can depend on the data bus, the temperature, or the individual
;   chip.  This lesson does not use them.  The 65C02 does not implement the
;   NMOS undocumented opcodes the same way (many became NOPs or new
;   instructions), so portable code must not depend on them.
;
; The screen (192 visible lines in both modes):
;   visible   0-15   the title block: a gold frame and "LAB" in 4-chunk glyphs
;   visible  16-47   four 8-line byte/cycle labels, one per operation
;                      line 0: the opcode byte as eight PF chunks (bit 7 first)
;                      line 1: the illegal cycle count as a PF2 bar
;                      line 2: the documented count as a white bar
;                      lines 3-7: blank
;   visible     48   a one-line setup gap (blank)
;   visible  49-176  the middle: four 32-line result rows (screen 0) or
;                    eight 16-line cycle bands (screen 1)
;   visible    177   the white footer rule
;   visible 178-183  six blank lines
;   visible 184-191  the XOR checksum as eight chunks and the screen indicator
;                    (left of centre = screen 0, right of centre = screen 1)
;
; The result row (32 lines):
;   PF0/PF1  eight flag columns (N V 1 B D I Z C), one chunk each, full height
;            PF0 = Rev4[flags >> 4] << 4; PF1 = (flags & $0F) << 4
;   PF2      the result bar: chunks 12-13, present only on the last `result`
;            lines of the row, so the bar's height is the result byte.
;            BarStart = 32 - result; the bar is drawn when Y >= BarStart.
;   P0       an 8x8 gold diamond at TIA X = 32, on the selected row's lines
;            20-27.  The marker strip is 33 bytes of ROM: 20 zeros, the
;            diamond, 5 zeros; MarkerStrip+1,Y is the value for line Y+1.
;   The row colours: LAX green, SAX blue, DCP orange, ISB purple.
;
;   Every line writes PF0/PF1 first, the PF2 bar next, and preloads the NEXT
;   line's GRP0.  The WSYNC/loop tail (INY/CPY/BNE) runs at the top of the
;   next line, so the cycle numbers below are measured from ResultLine:
;   PF0 by 7, PF1 by 14, PF2 by 24-26, the marker's LDA at ~40 and its
;   STA GRP0 at ~43.  Absolute scanline cycles are PF0/PF1 14/21 on a normal
;   line and 18/25 on the first line of rows 2-4 (the row-end LDY #0/JMP adds
;   5).  The next row's colour/PF2/BarCur are preloaded on the current row's
;   last line after the playfield is drawn; the last row ends with STA WSYNC
;   and jumps to the footer.  This keeps the first line of every row complete:
;   the old row setup wrote PF0 at 24-31 and PF1 at 31-38, after the beam.
;
; The cycle-table screen (screen 1):
;   eight 16-line bands, one per opcode: LAX, SAX, DCP, ISB, SLO, RLA, SRE,
;   RRA.  Each band has a separator line, a two-line documented bar (white)
;   at chunks 2..2+cycles-1, and a two-line illegal bar (the op's colour).
;   The documented counts are 5, 9, 8, 8, 8, 8, 8, 8; the illegal counts are
;   3, 3, 5, 5, 5, 5, 5, 5.  The first four bands are the lab's four ops;
;   the last four are documented examples of the same pattern.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;   One HMOVE per frame for the P0 marker.
;
; Cycle ledger (a line is 76 CPU cycles; the loops are page-local):
;   title row:      LDA/STA x3 (21) + WSYNC 3 + INY 2 + CPY 2 + BNE 3 = 31.
;                   PF0 is stored by cycle 14 on every row.
;   label row 0:    colour/PF0/PF1 by 27 on the first strip (after the
;                   title's 6-cycle tail), by 25 on the other three (after
;                   the blank loop's 4-cycle tail); PF2 by 32.  The old
;                   loop's INX/CPX/BNE tail put PF1 at 28-31; unrolling the
;                   four strips removes it.
;   label row 1:    PF2 first (7), then PF0/PF1 (12) = 19; PF0 by 12.
;   label row 2:    colour (5) + PF1 (7) + PF2 (7) + PF0 (5) = 24.
;   result row:     measured from ResultLine: PF0 7, PF1 14, PF2 24-26,
;                   marker LDA ~40, STA GRP0 ~43; a normal line ends at
;                   ~46-50 (about 26-30 unused).  The RowEnd line adds the
;                   next-row preload (after the playfield, cycle 42) and ends
;                   at ~66 (about 10 unused).  Absolute scanline PF0/PF1 are
;                   14/21 normal and 18/25 on the first line of rows 2-4.
;   table band:     the separator's tail is 9 cycles (the index update now
;                   runs before the nine blanks), so its colour, PF0, PF1 and
;                   PF2 are written by 16/21/26/29; the chunk-4 boundary is 28.
;                   The bar lines write within 25 cycles and repeat the value.
;   footer:         colour by 8, PF0 by 13, PF1 by 18, PF2 by 21 on screen 0;
;                   the screen-1 band loop reaches the footer ~7 cycles later,
;                   still before PF0's chunk 0.  The rule starts at chunk 0.
;   The RowEnd line is ~66 cycles (about 10 unused); a normal line leaves ~26-30.
;
; Checkpoints (the state log's A/X/Y/SP and P fields):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   OverscanStart (229/6);
;   Frame (A = the new frame count, 1, 2, 3, ...);
;   LaxRead (A = $12, X = $12), SaxRead (A = $12),
;   DcpRead (A = $1F), IsbRead (A = $0F), FlagsRead (P after ISB);
;   SaxM (A = $10), DcpM (A = $1F, C = 1), IsbM (A = $11);
;   Checksum (A = $0C), Screen (A = 0/1).
;
; RAM map (RIOT, $80-$FF; +clean_start zeroes every byte):
;   $80 ResultA      LAX's A, $12
;   $81 ResultX      LAX's X, $12
;   $82 ResultM      the last M result, ISB's $11
;   $83 Flags        the live P after ISB, $25
;   $84 Checksum     XOR of the four result bytes, $0C
;   $85 Screen       0 = the lab, 1 = the cycle table
;   $86 Result0..3   the four displayed result bytes ($12,$10,$1F,$11)
;   $8A Flag0..3     the four live P bytes ($24,$24,$27,$25)
;   $8E MarkerRow    the selected row, 0..3
;   $8F FrameCount   frames since reset, wraps at 256
;   $90 LaxMem       LAX's input, $12 (read-only)
;   $91 SaxMem       SAX's destination, written $10 every frame
;   $92 DcpMem       DCP's input, reset to $20, becomes $1F
;   $93 IsbMem       ISB's input, reset to $10, becomes $11
;   $94 PrevSelect   SELECT state last frame (1 = pressed)
;   $95 SelectNow    this frame's SELECT level
;   $96 MarkerTimer  the 60-frame marker divider
;   $97 ScreenTimer  the 240-frame screen divider
;   $98 Startup      frames left before SELECT is trusted
;   $99 BarCur       the current row's BarStart
;   $9A Tmp          scratch
;   $9B-$9C          free (2 bytes)
;   $9D ChecksumPF1  the footer's checksum bits 7-2, precomputed
;   $9E ChecksumPF2  the footer's checksum bits 1-0, precomputed
;   $9F              free (1 byte)
;   $A0 RowF0        four flag-field PF0 bytes, one per row
;   $A4 RowF1        four flag-field PF1 bytes, one per row
;   $A8 BarStart     four bar thresholds, one per row
;   $AC-$D7 free
;   $D8-$F7 free
;   $F8-$FF stack
;
; Build: acme -f plain -o build/lesson58.bin \
;        lessons/part8-advanced/58-illegal-opcodes/58-illegal-opcodes.asm
; Run:   stella build/lesson58.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; THE UNDOCUMENTED OPCODES AS NAMED MACROS
; =============================================================================
; ACME 0.97 has no 6502i type.  Under !cpu 6502 the undocumented mnemonics are
; rejected; under !cpu 6510 they assemble (LAX, SAX, DCP and ISC for ISB).
; This course keeps !cpu 6502, and each macro emits the opcode byte followed by
; the zero-page operand.  The names keep the source readable; the bytes keep
; the lesson honest.  A macro invocation is written +LAX_ZP LaxMem and so on.
!macro LAX_ZP .addr {
    !byte $A7, .addr        ; LAX zp: A = M, X = M
}
!macro SAX_ZP .addr {
    !byte $87, .addr        ; SAX zp: M = A AND X
}
!macro DCP_ZP .addr {
    !byte $C7, .addr        ; DCP zp: M = M-1, then CMP A,M
}
!macro ISB_ZP .addr {
    !byte $E7, .addr        ; ISB zp: M = M+1, then SBC A,M (6510: ISC)
}

; +SAVE_P stores the live processor flags in .dest without destroying A.
; PHP pushes a copy with the B marker set; PLA reads it back, AND #$EF clears
; the marker, and the saved A is restored from Tmp.  The stack is used for one
; byte at a time, so the call depth does not grow.
!macro SAVE_P .dest {
    STA Tmp                 ; preserve the result byte
    PHP
    PLA
    AND #$EF                ; clear the PHP B marker
    STA .dest
    LDA Tmp                 ; restore the result byte
}

; -----------------------------------------------------------------------------
; LABEL_STRIP — one 8-line byte/cycle label strip, unrolled four times
; -----------------------------------------------------------------------------
; The four strips used to be a loop with an INX/CPX/BNE tail.  That tail put
; the byte line's PF1 write at cycle 28-31, after chunks 4-6, so the ISB byte
; lost bit 5 (chunk 4) and the LAX bit 5 was short.  Unrolling removes the
; tail: the byte line's colour/PF0/PF1 writes complete at cycle 27, before
; chunk 4 at cycle 28.  The illegal and documented bars are right-aligned at
; chunk 19, so their lengths compare from the same edge.
!macro LABEL_STRIP .idx {
; --- line 0: the opcode byte, bit 7 first ------------------------------------
    LDA OpColor + .idx
    STA COLUPF
    LDA OpBytePF0 + .idx
    STA PF0
    LDA OpBytePF1 + .idx
    STA PF1
    LDA #$00
    STA PF2
    STA WSYNC
; --- line 1: the illegal cycle bar, right-aligned at chunk 19 ---------------
    LDA OpIllegalPF2 + .idx
    STA PF2
    LDA #$00
    STA PF0
    STA PF1
    STA WSYNC
; --- line 2: the documented cycle bar, white, right-aligned at chunk 19 ------
    LDA #C_WHITE
    STA COLUPF
    LDA OpDocPF1 + .idx
    STA PF1
    LDA OpDocPF2 + .idx
    STA PF2
    LDA #$00
    STA PF0
    STA WSYNC
; --- lines 3-7: blank --------------------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #5
-
    STA WSYNC
    DEY
    BNE -
}

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan
POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

SCREEN_LINES   = 192     ; every frame draws 192 visible lines
TITLE_LINES    = 16      ; the gold LAB block
LABEL_LINES    = 32      ; four 8-line byte/cycle labels
MIDDLE_LINES   = 128     ; four 32-line result rows, or eight 16-line bands
GAP_LINES      = 1       ; one setup line before the middle content
FOOTER_LINES   = 15      ; the rule, the checksum and the screen indicator

ROW_COUNT      = 4       ; LAX, SAX, DCP, ISB
ROW_LINES      = 32      ; one row per operation
BAND_COUNT     = 8       ; the four lab ops plus SLO/RLA/SRE/RRA
BAND_LINES     = 16      ; one cycle-table band

MARKER_X       = 32      ; the P0 marker's TIA X (the gap between the fields)
MARKER_TOP     = 20      ; the marker's first line inside a row

MARKER_FRAMES  = 60      ; the marker steps down every 60 frames
SCREEN_FRAMES  = 240     ; the screen toggles every 240 frames
STARTUP_FRAMES = 8       ; SELECT is ignored while the console settles

C_BG           = $00     ; black page
C_TITLE        = $1A     ; gold title frame
C_WHITE        = $0E     ; white documented-cycle bars and footer
C_MARK         = $1A     ; gold marker (the same gold as the title)
C_LAX          = $C8     ; green
C_SAX          = $84     ; blue
C_DCP          = $38     ; orange
C_ISB          = $66     ; purple
C_GRAY         = $0A     ; the four documented-example bands

FLAG_BAND_TOP  = 4       ; the flag columns run the full row; kept for clarity

; The frame arithmetic is a build-time assertion, not a comment.
!if TITLE_LINES + LABEL_LINES + GAP_LINES + MIDDLE_LINES + FOOTER_LINES != SCREEN_LINES {
    !error "the five screen zones must total 192 lines"
}
!if ROW_COUNT * ROW_LINES != MIDDLE_LINES {
    !error "four 32-line rows must fill the middle 128 lines"
}
!if BAND_COUNT * BAND_LINES != MIDDLE_LINES {
    !error "eight 16-line bands must fill the middle 128 lines"
}

; =============================================================================
; RAM ALLOCATION ($80-$AB; +clean_start zeroes every byte)
; =============================================================================
ResultA      = $80    ; LAX's A, $12
ResultX      = $81    ; LAX's X, $12
ResultM      = $82    ; the last M result, ISB's $11
Flags        = $83    ; the live P after ISB, $25
ChecksumVal  = $84    ; XOR of the four result bytes, $0C
ScreenNum    = $85    ; 0 = lab, 1 = cycle table

ResultBytes  = $86    ; four bytes: LAX, SAX, DCP, ISB
FlagBytes    = $8A    ; four live P bytes, one per operation

MarkerRow    = $8E    ; 0..3
FrameCount   = $8F    ; frames since reset
LaxMem       = $90    ; LAX's input, $12
SaxMem       = $91    ; SAX's destination, $10
DcpMem       = $92    ; DCP's input, $20 -> $1F
IsbMem       = $93    ; ISB's input, $10 -> $11
PrevSelect   = $94
SelectNow    = $95
MarkerTimer  = $96
ScreenTimer  = $97
Startup      = $98
BarCur       = $99
Tmp          = $9A

ChecksumPF1  = $9D    ; the footer's checksum bits 7-2
ChecksumPF2  = $9E    ; the footer's checksum bits 1-0

RowF0        = $A0    ; four flag-field PF0 bytes
RowF1        = $A4    ; four flag-field PF1 bytes
BarStart     = $A8    ; four bar thresholds, 32 - result

; $AC-$D7 and $D8-$F7 are free.  The stack lives at $F8-$FF; the call depth is
; one level (RunLab, BuildDisplay, SetCoarseP0).

; =============================================================================
; RESET — the program's entry point
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port

; --- make the flag state deterministic ---------------------------------------
; +clean_start does SEI and CLD but does not clear V or C.  The lab's P bytes
; are part of the display, so set them here.  I = 1 from SEI, D = 0 from CLD,
; V = 0 from CLV, C = 0 from CLC: the base P is $24.
    SEI
    CLD
    CLV
    CLC

; --- the lab's known inputs ---------------------------------------------------
; LAX and SAX are read-only on their operand for LAX and write-only for SAX;
; DCP and ISB modify their operand, so RunLab resets those two every frame.
    LDA #$12
    STA LaxMem
    LDA #$00
    STA SaxMem
    LDA #$20
    STA DcpMem
    LDA #$10
    STA IsbMem

; --- the demo state -----------------------------------------------------------
; Screen, MarkerRow, the two timers and PrevSelect are already zero.
    LDA #STARTUP_FRAMES
    STA Startup

; --- the TIA's fixed state ----------------------------------------------------
    LDA #C_BG
    STA COLUBK              ; black page
    LDA #C_TITLE
    STA COLUPF              ; gold until the first zone sets its own colour
    LDA #C_MARK
    STA COLUP0              ; the marker
    LDA #$01
    STA CTRLPF              ; reflect the playfield: the panel is symmetric
    LDA #$00
    STA NUSIZ0              ; one copy of P0
    STA GRP0
    STA PF0
    STA PF1
    STA PF2

    JMP StartFrame

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK              ; blank the picture
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; 1. THE FRAME COUNTER
; -----------------------------------------------------------------------------
    INC FrameCount
    LDA FrameCount
Frame:                      ; checkpoint: A = the new frame count

; -----------------------------------------------------------------------------
; 2. SELECT — toggle the screen on the 0 -> 1 edge
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  EOR turns that into a 1; the
; EOR/AND pair keeps only a new press, so holding the switch toggles once.
; The first eight frames are not trusted: the console's switches can read low
; while it settles, so Startup forces the edge clear until it reaches zero.
    LDA Startup
    BEQ SelectReady
    DEC Startup
    LDA #$00
    STA SelectNow
    JMP SelectEdgeDone
SelectReady:
    LDA SWCHB
    AND #$02
    EOR #$02                ; 1 = pressed
    STA SelectNow
    EOR PrevSelect
    AND SelectNow
    BEQ SelectEdgeDone
    LDA ScreenNum
    EOR #$01                ; 0 -> 1 = the cycle table, 1 -> 0 = the lab
    STA ScreenNum
    LDA #$00
    STA ScreenTimer         ; restart the 240-frame clock
SelectEdgeDone:
    LDA SelectNow
    STA PrevSelect

; -----------------------------------------------------------------------------
; 3. THE AUTO-DEMO CLOCKS
; -----------------------------------------------------------------------------
; The marker walks the four rows every 60 frames; the screen toggles every
; 240 frames.  Both counters run in VBLANK, so a long frame cannot drift them.
    INC MarkerTimer
    LDA MarkerTimer
    CMP #MARKER_FRAMES
    BCC NoMarkerStep
    LDA #$00
    STA MarkerTimer
    INC MarkerRow
    LDA MarkerRow
    AND #$03
    STA MarkerRow
NoMarkerStep:
    INC ScreenTimer
    LDA ScreenTimer
    CMP #SCREEN_FRAMES
    BCC NoScreenStep
    LDA #$00
    STA ScreenTimer
    LDA ScreenNum
    EOR #$01
    STA ScreenNum
NoScreenStep:
    LDA ScreenNum
Screen:                     ; checkpoint: A = 0 (lab) or 1 (cycle table)

; -----------------------------------------------------------------------------
; 4. THE FOUR OPERATIONS — once per frame on the known inputs
; -----------------------------------------------------------------------------
    JSR RunLab

; -----------------------------------------------------------------------------
; 5. THE DISPLAY BYTES — flags to PF fields, results to bar thresholds
; -----------------------------------------------------------------------------
    JSR BuildDisplay

; -----------------------------------------------------------------------------
; 6. THE MARKER'S POSITION — one divide-by-15 dance and one HMOVE
; -----------------------------------------------------------------------------
    LDA #(MARKER_X + POS_BIAS)
    JSR SetCoarseP0         ; sets HMP0 and strobes RESP0
    STA WSYNC
    STA HMOVE               ; the frame's only HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; THE VISIBLE KERNEL — 192 lines
; =============================================================================

; -----------------------------------------------------------------------------
; Zone 1: 16 title lines — the gold frame and the 4-chunk "LAB"
; -----------------------------------------------------------------------------
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDA #C_TITLE
    STA COLUPF
    LDY #0
TitleRow:
    LDA TitlePF0,Y
    STA PF0
    LDA TitlePF1,Y
    STA PF1
    LDA TitlePF2,Y
    STA PF2
    STA WSYNC
    INY
    CPY #TITLE_LINES
    BNE TitleRow

; -----------------------------------------------------------------------------
; Zone 2: 32 byte/cycle label lines — four 8-line strips, unrolled
; -----------------------------------------------------------------------------
; Line 0 of a strip is the opcode byte as eight chunks, bit 7 first, at
; chunks 2-9.  Line 1 is the illegal cycle count as a PF2 bar; line 2 is the
; documented count as a white bar.  Both bars are right-aligned at chunk 19,
; so a longer bar starts further left and the lengths compare.
    +LABEL_STRIP 0
    +LABEL_STRIP 1
    +LABEL_STRIP 2
    +LABEL_STRIP 3

; -----------------------------------------------------------------------------
; Zone 3: 128 middle lines — branch on the screen
; -----------------------------------------------------------------------------
    LDA ScreenNum
    BNE CycleTable
; --- the one-line setup gap: blank the current line and seed row 0 -----------
; This line absorbs the screen branch.  It also loads row 0's colour, bar
; threshold and PF2, so the first row's first line starts with its PF0/PF1
; writes (cycle 7/14) instead of a 13-cycle row-setup tail.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDX #0
    LDA OpColor,X
    STA COLUPF
    LDA BarStart,X
    STA BarCur
    STA WSYNC
    LDY #0

; --- Screen 0: four 32-line result rows --------------------------------------
; Every line writes PF0/PF1 first (cycle 7/14), then the PF2 bar (cycle 26),
; then preloads the NEXT line's marker into GRP0 (cycle 40).  The marker is
; latched at the player's pixels, not at the start of the line, so the preload
; keeps the diamond intact.  The next row's colour/PF2/BarCur are preloaded on
; the current row's last line after the playfield is drawn; the last row
; preloads the footer's white colour.  This is the fix for the old row setup,
; which wrote PF0 at cycle 24-31 and PF1 at 31-38 and left the first line of
; rows 2-4 showing the previous row's P bytes.
ResultLine:
    LDA RowF0,X             ; PF0 by cycle 7
    STA PF0
    LDA RowF1,X             ; PF1 by cycle 14
    STA PF1
    LDA #$00
    CPY BarCur
    BCC NoBar
    LDA #$03                ; PF2 bits 0-1 = chunks 12-13
NoBar:
    STA PF2                 ; PF2 by cycle 24-26
    CPY #(ROW_LINES - 1)
    BEQ RowEnd
; --- the P0 marker: preload the NEXT line's diamond --------------------------
    LDA #$00
    CPX MarkerRow
    BNE NoMarkerPre
    LDA MarkerStrip+1,Y     ; MarkerStrip+1,Y is line Y+1
NoMarkerPre:
    STA GRP0
    JMP LineDone
RowEnd:
; --- preload the next row's setup, or the footer's colour --------------------
; These writes happen after the current line's playfield is drawn (cycle 42),
; so they affect only the next line.
    CPX #(ROW_COUNT - 1)
    BEQ RowFooter
    LDA NextRowTab,X
    TAX
    LDA OpColor,X
    STA COLUPF
    LDA #$00
    STA PF2
    LDA BarStart,X
    STA BarCur
    JMP LineDone
RowFooter:
    STA WSYNC
    JMP Footer
LineDone:
    STA WSYNC
    INY
    CPY #ROW_LINES
    BNE ResultLine
    LDY #0
    JMP ResultLine           ; X is already the next row

; --- Screen 1: eight 16-line cycle-table bands --------------------------------
; A band: a separator line, a blank line, a two-line white documented bar, a
; blank line, a two-line illegal bar, and nine blank lines.  The bars start at
; chunk 2; PF0 = $C0 covers chunks 2-3, PF1 carries the rest.
CycleTable:
; --- the same one-line setup gap for the cycle table ------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
    LDX #0
BandLoop:
; --- separator line -----------------------------------------------------------
    LDA BandColor,X
    STA COLUPF
    LDA #$C0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    STA WSYNC
; --- blank line ---------------------------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
; --- documented bar, two lines, white ----------------------------------------
    LDA #C_WHITE
    STA COLUPF
    LDA #$C0
    STA PF0
    LDA BandDocPF1,X
    STA PF1
    LDA #$00
    STA PF2
    STA WSYNC
    STA WSYNC
; --- blank line ---------------------------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
; --- illegal bar, two lines, the band's colour -------------------------------
    LDA BandColor,X
    STA COLUPF
    LDA #$C0
    STA PF0
    LDA BandIllPF1,X
    STA PF1
    LDA #$00
    STA PF2
    STA WSYNC
    STA WSYNC
; --- advance to the next band before the blank lines -------------------------
; The index update used to sit after the nine blank lines; its INX/CPX/BNE
; tail pushed the next separator's PF1 write to cycle 28, the chunk-4
; boundary.  Updating X before the blanks leaves only the blank loop's last
; DEY/BNE plus the loop test (9 cycles), so the separator's PF1 is written at
; cycle 26.  The blank lines are unaffected: their PF bytes are 0.
    INX
; --- nine blank lines ---------------------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #9
BandBlank:
    STA WSYNC
    DEY
    BNE BandBlank
    CPX #BAND_COUNT
    BNE BandLoop
    JMP Footer

; -----------------------------------------------------------------------------
; Zone 4: 15 footer lines — the rule, the checksum and the screen indicator
; -----------------------------------------------------------------------------
; The last result row reaches this label with its own STA WSYNC, so the rule
; line starts at cycle 3; the screen-1 band loop reaches it at cycle 10.  Both
; are early enough for the rule's colour/PF0/PF1/PF2 writes (cycles 13-28) to
; beat the left half, so the rule needs no setup gap and starts at chunk 0.
Footer:
    LDA #C_WHITE
    STA COLUPF
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    LDA #$00
    STA GRP0
    STA WSYNC
; --- six blank lines --------------------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #6
FooterBlank:
    STA WSYNC
    DEY
    BNE FooterBlank
; --- eight lines: the checksum bits and the screen indicator ------------------
; The checksum is shown at chunks 6-13, bit 7 first.  Screen 0 puts a two-chunk
; indicator at chunks 1-2 (PF0); screen 1 puts it at chunks 17-18 (PF2).
    LDX ScreenNum
    LDA ScreenPF0Tab,X
    STA PF0
    LDA ChecksumPF1
    STA PF1
    LDA ChecksumPF2
    ORA ScreenPF2Tab,X
    STA PF2
    LDY #8
FooterBits:
    STA WSYNC
    DEY
    BNE FooterBits
    NOP                     ; the frame checkpoint reports 229/6, not 229/4

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; RunLab — the four undocumented operations on known inputs
; =============================================================================
; The operations run once per frame.  DCP and ISB modify their operands, so
; both are reset before every run; SAX overwrites its destination every time.
; The flags are saved as the live P: PHP pushes a copy with B set, and the
; AND #$EF clears that marker so the stored byte is the register's value.
RunLab:
; --- reset the operands that the operations change ---------------------------
    LDA #$20
    STA DcpMem
    LDA #$10
    STA IsbMem

; --- LAX: A = X = M ----------------------------------------------------------
; LAX defines N and Z only.  CLC makes the carry deterministic, so the C
; column in the LAX row cannot inherit a carry from the previous frame's ISB
; (or from the screen timer's arithmetic).
    CLC
    +LAX_ZP LaxMem           ; ACME emits $A7 $90
LaxRead:                     ; checkpoint: A = $12, X = $12
    STA ResultBytes+0        ; the LAX result
    STA ResultA
    STX ResultX
    +SAVE_P FlagBytes+0      ; A stays $12 for the SAX
; --- SAX: M = A AND X --------------------------------------------------------
; A is still $12 from LAX; set X to $34.  SAX changes no flags; CLC keeps the
; captured C at 0, the same value the LAX row shows.
    CLC
    LDX #$34
    +SAX_ZP SaxMem           ; ACME emits $87 $91
SaxRead:                     ; checkpoint: A = $12 (unchanged)
    LDA SaxMem
    STA ResultBytes+1
    +SAVE_P FlagBytes+1      ; A stays $10
SaxM:                        ; checkpoint: A = $10

; --- DCP: M = M-1, then CMP A,M ---------------------------------------------
; Set A to the value the decremented memory will hold, so the compare reports
; equality: M = $20-1 = $1F, A = $1F, Z = 1 and C = 1.
    LDA #$1F
    +DCP_ZP DcpMem           ; ACME emits $C7 $92
DcpRead:                     ; checkpoint: A = $1F, P has Z=1 and C=1
    +SAVE_P FlagBytes+2
    LDA DcpMem
    STA ResultBytes+2
DcpM:                        ; checkpoint: A = $1F, C = 1

; --- ISB: M = M+1, then SBC A,M ---------------------------------------------
; Secure the carry first: the SBC then computes A - M - 0.  With A = $20 and
; M = $11 the result is $0F and the carry stays set (no borrow).
    LDA #$20
    SEC
    +ISB_ZP IsbMem           ; ACME emits $E7 $93
IsbRead:                     ; checkpoint: A = $0F
FlagsRead:                   ; checkpoint: P after ISB (C=1, Z=0)
    +SAVE_P FlagBytes+3
    LDA FlagBytes+3
    STA Flags                ; $83 = the live P after ISB
    LDA IsbMem
    STA ResultBytes+3
    STA ResultM
IsbM:                        ; checkpoint: A = $11

; --- the XOR checksum of the four result bytes ------------------------------
    LDA ResultBytes+0
    EOR ResultBytes+1
    EOR ResultBytes+2
    EOR ResultBytes+3
Checksum:                    ; checkpoint: A = $0C
    STA ChecksumVal
    RTS

; =============================================================================
; BuildDisplay — turn the runtime bytes into playfield bytes
; =============================================================================
; The flag columns are PF0 chunks 0-3 (N V 1 B) and PF1 chunks 4-7 (D I Z C).
; The high nibble is reversed because PF0's bit 4 is the leftmost chunk; the
; low nibble shifts straight up because PF1's bit 7 is chunk 4.
BuildDisplay:
    LDX #0
FlagToPF:
    LDA FlagBytes,X
    STA Tmp
    LSR
    LSR
    LSR
    LSR                     ; the high nibble (N V 1 B)
    TAY
    LDA Rev4,Y
    ASL
    ASL
    ASL
    ASL                     ; move it to PF0's high four bits
    STA RowF0,X
    LDA Tmp
    AND #$0F
    ASL
    ASL
    ASL
    ASL                     ; the low nibble (D I Z C) to PF1's high bits
    STA RowF1,X
    INX
    CPX #ROW_COUNT
    BNE FlagToPF

; --- BarStart = 32 - result ---------------------------------------------------
    LDX #0
BarStarts:
    LDA #32
    SEC
    SBC ResultBytes,X
    STA BarStart,X
    INX
    CPX #ROW_COUNT
    BNE BarStarts

; --- the footer's checksum bytes ---------------------------------------------
; The checksum's bit 7 goes to chunk 6 and bit 0 to chunk 13.  PF1 carries
; bits 7-2 (chunks 6-11); PF2 carries bits 1-0, but PF2 bit 0 is chunk 12 and
; bit 1 is chunk 13, so the two bits are reversed with the Rev2 table.
    LDA ChecksumVal
    STA Tmp
    LSR
    LSR
    AND #$3F
    STA ChecksumPF1
    LDA Tmp
    AND #$03
    TAY
    LDA Rev2,Y
    STA ChecksumPF2
    RTS

; =============================================================================
; SetCoarseP0 — the Lesson 26 divide-by-15 positioning dance
; =============================================================================
; A = the desired left edge + POS_BIAS.  Each loop pass is 5 cycles = 15
; colour clocks, which is why dividing by 15 works.  The remainder becomes
; HMP0's fine value and RESP0 strobes the coarse position.
SetCoarseP0:
    STA WSYNC
    SEC
DivP0:
    SBC #15
    BCS DivP0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    RTS

; =============================================================================
; THE DATA
; =============================================================================
    !if * > $F800 {
        !error "the code must end before $F800"
    }
    !fill $F800 - *, $EA

; --- the 16-line title block: a gold frame and "LAB" --------------------------
; 20 chunks per line, reflected by CTRLPF.  The three 4-chunk glyphs sit at
; chunks 2-5, 7-10 and 12-15; the frame is chunk 0, chunk 19, and rows 0/15.
TitlePF0:
    !byte $F0, $10, $50, $50, $50, $50, $50, $50
    !byte $D0, $10, $10, $10, $10, $10, $10, $F0
TitlePF1:
    !byte $FF, $00, $0C, $12, $12, $1E, $12, $12
    !byte $D2, $00, $00, $00, $00, $00, $00, $FF
TitlePF2:
    !byte $FF, $80, $87, $89, $89, $87, $89, $89
    !byte $87, $80, $80, $80, $80, $80, $80, $FF

; --- the four opcode bytes as eight chunks, bit 7 first ----------------------
; LAX $A7 = 1010 0111, SAX $87 = 1000 0111, DCP $C7 = 1100 0111,
; ISB $E7 = 1110 0111.  The byte sits at chunks 2-9: PF0 bits 6-7 are bits
; 7-6, and PF1 bits 7-2 are bits 5-0.
OpBytePF0:
    !byte $40, $40, $C0, $C0
OpBytePF1:
    !byte $9C, $1C, $1C, $9C

; --- the illegal cycle bar, right-aligned at chunk 19 ------------------------
; 3 chunks = 17-19 (PF2 $E0); 5 chunks = 15-19 (PF2 $F8).
OpIllegalPF2:
    !byte $E0, $E0, $F8, $F8

; --- the documented cycle bar, right-aligned at chunk 19 ---------------------
; LAX 5 = 15-19 (PF2 $F8).  SAX 9 = 11-19 (PF1 bit 0 + PF2 $FF).
; DCP/ISB 8 = 12-19 (PF2 $FF).
OpDocPF1:
    !byte $00, $01, $00, $00
OpDocPF2:
    !byte $F8, $FF, $FF, $FF

; --- the row colours ----------------------------------------------------------
OpColor:
    !byte C_LAX, C_SAX, C_DCP, C_ISB

; --- the 33-byte marker strip ------------------------------------------------
; One GRP0 byte per line inside a row: 20 zeros, the 8x8 diamond, 5 zeros.
; The extra zero at index 32 makes MarkerStrip+1,Y read a clean zero when
; Y = 31 (the preload for the next line).
MarkerStrip:
    !fill MARKER_TOP, $00
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !fill ROW_LINES - MARKER_TOP - 8 + 1, $00

; --- the row after X, wrapping 3 -> 0 ----------------------------------------
NextRowTab:
    !byte 1, 2, 3, 0

; --- the cycle-table bands ----------------------------------------------------
; The first four are the lab's four operations; the last four are documented
; examples of the same combined-operation pattern.
BandColor:
    !byte C_LAX, C_SAX, C_DCP, C_ISB, C_GRAY, C_GRAY, C_GRAY, C_GRAY
; Documented bars, two lines each at chunks 2..2+cycles-1 (PF0=$C0, PF1 below):
; 5 -> $E0, 9 -> $FE, 8 -> $FC.
BandDocPF1:
    !byte $E0, $FE, $FC, $FC, $FC, $FC, $FC, $FC
; Illegal bars: 3 -> $80, 5 -> $E0.
BandIllPF1:
    !byte $80, $80, $E0, $E0, $E0, $E0, $E0, $E0

; --- the footer's screen indicator -------------------------------------------
; Screen 0: chunks 1-2 in PF0 ($60).  Screen 1: chunks 17-18 in PF2 ($60).
ScreenPF0Tab:
    !byte $60, $00
ScreenPF2Tab:
    !byte $00, $60

; --- the 4-bit reversal used by PF0's high nibble -----------------------------
; Rev4[n] reverses n's four bits: bit 3 becomes bit 0.  BuildDisplay uses it
; to place the flag nibble's leftmost bit in PF0's leftmost chunk.
Rev4:
    !byte $0, $8, $4, $C, $2, $A, $6, $E, $1, $9, $5, $D, $3, $B, $7, $F

; --- the 2-bit reversal used by the footer's checksum ------------------------
; Rev2[n] swaps n's two bits: bit 0 -> PF2 bit 1 (chunk 13) and bit 1 ->
; PF2 bit 0 (chunk 12), so the footer still reads bit 7 first.
Rev2:
    !byte $00, $02, $01, $03

; -----------------------------------------------------------------------------
; The vectors
; -----------------------------------------------------------------------------
    !if * > $FFFA {
        !error "the data must end before $FFFA"
    }
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset, Reset, Reset
