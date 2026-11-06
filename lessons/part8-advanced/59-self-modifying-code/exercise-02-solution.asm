; =============================================================================
; LESSON 59 — EXERCISE 2 SOLUTION: Patch a Table Address Operand
; =============================================================================
; Racing the Beam · Part 8: Advanced Topics
;
; The lesson's routine patches an immediate operand.  This solution patches an
; address operand instead: the routine's first instruction is
;
;   $80  BD lo hi   LDA TableA,X
;   $83  85 09      STA COLUBK
;   $85  85 02      STA WSYNC
;   $87  60         RTS
;
; The eight-byte routine is copied to $80.  The main loop patches $81 and $82
; — the low and high bytes of the LDA's absolute address — to point at TableA
; or TableB.  X is the line index 0..183; the routine preserves X, so the
; same eight bytes draw 184 table reads from whichever table the operand
; names.  The tables are page-aligned and 184 bytes long, so
; LDA table,X never crosses a page and the color write keeps a fixed cycle.
;
; The demo switches tables every 60 frames.  TableA is the lesson's gradient;
; TableB is the same 184 colors rotated by 92 entries, so the bands visibly
; change phase.  The top status field shows TableID (0 or 1); the bottom field
; shows the call count (184).
;
; Frame: 262 lines; StartFrame 259/3, VblankStart 0/5, BodyStart 37/5,
;        OverscanStart 229/6.
;
; Checkpoints:
;   StartFrame   $F02F  259/3
;   VblankStart  $F03D  0/5
;   BodyStart    $F091  37/5
;   OverscanStart $F0BE 229/6
;   PtrLowB      $F061  A = the low byte of TableB ($00)
;   PtrHighB     $F065  A = the high byte of TableB ($F2)
;   PtrLowA      $F06C  A = the low byte of TableA ($00)
;   PtrHighA     $F070  A = the high byte of TableA ($F1)
;   TableRead    $0083  A = the selected table byte, X = the line index
;   CallCount    $F0B9  A = 184
;
; RAM:
;   $80-$87  the 8-byte routine (copied from PtrTemplate)
;   $88      TableID    0 = TableA, 1 = TableB
;   $89      Calls      184 calls per frame
;   $8A      FrameNum   frames since reset
;   $8B      TableTimer the 60-frame switch divider
;   $8C-$9F  free
;   $F8-$FF  stack
;
; Build: acme -f plain -o build/lesson59-ex2.bin \
;        lessons/part8-advanced/59-self-modifying-code/exercise-02-solution.asm
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
GRADIENT_LINES = 184
SCREEN_LINES   = 192
SWITCH_FRAMES  = 60

C_BG           = $00
C_STATUS_A     = $0E
C_STATUS_B     = $1A

; -----------------------------------------------------------------------------
; RAM
; -----------------------------------------------------------------------------
RamRoutine   = $80           ; BD lo hi 85 09 85 02 60 (8 bytes)
TableID      = $88           ; 0 = TableA, 1 = TableB
Calls        = $89           ; 184 calls per frame
FrameNum     = $8A           ; frames since reset
TableTimer   = $8B           ; the 60-frame switch divider

; -----------------------------------------------------------------------------
; RESET
; -----------------------------------------------------------------------------
    * = $F000

Reset:
    +clean_start

; Copy eight bytes to $80.  X runs 7 down to 0.
    LDX #7
CopyRoutine:
    LDA PtrTemplate,X
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

; --- switch tables every 60 frames ------------------------------------------
    INC TableTimer
    LDA TableTimer
    CMP #SWITCH_FRAMES
    BCC NoSwitch
    LDA #$00
    STA TableTimer
    LDA TableID
    EOR #$01
    STA TableID
    BEQ SelectA
; --- TableB ----------------------------------------------------------------
    LDA #<TableB
PtrLowB:                     ; checkpoint: A = the low byte of TableB
    STA $81
    LDA #>TableB
PtrHighB:                    ; checkpoint: A = the high byte of TableB
    STA $82
    JMP SwitchDone
; --- TableA ----------------------------------------------------------------
SelectA:
    LDA #<TableA
PtrLowA:                     ; checkpoint: A = the low byte of TableA
    STA $81
    LDA #>TableA
PtrHighA:                    ; checkpoint: A = the high byte of TableA
    STA $82
SwitchDone:
NoSwitch:

; Load the first status field while the picture is still blanked.  PF1 must
; not race playfield chunk 4 on visible line 0.  +wait_timer preserves Y.
    LDA #C_BG
    STA COLUBK
    LDA #C_STATUS_A
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF2
    LDA TableID
    STA PF1
    LDY #4

    +wait_timer
    LDA #$00
    STA VBLANK

BodyStart:
    NOP                     ; one-time hit; StatusTable is the loop target
StatusTable:
    STA WSYNC
    DEY
    BNE StatusTable

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

; --- the 184-line gradient: X is the table index ---------------------------
; The loop is arranged so the last JSR runs with X = 183 (the last table
; entry) and returns directly into the overscan at scanline 229, cycle 6.
    LDX #0
GradientLoop:
    CPX #(GRADIENT_LINES - 1)
    BEQ LastLine
    JSR RamRoutine
    INX
    JMP GradientLoop
LastLine:
    LDA #GRADIENT_LINES
CallCount:                   ; checkpoint: A = 184
    STA Calls
    JSR RamRoutine           ; the 184th line, X = 183

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; -----------------------------------------------------------------------------
; THE TEMPLATE — the address operand is patched at $81/$82
; -----------------------------------------------------------------------------
PtrTemplate:
    !byte $BD, <TableA, >TableA   ; $80  LDA TableA,X (operands $81/$82)
    !byte $85, COLUBK              ; $83  STA COLUBK
    !byte $85, WSYNC               ; $85  STA WSYNC
    !byte $60                      ; $87  RTS

; -----------------------------------------------------------------------------
; TABLE A — the lesson's gradient
; -----------------------------------------------------------------------------
    !align 255, 0
TableA:
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
; TABLE B — the same colors rotated by 92 entries
; -----------------------------------------------------------------------------
; TableB[L] = TableA[(L + 92) mod 184].  The phase shift moves the bright
; middle of the gradient and changes every hue band's position.
    !align 255, 0
TableB:
    !byte $8E, $8E, $8E, $8E, $8E, $8E, $8E, $8E, $8E, $8E, $8E, $8E, $9E, $9E, $9E, $9E
    !byte $9E, $9E, $9E, $9E, $9E, $9E, $9E, $AE, $AC, $AC, $AC, $AC, $AC, $AC, $AC, $AC
    !byte $AC, $AC, $AC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BA, $BA, $BA, $BA, $CA, $CA
    !byte $CA, $CA, $CA, $CA, $CA, $CA, $CA, $C8, $C8, $C8, $D8, $D8, $D8, $D8, $D8, $D8
    !byte $D8, $D8, $D6, $D6, $D6, $E6, $E6, $E6, $E6, $E6, $E6, $E6, $E6, $E4, $E4, $E4
    !byte $E4, $F4, $F4, $F4, $F4, $F4, $F4, $F2, $F2, $F2, $F2, $F2, $02, $02, $02, $02
    !byte $02, $04, $04, $04, $04, $04, $04, $04, $14, $14, $14, $16, $16, $16, $16, $16
    !byte $16, $16, $16, $26, $26, $26, $28, $28, $28, $28, $28, $28, $28, $28, $28, $38
    !byte $38, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $4A, $4A, $4A, $4A, $4C, $4C
    !byte $4C, $4C, $4C, $4C, $4C, $4C, $5C, $5C, $5C, $5C, $5C, $5C, $5C, $5C, $5C, $5C
    !byte $5E, $6E, $6E, $6E, $6E, $6E, $6E, $6E, $6E, $6E, $6E, $6E, $6E, $7E, $7E, $7E
    !byte $7E, $7E, $7E, $7E, $7E, $7E, $7E, $7E

    !if * > $FFFA {
        !error "the data must end before $FFFA"
    }
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset, Reset, Reset
