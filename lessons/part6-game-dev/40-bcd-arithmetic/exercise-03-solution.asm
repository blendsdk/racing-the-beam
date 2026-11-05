; =============================================================================
; LESSON 40 — EXERCISE 3 SOLUTION: Add 100 with a Middle Carry
; =============================================================================
; Part 6: Game Development
;
; The exercise:
;   Set up the middle-carry scenario: 009900 + 100 = 010000.  The middle
;   byte is $99, so adding 1 wraps it to $00 and carries into the high
;   byte.  Expected: BCDCarry reports A=1 on the middle add and the score
;   reads 010000; the ADD 100 cell is lit.
;
; The changes from the main ROM:
;   1. Reset presets BCDScoreMid to $99, so the display starts at 009900.
;   2. The demo starts on ADD 100, so its first operation carries the
;      middle byte into the high byte.
;
; What stays the same:
;   BCDAdd (ADD 1 and ADD 100), the 48-pixel score kernel, the monitor
;   zones, the input handling, and the beep are the main ROM's.  This
;   exercise is about choosing the values that make the carry visible.
;
; The score and the display:
;   BCDScoreLow/Mid/High hold two decimal digits each (high nibble = the
;   left digit).  BCDToDigits turns each nibble into one ScoreSetDigit call,
;   and ScoreDraw draws the six columns in nine visible lines.  The library's
;   ScoreDigits array is only a display cache; the BCD bytes are the truth.
;
; The screen (192 visible lines):
;   visible 0-8     the score, 9 lines (ScoreDraw: 1 setup + 8 rows)
;   visible 9-16    the operation bar: four cells, chunks 2-17; ADD 100 is
;                   slot 2, chunks 10-13, and is lit while it is selected
;   visible 17-24   the carry cell: a red center block when Overflow is set
;   visible 25-32   the low-byte bit strip: PF2 = BCDScoreLow
;   visible 33-191  background (159 lines)
;   CTRLPF=$01 mirrors the playfield, so every zone appears on both halves.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), BCDAdd (A = the command selector),
;   BCDCarryMid (A = the carry into the middle byte), BCDCarry (A = the
;   carry into the high byte), BCDOverflow, Overflow (the flag at $86),
;   BCDScoreLow/Mid/High (the three BCD bytes), ScoreDigitWrite (A =
;   position, X = digit), BodyStart (37), ScoreDraw (the call),
;   HmoveApply/HmoveDone (once per frame), OverscanStart (229).
;
; Build: acme -f plain -o build/ex40-3.bin \
;        lessons/part6-game-dev/40-bcd-arithmetic/exercise-03-solution.asm
; Run:   stella build/ex40-3.bin      (click the screen to hear the beep)
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36

DEMO_FRAMES    = 60      ; frames per auto-demo operation (about one second)
BEEP_FRAMES    = 8
BEEP_PITCH     = $0A     ; AUDF 10 on AUDC $0C: a short, bright beep

OP_ADD1        = 0
OP_ADD10       = 1
OP_ADD100      = 2
OP_SUB1        = 3
OPMASK_MAIN    = %00000101   ; ADD 1 and ADD 100; bits 1 and 3 are exercises

C_WHITE        = $0E
C_GOLD         = $1A
C_RED          = $42
C_GREEN        = $C8
C_BG           = $02

; --- Lesson variables (RAM $80-$9F; +clean_start zeroes them) ---
Operation    = $80   ; 0=ADD1, 1=ADD10, 2=ADD100, 3=SUB1
DemoTimer    = $81   ; frames until the next auto-demo operation
DemoStarted  = $82   ; 0 until the first demo operation has run
Buttons      = $83   ; bit 0=up, bit 1=down, bit 2=fire (1 = pressed)
PrevButtons  = $84   ; the previous frame's Buttons
NewPress     = $85   ; Buttons & ~PrevButtons: the 0 -> 1 edges
Overflow     = $86   ; 1 after the sum passes 999999 (the top carry)
OverflowPF   = $87   ; $FF when Overflow, $00 otherwise (the red cell)
BeepTimer    = $88   ; frames of beep remaining
BeepPitch    = $89   ; AUDF for the beep
BCDCarryTmp  = $8A   ; the 0/1 carry saved across one byte's add
BarPF0       = $8B   ; the operation bar's playfield bytes for this frame
BarPF1       = $8C
BarPF2       = $8D
OpMask       = $8E   ; bits of the operations this build implements

; --- The BCD score: three bytes, two decimal digits each ---
BCDScoreLow  = $90   ; positions 5/4: high nibble = position 4, low = 5
BCDScoreMid  = $91   ; positions 3/2
BCDScoreHigh = $92   ; positions 1/0
;
; The score library owns $A0-$D7:
;   ScoreDigits $A0-$A5, ScoreRow $A6, ScoreTmp $A7, ScoreBuf $A8-$D7.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start

    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the score starts at 009900; the middle byte is the carry subject ---
    JSR ScoreInit           ; zero the six digits and the 48-byte buffer
    LDA #$99
    STA BCDScoreMid         ; 009900: the middle byte will carry into high
    JSR BCDToDigits         ; build the six glyphs: 009900

; --- the demo starts on ADD 100 ---
    LDA #OP_ADD100
    STA Operation
    LDA #OPMASK_MAIN        ; only ADD 1 and ADD 100 are implemented here
    STA OpMask
    LDA #DEMO_FRAMES
    STA DemoTimer
    LDA #BEEP_PITCH
    STA BeepPitch

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
; 1. THE BEEP'S CLOCK — the last frame writes silence
; -----------------------------------------------------------------------------
    LDA BeepTimer
    BEQ BeepDone
    DEC BeepTimer
    BNE BeepDone
    LDA #$00
    STA AUDV0
BeepDone:

; -----------------------------------------------------------------------------
; 2. READ THE JOYSTICK — up, down, and fire as 0 -> 1 edges
; -----------------------------------------------------------------------------
; SWCHA bits 4/5 are P0 up/down (0 = pressed).  EOR flips them to 1 =
; pressed, and four LSRs move them to bits 0/1.  INPT4 bit 7 is 0 while fire
; is held, so it becomes bit 2.  NewPress keeps only the bits that changed
; from 0 to 1, so holding a direction makes exactly one step.
    LDA SWCHA
    AND #$30                ; P0 up (bit 4) and down (bit 5)
    EOR #$30                ; 1 = pressed
    LSR
    LSR
    LSR
    LSR                     ; bit 0 = up, bit 1 = down
    STA Buttons
    LDA INPT4
    AND #$80
    BNE ReadDone            ; bit 7 = 1: fire is released
    LDA Buttons
    ORA #$04                ; bit 2 = fire pressed
    STA Buttons
ReadDone:
    LDA Buttons
    EOR PrevButtons
    AND Buttons             ; new presses only: Buttons & ~PrevButtons
    STA NewPress
    LDA Buttons
    STA PrevButtons

; -----------------------------------------------------------------------------
; 3. FIRE EXECUTES THE SELECTED OPERATION
; -----------------------------------------------------------------------------
    LDA NewPress
    AND #$04
    BEQ NoFireEdge
    JSR ExecuteOperation    ; one operation per press
NoFireEdge:

; -----------------------------------------------------------------------------
; 4. UP/DOWN SELECT THE OPERATION (UP = PREVIOUS, DOWN = NEXT)
; -----------------------------------------------------------------------------
    LDA NewPress
    AND #$01
    BEQ NoUpEdge
    JSR PreviousOperation
NoUpEdge:
    LDA NewPress
    AND #$02
    BEQ NoDownEdge
    JSR NextOperation
NoDownEdge:

; -----------------------------------------------------------------------------
; 5. THE AUTO-DEMO — run only while no button is held
; -----------------------------------------------------------------------------
; The first tick executes the operation that is already selected; every
; later tick steps to the next enabled operation and executes that.  The
; score and the lit cell therefore describe the same operation between
; ticks: 000001 with ADD 1 lit, then 000101 with ADD 100 lit.
    LDA Buttons
    BNE ResetDemo
    DEC DemoTimer
    BNE DemoDone
    LDA DemoStarted
    BEQ DemoFirst
    JSR NextOperation
DemoFirst:
    JSR ExecuteOperation
    LDA #1
    STA DemoStarted
    LDA #DEMO_FRAMES
    STA DemoTimer
    JMP DemoDone
ResetDemo:
    LDA #DEMO_FRAMES        ; any input pauses the demo for another second
    STA DemoTimer
DemoDone:

; -----------------------------------------------------------------------------
; 6. TURN THE STATE INTO PLAYFIELD BYTES FOR THE MONITOR ZONES
; -----------------------------------------------------------------------------
; The operation bar is four 16-pixel cells in chunks 2-17 (TIA X=8-71):
;   ADD 1    chunks 2-5    PF0=$C0           PF1=$C0           PF2=$00
;   ADD 10   chunks 6-9    PF0=$00           PF1=$3C           PF2=$00
;   ADD 100  chunks 10-13  PF0=$00           PF1=$03           PF2=$03
;   SUB 1    chunks 14-17  PF0=$00           PF1=$00           PF2=$3C
    LDX Operation
    LDA BarTab0,X
    STA BarPF0
    LDA BarTab1,X
    STA BarPF1
    LDA BarTab2,X
    STA BarPF2

    LDX Overflow
    LDA OverflowTab,X
    STA OverflowPF

; -----------------------------------------------------------------------------
; 7. POSITION THE SCORE — both players and ONE HMOVE
; -----------------------------------------------------------------------------
; ScoreSetup sets NUSIZ0/NUSIZ1=3, turns VDEL on, positions P0 at 56 and
; P1 at 64, and strobes the frame's only HMOVE.
    JSR ScoreSetup

; -----------------------------------------------------------------------------
; 8. COLORS AND PLAYFIELD CONTROL
; -----------------------------------------------------------------------------
    LDA #C_WHITE
    STA COLUP0              ; the score is white
    STA COLUP1
    LDA #C_GOLD
    STA COLUPF              ; the operation bar is gold (set again per zone)
    LDA #C_BG
    STA COLUBK
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA ENABL               ; no ball in this lesson
    LDA #$01
    STA CTRLPF              ; reflect the playfield; per-half counts

    +wait_timer

; =============================================================================
; VISIBLE — 192 lines: score (9) + bar (8) + carry (8) + strip (8) + 159
; =============================================================================
    LDA #$00
    STA VBLANK

BodyStart:                  ; checkpoint: scanline 37, visible line 0
    JSR ScoreDraw           ; 9 lines: line 0 setup, lines 1-8 rows

; -----------------------------------------------------------------------------
; VISIBLE 9-16: THE OPERATION BAR — one bright cell per half
; -----------------------------------------------------------------------------
; The caller resumes at line 9, cycle 5; the stores take effect at clocks
; ~36 (PF0), ~54 (PF1) and ~69 (PF2).  All three land before their left
; slots (68/84/116), so line 9 shows the new bytes for its whole width.
    LDA BarPF0
    STA PF0
    LDA BarPF1
    STA PF1
    LDA BarPF2
    STA PF2
    LDY #8
BarLines:
    STA WSYNC
    DEY
    BNE BarLines

; -----------------------------------------------------------------------------
; VISIBLE 17-24: THE CARRY CELL — a red center block on overflow
; -----------------------------------------------------------------------------
; PF2=$FF is chunks 12-19 (X=48-79); with the mirrored right half the block
; fills X=48-111, a 64-pixel bar across the center.  It is dark (PF2=$00)
; except on the operation that carried out of the high byte.
    LDA #C_RED
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF1
    LDA OverflowPF
    STA PF2
    LDY #8
CarryLines:
    STA WSYNC
    DEY
    BNE CarryLines

; -----------------------------------------------------------------------------
; VISIBLE 25-32: THE LOW-BYTE BIT STRIP — PF2 = BCDScoreLow
; -----------------------------------------------------------------------------
; PF2's eight chunks are the eight bits of the low byte, one 4-pixel cell
; each: bit 0 is the leftmost cell, bit 7 the rightmost.  Four cells show
; the low nibble (digit 5) and four show the high nibble (digit 4).
    LDA #C_GREEN
    STA COLUPF
    LDA BCDScoreLow
    STA PF2
    LDY #8
StripLines:
    STA WSYNC
    DEY
    BNE StripLines

; -----------------------------------------------------------------------------
; VISIBLE 33-191: BACKGROUND — 159 lines
; -----------------------------------------------------------------------------
    LDA #$00
    STA PF2
    LDY #(192 - 33)
BackgroundLines:
    STA WSYNC
    DEY
    BNE BackgroundLines

; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines
; -----------------------------------------------------------------------------
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; EXECUTE OPERATION — run the selected op, rebuild the display, beep
; =============================================================================
; Clearing Overflow first means the red cell reports the operation that just
; ran and goes dark on the next one.
ExecuteOperation:
    LDA #$00
    STA Overflow
    LDX Operation
    LDA OpCommand,X
    JSR BCDAdd
    JSR BCDToDigits
    JSR BeepStart
    RTS

; The command selector for each operation.  A=$FF is the SUB 1 slot, which
; this build never selects (OpMask has its bit clear).
OpCommand:
    !byte 1, 10, 100, $FF

; =============================================================================
; BCDAdd — A = the command selector
; =============================================================================
; The selector names the byte to change; it is not a BCD addend:
;   A=1    low += 1
;   A=10   low += $10
;   A=100  mid += 1
; Every path that enters decimal mode restores binary mode with CLD; the
; A=10 and A=$FF selectors return without touching D.  BCDAdd returns the
; top carry as the Overflow flag.
BCDAdd:                     ; checkpoint: A = the command selector
    CMP #1
    BEQ BCDAddOne
    CMP #100
    BEQ BCDAddHundred
    RTS                     ; A=10 is the ADD 10 exercise's path

; --- ADD 1: low += 1, then carry into the middle and the high byte ----------
BCDAddOne:
    SED                     ; decimal mode: ADC keeps each byte in 00-99
    CLC
    LDA BCDScoreLow
    ADC #$01
    STA BCDScoreLow
    LDA #0
    ADC #0                  ; 0 + 0 + C = the carry into the middle byte
BCDCarryMid:                ; checkpoint: A = the carry into the middle byte
    STA BCDCarryTmp
    LDA BCDScoreMid
    CLC
    ADC BCDCarryTmp
    STA BCDScoreMid
    JMP BCDAddHigh          ; the middle's carry is in C

; --- ADD 100: mid += 1, then carry into the high byte -----------------------
BCDAddHundred:
    SED
    CLC
    LDA BCDScoreMid
    ADC #$01
    STA BCDScoreMid
    ; fall through with the middle's carry in C

; --- finish at the high byte and report the top carry -----------------------
BCDAddHigh:
    LDA #0
    ADC #0                  ; 0 + 0 + C = the carry into the high byte
BCDCarry:                   ; checkpoint: A = the carry into the high byte
    STA BCDCarryTmp
    LDA BCDScoreHigh
    CLC
    ADC BCDCarryTmp
    STA BCDScoreHigh
    CLD                     ; back to binary before any other code runs
    BCS BCDOverflow         ; C=1: the high byte carried out
    RTS
BCDOverflow:                ; checkpoint: the sum passed 999999
    LDA #1
    STA Overflow
    RTS

; =============================================================================
; BCDToDigits — rebuild the six score columns from the three BCD bytes
; =============================================================================
; ScoreSetDigit wants A = position (0 = leftmost) and X = digit 0-9, so each
; byte contributes two calls: high nibble first, then low nibble.  The low
; byte is the rightmost pair, the middle byte the middle pair, and the high
; byte the leftmost pair.
BCDToDigits:
    LDA BCDScoreHigh
    LSR                     ; move the high nibble down to bits 0-3
    LSR
    LSR
    LSR
    TAX
    LDA #0
    JSR ScoreSetDigit       ; position 0 = the high byte's high nibble
    LDA BCDScoreHigh
    AND #$0F
    TAX
    LDA #1
    JSR ScoreSetDigit       ; position 1 = the high byte's low nibble
    LDA BCDScoreMid
    LSR
    LSR
    LSR
    LSR
    TAX
    LDA #2
    JSR ScoreSetDigit       ; position 2 = the middle byte's high nibble
    LDA BCDScoreMid
    AND #$0F
    TAX
    LDA #3
    JSR ScoreSetDigit       ; position 3 = the middle byte's low nibble
    LDA BCDScoreLow
    LSR
    LSR
    LSR
    LSR
    TAX
    LDA #4
    JSR ScoreSetDigit       ; position 4 = the low byte's high nibble
    LDA BCDScoreLow
    AND #$0F
    TAX
    LDA #5
    JSR ScoreSetDigit       ; position 5 = the low byte's low nibble
    RTS

; =============================================================================
; OPERATION SELECTION — walk to the next/previous enabled operation
; =============================================================================
; BitTable maps an operation index to its bit in OpMask.  The walk skips
; disabled operations, which is why an exercise can enable ADD 10 or SUB 1
; by setting one mask bit: the bar table already has a cell for every slot.
BitTable:
    !byte $01, $02, $04, $08

NextOperation:
    LDX Operation
NextLoop:
    INX
    CPX #4
    BNE NextCheck
    LDX #0
NextCheck:
    LDA BitTable,X
    AND OpMask
    BEQ NextLoop
    STX Operation
    RTS

PreviousOperation:
    LDX Operation
PrevLoop:
    DEX
    BPL PrevCheck
    LDX #3
PrevCheck:
    LDA BitTable,X
    AND OpMask
    BEQ PrevLoop
    STX Operation
    RTS

; =============================================================================
; THE OPERATION BAR TABLE — three playfield bytes per slot
; =============================================================================
; Four 16-pixel cells in chunks 2-17, one 8-line row.  The mirrored right
; half repeats them, so the bar reads left to right on the left half and
; right to left on the right half.
BarTab0:
    !byte $C0, $00, $00, $00
BarTab1:
    !byte $C0, $3C, $03, $00
BarTab2:
    !byte $00, $00, $03, $3C

; The carry cell is either fully dark or the $FF center block.
OverflowTab:
    !byte $00, $FF

; =============================================================================
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
BeepStart:
    LDA #BEEP_FRAMES
    STA BeepTimer
    LDA #$0C                ; AUDC 0C: the div-6 tone from Lesson 35
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0
    RTS

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreInit, ScoreClear, ScoreSetup, ScoreSetDigit, ScoreAddOne, ScoreDraw,
; and ScoreFont live here.  The library must be sourced inside the ROM area
; (after * = $F000) and after include/vcs.asm.
    !source "include/score.asm"

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
