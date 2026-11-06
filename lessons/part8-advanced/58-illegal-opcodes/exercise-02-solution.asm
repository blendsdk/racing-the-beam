; =============================================================================
; LESSON 58 — EXERCISE 2 SOLUTION: A DCP Countdown
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   DCP zp decrements a zero-page byte and then compares A with the new value.
;   With A = 0 the compare is "0 versus the counter", so the zero flag is set
;   exactly when the counter reaches 0.  This solution uses that as a countdown:
;
;       LDA #$00
;       +DCP_ZP Counter     ; Counter = Counter - 1; CMP 0,Counter
;       BEQ  ReachedZero    ; taken when Counter becomes 0
;
;   The screen is a 192-line gauge:
;     visible   0-63   the "DCP" title block
;     visible  64-127  the counter bar: chunks 2-3, height Counter x 2
;     visible 128-191  the status band: the live P byte as eight chunks
;                      (PF1 = P), plus a zero indicator at chunks 2-3
;   The counter steps once every 15 frames, from 32 down to 0; at zero the
;   background flashes red for 15 frames, then the counter reloads to 32.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;
; ACME 0.97 has no DCP mnemonic under !cpu 6502; !cpu 6510 accepts it, but this
; course keeps !cpu 6502 and the named macro emits the opcode byte and the
; zero-page operand so the byte stays visible: DCP $80 is $C7 $80.
;
; RAM map ($80-$8A; +clean_start zeroes every byte):
;   $80 Counter    32 down to 0
;   $81 Tick       the 15-frame divider
;   $82 Pause      frames left in the zero flash
;   $83 Flags      the live P after the last DCP
;   $84 BarStart   64 - (Counter x 2)
;   $85 Tmp        scratch
;   $86-$9F free
;   $F8-$FF stack
;
; Checkpoints: StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   OverscanStart (229/6), DcpCount (A = the counter), ReachedZero (A = 0,
;   Z = 1), DcpFlags (P after the DCP), CountFlags (the capture path).
;
; Build: acme -f plain -o build/exercise-02.bin \
;        lessons/part8-advanced/58-illegal-opcodes/exercise-02-solution.asm
; Run:   stella build/exercise-02.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- the undocumented opcode as a named macro --------------------------------
!macro DCP_ZP .addr {
    !byte $C7, .addr        ; DCP zp: M = M-1, then CMP A,M
}

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36

TITLE_LINES    = 16
TITLE_BLANK    = 48
BAR_LINES      = 64
STATUS_LINES   = 64

COUNTER_START  = 32
TICK_FRAMES    = 15
PAUSE_FRAMES   = 15

C_BG           = $00
C_TITLE        = $1A
C_BAR          = $C8
C_STATUS       = $0E
C_FLASH        = $46

; --- RAM ---------------------------------------------------------------------
Counter     = $80
Tick        = $81
Pause       = $82
Flags       = $83
BarStart    = $84
Tmp         = $85

    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA SWACNT

    LDA #COUNTER_START
    STA Counter
    LDA #$00
    STA Tick
    STA Pause
    STA Flags

; --- the TIA's fixed state ----------------------------------------------------
    LDA #C_BG
    STA COLUBK
    LDA #C_TITLE
    STA COLUPF
    LDA #$01
    STA CTRLPF
    LDA #$00
    STA NUSIZ0
    STA GRP0
    STA PF0
    STA PF1
    STA PF2

    JMP StartFrame

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                  ; checkpoint: scanline 259
    +vsync
VblankStart:                 ; checkpoint: scanline 0
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; 1. THE COUNTDOWN CLOCK — one DCP step every 15 frames
; -----------------------------------------------------------------------------
    LDA Pause
    BEQ CountStep
    DEC Pause
    BNE CountDone
    LDA #COUNTER_START       ; the flash is over: reload
    STA Counter
    LDA #C_BG
    STA COLUBK
    JMP CountDone

CountStep:
    INC Tick
    LDA Tick
    CMP #TICK_FRAMES
    BCC CountDone
    LDA #$00
    STA Tick

; --- the DCP countdown --------------------------------------------------------
    LDA #$00
    +DCP_ZP Counter          ; ACME emits $C7 $80
    PHP                      ; save the DCP flags before the zero path changes them
DcpFlags:                    ; checkpoint: P after the DCP (Z=1 at zero)
    BEQ ReachedZero
    JMP CountFlags
ReachedZero:                 ; checkpoint: A = 0, Z = 1
    LDA #PAUSE_FRAMES
    STA Pause
    LDA #C_FLASH
    STA COLUBK
CountFlags:
    PLA
    AND #$EF                 ; clear the PHP B marker
    STA Flags
    LDA Counter
DcpCount:                    ; checkpoint: A = the counter, 0..31
    ASL
    STA Tmp
    LDA #BAR_LINES
    SEC
    SBC Tmp
    STA BarStart

CountDone:
    +wait_timer
    LDA #$00
    STA VBLANK

; -----------------------------------------------------------------------------
; Zone 1: 64 title lines — the DCP block and 48 blanks
; -----------------------------------------------------------------------------
BodyStart:                   ; checkpoint: scanline 37, visible line 0
    LDA #C_TITLE
    STA COLUPF
    LDY #0
TitleRow:
    LDA TitlePF0,Y
    STA PF0
    LDA TitlePF1,Y
    STA PF1
    LDA TitlePF2,Y
    STA PF2
    STA WSYNC
    INY
    CPY #TITLE_LINES
    BNE TitleRow

    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #TITLE_BLANK
TitleBlank:
    STA WSYNC
    DEY
    BNE TitleBlank

; -----------------------------------------------------------------------------
; Zone 2: 64 lines — the counter bar at chunks 2-3
; -----------------------------------------------------------------------------
    LDA #C_BAR
    STA COLUPF
    LDY #0
BarRow:
    LDA #$00
    STA PF0
    CPY BarStart
    BCC BarNoBar
    LDA #$C0
    STA PF0
BarNoBar:
    STA WSYNC
    INY
    CPY #BAR_LINES
    BNE BarRow

; -----------------------------------------------------------------------------
; Zone 3: 64 lines — the P byte and the zero indicator
; -----------------------------------------------------------------------------
    LDA #C_STATUS
    STA COLUPF
    LDA Flags
    STA PF1                  ; the live P as eight chunks at chunks 4-11
    LDA #$00
    STA PF2
    LDA #$00
    STA PF0
    LDA Counter
    BNE StatusNoZero
    LDA #$C0                 ; the zero indicator at chunks 2-3
    STA PF0
StatusNoZero:
    LDY #0
StatusRow:
    STA WSYNC
    INY
    CPY #STATUS_LINES
    BNE StatusRow

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:               ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; THE DATA
; =============================================================================
    !if * > $F800 {
        !error "the code must end before $F800"
    }
    !fill $F800 - *, $EA

; --- the 16-line "DCP" title --------------------------------------------------
TitlePF0:
    !byte $F0, $10, $D0, $50, $50, $50, $50, $50
    !byte $D0, $10, $10, $10, $10, $10, $10, $F0
TitlePF1:
    !byte $FF, $00, $8E, $50, $50, $50, $50, $50
    !byte $8E, $00, $00, $00, $00, $00, $00, $FF
TitlePF2:
    !byte $FF, $80, $87, $89, $89, $87, $81, $81
    !byte $81, $80, $80, $80, $80, $80, $80, $FF

; -----------------------------------------------------------------------------
; The vectors
; -----------------------------------------------------------------------------
    !if * > $FFFA {
        !error "the data must end before $FFFA"
    }
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset, Reset, Reset
