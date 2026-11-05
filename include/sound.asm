; =============================================================================
; SOUND.ASM — A small two-channel sound engine for the Atari 2600
; =============================================================================
;
; This library turns the per-frame audio writes of Lessons 35 and 36 into a
; data-driven engine.  A sound is a definition plus two per-step tables; the
; engine owns both TIA audio channels and decides which sound may use one.
;
; -----------------------------------------------------------------------------
; API
; -----------------------------------------------------------------------------
;   SoundInit                 Silence both channels and clear the state.
;   SoundTrigger              A = sound ID, X = channel (0 or 1).
;                             Returns C=1 if accepted, C=0 if rejected;
;                             X is preserved on return.
;                             A sound is rejected when the channel is busy with
;                             a sound of equal or higher priority.
;   SoundUpdate               Call once per frame.  Advances both channels,
;                             writes AUDF/AUDV, and mutes a non-looping sound
;                             when its last step has played.
;   SoundStop                 X = channel; silence it and free the channel.
;
; -----------------------------------------------------------------------------
; SOUND DEFINITION (8 bytes, little-endian pointers)
; -----------------------------------------------------------------------------
;   +0  AUDC        generator / tone divisor (0-15)
;   +1  Rate        frames per step
;   +2  Steps       low 7 bits = number of steps; bit 7 = loop
;   +3  Priority    0-15; higher wins
;   +4  FreqL       low byte of the per-step AUDF table
;   +5  FreqH       high byte
;   +6  VolL        low byte of the per-step AUDV table
;   +7  VolH        high byte
;
; The caller defines a label `SoundTable` whose entries are these 8-byte
; records, in sound-ID order.  The engine reads the definition pointer and
; re-reads the two table pointers on every step, so the state stays small.
;
; -----------------------------------------------------------------------------
; RAM
; -----------------------------------------------------------------------------
; The engine owns $90-$9F (read-only to the caller) and uses $88-$8D as scratch.
; $8E-$8F are free for the caller; this lesson's monitor uses $A0-$A5.  `+clean_start`
; zeroes all of it.
;
;   $88 SndID      the sound being triggered
;   $89 SndChan    the channel being triggered/updated
;   $8A SndDefL    definition pointer, low
;   $8B SndDefH    definition pointer, high
;   $8C SndTabL    per-step table pointer, low
;   $8D SndTabH    per-step table pointer, high
;   $8E-$8F        free for the caller after the engine calls
;
;   $90 SndPtrL    2 bytes, one per channel
;   $92 SndPtrH    2
;   $94 SndTimer   2
;   $96 SndStep    2
;   $98 SndPrio    2
;   $9A SndActive  2
;   $9C SndFreq    2  (the last AUDF written, for a monitor)
;   $9E SndVol     2  (the last AUDV written, for a monitor)
;
; -----------------------------------------------------------------------------
; EXAMPLE
; -----------------------------------------------------------------------------
;   SoundTable:
;       !byte $0C, 12, $90, 1        ; AUDC, Rate, Steps|loop, Priority
;       !word MusicFreq, MusicVol
;   ...
;       JSR SoundInit
;       LDA #0
;       LDX #1
;       JSR SoundTrigger             ; start the music on channel 1
;       ...
;       JSR SoundUpdate              ; once per frame, in VBLANK
; =============================================================================

SndID     = $88
SndChan   = $89
SndDefL   = $8A
SndDefH   = $8B
SndTabL   = $8C
SndTabH   = $8D

SndPtrL   = $90
SndPtrH   = $92
SndTimer  = $94
SndStep   = $96
SndPrio   = $98
SndActive = $9A
SndFreq   = $9C
SndVol    = $9E

; =============================================================================
; SoundInit — silence both channels and clear the engine state.
; =============================================================================
SoundInit:
    LDA #0
    STA AUDV0
    STA AUDV1
    STA AUDC0
    STA AUDC1
    LDX #1
SndInitLoop:
    STA SndActive,X
    STA SndVol,X
    STA SndPrio,X
    STA SndStep,X
    STA SndFreq,X
    DEX
    BPL SndInitLoop
    RTS

; =============================================================================
; SoundTrigger — A = ID, X = channel; C=1 accepted, C=0 rejected.
; =============================================================================
SoundTrigger:
    STA SndID
    STX SndChan
Trigger:                    ; checkpoint: A = ID, X = channel

    ; --- definition pointer = SoundTable + ID*8 ---
    LDA SndID
    ASL
    ASL
    ASL
    CLC
    ADC #<SoundTable
    STA SndDefL
    LDA #>SoundTable
    ADC #$00
    STA SndDefH

    ; --- reject an equal or lower priority on a busy channel ---
    LDX SndChan
    LDA SndActive,X
    BEQ AcceptLoad
    LDY #3
    LDA (SndDefL),Y         ; the new sound's priority
    CMP SndPrio,X
    BCC RejectLoad          ; lower: keep the current sound
    BEQ RejectLoad          ; equal: keep the current sound

AcceptLoad:
    LDA SndID
Accept:                     ; checkpoint: A = ID, X = channel
    ; --- install the definition ---
    LDX SndChan
    LDA SndDefL
    STA SndPtrL,X
    LDA SndDefH
    STA SndPtrH,X
    LDY #3
    LDA (SndDefL),Y
    STA SndPrio,X
    LDA #1
    STA SndActive,X
    LDA #0
    STA SndStep,X
    LDY #1
    LDA (SndDefL),Y
    STA SndTimer,X
    LDY #0
    LDA (SndDefL),Y
    STA AUDC0,X
CtlWrite:                   ; checkpoint: A = AUDC, X = channel
    JSR SndLoadStep
    SEC
    RTS
RejectLoad:
    LDA SndID
Reject:                     ; checkpoint: A = ID, X = channel
    CLC
    RTS

; =============================================================================
; SndLoadStep — load step SndStep[SndChan] and write AUDF/AUDV.
; =============================================================================
SndLoadStep:
    LDX SndChan
    LDA SndPtrL,X
    STA SndDefL
    LDA SndPtrH,X
    STA SndDefH

    ; --- frequency table pointer (+4/+5) ---
    LDY #4
    LDA (SndDefL),Y
    STA SndTabL
    INY
    LDA (SndDefL),Y
    STA SndTabH
    LDY SndStep,X
    LDA (SndTabL),Y
    STA SndFreq,X
    STA AUDF0,X
FreqWrite:                  ; checkpoint: A = AUDF, X = channel

    ; --- volume table pointer (+6/+7) ---
    LDY #6
    LDA (SndDefL),Y
    STA SndTabL
    INY
    LDA (SndDefL),Y
    STA SndTabH
    LDY SndStep,X
    LDA (SndTabL),Y
    STA SndVol,X
    STA AUDV0,X
VolWrite:                   ; checkpoint: A = AUDV, X = channel
    RTS

; =============================================================================
; SoundUpdate — advance both channels once per frame.
; =============================================================================
SoundUpdate:
    LDX #0
SndNextChannel:
    LDA SndActive,X
    BEQ SndNext
    DEC SndTimer,X
    BNE SndNext
    LDA SndPtrL,X
    STA SndDefL
    LDA SndPtrH,X
    STA SndDefH
    LDY #1
    LDA (SndDefL),Y
    STA SndTimer,X
    INC SndStep,X
    LDA SndStep,X
StepWrite:                  ; checkpoint: A = step, X = channel
    LDY #2
    LDA (SndDefL),Y
    AND #$7F
    CMP SndStep,X
    BEQ SndWrap
    BCC SndWrap
    JMP SndLoad
SndWrap:
    LDY #2
    LDA (SndDefL),Y
    BMI SndLoop
    ; the sequence is over: mute and free the channel
    LDA #0
    STA SndActive,X
    STA SndVol,X
    STA AUDV0,X
    JMP SndNext
SndLoop:
    LDA #0
    STA SndStep,X
SndLoad:
    STX SndChan
    JSR SndLoadStep
SndNext:
    INX
    CPX #2
    BNE SndNextChannel
    RTS

; =============================================================================
; SoundStop — X = channel; silence it and free it.
; =============================================================================
SoundStop:
    LDA #0
    STA SndActive,X
    STA SndVol,X
    STA AUDV0,X
    RTS
