; =============================================================================
; LESSON 20: Playfield Colors and Priority — Racing the Beam
; =============================================================================
; Part 3: Playfield
;
; What this program does:
;   Draws a solid green wall with a central gap — then, every ~2 seconds,
;   splits the wall into a red left half and a blue right half using
;   CTRLPF's SCORE mode.  The playfield's shape never changes; only its
;   colors do.
;
; Two ways to color a playfield:
;   - COLUPF colors the whole playfield (and the ball).  That is the normal
;     state: a green wall.
;   - CTRLPF bit 1 = SCORE splits the playfield at the center: the left
;     half takes COLUP0's color, the right half COLUP1's.  That is the
;     scoreboard trick: one 20-bit pattern, two colors, no extra objects.
;
; The pattern and the gap:
;   PF0 = $F0  -> chunks 0-3   on
;   PF1 = $FF  -> chunks 4-11  on
;   PF2 = $3F  -> chunks 12-17 on, 18-19 off
;
;   Remember PF2's bit order: bit 0 is leftmost, so $3F (00111111) clears
;   the two chunks nearest the center.  Reflect mode mirrors them, so the
;   gap is four chunks wide: chunks 18-21, capture x = 457-552 (96 px).
;
;   Normal state: green wall, dark gap.  Score state: red left half, blue
;   right half, dark gap.  The screen is 40 chunks wide; the gap is at the
;   center, so the color split and the gap line up.
;
; Priority, in one table (the TIA draws the highest level that has a pixel):
;
;   default (CTRLPF bit 2 PFP = 0)     with PFP = 1
;   1  Player 0 + Missile 0 (COLUP0)    1  Playfield + Ball (COLUPF)
;   2  Player 1 + Missile 1 (COLUP1)    2  Player 0 + Missile 0
;   3  Playfield + Ball (COLUPF)        3  Player 1 + Missile 1
;   4  Background (COLUBK)              4  Background
;
;   The playfield is above the background and below the players by
;   default.  PFP lifts the playfield (and ball) above both players — the
;   "playfield in front of sprites" mode.  Its visible effect needs a
;   player or ball, so this lesson teaches the bit and leaves the
;   demonstration to Part 4 (Lesson 25+); no forward object code runs here.
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
; The registers are written in VBLANK; the visible kernel is a 192-line
; WSYNC hold.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), CtrlWrite (one hit per frame; A =
;   $01 normal, $03 score; first change at frame 120), VisibleStart (37),
;   OverscanStart (229).
;
; Build: acme -f plain -o build/lesson20.bin \
;        lessons/part3-playfield/20-playfield-colors/20-playfield-colors.asm
; Run:   stella build/lesson20.bin
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
ANIM_FRAMES    = 120    ; ~2 seconds per color state

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
FrameCounter   = $80
AnimState      = $81    ; 0 = normal color, 1 = score mode

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM; AnimState = 0 (normal color)

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
    +vsync

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the color tick: flip normal <-> score every ANIM_FRAMES frames ---
    INC FrameCounter
    LDA FrameCounter
    CMP #ANIM_FRAMES
    BNE VblankTickDone
    LDA #$00
    STA FrameCounter
    LDA AnimState
    EOR #$01
    STA AnimState
VblankTickDone:

; --- choose the CTRLPF bits: REF always, SCORE only in state 1 ---
    LDA AnimState
    BEQ VblankNormal
    LDA #$03                ; bit 0 REF + bit 1 SCORE
    BNE VblankStoreCtrl     ; (always taken: A = 3)
VblankNormal:
    LDA #$01                ; bit 0 REF only
VblankStoreCtrl:
    STA CTRLPF
CtrlWrite:                  ; debugger checkpoint: A = $01 / $03

; --- the wall and its colors; the pattern never changes ---
    LDA #$F0
    STA PF0                 ; chunks 0-3 on
    LDA #$FF
    STA PF1                 ; chunks 4-11 on
    LDA #$3F
    STA PF2                 ; chunks 12-17 on, 18-19 off (bit 0 first)
    LDA #$C8
    STA COLUPF              ; green: the normal-state color
    LDA #$42
    STA COLUP0              ; red: the score mode's left half
    LDA #$84
    STA COLUP1              ; blue: the score mode's right half
    LDA #$02
    STA COLUBK              ; dark background

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — 192 lines; the TIA redraws the wall every line
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam on line 37
    LDX #VISIBLE_LINES
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
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
