; =============================================================================
; LESSON 19: Playfield Basics — PF0, PF1, PF2 — Racing the Beam
; =============================================================================
; Part 3: Playfield
;
; What this program does:
;   Draws the TIA's playfield: a green "castle wall" on a dark field, made
;   from the three playfield registers PF0, PF1, PF2.  The picture is the
;   same on every one of the 192 visible lines — the TIA re-reads the three
;   registers for every line, so a pattern written once is a vertical wall.
;
;   Every ~2 seconds the wall changes symmetry:
;     - reflect mode (CTRLPF bit 0 = 1): the right half mirrors the left,
;       so the wall is symmetric: an eight-chunk green center between two
;       dark bands;
;     - repeat mode  (CTRLPF bit 0 = 0): the right half repeats the left,
;       so the green center widens to ten chunks; beyond it the right half
;       shows a new rhythm while the left half is unchanged.
;
; The playfield in one paragraph:
;   20 bits cover the LEFT half of the screen.  Each bit is one "chunk" of
;   four color clocks (24 screen pixels — six per color clock — in the
;   course captures).  Twenty
;   chunks of four clocks = 80 clocks; the full visible line is 160 clocks,
;   so the right half is the same 20 bits mirrored or repeated.
;
;   PF0 uses only bits 4-7, and bit 4 is the LEFTMOST chunk.
;   PF1 uses all eight bits, and bit 7 is the leftmost chunk.
;   PF2 uses all eight bits, and bit 0 is the leftmost chunk; bit 7 is the
;   chunk nearest the center of the screen.  Those three different bit
;   orders are the classic playfield confusion — the table below is the map.
;
;     register  bits   chunks (left to right)
;     PF0       4-7    0-3
;     PF1       7-0    4-11
;     PF2       0-7    12-19
;
; The castle pattern (one 20-bit half):
;   PF0 = $F0  -> chunks 0-3   on   (1111)
;   PF1 = $CC  -> chunks 4-11   11001100
;   PF2 = $F0  -> chunks 12-19  00001111   (bit 0 is leftmost!)
;
;   Reflect (this ROM's starting state): the right half is chunks 0-19 reversed, so the
;   center is a green eight-chunk block (chunks 16-23) with a dark band on
;   each side.  Repeat: the right half is the same 20 bits again, so the
;   green center widens to chunks 16-25 and the dark bands move outward.
;
; The frame is the course standard (262 lines):
;   VSYNC 3 lines, VBLANK 37 lines on TIM64T = 44, visible 192 lines,
;   overscan 30 lines on TIM64T = 36.  The PF/CTRLPF/color writes happen in
;   VBLANK, before the beam is released; the visible kernel is a counted
;   WSYNC hold — the TIA redraws the wall from the registers every line.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259 — a standard 262-line frame), VblankStart (0),
;   CtrlWrite (A = the mode: $01 reflect, $00 repeat; first flip at frame
;   120), VisibleStart (37), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson19.bin \
;        lessons/part3-playfield/19-playfield-basics/19-playfield-basics.asm
; Run:   stella build/lesson19.bin
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
VISIBLE_LINES  = 192    ; the standard NTSC picture height
ANIM_FRAMES    = 120    ; ~2 seconds per symmetry state at ~60 Hz

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
FrameCounter   = $80    ; counts up to ANIM_FRAMES, then resets
AnimState      = $81    ; 1 = reflect, 0 = repeat (starts reflect)

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)
    LDA #$01
    STA AnimState           ; frame 1 starts in reflect mode

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; VSYNC — exactly 3 lines (Lesson 12)
; -----------------------------------------------------------------------------
    +vsync

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
; -----------------------------------------------------------------------------
; VBLANK — 37 lines, counted by the RIOT timer (TIM64T = 44)
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    +set_timer VBLANK_TIMER ; start the countdown: 44 ticks for 37 lines

; --- the symmetry tick: flip CTRLPF's REF bit every ANIM_FRAMES frames ---
    INC FrameCounter
    LDA FrameCounter
    CMP #ANIM_FRAMES
    BNE VblankTickDone
    LDA #$00
    STA FrameCounter        ; wrap the counter
    LDA AnimState
    EOR #$01
    STA AnimState           ; reflect <-> repeat
VblankTickDone:

; --- write the frame's playfield state (the pattern never changes) ---
    LDA AnimState
    BEQ VblankRepeat
    LDA #$01                ; bit 0 = REF: mirror the right half
    BNE VblankStoreCtrl     ; (always taken: A = 1)
VblankRepeat:
    LDA #$00                ; REF = 0: repeat the left half
VblankStoreCtrl:
    STA CTRLPF
CtrlWrite:                  ; debugger checkpoint: A = $01 / $00

    LDA #$F0
    STA PF0                 ; chunks 0-3 on
    LDA #$CC
    STA PF1                 ; chunks 4-11: 11001100
    LDA #$F0
    STA PF2                 ; chunks 12-19: 00001111 (bit 0 first)
    LDA #$C8
    STA COLUPF              ; green
    LDA #$02
    STA COLUBK              ; dark neutral

    +wait_timer             ; wait out line 36, then park it

; -----------------------------------------------------------------------------
; VISIBLE — 192 lines; the pattern is redrawn from the registers every line
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam on line 37
    LDX #VISIBLE_LINES      ; 192 lines to hold
VisibleStart:               ; debugger checkpoint: the picture's first line (37)
    STA WSYNC               ; park the rest of this line
    DEX
    BNE VisibleStart

; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines (TIM64T = 36); blank-on lands in line 229's HBLANK
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
