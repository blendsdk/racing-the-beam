; =============================================================================
; LESSON 13: Colors — Painting the Screen
; =============================================================================
; Part 2: TV & TIA
;
; What this program does:
;   The "palette explorer": SIXTEEN equal bands of twelve lines — one band
;   per hue, 0 (light gray) at the top through 15 (yellow) at the bottom.
;   Every band's color byte is built from two parts:
;
;     %HHHHLLL0        HHHH = hue (the band number)
;                      LLL  = luminance (the picture's brightness level)
;                      bit 0 is unused — it is always 0
;
;   and the whole picture descends through the eight luminance levels,
;   7 (brightest) down to 0, one step every 120 frames — about two seconds
;   — then wraps back to 7.  A full cycle is 8 x 120 frames, about
;   sixteen seconds, and shows all 128 colors the TIA has: 16 hues x
;   8 luminance levels.
;
;   The frame is Lesson 12's, unchanged: VSYNC 3, VBLANK 37, visible 192
;   (16 x 12), overscan 30 — 262 counted scanlines per pass of the loop.
;   The luminance clock is a RAM byte decremented once per frame; when it
;   reaches 0 the level steps and the byte reloads with 120.
;
; What you'll learn:
;   - the palette byte: hue in the high nibble, luminance in bits 3-1
;   - 16 hues x 8 luminance levels = 128 colors
;   - luminance 0 is the palette's darkest step, not pure black
;   - building color bytes in code — a hue table ORed with a luminance field
;   - reading the picture back in the debugger: COLUBK shows the byte
;   - COLUP0, COLUP1 and COLUPF use the same byte for objects (later parts)
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), VisibleStart (37), Band0Write,
;   BandWrite, LumStep, OverscanStart (229).  See the lesson document
;   for what each one watches.
;
; Build: acme -f plain -o build/lesson13.bin \
;        lessons/part2-tv-and-tia/13-colors/13-colors.asm
; Run:   stella build/lesson13.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame, the palette, and the clock
; =============================================================================
VBLANK_LINES   = 37     ; blanked lines between VSYNC and the picture
BANDS          = 16     ; visible bands — one per hue
LINES          = 12     ; scanlines per band (16 x 12 = 192 visible lines)
OVERSCAN_LINES = 30     ; blanked lines after the picture
STEP_FRAMES    = 120    ; frames per luminance step (~2 seconds at ~60 Hz)

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
FrameCounter = $80      ; frames left in this luminance step: 120 -> 0
Luminance    = $81      ; the current level, 0-7 (7 = brightest)
LumField     = $82      ; the level as the palette byte's field: level x 2

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

    ; --- Start bright: level 7, its doubled field, and a full step ---
    LDA #$07
    STA Luminance           ; level 7 = brightest
    ASL                     ; 7 x 2 = $0E — the palette byte's field
    STA LumField
    LDA #STEP_FRAMES
    STA FrameCounter        ; 120 frames until the first step

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; THE LUMINANCE CLOCK — one tick per frame, one step per 120 ticks
; -----------------------------------------------------------------------------
; FrameCounter counts down once per pass of the loop.  At 0 the picture
; steps one luminance level darker: 7, 6, 5, ... 0, and then — because DEC
; past 0 wraps to $FF, whose sign bit is set — the wrap branch puts it back
; at 7.  The field the palette byte needs is level x 2, rebuilt each step.
    DEC FrameCounter
    BNE NoStep              ; still counting: mid-step, nothing changes
    LDA #STEP_FRAMES
    STA FrameCounter        ; reload: another 120 frames to the next step
    DEC Luminance
    BPL LumStep             ; landed on 0-7: use it as-is
    LDA #$07                ; DEC wrapped past 0 to $FF: back to brightest
    STA Luminance
LumStep:                    ; debugger checkpoint: one hit per 120 frames
    LDA Luminance
    ASL                     ; level x 2 = the luminance field
    STA LumField
NoStep:
; -----------------------------------------------------------------------------
; VSYNC — exactly 3 lines (Lesson 12)
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = start VSYNC
    STA VSYNC
    STA WSYNC               ; VSYNC line 1 ends
    STA WSYNC               ; VSYNC line 2 ends
    STA WSYNC               ; VSYNC line 3 ends
    LDA #$00
    STA VSYNC               ; pulse off — exactly 3 lines

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
; -----------------------------------------------------------------------------
; VBLANK — 37 blanked lines (Lesson 12)
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    LDX #VBLANK_LINES
VblankLines:
    STA WSYNC
    DEX
    BNE VblankLines

VisibleStart:               ; debugger checkpoint: visible's first line (Stella: 37)
; -----------------------------------------------------------------------------
; VISIBLE — 192 lines = sixteen bands of 12, one per hue
; -----------------------------------------------------------------------------
; Band k's color is the palette byte for hue k at the current luminance:
; the hue nibble comes out of the table, the luminance field out of RAM.
    LDA #$00
    STA VBLANK              ; release the beam — visible line 1
    LDX #$00
    LDA HueNibbles,X        ; band 0: the hue nibble, $00
    ORA LumField            ; OR in the luminance field
    STA COLUBK              ; lands in HBLANK: the release line shows it
Band0Write:                 ; debugger checkpoint: A = 0 | field (see the doc)
    LDY #LINES-1            ; Y = 11: release line + 11 painted = band 0's 12
    JSR PaintLines
    LDX #$01                ; bands 1...15 remain
BandLoop:
    LDA HueNibbles,X        ; this band's hue nibble (k << 4)
    ORA LumField            ; OR in the luminance field: k<<4 | level<<1
BandWrite:                  ; debugger checkpoint: A = hue*16 + level*2, X = hue
    LDY #LINES              ; a full band of 12
    JSR PaintLines
    INX                     ; next band
    CPX #BANDS              ; 0...15 — the index IS the hue
    BNE BandLoop

    STA WSYNC               ; let the last band line finish before blanking
    LDA #$02
OverscanStart:              ; debugger checkpoint: overscan's first line (Stella: 229)
    STA VBLANK
    LDX #OVERSCAN_LINES
OverscanLines:
    STA WSYNC
    DEX
    BNE OverscanLines
    JMP StartFrame          ; 262 lines done: next frame

; =============================================================================
; SUBROUTINE: PaintLines — paint Y scanlines with the color in A
; =============================================================================
; How to call:   A = color byte, Y = scanline count, then JSR PaintLines
; What it does:  waits for the next scanline to start, then writes the color
;                to COLUBK once per line for Y lines — every write lands in
;                HBLANK, so band boundaries fall exactly on scanlines.
; Registers:     A survives, X is never touched (the hue index lives there),
;                Y is used up counting lines down to 0.
; Stack:         JSR pushed the return address; the RTS pops it.
; =============================================================================
PaintLines:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEY                     ; one line fewer to go
    BNE -
    RTS

; =============================================================================
; DATA — the hue nibbles: entry k is k << 4, k = 0...15
; =============================================================================
; The table holds the palette byte's HIGH nibble and nothing else; the low
; nibble's luminance field is ORed in from RAM at paint time.  Aligned so
; X can never push a read across a page: every fetch costs 4 cycles.
    !align 15, 0, 0
HueNibbles:
    !byte $00, $10, $20, $30    ; hues 0-3  (0 = light gray)
    !byte $40, $50, $60, $70    ; hues 4-7  (4 = red, 7 = violet)
    !byte $80, $90, $A0, $B0    ; hues 8-11 (8 = blue, 11 = teal-green)
    !byte $C0, $D0, $E0, $F0    ; hues 12-15 (12 = green, 15 = yellow)

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
