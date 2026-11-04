; =============================================================================
; LESSON 36 — EXERCISE 1 SOLUTION: Double-Speed Music
; =============================================================================
; Part 5: Sound
;
; Exercise: change NOTE_FRAMES from 12 to 6 so the melody plays twice as fast.
; HARMONY_FRAMES is 4 * NOTE_FRAMES, so the harmony scales with the lead and
; the two voices stay aligned.
;
; Build: acme -f plain -o build/lesson36-ex1.bin \
;        lessons/part5-sound/36-music/exercise-01-solution.asm
; Run:   stella build/lesson36-ex1.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
NOTE_FRAMES    = 6
HARMONY_FRAMES = 4 * NOTE_FRAMES
LEAD_X         = 48
HARMONY_X      = 112
POS_BIAS       = 3

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
LeadIndex   = $80   ; 0-15, the current lead step
LeadTimer   = $81   ; frames until the next lead step
HarmonyIndex= $82   ; 0-3, the current harmony step
HarmonyTimer= $83   ; frames until the next harmony step
LeadTop     = $84   ; the lead marker's first visible line ($F0 hides it)
HarmonyTop  = $85   ; the harmony marker's first visible line ($F0 hides it)
GridPhase   = $86   ; 0-19: when it wraps, the next line is a rung

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$0C
    STA AUDC0               ; div 6 pure tone: the lead
AUDC0Write:                 ; checkpoint: A = the lead timbre
    LDA #$0D
    STA AUDC1               ; div 6 pure tone: the harmony
AUDC1Write:                 ; checkpoint: A = the harmony timbre
    LDA #0
    STA LeadIndex
    STA HarmonyIndex
    LDA #NOTE_FRAMES
    STA LeadTimer
    LDA #HARMONY_FRAMES
    STA HarmonyTimer
    JSR PlayLead
    JSR PlayHarmony

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- advance the lead every NOTE_FRAMES ---
    DEC LeadTimer
    BNE NoLeadStep
    LDA #NOTE_FRAMES
    STA LeadTimer
    INC LeadIndex
    LDA LeadIndex
    CMP #16
    BCC LeadStore
    LDA #0
LeadStore:
LeadStep:                   ; checkpoint: A = the new lead index
    STA LeadIndex
    JSR PlayLead
NoLeadStep:

; --- advance the harmony every HARMONY_FRAMES ---
    DEC HarmonyTimer
    BNE NoHarmonyStep
    LDA #HARMONY_FRAMES
    STA HarmonyTimer
    INC HarmonyIndex
    LDA HarmonyIndex
    CMP #4
    BCC HarmonyStore
    LDA #0
HarmonyStore:
HarmonyStep:                ; checkpoint: A = the new harmony index
    STA HarmonyIndex
    JSR PlayHarmony
NoHarmonyStep:

; --- position the two markers; one HMOVE applies both fine offsets ---
    LDA #(LEAD_X + POS_BIAS)
    JSR SetPos0
    LDA #(HARMONY_X + POS_BIAS)
    JSR SetPos1

    LDA #$42
    STA COLUP0              ; red lead
    LDA #$84
    STA COLUP1              ; blue harmony
    LDA #$0A
    STA COLUPF              ; dim grid
    LDA #$02
    STA COLUBK
    LDA #0
    STA NUSIZ0
    STA NUSIZ1
    LDA #$01
    STA CTRLPF
    LDA #17
    STA GridPhase

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — 192 lines, work-first: draw the line, then WSYNC
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK
    LDX #0
BodyStart:                  ; checkpoint: the first visible line (scanline 37)
BodyLoop:
    ; --- a 1-line rung every 20 lines: set PF1/PF2 on the rung,
    ;     clear them on the following line (PF0 stays 0, so the rung
    ;     has a 16-px margin on each side) ---
    DEC GridPhase
    BNE NoGrid
    LDA #20
    STA GridPhase
    LDA #$FF
    STA PF1
    STA PF2
    JMP GridDone
NoGrid:
    LDA GridPhase           ; the line after a rung clears the playfield
    CMP #19
    BNE GridDone
    LDA #0
    STA PF1
    STA PF2
GridDone:

    ; --- the lead marker, 8 rows from LeadTop ---
    TXA
    SEC
    SBC LeadTop
    CMP #8
    BCS NoLead
    LDA #$FF
    STA GRP0
    JMP LeadDone
NoLead:
    LDA #0
    STA GRP0
LeadDone:

    ; --- the harmony marker, 8 rows from HarmonyTop ---
    TXA
    SEC
    SBC HarmonyTop
    CMP #8
    BCS NoHarmony
    LDA #$FF
    STA GRP1
    JMP HarmonyDone
NoHarmony:
    LDA #0
    STA GRP1
HarmonyDone:
    STA WSYNC
    INX
    CPX #192
    BNE BodyLoop

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; PLAY THE LEAD — one note per call; $FF is a silent C4
; =============================================================================
PlayLead:
    LDY LeadIndex
    LDA LeadNotes,Y
    CMP #$FF
    BEQ LeadRest
    TAX
    LDA NoteFreq,X
    STA AUDF0
LeadFreqWrite:              ; checkpoint: A = the lead AUDF
    LDA #8
    STA AUDV0
LeadVolWrite:               ; checkpoint: A = the lead volume
    LDA RungTop,X
    STA LeadTop
    RTS
LeadRest:
    LDA #19                 ; C4's divider, with volume 0
    STA AUDF0
LeadRestFreq:               ; checkpoint: A = 19 on the rest
    LDA #0
    STA AUDV0
LeadRestVol:                ; checkpoint: A = 0 on the rest
    LDA #$F0
    STA LeadTop
    RTS

; =============================================================================
; PLAY THE HARMONY — C and G, in the same octave as the lead table
; =============================================================================
PlayHarmony:
    LDY HarmonyIndex
    LDA HarmonyNotes,Y
    TAX
    LDA NoteFreq,X
    STA AUDF1
HarmonyFreqWrite:           ; checkpoint: A = the harmony AUDF
    LDA #6
    STA AUDV1
HarmonyVolWrite:            ; checkpoint: A = the harmony volume
    LDA RungTop,X
    STA HarmonyTop
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
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed
    RTS

; =============================================================================
; NOTE AND PICTURE TABLES
; =============================================================================
LeadNotes:
    !byte 2,2,3,4,4,3,2,1,0,0,1,2,2,1,1,$FF
HarmonyNotes:
    !byte 0,4,0,4
NoteFreq:
    !byte 19,17,15,14,12,11,10,9
RungTop:
    !byte 12,32,52,72,92,112,132,152

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
