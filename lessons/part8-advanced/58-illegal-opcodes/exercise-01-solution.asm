; =============================================================================
; LESSON 58 — EXERCISE 1 SOLUTION: LAX Replaces LDA + TAX
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   The lesson's documented LDA $80 / TAX pair costs 5 cycles (3 + 2) and
;   leaves A = X = $42.  The undocumented LAX $80 costs 3 cycles and leaves
;   exactly the same A and X.  This solution runs both sequences at startup,
;   stores all four result bytes, and draws a 192-line proof:
;
;     visible   0-15   the "LAX" title block, a gold frame and 4-chunk glyphs
;     visible  16-55   blank
;     visible  56-63   the saved-cycle bar, two gold chunks (5 - 3 = 2)
;     visible  64-127  the documented row: A and X fields, a 5-line bar
;     visible 128-191  the LAX row: the same A and X fields, a 3-line bar
;
;   Both rows show the same A field (PF1 = $42) and X field (PF2 = $42), so
;   the two pictures are identical except for the cycle bar at chunks 2-3.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;
; ACME 0.97 has no LAX mnemonic under !cpu 6502; !cpu 6510 accepts it, but this
; course keeps !cpu 6502 and the named macro emits the opcode byte and the
; zero-page operand so the byte stays visible: LAX $80 is $A7 $80.
;
; RAM map ($80-$8B; +clean_start zeroes every byte):
;   $80 Input       the shared input, $42
;   $81 PairAVal    the documented pair's A, $42
;   $82 PairXVal    the documented pair's X, $42
;   $83 LaxAVal     LAX's A, $42
;   $84 LaxXVal     LAX's X, $42
;   $85 SavedCycles 5 - 3 = 2
;   $86-$9F free
;   $F8-$FF stack
;
; Checkpoints: StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   OverscanStart (229/6), PairA (A = $42), PairX (X = $42),
;   LaxRead (A = $42, X = $42), Saved (A = 2).
;
; Build: acme -f plain -o build/exercise-01.bin \
;        lessons/part8-advanced/58-illegal-opcodes/exercise-01-solution.asm
; Run:   stella build/exercise-01.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- the undocumented opcode as a named macro --------------------------------
!macro LAX_ZP .addr {
    !byte $A7, .addr        ; LAX zp: A = M, X = M
}

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36

TITLE_LINES    = 16
TITLE_BLANK    = 40
SAVED_LINES    = 8
ROW_LINES      = 64

C_BG           = $00
C_TITLE        = $1A
C_DOC          = $C8     ; green: the documented pair
C_LAX          = $1A     ; gold: the LAX replacement
C_WHITE        = $0E

; --- RAM ---------------------------------------------------------------------
Input       = $80
PairAVal    = $81
PairXVal    = $82
LaxAVal     = $83
LaxXVal     = $84
SavedCycles = $85

    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA SWACNT

    LDA #$42
    STA Input

; --- the documented pair: LDA $80 (3) + TAX (2) = 5 cycles -------------------
    LDA Input
PairA:                       ; checkpoint: A = $42
    TAX
PairX:                       ; checkpoint: X = $42
    STX PairXVal
    STA PairAVal             ; A is still $42

; --- the illegal replacement: LAX $80 (3 cycles) -----------------------------
    +LAX_ZP Input            ; ACME emits $A7 $80
LaxRead:                     ; checkpoint: A = $42, X = $42
    STA LaxAVal
    STX LaxXVal

; --- the saved cycles: 5 - 3 = 2 ---------------------------------------------
    LDA #2
Saved:                       ; checkpoint: A = 2
    STA SavedCycles

; --- the TIA's fixed state ----------------------------------------------------
    LDA #C_BG
    STA COLUBK
    LDA #C_TITLE
    STA COLUPF
    LDA #$01
    STA CTRLPF               ; reflect the playfield
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
; Zone 1: 64 title lines — the LAX block, 40 blanks, the saved-cycle bar
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

; --- 40 blank lines -----------------------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #TITLE_BLANK
TitleBlank:
    STA WSYNC
    DEY
    BNE TitleBlank

; --- 8 lines: the two-chunk saved-cycle bar -----------------------------------
    LDA #$C0
    STA PF0
    LDY #SAVED_LINES
SavedRow:
    STA WSYNC
    DEY
    BNE SavedRow
    LDA #$00
    STA PF0

; -----------------------------------------------------------------------------
; Zone 2: 64 lines — the documented pair: A and X fields, a 5-line bar
; -----------------------------------------------------------------------------
    LDA #C_DOC
    STA COLUPF
    LDA PairAVal
    STA PF1                  ; the A field, chunks 4-11
    LDA PairXVal
    STA PF2                  ; the X field, chunks 12-19
    LDY #0
DocRow:
    LDA #$00
    STA PF0
    CPY #(ROW_LINES - 5)
    BCC DocNoBar
    LDA #$C0                 ; five chunks? no: two chunks, five lines tall
    STA PF0
DocNoBar:
    STA WSYNC
    INY
    CPY #ROW_LINES
    BNE DocRow

; -----------------------------------------------------------------------------
; Zone 3: 64 lines — the LAX row: the same fields, a 3-line bar
; -----------------------------------------------------------------------------
    LDA #C_LAX
    STA COLUPF
    LDA LaxAVal
    STA PF1
    LDA LaxXVal
    STA PF2
    LDY #0
LaxRow:
    LDA #$00
    STA PF0
    CPY #(ROW_LINES - 3)
    BCC LaxNoBar
    LDA #$C0
    STA PF0
LaxNoBar:
    STA WSYNC
    INY
    CPY #ROW_LINES
    BNE LaxRow

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

; --- the 16-line "LAX" title: a gold frame and three 4-chunk glyphs ----------
TitlePF0:
    !byte $F0, $10, $50, $50, $50, $50, $50, $50
    !byte $D0, $10, $10, $10, $10, $10, $10, $F0
TitlePF1:
    !byte $FF, $00, $0C, $12, $12, $1E, $12, $12
    !byte $D2, $00, $00, $00, $00, $00, $00, $FF
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
