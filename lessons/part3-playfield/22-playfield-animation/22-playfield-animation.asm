; =============================================================================
; LESSON 22: Playfield Animation — Moving Walls — Racing the Beam
; =============================================================================
; Part 3: Playfield
;
; What this program does:
;   Animates a symmetric portcullis.  The castle wall is solid except for a
;   central gate; every half second the gate opens one step, then closes
;   again.  Nine states take the gate from fully closed to fully open and
;   back.  The wall's shape is constant down the screen; only PF2 changes,
;   and it changes once per frame in VBLANK.
;
; Why the animation is cheap:
;   The playfield registers persist across scanlines — the TIA re-reads them
;   every line.  A change made in VBLANK therefore appears on the whole next
;   frame, with no per-line writes.  The visible kernel just holds 192 lines;
;   the state machine lives in the blanking time, where there are thousands
;   of free cycles.
;
; The gate:
;   PF0 = $F0, PF1 = $FF  -> the wall, solid from chunk 0 to chunk 11.
;   PF2 = GateTable[state] -> the gate, in chunks 12-19 and their mirror.
;
;   PF2 bit 0 is leftmost, so clearing bits from bit 7 downward opens the
;   gate from the center outward.  A cleared bit is a zero, which shows
;   COLUBK (the dark background).
;
;     state  PF2    open chunks (each side mirrors)
;     0      $FF    0        closed
;     1      $7F    1        a 2-chunk gap
;     2      $3F    2        a 4-chunk gap
;     ...
;     8      $00    8        a 16-chunk gap (x = 313-696, 384 px)
;
;   State k opens 2k chunks; the gap spans x = 505 - 24k .. 505 + 24k - 1.
;
; The animation:
;   GateState 0..8, GateDir $01 (up) or $FF (down).  FrameCounter counts to
;   30 (~0.5 s), then the state steps and the direction reverses at 0 and 8.
;   At ~60 Hz the full open-close cycle is 8 seconds (16 steps).
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), GateStep (A = the new state, once per
;   30 frames), PF2Write (A = the table byte), VisibleStart (37),
;   OverscanStart (229).
;
; Build: acme -f plain -o build/lesson22.bin \
;        lessons/part3-playfield/22-playfield-animation/22-playfield-animation.asm
; Run:   stella build/lesson22.bin
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
VISIBLE_LINES  = 192
STEP_FRAMES    = 30     ; ~0.5 s per gate step

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
GateState      = $80    ; 0 (closed) .. 8 (open)
GateDir        = $81    ; $01 = opening, $FF = closing
FrameCounter   = $82    ; counts up to STEP_FRAMES

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM; GateState = 0
    LDA #$01
    STA GateDir             ; start opening

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
    +vsync

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the gate tick: step the state every STEP_FRAMES frames ---
    INC FrameCounter
    LDA FrameCounter
    CMP #STEP_FRAMES
    BNE VblankSetGate
    LDA #$00
    STA FrameCounter
    LDA GateState
    CLC
    ADC GateDir
    STA GateState
GateStep:                   ; debugger checkpoint: A = the new state
    CMP #8
    BNE VblankCheckBottom
    LDA #$FF                ; at the top: start closing
    STA GateDir
    JMP VblankSetGate
VblankCheckBottom:
    CMP #0
    BNE VblankSetGate
    LDA #$01                ; at the bottom: start opening
    STA GateDir

; --- write the frame's wall and gate ---
VblankSetGate:
    LDX GateState
    LDA GateTable,X
    STA PF2
PF2Write:                   ; debugger checkpoint: A = GateTable[state]
    LDA #$F0
    STA PF0                 ; chunks 0-3 on
    LDA #$FF
    STA PF1                 ; chunks 4-11 on
    LDA #$C8
    STA COLUPF              ; green
    LDA #$02
    STA COLUBK              ; dark
    LDA #$01
    STA CTRLPF              ; reflect: the gate mirrors about the center

    LDX #VISIBLE_LINES
    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — the registers are the picture; hold 192 lines
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam on line 37
VisibleStart:               ; debugger checkpoint: the picture's first line (37)
    STA WSYNC
    DEX
    BNE VisibleStart

; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines; blank-on lands in line 229's HBLANK
; -----------------------------------------------------------------------------
OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; GATE TABLE — nine states, closed to fully open
; =============================================================================
GateTable:
    !byte $FF, $7F, $3F, $1F, $0F, $07, $03, $01, $00

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
