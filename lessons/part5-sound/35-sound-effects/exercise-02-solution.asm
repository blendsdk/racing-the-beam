; =============================================================================
; LESSON 35 — EXERCISE 2 SOLUTION: Siren Boop
; =============================================================================
; Part 5: Sound
;
; Exercise: replace the BOOP's one-way sweep with a two-pitch siren.  AUDF 6
; for four frames, AUDF 20 for four frames, repeating; the volume envelope is
; unchanged.
;
; The technique: test bit 2 of the effect frame.  The low and high pitches are
; four frames apart, so the marker jumps between X=48 and X=104.
;
; Build: acme -f plain -o build/lesson35-ex2.bin \
;        lessons/part5-sound/35-sound-effects/exercise-02-solution.asm
; Run:   stella build/lesson35-ex2.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
METER_X        = 24
POS_BIAS       = 3

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
EffectID    = $80   ; 0 = BEEP, 1 = BOOP, 2 = BOOM
EffectFrame = $81   ; 0 .. EffectLen-1; starts at $FF so the first INC is 0
Volume      = $82   ; the current AUDV value, for the meter
Pitch       = $83   ; the current AUDF value, for the marker
EffectColor = $84   ; the active effect's color, for the band/meter/marker

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$FF
    STA EffectFrame         ; the first VBLANK increment makes this 0
    LDA #$00
    STA EffectID

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- advance to the next effect when the current one ends ---
    INC EffectFrame
    LDX EffectID
    LDA EffectLen,X
    CMP EffectFrame
    BNE NoEffectStep
    LDA #$00
    STA EffectFrame
    INC EffectID
    LDA EffectID
    CMP #3
    BCC StoreEffect
    LDA #$00
StoreEffect:
EffectStep:                 ; checkpoint: A = the new effect ID
    STA EffectID
NoEffectStep:

; --- the generator is shared; the effect routines pick pitch and volume ---
    LDX EffectID
    LDA EffectCtl,X
    STA AUDC0
CtlWrite:                   ; checkpoint: A = AUDC

    LDA EffectID
    CMP #0
    BEQ Beep
    CMP #1
    BEQ Boop
    JMP Boom

Beep:
    LDA #$13                ; AUDF 19 = 261.66 Hz on div 6
    STA Pitch
    LDX EffectFrame
    LDA BeepVol,X
    STA Volume
    JMP SoundDone

Boop:
    LDA EffectFrame
    AND #$04                ; four frames low, four frames high
    BEQ BoopLow
    LDA #20
    JMP BoopStore
BoopLow:
    LDA #6
BoopStore:
    STA Pitch
    LDX EffectFrame
    LDA BoopVol,X
    STA Volume
    JMP SoundDone

Boom:
    LDA EffectFrame
    AND #$0F
    TAX
    LDA BoomFreq,X          ; the noise generator's divider
    STA Pitch
    LDX EffectFrame
    LDA BoomVol,X
    STA Volume

SoundDone:
    LDA Pitch
    STA AUDF0
FreqWrite:                  ; checkpoint: A = AUDF
    LDA Volume
    STA AUDV0
VolWrite:                   ; checkpoint: A = AUDV

    LDX EffectID
    LDA EffectColorTbl,X
    STA EffectColor

; --- position player 0 (meter) and player 1 (pitch marker) ---
    LDA #(METER_X + POS_BIAS)
    JSR SetPos0
    LDA Pitch
    ASL
    ASL                     ; Pitch * 4
    CLC
    ADC #(METER_X + POS_BIAS)
    JSR SetPos1

; --- colors and playfield setup ---
    LDA EffectColor
    STA COLUP0
    STA COLUP1
    LDA #$02
    STA COLUBK
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    LDA #$01
    STA CTRLPF

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK
    LDX #0
VisibleStart:
BodyStart:                  ; checkpoint: the first visible line (scanline 37)
BandLoop:
    LDA #$02
    CPX EffectID
    BNE BandColor
    LDA EffectColor
BandColor:
    STA COLUPF
    LDY #8
BandLines:
    STA WSYNC
    DEY
    BNE BandLines
    INX
    CPX #3
    BNE BandLoop

; --- the 4-line gap; the playfield bars are off below the top bands ---
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #4
GapLoop:
    STA WSYNC
    DEY
    BNE GapLoop

; --- the 15-cell meter, top cell (14) down to bottom cell (0) ---
MeterStart:                 ; checkpoint: the first meter line (scanline 65)
    LDX #15
MeterLoop:
    DEX
    CPX Volume
    LDA #$00
    BCS MeterDark           ; cell index >= volume: dark
    LDA #$FF                ; cell index < volume: lit
MeterDark:
    STA GRP0
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    CPX #0
    BNE MeterLoop

; --- the pitch band: 4 blank, 8 marker, 4 blank ---
    LDA #$00
    STA GRP0
    STA GRP1
    LDY #4
PitchTop:
    STA WSYNC
    DEY
    BNE PitchTop
    LDA #$FF
    LDY #8
PitchMarker:
    STA GRP1
    STA WSYNC
    DEY
    BNE PitchMarker
    LDA #$00
    STA GRP1
    LDY #4
PitchBottom:
    STA WSYNC
    DEY
    BNE PitchBottom

; --- the bottom background: 58 lines ---
    LDY #58
BottomLoop:
    STA WSYNC
    DEY
    BNE BottomLoop

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; TWO-OBJECT POSITIONING — the class routine, one HMOVE at the end
; =============================================================================
; A = the target TIA X plus POS_BIAS.  Each routine sets its coarse RESxx and
; its HMPx value; SetPos1 ends with WSYNC/HMOVE, so the fine offsets for both
; players are applied in one HBLANK.
SetPos0:
    STA WSYNC
    SEC
Div0:
    SBC #15
    BCS Div0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    RTS
SetPos1:
    STA WSYNC
    SEC
Div1:
    SBC #15
    BCS Div1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
    STA RESP1
    STA WSYNC
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed
    RTS

; =============================================================================
; EFFECT TABLES
; =============================================================================
EffectLen:
    !byte 32, 32, 48
EffectCtl:
    !byte $0C, $04, $08
EffectColorTbl:
    !byte $C8, $84, $42

BeepVol:
    !fill 10, 15
    !fill 5, 12
    !fill 5, 8
    !fill 12, 0

BoopVol:
    !fill 24, 12
    !fill 4, 8
    !fill 4, 0

BoomFreq:
    !byte 12,19,7,25,3,30,14,9,22,5,28,16,1,24,11,19

BoomVol:
    !fill 3, 15
    !fill 3, 14
    !fill 3, 13
    !fill 3, 12
    !fill 3, 11
    !fill 3, 10
    !fill 3, 9
    !fill 3, 8
    !fill 3, 7
    !fill 3, 6
    !fill 3, 5
    !fill 3, 4
    !fill 3, 3
    !fill 3, 2
    !fill 3, 1
    !fill 3, 0

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
