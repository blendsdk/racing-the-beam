; =============================================================================
; KERNEL_PATTERNS.ASM — Four reusable kernel building blocks
; =============================================================================
;
; This library packages the four kernel shapes the course builds in Part 7:
; a solid fill, a two-line playfield, a one-line sprite strip, and a per-line
; colour ramp.  Each routine draws one band of scanlines and returns.  A
; lesson decides where the bands go by calling the routines in order.
;
; Source this file AFTER include/vcs.asm and AFTER the `* = $F000` line: the
; routines use the TIA register names (COLUBK, PF0-PF2, GRP0, WSYNC) that
; vcs.asm defines, and they emit code at the current program counter.  This
; file never sets the program counter, the CPU, or a vector, so it adds only
; the routines and the three zero-page bytes below.
;
; -----------------------------------------------------------------------------
; THE API
; -----------------------------------------------------------------------------
;   KernelFill          A = colour, X = lines (X > 0).
;                       Writes COLUBK on every line, then WSYNC.  11 cycles per
;                       line in steady state (10 on the last line).  Clobbers
;                       X; preserves A and Y (STA does not change A).
;
;   KernelPFRows        KernelPtr -> a table of 3 bytes per row
;                       (byte 0 = PF0, byte 1 = PF1, byte 2 = PF2);
;                       KernelRows = the number of rows (>= 1).
;                       Draws TWO scanlines per row, so the band is
;                       KernelRows x 2 lines.  Advances KernelPtr by
;                       3 x KernelRows, so reload it before reusing the table.
;                       The bytes are stored in
;                       pixel-deadline order: PF0 first (its field starts at
;                       pixel 0), then PF1 (chunk 4, pixel 16), then PF2
;                       (chunk 12, pixel 48).  Clobbers A and Y; preserves X.
;
;   KernelSpriteStrip   KernelPtr -> one byte per line for GRP0;
;                       KernelRows = the number of lines (>= 1).
;                       Draws one scanline per byte.  Clobbers A and Y;
;                       preserves X.
;
;   KernelColorRamp     KernelPtr -> one colour byte per line for COLUBK;
;                       KernelRows = the number of lines (>= 1).
;                       Draws one scanline per byte.  Clobbers A and Y;
;                       preserves X.
;
; Every routine resumes at the start of the line after its last WSYNC and
; returns 10 cycles (KernelFill) or 13 cycles (the other three) into that
; line.  The caller therefore owns the next band's first line: it must set
; the next band's colours and clear the objects the next routine does not
; write.  That is the band-boundary contract.
;
; -----------------------------------------------------------------------------
; THE BAND-BOUNDARY CONTRACT
; -----------------------------------------------------------------------------
; The routines write ONLY their own object:
;
;   KernelFill          COLUBK
;   KernelPFRows        PF0, PF1, PF2
;   KernelSpriteStrip   GRP0
;   KernelColorRamp     COLUBK
;
; A band boundary must leave the TIA holding what the next routine expects:
; clear PF0/PF1/PF2 before KernelSpriteStrip, clear GRP0/GRP1 before
; KernelFill/KernelPFRows/KernelColorRamp, and set the new band's colours.
; The boundary runs on the first line of the new band, between the previous
; routine's return (cycle 10 after KernelFill, cycle 13 after the other three)
; and the new routine's first WSYNC.  A store that must affect the leftmost
; pixel (PF0, COLUBK, COLUPF) has to complete before cycle 22.7; either store
; it first or give the band a blank first row.
;
; The routines keep no hidden state: KernelPtr and KernelRows are the only
; inputs, and the caller sets them before each call.  That is what lets a
; lesson move a band, resize it, or reorder the bands without rewriting the
; kernels.
;
; -----------------------------------------------------------------------------
; RAM
; -----------------------------------------------------------------------------
; The library owns three zero-page bytes.  `+clean_start` zeroes them.
;
;   $80-$81  KernelPtr    a 16-bit pointer to the band's table
;   $82      KernelRows   the band's row count (KernelPFRows) or line count
;                         (KernelSpriteStrip, KernelColorRamp)
;
; $83 is deliberately left free: the lesson's counters start there.
;
; -----------------------------------------------------------------------------
; CYCLE LEDGERS
; -----------------------------------------------------------------------------
; KernelFill, one line:
;   STA COLUBK   3
;   STA WSYNC    3
;   DEX          2
;   BNE (taken)  3
;   -----------------
;   total       11   (10 on the last line: BNE not taken)
;
; KernelPFRows, one row (two lines), steady state:
;   LDY #0                    2
;   LDA (KernelPtr),Y + STA PF0   5 + 3
;   INY                       2
;   LDA (KernelPtr),Y + STA PF1   5 + 3
;   INY                       2
;   LDA (KernelPtr),Y + STA PF2   5 + 3
;   CLC + LDA KernelPtr + ADC #3 + STA KernelPtr   2 + 3 + 2 + 3
;   BCC (no carry)            3
;   STA WSYNC + STA WSYNC     3 + 3
;   DEC KernelRows            5
;   BNE (taken)               3
;   -----------------
;   total                    57 per row = 28.5 per line
; The two lines' budget is 152, so the row leaves 95 cycles (47.5 per line).
; The last row's BNE is not taken (56 cycles).  If the pointer's low byte
; carries, BCC costs 2 instead of 3 and INC KernelPtr+1 costs 5, a net +4
; (61 cycles, 30.5 per line).  A page-aligned table whose row-start low byte
; never exceeds $FC has no carry and no (KernelPtr),Y page cross; the
; lesson's table is page-aligned.
;
; KernelSpriteStrip, one line:
;   LDA (KernelPtr),Y   5
;   STA GRP0            3
;   STA WSYNC           3
;   INY                 2
;   CPY KernelRows      3   (zero page; CPY #imm would be 2)
;   BNE (taken)         3
;   -----------------
;   total              19   (18 on the last line)
;
; KernelColorRamp, one line:
;   the same shape with STA COLUBK instead of STA GRP0
;   -----------------
;   total              19   (18 on the last line)
;
; A (KernelPtr),Y load whose base + Y crosses a page takes 6 cycles instead of
; 5, adding one cycle to the sprite/ramp line (20) or one to the PF row (58).
; The lesson's strip, ramp, and PF tables are page-aligned or short enough
; that the index never crosses.
; =============================================================================

; -----------------------------------------------------------------------------
; ZERO-PAGE CONTROL BYTES
; -----------------------------------------------------------------------------
KernelPtr   = $80       ; 16-bit pointer to the band's table (low, high)
KernelRows  = $82       ; the band's row or line count
; $83 is free for the lesson.

; =============================================================================
; KernelFill — A = colour, X = lines (X > 0)
; =============================================================================
; The colour is re-stored every line, so the routine needs no separate setup
; and the caller can change COLUBK without touching the loop.  The store is
; the first instruction of the line, so it completes well before pixel 0.
KernelFill:
KernelFillLine:
    STA COLUBK              ; the whole line shows this colour
    STA WSYNC               ; finish the line; resume at the next one
    DEX                     ; one line down
    BNE KernelFillLine
    RTS

; =============================================================================
; KernelPFRows — 3 bytes per row, 2 scanlines per row
; =============================================================================
; KernelPtr points at the row table and KernelRows holds the row count.  Y is
; only 0..2: it selects the three playfield bytes of the current row.  The
; outer loop is the KernelRows down-counter (DEC/BNE), not Y.
;
; The three stores are in pixel-deadline order: PF0's field starts at pixel 0,
; PF1's at pixel 16 (chunk 4), PF2's at pixel 48 (chunk 12).  A row is written
; once and displayed on both scanlines of the pair, because no other playfield
; write happens between the two WSYNCs.
KernelPFRows:
KernelPFRow:
    LDY #0                  ; byte 0 of this row
    LDA (KernelPtr),Y
    STA PF0                 ; chunks 0-3: the earliest field
    INY
    LDA (KernelPtr),Y
    STA PF1                 ; chunks 4-11
    INY
    LDA (KernelPtr),Y
    STA PF2                 ; chunks 12-19
    CLC                     ; advance the pointer by three bytes
    LDA KernelPtr
    ADC #3
    STA KernelPtr
    BCC KernelPFNoCarry     ; the low byte did not wrap
    INC KernelPtr+1
KernelPFNoCarry:
    STA WSYNC               ; line 1 of the pair
    STA WSYNC               ; line 2 of the pair
    DEC KernelRows          ; the outer loop counts rows, not Y
    BNE KernelPFRow
    RTS

; =============================================================================
; KernelSpriteStrip — one byte per line for GRP0
; =============================================================================
; KernelPtr points at the strip and KernelRows holds its length in lines.
; The strip may be in ROM or RAM; the routine only reads it.  The loop is the
; course's forward row form: Y starts at 0 and stops when CPY KernelRows
; matches, so row 0 is the top line and row KernelRows-1 the bottom.
KernelSpriteStrip:
    LDY #0
KernelSpriteLine:
    LDA (KernelPtr),Y
    STA GRP0                ; player 0's byte for this line
    STA WSYNC               ; one line per byte
    INY
    CPY KernelRows
    BNE KernelSpriteLine
    RTS

; =============================================================================
; KernelColorRamp — one colour per line for COLUBK
; =============================================================================
; KernelPtr points at the ramp and KernelRows holds its length in lines.  The
; loop is byte-for-byte the sprite strip's, with COLUBK as the destination,
; which is the point of the pattern: the shape of the kernel, not the object,
; is what the library reuses.
KernelColorRamp:
    LDY #0
KernelRampLine:
    LDA (KernelPtr),Y
    STA COLUBK              ; the background colour for this line
    STA WSYNC               ; one line per colour
    INY
    CPY KernelRows
    BNE KernelRampLine
    RTS
