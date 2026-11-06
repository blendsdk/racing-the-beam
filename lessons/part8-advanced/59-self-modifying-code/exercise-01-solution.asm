; =============================================================================
; LESSON 59 — EXERCISE 1 SOLUTION: Patch a Delay Count in the RAM Routine
; =============================================================================
; Racing the Beam · Part 8: Advanced Topics
;
; The lesson's seven-byte routine writes COLUBK and waits for the next line.
; This solution adds a delay loop *before* the color write:
;
;   $80  A2 nn   LDX #delay     ; the operand at $81 is patched each line
;   $82  CA      DEX
;   $83  D0 FD   BNE $82        ; branch back to $82 (offset -3)
;   $85  A9 xx   LDA #color     ; the operand at $86 is patched each line
;   $87  85 09   STA COLUBK
;   $89  85 02   STA WSYNC
;   $8B  60      RTS
;
; The delay moves the color write later in the scanline.  Because the first
; pixels of a line are drawn before the write, the boundary between the
; previous line's color and this line's color slides to the right as the delay
; count grows.  Patching the LDX operand every line therefore paints a
; repeating diagonal seam over the gradient.  The routine still uses no stack;
; LDX/DEX/BNE only touch X and the flags, and the JSR/RTS pair uses $FF/$FE.
;
; The delay table is 1,2,3,4 repeating (184 entries).  The 1..4 range keeps
; the delay loop inside the 76-cycle line: 4 costs 2 + (5*4 - 1) = 21 extra
; cycles, so the color write still lands before the line ends.  A delay of 0
; would not work with LDX/DEX/BNE (DEX wraps 0 to $FF and the loop runs 255
; times).  The budget reaches the WSYNC write at cycle 70 for d = 5 and 75
; for d = 6; d = 7 overflows the 76-cycle line.  Both tables are page-aligned,
; so the two loads are always 4 cycles; d = 6 has one cycle to spare.  The
; shipped table stops at 4 to leave margin.
;
; The picture is the lesson's 8 status lines + 184 gradient lines.  The top
; status field shows the last patched delay (DelayVal); the bottom field shows
; the call count (184).
;
; Frame: 262 lines; StartFrame 259/3, VblankStart 0/5, BodyStart 37/5,
;        OverscanStart 229/6.
;
; RAM:
;   $80-$8B  the 12-byte routine (copied from DelayTemplate)
;   $8C      DelayVal   the last delay patched into $81
;   $8D      Calls      the call count (184)
;   $8E      FrameNum   frames since reset
;   $8F-$9F  free
;   $F8-$FF  stack
;
; Build: acme -f plain -o build/lesson59-ex1.bin \
;        lessons/part8-advanced/59-self-modifying-code/exercise-01-solution.asm
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

; -----------------------------------------------------------------------------
; RAM
; -----------------------------------------------------------------------------
RamRoutine   = $80           ; A2 nn CA D0 FD A9 xx 85 09 85 02 60 (12 bytes)
DelayVal     = $8C           ; the delay operand last patched into $81
Calls        = $8D           ; 184 calls per frame
FrameNum     = $8E           ; frames since reset

; -----------------------------------------------------------------------------
; RESET
; -----------------------------------------------------------------------------
    * = $F000

Reset:
    +clean_start

; Copy the 12-byte template to $80.  X runs 11 down to 0; DEX sets N when it
; wraps, so BPL exits after the index-0 byte.
    LDX #11
CopyRoutine:
    LDA DelayTemplate,X
    STA $80,X
    DEX
    BPL CopyRoutine

    LDA #C_BG
    STA COLUBK
    LDA #C_STATUS_A
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA #$01
    STA CTRLPF

; The status shows the last delay the frame will patch.  The delay table ends
; at 4, so set that once here rather than adding seven cycles to the already
; tight last visible line.
    LDA DelayTable+183
    STA DelayVal

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

; Load the first status field while the picture is still blanked.  PF1 must
; not race playfield chunk 4 on visible line 0.  +wait_timer preserves Y.
    LDA #C_BG
    STA COLUBK
    LDA #C_STATUS_A
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF2
    LDA DelayVal
    STA PF1
    LDY #4

    +wait_timer
    LDA #$00
    STA VBLANK

BodyStart:
    NOP                     ; one-time hit; StatusDelay is the loop target
StatusDelay:
    STA WSYNC
    DEY
    BNE StatusDelay

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

; --- the 184-line gradient --------------------------------------------------
    LDY #0
GradientLoop:
    LDA DelayTable,Y
DelayPatch:                  ; checkpoint: A = the delay patched into $81
    STA $81
    LDA ColorTable,Y
PatchByte:                   ; checkpoint: A = the color patched into $86
    STA $86
    INY
    CPY #GRADIENT_LINES
    BEQ LastLine
    JSR RamRoutine
    JMP GradientLoop
LastLine:
    STY Calls
    LDA Calls
CallCount:                   ; checkpoint: A = 184
    JSR RamRoutine

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; -----------------------------------------------------------------------------
; THE TEMPLATE
; -----------------------------------------------------------------------------
DelayTemplate:
    !byte $A2, $00           ; $80  LDX #$00 (operand at $81)
    !byte $CA                ; $82  DEX
    !byte $D0, $FD           ; $83  BNE $82 (-3)
    !byte $A9, $00           ; $85  LDA #$00 (operand at $86)
    !byte $85, COLUBK        ; $87  STA COLUBK
    !byte $85, WSYNC         ; $89  STA WSYNC
    !byte $60                ; $8B  RTS

; -----------------------------------------------------------------------------
; THE DELAY TABLE — 1,2,3,4 repeating (184 entries, page-aligned)
; -----------------------------------------------------------------------------
    !align 255, 0
DelayTable:
    !byte $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04
    !byte $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04
    !byte $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04
    !byte $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04
    !byte $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04
    !byte $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04
    !byte $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04
    !byte $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04
    !byte $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04
    !byte $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04
    !byte $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04, $01, $02, $03, $04
    !byte $01, $02, $03, $04, $01, $02, $03, $04

; -----------------------------------------------------------------------------
; THE COLOR TABLE (the lesson's 184-entry gradient, page-aligned)
; -----------------------------------------------------------------------------
    !align 255, 0
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
