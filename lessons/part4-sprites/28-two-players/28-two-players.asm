; =============================================================================
; LESSON 28: Two Players — GRP0 and GRP1 — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   Draws both players on the same eight scanlines: player 0 in red at X=48,
;   player 1 in blue at X=104.  Each has its own shape table and color.
;   The two players share the line budget but not their graphics.
;
; The two players:
;   GRP0 and GRP1 follow the same rules: 8 bits wide, bit 7 leftmost, one
;   write per scanline.  COLUP0/COLUP1 color them; RESP0/RESP1 position
;   them; HMP0/HMP1 carry their fine offsets.
;
; One HMOVE for both:
;   The classic divide-by-15 routine ends with its own HMOVE.  Calling it
;   twice would apply the first object's HMP0 again while positioning the
;   second object — the HM registers persist.  This lesson splits the
;   routine: SetCoarse0 and SetCoarse1 set their HMPx and strobe their
;   RESPx, then one HMOVE applies both fine offsets.  Both HM registers are
;   rewritten every frame before the single strobe, so nothing accumulates.
;   This is the one-HMOVE rule for multi-object kernels.
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
; Both sprites start at visible line 88 (scanline 125): 88 top lines, 8 body
; rows writing both players, one clear line, 95 bottom lines.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), PosApply0/PosApply1 (A = the biased
;   X targets), Resp0Write/Resp1Write (the coarse strobes), HmoveApply (the
;   single fine-motion strobe), VisibleStart (37), BodyStart (125),
;   OverscanStart (229).
;
; Build: acme -f plain -o build/lesson28.bin \
;        lessons/part4-sprites/28-two-players/28-two-players.asm
; Run:   stella build/lesson28.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
SPRITE_TOP     = 88
SPRITE_HEIGHT  = 8
P0_TARGET      = 48
P1_TARGET      = 104
POS_BIAS       = 3

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- position both players, then apply both fine offsets once ---
    LDA #(P0_TARGET + POS_BIAS)
PosApply0:                  ; checkpoint: A = P0's biased target
    JSR SetCoarse0
    LDA #(P1_TARGET + POS_BIAS)
PosApply1:                  ; checkpoint: A = P1's biased target
    JSR SetCoarse1
    STA WSYNC
HmoveApply:                 ; checkpoint: the single HMOVE
    STA HMOVE               ; store applied at cycle 2; next instruction at cycle 3
AfterHmove:                 ; verification label: the instruction after HMOVE

    LDA #$42
    STA COLUP0              ; red
    LDA #$84
    STA COLUP1              ; blue
    LDA #$02
    STA COLUBK              ; dark neutral
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    STA REFP0
    STA REFP1

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — both players on the same eight lines
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK
    LDX #SPRITE_TOP
VisibleStart:
TopLoop:
    STA WSYNC
    DEX
    BNE TopLoop

    LDX #0
BodyStart:
BodyLoop:
    LDA ShapeP0,X
    STA GRP0
    LDA ShapeP1,X
    STA GRP1
    STA WSYNC
    INX
    CPX #SPRITE_HEIGHT
    BNE BodyLoop

    LDA #$00
    STA GRP0
    STA GRP1
    STA WSYNC

    LDX #(VISIBLE_LINES - SPRITE_TOP - SPRITE_HEIGHT - 1)
BottomLoop:
    STA WSYNC
    DEX
    BNE BottomLoop

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; COARSE POSITIONING — set HMPx and strobe RESPx; no HMOVE here
; =============================================================================
; Input: A = the biased target (target + 3).
SetCoarse0:
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
Resp0Write:
    STA RESP0
    RTS

SetCoarse1:
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
Resp1Write:
    STA RESP1
    RTS

; =============================================================================
; SHAPES — two different 8-row creatures
; =============================================================================
ShapeP0:
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %11011011
    !byte %11111111
    !byte %00100100
    !byte %01011010
    !byte %10100101

ShapeP1:
    !byte %00111100
    !byte %01111110
    !byte %11111111
    !byte %11011011
    !byte %11111111
    !byte %01100110
    !byte %00111100
    !byte %00011000

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
