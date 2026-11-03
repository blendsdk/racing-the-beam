; =============================================================================
; LESSON 19 — EXERCISE 1 SOLUTION: Invert the Pattern
; =============================================================================
; Part 3: Playfield
;
; Exercise: invert every playfield bit, so the wall's on and off regions swap.
;
; The technique: the pattern is three bytes.  Invert each one, but respect
; PF0's unused low nibble — only bits 4-7 are displayed, so the inverse of
; $F0 is $00, not $0F.
;
;   register  lesson ROM  inverse  chunks (left to right)
;   PF0       $F0        $00      0000
;   PF1       $CC        $33      00110011
;   PF2       $F0        $0F      11110000   (bit 0 first!)
;
; In reflect mode the right half mirrors the left.  The lesson ROM's
; eight-chunk green center becomes dark; its dark bands become green; the
; green outer blocks become dark.  The picture is the photographic negative
; of the lesson ROM's reflect state.
;
; Debugger checkpoint: CtrlWrite (A = $01, reflect), VisibleStart (37).
;
; Build: acme -f plain -o build/lesson19-ex1.bin \
;        lessons/part3-playfield/19-playfield-basics/exercise-01-solution.asm
; Run:   stella build/lesson19-ex1.bin
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
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; VSYNC's first line (Stella: 259)
    +vsync

VblankStart:                ; VBLANK's first line (Stella: 0)
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the inverted castle pattern, written once per frame ---
    LDA #$01
    STA CTRLPF              ; reflect
CtrlWrite:                  ; checkpoint: A = $01
    LDA #$00
    STA PF0                 ; chunks 0-3: off
    LDA #$33
    STA PF1                 ; chunks 4-11: 00110011
    LDA #$0F
    STA PF2                 ; chunks 12-19: 11110000 (bit 0 first)
    LDA #$C8
    STA COLUPF              ; green
    LDA #$02
    STA COLUBK              ; dark neutral

    +wait_timer

; --- visible: 192 lines; the TIA redraws the registers every line ---
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
