; =============================================================================
; LESSON 77 — EXERCISE 2 SOLUTION: Field Interlacing for Doubled Resolution
; =============================================================================
; Part 11: Legendary Techniques
;
; The exercise (stretch): field-interlace a 96-line bitmap so the eye sees a
; 192-line picture.
;
; THE IDEA
;   The 2600 can only draw 192 visible scanlines per frame, and a normal
;   bitmap stores one byte per scanline.  This ROM stores TWO 96-row bitmaps
;   and shows only one of them per frame, on every other scanline:
;
;     frame with Phase 0   field A on visible lines 0, 2, 4, ..., 190
;                          (the odd lines are blank)
;     frame with Phase 1   field B on visible lines 1, 3, 5, ..., 191
;                          (the even lines are blank)
;
;   Each field row is two scanlines tall: one line carries the row's three
;   playfield bytes, the other line clears them.  Over two frames the eye
;   integrates the two fields and sees every scanline of a 192-line picture
;   at 30 Hz.  A still capture shows ONE field: the picture with every other
;   scanline black.
;
; THE PICTURE
;   A 192-line image built from a single formula: image line y lights the
;   first n chunks of the 20-chunk playfield, with
;
;     n = 1 + (y & 15)          n = 1..16, a sawtooth every 16 lines
;
;   CTRLPF's REFLECT bit mirrors the left half, so each line is a bar that
;   grows from the left and right edges toward the centre and closes again
;   every 16 lines: twelve "irises" down the screen.
;
;   Field A holds the EVEN image lines (n = 1, 3, 5, ... 15) and field B the
;   ODD ones (n = 2, 4, 6, ... 16).  In one field the bar's edge advances one
;   chunk every TWO scanlines; interlaced the edge advances one chunk every
;   scanline.  That halving of the step height is the doubled resolution: the
;   screen addresses 192 distinct lines instead of 96 two-line rows.
;
; THE PRICE
;   Every scanline is now lit on only half the frames, so the interlaced
;   picture is about half as bright as a normal one, and each line refreshes
;   at 30 Hz.  A one-scanline feature cannot be shown by one field at all;
;   it can only exist in the union.  That is why the technique is a curiosity
;   on a stock 2600 and a standard tool on machines with real 2:1 interlace.
;
; THE DATA
;   A 96-row field is 96 x 3 = 288 bytes of playfield bytes; two fields are
;   576 bytes, a seventh of the cartridge.  The tables are written out in the
;   source (they are data, not code) and were generated from the formula above.
;
; THE DEMO
;   The phase alternates every frame for two seconds, then holds field A for
;   two seconds, then field B for two seconds, then restarts.  SELECT toggles
;   the freeze by hand.  The two held windows are what a still capture can
;   show: one field each.
;
;   Frame: 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262 lines.
;   ROM: 4,096 bytes.
;
; RAM map:
;   $80 Phase       0 = field A, 1 = field B
;   $81 Freeze      1 = hold the current phase
;   $82 AutoDemo    1 until SELECT is pressed; then 0
;   $83 FrameLo     frame counter low byte
;   $84 DemoTimer   frames inside the current two-second segment (0..119)
;   $85 PrevSelect  SELECT edge latch
;   $86 DemoStep    0 alternate, 1 hold field A, 2 hold field B
;   $87-$F7         free
;   $F8-$FF         the stack
;
; Build: acme -f plain -o build/exercise-02.bin \
;        lessons/part11-legendary/77-interlaced-flicker/exercise-02-solution.asm
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36

FIELD_ROWS     = 96      ; 96 rows per field, two scanlines per row
VISIBLE_LINES  = FIELD_ROWS * 2   ; 192

DEMO_SEGMENT   = 120     ; 2 s per segment

C_BAR          = $CA     ; hue 12, level 5: the green bar

Phase        = $80
Freeze       = $81
AutoDemo     = $82
FrameLo      = $83
DemoTimer    = $84
PrevSelect   = $85
DemoStep     = $86

!if FIELD_ROWS * 2 != VISIBLE_LINES {
    !error "96 rows of two scanlines must total 192 visible lines"
}

    * = $F000

; =============================================================================
; RESET
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT
    STA NUSIZ0
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL
    STA COLUP0
    STA COLUP1
    STA COLUBK              ; the gaps between the bars: black
    LDA #$01
    STA CTRLPF              ; REFLECT the playfield (bit 0)
    LDA #C_BAR
    STA COLUPF              ; the bar colour

    LDA #$00
    STA Phase
    STA Freeze
    STA FrameLo
    STA DemoTimer
    STA PrevSelect
    STA DemoStep
    LDA #$01
    STA AutoDemo

; =============================================================================
; FRAME
; =============================================================================
StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    INC FrameLo

; --- SELECT: freeze by hand --------------------------------------------------
    LDA SWCHB
    AND #$02
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA #$00
    STA AutoDemo
    LDA Freeze
    EOR #$01
    STA Freeze
    JMP SelectDone
SelectReleased:
    LDA #$00
    STA PrevSelect
SelectDone:

; --- the auto-demo: alternate, hold A, hold B, restart -----------------------
    LDA AutoDemo
    BEQ DemoDone
    INC DemoTimer
    LDA DemoTimer
    CMP #DEMO_SEGMENT
    BCC DemoDone
    LDA #$00
    STA DemoTimer
    INC DemoStep
    LDA DemoStep
    CMP #$01
    BNE DemoStep2
    LDA #$01
    STA Freeze
    LDA #$00
    STA Phase               ; hold field A
    JMP DemoDone
DemoStep2:
    CMP #$02
    BNE DemoStep3
    LDA #$01
    STA Phase               ; hold field B
    JMP DemoDone
DemoStep3:
    LDA #$00
    STA Freeze
    STA DemoStep
DemoDone:

; --- one phase step per frame ------------------------------------------------
    LDA Freeze
    BNE PhaseFixed
    LDA Phase
    EOR #$01
    STA Phase
PhaseFixed:

    +wait_timer
    LDA #$00
    STA VBLANK

; =============================================================================
; VISIBLE LINES 0-191: TWO KERNELS, ONE PER FIELD
; =============================================================================
; Phase picks the kernel once per frame, so no row pays for a branch.  Each
; row is two scanlines: the pattern line and the blank line.
;
; Field A's pattern line is the EVEN line of the row (visible 2k).  Its first
; playfield write completes at cycle 19 of the line, before the beam reaches
; pixel 0 at 22.67; every later row starts from a WSYNC release and completes
; PF0 at cycle 14.  Field B's pattern line is the ODD line, so its writes
; start directly after the WSYNC release — the earliest possible moment.
BodyStart:
    LDX #$00
    LDA Phase
    BNE FieldB

; --- field A: pattern on the even line, blank on the odd line ----------------
RowA:
    LDA FieldA0,X
    STA PF0
    LDA FieldA1,X
    STA PF1
    LDA FieldA2,X
    STA PF2
    LDA #$00
    STA WSYNC               ; end visible line 2k (the pattern line)
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC               ; end visible line 2k+1 (blank)
    INX
    CPX #FIELD_ROWS
    BNE RowA
    JMP BodyDone

; --- field B: blank on the even line, pattern on the odd line ----------------
FieldB:
RowB:
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC               ; end visible line 2k (blank)
    LDA FieldB0,X
    STA PF0
    LDA FieldB1,X
    STA PF1
    LDA FieldB2,X
    STA PF2
    STA WSYNC               ; end visible line 2k+1 (the pattern line)
    INX
    CPX #FIELD_ROWS
    BNE RowB

BodyDone:
OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; THE TWO FIELDS — 96 rows x 3 playfield bytes each
; =============================================================================
; Row k of field A is image line 2k, width 1 + (2k & 15) chunks; row k of
; field B is image line 2k+1, width 1 + ((2k+1) & 15) chunks.  Each row is
; PF0 (chunks 0-3), PF1 (chunks 4-11), PF2 (chunks 12-19) in the left half;
; REFLECT draws the right half as the mirror.
FieldA0:
    !byte $10, $70, $F0, $F0, $F0, $F0, $F0, $F0, $10, $70, $F0, $F0   ; rows 0-11
    !byte $F0, $F0, $F0, $F0, $10, $70, $F0, $F0, $F0, $F0, $F0, $F0   ; rows 12-23
    !byte $10, $70, $F0, $F0, $F0, $F0, $F0, $F0, $10, $70, $F0, $F0   ; rows 24-35
    !byte $F0, $F0, $F0, $F0, $10, $70, $F0, $F0, $F0, $F0, $F0, $F0   ; rows 36-47
    !byte $10, $70, $F0, $F0, $F0, $F0, $F0, $F0, $10, $70, $F0, $F0   ; rows 48-59
    !byte $F0, $F0, $F0, $F0, $10, $70, $F0, $F0, $F0, $F0, $F0, $F0   ; rows 60-71
    !byte $10, $70, $F0, $F0, $F0, $F0, $F0, $F0, $10, $70, $F0, $F0   ; rows 72-83
    !byte $F0, $F0, $F0, $F0, $10, $70, $F0, $F0, $F0, $F0, $F0, $F0   ; rows 84-95
FieldA1:
    !byte $00, $00, $80, $E0, $F8, $FE, $FF, $FF, $00, $00, $80, $E0   ; rows 0-11
    !byte $F8, $FE, $FF, $FF, $00, $00, $80, $E0, $F8, $FE, $FF, $FF   ; rows 12-23
    !byte $00, $00, $80, $E0, $F8, $FE, $FF, $FF, $00, $00, $80, $E0   ; rows 24-35
    !byte $F8, $FE, $FF, $FF, $00, $00, $80, $E0, $F8, $FE, $FF, $FF   ; rows 36-47
    !byte $00, $00, $80, $E0, $F8, $FE, $FF, $FF, $00, $00, $80, $E0   ; rows 48-59
    !byte $F8, $FE, $FF, $FF, $00, $00, $80, $E0, $F8, $FE, $FF, $FF   ; rows 60-71
    !byte $00, $00, $80, $E0, $F8, $FE, $FF, $FF, $00, $00, $80, $E0   ; rows 72-83
    !byte $F8, $FE, $FF, $FF, $00, $00, $80, $E0, $F8, $FE, $FF, $FF   ; rows 84-95
FieldA2:
    !byte $00, $00, $00, $00, $00, $00, $01, $07, $00, $00, $00, $00   ; rows 0-11
    !byte $00, $00, $01, $07, $00, $00, $00, $00, $00, $00, $01, $07   ; rows 12-23
    !byte $00, $00, $00, $00, $00, $00, $01, $07, $00, $00, $00, $00   ; rows 24-35
    !byte $00, $00, $01, $07, $00, $00, $00, $00, $00, $00, $01, $07   ; rows 36-47
    !byte $00, $00, $00, $00, $00, $00, $01, $07, $00, $00, $00, $00   ; rows 48-59
    !byte $00, $00, $01, $07, $00, $00, $00, $00, $00, $00, $01, $07   ; rows 60-71
    !byte $00, $00, $00, $00, $00, $00, $01, $07, $00, $00, $00, $00   ; rows 72-83
    !byte $00, $00, $01, $07, $00, $00, $00, $00, $00, $00, $01, $07   ; rows 84-95

FieldB0:
    !byte $30, $F0, $F0, $F0, $F0, $F0, $F0, $F0, $30, $F0, $F0, $F0   ; rows 0-11
    !byte $F0, $F0, $F0, $F0, $30, $F0, $F0, $F0, $F0, $F0, $F0, $F0   ; rows 12-23
    !byte $30, $F0, $F0, $F0, $F0, $F0, $F0, $F0, $30, $F0, $F0, $F0   ; rows 24-35
    !byte $F0, $F0, $F0, $F0, $30, $F0, $F0, $F0, $F0, $F0, $F0, $F0   ; rows 36-47
    !byte $30, $F0, $F0, $F0, $F0, $F0, $F0, $F0, $30, $F0, $F0, $F0   ; rows 48-59
    !byte $F0, $F0, $F0, $F0, $30, $F0, $F0, $F0, $F0, $F0, $F0, $F0   ; rows 60-71
    !byte $30, $F0, $F0, $F0, $F0, $F0, $F0, $F0, $30, $F0, $F0, $F0   ; rows 72-83
    !byte $F0, $F0, $F0, $F0, $30, $F0, $F0, $F0, $F0, $F0, $F0, $F0   ; rows 84-95
FieldB1:
    !byte $00, $00, $C0, $F0, $FC, $FF, $FF, $FF, $00, $00, $C0, $F0   ; rows 0-11
    !byte $FC, $FF, $FF, $FF, $00, $00, $C0, $F0, $FC, $FF, $FF, $FF   ; rows 12-23
    !byte $00, $00, $C0, $F0, $FC, $FF, $FF, $FF, $00, $00, $C0, $F0   ; rows 24-35
    !byte $FC, $FF, $FF, $FF, $00, $00, $C0, $F0, $FC, $FF, $FF, $FF   ; rows 36-47
    !byte $00, $00, $C0, $F0, $FC, $FF, $FF, $FF, $00, $00, $C0, $F0   ; rows 48-59
    !byte $FC, $FF, $FF, $FF, $00, $00, $C0, $F0, $FC, $FF, $FF, $FF   ; rows 60-71
    !byte $00, $00, $C0, $F0, $FC, $FF, $FF, $FF, $00, $00, $C0, $F0   ; rows 72-83
    !byte $FC, $FF, $FF, $FF, $00, $00, $C0, $F0, $FC, $FF, $FF, $FF   ; rows 84-95
FieldB2:
    !byte $00, $00, $00, $00, $00, $00, $03, $0F, $00, $00, $00, $00   ; rows 0-11
    !byte $00, $00, $03, $0F, $00, $00, $00, $00, $00, $00, $03, $0F   ; rows 12-23
    !byte $00, $00, $00, $00, $00, $00, $03, $0F, $00, $00, $00, $00   ; rows 24-35
    !byte $00, $00, $03, $0F, $00, $00, $00, $00, $00, $00, $03, $0F   ; rows 36-47
    !byte $00, $00, $00, $00, $00, $00, $03, $0F, $00, $00, $00, $00   ; rows 48-59
    !byte $00, $00, $03, $0F, $00, $00, $00, $00, $00, $00, $03, $0F   ; rows 60-71
    !byte $00, $00, $00, $00, $00, $00, $03, $0F, $00, $00, $00, $00   ; rows 72-83
    !byte $00, $00, $03, $0F, $00, $00, $00, $00, $00, $00, $03, $0F   ; rows 84-95

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
