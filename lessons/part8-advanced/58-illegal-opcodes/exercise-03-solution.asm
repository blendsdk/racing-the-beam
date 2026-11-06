; =============================================================================
; LESSON 58 — EXERCISE 3 SOLUTION: SAX Stores a Mask, LAX Loads It Back
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   SAX zp stores A AND X in one instruction (3 cycles); LAX zp loads the same
;   byte into both A and X (3 cycles).  The pair is a compact way to compute
;   and keep a mask:
;
;       LDA #$F0
;       LDX #$3C
;       +SAX_ZP Mask        ; Mask = $F0 & $3C = $30
;       +LAX_ZP Mask        ; A = X = $30
;
;   The screen is a 192-line proof:
;     visible   0-63   the "SAX" title block
;     visible  64-127  the result bar: chunks 2-3, 48 lines tall ($30)
;     visible 128-191  the two inputs: A = $F0 as PF1, X = $3C as PF2
;
;   The status band shows the inputs as eight-chunk fields; the bar shows the
;   masked result.  The state log proves the stored byte and the reload.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;
; ACME 0.97 has no SAX/LAX mnemonics under !cpu 6502; !cpu 6510 accepts them,
; but this course keeps !cpu 6502 and the named macros emit the opcode bytes so
; they stay visible: SAX $81 is $87 $81, LAX $81 is $A7 $81.
;
; RAM map ($80-$84; +clean_start zeroes every byte):
;   $80 InputA     the A input, $F0
;   $81 Mask       the SAX result, $30
;   $82 InputX     the X input, $3C
;   $83 ResultA    the LAX reload, $30
;   $84 ResultX    the LAX reload, $30
;   $85-$9F free
;   $F8-$FF stack
;
; Checkpoints: StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   OverscanStart (229/6), SaxStore (A = $F0, X = $3C),
;   SaxMem (A = $30), LaxLoad (A = $30, X = $30).
;
; Build: acme -f plain -o build/exercise-03.bin \
;        lessons/part8-advanced/58-illegal-opcodes/exercise-03-solution.asm
; Run:   stella build/exercise-03.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- the undocumented opcodes as named macros --------------------------------
!macro SAX_ZP .addr {
    !byte $87, .addr        ; SAX zp: M = A AND X
}
!macro LAX_ZP .addr {
    !byte $A7, .addr        ; LAX zp: A = M, X = M
}

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36

TITLE_LINES    = 16
TITLE_BLANK    = 48
BAR_LINES      = 64
STATUS_LINES   = 64

RESULT_VALUE   = $30     ; $F0 & $3C
BAR_START      = BAR_LINES - RESULT_VALUE   ; 64 - 48 = 16

C_BG           = $00
C_TITLE        = $1A
C_BAR          = $C8
C_STATUS       = $0E

; --- RAM ---------------------------------------------------------------------
InputA      = $80
Mask        = $81
InputX      = $82
ResultA     = $83
ResultX     = $84

    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA SWACNT

; --- the inputs ---------------------------------------------------------------
    LDA #$F0
    STA InputA
    LDX #$3C
    STX InputX

; --- SAX: M = A AND X --------------------------------------------------------
    +SAX_ZP Mask             ; ACME emits $87 $81
SaxStore:                    ; checkpoint: A = $F0, X = $3C
    LDA Mask
SaxMem:                      ; checkpoint: A = $30

; --- LAX: A = X = M ----------------------------------------------------------
    +LAX_ZP Mask             ; ACME emits $A7 $81
LaxLoad:                     ; checkpoint: A = $30, X = $30
    STA ResultA
    STX ResultX

; --- the TIA's fixed state ----------------------------------------------------
    LDA #C_BG
    STA COLUBK
    LDA #C_TITLE
    STA COLUPF
    LDA #$01
    STA CTRLPF
    LDA #$00
    STA NUSIZ0
    STA GRP0
    STA PF0
    STA PF1
    STA PF2

    JMP StartFrame

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                  ; checkpoint: scanline 259
    +vsync
VblankStart:                 ; checkpoint: scanline 0
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    +wait_timer
    LDA #$00
    STA VBLANK

; -----------------------------------------------------------------------------
; Zone 1: 64 title lines — the SAX block and 48 blanks
; -----------------------------------------------------------------------------
BodyStart:                   ; checkpoint: scanline 37, visible line 0
    LDA #C_TITLE
    STA COLUPF
    LDY #0
TitleRow:
    LDA TitlePF0,Y
    STA PF0
    LDA TitlePF1,Y
    STA PF1
    LDA TitlePF2,Y
    STA PF2
    STA WSYNC
    INY
    CPY #TITLE_LINES
    BNE TitleRow

    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #TITLE_BLANK
TitleBlank:
    STA WSYNC
    DEY
    BNE TitleBlank

; -----------------------------------------------------------------------------
; Zone 2: 64 lines — the 48-line result bar at chunks 2-3
; -----------------------------------------------------------------------------
    LDA #C_BAR
    STA COLUPF
    LDA #$00
    STA PF1
    STA PF2
    LDY #0
BarRow:
    LDA #$00
    STA PF0
    CPY #BAR_START
    BCC BarNoBar
    LDA #$C0
    STA PF0
BarNoBar:
    STA WSYNC
    INY
    CPY #BAR_LINES
    BNE BarRow

; -----------------------------------------------------------------------------
; Zone 3: 64 lines — the A and X inputs as eight-chunk fields
; -----------------------------------------------------------------------------
    LDA #C_STATUS
    STA COLUPF
    LDA InputA
    STA PF1                  ; A = $F0 at chunks 4-7
    LDA InputX
    STA PF2                  ; X = $3C at chunks 14-17
    LDA #$00
    STA PF0
    LDY #0
StatusRow:
    STA WSYNC
    INY
    CPY #STATUS_LINES
    BNE StatusRow

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:               ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; THE DATA
; =============================================================================
    !if * > $F800 {
        !error "the code must end before $F800"
    }
    !fill $F800 - *, $EA

; --- the 16-line "SAX" title --------------------------------------------------
TitlePF0:
    !byte $F0, $10, $90, $50, $50, $90, $10, $10
    !byte $D0, $10, $10, $10, $10, $10, $10, $F0
TitlePF1:
    !byte $FF, $00, $CC, $12, $12, $9E, $52, $52
    !byte $92, $00, $00, $00, $00, $00, $00, $FF
TitlePF2:
    !byte $FF, $80, $89, $89, $86, $86, $86, $89
    !byte $89, $80, $80, $80, $80, $80, $80, $FF

; -----------------------------------------------------------------------------
; The vectors
; -----------------------------------------------------------------------------
    !if * > $FFFA {
        !error "the data must end before $FFFA"
    }
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset, Reset, Reset
