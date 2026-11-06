; =============================================================================
; LESSON 60 — EXERCISE 2 SOLUTION: An RNG Starfield — Racing the Beam
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   The DPC display image is used as a bank of eight 192-byte star planes.
;   Every frame the random generator picks three of them: one for DF0, one
;   for DF1 and one for DF2.  The three fetchers draw the playfield from the
;   three chosen planes, so the screen is a full 20-bit starfield that
;   changes as the RNG advances.  A small white ship (player 0)
;   sits at x=40.
;
; Why this is the exercise:
;   The lesson program uses the padding of the 2K image for three extra PF2
;   twinkle planes.  This solution makes the whole image a pattern bank:
;   eight planes at offsets 0, 192, 384, 576, 768, 960, 1152 and 1344.
;   The RNG then selects the plane each fetcher reads.  That is the same
;   idea as the lesson's twinkle, applied to all three fetchers at once.
;
; The 10K layout:
;   file offset $0000-$0FFF   bank 0, real $C000, !pseudopc $F000
;   file offset $1000-$1FFF   bank 1, real $D000, !pseudopc $F000
;   file offset $2000-$27FF   the 2K display image, real $E000-$E7FF
; DPC starts in bank 1; the entry is $F080 because the first 128 bytes of
; every 4K bank are the mirrored DPC register window.  Bank 0 is the same
; switch stub as the lesson's.
;
; The plane counters (display[2047 - counter]):
;   plane 0 offset    0 -> counter 2047 = $07FF
;   plane 1 offset  192 -> counter 1855 = $073F
;   plane 2 offset  384 -> counter 1663 = $067F
;   plane 3 offset  576 -> counter 1471 = $05BF
;   plane 4 offset  768 -> counter 1279 = $04FF
;   plane 5 offset  960 -> counter 1087 = $043F
;   plane 6 offset 1152 -> counter  895 = $037F
;   plane 7 offset 1344 -> counter  703 = $02BF
;
; Every frame:
;   DF0 reads plane  Rng & 7
;   DF1 reads plane (Rng >> 3) & 7
;   DF2 reads plane 4 + ((Rng >> 6) & 3)
; The three fetchers decrement their counters once per line, so the three
; planes stay aligned.  Plane 0 and plane 1 are not used by DF2 (the upper
; half of the bank is), so the three choices are spread across the bank.
;
; Frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;   One HMOVE, inside VBLANK, positions player 0.
;
; The 1-line kernel (38 cycles of 76, including the 7-cycle loop tail):
;   loop tail       7
;   LDA $1008       4   fetch the DF0 star plane byte
;   STA PF0         3
;   LDA $1009       4   fetch the DF1 star plane byte
;   STA PF1         3
;   LDA $100A       4   fetch the DF2 star plane byte
;   STA PF2         3
;   LDA Probe,Y     4
;   STA GRP0        3   the ship
;   STA WSYNC       3
; The three PF writes land on cycles 13, 20 and 27, before the beam reaches
; PF0, PF1 and PF2 at cycles ~23, 28 and ~38.7.
;
; Checkpoints:
;   Reset ($F080), Main, StartFrame (259/3), VblankStart (0/5),
;   BodyStart (37/5), OverscanStart (229/6), Line,
;   Fetch0/Fetch1/Fetch2 (A = the fetched plane byte),
;   RngRead (A = the random byte), Frame (A = FrameCount).
;
; RAM map:
;   $80  FrameCount
;   $81  StarPtr    the DF0 plane counter low byte
;   $82  Twinkle    the RNG byte latched for this frame
;   $83  Rng        the raw read of $1000
;   $84-$9F free
;   $F8-$FF stack
;
; Build: acme -f plain -o build/exercise-02-solution.bin \
;        lessons/part8-advanced/60-dpc-plus/exercise-02-solution.asm
; Run:   stella build/exercise-02-solution.bin
; The ROM is 10,240 bytes and Stella reports DPC* (10K).
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
POS_BIAS       = 3
SCREEN_LINES   = 192
PLAYER_X       = 40

DPC_RNG        = $1000
DPC_DF0        = $1008
DPC_DF1        = $1009
DPC_DF2        = $100A
DPC_DF0_TOP    = $1040
DPC_DF1_TOP    = $1041
DPC_DF2_TOP    = $1042
DPC_DF0_BOTTOM = $1048
DPC_DF1_BOTTOM = $1049
DPC_DF2_BOTTOM = $104A
DPC_DF0_LO     = $1050
DPC_DF1_LO     = $1051
DPC_DF2_LO     = $1052
DPC_DF0_HI     = $1058
DPC_DF1_HI     = $1059
DPC_DF2_HI     = $105A
DPC_RNG_RESET  = $1070

PhaseLo        = $F2F0
PhaseHi        = $F2F8
Probe          = $F400

FrameCount     = $80
StarPtr        = $81
Twinkle        = $82
Rng            = $83

    * = $C000
    !pseudopc $F000 {
    !fill 128, $EA
Bank0Entry:
    LDA $1FF9
    JMP $F080
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Bank0Entry, Bank0Entry, Bank0Entry
}

    * = $D000
    !pseudopc $F000 {
    !fill 128, $EA
Reset:
    JMP Init
    JMP Init
Init:
    +clean_start
    LDA #$00
    STA SWACNT
    LDA #$02
    STA VBLANK
    LDA #$AE
    STA COLUPF               ; cyan stars
    LDA #$00
    STA COLUBK               ; black space
    LDA #$0E
    STA COLUP0               ; white ship
    LDA #$01
    STA CTRLPF               ; reflect: a wider starfield
    LDA #$00
    STA DPC_RNG_RESET
    JMP Main

Main:
    NOP
StartFrame:
    +vsync
VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    LDA DPC_RNG
RngRead:
    STA Rng
    STA Twinkle

    LDA #$FF
    STA DPC_DF0_TOP
    STA DPC_DF1_TOP
    STA DPC_DF2_TOP
    LDA #$00
    STA DPC_DF0_BOTTOM
    STA DPC_DF1_BOTTOM
    STA DPC_DF2_BOTTOM

; --- DF0: plane Rng & 7 ------------------------------------------------------
    LDA Twinkle
    AND #$07
    TAX
    LDA PhaseLo,X
    STA StarPtr
    STA DPC_DF0_LO
    LDA PhaseHi,X
    STA DPC_DF0_HI

; --- DF1: plane (Rng >> 3) & 7 ----------------------------------------------
    LDA Twinkle
    LSR
    LSR
    LSR
    AND #$07
    TAX
    LDA PhaseLo,X
    STA DPC_DF1_LO
    LDA PhaseHi,X
    STA DPC_DF1_HI

; --- DF2: plane 4 + ((Rng >> 6) & 3) ----------------------------------------
    LDA Twinkle
    LSR
    LSR
    LSR
    LSR
    LSR
    LSR
    AND #$03
    CLC
    ADC #$04
    TAX
    LDA PhaseLo,X
    STA DPC_DF2_LO
    LDA PhaseHi,X
    STA DPC_DF2_HI

    INC FrameCount
    LDA FrameCount
Frame:

    LDA #(PLAYER_X + POS_BIAS)
    JSR SetCoarseP0
    STA WSYNC
    STA HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK

BodyStart:
    LDY #0
Line:
    LDA DPC_DF0
Fetch0:
    STA PF0
    LDA DPC_DF1
Fetch1:
    STA PF1
    LDA DPC_DF2
Fetch2:
    STA PF2
    LDA Probe,Y
    STA GRP0
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE Line

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

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

    !if * > PhaseLo {
        !error "bank 1's code must end before PhaseLo"
    }
    !fill PhaseLo - *, $EA
PhaseLo:
    !byte $FF, $3F, $7F, $BF, $FF, $3F, $7F, $BF
    !fill PhaseHi - *, $EA
PhaseHi:
    !byte $07, $07, $06, $05, $04, $04, $03, $02

    !fill Probe - *, $EA
Probe:
    !fill 90, $00
    !byte $18   ; row 90
    !byte $3C   ; row 91
    !byte $7E   ; row 92
    !byte $FF   ; row 93
    !byte $FF   ; row 94
    !byte $7E   ; row 95
    !byte $3C   ; row 96
    !byte $18   ; row 97
    !fill 94, $00
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset, Reset, Reset
}

    * = $E000
DisplayImage:
; --- star plane 0: display offset 0 ------------------------------
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 0-7
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 8-15
    !byte $01, $00, $00, $00, $00, $00, $40, $00   ; rows 16-23
    !byte $00, $02, $00, $00, $00, $80, $00, $00   ; rows 24-31
    !byte $00, $00, $00, $01, $00, $00, $00, $08   ; rows 32-39
    !byte $00, $00, $08, $00, $00, $00, $00, $04   ; rows 40-47
    !byte $00, $00, $00, $00, $00, $08, $00, $00   ; rows 48-55
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 56-63
    !byte $00, $00, $00, $00, $00, $10, $01, $00   ; rows 64-71
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 72-79
    !byte $00, $00, $00, $00, $01, $00, $00, $00   ; rows 80-87
    !byte $00, $00, $00, $00, $00, $00, $10, $00   ; rows 88-95
    !byte $00, $00, $00, $04, $00, $00, $00, $00   ; rows 96-103
    !byte $01, $00, $00, $00, $00, $00, $00, $00   ; rows 104-111
    !byte $00, $00, $00, $00, $00, $10, $00, $00   ; rows 112-119
    !byte $00, $00, $00, $40, $00, $00, $00, $00   ; rows 120-127
    !byte $00, $80, $00, $00, $00, $00, $00, $00   ; rows 128-135
    !byte $80, $00, $00, $01, $00, $01, $00, $00   ; rows 136-143
    !byte $01, $00, $00, $00, $00, $00, $00, $00   ; rows 144-151
    !byte $00, $00, $00, $80, $42, $20, $00, $00   ; rows 152-159
    !byte $00, $00, $00, $40, $00, $00, $00, $00   ; rows 160-167
    !byte $01, $00, $00, $0A, $00, $01, $00, $04   ; rows 168-175
    !byte $00, $08, $00, $00, $00, $00, $00, $00   ; rows 176-183
    !byte $00, $00, $00, $80, $00, $00, $00, $00   ; rows 184-191
; --- star plane 1: display offset 192 ------------------------------
    !byte $00, $00, $08, $00, $00, $00, $00, $00   ; rows 0-7
    !byte $00, $08, $00, $00, $00, $00, $00, $00   ; rows 8-15
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 16-23
    !byte $00, $00, $00, $40, $00, $00, $00, $00   ; rows 24-31
    !byte $00, $20, $00, $00, $00, $00, $00, $00   ; rows 32-39
    !byte $00, $00, $00, $00, $00, $00, $00, $08   ; rows 40-47
    !byte $04, $00, $08, $00, $00, $00, $00, $00   ; rows 48-55
    !byte $00, $00, $00, $00, $00, $00, $08, $00   ; rows 56-63
    !byte $21, $00, $10, $00, $00, $00, $02, $00   ; rows 64-71
    !byte $04, $00, $00, $00, $00, $00, $40, $04   ; rows 72-79
    !byte $00, $00, $00, $12, $00, $04, $00, $00   ; rows 80-87
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 88-95
    !byte $20, $00, $00, $00, $40, $00, $00, $00   ; rows 96-103
    !byte $00, $00, $00, $00, $80, $00, $00, $00   ; rows 104-111
    !byte $00, $00, $02, $00, $00, $01, $00, $01   ; rows 112-119
    !byte $00, $00, $00, $00, $04, $10, $00, $00   ; rows 120-127
    !byte $02, $00, $00, $00, $00, $00, $00, $00   ; rows 128-135
    !byte $00, $00, $00, $00, $40, $00, $00, $01   ; rows 136-143
    !byte $00, $40, $00, $00, $00, $00, $00, $00   ; rows 144-151
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 152-159
    !byte $00, $08, $00, $00, $00, $00, $00, $40   ; rows 160-167
    !byte $00, $00, $00, $00, $02, $00, $00, $00   ; rows 168-175
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 176-183
    !byte $00, $00, $00, $00, $10, $00, $00, $00   ; rows 184-191
; --- star plane 2: display offset 384 ------------------------------
    !byte $00, $00, $80, $00, $00, $00, $08, $00   ; rows 0-7
    !byte $00, $00, $00, $00, $80, $00, $00, $01   ; rows 8-15
    !byte $00, $04, $00, $00, $00, $00, $00, $00   ; rows 16-23
    !byte $00, $00, $00, $10, $20, $00, $00, $00   ; rows 24-31
    !byte $00, $10, $00, $00, $00, $00, $00, $00   ; rows 32-39
    !byte $00, $00, $00, $80, $00, $00, $00, $00   ; rows 40-47
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 48-55
    !byte $40, $40, $00, $00, $00, $00, $00, $00   ; rows 56-63
    !byte $00, $00, $00, $20, $00, $80, $00, $00   ; rows 64-71
    !byte $00, $00, $00, $00, $02, $00, $00, $00   ; rows 72-79
    !byte $00, $01, $00, $00, $00, $00, $00, $00   ; rows 80-87
    !byte $00, $00, $04, $00, $00, $00, $00, $00   ; rows 88-95
    !byte $84, $00, $00, $00, $00, $00, $03, $00   ; rows 96-103
    !byte $00, $20, $00, $00, $00, $00, $04, $00   ; rows 104-111
    !byte $00, $00, $00, $02, $00, $00, $00, $00   ; rows 112-119
    !byte $00, $00, $00, $00, $10, $00, $00, $00   ; rows 120-127
    !byte $00, $20, $00, $00, $00, $00, $00, $08   ; rows 128-135
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 136-143
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 144-151
    !byte $00, $00, $00, $00, $A0, $00, $00, $02   ; rows 152-159
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 160-167
    !byte $10, $00, $00, $00, $00, $00, $00, $10   ; rows 168-175
    !byte $00, $00, $00, $00, $00, $00, $04, $00   ; rows 176-183
    !byte $04, $00, $00, $00, $00, $00, $04, $00   ; rows 184-191
; --- star plane 3: display offset 576 ------------------------------
    !byte $00, $00, $00, $00, $00, $00, $00, $0C   ; rows 0-7
    !byte $20, $00, $80, $02, $00, $08, $00, $00   ; rows 8-15
    !byte $00, $01, $00, $00, $00, $08, $00, $00   ; rows 16-23
    !byte $00, $00, $00, $00, $40, $00, $00, $00   ; rows 24-31
    !byte $10, $00, $00, $08, $02, $00, $00, $08   ; rows 32-39
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 40-47
    !byte $00, $00, $00, $80, $00, $00, $00, $00   ; rows 48-55
    !byte $00, $00, $00, $00, $80, $00, $00, $00   ; rows 56-63
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 64-71
    !byte $01, $00, $00, $40, $00, $00, $00, $00   ; rows 72-79
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 80-87
    !byte $00, $00, $00, $80, $00, $00, $10, $40   ; rows 88-95
    !byte $00, $00, $00, $00, $00, $80, $00, $00   ; rows 96-103
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 104-111
    !byte $00, $00, $00, $00, $00, $00, $00, $40   ; rows 112-119
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 120-127
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 128-135
    !byte $00, $00, $08, $00, $00, $00, $02, $00   ; rows 136-143
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 144-151
    !byte $20, $01, $00, $00, $00, $00, $00, $00   ; rows 152-159
    !byte $20, $00, $40, $00, $00, $00, $00, $00   ; rows 160-167
    !byte $00, $00, $00, $00, $00, $00, $20, $00   ; rows 168-175
    !byte $04, $40, $00, $00, $00, $00, $00, $40   ; rows 176-183
    !byte $00, $00, $00, $00, $00, $00, $00, $22   ; rows 184-191
; --- star plane 4: display offset 768 ------------------------------
    !byte $00, $00, $02, $00, $02, $80, $00, $00   ; rows 0-7
    !byte $03, $00, $00, $00, $00, $00, $00, $00   ; rows 8-15
    !byte $00, $00, $02, $00, $00, $00, $00, $00   ; rows 16-23
    !byte $00, $80, $00, $00, $00, $00, $00, $00   ; rows 24-31
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 32-39
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 40-47
    !byte $00, $00, $01, $00, $00, $00, $00, $00   ; rows 48-55
    !byte $00, $00, $08, $00, $00, $00, $08, $08   ; rows 56-63
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 64-71
    !byte $00, $00, $10, $00, $00, $00, $00, $00   ; rows 72-79
    !byte $02, $00, $00, $00, $00, $00, $00, $00   ; rows 80-87
    !byte $00, $00, $00, $00, $04, $40, $00, $00   ; rows 88-95
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 96-103
    !byte $00, $00, $00, $00, $08, $88, $00, $01   ; rows 104-111
    !byte $00, $00, $00, $00, $00, $10, $00, $00   ; rows 112-119
    !byte $00, $00, $00, $00, $00, $00, $00, $04   ; rows 120-127
    !byte $00, $00, $00, $00, $00, $40, $00, $00   ; rows 128-135
    !byte $08, $00, $00, $00, $00, $04, $00, $40   ; rows 136-143
    !byte $01, $00, $00, $04, $01, $00, $00, $00   ; rows 144-151
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 152-159
    !byte $80, $00, $00, $00, $20, $40, $00, $00   ; rows 160-167
    !byte $00, $00, $00, $20, $00, $00, $00, $00   ; rows 168-175
    !byte $00, $00, $02, $00, $00, $00, $00, $00   ; rows 176-183
    !byte $00, $00, $00, $00, $00, $00, $00, $01   ; rows 184-191
; --- star plane 5: display offset 960 ------------------------------
    !byte $08, $00, $08, $04, $00, $00, $00, $40   ; rows 0-7
    !byte $00, $00, $00, $00, $00, $00, $02, $00   ; rows 8-15
    !byte $00, $00, $00, $00, $00, $00, $00, $28   ; rows 16-23
    !byte $00, $00, $20, $00, $00, $00, $00, $60   ; rows 24-31
    !byte $04, $00, $00, $08, $00, $00, $02, $00   ; rows 32-39
    !byte $40, $00, $00, $00, $00, $00, $00, $00   ; rows 40-47
    !byte $20, $00, $40, $00, $00, $00, $00, $00   ; rows 48-55
    !byte $00, $00, $00, $00, $00, $00, $40, $02   ; rows 56-63
    !byte $00, $00, $00, $00, $00, $00, $00, $08   ; rows 64-71
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 72-79
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 80-87
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 88-95
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 96-103
    !byte $00, $00, $00, $00, $10, $00, $00, $02   ; rows 104-111
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 112-119
    !byte $00, $00, $00, $40, $00, $00, $00, $00   ; rows 120-127
    !byte $00, $00, $00, $00, $03, $80, $01, $00   ; rows 128-135
    !byte $01, $00, $00, $00, $00, $00, $00, $00   ; rows 136-143
    !byte $00, $00, $00, $00, $10, $00, $00, $00   ; rows 144-151
    !byte $00, $00, $00, $00, $00, $00, $02, $84   ; rows 152-159
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 160-167
    !byte $00, $00, $00, $00, $00, $00, $10, $10   ; rows 168-175
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 176-183
    !byte $00, $00, $00, $00, $00, $08, $00, $00   ; rows 184-191
; --- star plane 6: display offset 1152 ------------------------------
    !byte $00, $00, $01, $00, $00, $00, $00, $10   ; rows 0-7
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 8-15
    !byte $00, $40, $00, $00, $00, $00, $00, $00   ; rows 16-23
    !byte $02, $00, $00, $00, $02, $00, $00, $00   ; rows 24-31
    !byte $00, $00, $00, $00, $00, $04, $00, $00   ; rows 32-39
    !byte $00, $00, $00, $00, $00, $00, $00, $61   ; rows 40-47
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 48-55
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 56-63
    !byte $00, $20, $00, $00, $00, $04, $00, $20   ; rows 64-71
    !byte $20, $00, $00, $00, $00, $00, $00, $02   ; rows 72-79
    !byte $02, $00, $00, $00, $00, $00, $00, $00   ; rows 80-87
    !byte $40, $00, $00, $00, $00, $00, $01, $00   ; rows 88-95
    !byte $00, $10, $00, $00, $00, $00, $00, $00   ; rows 96-103
    !byte $00, $40, $00, $00, $00, $00, $00, $00   ; rows 104-111
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 112-119
    !byte $00, $00, $00, $00, $00, $10, $00, $00   ; rows 120-127
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 128-135
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 136-143
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 144-151
    !byte $00, $00, $00, $00, $00, $02, $00, $00   ; rows 152-159
    !byte $80, $00, $20, $00, $00, $00, $00, $08   ; rows 160-167
    !byte $80, $00, $80, $00, $00, $00, $00, $00   ; rows 168-175
    !byte $00, $00, $00, $40, $00, $20, $00, $04   ; rows 176-183
    !byte $00, $41, $00, $80, $01, $40, $00, $00   ; rows 184-191
; --- star plane 7: display offset 1344 ------------------------------
    !byte $01, $00, $00, $00, $00, $00, $01, $00   ; rows 0-7
    !byte $00, $00, $40, $00, $00, $00, $00, $00   ; rows 8-15
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 16-23
    !byte $00, $00, $00, $00, $00, $80, $00, $01   ; rows 24-31
    !byte $00, $00, $10, $00, $00, $00, $00, $00   ; rows 32-39
    !byte $00, $00, $04, $01, $00, $00, $00, $00   ; rows 40-47
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 48-55
    !byte $00, $02, $04, $00, $04, $00, $08, $00   ; rows 56-63
    !byte $00, $00, $00, $00, $40, $00, $00, $00   ; rows 64-71
    !byte $00, $00, $80, $40, $00, $00, $01, $00   ; rows 72-79
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 80-87
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 88-95
    !byte $00, $00, $00, $00, $00, $02, $00, $00   ; rows 96-103
    !byte $00, $00, $00, $00, $00, $08, $00, $00   ; rows 104-111
    !byte $00, $00, $00, $00, $00, $00, $00, $04   ; rows 112-119
    !byte $00, $00, $00, $10, $00, $00, $00, $04   ; rows 120-127
    !byte $04, $00, $00, $10, $00, $00, $00, $00   ; rows 128-135
    !byte $00, $00, $00, $00, $00, $00, $00, $80   ; rows 136-143
    !byte $00, $10, $00, $00, $80, $0A, $00, $00   ; rows 144-151
    !byte $50, $00, $00, $00, $00, $00, $00, $00   ; rows 152-159
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 160-167
    !byte $40, $00, $40, $00, $00, $02, $00, $00   ; rows 168-175
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 176-183
    !byte $00, $00, $00, $00, $00, $00, $00, $80   ; rows 184-191
    !fill 2048 - (* - DisplayImage), $00
