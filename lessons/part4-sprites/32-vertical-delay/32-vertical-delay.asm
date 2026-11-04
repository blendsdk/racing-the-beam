; =============================================================================
; LESSON 32: Vertical Delay — VDELP0, VDELP1 — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   Draws two identical 16-row striped blocks, one red (P0) and one blue
;   (P1).  P1 has VDELP1 set, so its graphic is delayed by one scanline:
;   P1 appears exactly one line lower than P0.  The one-line offset is the
;   visible proof of the vertical-delay latch.
;
; What VDEL does:
;   VDELP0/VDELP1 bit 0 delays that player's graphic output by one scanline.
;   The graphic register is double-buffered: the value written on line N is
;   displayed on line N+1.  The copy is cross-coupled: a GRP0 write latches
;   player 1's pending graphic, and a GRP1 write latches player 0's.  The
;   delay is uniform, so the whole sprite shifts down one line; nothing
;   accumulates.
;
;   The latch is useful when a kernel needs to stage the next line's shape
;   while the current line is still displayed.  The 48-pixel trick and
;   flicker-free animation are the classic uses; they are named here, not
;   implemented.
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
; Both sprites start at visible line 88 (scanline 125): 88 top + 16 body +
; 1 clear + 87 bottom = 192.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), PosApply0/PosApply1, Resp0Write/
;   Resp1Write, HmoveApply, VisibleStart (37), BodyStart (125, 16 hits),
;   VdelWrite (A = $01), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson32.bin \
;        lessons/part4-sprites/32-vertical-delay/32-vertical-delay.asm
; Run:   stella build/lesson32.bin
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
SPRITE_HEIGHT  = 16
P0_X           = 48
P1_X           = 104
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

    LDA #(P0_X + POS_BIAS)
PosApply0:                  ; checkpoint: P0's biased target
    JSR SetCoarse0
    LDA #(P1_X + POS_BIAS)
PosApply1:                  ; checkpoint: P1's biased target
    JSR SetCoarse1
    STA WSYNC
HmoveApply:                 ; checkpoint: the single HMOVE
    STA HMOVE

    LDA #$42
    STA COLUP0
    LDA #$84
    STA COLUP1
    LDA #$02
    STA COLUBK
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    STA REFP0
    STA REFP1
    LDA #$01
VdelWrite:                  ; checkpoint: A = $01
    STA VDELP1              ; delay player 1 by one scanline

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — identical shapes; P1 is one line lower
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
    LDA Shape,X
    STA GRP0
    LDA Shape,X
    STA GRP1
    STA WSYNC
    INX
    CPX #SPRITE_HEIGHT
    BNE BodyLoop

    LDA #$00
    STA GRP0                ; trigger the delayed copy of the last row
    STA GRP1                ; then clear the primary
    STA WSYNC

    LDX #(VISIBLE_LINES - SPRITE_TOP - SPRITE_HEIGHT - 1)
BottomLoop:
    STA GRP0                ; keep triggering the delayed copy with 0
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
; COARSE POSITIONING — two players, one HMOVE
; =============================================================================
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
Resp0Write:                 ; checkpoint: P0's coarse strobe
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
Resp1Write:                 ; checkpoint: P1's coarse strobe
    STA RESP1
    RTS

; =============================================================================
; SHAPE — a 16-row striped block
; =============================================================================
Shape:
    !byte %11111111
    !byte %10000001
    !byte %10000001
    !byte %10000001
    !byte %11111111
    !byte %10000001
    !byte %10000001
    !byte %10000001
    !byte %11111111
    !byte %10000001
    !byte %10000001
    !byte %10000001
    !byte %11111111
    !byte %10000001
    !byte %10000001
    !byte %10000001

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
