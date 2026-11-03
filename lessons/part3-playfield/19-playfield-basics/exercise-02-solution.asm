; =============================================================================
; LESSON 19 — EXERCISE 2 SOLUTION: One Chunk Bar
; =============================================================================
; Part 3: Playfield
;
; Exercise: draw a single playfield chunk and explain where it appears.
;
; The technique: set one bit.  PF1 = $10 is bit 4.  PF1's bit 7 is the
; leftmost chunk (chunk 4), so bit 4 is chunk 7.  In reflect mode the right
; half mirrors the left, so the same bar appears at the mirrored chunk:
;   chunk 7  -> capture x = 25 + 7  x 24 = 193
;   chunk 32 -> capture x = 25 + 32 x 24 = 793
; The two bars are 24 pixels wide (one chunk = 4 color clocks = 24 capture
; pixels).  In repeat mode the bar would instead appear at chunk 27
; (x = 673): the right half repeats the left's chunk numbering, it does not
; mirror it.  That is the whole difference between the two modes in one
; experiment.
;
; Debugger checkpoint: CtrlWrite (A = $01), VisibleStart (37).
;
; Build: acme -f plain -o build/lesson19-ex2.bin \
;        lessons/part3-playfield/19-playfield-basics/exercise-02-solution.asm
; Run:   stella build/lesson19-ex2.bin
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

; --- one bit set: PF1 bit 4 = chunk 7 ---
    LDA #$01
    STA CTRLPF              ; reflect
CtrlWrite:                  ; checkpoint: A = $01
    LDA #$00
    STA PF0                 ; no chunks from PF0
    LDA #$10
    STA PF1                 ; bit 4 = chunk 7 (the only bar)
    LDA #$00
    STA PF2                 ; no chunks from PF2
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
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
