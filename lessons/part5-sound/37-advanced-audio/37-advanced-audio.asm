; =============================================================================
; LESSON 37: Advanced Audio — Sound Engine Design — Racing the Beam
; =============================================================================
; Part 5: Sound
;
; What this program does:
;   "The mixer": a small data-driven sound engine owns both TIA channels.
;   Channel 0 plays BLIP, LASER, and EXPLOSION on a schedule; channel 1 loops
;   MUSIC and is interrupted by a POWERUP.  Three top bands show the active
;   channel-0 sound; two 15-cell bars show the two channel volumes; a bottom
;   bar shows the channel-0 priority.  A request that loses the priority test
;   is rejected, and the debugger's Accept/Reject checkpoints prove it.
;
; The engine (include/sound.asm):
;   Each sound is 8 bytes: AUDC, Rate (frames per step), Steps (bit 7 = loop),
;   Priority, and pointers to the per-step frequency and volume tables.
;   A channel owns one sound.  A new sound is accepted only if the channel is
;   free or the new priority is strictly higher; equal or lower is rejected.
;   SoundUpdate advances both channels once per frame and mutes a non-looping
;   sound at its end.
;
; The demo schedule (counters start at their periods):
;   BLIP       every 24 frames, channel 0, priority 2
;   LASER      every 120, channel 0, priority 5
;   EXPLOSION  every 240, channel 0, priority 9
;   POWERUP    every 360, channel 1, priority 8
;   MUSIC      channel 1, priority 1, 16-step loop, retriggered when free
;   The VBLANK order is LASER, EXPLOSION, POWERUP, BLIP, so a BLIP that lands
;   on a LASER/EXPLOSION frame is rejected deterministically.  The guaranteed
;   standalone rejection is the BLIP at frame 264 inside the explosion's
;   240-275 window.
;
; The picture:
;   Visible line 0 = scanline 37.  The top 24 lines are three 8-line bands for
;   BLIP/LASER/EXPLOSION.  The next 90 lines are two 15-cell meters (6 lines
;   per cell) at X=48 and X=112.  A 4-line gap, an 8-line priority bar (N
;   playfield chunks per half), and 62 background lines complete the 192.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), Trigger/Accept/Reject (A=ID, X=channel),
;   CtlWrite/FreqWrite/VolWrite/StepWrite (A=value, X=channel), MusicStart (384),
;   BodyStart (37), MeterStart (65), PrioStart (159), HmoveApply/HmoveDone,
;   OverscanStart (229).
;
; Build: acme -f plain -o build/lesson37.bin \
;        lessons/part5-sound/37-advanced-audio/37-advanced-audio.asm
; Run:   stella build/lesson37.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"
; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
SFX_X          = 48
CH1_X          = 112
POS_BIAS       = 3

; --- Lesson variables (the engine owns $88-$9F) ---
BlipTimer  = $80   ; 24 -> 0, then reload
LaserTimer = $81   ; 120 -> 0
BoomTimer  = $82   ; 240 -> 0
PowerTimer = $83   ; 120 -> 0, three ticks make 360
PowerCount = $8F   ; 3 -> 0; the third tick triggers POWERUP
SfxID      = $84   ; the last accepted channel-0 sound
Ch1ID      = $85   ; the last accepted channel-1 sound
SfxColor   = $86   ; the active channel-0 color
ActiveBand = $87   ; the active top band (0-2) or $FF

; The priority bar's three bytes live in the free $A0-$F7 block.
PrioPF0    = $A0
PrioPF1    = $A1
PrioPF2    = $A2
BandColor0 = $A3
BandColor1 = $A4
BandColor2 = $A5

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

    !source "include/sound.asm"

Reset:
    +clean_start
    LDA #24
    STA BlipTimer
    LDA #120
    STA LaserTimer
    LDA #240
    STA BoomTimer
    LDA #120
    STA PowerTimer
    LDA #3
    STA PowerCount
    LDA #0
    STA SfxID
    STA Ch1ID
    JSR SoundInit
    LDA #0
    LDX #1
    JSR TriggerSound       ; start MUSIC on channel 1

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- advance the engine, then make the scheduled requests ---
    JSR SoundUpdate

    DEC LaserTimer
    BNE NoLaser
    LDA #120
    STA LaserTimer
    LDA #2
    LDX #0
    JSR TriggerSound
NoLaser:

    DEC BoomTimer
    BNE NoBoom
    LDA #240
    STA BoomTimer
    LDA #3
    LDX #0
    JSR TriggerSound
NoBoom:

    DEC PowerTimer
    BNE NoPower
    LDA #120
    STA PowerTimer
    DEC PowerCount
    BNE NoPower
    LDA #3
    STA PowerCount
    LDA #4
    LDX #1
    JSR TriggerSound
NoPower:

    DEC BlipTimer
    BNE NoBlip
    LDA #24
    STA BlipTimer
    LDA #1
    LDX #0
    JSR TriggerSound
NoBlip:

    LDA SndActive+1        ; if channel 1 is free, bring the music back
    BNE NoMusic
    LDA #0
    LDX #1
    JSR TriggerSound
MusicStart:                ; checkpoint: the music restarted (frame 384)
    NOP
NoMusic:

; --- derive the monitor's colors and the priority pattern ---
    LDA #$02
    STA SfxColor
    LDA #$FF
    STA ActiveBand
    LDA SndActive
    BEQ NoSfxShadow
    LDX SfxID
    LDA SfxColorTbl,X
    STA SfxColor
    LDA BandMap,X
    STA ActiveBand
NoSfxShadow:

    LDA #$02
    STA BandColor0
    STA BandColor1
    STA BandColor2
    LDX ActiveBand
    CPX #3
    BCS NoBandColor
    LDA SfxColor
    STA BandColor0,X
NoBandColor:

    LDA #0
    STA PrioPF0
    STA PrioPF1
    STA PrioPF2
    LDA SndActive
    BEQ NoPriority
    LDA SndPrio
    ASL
    CLC
    ADC SndPrio
    TAX
    LDA PriorityPF,X
    STA PrioPF0
    LDA PriorityPF+1,X
    STA PrioPF1
    LDA PriorityPF+2,X
    STA PrioPF2
NoPriority:

; --- position both players, one HMOVE ---
    LDA #(SFX_X + POS_BIAS)
    JSR SetPos0
    LDA #(CH1_X + POS_BIAS)
    JSR SetPos1

; --- colors ---
    LDA SfxColor
    STA COLUP0
    LDA #$02
    LDX SndActive+1
    BEQ Ch1ColorDone
    LDA #$84                ; blue for the music
    LDX Ch1ID
    CPX #4
    BNE Ch1ColorDone
    LDA #$C8                ; green for the power-up
Ch1ColorDone:
    STA COLUP1
    LDA #$02
    STA COLUBK
    LDA #0
    STA NUSIZ0
    STA NUSIZ1
    LDA #$01
    STA CTRLPF

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — 192 lines, work-first
; -----------------------------------------------------------------------------
    LDA BandColor0          ; band 0's colour before the first visible line
    STA COLUPF
    LDA #$00
    STA VBLANK
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2

    LDX #0
BodyStart:                 ; checkpoint: the first visible line (scanline 37)
BandLoop:
    LDA BandColor0,X
    STA COLUPF
    LDY #8
BandLines:
    STA WSYNC
    DEY
    BNE BandLines
    INX
    CPX #3
    BNE BandLoop

; --- the 4-line gap; the bars are players, the playfield is off ---
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    LDY #4
GapLoop:
    STA WSYNC
    DEY
    BNE GapLoop

; --- two 15-cell meters, 6 lines per cell, top cell (14) down to 0 ---
MeterStart:                ; checkpoint: the first meter line (scanline 65)
    LDX #15
MeterLoop:
    DEX
    CPX SndVol
    LDA #0
    BCS SfxDark
    LDA #$FF
SfxDark:
    STA GRP0
    CPX SndVol+1
    LDA #0
    BCS Ch1Dark
    LDA #$FF
Ch1Dark:
    STA GRP1
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    CPX #0
    BNE MeterLoop

; --- the 4-line gap before the priority bar ---
    LDA #0
    STA GRP0
    STA GRP1
    LDA SfxColor            ; the four gap lines give the colour time to settle
    STA COLUPF
    LDY #4
PrioGap:
    STA WSYNC
    DEY
    BNE PrioGap

; --- the 8-line priority bar ---
    LDA PrioPF0
    STA PF0
    LDA PrioPF1
    STA PF1
    LDA PrioPF2
    STA PF2
PrioStart:                 ; checkpoint: the priority bar (scanline 159)
    LDY #8
PrioLines:
    STA WSYNC
    DEY
    BNE PrioLines
    LDA #0
    STA PF0
    STA PF1
    STA PF2

; --- the bottom background: 62 lines ---
    LDY #62
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
; TRIGGER SOUND — A = ID, X = channel; remembers accepted IDs for the monitor
; =============================================================================
TriggerSound:
    PHA
    JSR SoundTrigger
    BCC TriggerReject
    PLA
    CPX #0
    BNE TriggerCh1
    STA SfxID
    RTS
TriggerCh1:
    STA Ch1ID
    RTS
TriggerReject:
    PLA
    RTS

; =============================================================================
; TWO-OBJECT POSITIONING — one HMOVE at the end
; =============================================================================
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
HmoveApply:                ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                 ; checkpoint: the store has executed
    RTS

; =============================================================================
; SOUND DEFINITIONS — see include/sound.asm for the 8-byte format
; =============================================================================
SoundTable:
    !byte $0C, 12, $90, 1   ; 0 MUSIC, 16 steps, loop, priority 1
    !word MusicFreq, MusicVol
    !byte $0C, 2, 4, 2      ; 1 BLIP, 4 steps, priority 2
    !word BlipFreq, BlipVol
    !byte $04, 2, 6, 5      ; 2 LASER, 6 steps, priority 5
    !word LaserFreq, LaserVol
    !byte $08, 3, 12, 9     ; 3 EXPLOSION, 12 steps, priority 9
    !word BoomFreq, BoomVol
    !byte $04, 3, 8, 8      ; 4 POWERUP, 8 steps, priority 8
    !word PowerFreq, PowerVol

MusicFreq:
    !byte 15,15,14,12,12,14,15,17,19,19,17,15,15,17,17,19
MusicVol:
    !fill 15, 4
    !byte 0

BlipFreq:
    !fill 4, 20
BlipVol:
    !byte 10, 8, 4, 0

LaserFreq:
    !byte 6,8,10,12,14,16
LaserVol:
    !byte 11,11,9,7,5,0

BoomFreq:
    !byte 12,19,7,25,3,30,14,9,22,5,28,16
BoomVol:
    !byte 11,10,9,8,7,6,5,4,3,2,1,0

PowerFreq:
    !byte 20,18,16,14,12,10,8,6
PowerVol:
    !byte 10,10,10,8,8,6,6,4

; =============================================================================
; MONITOR TABLES
; =============================================================================
SfxColorTbl:
    !byte $84, $C8, $1A, $42, $C8        ; MUSIC, BLIP, LASER, BOOM, POWER
BandMap:
    !byte 0, 0, 1, 2, 1                  ; which top band each ID uses

; One 20-bit playfield pattern per priority: N chunks in the left half,
; mirrored by CTRLPF.  PF0 = chunks 0-3, PF1 = 4-11, PF2 = 12-19.
PriorityPF:
    !byte $00, $00, $00    ; priority 0
    !byte $10, $00, $00    ; priority 1
    !byte $30, $00, $00    ; priority 2
    !byte $70, $00, $00    ; priority 3
    !byte $F0, $00, $00    ; priority 4
    !byte $F0, $80, $00    ; priority 5
    !byte $F0, $C0, $00    ; priority 6
    !byte $F0, $E0, $00    ; priority 7
    !byte $F0, $F0, $00    ; priority 8
    !byte $F0, $F8, $00    ; priority 9
    !byte $F0, $FC, $00    ; priority 10
    !byte $F0, $FE, $00    ; priority 11
    !byte $F0, $FF, $00    ; priority 12
    !byte $F0, $FF, $01    ; priority 13
    !byte $F0, $FF, $03    ; priority 14
    !byte $F0, $FF, $07    ; priority 15

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
