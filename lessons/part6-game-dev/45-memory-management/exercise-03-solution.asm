; =============================================================================
; LESSON 45 — EXERCISE 3 SOLUTION: The RAM Budget Assert — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; EXERCISE 3 (STRETCH GOAL): make the memory budget a build-time check.  The
; source already labels the highest used address:
;
;       BarLevel = $F7
;       RamEnd   = BarLevel
;
; The assert below stops the assembler when RamEnd moves past $F7, the last
; byte before the stack reserve ($F8-$FF).  The check costs no ROM cycles: it
; runs while ACME assembles, not on the 2600.
;
; The source is the main ROM plus the !if block after the allocation.  The
; screen, the controls, the map table, and every checkpoint are unchanged.
; FreeBytes still reports 30.  The only difference is the guard.
;
; PROVE IT (the documented failure):
;   1. Copy this file to a scratch name.
;   2. Change ``BarLevel = $F7`` to ``BarLevel = $F8``.  RamEnd follows the
;      label, so it becomes $F8.
;   3. Assemble it.  ACME stops with:
;
;          Error - File ..., line ... (Zone <untitled>): !error: RAM budget exceeded
;
;   4. Change it back and the build returns to 4,096 bytes.  The point is
;      that the failure is a build failure with a clear message, not a ROM
;      that silently corrupts the stack at run time.
;
; The map table in this file still marks $F7 as used; a real move would also
; update row 7 (the map is a hand-maintained reference).  The assert catches
; the plan error first.
;
; Build: acme -f plain -o build/ex45-3.bin \
;        lessons/part6-game-dev/45-memory-management/exercise-03-solution.asm
; Run:   stella build/ex45-3.bin     (identical to the main ROM)
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36

TIMER_FULL     = $F0     ; 240 frames: 15 ticks of 16 frames
BEEP_FRAMES    = 2       ; a two-frame tick
BEEP_PITCH     = $0C     ; AUDF 12 on AUDC $0C: a low, short beep

DEMO_FRAMES    = 64      ; the auto-demo changes phase every 64 frames

BAR_CELLS      = 15      ; the timer shows a nibble: 0-15 lit cells
BAR_LINES      = 6       ; six visible lines per cell
BAR_CHUNK      = $20     ; PF1 bit 5 = chunk 6 = X=24-27

FLAG_FIRE_PF0  = $40     ; PF0 bit 6 = chunk 2 = X=8-11
FLAG_LEFT_PF0  = $80     ; PF0 bit 7 = chunk 3 = X=12-15
FLAG_RIGHT_PF1 = $80     ; PF1 bit 7 = chunk 4 = X=16-19
FLAG_OVER_PF1  = $40     ; PF1 bit 6 = chunk 5 = X=20-23

C_GOLD         = $1A
C_GREEN        = $C8
C_BG           = $02

; =============================================================================
; RAM ALLOCATION — the plan the RamMap table draws
; =============================================================================
; Every address is explicit: the map table below is the reference, and these
; labels are the code's view of the same plan.  Add a variable only by taking
; a byte from a free row and lighting its cell in RamMap.

; --- $80-$91: lesson variables ---------------------------------------------
FrameLo      = $80   ; 16-bit frame counter, low byte
FrameHi      = $81   ; frame counter, high byte
PrevFire     = $82   ; fire state last frame (1 = pressed)
NewFire      = $83   ; this frame's fire 0 -> 1 edge
FlagFire     = $84   ; flags row cell 0: fire is held
FlagLeft     = $85   ; flags row cell 1: joystick left is held
FlagRight    = $86   ; flags row cell 2: joystick right is held
FlagOver     = $87   ; flags row cell 3: the 240-frame timer finished
PackedTimer  = $88   ; high nibble = 16-frame ticks, low nibble = frames
BeepTimer    = $89   ; frames of beep remaining
BeepPitch    = $8A   ; AUDF for the beep
DemoHold     = $8B   ; frames until the next auto-demo phase
DemoStep     = $8C   ; auto-demo phase, 0-3
Scratch0     = $8D   ; reserved scratch, $8D-$8E (not written by this ROM)
Scratch1     = $8E
FlagPF0      = $8F   ; the flags row's PF0 byte, precomputed in VBLANK
FlagPF1      = $90   ; the flags row's PF1 byte, precomputed in VBLANK
FreeCount    = $91   ; the computed free-byte count (128 - used)

; $92-$9F are free (14 bytes).  The auto-demo tables are in ROM.

; --- $A0-$D7: the scoreboard reservation ------------------------------------
; The finished game's plan spends these 56 bytes on the Lesson 39 scoreboard:
; six digit bytes, two scratch bytes, and a 48-byte glyph buffer.  This lab
; does not source include/score.asm, so nothing here is read or written; the
; reservation is a budget line, and the map marks a budget line as used.

; --- $D8-$E7: free (16 bytes) ----------------------------------------------

; --- $E8-$F7: the timer bar's block ----------------------------------------
BarBuf       = $E8   ; fifteen cell bytes: $20 = lit, $00 = dark ($E8-$F6)
BarLevel     = $F7   ; the bar height, PackedTimer >> 4 (0-15)
RamEnd       = BarLevel   ; the highest used address ($F7)

; --- the RAM budget check --------------------------------------------------
; RamEnd names the highest byte the plan may use.  The stack owns $F8-$FF,
; so the plan must end at or below $F7.  A variable moved above the boundary
; stops the build here, with a message, instead of corrupting the stack at
; run time.  The check is assembly-time only: it costs no ROM cycles.
!if RamEnd > $F7 {
    !error "RAM budget exceeded"
}

; --- $F8-$FF: the stack ----------------------------------------------------
; +clean_start sets SP=$FF; every JSR and interrupt push grows down from $FF.
; The lesson keeps its call depth to two levels, so eight bytes are enough.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #C_BG
    STA COLUBK              ; the free cells and the background are $02
    LDA #$01
    STA CTRLPF              ; mirror the playfield; ball one pixel wide

; --- the map is static, but the free-byte count is computed once -----------
; CountFree walks the 24-byte table, counts the used bits (PF0 bits 6-7,
; PF1 bits 0-7, PF2 bits 0-5), and returns 128 - used.  It runs before the
; first frame, where no timing budget applies.
    JSR CountFree
FreeBytes:                  ; checkpoint: A = the computed free-byte count
    STA FreeCount

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; 1. THE FRAME COUNTER
; -----------------------------------------------------------------------------
    INC FrameLo
    BNE FrameCounted
    INC FrameHi
FrameCounted:

; -----------------------------------------------------------------------------
; 2. THE BEEP'S CLOCK
; -----------------------------------------------------------------------------
    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0               ; silence at the end of the tick
BeepClockDone:

; -----------------------------------------------------------------------------
; 3. INPUT — three level flags, active low
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  SWCHA bit 6 is P0 left and bit 7 is
; P0 right, also active low.  Each flag byte is 0 or 1: the flags row turns
; the byte into a playfield cell, and the exercises pack the bytes.
    LDA #$00
    STA FlagFire
    LDA INPT4
FireRead:                   ; checkpoint: A = INPT4 (bit 7 = 0 while pressed)
    AND #$80
    BNE FireReadDone
    LDA #$01
    STA FlagFire
FireReadDone:

    LDA #$00
    STA FlagLeft
    LDA SWCHA
    AND #$40                ; P0 left
    BNE LeftReadDone
    LDA #$01
    STA FlagLeft
LeftReadDone:

    LDA #$00
    STA FlagRight
    LDA SWCHA
    AND #$80                ; P0 right
    BNE RightReadDone
    LDA #$01
    STA FlagRight
RightReadDone:

; -----------------------------------------------------------------------------
; 4. THE AUTO-DEMO — a changing screen without a controller
; -----------------------------------------------------------------------------
; DemoStep cycles 0,1,2,3 every 64 frames.  The left flag is set in phases 0
; and 2, the right flag in phases 1 and 2.  The demo's flags are ORed with
; the real input, so pressing a direction adds its cell instead of fighting
; the demo.  Fire is left to the player: the demo never restarts the timer.
    INC DemoHold
    LDA DemoHold
    CMP #DEMO_FRAMES
    BCC DemoStepDone
    LDA #$00
    STA DemoHold
    LDA DemoStep
    CLC
    ADC #$01
    AND #$03
    STA DemoStep
DemoStepDone:
    LDX DemoStep
    LDA DemoLeftTable,X
    ORA FlagLeft
    STA FlagLeft
    LDA DemoRightTable,X
    ORA FlagRight
    STA FlagRight

; -----------------------------------------------------------------------------
; 5. THE FIRE EDGE AND THE ROUND RESTART
; -----------------------------------------------------------------------------
; A held fire keeps FlagFire lit, but the restart happens only on the 0 -> 1
; edge: EOR with last frame's value keeps the bits that changed, and AND with
; this frame's value keeps the ones that changed to 1.
    LDA FlagFire
    EOR PrevFire
    AND FlagFire
    STA NewFire
    LDA FlagFire
    STA PrevFire

    LDA NewFire
    BEQ NoRestart
    LDA #$00
    STA PackedTimer
    STA FlagOver
NoRestart:

; -----------------------------------------------------------------------------
; 6. THE PACKED TIMER — one byte, two counters
; -----------------------------------------------------------------------------
; INC adds one to the low nibble, and binary carry does the rest: $0F + 1 =
; $10 (one 16-frame tick, zero frames), $1F + 1 = $20, and so on.  The high
; nibble is the bar's height.  At $F0 (240 frames) the round is full: FlagOver
; latches and the beep sounds.  Fire clears both and starts again.
    LDA FlagOver
    BNE TimerDone
    INC PackedTimer
    LDA PackedTimer
PackTimer:                  ; checkpoint: A = the packed byte, before the test
    CMP #TIMER_FULL
    BNE TimerDone
    LDA #$01
    STA FlagOver
    JSR BeepStart
TimerDone:

; -----------------------------------------------------------------------------
; 7. THE BAR'S HEIGHT AND ITS FIFTEEN DISPLAY BYTES
; -----------------------------------------------------------------------------
; Four LSRs divide by 16.  Cell 0 is the bottom cell; a cell is lit when its
; index is below the height, so the bar grows from the bottom.  Precomputing
; the fifteen bytes in VBLANK replaces the per-cell compare/branch/select
; (about twelve or thirteen cycles) with a four-cycle load and a store:
; seven cycles of per-cell work instead of the Lesson 43 shape.
    LDA PackedTimer
    LSR
    LSR
    LSR
    LSR
    STA BarLevel
    LDX #$00
FillBar:
    CPX BarLevel
    LDA #$00
    BCS FillBarDark         ; X >= height: this cell is dark
    LDA #BAR_CHUNK          ; chunk 6: X=24-27
FillBarDark:
    STA BarBuf,X
    INX
    CPX #BAR_CELLS
    BNE FillBar

; -----------------------------------------------------------------------------
; 8. THE FLAGS ROW'S TWO PLAYFIELD BYTES
; -----------------------------------------------------------------------------
; The four separate flag bytes are read directly: fire and left share PF0
; (bits 6 and 7), right and over share PF1 (bits 7 and 6).  Exercise 1
; replaces this block with two lookups into a packed Flags byte.
    LDA #$00
    STA FlagPF0
    STA FlagPF1
    LDA FlagFire
    BEQ FireCellDone
    LDA #FLAG_FIRE_PF0
    STA FlagPF0
FireCellDone:
    LDA FlagLeft
    BEQ LeftCellDone
    LDA FlagPF0
    ORA #FLAG_LEFT_PF0
    STA FlagPF0
LeftCellDone:
    LDA FlagRight
    BEQ RightCellDone
    LDA #FLAG_RIGHT_PF1
    STA FlagPF1
RightCellDone:
    LDA FlagOver
    BEQ OverCellDone
    LDA FlagPF1
    ORA #FLAG_OVER_PF1
    STA FlagPF1
OverCellDone:

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0

; --- visible 0-7: the flags row --------------------------------------------
; BodyStart is scanline 37, cycle 5, so the first line's PF0 store completes
; at cycle 15, PF1 at 21 and PF2 at 26 -- before the playfield's first slots
; (~22.7 for PF0).  The eight lines then hold the same bytes.
    LDA #C_GOLD
    STA COLUPF
    LDA FlagPF0
    STA PF0
    LDA FlagPF1
    STA PF1
    LDA #$00
    STA PF2
    LDY #8
FlagsRow:
    STA WSYNC
    DEY
    BNE FlagsRow

; --- visible 8-39: the 16x8 memory grid, eight rows of four lines ----------
; Each row reads three bytes from RamMap and writes PF0/PF1/PF2.  The X
; arithmetic advances to the next row *before* the four WSYNCs, so the row
; transition is the DEY/BNE loop exit plus CPX/BNE.  Rows 1-7 complete PF0 at
; cycle 15, PF1 at 22 and PF2 at 29; row 0 is two cycles later (17/24/31)
; because the flags-row exit and the colour setup precede it.  The slots close
; at about 22.7, 28 and 38.7, so PF0 keeps about eight cycles of margin.
    LDA #C_GREEN
    STA COLUPF
    LDX #$00
MapRow:
    LDA RamMap+0,X
MapDraw:                    ; checkpoint: A = the row's PF0 byte
    STA PF0
    LDA RamMap+1,X
    STA PF1
    LDA RamMap+2,X
    STA PF2
    TXA
    CLC
    ADC #$03
    TAX                     ; X = the next row's table index (or 24)
    LDY #4
MapLine:
    STA WSYNC
    DEY
    BNE MapLine
    CPX #24
    BNE MapRow

; --- visible 40-129: the timer bar, fifteen cells of six lines -------------
; The last map row ends at line 39; the preload below writes the top cell's
; byte into PF1 at cycle 14, before PF1's first slot (~28).  The loop's first
; store repeats the same byte, so a late repeat cannot change the picture.
    LDA BarBuf+14
    STA PF1                 ; cell 14 (the top cell) for line 40
    LDA #$00
    STA PF0
    STA PF2
    LDA #C_GOLD
    STA COLUPF
    LDX #14
MeterCell:
    LDA BarBuf,X
    STA PF1
    LDY #BAR_LINES
MeterLine:
    STA WSYNC
    DEY
    BNE MeterLine
    DEX
    BPL MeterCell

; --- visible 130-191: background -------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #62
RestZone:
    STA WSYNC
    DEY
    BNE RestZone
    JMP FrameEnd

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
FrameEnd:
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; CountFree — walk RamMap and return 128 - used in A
; =============================================================================
; The table uses 16 bits per row: PF0 bits 6-7 (two cells), PF1 bits 0-7
; (eight cells), and PF2 bits 0-5 (six cells).  The unused bits are zero, so
; each byte is masked before its bits are counted; counting the used bits and
; subtracting from 128 avoids having to invert the masks.
CountFree:
    LDA #$00
    STA FreeCount           ; the used-byte tally
    LDX #$00
CountRow:
    LDA RamMap+0,X
    AND #$C0                ; PF0 cells 0-1
    JSR CountBits
    LDA RamMap+1,X
    JSR CountBits           ; PF1 cells 2-9
    LDA RamMap+2,X
    AND #$3F                ; PF2 cells 10-15
    JSR CountBits
    TXA
    CLC
    ADC #$03
    TAX
    CPX #24
    BNE CountRow
    LDA #128
    SEC
    SBC FreeCount
    RTS

; --- add the eight bits of A to FreeCount ----------------------------------
CountBits:
    LDY #8
CountBit:
    ASL                     ; the old bit 7 moves into the carry
    BCC CountBitNext
    INC FreeCount
CountBitNext:
    DEY
    BNE CountBit
    RTS

; =============================================================================
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
; The timer's overflow calls this once.  AUDC 0C is the div-6 tone from
; Lesson 35; AUDV 0A is audible but not loud.  The VBLANK clock silences the
; channel two frames later.
BeepStart:
    LDA #BEEP_FRAMES
    STA BeepTimer
    LDA #$0C
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0
    RTS

; =============================================================================
; TABLES
; =============================================================================

; --- the auto-demo's two direction flags, indexed by DemoStep ---------------
DemoLeftTable:
    !byte 1, 0, 1, 0        ; phase 0 and phase 2
DemoRightTable:
    !byte 0, 1, 1, 0        ; phase 1 and phase 2

; --- the memory map: eight rows x three playfield bytes --------------------
; One bit per byte in $80-$FF.  Row 0 is the top row ($80-$8F); within a row,
; cell 0 is the lowest address and lives in PF0 bit 6.  The table is the
; reference: when the allocation changes, change this table and the picture
; follows.
RamMap:
    !byte $C0, $FF, $3F     ; row 0: $80-$8F  all 16 used
    !byte $C0, $00, $00     ; row 1: $90-$9F  cells 0-1 used ($90,$91)
    !byte $C0, $FF, $3F     ; row 2: $A0-$AF  all 16 used (score plan)
    !byte $C0, $FF, $3F     ; row 3: $B0-$BF  all 16 used (score plan)
    !byte $C0, $FF, $3F     ; row 4: $C0-$CF  all 16 used (score plan)
    !byte $C0, $FC, $00     ; row 5: $D0-$DF  cells 0-7 used ($D0-$D7)
    !byte $00, $03, $3F     ; row 6: $E0-$EF  cells 8-15 used ($E8-$EF)
    !byte $C0, $FF, $3F     ; row 7: $F0-$FF  all 16 used (bar + stack)

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
