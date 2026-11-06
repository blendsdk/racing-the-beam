; =============================================================================
; LESSON 59: Self-Modifying Code — The Ultimate 6502 Trick — Racing the Beam
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "the code painter": a 4,096-byte cartridge that copies a seven-byte
;   routine into RIOT RAM at $80, patches the routine's immediate operand on
;   every visible line, and calls the patched routine with JSR $80.  The
;   routine writes the patched color to COLUBK and then waits for the next
;   line with STA WSYNC.  The result is a 184-line vertical color gradient:
;   sixteen hue bands with a luminance arc, painted by code that rewrites
;   itself 184 times per frame.
;
; The routine (seven bytes, copied from ROM to $80 before it runs):
;   $80  A9 xx   LDA #color     ; the operand at $81 is patched each line
;   $82  85 09   STA COLUBK     ; $09 is the background-color register
;   $84  85 02   STA WSYNC      ; $02 is the wait-for-next-line strobe
;   $86  60      RTS            ; return to the main loop
;
; Why the routine must live in RAM:
;   A cartridge is ROM.  The 6507 can read it, but a write to a ROM address
;   does nothing: there is no RAM there and no write path.  RIOT RAM at
;   $80-$FF is the only writable memory in the machine, and the 6507 can
;   execute code from it.  So the routine is copied from the ROM template
;   (RoutineTemplate) to $80, and the main loop patches the copy.  The ROM
;   template never changes.
;
; The stack:
;   RIOT RAM is also the stack page.  +clean_start sets SP = $FF; the single
;   JSR $80 pushes the return address at $FF/$FE (SP becomes $FD), and the
;   RTS inside the routine pops it (SP returns to $FF).  The routine itself
;   uses no stack: it only loads, stores, and returns.  The routine and the
;   variables at $87-$8C are far below the stack at $F8-$FF, so the two
;   cannot collide.
;
; The picture (192 visible lines):
;   visible   0-7    the status band, eight lines:
;                      lines 0-3  PatchVal as eight PF1 chunks (bit 7 first)
;                      lines 4-7  Calls as eight PF1 chunks (bit 7 first)
;                    PF1's bit 7 is playfield chunk 4, so the field sits at
;                    chunks 4-11 (TIA X 16-47); CTRLPF=$01 mirrors it on the
;                    right.  The top field is white; the bottom field is gold.
;   visible   8-191  the gradient: 184 lines, one color per line from the
;                    184-entry ColorTable.  The table walks 16 hue bands with
;                    a luminance arc that is dark at both ends and bright in
;                    the middle.  The table is page-aligned and stored twice.
;                    The first window starts at Y = Phase and reads
;                    ColorTable,Y; for a phase above 72 it reaches Y = 255
;                    and covers table[Phase..183] plus the second copy's
;                    table[0..71]; for a lower phase the 184 entries end
;                    inside the first copy.  If Y wraps, the second
;                    window starts at Y = 0 and reads ColorTable+256,Y, which
;                    is the second copy's table[72..]; it finishes the
;                    remaining table[72..Phase-1] entries.  A one-shot
;                    60-frame hold keeps phase 0 for the first capture; after
;                    it expires the phase advances one entry every four
;                    frames.  The hold does not repeat when FrameNum wraps.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5, OverscanStart 229/6.
;   No player or missile is used, so there is no HMOVE in the main demo.
;
; Cycle ledger (one scanline = 76 CPU cycles; measured in Stella):
;   The patched routine is called once per gradient line.  Both windows use
;   the same patch/call body and the same padded tail:
;     RTS 6 + CPY 2 + BNE 3 + LDA ColorTable,Y 4 + STA $81 3 + INY 2 +
;     DEX 2 + BEQ 2 (not taken) + JSR 6 + LDA # 2 = 32 cycles to the STA
;   COLUBK instruction; its write is the third cycle, 34.  The state log
;   confirms 46/32 for the instruction and a write on cycle 34.
;   The table is page-aligned, so neither window's LDA abs,Y crosses a page;
;   the color write is 34 in both windows.
;   The write is 34 CPU cycles = 102 color clocks; the visible field starts
;   at clock 68, and the write applies about three clocks later, so the
;   measured steady strip is 37 pixels (x = 247).
;   One extra CPU cycle is 3 pixels: the first line's longer setup puts its
;   STA COLUBK at 45/35 (write 37) and its strip at 46 pixels (x = 301); the
;   last line's bookkeeping puts it at 228/41 (write 43) and its strip at 64
;   pixels.  The 37 -> 46 -> 64 progression is 0 -> +3 -> +9 cycles, i.e.
;   0 -> +9 -> +27 pixels, exactly the 3-pixel rule.
;   That stair-step left edge is the measured cost of the copy/patch/call
;   pattern, not a bug.  A data-driven kernel that writes COLUBK directly
;   after WSYNC can put the write inside HBLANK, but it does not change its
;   instruction stream.
;   The routine's STA WSYNC is at 46/35; the CPU then waits out the remaining
;   cycles of the 76-cycle line.
;
; Checkpoints (the state log's scanline/cycle, A/X/Y/SP, and P fields):
;   StartFrame   $F033  259/3, the first VSYNC instruction
;   VblankStart  $F041  0/5, the first VBLANK instruction
;   BodyStart    $F08B  37/5, the first visible-line instruction
;   OverscanStart $F0D1 229/6, the first overscan instruction
;   Frame        $F04E  A = 1, 2, 3, ... (the new frame count)
;   PatchByte    $F0AB  A = the new color in the first window
;   PatchByteTail $F0BB A = the new color in the second window
;   CallCount    $F0CC  A = 184 (the number of JSR $80 calls this frame)
;   RamRoutine   $0080  the copied routine; the debugger disassembly is
;                       A9 xx 85 09 85 02 60
;
; RAM map (RIOT, $80-$FF; +clean_start zeroes every byte):
;   $80-$86  the copied routine (LDA #, STA COLUBK, STA WSYNC, RTS)
;   $87      PatchVal  the last color patched into $81
;   $88      Calls     the number of gradient lines drawn this frame (184)
;   $89      FrameNum  frames since reset, wraps at 256
;   $8A      Phase     the table phase, 0-183; +1 every four frames
;   $8B      HoldFrames one-shot 60-frame phase hold
;   $8C      PhaseTimer divides the post-hold frames by four
;   $8D-$9F  free
;   $A0-$D7  free
;   $D8-$F7  free
;   $F8-$FF  stack (the single JSR uses $FF/$FE; SP returns to $FF)
;
; Build: acme -f plain -o build/lesson59.bin \
;        lessons/part8-advanced/59-self-modifying-code/59-self-modifying-code.asm
; Run:   stella build/lesson59.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44          ; 37-line VBLANK (44 ticks)
OVERSCAN_TIMER = 36          ; 30-line overscan (36 ticks)

GRADIENT_LINES = 184         ; visible lines 8-191
STATUS_LINES   = 8           ; visible lines 0-7
SCREEN_LINES   = 192         ; 8 status + 184 gradient

C_BG           = $00         ; black behind the status band
C_STATUS_A     = $0E         ; white: the PatchVal field
C_STATUS_B     = $1A         ; gold: the CallCount field

; =============================================================================
; RAM ALLOCATION ($80-$FF; +clean_start zeroes every byte)
; =============================================================================
; The routine occupies $80-$86.  The equates below are the variables; the
; routine is addressed with the RamRoutine equate so a breakpoint at $0080
; names the copied code, not a ROM label.
RamRoutine   = $80           ; A9 xx 85 09 85 02 60 (seven bytes)
PatchVal     = $87           ; the last color patched into $81
Calls        = $88           ; the number of calls this frame (184)
FrameNum     = $89           ; frames since reset (wraps at 256)
Phase        = $8A           ; the table phase, 0-183
HoldFrames   = $8B           ; one-shot 60-frame hold before the phase moves
PhaseTimer   = $8C           ; divides the post-hold frames by four

; $8D-$9F, $A0-$D7, and $D8-$F7 are free.  The stack lives at $F8-$FF; the
; call depth is one (the main loop's JSR $80), so the stack uses $FF/$FE only.

; A build-time guard: the status and gradient must fill the 192-line picture.
    !if STATUS_LINES + GRADIENT_LINES != SCREEN_LINES {
        !error "the status and the gradient must total 192 visible lines"
    }

; =============================================================================
; RESET — copy the routine, set the TIA, and start the frame loop
; =============================================================================
    * = $F000

Reset:
    +clean_start            ; zero TIA + RAM, set SP = $FF

; The phase hold is one-shot: it must not repeat when FrameNum wraps.
    LDA #60
    STA HoldFrames

; -----------------------------------------------------------------------------
; 1. COPY THE SEVEN-BYTE ROUTINE FROM ROM TO $80
; -----------------------------------------------------------------------------
; This must happen after +clean_start: the macro zeroes all of RAM, including
; $80-$86.  The template is in ROM (RoutineTemplate, below); the loop copies
; indices 6 down to 0.  DEX sets N when X wraps from $00 to $FF, so BPL exits
; after the index-0 byte is copied.
    LDX #6
CopyRoutine:
    LDA RoutineTemplate,X   ; the ROM byte
    STA $80,X               ; the RAM copy: $80-$86
    DEX
    BPL CopyRoutine

; -----------------------------------------------------------------------------
; 2. THE TIA'S FIXED STATE
; -----------------------------------------------------------------------------
    LDA #C_BG
    STA COLUBK              ; a black page until the first gradient line
    LDA #C_STATUS_A
    STA COLUPF              ; the status field is white
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA #$01
    STA CTRLPF              ; reflect the playfield: the fields mirror

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
; The counter is the only per-frame work in VBLANK: the demo has no input and
; no game logic.  Frame: is placed on the NOP so the breakpoint fires once per
; frame (the +wait_timer loop polls INTIM many times, so a label inside it
; would report the timer value, not the frame count).
    INC FrameNum
    LDA FrameNum
Frame:                      ; checkpoint: A = the new frame count
    NOP

; Advance the table phase one entry every four frames, after a one-shot
; 60-frame hold at phase 0.  HoldFrames is a separate byte, not FrameNum:
; FrameNum wraps at 256, and a compare against it would freeze the phase again
; every 256 frames.  The one-shot hold makes the first capture deterministic;
; the first phase step lands four frames after the hold expires.
    LDA HoldFrames
    BEQ PhaseTick
    DEC HoldFrames
    JMP NoPhase
PhaseTick:
    INC PhaseTimer
    LDA PhaseTimer
    AND #$03
    BNE NoPhase
    INC Phase
    LDA Phase
    CMP #GRADIENT_LINES
    BCC NoPhase
    LDA #$00
    STA Phase
NoPhase:

; Load the first status field while the picture is still blanked.  The PF1
; store must not race playfield chunk 4 on visible line 0; doing it here, in
; VBLANK, means the first line starts with its field already set.  The
; +wait_timer macro clobbers A but preserves Y.
    LDA #C_BG
    STA COLUBK
    LDA #C_STATUS_A
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF2
    LDA PatchVal
    STA PF1
    LDY #4

    +wait_timer             ; wait out the 37-line VBLANK
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; THE VISIBLE KERNEL — 192 lines
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    NOP                     ; one-time hit; StatusPatch is the loop target

; -----------------------------------------------------------------------------
; ZONE 1: EIGHT STATUS LINES — the patch byte and the call count
; -----------------------------------------------------------------------------
; Both fields are eight PF1 bits at playfield chunks 4-11.  PF1 bit 7 is the
; leftmost chunk of the field, so the byte reads bit 7 first.  The top four
; lines are white and show PatchVal; the next four are gold and show Calls.
; COLUBK is black behind the status.
StatusPatch:
    STA WSYNC               ; one status line per pass
    DEY
    BNE StatusPatch

    LDA #C_STATUS_B
    STA COLUPF
    LDA Calls
    STA PF1
    LDY #4
StatusCalls:
    STA WSYNC
    DEY
    BNE StatusCalls

; Clear the playfield before the gradient: PF1 still holds the call-count
; field, and an uncleared PF1 would paint eight vertical bars down the whole
; gradient.
    LDA #$00
    STA PF1

; -----------------------------------------------------------------------------
; ZONE 2: 184 GRADIENT LINES — patch the routine, call it, repeat
; -----------------------------------------------------------------------------
; The phase window is split in two because Y is only eight bits.  The first
; window starts at Y = Phase and reads ColorTable,Y; it can reach Y = 255,
; which covers table[Phase..183] and the second copy's table[0..71].  If Y
; wraps, the second window starts at Y = 0 and reads ColorTable+256,Y, which
; is the second copy's table[72..]; it finishes the remaining table[72..Phase-1]
; entries.  X is the line counter, so every frame draws exactly 184 lines.
; The last line skips the normal tail and returns from JSR directly into the
; overscan: that is what puts OverscanStart at 229/6.
    LDY Phase
    LDX #GRADIENT_LINES
FirstWindow:
    LDA ColorTable,Y        ; page-aligned: always a 4-cycle abs,Y load
PatchByte:                  ; checkpoint: A = the new color
    STA $81                 ; patch the LDA #'s immediate operand
    INY
    DEX
    BEQ LastLine
    JSR RamRoutine          ; LDA #color; STA COLUBK; STA WSYNC; RTS
    CPY #0                  ; did the table index wrap past 255?
    BNE FirstWindow
SecondWindow:
    ; Y is already 0 here: the first window's INY wrapped it.  Do not reload
    ; it; the hand-off is then one cycle shorter than a steady tail line.
SecondWindowLoop:
    LDA ColorTable+256,Y    ; second copy, offset 72: table[72..]
PatchByteTail:              ; checkpoint: A = the new color in the tail
    STA $81
    INY
    DEX
    BEQ LastLine
    JSR RamRoutine
    CPY #0                  ; harmless pad: matches the first window's tail
    BNE SecondWindowLoop
LastLine:
    STA PatchVal            ; A = the last color
    LDA #GRADIENT_LINES
CallCount:                  ; checkpoint: A = 184
    STA Calls               ; the frame's call count
    JSR RamRoutine          ; the 184th visible line
; The last routine's STA WSYNC ends visible line 191; its RTS returns here at
; scanline 229, cycle 6.

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229, cycle 6
    LDA #$02
    STA VBLANK              ; blank during overscan
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; THE ROM TEMPLATE — the seven bytes that are copied to $80
; =============================================================================
; The bytes are written with !byte rather than mnemonics so the copy is
; explicit: the operand at $81 is the byte the main loop patches.  The
; assembled bytes are A9 00 85 09 85 02 60.
RoutineTemplate:
    !byte $A9, $00          ; $80  A9 00  LDA #$00 (operand at $81)
    !byte $85, COLUBK       ; $82  85 09  STA COLUBK
    !byte $85, WSYNC        ; $84  85 02  STA WSYNC
    !byte $60               ; $86  60     RTS

; =============================================================================
; THE COLOR TABLE — 184 entries, one per gradient line
; =============================================================================
; hue = (line * 16) / 184: sixteen bands, about 11.5 lines each.
; luminance = 1 + round(6 * |sin(pi * line / 183)|): dark at both ends,
; bright in the middle.  A TIA color byte is CCCCLLL0: the high nibble is the
; hue (0-15), bits 3-1 are the luminance (0-7), and bit 0 is unused.  Every
; entry below is even, as a color byte must be.  The table is page-aligned so
; neither window's LDA abs,Y crosses a page: the first window reads
; $F100-$F1FF, the second reads $F200-$F26E.
    !align 255, 0
ColorTable:
    !byte $02, $02, $02, $02, $02, $04, $04, $04   ; lines   0-  7, hue 0
    !byte $04, $04, $04, $04, $14, $14, $14, $16   ; lines   8- 15, hue 0-1
    !byte $16, $16, $16, $16, $16, $16, $16, $26   ; lines  16- 23, hue 1-2
    !byte $26, $26, $28, $28, $28, $28, $28, $28   ; lines  24- 31, hue 2
    !byte $28, $28, $28, $38, $38, $3A, $3A, $3A   ; lines  32- 39, hue 2-3
    !byte $3A, $3A, $3A, $3A, $3A, $3A, $4A, $4A   ; lines  40- 47, hue 3-4
    !byte $4A, $4A, $4C, $4C, $4C, $4C, $4C, $4C   ; lines  48- 55, hue 4
    !byte $4C, $4C, $5C, $5C, $5C, $5C, $5C, $5C   ; lines  56- 63, hue 4-5
    !byte $5C, $5C, $5C, $5C, $5E, $6E, $6E, $6E   ; lines  64- 71, hue 5-6
    !byte $6E, $6E, $6E, $6E, $6E, $6E, $6E, $6E   ; lines  72- 79, hue 6
    !byte $6E, $7E, $7E, $7E, $7E, $7E, $7E, $7E   ; lines  80- 87, hue 6-7
    !byte $7E, $7E, $7E, $7E, $8E, $8E, $8E, $8E   ; lines  88- 95, hue 7-8
    !byte $8E, $8E, $8E, $8E, $8E, $8E, $8E, $8E   ; lines  96-103, hue 8
    !byte $9E, $9E, $9E, $9E, $9E, $9E, $9E, $9E   ; lines 104-111, hue 9
    !byte $9E, $9E, $9E, $AE, $AC, $AC, $AC, $AC   ; lines 112-119, hue 9-10
    !byte $AC, $AC, $AC, $AC, $AC, $AC, $AC, $BC   ; lines 120-127, hue 10-11
    !byte $BC, $BC, $BC, $BC, $BC, $BC, $BA, $BA   ; lines 128-135, hue 11
    !byte $BA, $BA, $CA, $CA, $CA, $CA, $CA, $CA   ; lines 136-143, hue 11-12
    !byte $CA, $CA, $CA, $C8, $C8, $C8, $D8, $D8   ; lines 144-151, hue 12-13
    !byte $D8, $D8, $D8, $D8, $D8, $D8, $D6, $D6   ; lines 152-159, hue 13
    !byte $D6, $E6, $E6, $E6, $E6, $E6, $E6, $E6   ; lines 160-167, hue 13-14
    !byte $E6, $E4, $E4, $E4, $E4, $F4, $F4, $F4   ; lines 168-175, hue 14-15
    !byte $F4, $F4, $F4, $F2, $F2, $F2, $F2, $F2   ; lines 176-183, hue 15

; --- the second copy: 184 more entries; offset 72 is ColorTable+256 ----------
; The first window uses the first 256 bytes; its wrapped tail uses the second
; copy's first 72 entries.  The second window starts at ColorTable+256, which
; is this copy's table[72], and finishes the window.
ColorTableWrap:
    !byte $02, $02, $02, $02, $02, $04, $04, $04
    !byte $04, $04, $04, $04, $14, $14, $14, $16
    !byte $16, $16, $16, $16, $16, $16, $16, $26
    !byte $26, $26, $28, $28, $28, $28, $28, $28
    !byte $28, $28, $28, $38, $38, $3A, $3A, $3A
    !byte $3A, $3A, $3A, $3A, $3A, $3A, $4A, $4A
    !byte $4A, $4A, $4C, $4C, $4C, $4C, $4C, $4C
    !byte $4C, $4C, $5C, $5C, $5C, $5C, $5C, $5C
    !byte $5C, $5C, $5C, $5C, $5E, $6E, $6E, $6E
    !byte $6E, $6E, $6E, $6E, $6E, $6E, $6E, $6E
    !byte $6E, $7E, $7E, $7E, $7E, $7E, $7E, $7E
    !byte $7E, $7E, $7E, $7E, $8E, $8E, $8E, $8E
    !byte $8E, $8E, $8E, $8E, $8E, $8E, $8E, $8E
    !byte $9E, $9E, $9E, $9E, $9E, $9E, $9E, $9E
    !byte $9E, $9E, $9E, $AE, $AC, $AC, $AC, $AC
    !byte $AC, $AC, $AC, $AC, $AC, $AC, $AC, $BC
    !byte $BC, $BC, $BC, $BC, $BC, $BC, $BA, $BA
    !byte $BA, $BA, $CA, $CA, $CA, $CA, $CA, $CA
    !byte $CA, $CA, $CA, $C8, $C8, $C8, $D8, $D8
    !byte $D8, $D8, $D8, $D8, $D8, $D8, $D6, $D6
    !byte $D6, $E6, $E6, $E6, $E6, $E6, $E6, $E6
    !byte $E6, $E4, $E4, $E4, $E4, $F4, $F4, $F4
    !byte $F4, $F4, $F4, $F2, $F2, $F2, $F2, $F2

; -----------------------------------------------------------------------------
; The vectors
; -----------------------------------------------------------------------------
    !if * > $FFFA {
        !error "the data must end before $FFFA"
    }
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset, Reset, Reset
