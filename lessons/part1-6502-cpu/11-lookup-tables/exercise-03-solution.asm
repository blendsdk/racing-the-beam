; =============================================================================
; LESSON 11 — EXERCISE 3 SOLUTION: A Pointer Table Picks the Wave (stretch)
; =============================================================================
;
; Challenge: keep the wave scrolling, but let a POINTER TABLE choose which of
; two palettes it reads.  WavePtrs holds two !word entries — the 16-bit
; addresses of WaveA and WaveB — and every two seconds the selector flips, so
; the picture changes palette while it keeps moving.
;
; Why this works:
;   - !word stores a 16-bit address, so a table of !word entries is a table of
;     POINTERS: one level of indirection more than the lesson's color table.
;     What the table holds is not the picture — it is WHERE the picture comes
;     from, and swapping one entry swaps the whole palette.
;   - A ROM pointer table cannot be read with (zp,X).  That mode reads the
;     pointer out of ZERO PAGE, and WavePtrs lives in cartridge space (page
;     $F0+).  So the pointer is loaded in two halves — LDA WavePtrs,X for the
;     low byte, LDA WavePtrs+1,X for the high byte — and both are stored into
;     the zero-page pair at $80/$81.  (zp),Y then walks whichever wave it
;     points at, and the kernel itself never changes.
;   - X is the selector times two, because each entry is two bytes wide:
;     X = 0 picks WaveA's address, X = 2 picks WaveB's.
;   - Here the wave index lives in Y, because (zp),Y adds Y to the pointer.
;     That is why this version counts scanlines in X (Lesson 09's PaintBand
;     contract) instead of in Y, the way the lesson ROM does.
;
; The two waves are the same 16 colors in opposite order: WaveB is WaveA read
; backwards, so the switch is unmistakable — the ramp turns upside down while
; the scroll keeps running.
;
; Frame geometry: 192 non-blanked scanlines — 16 equal bands of 12 lines.
; Band 0's color is fetched during VBLANK, so the beam-release line is band
; 0's FIRST line and PaintBand paints the other 11; every other band is one
; PaintBand call of 12 lines.  The blank-on after the last band waits for
; HBLANK first (STA WSYNC), so the last band line is painted whole.
;
; Expected screen: the lesson's scrolling wave for about two seconds, then the
; same colors read backwards for about two seconds, and so on.  Both palettes
; keep the scroll running one band per step, and every band on screen is a
; table entry — only the table it came from changes.
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
Ptr         = $80       ; $80/$81: the zero-page pointer the kernel reads with
                        ;   (zp),Y.  Its two bytes are filled from WavePtrs.
Offset      = $82       ; the wave position: 0...15, the TOP band's index
WaveTimer   = $83       ; frames left before the wave takes its next step
BandsLeft   = $84       ; bands still to paint this frame: 15 after band 0
Selector    = $85       ; which pointer-table entry is in use: 0 or 1
SwitchTimer = $86       ; frames left before the palette flips

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
BANDS         = 16      ; bands on the screen — one per table entry
LINES         = 12      ; scanlines per band (16 x 12 = 192 non-blanked lines)
STEP_FRAMES   = 16      ; frames between wave steps (~1/4 second at 60 Hz)
SWITCH_FRAMES = 120     ; frames between palette switches (~2 seconds at 60 Hz)
INDEX_MASK    = $0F     ; keeps (offset + k) inside the 16-byte tables

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

    ; --- The wave starts at offset 0 on the first palette ---
    LDA #$00
    STA Offset              ; TOP band = WaveA[0] = $1A, next band = WaveA[1] ...
    STA Selector            ; 0 = WaveA: the first pointer-table entry
    LDA #STEP_FRAMES
    STA WaveTimer           ; the first wave step comes after one full cadence
    LDA #SWITCH_FRAMES
    STA SwitchTimer         ; the first palette switch comes ~2 seconds later

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame
; =============================================================================
StartFrame:
    +vsync                  ; 3-line VSYNC — "a new frame starts now"

    LDA #$02
    STA VBLANK              ; blank the beam while we set up
    +set_timer 43           ; ~37 scanlines of VBLANK

; -----------------------------------------------------------------------------
; POINT THE ZERO-PAGE POINTER AT THE SELECTED WAVE
; -----------------------------------------------------------------------------
; Two halves, because the pointer table is in ROM: the entry's low byte goes to
; $80 and its high byte to $81.  X addresses the entry (2 bytes each), so the
; selector doubles as the index once it is shifted left.
    LDX Selector            ; 0 or 1: which !word entry to read
    TXA
    ASL                     ; x2: each pointer-table entry is two bytes wide
    TAX
    LDA WavePtrs,X          ; low byte of the chosen wave's address ...
    STA Ptr
    LDA WavePtrs+1,X        ; ... then the byte right after it: the high byte
    STA Ptr+1               ; $80/$81 now point at WaveA or WaveB
PtrLoaded:                  ; debugger checkpoint: break here, A = the high byte

; -----------------------------------------------------------------------------
; BAND 0 — fetched through the pointer while the beam is still blanked
; -----------------------------------------------------------------------------
; Band 0's index is (offset + 0) AND $0F — the offset itself.  Offset is kept
; in 0...15 by the code that writes it, so this mask is a no-op here; it is
; written anyway because every index in this program goes through the same
; mask, and one extra instruction during VBLANK is cheaper than one index that
; escapes the table.
    LDY Offset              ; Y = the wave position, 0...15
    TYA
    AND #INDEX_MASK         ; (offset + 0) AND $0F
    TAY
    LDA (Ptr),Y             ; band 0's color: Wave[(offset + 0) AND $0F]
WaveFetch0:                 ; debugger checkpoint: break here, A = color, Y = index
    TAX                     ; park the color: +wait_timer clobbers A

    +wait_timer             ; finish the ~37 scanlines of VBLANK

    LDA #$00
    STA VBLANK              ; release the beam: this line is band 0's FIRST line
    TXA                     ; A = band 0's color again
    STA COLUBK              ; written in HBLANK, so the release line shows it
    LDX #LINES-1            ; X = 11: release line + 11 painted = band 0's 12
    JSR PaintBand           ; paint them — A and Y survive, X is used up

; -----------------------------------------------------------------------------
; BANDS 1-15 — one pointer read per band, with a moving index
; -----------------------------------------------------------------------------
    LDA #BANDS-1            ; 15 bands left after band 0
    STA BandsLeft
BandLoop:
    INY                     ; Y = offset + k for the band about to be painted
    TYA                     ; A = offset + k, which can be 16...30
    AND #INDEX_MASK         ; 16...30 comes back as 0...14 — that is the wrap ...
    TAY                     ;   ... and Y is never allowed past 15
    LDA (Ptr),Y             ; band k's color, through the pointer
WaveFetch:                  ; debugger checkpoint: break here, A = color, Y = index
    LDX #LINES              ; X = 12: a full band
    JSR PaintBand           ; paint it — A and Y survive, X is used up
    DEC BandsLeft           ; one band fewer to go
    BNE BandLoop

; -----------------------------------------------------------------------------
; OVERSCAN
; -----------------------------------------------------------------------------
    STA WSYNC               ; wait for HBLANK before blanking: the last band
                            ; line is being drawn right now, so writing VBLANK
                            ; here would clip it partway across
    LDA #$02
    STA VBLANK
    +set_timer 35           ; ~30 scanlines of overscan
    +wait_timer

; -----------------------------------------------------------------------------
; THE WAVE CLOCK — the wave steps once every STEP_FRAMES frames
; -----------------------------------------------------------------------------
    DEC WaveTimer           ; one frame closer to the next step
    BNE NoStep              ; not 0 yet -> the offset stays put
    LDA #STEP_FRAMES        ; countdown reached 0 -> reload it ...
    STA WaveTimer
    INC Offset              ; ... and move the wave one entry up the screen
    LDA Offset              ; A = offset + 1
    AND #INDEX_MASK         ; wrap 16 back to 0 — the same mask as the kernel
    STA Offset              ; Offset is 0...15 again
NoStep:

; -----------------------------------------------------------------------------
; THE PALETTE CLOCK — flip the selector once every SWITCH_FRAMES frames
; -----------------------------------------------------------------------------
    DEC SwitchTimer         ; one frame closer to the palette switch
    BNE NoSwitch            ; not 0 yet -> the same wave next frame
    LDA #SWITCH_FRAMES      ; countdown reached 0 -> reload it ...
    STA SwitchTimer
    LDA Selector
    EOR #$01                ; ... and flip 0 <-> 1: the other !word entry
    STA Selector            ; next frame's pointer load reads the other wave
NoSwitch:
    JMP StartFrame          ; next frame

; =============================================================================
; SUBROUTINE: PaintBand — paint X scanlines of the color in A
; =============================================================================
; How to call:   A = color byte, X = scanline count, then JSR PaintBand
; What it does:  waits for the next scanline to start, then writes the color
;                to COLUBK once per line for X lines.  Writing the color
;                right after the WSYNC puts the change in the first few
;                cycles of the line, so band boundaries fall exactly on a
;                scanline.
; Registers:     A survives (still the color) and Y is never touched — the
;                wave index lives in Y in this version, so the kernel depends
;                on that; X is used up: the line counter counts it down to 0.
; Stack:         JSR pushed the return address; the RTS pops it.
; =============================================================================
PaintBand:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEX                     ; one line fewer to go: 12, 11, ... 1
    BNE -                   ; loop until the line counter reaches 0
    RTS                     ; return; the return address comes off the stack

; =============================================================================
; DATA — two 16-byte color tables, and a table of POINTERS to them
; =============================================================================
; Each wave is 16-byte aligned (!align 15, 0, 0: mask $0F pads to the next
; multiple of 16, and the third field is the fill byte — 0, not the default
; $EA), so an index of 0...15 can never push a (zp),Y load across a page.
    !align 15, 0, 0
WaveA:
    !byte $1A, $28, $36, $44    ; k = 0...3  — the lesson's ramp ...
    !byte $52, $60, $6E, $7C    ; k = 4...7
    !byte $8A, $98, $A6, $B4    ; k = 8...11
    !byte $C2, $D0, $DE, $EC    ; k = 12...15
    !align 15, 0, 0
WaveB:
    !byte $EC, $DE, $D0, $C2    ; ... read backwards: k = 0...3
    !byte $B4, $A6, $98, $8A    ; k = 4...7
    !byte $7C, $6E, $60, $52    ; k = 8...11
    !byte $44, $36, $28, $1A    ; k = 12...15

; The pointer table: one !word per wave.  Entry 0 is the low/high byte pair at
; WavePtrs/WavePtrs+1, entry 1 is the pair at WavePtrs+2/WavePtrs+3.
WavePtrs:
    !word WaveA                 ; entry 0: the starting palette
    !word WaveB                 ; entry 1: the palette it flips to

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
