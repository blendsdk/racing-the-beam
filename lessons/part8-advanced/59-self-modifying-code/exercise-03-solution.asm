; =============================================================================
; LESSON 59 — EXERCISE 3 SOLUTION: A Second RAM Routine Draws an Object
; =============================================================================
; Racing the Beam · Part 8: Advanced Topics
;
; This solution copies two routines into RIOT RAM:
;
;   $80  A9 xx   LDA #color     ; the gradient's color, patched at $81
;   $82  85 09   STA COLUBK
;   $84  85 02   STA WSYNC
;   $86  60      RTS
;
;   $90  A9 xx   LDA #shape     ; the P0 shape, patched at $91
;   $92  85 1B   STA GRP0
;   $94  60      RTS
;
; The main loop patches both operands from two 184-byte tables and calls the
; shape routine before the gradient routine on every visible line.  The P0
; sprite is positioned once per frame at TIA X = 80 with the Lesson 26
; divide-by-15 dance and one HMOVE; the shape table draws a chain of diamonds
; down the screen.  The top status field shows the first shape byte ($18);
; the bottom field shows the call count (184).
;
; The two calls cost more cycles than the lesson's single call: the P0 shape
; write lands at cycle 39-41 (STA GRP0 starts at 37-39), and the gradient's
; STA COLUBK starts at cycle 54-56, so its write is at 56-58 (TIA X ~100-106)
; and the left edge of the gradient is smeared further than in the main
; lesson.  That is the point of the exercise: every added RAM routine spends
; part of the 76-cycle line.  The shape write still beats the beam to X = 80
; (about cycle 49), so the sprite itself is clean; the WSYNC instruction is at
; cycle 57-59 (write at 59-61), leaving about 15-17 cycles of slack.
;
; Frame: 262 lines; StartFrame 259/3, VblankStart 0/5, BodyStart 37/5,
;        OverscanStart 229/6.  One HMOVE per frame.
;
; RAM:
;   $80-$86  the gradient routine (copied from ColorTemplate)
;   $87      free
;   $88      ShapeVal   the displayed shape byte (the first table entry)
;   $89      Calls      184 calls per frame
;   $8A      FrameNum   frames since reset
;   $8B-$8F  free
;   $90-$94  the shape routine (copied from ShapeTemplate)
;   $95-$9F  free
;   $F8-$FF  stack
;
; Build: acme -f plain -o build/lesson59-ex3.bin \
;        lessons/part8-advanced/59-self-modifying-code/exercise-03-solution.asm
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
GRADIENT_LINES = 184
SCREEN_LINES   = 192

C_BG           = $00
C_STATUS_A     = $0E
C_STATUS_B     = $1A
C_P0           = $1A

P0_X           = 80
POS_BIAS       = 3

; -----------------------------------------------------------------------------
; RAM
; -----------------------------------------------------------------------------
RamRoutine   = $80           ; A9 xx 85 09 85 02 60 (7 bytes)
ShapeVal     = $88           ; the first shape byte shown in the status
Calls        = $89           ; 184 calls per frame
FrameNum     = $8A           ; frames since reset
ShapeRoutine = $90           ; A9 xx 85 1B 60 (5 bytes)

; -----------------------------------------------------------------------------
; RESET
; -----------------------------------------------------------------------------
    * = $F000

Reset:
    +clean_start

; Copy the gradient routine (7 bytes) to $80.
    LDX #6
CopyColor:
    LDA ColorTemplate,X
    STA $80,X
    DEX
    BPL CopyColor

; Copy the shape routine (5 bytes) to $90.
    LDX #4
CopyShape:
    LDA ShapeTemplate,X
    STA $90,X
    DEX
    BPL CopyShape

    LDA #C_BG
    STA COLUBK
    LDA #C_STATUS_A
    STA COLUPF
    LDA #C_P0
    STA COLUP0
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    LDA #$01
    STA CTRLPF

; The status shows the first shape byte and the frame's fixed call count.
; Keeping these values out of the last visible line matters: the last line
; already carries two JSRs, and the extra stores would push its STA WSYNC past
; the 76-cycle line and stretch the frame by one scanline.
    LDA ShapeTable
    STA ShapeVal
    LDA #GRADIENT_LINES
    STA Calls

    JMP StartFrame

; -----------------------------------------------------------------------------
; FRAME
; -----------------------------------------------------------------------------
StartFrame:
    +vsync
VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    INC FrameNum
    LDA FrameNum
Frame:                       ; checkpoint: A = the new frame count
    NOP

; --- position P0 once per frame, then strobe one HMOVE ----------------------
    LDA #(P0_X + POS_BIAS)
    JSR SetCoarseP0
    STA WSYNC
    STA HMOVE                  ; the frame's only HMOVE

; Clear GRP0 and load the first status field while the picture is still
; blanked.  GRP0 and PF1 must not race the first visible line.  +wait_timer
; preserves Y.
    LDA #$00
    STA GRP0
    LDA #C_BG
    STA COLUBK
    LDA #C_STATUS_A
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF2
    LDA ShapeVal
    STA PF1
    LDY #4

    +wait_timer
    LDA #$00
    STA VBLANK

BodyStart:
    NOP                     ; one-time hit; StatusShape is the loop target
StatusShape:
    STA WSYNC
    DEY
    BNE StatusShape

    LDA #C_STATUS_B
    STA COLUPF
    LDA Calls
    STA PF1
    LDY #4
StatusCalls:
    STA WSYNC
    DEY
    BNE StatusCalls

    LDA #$00
    STA PF1

; --- the 184-line gradient plus the P0 object ------------------------------
; The shape patch and the shape call come first so GRP0 is written before the
; beam reaches P0's X.  The gradient's patch and call follow; the gradient
; routine's STA WSYNC ends the line.
    LDY #0
GradientLoop:
    LDA ShapeTable,Y
ShapePatch:                  ; checkpoint: A = the shape patched into $91
    STA $91
    LDA ColorTable,Y
PatchByte:                   ; checkpoint: A = the color patched into $81
    STA $81
    INY
    CPY #GRADIENT_LINES
    BEQ LastLine
    JSR ShapeRoutine          ; LDA #shape; STA GRP0; RTS
    JSR RamRoutine            ; LDA #color; STA COLUBK; STA WSYNC; RTS
    JMP GradientLoop
LastLine:
    JSR ShapeRoutine          ; the 184th line, Y = 183
    JSR RamRoutine

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; -----------------------------------------------------------------------------
; SetCoarseP0 — the Lesson 26 divide-by-15 positioning dance
; -----------------------------------------------------------------------------
; A = the desired left edge + POS_BIAS.  Each loop pass is 5 cycles = 15
; colour clocks; the remainder becomes HMP0's fine value and RESP0 sets the
; coarse position.
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

; -----------------------------------------------------------------------------
; THE TEMPLATES
; -----------------------------------------------------------------------------
ColorTemplate:
    !byte $A9, $00           ; $80  LDA #$00 (operand at $81)
    !byte $85, COLUBK        ; $82  STA COLUBK
    !byte $85, WSYNC         ; $84  STA WSYNC
    !byte $60                ; $86  RTS

ShapeTemplate:
    !byte $A9, $00           ; $90  LDA #$00 (operand at $91)
    !byte $85, GRP0          ; $92  STA GRP0
    !byte $60                ; $94  RTS

; -----------------------------------------------------------------------------
; THE SHAPE TABLE — 23 repetitions of an 8-line diamond
; -----------------------------------------------------------------------------
ShapeTable:
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18

; -----------------------------------------------------------------------------
; THE COLOR TABLE — the lesson's 184-entry gradient
; -----------------------------------------------------------------------------
ColorTable:
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

    !if * > $FFFA {
        !error "the data must end before $FFFA"
    }
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset, Reset, Reset
