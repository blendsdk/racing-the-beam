; =============================================================================
; LESSON 60: DPC and DPC+ — Enhanced Audio and Graphics — Racing the Beam
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "the display processor": a 10,240-byte DPC cartridge.  The DPC is the
;   custom chip David Crane designed for Pitfall II (1984).  It gives the
;   2600 a 2K display image and eight data fetchers; three of them feed the
;   playfield registers on every scanline, and its random number generator
;   twinkles the stars.  The picture is a stepped cyan tunnel with a bold
;   "DPC" logo, a starfield, and a small white probe drawn by player 0.
;
; The 10K layout (the flat file is 10,240 bytes):
;   file offset $0000-$0FFF   bank 0, real $C000, assembled with !pseudopc $F000
;   file offset $1000-$1FFF   bank 1, real $D000, assembled with !pseudopc $F000
;   file offset $2000-$27FF   the 2K DPC display image, real $E000-$E7FF
;
; DPC starts in BANK 1, exactly like F8.  The reset vector at $FFFC in
; bank 1 points to $F080.  Why $F080 and not $F000?
;   The DPC's register window is at $1000-$107F.  The chip decodes only
;   the low address bits, so $F000-$F07F in whichever 4K bank is selected
;   is the same window.  The 6507 has no A13-A15, so there is no $3000 or
;   $5000 alias.  The first 128 bytes of every DPC bank are therefore
;   reserved: the low half is the read port (an instruction fetch there
;   would read the DPC registers and clock a data fetcher) and the high
;   half is the write port.  Every DPC bank starts with 128 filler bytes,
;   and its code at $F080.
;
; Bank 0 is only a stub.  It is never selected by this program, but every
; bank needs a valid vector, and the stub must switch safely if it runs:
;   $F080  Bank0Entry: LDA $1FF9   ; select bank 1 (the F8 hotspot)
;          JMP $F080              ; fetched from bank 1 at $F083
; Bank 1 carries a landing pad at $F083 as well:
;   $F080  Reset:      JMP Init    ; the reset vector's target
;   $F083             JMP Init    ; the JMP above is fetched here
; The LDA's switch takes effect before the following instruction fetch, so
; the target bank (not the bank that issued the JMP) supplies the next
; instruction.  That is the Lesson 56 rule, unchanged.
;
; The DPC register window (the chip's own memory map):
;   $1000-$1003  read  random number generator (4 mirrors)
;   $1004-$1007  read  music amplitude (4 mirrors)
;   $1008-$100F  read  DF0-DF7 display data; the read decrements the counter
;   $1010-$1017  read  DF0-DF7 display data AND the fetcher flag
;   $1038-$103F  read  DF0-DF7 flag
;   $1040-$1047  write DF0-DF7 top
;   $1048-$104F  write DF0-DF7 bottom
;   $1050-$1057  write DF0-DF7 counter low
;   $1058-$105F  write DF0-DF7 counter high (bits 0-2); bit 4 = music mode
;   $1070-$1077  write reset the random generator
; The write decode is: function = (address >> 3) & 7, index = address & 7.
; That is why DF1's bottom is $1049 (not $1041) and DF2's counter high is
; $105A (not $1053).  The addresses below are the measured table.
;
; The display image (2,048 bytes):
;   offset 0    192 bytes: plane 0, the PF0 byte for each visible line
;   offset 200  192 bytes: PF2 twinkle phase 1
;   offset 400  192 bytes: PF2 twinkle phase 2
;   offset 683  192 bytes: plane 1, the PF1 byte for each visible line
;   offset 880  192 bytes: PF2 twinkle phase 3
;   offset 1366 192 bytes: plane 2, the PF2 byte for each visible line
; The three main planes sit at 0, 683 and 1366; the padding between them
; holds three extra PF2 planes.  A fetcher returns display[2047 - counter],
; so the main counters start at 2047, 1364 and 681:
;   2047 - 0 = 2047, 2047 - 683 = 1364, 2047 - 1366 = 681.
; Each line reads one byte from each plane; the three counters decrement
; together, so the three planes stay aligned.
;
; The twinkle:
;   Plane 0 and plane 1 never change: they carry the frame, the logo and
;   the static stars.  Plane 2 has four variants.  Phase 0 is the main
;   plane at 1366; phases 1-3 are the copies at 200, 400 and 880.  Each
;   variant carries the same tunnel/logo bits and a different set of stars.
;   Every frame the random generator picks a phase, and DF2's counter is
;   set to 2047 - the phase's display offset.  The stars jump, the tunnel
;   and the logo do not.  The phase counters are:
;     phase 0: 2047 - 1366 = 681  = $02A9
;     phase 1: 2047 -  200 = 1847 = $0737
;     phase 2: 2047 -  400 = 1647 = $066F
;     phase 3: 2047 -  880 = 1167 = $048F
;
; One DPC trap in Stella's model: a read of $1000 (the random generator)
; also decrements DF0's counter, because the decode uses index 0.  The main
; loop therefore reads the random byte BEFORE it resets the counters.  A
; read in the middle of the frame would shift plane 0 by one line.
;
; The picture (192 visible lines):
;   rows 0-3      solid top band
;   rows 4-67     stepped perspective braces, meeting at bits 9-10
;   rows 68-123   the open middle: stars, the probe, the DPC logo
;   rows 84-97    the bold "DPC" logo: a five-bit-wide, seven-row font,
;                 bits 2-18, each font row duplicated to 14 scanlines
;   rows 124-187  stepped braces, opening downward
;   rows 188-191  solid bottom band
;   The playfield is reflected (CTRLPF = $01), so the left half is drawn
;   again as its mirror on the right: the logo appears twice, mirrored.
;   Player 0 draws a small white diamond at x=40, visible rows 70-77.
;
; Frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;   One HMOVE, inside VBLANK, positions player 0.
;
; The 1-line kernel (38 cycles of 76, including the 7-cycle loop tail that
; runs at the top of each line; the phase tables sit inside one page and
; the probe strip is page-aligned):
; Cycles below are 0-based Stella cycles; a store writes on its last cycle.
;   loop tail       7   INY + CPY + BNE from the previous line
;   LDA $1008       4   fetch plane 0
;   STA PF0         3   write PF0 (cycle 13; PF0's first pixel at 22.7)
;   LDA $1009       4   fetch plane 1
;   STA PF1         3   write PF1 (cycle 20; PF1's first pixel at 28.0)
;   LDA $100A       4   fetch plane 2
;   STA PF2         3   write PF2 (cycle 27; PF2's first pixel at 38.7)
;   LDA Probe,Y     4
;   STA GRP0        3   the white probe (cycle 34; x=40's first pixel at 36.0)
;   STA WSYNC       3
; The writes are ordered so each playfield register is written before the
; beam reaches the pixels that register controls, and the probe's GRP0
; write still lands before x=40 (a 2.0-cycle margin).
;
; Checkpoints (Stella's scanline/cycle in parentheses):
;   Reset ($F080), Main, StartFrame (259/3), VblankStart (0/5),
;   BodyStart (37/5), OverscanStart (229/6), Line,
;   Fetch0/Fetch1/Fetch2 (A = the fetched plane byte),
;   RngRead (A = the random byte), Frame (A = FrameCount).
;
; RAM map (+clean_start zeroes every byte):
;   $80  FrameCount  frames since reset, wraps at 256 (the Frame checkpoint)
;   $81  StarPtr     the selected phase's DF2 counter low byte
;   $82  Twinkle     the phase index (Rng & 3)
;   $83  Rng         the raw read of $1000
;   $84-$9F free
;   $F8-$FF stack
; The DPC registers and the 2K display image are in the cartridge, not RAM.
;
; Build: acme -f plain -o build/lesson60.bin \
;        lessons/part8-advanced/60-dpc-plus/60-dpc-plus.asm
; Run:   stella build/lesson60.bin
; The ROM is 10,240 bytes and Stella reports DPC* (10K).
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan
POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

SCREEN_LINES   = 192     ; the DPC kernel draws every visible line
PLAYER_X       = 40      ; the probe's left edge, TIA X 40..47

; =============================================================================
; DPC REGISTERS — the cartridge's 128-byte window at $1000-$107F
; =============================================================================
; Reads and writes use the same 128 bytes.  The low three address bits
; select the fetcher; bits 3-5 select the function.  The constants below
; spell the measured table out so the source never relies on the formula
; at the call site.
DPC_RNG        = $1000   ; read: the random byte (index 0, function 0)
DPC_MUSIC      = $1005   ; read: the 4-bit music amplitude (exercise 3)
DPC_DF0        = $1008   ; read: display plane 0, decrements DF0's counter
DPC_DF1        = $1009   ; read: display plane 1, decrements DF1's counter
DPC_DF2        = $100A   ; read: display plane 2, decrements DF2's counter

DPC_DF0_TOP    = $1040   ; write: DF0 top
DPC_DF1_TOP    = $1041   ; write: DF1 top
DPC_DF2_TOP    = $1042   ; write: DF2 top
DPC_DF0_BOTTOM = $1048   ; write: DF0 bottom
DPC_DF1_BOTTOM = $1049   ; write: DF1 bottom
DPC_DF2_BOTTOM = $104A   ; write: DF2 bottom
DPC_DF0_LO     = $1050   ; write: DF0 counter low
DPC_DF1_LO     = $1051   ; write: DF1 counter low
DPC_DF2_LO     = $1052   ; write: DF2 counter low
DPC_DF0_HI     = $1058   ; write: DF0 counter high (bits 0-2)
DPC_DF1_HI     = $1059   ; write: DF1 counter high (bits 0-2)
DPC_DF2_HI     = $105A   ; write: DF2 counter high (bits 0-2)
DPC_RNG_RESET  = $1070   ; write: any value resets the random generator to 1

; =============================================================================
; FIXED DATA ADDRESSES in bank 1
; =============================================================================
; The phase tables sit at $F2F0/$F2F4 inside one page, so the indexed
; loads do not cross a page; the probe strip is page-aligned at $F400.
PhaseLo        = $F2F0   ; 4 bytes: DF2 counter low per twinkle phase
PhaseHi        = $F2F4   ; 4 bytes: DF2 counter high per twinkle phase
Probe          = $F400   ; 192 bytes: one GRP0 byte per visible line

; =============================================================================
; RAM ALLOCATION ($80-$83; +clean_start zeroes every byte)
; =============================================================================
FrameCount     = $80     ; frames since reset, wraps at 256 (Frame checkpoint)
StarPtr        = $81     ; the selected phase's DF2 counter low byte
Twinkle        = $82     ; the phase index (Rng & 3)
Rng            = $83     ; the raw read of $1000

; =============================================================================
; BANK 0 — real $C000, virtual $F000.  THE SWITCH STUB.
; =============================================================================
; The flat ROM starts here.  The first 128 bytes are the shadow of the DPC
; register window and must not contain code.  $F080 is the six-byte stub:
; the hotspot read selects bank 1, and the JMP that follows is fetched from
; bank 1 at $F083, where bank 1 carries a matching JMP Init landing pad.
    * = $C000
    !pseudopc $F000 {

    !fill 128, $EA           ; $F000-$F07F: not code (the register window)

Bank0Entry:
    LDA $1FF9                ; select bank 1 (F8 hotspot)
    JMP $F080                ; fetched from bank 1 at $F083

    !fill $FFFA - *, $EA
    * = $FFFA
    !word Bank0Entry, Bank0Entry, Bank0Entry
}

; =============================================================================
; BANK 1 — real $D000, virtual $F000.  THE PROGRAM (the start bank).
; =============================================================================
; The DPC selects bank 1 at power-on, so the vector at $FFFC below is the
; one the CPU uses.  The first 128 bytes are the register-window shadow;
; the entry is $F080.
    * = $D000
    !pseudopc $F000 {

    !fill 128, $EA           ; $F000-$F07F: not code (the register window)

; -----------------------------------------------------------------------------
; Reset — $F080, the reset vector's target (checkpoint)
; -----------------------------------------------------------------------------
; The first JMP is the real entry.  The second JMP is the landing pad for
; bank 0's stub: when that stub's LDA switches to bank 1, the CPU fetches
; the following JMP from $F083 here, and this second JMP sends it to Init.
Reset:
    JMP Init
    JMP Init

; -----------------------------------------------------------------------------
; Init — one-time hardware setup
; -----------------------------------------------------------------------------
Init:
    +clean_start             ; zero TIA and RAM, set the stack to $FF
    LDA #$00
    STA SWACNT               ; port A is an input port (the joystick)

    LDA #$02
    STA VBLANK               ; blank the picture until the first frame
    LDA #$AE
    STA COLUPF               ; the tunnel is bright cyan
    LDA #$00
    STA COLUBK               ; black space behind it
    LDA #$0E
    STA COLUP0               ; the probe is white
    LDA #$01
    STA CTRLPF               ; reflect the playfield: the right half mirrors

    LDA #$00
    STA DPC_RNG_RESET        ; the DPC's random generator starts at 1
    JMP Main

; -----------------------------------------------------------------------------
; Main — the frame loop
; -----------------------------------------------------------------------------
Main:
    NOP                      ; the Main checkpoint (one pass at startup)
StartFrame:                  ; checkpoint: scanline 259, the first VSYNC line
    +vsync                   ; 3 VSYNC lines: 259, 260, 261

VblankStart:                 ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- read the DPC random generator -------------------------------------------
; In Stella's DPC model this read clocks DF0's counter as a side effect,
; so it happens before the three counters are reset.  Rng is the raw byte;
; Twinkle keeps its low two bits as the star phase.
    LDA DPC_RNG
RngRead:                     ; checkpoint: A = the random byte
    STA Rng

; --- reset the three graphics fetchers ---------------------------------------
; Top = $FF and bottom = $00 for all three.  The plain data read ignores
; top/bottom; they matter only for the masked read and the flag.  Writing
; the top also clears the fetcher's flag.
    LDA #$FF
    STA DPC_DF0_TOP
    STA DPC_DF1_TOP
    STA DPC_DF2_TOP
    LDA #$00
    STA DPC_DF0_BOTTOM
    STA DPC_DF1_BOTTOM
    STA DPC_DF2_BOTTOM

; --- the three counters ------------------------------------------------------
; Plane 0 and plane 1 are fixed:
;   DF0 = 2047 -> plane 0 offset 0
;   DF1 = 1364 -> plane 1 offset 683
; Plane 2 is the twinkle phase: 681 for the main plane at 1366, or the
; counter of one of the three alternate planes in the padding.
    LDA #$FF
    STA DPC_DF0_LO
    LDA #$54
    STA DPC_DF1_LO
    LDA #$07
    STA DPC_DF0_HI
    LDA #$05
    STA DPC_DF1_HI

    LDA Rng
    AND #$03
    STA Twinkle              ; the phase index, 0-3
    TAX
    LDA PhaseLo,X
    STA StarPtr              ; the selected phase's counter low
    STA DPC_DF2_LO
    LDA PhaseHi,X
    STA DPC_DF2_HI

; --- the frame counter -------------------------------------------------------
    INC FrameCount
    LDA FrameCount
Frame:                       ; checkpoint: A = the new frame count

; --- position player 0: one divide-by-15 dance and one HMOVE -------------------
; SetCoarseP0 sets HMP0 and strobes RESP0.  The WSYNC starts a fresh line
; and the HMOVE applies the fine offset in its HBLANK.  This is the frame's
; only HMOVE, and it falls inside VBLANK: the artifact blanks the first
; eight visible pixels of the following line, which is still a VBLANK line.
    LDA #(PLAYER_X + POS_BIAS)
    JSR SetCoarseP0
    STA WSYNC
    STA HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK               ; picture on

; -----------------------------------------------------------------------------
; The visible kernel — 192 lines, three DPC fetches per line
; -----------------------------------------------------------------------------
BodyStart:                   ; checkpoint: scanline 37, visible line 0
    LDY #0
Line:
    LDA DPC_DF0              ; plane 0 byte for this line
Fetch0:                      ; checkpoint: A = the fetched PF0 byte
    STA PF0
    LDA DPC_DF1              ; plane 1 byte for this line
Fetch1:                      ; checkpoint: A = the fetched PF1 byte
    STA PF1
    LDA DPC_DF2              ; plane 2 byte for this line (the star phase)
Fetch2:                      ; checkpoint: A = the fetched PF2 byte
    STA PF2
    LDA Probe,Y              ; the white probe strip
    STA GRP0
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE Line

; -----------------------------------------------------------------------------
; Overscan — 30 lines, then the next frame
; -----------------------------------------------------------------------------
OverscanStart:               ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; -----------------------------------------------------------------------------
; SetCoarseP0 — the Lesson 26 divide-by-15 positioning dance
; -----------------------------------------------------------------------------
; A = the desired left edge + POS_BIAS.  Each loop pass is 5 cycles = 15
; colour clocks, which is why dividing by 15 works.  The remainder becomes
; HMP0's fine value and RESP0 strobes the coarse position.
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

; -----------------------------------------------------------------------------
; The twinkle phase tables — four DF2 counter values
; -----------------------------------------------------------------------------
; display[2047 - counter], so the counter is 2047 minus the plane's display
; offset.  Phase 0 is the main plane at 1366; phases 1-3 are the copies in
; the padding at 200, 400 and 880.
    !if * > PhaseLo {
        !error "bank 1's code must end before PhaseLo"
    }
    !fill PhaseLo - *, $EA
PhaseLo:
    !byte $A9, $37, $6F, $8F   ; 681, 1847, 1647, 1167
    !fill PhaseHi - *, $EA
PhaseHi:
    !byte $02, $07, $06, $04

    !fill Probe - *, $EA

; -----------------------------------------------------------------------------
; The probe strip — one GRP0 byte per visible line
; -----------------------------------------------------------------------------
; An 8x8 diamond at visible rows 70-77.  Player 0 is positioned once per
; frame by SetCoarseP0.  The probe is a normal TIA object; the playfield
; behind it comes from the DPC.
Probe:
    !fill 70, $00
    !byte $18   ; row 70
    !byte $3C   ; row 71
    !byte $7E   ; row 72
    !byte $FF   ; row 73
    !byte $FF   ; row 74
    !byte $7E   ; row 75
    !byte $3C   ; row 76
    !byte $18   ; row 77
    !fill 114, $00
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset, Reset, Reset
}

; =============================================================================
; THE 2K DPC DISPLAY IMAGE — real $E000-$E7FF, file offset $2000
; =============================================================================
; The flat file ends with 2,048 bytes of display data.  The DPC's fetchers
; read it backwards through their counters: display[2047 - counter].
; The three main planes sit at offsets 0, 683 and 1366; the padding holds
; the three alternate PF2 twinkle planes at 200, 400 and 880.  The !fill
; arithmetic checks every offset at build time and fails if a plane
; overruns its slot.
    * = $E000
DisplayImage:

; Each !byte line's comment names the range of its eight rows.  The logo
; strokes begin at row 84: the first four bytes of the "rows 80-87" line
; are rows 80-83 and are zero.

; --- plane 0: the PF0 byte (the 4 leftmost playfield bits) for each line ----
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0   ; rows 0-7
    !byte $F0, $F0, $F0, $F0, $B0, $B0, $B0, $B0   ; rows 8-15
    !byte $B0, $B0, $B0, $B0, $30, $30, $30, $30   ; rows 16-23
    !byte $30, $30, $30, $30, $30, $30, $B0, $30   ; rows 24-31
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 32-39
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 40-47
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 48-55
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 56-63
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 64-71
    !byte $30, $30, $B0, $30, $30, $30, $30, $30   ; rows 72-79
    !byte $30, $30, $30, $30, $F0, $F0, $F0, $F0   ; rows 80-87
    !byte $70, $70, $70, $70, $70, $70, $F0, $F0   ; rows 88-95
    !byte $F0, $F0, $30, $30, $30, $30, $30, $30   ; rows 96-103
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 104-111
    !byte $70, $30, $30, $30, $30, $30, $30, $30   ; rows 112-119
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 120-127
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 128-135
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 136-143
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 144-151
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 152-159
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 160-167
    !byte $30, $30, $30, $30, $B0, $B0, $B0, $B0   ; rows 168-175
    !byte $B0, $B0, $B0, $B0, $F0, $F0, $F0, $F0   ; rows 176-183
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0   ; rows 184-191
    !fill 200 - (* - DisplayImage), $00

; --- PF2 twinkle phase 1 (display offset 200) -------------------------------
    !byte $FF, $FF, $FF, $FF, $30, $30, $30, $30   ; rows 0-7
    !byte $30, $30, $30, $30, $18, $18, $18, $18   ; rows 8-15
    !byte $18, $18, $18, $18, $0C, $0C, $0C, $0C   ; rows 16-23
    !byte $2C, $0C, $0C, $0C, $06, $06, $06, $06   ; rows 24-31
    !byte $06, $06, $06, $06, $03, $03, $03, $03   ; rows 32-39
    !byte $03, $03, $03, $03, $01, $01, $01, $01   ; rows 40-47
    !byte $01, $01, $81, $01, $00, $00, $00, $00   ; rows 48-55
    !byte $00, $00, $00, $00, $00, $00, $08, $00   ; rows 56-63
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 64-71
    !byte $01, $00, $00, $00, $00, $00, $00, $00   ; rows 72-79
    !byte $40, $00, $00, $00, $78, $78, $7D, $7D   ; rows 80-87
    !byte $0D, $0D, $0D, $0D, $0D, $0D, $7C, $7C   ; rows 88-95
    !byte $78, $78, $00, $00, $00, $00, $10, $00   ; rows 96-103
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 104-111
    !byte $00, $00, $00, $00, $04, $00, $00, $00   ; rows 112-119
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 120-127
    !byte $00, $00, $00, $00, $80, $00, $00, $00   ; rows 128-135
    !byte $00, $00, $00, $00, $01, $01, $01, $01   ; rows 136-143
    !byte $01, $01, $01, $01, $23, $03, $03, $03   ; rows 144-151
    !byte $03, $03, $03, $03, $06, $06, $06, $06   ; rows 152-159
    !byte $06, $06, $06, $06, $0C, $0C, $0C, $0C   ; rows 160-167
    !byte $0E, $0C, $0C, $0C, $18, $18, $18, $18   ; rows 168-175
    !byte $18, $18, $18, $18, $30, $30, $30, $30   ; rows 176-183
    !byte $30, $30, $30, $30, $FF, $FF, $FF, $FF   ; rows 184-191
    !fill 400 - (* - DisplayImage), $00

; --- PF2 twinkle phase 2 (display offset 400) -------------------------------
    !byte $FF, $FF, $FF, $FF, $30, $30, $30, $30   ; rows 0-7
    !byte $30, $30, $30, $30, $18, $18, $18, $18   ; rows 8-15
    !byte $18, $18, $18, $18, $0C, $0C, $0C, $0C   ; rows 16-23
    !byte $0C, $0C, $0C, $0C, $06, $06, $06, $06   ; rows 24-31
    !byte $06, $06, $06, $06, $03, $03, $03, $03   ; rows 32-39
    !byte $13, $03, $03, $03, $01, $01, $01, $01   ; rows 40-47
    !byte $01, $01, $01, $01, $00, $00, $01, $00   ; rows 48-55
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 56-63
    !byte $00, $00, $40, $00, $00, $00, $20, $00   ; rows 64-71
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 72-79
    !byte $00, $00, $02, $00, $78, $78, $7D, $7D   ; rows 80-87
    !byte $0D, $0D, $0D, $0D, $0D, $0D, $7C, $7C   ; rows 88-95
    !byte $78, $78, $00, $00, $80, $00, $00, $00   ; rows 96-103
    !byte $00, $00, $00, $00, $00, $00, $08, $00   ; rows 104-111
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 112-119
    !byte $00, $00, $00, $00, $00, $00, $40, $00   ; rows 120-127
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 128-135
    !byte $00, $00, $00, $00, $01, $01, $01, $01   ; rows 136-143
    !byte $01, $01, $01, $01, $03, $03, $03, $03   ; rows 144-151
    !byte $03, $03, $03, $03, $16, $06, $06, $06   ; rows 152-159
    !byte $06, $06, $06, $06, $0C, $0C, $0C, $0C   ; rows 160-167
    !byte $0C, $0C, $0C, $0C, $18, $18, $18, $18   ; rows 168-175
    !byte $18, $18, $18, $18, $30, $30, $30, $30   ; rows 176-183
    !byte $30, $30, $30, $30, $FF, $FF, $FF, $FF   ; rows 184-191
    !fill 683 - (* - DisplayImage), $00

; --- plane 1: the PF1 byte (playfield bits 4-11) for each line --------------
    !byte $FF, $FF, $FF, $FF, $00, $00, $00, $00   ; rows 0-7
    !byte $00, $00, $00, $00, $80, $80, $80, $80   ; rows 8-15
    !byte $80, $80, $80, $80, $C0, $C0, $C0, $C0   ; rows 16-23
    !byte $C0, $C0, $C0, $C0, $60, $60, $60, $60   ; rows 24-31
    !byte $60, $60, $60, $60, $30, $30, $30, $30   ; rows 32-39
    !byte $30, $30, $38, $30, $19, $19, $19, $19   ; rows 40-47
    !byte $19, $19, $19, $19, $0F, $0F, $0F, $0F   ; rows 48-55
    !byte $0F, $0F, $0F, $0F, $06, $06, $06, $06   ; rows 56-63
    !byte $06, $06, $46, $06, $00, $00, $00, $00   ; rows 64-71
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 72-79
    !byte $00, $00, $00, $00, $CF, $CF, $EF, $EF   ; rows 80-87
    !byte $69, $69, $69, $69, $6F, $6F, $EF, $EF   ; rows 88-95
    !byte $C8, $C8, $02, $00, $00, $00, $00, $00   ; rows 96-103
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 104-111
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 112-119
    !byte $00, $00, $00, $00, $86, $06, $06, $06   ; rows 120-127
    !byte $06, $06, $06, $06, $0F, $0F, $0F, $0F   ; rows 128-135
    !byte $1F, $0F, $0F, $0F, $19, $19, $19, $19   ; rows 136-143
    !byte $19, $19, $19, $19, $30, $30, $31, $30   ; rows 144-151
    !byte $30, $30, $30, $30, $60, $60, $60, $60   ; rows 152-159
    !byte $60, $60, $60, $60, $C0, $C0, $C0, $C0   ; rows 160-167
    !byte $C0, $C0, $C0, $C0, $80, $80, $80, $80   ; rows 168-175
    !byte $80, $80, $80, $80, $00, $00, $00, $00   ; rows 176-183
    !byte $00, $00, $00, $00, $FF, $FF, $FF, $FF   ; rows 184-191
    !fill 880 - (* - DisplayImage), $00

; --- PF2 twinkle phase 3 (display offset 880) -------------------------------
    !byte $FF, $FF, $FF, $FF, $30, $30, $30, $30   ; rows 0-7
    !byte $30, $30, $30, $30, $18, $18, $18, $18   ; rows 8-15
    !byte $18, $18, $18, $18, $0C, $0C, $0C, $0C   ; rows 16-23
    !byte $0C, $0C, $0C, $0C, $06, $06, $06, $06   ; rows 24-31
    !byte $86, $06, $06, $06, $03, $03, $03, $03   ; rows 32-39
    !byte $03, $03, $03, $03, $01, $01, $09, $01   ; rows 40-47
    !byte $01, $01, $01, $01, $00, $00, $00, $00   ; rows 48-55
    !byte $00, $00, $02, $00, $00, $00, $00, $00   ; rows 56-63
    !byte $20, $00, $00, $00, $00, $00, $00, $00   ; rows 64-71
    !byte $00, $00, $00, $00, $04, $00, $00, $00   ; rows 72-79
    !byte $01, $00, $00, $00, $78, $78, $7D, $7D   ; rows 80-87
    !byte $0D, $0D, $0D, $0D, $0D, $0D, $7C, $7C   ; rows 88-95
    !byte $78, $78, $00, $00, $00, $00, $00, $00   ; rows 96-103
    !byte $00, $00, $00, $00, $40, $00, $00, $00   ; rows 104-111
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 112-119
    !byte $00, $00, $10, $00, $00, $00, $00, $00   ; rows 120-127
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 128-135
    !byte $00, $00, $02, $00, $01, $01, $01, $01   ; rows 136-143
    !byte $01, $01, $01, $01, $03, $03, $03, $03   ; rows 144-151
    !byte $83, $03, $03, $03, $06, $06, $06, $06   ; rows 152-159
    !byte $06, $06, $06, $06, $0C, $0C, $0C, $0C   ; rows 160-167
    !byte $0C, $0C, $0C, $0C, $18, $18, $18, $18   ; rows 168-175
    !byte $18, $18, $18, $18, $30, $30, $30, $30   ; rows 176-183
    !byte $30, $30, $30, $30, $FF, $FF, $FF, $FF   ; rows 184-191
    !fill 1366 - (* - DisplayImage), $00

; --- plane 2: the PF2 byte, twinkle phase 0, at display offset 1366 ---------
    !byte $FF, $FF, $FF, $FF, $30, $30, $30, $30   ; rows 0-7
    !byte $30, $30, $30, $30, $18, $18, $18, $18   ; rows 8-15
    !byte $18, $18, $18, $18, $1C, $0C, $0C, $0C   ; rows 16-23
    !byte $0C, $0C, $0C, $0C, $06, $06, $46, $06   ; rows 24-31
    !byte $06, $06, $06, $06, $03, $03, $03, $03   ; rows 32-39
    !byte $03, $03, $03, $03, $05, $01, $01, $01   ; rows 40-47
    !byte $01, $01, $01, $01, $00, $00, $00, $00   ; rows 48-55
    !byte $20, $00, $00, $00, $00, $00, $00, $00   ; rows 56-63
    !byte $00, $00, $00, $00, $00, $00, $02, $00   ; rows 64-71
    !byte $00, $00, $00, $00, $00, $00, $80, $00   ; rows 72-79
    !byte $00, $00, $00, $00, $78, $78, $7D, $7D   ; rows 80-87
    !byte $0D, $0D, $0D, $0D, $0D, $0D, $7C, $7C   ; rows 88-95
    !byte $78, $78, $00, $00, $00, $00, $00, $00   ; rows 96-103
    !byte $08, $00, $00, $00, $00, $00, $00, $00   ; rows 104-111
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 112-119
    !byte $01, $00, $00, $00, $00, $00, $00, $00   ; rows 120-127
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 128-135
    !byte $00, $00, $00, $00, $41, $01, $01, $01   ; rows 136-143
    !byte $01, $01, $01, $01, $03, $03, $03, $03   ; rows 144-151
    !byte $03, $03, $03, $03, $06, $06, $06, $06   ; rows 152-159
    !byte $16, $06, $06, $06, $0C, $0C, $0C, $0C   ; rows 160-167
    !byte $0C, $0C, $0C, $0C, $18, $18, $18, $18   ; rows 168-175
    !byte $1C, $18, $18, $18, $30, $30, $30, $30   ; rows 176-183
    !byte $30, $30, $30, $30, $FF, $FF, $FF, $FF   ; rows 184-191
    !fill 2048 - (* - DisplayImage), $00
