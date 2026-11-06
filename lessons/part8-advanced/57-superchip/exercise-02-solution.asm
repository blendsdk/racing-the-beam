; =============================================================================
; LESSON 57 — EXERCISE 2 SOLUTION: The 128-Byte Strip — Racing the Beam
; =============================================================================
; Part 8: Advanced Topics
;
; EXERCISE 2: use the 128 bytes as a 16-row x 8-byte sprite/playfield strip
;   and draw it.
;
;   The ROM table Strip holds 16 rows of 8 bytes (128 bytes).  The init loop
;   copies it into the Superchip RAM through the write window:
;
;       Strip + X  ->  $1000 + X     for X = 0..127
;
;   The visible kernel then reads the bytes back through the read window and
;   draws one byte per scanline as PF2:
;
;       StripRow: LDA $1080,Y        ; one 8-chunk PF2 pattern per line
;                 STA PF2
;                 STA WSYNC
;                 INY
;                 CPY #128
;                 BNE StripRow
;
;   The 16 rows of the table become 16 bands of eight scanlines.  Each band's
;   eight bytes step one chunk to the right, so the picture is a diagonal
;   weave 8 chunks wide (32 TIA pixels, reflected to 64).
;
;   The status band keeps the lesson's SC label and 16-cell gauge, and the
;   init sets GaugeLo and GaugeHi to $FF because all 128 bytes were written.
;   The marker is the lesson's P0 diamond, positioned with one HMOVE.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;   Visible lines: 8 status + 128 strip + 56 marker/background = 192.
;
; Checkpoints:
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   OverscanStart (229/6), Frame (A = the frame count);
;   StripRead (A = the byte read from $1080,Y, Y = the strip line 0..127);
;   StripDone (Y = 128; A = $00 from the loop's PF clear);
;   GaugeAll (A = $FF, all 16 cells lit).
;
; RAM map (RIOT):
;   $80 FrameCount  frames since reset, wraps at 256
;   $85 GaugeLo     gauge cells 8-15 (the exercise sets $FF)
;   $86 GaugeHi     gauge cells 0-7  (the exercise sets $FF)
;   $F8-$FF stack
;
; Build: acme -f plain -o build/exercise-02.bin \
;        lessons/part8-advanced/57-superchip/exercise-02-solution.asm
; Run:   stella build/exercise-02.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan
POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

SCREEN_LINES   = 192     ; every frame draws 192 visible lines
STATUS_LINES   = 8       ; the SC label and gauge band
STRIP_LINES    = 128     ; the 16 x 8 strip, one byte per line
PLAY_LINES     = 184     ; 192 - 8 status lines
MARKER_TOP     = 152     ; the marker's first play row
MARKER_X_BASE  = 24      ; the sweep's left edge, TIA X 24..87

C_BG           = $00     ; black
C_STATUS       = $C8     ; green SC label and gauge
C_MARK         = $1A     ; gold marker

!if STATUS_LINES + PLAY_LINES != SCREEN_LINES {
    !error "the status band plus the play area must total 192 lines"
}
!if STRIP_LINES > PLAY_LINES {
    !error "the strip must fit in the play area"
}

; =============================================================================
; RAM
; =============================================================================
FrameCount  = $80
GaugeLo     = $85
GaugeHi     = $86

; =============================================================================
; BANK 0 — real $E000, virtual $F000.  The reset-only bank.
; =============================================================================
    * = $E000
    !pseudopc $F000 {
    !fill 128, $EA
    !fill 128, $EA
    * = $F100
Bank0Entry:
    LDA $1FF9               ; select bank 1
    JMP $F106
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Bank0Entry, Bank0Entry, Bank0Entry
}

; =============================================================================
; BANK 1 — real $F000, virtual $F000.  The strip.
; =============================================================================
    * = $F000
    !pseudopc $F000 {
    !fill 128, $EA
    !fill 128, $EA
    * = $F100
Entry:
    LDA $1FF9               ; select bank 1
    JMP $F106

Init:
    +clean_start
    LDA #$00
    STA SWACNT

; --- copy the 128-byte strip into the Superchip RAM --------------------------
    LDX #0
CopyStrip:
    LDA Strip,X
    STA $1000,X             ; the write window
    INX
    CPX #STRIP_LINES
    BNE CopyStrip
    LDA #$FF
GaugeAll:                   ; checkpoint: A = $FF, all 16 cells lit
    STA GaugeLo             ; all 16 cells, because all 128 bytes were written
    STA GaugeHi

; --- the TIA's fixed state ---------------------------------------------------
    LDA #C_BG
    STA COLUBK
    LDA #C_STATUS
    STA COLUPF
    LDA #C_MARK
    STA COLUP0
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
StartFrame:                 ; checkpoint: scanline 259
    +vsync

VblankStart:                ; checkpoint: scanline 0
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    LDA #C_STATUS
    STA COLUPF
    LDA #C_MARK
    STA COLUP0

    INC FrameCount
    LDA FrameCount
Frame:                      ; checkpoint: A = the new frame count

    AND #$3F
    CLC
    ADC #(MARKER_X_BASE + POS_BIAS)
    JSR SetCoarseP0
    STA WSYNC
    STA HMOVE               ; the frame's only HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK

; --- 8 status lines: SC and the full gauge -----------------------------------
BodyStart:                  ; checkpoint: scanline 37
    LDY #0
StatusRow:
    LDA ScRow,Y
    STA PF0
    LDA GaugeHi
    STA PF1
    LDA GaugeLo
    STA PF2
    STA WSYNC
    INY
    CPY #7
    BNE StatusRow
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    STA WSYNC

; --- 128 lines: one byte per line, read through $1080 ------------------------
    LDY #0
StripRow:
    LDA $1080,Y             ; the read window
StripRead:                  ; checkpoint: A = the byte, Y = the line
    STA PF2
    LDA #$00
    STA PF0
    STA PF1
    STA WSYNC
    INY
    CPY #STRIP_LINES
    BNE StripRow
StripDone:                  ; checkpoint: Y = 128; A = $00 from the PF clear

; --- the rest of the play area: background and the marker --------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
MarkerRow:
    LDA MarkerStrip,Y
    STA GRP0
    STA WSYNC
    INY
    CPY #PLAY_LINES
    BNE MarkerRow

; =============================================================================
; FRAME END
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SetCoarseP0 — the Lesson 26 divide-by-15 dance
; =============================================================================
; A = the desired left edge + POS_BIAS.  Each loop pass is 5 cycles = 15
; colour clocks, which is why dividing by 15 works.  The remainder becomes
; HMP0's fine value and RESP0 strobes the coarse position.
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

; =============================================================================
; THE DATA
; =============================================================================
    !if * > $F400 {
        !error "bank 1's code must end before $F400"
    }
    !fill $F400 - *, $EA

; --- the SC label ------------------------------------------------------------
ScRow:
    !byte $F0, $50, $50, $70, $60, $60, $F0

; --- the 16 x 8 strip --------------------------------------------------------
; Row r holds eight bytes; byte b is one scanline whose PF2 pattern is one
; chunk, stepped by r + b.  The 16 rows therefore draw a diagonal weave of
; 16 bands, eight lines each.
Strip:
    !byte $01,$02,$04,$08,$10,$20,$40,$80   ; row 0
    !byte $02,$04,$08,$10,$20,$40,$80,$01   ; row 1
    !byte $04,$08,$10,$20,$40,$80,$01,$02   ; row 2
    !byte $08,$10,$20,$40,$80,$01,$02,$04   ; row 3
    !byte $10,$20,$40,$80,$01,$02,$04,$08   ; row 4
    !byte $20,$40,$80,$01,$02,$04,$08,$10   ; row 5
    !byte $40,$80,$01,$02,$04,$08,$10,$20   ; row 6
    !byte $80,$01,$02,$04,$08,$10,$20,$40   ; row 7
    !byte $01,$02,$04,$08,$10,$20,$40,$80   ; row 8
    !byte $02,$04,$08,$10,$20,$40,$80,$01   ; row 9
    !byte $04,$08,$10,$20,$40,$80,$01,$02   ; row 10
    !byte $08,$10,$20,$40,$80,$01,$02,$04   ; row 11
    !byte $10,$20,$40,$80,$01,$02,$04,$08   ; row 12
    !byte $20,$40,$80,$01,$02,$04,$08,$10   ; row 13
    !byte $40,$80,$01,$02,$04,$08,$10,$20   ; row 14
    !byte $80,$01,$02,$04,$08,$10,$20,$40   ; row 15

; --- the marker strip --------------------------------------------------------
MarkerStrip:
    !fill MARKER_TOP, $00
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !fill PLAY_LINES - MARKER_TOP - 8, $00

    !if * > $FFFA {
        !error "bank 1's data must end before $FFFA"
    }
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Entry, Entry, Entry
}
