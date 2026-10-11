; =============================================================================
; LESSON 18 — EXERCISE 3 SOLUTION: The Smooth March (Stretch Goal)
; =============================================================================
; Part 2: TV & TIA
;
; Exercise: animate the boundaries smoothly — one cycle step per frame.
;
; The technique: the lesson ROM flips between two frozen states.  This
; solution marches the whole boundary block one cycle per frame instead: a
; ping-pong phase (0..11) picks one of twelve pad blocks through an indirect
; pointer, and each block delays the boundary code by a different number of
; cycles (pad = phase + 4).  Phase 6 is the home position (boundaries at
; clocks 108 / 147 / 189, like the lesson ROM); below and above it the three
; boundaries sweep six cycles down and five up (boundary 1: clocks 90..123),
; one cycle every frame — a smooth 22-frame round trip (~0.37 s).
;
; The per-line ledger (phase k; pad = k + 4; all exactly 76 cycles):
;   DEX / BNE                5    0-4
;   LDA #C1 / BIT / STA      8    5-12   base:     hit 13 -> clock 39 (HBLANK)
;   JMP (PhasePtr)           5   13-17   jump into the phase's pad block
;   pad block           4..15   18-…    NOPs (+ BIT when odd), then JMP back
;   JMP B1Code               3           (the block re-joins the boundary code)
;   LDA #C2 / STA            5           boundary 1: hit 26+pad -> clock 78+3xpad
;   NOP x 4 + LDA/STA        13          boundary 2: follows +13 cycles
;   NOP x 3 + BIT + LDA/STA  14          boundary 3: follows +14 cycles
;   STA WSYNC                3           anchor: write (hit+29), park
;   ----------------------------------------------------------------
;   hit cycles: boundary 1  30..41, boundary 2  43..54, boundary 3  57..68
;   anchor writes: cycle 59 (lowest phase) .. 70 (highest phase) — within
;   the line in every phase.
;
;   Phase 6 (pad 10) reproduces the lesson ROM's default geometry exactly:
;   hits 36 / 49 / 63, boundaries at clocks 108 / 147 / 189.
;
; Expected picture: the four columns, with the three boundaries drifting
; smoothly left and right — one CPU cycle (three color clocks / 18 capture
; pixels) per frame — and reversing at the extremes.  A burst of captures a
; frame or two apart shows the boundaries stepping three clocks per frame.
;
; Debugger checkpoints: BaseTick (13), B1Tick — its hit CYCLE is the readout:
;   it sweeps 30 -> 41 -> 30, one cycle per frame, pinging at the ends;
;   OverscanStart, OverscanPoll.  The phase machine runs once per frame in
;   VBLANK.
;
; Build: acme -f plain -o build/lesson18-ex3.bin \
;        lessons/part2-tv-and-tia/18-mid-scanline-changes/exercise-03-solution.asm
; Run:   stella build/lesson18-ex3.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines (Lesson 15)
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines (Lesson 15)

COL1           = $42
COL2           = $84
COL3           = $C8
COL4           = $1A

VISIBLE_LINES  = 192

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
Phase          = $80    ; 0..11 ping-pong phase (6 = home geometry)
PhaseDir       = $81    ; $01 = stepping up, $FF = stepping down
PhasePtr       = $82    ; 2-byte pointer: the current pad block

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)
    LDA #$01
    STA PhaseDir            ; start stepping up from phase 0

; =============================================================================
; MAIN LOOP  —  one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
    LDA #$02                ; bit 1 = start VSYNC
    STA VSYNC
    STA WSYNC               ; VSYNC line 1
    STA WSYNC               ; VSYNC line 2
    STA WSYNC               ; VSYNC line 3
    LDA #$00
    STA VSYNC               ; pulse off — exactly 3 lines

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
    LDA #$02
    STA VBLANK
    LDA #VBLANK_TIMER
    STA TIM64T              ; 44 ticks for 37 lines

; --- the phase machine: one step per frame, ping-ponging at 0 and 11 ---
    LDA Phase
    CLC
    ADC PhaseDir            ; +1 or -1
    STA Phase
    CMP #11
    BNE PhaseNotTop
    LDA #$FF
    STA PhaseDir            ; at the top: step down
    JMP PhaseSetPtr
PhaseNotTop:
    CMP #0
    BNE PhaseSetPtr
    LDA #$01
    STA PhaseDir            ; at the bottom: step up
PhaseSetPtr:
    LDA Phase
    ASL                     ; phase x 2 — the table holds words
    TAY
    LDA PhaseTable,Y
    STA PhasePtr
    LDA PhaseTable+1,Y
    STA PhasePtr+1

VblankWait:
    LDA INTIM
VblankPoll:                 ; debugger checkpoint: A = the value just read
    BNE VblankWait
    LDX #VISIBLE_LINES      ; 192 lines to paint
    STA WSYNC               ; park the rest of line 36
    LDA #$00
    STA VBLANK              ; release the beam
VisibleStart:               ; debugger checkpoint: the picture's first line (Stella: 37)
VarBody:
    LDA #COL1               ; 5-6    base color
    BIT Phase               ; 7-9    the 3-cycle odd-gap tuner (reads, changes nothing)
    STA COLUBK              ; 10-12
BaseTick:                   ; checkpoint: hit cycle 13
    JMP (PhasePtr)          ; 13-17  into the phase's pad block

; --- the boundaries: shared by every phase ---
B1Code:
    LDA #COL2               ; 2
    STA COLUBK              ; 3
B1Tick:                     ; checkpoint: hit cycle 26+pad (30..41) — the march
    NOP
    NOP
    NOP
    NOP                     ; 8 cycles
    LDA #COL3               ; 2
    STA COLUBK              ; 3
    NOP
    NOP
    NOP                     ; 6 cycles
    BIT Phase               ; 3
    LDA #COL4               ; 2
    STA COLUBK              ; 3
    STA WSYNC               ; the anchor
    DEX
    BNE VarBody
    JMP OverscanStart       ; 192 lines done

; =============================================================================
; PAD BLOCKS — outside the line ring (the indirect jump reaches them
; absolutely, so their physical position costs nothing): each block eats
; its phase's cycles, then re-joins the shared boundary code.
; =============================================================================
Pad04:
    NOP
    NOP                     ; 4
    JMP B1Code
Pad05:
    NOP                     ; 2
    BIT Phase               ; 3
    JMP B1Code
Pad06:
    NOP
    NOP
    NOP                     ; 6
    JMP B1Code
Pad07:
    NOP
    NOP                     ; 4
    BIT Phase               ; 3
    JMP B1Code
Pad08:
    NOP
    NOP
    NOP
    NOP                     ; 8
    JMP B1Code
Pad09:
    NOP
    NOP
    NOP                     ; 6
    BIT Phase               ; 3
    JMP B1Code
Pad10:
    NOP
    NOP
    NOP
    NOP
    NOP                     ; 10
    JMP B1Code
Pad11:
    NOP
    NOP
    NOP
    NOP                     ; 8
    BIT Phase               ; 3
    JMP B1Code
Pad12:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP                     ; 12
    JMP B1Code
Pad13:
    NOP
    NOP
    NOP
    NOP
    NOP                     ; 10
    BIT Phase               ; 3
    JMP B1Code
Pad14:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP                     ; 14
    JMP B1Code
Pad15:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP                     ; 12
    BIT Phase               ; 3
    JMP B1Code


; =============================================================================
; PHASE TABLE — twelve pad blocks, one per phase (word addresses)
; =============================================================================
PhaseTable:
    !word Pad04, Pad05, Pad06, Pad07, Pad08, Pad09
    !word Pad10, Pad11, Pad12, Pad13, Pad14, Pad15

OverscanStart:              ; debugger checkpoint: overscan's first line (Stella: 229)
    LDA #$02
    STA VBLANK
    LDA #OVERSCAN_TIMER
    STA TIM64T              ; 36 ticks for 30 lines

OverscanWait:
    LDA INTIM
OverscanPoll:               ; debugger checkpoint: A = the value just read
    BNE OverscanWait
    STA WSYNC
    JMP StartFrame

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
