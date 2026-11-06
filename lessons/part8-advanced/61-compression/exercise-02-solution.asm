; =============================================================================
; LESSON 61 — EXERCISE 2 SOLUTION
; A different RLE token scheme: a separate 2-byte run/literal opcode
; =============================================================================
; The exercise: implement a different RLE token scheme and compare its packed
; size with the lesson's scheme.
;
; The lesson's scheme folds the type into the count byte:
;   bit 7 = 1  run:   count-1 in bits 0-6, then the value
;   bit 7 = 0  literals: count-1 in bits 0-6, then the bytes
;
; This scheme uses a separate opcode byte and a separate count byte:
;   byte 0  opcode: $00 = run, $01 = literals
;   byte 1  count-1 (0..127)
;   byte 2  the run's value, or the first literal byte
;   ...     the remaining literal bytes
;
; The picture is the lesson's 576-byte logo image, re-encoded with the new
; scheme.  The lesson's stream is 214 bytes; this one is 257 bytes.  The
; difference is exactly one byte per token: 43 tokens, 43 extra opcode bytes.
; The comparison is the point: folding the type into the count byte is worth
; 43 bytes on this picture, a 20% saving.
;
; What the program shows:
;   A startup pass decodes the alternate stream, adds all 576 bytes and checks
;   the sum ($41, the same as the lesson).  The screen then compares the two
;   packed sizes as two horizontal bars, four bytes per scanline:
;     54 rows  the lesson's 214-byte stream
;     64 rows  this scheme's 257-byte stream
;   The second bar is striped so the two are easy to tell apart.
;
; The frame: 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;
; RAM map:
;   $80-$82  free
;   $83-$86  free
;   $87      Sum       the decoded checksum
;   $88-$89  Cnt       the decoded byte count (16 bits)
;   $8A-$8F  free
;   $90      AltValue  the current run's value
;   $91-$92  AltPtr    the alternate stream's 16-bit pointer
;   $93-$94  free
;   $F8-$FF  stack
;
; Build: acme -f plain -o build/exercise-02-solution.bin \
;        lessons/part8-advanced/61-compression/exercise-02-solution.asm
; The ROM is 4,096 bytes.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36

Sum      = $87
Cnt      = $88
AltValue = $90
AltPtr   = $91

; =============================================================================
; RESET — decode the alternate stream and set the TIA
; =============================================================================
    * = $F000
Reset:
    +clean_start
    LDA #$00
    STA COLUBK
    LDA #$0E
    STA COLUPF
    LDA #$01
    STA CTRLPF

    LDA #<AltStream
    STA AltPtr
    LDA #>AltStream
    STA AltPtr+1
    LDA #0
    STA Sum
    STA Cnt
    STA Cnt+1

AltNext:
    LDA Cnt
    CMP #$40
    BNE AltRead
    LDA Cnt+1
    CMP #$02
    BEQ AltDone
AltRead:
    JSR Fetch
    TAX
    BEQ AltRun              ; opcode 0 = run
    JSR Fetch               ; count-1
    TAX
    INX
AltLit:
    JSR Fetch
    CLC
    ADC Sum
    STA Sum
    INC Cnt
    BNE +
    INC Cnt+1
+   DEX
    BNE AltLit
    JMP AltNext
AltRun:
    JSR Fetch               ; count-1
    TAX
    INX
    JSR Fetch               ; value
    STA AltValue
AltRunLoop:
    LDA Sum
    CLC
    ADC AltValue
    STA Sum
    INC Cnt
    BNE +
    INC Cnt+1
+   DEX
    BNE AltRunLoop
    JMP AltNext
AltDone:
    LDA Sum
AltChecksum:                 ; checkpoint: A = $41 (the same 576 bytes)

    JMP StartFrame

; -----------------------------------------------------------------------------
; Fetch — return the next stream byte and advance the 16-bit pointer
; -----------------------------------------------------------------------------
; The alternate stream is 257 bytes, one byte longer than a page, so a single
; 8-bit index would wrap.  This helper carries Y into the pointer's high byte.
; It runs only at startup, where cycles do not matter.
Fetch:
    LDA (AltPtr),Y
    INY
    BNE +
    INC AltPtr+1
+   RTS

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:
    +vsync
VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    +wait_timer
    LDA #$00
    STA VBLANK

BodyStart:
; --- rows 0-3: the top border ------------------------------------------------
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    LDY #4
TopLoop:
    STA WSYNC
    DEY
    BNE TopLoop

; --- rows 4-15: blank --------------------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #12
Blank1:
    STA WSYNC
    DEY
    BNE Blank1

; --- rows 16-69: the lesson's 214-byte stream (54 rows) ----------------------
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    LDY #54
Bar1:
    STA WSYNC
    DEY
    BNE Bar1

; --- rows 70-77: blank -------------------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #8
Blank2:
    STA WSYNC
    DEY
    BNE Blank2

; --- rows 78-141: this scheme's 257-byte stream (64 rows, striped) ----------
    LDY #32
Bar2:
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    STA WSYNC
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
    DEY
    BNE Bar2

; --- rows 142-149: blank -----------------------------------------------------
    LDY #8
Blank3:
    STA WSYNC
    DEY
    BNE Blank3

; --- rows 150-151: a separator ----------------------------------------------
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    LDY #2
Sep:
    STA WSYNC
    DEY
    BNE Sep

; --- rows 152-191: blank -----------------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #40
Blank4:
    STA WSYNC
    DEY
    BNE Blank4

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; THE ALTERNATE STREAM — the lesson's 576-byte image, 257 bytes
; =============================================================================
; Each token is [opcode, count-1, data...]; opcode 0 is a run, 1 is literals.
    !align 255, 0
AltStream:
    !byte $00, $08, $FF, $00, $08, $00, $00, $0B
    !byte $FF, $00, $08, $00, $00, $05, $FF, $00
    !byte $08, $00, $00, $11, $FF, $00, $0B, $00
    !byte $01, $29, $80, $CF, $0E, $80, $CF, $0E
    !byte $80, $24, $12, $80, $24, $12, $80, $24
    !byte $12, $80, $24, $12, $80, $C4, $0E, $80
    !byte $C4, $0E, $80, $44, $12, $80, $44, $12
    !byte $80, $24, $12, $80, $24, $12, $80, $24
    !byte $0E, $80, $24, $0E, $00, $0B, $00, $00
    !byte $05, $FF, $00, $0B, $00, $00, $0B, $FF
    !byte $00, $08, $00, $00, $05, $FF, $00, $08
    !byte $00, $00, $11, $FF, $00, $0B, $00, $00
    !byte $05, $FF, $00, $11, $00, $01, $1D, $70
    !byte $AE, $52, $70, $AE, $52, $50, $A2, $52
    !byte $50, $A2, $52, $70, $CE, $72, $70, $CE
    !byte $72, $10, $A8, $42, $10, $A8, $42, $10
    !byte $AE, $42, $10, $AE, $42, $00, $0B, $00
    !byte $01, $1D, $70, $AE, $77, $70, $AE, $77
    !byte $50, $A8, $14, $50, $A8, $14, $70, $EE
    !byte $74, $70, $EE, $74, $30, $E2, $54, $30
    !byte $E2, $54, $50, $AE, $74, $50, $AE, $74
    !byte $00, $0B, $00, $01, $1D, $70, $AA, $02
    !byte $70, $AA, $02, $10, $AA, $02, $10, $AA
    !byte $02, $10, $CE, $02, $10, $CE, $02, $10
    !byte $A2, $02, $10, $A2, $02, $70, $A2, $02
    !byte $70, $A2, $02, $00, $11, $00, $00, $05
    !byte $FF, $00, $0E, $00, $00, $0B, $FF, $00
    !byte $08, $00, $00, $05, $FF, $00, $0E, $00
    !byte $00, $11, $FF, $00, $0B, $00, $00, $05
    !byte $FF, $00, $0E, $00, $00, $0B, $FF, $00
    !byte $08, $00, $00, $05, $FF, $00, $0E, $00
    !byte $00, $11, $FF, $00, $05, $00, $00, $11
    !byte $FF

    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset, Reset, Reset
