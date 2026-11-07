; =============================================================================
; KERNEL_FRAMEWORK.ASM — The zone framework (a kernel as a schedule of bands)
; =============================================================================
; This file turns the four routines in include/kernel_patterns.asm into a
; build-time checked zone framework.  A lesson describes a frame as a list of
; macro calls, one call per display band:
;
;   Layout0:
;       +kf_begin
;       +kf_fill  $02, 15
;       +kf_pf    $1A, 24, PFData
;       +kf_strip $C8, 48, StripData
;       +kf_ramp  77, RampData
;       +kf_end
;       RTS
;
; The macros expand into straight-line code: each one sets the zone up during
; the line on which the previous zone's handler returned, ends that line with
; STA WSYNC, and calls the handler.  There is no runtime zone table and no
; interpreter in the ROM; the schedule is the program text.
;
; -----------------------------------------------------------------------------
; REQUIREMENTS AND SOURCING ORDER
; -----------------------------------------------------------------------------
; Source this file after:
;   1. !cpu 6502
;   2. include/vcs.asm and include/macro.asm
;   3. * = $F000
;   4. include/kernel_patterns.asm
;
; include/kernel_patterns.asm defines the four band routines and the three
; zero-page bytes this file uses ($80-$82).  This file emits no code, sets no
; program counter, and declares no vector: it defines macros only.
;
; The lesson defines its one-byte layout selector `Layout` (at $83 in the
; Lesson 68 map) before it expands +kf_dispatch.  The macro reads that symbol.
;
; -----------------------------------------------------------------------------
; THE API
; -----------------------------------------------------------------------------
;   +kf_begin
;       Reset the assembly-time line budget.  Call once per layout, before
;       the first zone.
;
;   +kf_fill .color, .dataLines
;       A solid background band.  COLUBK = .color on every line.
;       Uses KernelFill (A = colour, X = lines).
;
;   +kf_pf .color, .rows, .table
;       A playfield band.  COLUPF = .color; .table holds .rows records of
;       three bytes (PF0, PF1, PF2, in pixel-deadline order); each record is
;       drawn on two scanlines.  The band is .rows * 2 data lines.
;       Uses KernelPFRows.
;
;   +kf_strip .color, .dataLines, .table
;       A player-0 band.  COLUP0 = .color; .table holds .dataLines bytes,
;       one GRP0 byte per line.  Uses KernelSpriteStrip.
;
;   +kf_ramp .dataLines, .table
;       A background-colour band.  .table holds .dataLines COLUBK bytes;
;       the first colour lands on the first data line.  Uses KernelColorRamp.
;
;   +kf_custom .dataLines, .routine
;       A lesson-supplied band.  The framework sets KernelRows = .dataLines
;       and calls .routine.  The routine must draw exactly .dataLines lines
;       and return.  If it reads KernelPtr, the lesson must set KernelPtr
;       before the macro.  The routine owns its colours and objects: write
;       its first store before pixel 0 and clear what the next zone does not
;       expect.
;
;   +kf_end
;       Assert that the layout's budget is exactly 192 lines.  Each zone
;       costs .dataLines + 1 (one boundary line).  A mismatch is an ACME
;       !error and the build stops.
;
;   +kf_dispatch .l0, .l1, .l2
;       Run one of three layout routines from the one-byte `Layout`:
;       Layout = 0 -> .l0, 1 -> .l1, 2 -> .l2.  This is a branch dispatcher
;       with short JMP trampolines.  It never writes a jump target into ROM:
;       a write to a ROM address is ignored, and a preflight scratch
;       prototype's JMP (vector) then read $FFFF and collapsed its frame.
;
; -----------------------------------------------------------------------------
; THE BUDGET RULE
; -----------------------------------------------------------------------------
; Every zone owns one boundary line plus its data lines:
;
;   zone cost = .dataLines + 1
;
; A layout's costs must sum to 192.  With four zones and 188 data lines, the
; four boundary lines make 192.  The boundary line is not wasted: it is the
; line on which the next zone's colour, pointer and cleared objects are set
; up, and it is part of the visible picture.  The first boundary line is
; BodyStart; the last data line is picture line 191 (scanline 228), and the
; dispatch returns to the overscan on scanline 229.
;
; -----------------------------------------------------------------------------
; THE BOUNDARY CONTRACT
; -----------------------------------------------------------------------------
; A handler returns at cycle 10 (KernelFill) or 13 (the other three) of the
; line after its last data line.  The next zone's macro runs its setup during
; the rest of that line:
;
;   - it clears PF0-PF2, GRP0, GRP1 and ENABL first, then sets the zone's
;     colour and table pointer;
;   - it ends with STA WSYNC, which makes that line the boundary line;
;   - it calls the handler.  The JSR takes 6 cycles, so the handler's first
;     instruction starts 6 cycles into the next line; its first store
;     completes by about cycle 16, before pixel 0 (cycle 22.7).  The first
;     data line is therefore painted from its left edge.
;
; The built-in zones write only their own object.  Each one therefore clears
; PF0-PF2, GRP0, GRP1 and ENABL *first* on its boundary line, before the
; colour and pointer setup.  On a mid-layout boundary the first PF0 store
; completes by cycle 18, before pixel 0 (cycle 22.7), so the previous band's
; playfield bytes and first player copy cannot leak onto the boundary line.
; The first zone's objects are already zero from the VBLANK blanket clear.  The colour store may
; land after pixel 0; that is the boundary line's one-line gutter, and the
; first data line is fully the new band.  The framework writes GRP1 = 0 on
; every boundary line; it never writes ENAM0 or ENAM1, and a custom routine
; that uses the missiles must clear them before it returns.
;
; The FIRST zone's boundary line is BodyStart.  Its background colour must
; already be in the TIA when VBLANK releases the picture, because the
; dispatcher and the setup run after pixel 0.  The lesson sets that first-line
; colour in VBLANK (the "first-line prelude"); the macro re-stores it on the
; boundary line.
;
; The LAST zone in every layout must end black: either +kf_fill 0, N or a
; +kf_ramp whose last byte is 0.  The dispatch/return chain reaches
; OverscanStart at scanline 229 cycle 19 instead of the usual cycle 6, and the
; VBLANK store completes at about cycle 24.  The first visible clocks of the
; overscan line would otherwise show the last kernel colour.  Black makes the
; 13-cycle tax invisible.
;
; -----------------------------------------------------------------------------
; CYCLE COSTS
; -----------------------------------------------------------------------------
; The handlers are the kernel_patterns.asm routines (their own ledgers):
;   KernelFill         11 cycles per line (10 on the last line)
;   KernelPFRows       57 cycles per row = 28.5 per line
;   KernelSpriteStrip  19 cycles per line (18 on the last line)
;   KernelColorRamp    19 cycles per line (18 on the last line)
;
; The JSR into a handler adds 6 cycles to its first line.  The boundary setup
; costs roughly 30-45 cycles depending on the zone.  Every line stays well
; inside the 76-cycle budget.  The busiest band is a playfield row: 57 cycles
; for the two-line row (28.5 per line), so it uses 57 of the row's 152 cycles
; and has 95 left.
;
; -----------------------------------------------------------------------------
; RAM
; -----------------------------------------------------------------------------
; The framework owns no RAM of its own.  It uses the pattern library's three
; zero-page bytes:
;
;   $80-$81  KernelPtr    the current band's table pointer
;   $82      KernelRows   the current band's row or line count
;
; Lesson variables must start at $83.  A lesson variable at $80-$82 clobbers
; the pointer or the count; a preflight scratch prototype (not this ROM)
; collapsed when Layout and Frame were placed at $80/$81.
;
; -----------------------------------------------------------------------------
; THE BUILD-TIME CHECK
; -----------------------------------------------------------------------------
; KF_TOTAL is an assembly-time counter.  +kf_begin sets it to 0; every zone
; adds .dataLines + 1; +kf_end compares it with 192.  A 191-line layout stops
; the build:
;
;   !error: kf_end: zone budget is 191, expected 192 ...
;
; and a 193-line layout stops it the same way.  The check runs once per
; layout, so a missing or extra line cannot reach the ROM unnoticed.
; =============================================================================

; -----------------------------------------------------------------------------
; THE BUDGET COUNTER
; -----------------------------------------------------------------------------
; +kf_begin defines and resets it; the zone macros add to it; +kf_end checks
; it.  It is an assembly-time symbol, so it costs no RAM and no cycles.  (Use
; !set, not =: ACME treats a second = as a duplicate symbol, while !set is
; defined to be updated.)
; KF_TOTAL is created by the first +kf_begin.

; =============================================================================
; +kf_begin — reset the line budget
; =============================================================================
; Call once at the start of every layout.  The symbol is redefined with !set,
; which is what lets a second layout start a second count.
!macro kf_begin {
    !set KF_TOTAL = 0
}

; =============================================================================
; +kf_fill .color, .dataLines — a solid background band
; =============================================================================
!macro kf_fill .color, .dataLines {
    !set KF_TOTAL = KF_TOTAL + .dataLines + 1

    ; Clear first.  On a mid-layout boundary line the first PF0 store begins
    ; at cycle 13 and completes by cycle 18, before pixel 0 (cycle 22.7), so
    ; the previous band's playfield bytes and first player copy cannot leak
    ; onto the boundary line.
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL

    ; Then the zone's colour.  On a mid-layout boundary the background may
    ; change after pixel 0; that is the boundary line's gutter, and the first
    ; data line is fully the new colour.
    LDA #.color
    STA COLUBK

    ; The handler wants A = colour, X = lines.
    LDX #.dataLines
    LDA #.color
    STA WSYNC               ; the boundary line ends here
    JSR KernelFill          ; first data line starts at cycle 6
}

; =============================================================================
; +kf_pf .color, .rows, .table — a playfield band, two lines per row
; =============================================================================
!macro kf_pf .color, .rows, .table {
    !set KF_TOTAL = KF_TOTAL + (.rows * 2) + 1

    ; Clear first: the first PF0 store completes before pixel 0, so the
    ; previous playfield row does not leak onto the boundary line.
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL

    LDA #.color
    STA COLUPF

    LDA #<.table
    STA KernelPtr
    LDA #>.table
    STA KernelPtr+1
    LDA #.rows
    STA KernelRows

    STA WSYNC               ; the boundary line ends here
    JSR KernelPFRows        ; first row's first line starts at cycle 6
}

; =============================================================================
; +kf_strip .color, .dataLines, .table — one byte per line for GRP0
; =============================================================================
!macro kf_strip .color, .dataLines, .table {
    !set KF_TOTAL = KF_TOTAL + .dataLines + 1

    ; Clear first: the playfield and the first player copy are zero before
    ; the boundary line's visible area begins.
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL

    LDA #.color
    STA COLUP0

    LDA #<.table
    STA KernelPtr
    LDA #>.table
    STA KernelPtr+1
    LDA #.dataLines
    STA KernelRows

    STA WSYNC               ; the boundary line ends here
    JSR KernelSpriteStrip   ; first data line starts at cycle 6
}

; =============================================================================
; +kf_ramp .dataLines, .table — one background colour per line
; =============================================================================
!macro kf_ramp .dataLines, .table {
    !set KF_TOTAL = KF_TOTAL + .dataLines + 1

    ; Clear the playfield and player objects first.  The background remains
    ; the previous band's colour on this boundary line; the first data line
    ; writes the ramp's first colour.  That one-line gutter is the ramp's
    ; contract.
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL

    LDA #<.table
    STA KernelPtr
    LDA #>.table
    STA KernelPtr+1
    LDA #.dataLines
    STA KernelRows

    STA WSYNC               ; the boundary line ends here
    JSR KernelColorRamp     ; first data line starts at cycle 6
}

; =============================================================================
; +kf_custom .dataLines, .routine — a lesson-supplied band
; =============================================================================
; The framework only sets KernelRows and calls the routine.  The routine must
; draw .dataLines lines and return; it owns its colours and objects.  If it
; reads KernelPtr, the lesson sets the pointer before this macro.
!macro kf_custom .dataLines, .routine {
    !set KF_TOTAL = KF_TOTAL + .dataLines + 1

    LDA #.dataLines
    STA KernelRows
    STA WSYNC               ; the boundary line ends here
    JSR .routine            ; first data line starts at cycle 6
}

; =============================================================================
; +kf_end — the build-time 192-line assertion
; =============================================================================
!macro kf_end {
    !if KF_TOTAL != 192 {
        !error "kf_end: zone budget is ", KF_TOTAL, ", expected 192 (data lines + one boundary line per zone)"
    }
}

; =============================================================================
; +kf_dispatch .l0, .l1, .l2 — the runtime layout selector
; =============================================================================
; A branch dispatcher, not a self-modified jump vector.  Layout 0 is the
; fast path (8 cycles); layout 1 is 14 and layout 2 is 18.  Layouts 1 and 2
; branch to short local trampolines because the dispatch point is more than
; 127 bytes from Layout1 and Layout2, which is beyond a BEQ's range.  An
; out-of-range Layout value falls back to layout 0.
!macro kf_dispatch .l0, .l1, .l2 {
    LDA Layout
    BNE .not0               ; 2 cycles when Layout is 0
    JMP .l0
.not0:
    CMP #1
    BEQ .do1
    CMP #2
    BEQ .do2
    JMP .l0                 ; defensive: an unknown value runs layout 0
.do1:
    JMP .l1
.do2:
    JMP .l2
}
