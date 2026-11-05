; =============================================================================
; LESSON 38 — EXERCISE 1 SOLUTION: The Ball, Not the Wall
; =============================================================================
; Part 6: Game Development
;
; The exercise:
;   Change the green band's source from CXP0FB bit 7 (P0-playfield) to
;   CXP0FB bit 6 (P0-ball), and document the new meaning.
;
; The change:
;   The byte that feeds LatchMask bit 5 — the green band's bit — is now taken
;   from CXP0FB bit 6 instead of bit 7.  Band 2 therefore reports the
;   P0-ball pair, the same pair band 1 reports in gold.  The playfield wall
;   is no longer classified: touching it lights no band and adds no hit.
;
; What stays the same:
;   The collision reads, the edge detection, the hit bar, and the beep are
;   unchanged.  The wall still exists and still stops nothing (this is a lab,
;   not a game); it simply has no band of its own any more.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), ReadCX (A = CXP0FB; bit 6 set on a
;   ball hit), CollMask (A = the full mask), CollStep (A = the 0->1 edge
;   bits), CXClear (the strobe), Hits (A = HitCount), BodyStart (37),
;   HmoveApply/HmoveDone, OverscanStart (229).
;
; Build: acme -f plain -o build/ex38-1.bin \
;        lessons/part6-game-dev/38-collision-detection/exercise-01-solution.asm
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

PLAY_TOP       = 24      ; first play-area line
PLAY_BOTTOM    = 172     ; first hit-bar line
P0_MIN_X       = 8
P0_MAX_X       = 144
P0_MIN_Y       = 40
P0_MAX_Y       = 156
P0_HEIGHT      = 16
AUTO_MAX_X     = 80      ; the auto-demo rectangle's right edge
ENEMY_Y        = 40      ; P1's fixed top row
ENEMY_MIN_X    = 40
ENEMY_MAX_X    = 136
BALL_X         = 80
BALL_Y         = 100
BALL_HEIGHT    = 8
M0_HEIGHT      = 4
MISSILE_OFF    = 220     ; a Y outside the play area: the missile is hidden
BEEP_FRAMES    = 8
BEEP_PITCH     = $08     ; AUDF 8 on AUDC $0C: a short, bright hit

C_RED          = $42
C_GOLD         = $1A
C_GREEN        = $C8
C_BLUE         = $84
C_BG           = $02

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
PlayerX     = $80   ; P0's left edge, 8..144
PlayerY     = $81   ; P0's top row, 40..156
AutoPhase   = $82   ; 0 = up, 1 = right, 2 = down, 3 = left
AutoDiv     = $83   ; the auto-demo moves on every second frame
EnemyX      = $84   ; P1's left edge, 40..136
EnemyDir    = $85   ; 1 = right, 0 = left
MissileY    = $86   ; M0's top row; MISSILE_OFF hides it
MissileX    = $87   ; M0's left edge, set when it is fired
LatchMask    = $88   ; bit7 P0-P1, bit6 P0-ball, bit5 P0-PF, bit4 M0-P1
PrevMask    = $89   ; last frame's mask, for the 0->1 edge
NewBits     = $8A   ; the bits that changed from 0 to 1
HitCount    = $8B   ; new contacts, clamped at 15
BeepTimer   = $8C   ; frames of beep remaining
BeepPitch   = $8D   ; AUDF for the beep
FirePrev    = $8E   ; fire button state last frame
InputBits   = $8F   ; this frame's SWCHA read
BandColors  = $90   ; $90-$93: the four band colors
HitPF0      = $94   ; the hit bar's three playfield bytes
HitPF1      = $95
HitPF2      = $96
AutoFireTimer = $97 ; frames until the auto-demo fires M0 again

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the initial scene ---
    LDA #P0_MIN_X
    STA PlayerX             ; P0 starts inside the left wall
    LDA #140
    STA PlayerY
    LDA #0
    STA AutoPhase           ; climb to Y=40 first
    STA AutoDiv
    LDA #ENEMY_MIN_X
    STA EnemyX
    LDA #1
    STA EnemyDir            ; sweep right first
    LDA #MISSILE_OFF
    STA MissileY            ; no missile yet
    LDA #BEEP_PITCH
    STA BeepPitch

; --- the auto-demo's fire clock ---
    LDA #90
    STA AutoFireTimer

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; 1. THE BEEP'S CLOCK — one frame shorter every VBLANK
; -----------------------------------------------------------------------------
    LDA BeepTimer
    BEQ BeepDone
    DEC BeepTimer
    BNE BeepDone
    LDA #$00
    STA AUDV0               ; the last frame of the beep: silence
BeepDone:

; -----------------------------------------------------------------------------
; 2. READ THE COLLISION LATCHES — the previous visible frame's contacts
; -----------------------------------------------------------------------------
; The TIA latches a pair while the two objects are drawn on the same color
; clock.  The read happens in the next VBLANK, so it describes frame N while
; the program is building frame N+1: one frame of latency, by construction.
    LDA CXP0FB              ; bit 7 = P0-playfield, bit 6 = P0-ball
ReadCX:                     ; checkpoint: A = CXP0FB
    AND #$40                ; keep the P0-ball bit in bit 6
    STA LatchMask
    LDA CXP0FB
    AND #$40                ; exercise 1: P0-ball, not P0-playfield
    LSR                     ; bit 6 -> bit 5
    ORA LatchMask
    STA LatchMask
    LDA CXPPMM              ; P0-P1 stays in bit 7
    AND #$80
    ORA LatchMask
    STA LatchMask
    LDA CXM0P               ; M0-P1
    AND #$80
    LSR
    LSR
    LSR                     ; bit 7 -> bit 4
    ORA LatchMask
    STA LatchMask
CollMask:                   ; checkpoint: A = the full mask

; --- 0->1 edges only: a contact that is still held is not a new hit ---
    EOR PrevMask
    AND LatchMask
    STA NewBits
CollStep:                   ; checkpoint: A = the 0->1 edge bits
    LDA LatchMask
    STA PrevMask

; --- count the new bits (0..4) and add them to Hits ---
; The four mask bits live in bits 7-4, so four ASLs shift each one into the
; carry in turn: bit 7 first, then 6, 5, and 4.
    LDA NewBits
    LDX #0
    LDY #4
CountBits:
    ASL
    BCC CountNext
    INX
CountNext:
    DEY
    BNE CountBits
    TXA
    BEQ NoNewHit
    CLC
    ADC HitCount
    CMP #16
    BCC StoreHits
    LDA #15                 ; the bar has only 15 chunks
StoreHits:
    STA HitCount
Hits:                       ; checkpoint: A = Hits after the increment
    LDA #BEEP_FRAMES
    STA BeepTimer
    LDA #$0C                ; AUDC 0C: the div-6 tone from Lesson 35
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0

; --- clear the latches after reading them: this frame starts from zero ---
NoNewHit:
    LDA #$00
    STA CXCLR
CXClear:                    ; checkpoint: the strobe has executed

; -----------------------------------------------------------------------------
; 3. THE FOUR BAND COLORS — $02 unless the pair's mask bit is set
; -----------------------------------------------------------------------------
    LDA #C_BG
    STA BandColors+0
    STA BandColors+1
    STA BandColors+2
    STA BandColors+3

    LDA LatchMask
    AND #$80                ; P0-P1
    BEQ NoBand0
    LDA #C_RED
    STA BandColors+0
NoBand0:
    LDA LatchMask
    AND #$40                ; P0-ball
    BEQ NoBand1
    LDA #C_GOLD
    STA BandColors+1
NoBand1:
    LDA LatchMask
    AND #$20                ; P0-ball (exercise 1; the main band 2 is P0-playfield)
    BEQ NoBand2
    LDA #C_GREEN
    STA BandColors+2
NoBand2:
    LDA LatchMask
    AND #$10                ; M0-P1
    BEQ NoBand3
    LDA #C_BLUE
    STA BandColors+3
NoBand3:

; -----------------------------------------------------------------------------
; 4. THE HIT BAR'S BYTES — computed now so the kernel can write them in HBLANK
; -----------------------------------------------------------------------------
    LDA HitCount
    ASL                     ; Hits * 3: three playfield bytes per entry
    CLC
    ADC HitCount
    TAX
    LDA HitBarPF,X
    STA HitPF0
    LDA HitBarPF+1,X
    STA HitPF1
    LDA HitBarPF+2,X
    STA HitPF2

; -----------------------------------------------------------------------------
; 5. P0'S MOTION — the joystick, or the automatic rectangle
; -----------------------------------------------------------------------------
    LDA SWCHA
    STA InputBits
    AND #$F0
    CMP #$F0                ; all four directions released?
    BEQ AutoDemo

; --- manual: one pixel per frame on each pressed axis, clamped ---
    LDA InputBits
    AND #$10                ; up
    BNE NoUp
    DEC PlayerY
    LDA PlayerY
    CMP #P0_MIN_Y
    BCS NoUp
    LDA #P0_MIN_Y
    STA PlayerY
NoUp:
    LDA InputBits
    AND #$20                ; down
    BNE NoDown
    INC PlayerY
    LDA PlayerY
    CMP #(P0_MAX_Y + 1)
    BCC NoDown
    LDA #P0_MAX_Y
    STA PlayerY
NoDown:
    LDA InputBits
    AND #$40                ; left
    BNE NoLeft
    DEC PlayerX
    LDA PlayerX
    CMP #P0_MIN_X
    BCS NoLeft
    LDA #P0_MIN_X
    STA PlayerX
NoLeft:
    LDA InputBits
    AND #$80                ; right
    BNE NoRight
    INC PlayerX
    LDA PlayerX
    CMP #(P0_MAX_X + 1)
    BCC NoRight
    LDA #P0_MAX_X
    STA PlayerX
NoRight:
    JMP MoveDone

; --- auto-demo: one pixel every two frames around the rectangle.
;     With no joystick input it also fires M0 every 90 frames, so the
;     M0-P1 band demonstrates itself. ---
AutoDemo:
    DEC AutoFireTimer
    BNE AutoFireDone
    LDA #90
    STA AutoFireTimer
    LDA PlayerY
    STA MissileY
    LDA PlayerX
    STA MissileX
AutoFireDone:
    INC AutoDiv
    LDA AutoDiv
    AND #$01
    BNE MoveDone
    LDA AutoPhase
    CMP #0
    BEQ AutoUp
    CMP #1
    BEQ AutoRight
    CMP #2
    BEQ AutoDown
    JMP AutoLeft

AutoUp:
    DEC PlayerY
    LDA PlayerY
    CMP #P0_MIN_Y
    BCS MoveDone
    LDA #P0_MIN_Y
    STA PlayerY
    LDA #1
    STA AutoPhase
    JMP MoveDone
AutoRight:
    INC PlayerX
    LDA PlayerX
    CMP #(AUTO_MAX_X + 1)
    BCC MoveDone
    LDA #AUTO_MAX_X
    STA PlayerX
    LDA #2
    STA AutoPhase
    JMP MoveDone
AutoDown:
    INC PlayerY
    LDA PlayerY
    CMP #157
    BCC MoveDone
    LDA #P0_MAX_Y
    STA PlayerY
    LDA #3
    STA AutoPhase
    JMP MoveDone
AutoLeft:
    DEC PlayerX
    LDA PlayerX
    CMP #P0_MIN_X
    BCS MoveDone
    LDA #P0_MIN_X
    STA PlayerX
    LDA #0
    STA AutoPhase
MoveDone:

; -----------------------------------------------------------------------------
; 6. P1'S SWEEP — 40..136, one pixel per frame
; -----------------------------------------------------------------------------
    LDA EnemyDir
    BNE EnemyRight
    DEC EnemyX
    LDA EnemyX
    CMP #ENEMY_MIN_X
    BCS EnemyDone
    LDA #ENEMY_MIN_X
    STA EnemyX
    LDA #1
    STA EnemyDir
    JMP EnemyDone
EnemyRight:
    INC EnemyX
    LDA EnemyX
    CMP #(ENEMY_MAX_X + 1)
    BCC EnemyDone
    LDA #ENEMY_MAX_X
    STA EnemyX
    LDA #0
    STA EnemyDir
EnemyDone:

; -----------------------------------------------------------------------------
; 7. FIRE — a new press launches M0 from P0's position
; -----------------------------------------------------------------------------
    LDA INPT4               ; bit 7: 0 = pressed
    AND #$80
    BNE FireReleased
    LDA FirePrev
    BNE FireHeld
    LDA PlayerY
    STA MissileY
    LDA PlayerX
    STA MissileX
FireHeld:
    LDA #1
    STA FirePrev
    JMP FireDone
FireReleased:
    LDA #0
    STA FirePrev
FireDone:

; --- the missile climbs two pixels per frame and resets at the top ---
    LDA MissileY
    CMP #MISSILE_OFF
    BEQ MissileDone
    SEC
    SBC #2
    CMP #PLAY_TOP
    BCS MissileStore
    LDA #MISSILE_OFF
MissileStore:
    STA MissileY
MissileDone:

; -----------------------------------------------------------------------------
; 8. POSITION ALL FOUR MOVABLE OBJECTS, THEN STROBE ONE HMOVE
; -----------------------------------------------------------------------------
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA EnemyX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
    LDA MissileX
    CLC
    ADC #(POS_BIAS + 1)     ; missiles have a 4-clock reset, one pixel left
    JSR SetCoarseM0
; The ball's output delay is one clock shorter than a player's (Lesson 29),
; so its target needs one extra pixel to land on BALL_X.
    LDA #(BALL_X + POS_BIAS + 1)
    JSR SetCoarseBL
    STA WSYNC
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed (next line, cycle 3)

; -----------------------------------------------------------------------------
; 9. COLORS, SIZES, AND THE WALL — the playfield is off during the bands
; -----------------------------------------------------------------------------
    LDA #C_RED
    STA COLUP0              ; P0 and M0 are both red
    LDA #C_BLUE
    STA COLUP1              ; P1 and M1 are both blue
    LDA #C_GOLD
    STA COLUPF              ; the wall, the ball, and the hit bar
    LDA #C_BG
    STA COLUBK
    LDA #$00
    STA NUSIZ0              ; P0 normal; M0 one pixel wide
    STA NUSIZ1              ; P1 normal; M1 one pixel wide
    STA ENAM1               ; M1 is not used in this ROM
    STA PF0                 ; the bands and the bottom are not playfield
    STA PF1
    STA PF2
    LDA #$01
    STA CTRLPF              ; reflect the playfield; ball one pixel wide

    +wait_timer

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
    LDA #$00
    STA VBLANK

BodyStart:                  ; checkpoint: the first visible line (scanline 37)
; --- visible 0-23: four 6-line collision bands ---
    LDX #0
BandLoop:
    LDA BandColors,X
    STA COLUBK
    LDY #6
BandLines:
    STA WSYNC
    DEY
    BNE BandLines
    INX
    CPX #4
    BNE BandLoop

; --- visible 24: the wall goes on and the play area begins ---
    LDA #C_BG
    STA COLUBK
    LDA #$F0
    STA PF0                 ; PF0 bits 4-7: the 16-px left wall
    LDA #$00
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL

; --- visible 24-39: only M0 can be up here ---
    LDX #PLAY_TOP
ZoneA:
    TXA
    SEC
    SBC MissileY
    CMP #M0_HEIGHT
    LDA #$00
    BCS ZoneAM0Off
    LDA #$02
ZoneAM0Off:
    STA ENAM0
    STA WSYNC
    INX
    CPX #ENEMY_Y
    BNE ZoneA

; --- visible 40-55: P1 is always here; P0 and M0 may be ---
; P0's write comes first so it lands in HBLANK.  The GRP1 write is after it:
; P1 starts at X>=40, so a write at X~1 still reaches P1's pixels in time.
    LDX #ENEMY_Y
ZoneB:
    TXA
    SEC
    SBC PlayerY
    CMP #P0_HEIGHT
    LDA #$00
    BCS ZoneBP0Off
    LDA #$FF
ZoneBP0Off:
    STA GRP0
    LDA #$FF
    STA GRP1
    TXA
    SEC
    SBC MissileY
    CMP #M0_HEIGHT
    LDA #$00
    BCS ZoneBM0Off
    LDA #$02
ZoneBM0Off:
    STA ENAM0
    STA WSYNC
    INX
    CPX #(ENEMY_Y + P0_HEIGHT)
    BNE ZoneB
    LDA #$00
    STA GRP1

; --- visible 56-99: P0 and M0 ---
    LDX #56
ZoneC:
    TXA
    SEC
    SBC PlayerY
    CMP #P0_HEIGHT
    LDA #$00
    BCS ZoneCP0Off
    LDA #$FF
ZoneCP0Off:
    STA GRP0
    TXA
    SEC
    SBC MissileY
    CMP #M0_HEIGHT
    LDA #$00
    BCS ZoneCM0Off
    LDA #$02
ZoneCM0Off:
    STA ENAM0
    STA WSYNC
    INX
    CPX #BALL_Y
    BNE ZoneC

; --- visible 100-107: the ball sits here; P0 and M0 may pass ---
; As in zone B, P0's write goes first; ENABL is written after it, at X~1,
; well before the ball's X=80.
    LDX #BALL_Y
ZoneD:
    TXA
    SEC
    SBC PlayerY
    CMP #P0_HEIGHT
    LDA #$00
    BCS ZoneDP0Off
    LDA #$FF
ZoneDP0Off:
    STA GRP0
    LDA #$02
    STA ENABL
    TXA
    SEC
    SBC MissileY
    CMP #M0_HEIGHT
    LDA #$00
    BCS ZoneDM0Off
    LDA #$02
ZoneDM0Off:
    STA ENAM0
    STA WSYNC
    INX
    CPX #(BALL_Y + BALL_HEIGHT)
    BNE ZoneD
    LDA #$00
    STA ENABL

; --- visible 108-171: P0 and M0 ---
    LDX #108
ZoneE:
    TXA
    SEC
    SBC PlayerY
    CMP #P0_HEIGHT
    LDA #$00
    BCS ZoneEP0Off
    LDA #$FF
ZoneEP0Off:
    STA GRP0
    TXA
    SEC
    SBC MissileY
    CMP #M0_HEIGHT
    LDA #$00
    BCS ZoneEM0Off
    LDA #$02
ZoneEM0Off:
    STA ENAM0
    STA WSYNC
    INX
    CPX #(PLAY_BOTTOM - 1)
    BNE ZoneE

; --- line 171: the last play-area line.  Draw its P0/M0 work, preload the
;     hit-bar bytes in Y/A/X, then store them in line 172's HBLANK together
;     with the clears that stop P0 and the missile at row 171. ---
    TXA
    SEC
    SBC PlayerY
    CMP #P0_HEIGHT
    LDA #$00
    BCS LastP0Off
    LDA #$FF
LastP0Off:
    STA GRP0
    TXA
    SEC
    SBC MissileY
    CMP #M0_HEIGHT
    LDA #$00
    BCS LastM0Off
    LDA #$02
LastM0Off:
    STA ENAM0
    LDY HitPF0
    LDA HitPF1
    LDX HitPF2
    STA WSYNC               ; end line 171
; --- line 172 HBLANK: the bar's three bytes, then blank P0 and the missile ---
    STY PF0
    STA PF1
    STX PF2
    LDA #$00
    STA GRP0
    STA ENAM0
    STA ENAM1

; --- visible 172-177: the 15-chunk hit bar, mirrored by CTRLPF ---
    LDY #6
HitBarLoop:
    STA WSYNC
    DEY
    BNE HitBarLoop

; --- visible 178-191: the bottom background ---
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #14
BottomLoop:
    STA WSYNC
    DEY
    BNE BottomLoop

; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines
; -----------------------------------------------------------------------------
OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; COARSE POSITIONING — four objects, one HMOVE at the end
; =============================================================================
; A = the target TIA X plus POS_BIAS.  Each routine strobes its RESxx and
; leaves the fine value in its HMPx; the caller's single HMOVE applies all
; four fine offsets in one HBLANK (the one-HMOVE rule from Lesson 28/29).
SetCoarseP0:
    STA WSYNC
    SEC
DivP0:
    SBC #15
    BCS DivP0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    RTS

SetCoarseP1:
    STA WSYNC
    SEC
DivP1:
    SBC #15
    BCS DivP1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
    STA RESP1
    RTS

SetCoarseM0:
    STA WSYNC
    SEC
DivM0:
    SBC #15
    BCS DivM0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMM0
    STA RESM0
    RTS

SetCoarseBL:
    STA WSYNC
    SEC
DivBL:
    SBC #15
    BCS DivBL
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMBL
    STA RESBL
    RTS

; =============================================================================
; HIT-BAR TABLE — N chunks from the left, three playfield bytes per entry
; =============================================================================
; PF0 bits 4-7 are the first four chunks (bit 4 leftmost); PF1 bits 7-0 are
; the next eight (bit 7 leftmost); PF2 bits 0-2 are the last three (bit 0 is
; leftmost, because PF2's bit order is reversed).  CTRLPF=$01 mirrors the
; same chunks from the right edge.
HitBarPF:
    !byte $00,$00,$00       ; 0 chunks
    !byte $10,$00,$00       ; 1
    !byte $30,$00,$00       ; 2
    !byte $70,$00,$00       ; 3
    !byte $F0,$00,$00       ; 4
    !byte $F0,$80,$00       ; 5
    !byte $F0,$C0,$00       ; 6
    !byte $F0,$E0,$00       ; 7
    !byte $F0,$F0,$00       ; 8
    !byte $F0,$F8,$00       ; 9
    !byte $F0,$FC,$00       ; 10
    !byte $F0,$FE,$00       ; 11
    !byte $F0,$FF,$00       ; 12
    !byte $F0,$FF,$01       ; 13
    !byte $F0,$FF,$03       ; 14
    !byte $F0,$FF,$07       ; 15

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
