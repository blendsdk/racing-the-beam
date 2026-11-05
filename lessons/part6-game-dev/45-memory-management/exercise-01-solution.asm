; =============================================================================
; LESSON 45 — EXERCISE 1 SOLUTION: Pack the Flags — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; EXERCISE 1: replace the four separate flag bytes (FlagFire, FlagLeft,
; FlagRight, FlagOver) with one packed byte, Flags:
;
;       bit 0 = fire    bit 1 = left    bit 2 = right    bit 3 = over
;
; The flags row still lights one cell per flag, and the map loses three used
; cells in its top row ($85-$87 become free).  FlagsWrite reports the packed
; byte.
;
; The changes from the main ROM:
;   1. $85-$87 are free.  Flags sits at $84 and holds the four bits.
;   2. The input block builds bits 0-2 from INPT4 and SWCHA: the two joystick
;      bits are inverted as a pair and shifted down by five; fire is ORed in
;      as bit 0.
;   3. The auto-demo's two direction tables are shifted into bits 1 and 2.
;   4. The fire edge reads bit 0; the timer reads bit 3; the overflow sets bit
;      3 with ORA #$08; the restart clears it with AND #$F7.
;   5. The flags row indexes two four-entry tables with bits 0-1 and 2-3.
;      A = the packed byte at FlagsWrite.
;   6. RamMap row 0 becomes $C0,$E3,$3F: cells 5-7 are dark.  FreeBytes
;      reports 33 instead of 30.
;
; Checkpoints (Stella scanline numbers in parentheses): the main ROM's, plus
;   FlagsWrite (A = the packed byte; VBLANK line 6).  FreeBytes (A = $21 = 33).
;   PackTimer, MapDraw, BodyStart, OverscanStart, StartFrame are unchanged.
;
; Build: acme -f plain -o build/ex45-1.bin \
;        lessons/part6-game-dev/45-memory-management/exercise-01-solution.asm
; Run:   stella build/ex45-1.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36

TIMER_FULL     = $F0
BEEP_FRAMES    = 2
BEEP_PITCH     = $0C

DEMO_FRAMES    = 64

BAR_CELLS      = 15
BAR_LINES      = 6
BAR_CHUNK      = $20

FLAG_FIRE_PF0  = $40
FLAG_LEFT_PF0  = $80
FLAG_RIGHT_PF1 = $80
FLAG_OVER_PF1  = $40

C_GOLD         = $1A
C_GREEN        = $C8
C_BG           = $02

; =============================================================================
; RAM ALLOCATION — the packed plan
; =============================================================================
FrameLo      = $80
FrameHi      = $81
PrevFire     = $82
NewFire      = $83
Flags        = $84   ; bit 0 fire, bit 1 left, bit 2 right, bit 3 over
; $85-$87 free: the three bytes the separate flags used to take
PackedTimer  = $88
BeepTimer    = $89
BeepPitch    = $8A
DemoHold     = $8B
DemoStep     = $8C
Scratch0     = $8D   ; reserved scratch, $8D-$8E (not written by this ROM)
Scratch1     = $8E
FlagPF0      = $8F
FlagPF1      = $90
FreeCount    = $91

; $92-$9F free (14 bytes).
; $A0-$D7 the scoreboard reservation (56 bytes, not used by this lab).
; $D8-$E7 free (16 bytes).
BarBuf       = $E8   ; fifteen cell bytes ($E8-$F6)
BarLevel     = $F7   ; the bar height (0-15)
RamEnd       = BarLevel

; --- $F8-$FF: the stack ----------------------------------------------------

; =============================================================================
; ROM START
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA SWACNT

    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #C_BG
    STA COLUBK
    LDA #$01
    STA CTRLPF

    JSR CountFree
FreeBytes:                  ; checkpoint: A = the computed free-byte count
    STA FreeCount

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259
    +vsync

VblankStart:                ; checkpoint: scanline 0
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
    STA AUDV0
BeepClockDone:

; -----------------------------------------------------------------------------
; 3. INPUT — pack bits 0-2, then put the over latch back
; -----------------------------------------------------------------------------
; SWCHA bits 7 (right) and 6 (left) are active low.  Inverting the pair puts
; 1 = pressed in bits 7 and 6; five LSRs move right to bit 2 and left to bit
; 1.  Fire is bit 0.
;
; The input rebuild replaces the whole byte, so the timer's overflow bit (3)
; is parked in NewFire for a few instructions.  NewFire is scratch until the
; fire-edge block recomputes it; the latch is ORed back before the timer runs.
    LDA Flags
    AND #$08                ; the over latch, if any
    STA NewFire             ; scratch: NewFire is recomputed below

    LDA SWCHA
    AND #$C0
    EOR #$C0                ; 1 = pressed at bits 7 (right) and 6 (left)
    LSR
    LSR
    LSR
    LSR
    LSR                     ; right -> bit 2, left -> bit 1
    STA Flags

    LDA INPT4
FireRead:                   ; checkpoint: A = INPT4 (bit 7 = 0 while pressed)
    AND #$80
    BNE FireReadDone
    LDA Flags
    ORA #$01
    STA Flags
FireReadDone:

; -----------------------------------------------------------------------------
; 4. THE AUTO-DEMO — OR its two direction bits into Flags
; -----------------------------------------------------------------------------
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
    ASL                     ; 1 -> bit 1
    ORA Flags
    STA Flags
    LDA DemoRightTable,X
    ASL
    ASL                     ; 1 -> bit 2
    ORA Flags
    STA Flags

; --- put the timer's overflow latch back -----------------------------------
    LDA Flags
    ORA NewFire             ; the latch parked in step 3
    STA Flags

; -----------------------------------------------------------------------------
; 5. THE FIRE EDGE — bit 0
; -----------------------------------------------------------------------------
    LDA Flags
    AND #$01
    STA NewFire
    EOR PrevFire
    AND NewFire
    STA NewFire
    LDA Flags
    AND #$01
    STA PrevFire

    LDA NewFire
    BEQ NoRestart
    LDA #$00
    STA PackedTimer
    LDA Flags
    AND #$F7                ; clear the overflow bit
    STA Flags
NoRestart:

; -----------------------------------------------------------------------------
; 6. THE PACKED TIMER — bit 3 is the overflow latch
; -----------------------------------------------------------------------------
    LDA Flags
    AND #$08
    BNE TimerDone
    INC PackedTimer
    LDA PackedTimer
PackTimer:                  ; checkpoint: A = the packed byte
    CMP #TIMER_FULL
    BNE TimerDone
    LDA Flags
    ORA #$08
    STA Flags
    JSR BeepStart
TimerDone:

; -----------------------------------------------------------------------------
; 7. THE BAR'S HEIGHT AND ITS FIFTEEN DISPLAY BYTES
; -----------------------------------------------------------------------------
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
    BCS FillBarDark
    LDA #BAR_CHUNK
FillBarDark:
    STA BarBuf,X
    INX
    CPX #BAR_CELLS
    BNE FillBar

; -----------------------------------------------------------------------------
; 8. THE FLAGS ROW — two lookups into the packed byte
; -----------------------------------------------------------------------------
; Bits 0-1 index the PF0 table (fire and left); bits 2-3 index the PF1 table
; (right and over).  FlagsWrite is the packed value including the timer's
; overflow bit, because this block runs after the timer.
    LDA Flags
FlagsWrite:                 ; checkpoint: A = the packed flags byte
    AND #$03
    TAX
    LDA FlagPF0Table,X
    STA FlagPF0
    LDA Flags
    LSR
    LSR
    AND #$03
    TAX
    LDA FlagPF1Table,X
    STA FlagPF1

    +wait_timer
    LDA #$00
    STA VBLANK

; =============================================================================
; VISIBLE — 192 lines, work-first
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37

; --- visible 0-7: the flags row --------------------------------------------
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

; --- visible 8-39: the 16x8 memory grid ------------------------------------
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
    TAX
    LDY #4
MapLine:
    STA WSYNC
    DEY
    BNE MapLine
    CPX #24
    BNE MapRow

; --- visible 40-129: the timer bar -----------------------------------------
    LDA BarBuf+14
    STA PF1
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
; FRAME END — 30 overscan lines
; =============================================================================
FrameEnd:
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; CountFree — 128 - used, computed from the table
; =============================================================================
CountFree:
    LDA #$00
    STA FreeCount
    LDX #$00
CountRow:
    LDA RamMap+0,X
    AND #$C0
    JSR CountBits
    LDA RamMap+1,X
    JSR CountBits
    LDA RamMap+2,X
    AND #$3F
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

CountBits:
    LDY #8
CountBit:
    ASL
    BCC CountBitNext
    INC FreeCount
CountBitNext:
    DEY
    BNE CountBit
    RTS

; =============================================================================
; BEEP
; =============================================================================
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

; --- the auto-demo's direction bits, indexed by DemoStep -------------------
DemoLeftTable:
    !byte 1, 0, 1, 0
DemoRightTable:
    !byte 0, 1, 1, 0

; --- the flags row's two playfield bytes, indexed by two packed bits -------
; Index = fire | left<<1 for PF0, and right | over<<1 for PF1.
FlagPF0Table:
    !byte $00, FLAG_FIRE_PF0, FLAG_LEFT_PF0, FLAG_FIRE_PF0 | FLAG_LEFT_PF0
FlagPF1Table:
    !byte $00, FLAG_RIGHT_PF1, FLAG_OVER_PF1, FLAG_RIGHT_PF1 | FLAG_OVER_PF1

; --- the memory map --------------------------------------------------------
RamMap:
    !byte $C0, $E3, $3F     ; row 0: $80-$8F  cells 5-7 free ($85-$87)
    !byte $C0, $00, $00     ; row 1: $90-$9F  cells 0-1 used
    !byte $C0, $FF, $3F     ; row 2: $A0-$AF  all used (score plan)
    !byte $C0, $FF, $3F     ; row 3: $B0-$BF  all used (score plan)
    !byte $C0, $FF, $3F     ; row 4: $C0-$CF  all used (score plan)
    !byte $C0, $FC, $00     ; row 5: $D0-$DF  cells 0-7 used
    !byte $00, $03, $3F     ; row 6: $E0-$EF  cells 8-15 used
    !byte $C0, $FF, $3F     ; row 7: $F0-$FF  all used (bar + stack)

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
