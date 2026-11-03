; =============================================================================
; LESSON 19 — EXERCISE 3 SOLUTION: Eight Pattern Triples (Stretch Goal)
; =============================================================================
; Part 3: Playfield
;
; Exercise: cycle eight playfield patterns from a table, one per second.
;
; The technique: a pattern is three bytes (PF0, PF1, PF2).  Store eight of
; those triples in ROM, keep a 0..7 index in RAM, and advance it every 60
; frames (~1 s).  Multiplying the index by three gives the entry's byte
; offset:
;
;   offset = index x 3   (ASL makes 2x; add the index once more)
;
; The table below walks through the eight patterns it actually ships: the
; castle wall, a fine comb, the same comb shifted by one chunk, two wide
; slots, a full PF1 with a stepped center, inset edges, a split centre
; (gate), and sparse bars.  The picture changes shape once a second; the
; frame stays 262 lines throughout.
;
; Debugger checkpoints: PatStep (A = the new 0..7 index, once per 60
; frames), PatWrite (A = the PF2 byte just stored), VisibleStart (37).
;
; Build: acme -f plain -o build/lesson19-ex3.bin \
;        lessons/part3-playfield/19-playfield-basics/exercise-03-solution.asm
; Run:   stella build/lesson19-ex3.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
STEP_FRAMES    = 60     ; ~1 second per pattern

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
FrameCounter   = $80
PatIndex       = $81    ; 0..7, the table entry being shown

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start

StartFrame:                 ; VSYNC's first line (Stella: 259)
    +vsync

VblankStart:                ; VBLANK's first line (Stella: 0)
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- advance the pattern every STEP_FRAMES frames ---
    INC FrameCounter
    LDA FrameCounter
    CMP #STEP_FRAMES
    BNE VblankSetPattern
    LDA #$00
    STA FrameCounter
    INC PatIndex
    LDA PatIndex
    AND #$07                ; wrap 7 -> 0
    STA PatIndex
PatStep:                    ; checkpoint: A = the new index

; --- fetch this pattern's three bytes (offset = index x 3) ---
VblankSetPattern:
    LDA PatIndex
    ASL                     ; A = 2 x index
    CLC
    ADC PatIndex            ; A = 3 x index
    TAY
    LDA PatternTable,Y
    STA PF0
    LDA PatternTable+1,Y
    STA PF1
    LDA PatternTable+2,Y
    STA PF2
PatWrite:                   ; checkpoint: A = the PF2 byte
    LDA #$01
    STA CTRLPF              ; reflect
    LDA #$C8
    STA COLUPF
    LDA #$02
    STA COLUBK

    +wait_timer

    LDA #$00
    STA VBLANK              ; release the beam
    LDX #VISIBLE_LINES
VisibleStart:               ; the picture's first line (Stella: 37)
    STA WSYNC
    DEX
    BNE VisibleStart

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; PATTERN TABLE — eight (PF0, PF1, PF2) triples
; =============================================================================
PatternTable:
    !byte $F0, $CC, $F0     ; the lesson ROM's castle wall
    !byte $F0, $AA, $F0     ; a finer comb
    !byte $F0, $55, $F0     ; the same comb, offset by one chunk
    !byte $F0, $33, $F0     ; two wide slots
    !byte $F0, $FF, $F0     ; full PF1, stepped center
    !byte $C0, $CC, $F0     ; inset edges (2-chunk notches)
    !byte $F0, $CC, $3C     ; split centre (a 4-chunk gate)
    !byte $F0, $99, $F0     ; sparse bars

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
