; =============================================================================
; LESSON 08 — EXERCISE 2 SOLUTION: The Callee Saves X
; =============================================================================
;
; Challenge: write a subroutine that DELIBERATELY clobbers X, but still hands
; the caller's X back untouched — by saving it with TXA / PHA on entry and
; restoring it with PLA / TAX just before the RTS.  Then prove that the
; caller's live X really survives the call.
;
; The lesson ROM saved its band counter on the CALLER's side of the call (it
; pushed X before the JSR).  Here the saving moves into the callee:
;
;   PaintBandSafe:
;       TXA             ; A = the caller's X ...
;       PHA             ; ... saved on the stack
;       TYA             ; A = the color (this painter takes its color in Y,
;                       ;          which leaves A free for the save/restore)
;       LDX #LINES      ; X = 48 lines: the deliberate clobber
;       ...
;       PLA             ; A = the caller's X back ...
;       TAX             ; ... and into X, which is what the caller expects
;       RTS
;
; That is a CONTRACT: "I use X, but I give it back."  The caller can now keep
; a live value in X across the call and never think about it:
;
;   DrawScreen:
;       LDX #3          ; X = band index, counting DOWN 3, 2, 1, 0
;   BandLoop:
;       LDA BandColors,X    ; A = this band's color
;       TAY                 ; Y = the color, for the painter
;       JSR PaintBandSafe   ; X is used inside ... and restored before RTS
;       DEX
;       BPL BandLoop        ; N clear -> still 0..127: another band
;       RTS
;
; Why count DOWN?  It makes a broken restore visible.  The line loop inside
; PaintBandSafe ends with X = 0, so if the PLA / TAX were missing, the first
; DEX would take X from 0 to $FF, set N, and BPL would fall straight out of
; the loop after ONE band — the screen would show a single band instead of
; four.  The picture on screen is the proof: four bands mean X survived.
;
; Expected screen: the same four bands as the lesson ROM — red, green, blue,
; gold, top to bottom (the top band one scanline taller: the beam-release line
; already carries its color).
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- Colors (NTSC) ---
RED         = $42       ; band 3 (painted first) = top band
GREEN       = $C8       ; band 2
BLUE        = $96       ; band 1
GOLD        = $1A       ; band 0 = bottom band

; --- Geometry ---
BANDS       = 4         ; bands on the screen: 4 calls of 48 painted lines
LINES       = 48        ; scanlines per painting call (top band + the release
                        ; line; 4 x 48 + 1 = 193 non-blanked scanlines)

    * = $F000

Reset:
    +clean_start

; =============================================================================
; MAIN LOOP — one pass = one frame; SP = $FF at this label
; =============================================================================
StartFrame:
    +vsync

    LDA #$02
    STA VBLANK
    +set_timer 43
    +wait_timer

    LDA BandColors+BANDS-1  ; pre-load the top band's color (the table is
    STA COLUBK              ; bottom-first here) before the beam is released

    LDA #$00
    STA VBLANK

    JSR DrawScreen

    STA WSYNC               ; move the blank-on into HBLANK: the unwind home
                            ; from DrawScreen would otherwise clip partway
                            ; across the last band line

    LDA #$02
    STA VBLANK
    +set_timer 35
    +wait_timer

    JMP StartFrame

; =============================================================================
; DrawScreen — the band counter stays in X; the CALLEE protects it
; =============================================================================
DrawScreen:
    LDX #BANDS-1            ; X = 3: band index, counting DOWN (3 = top band)
BandLoop:
    LDA BandColors,X        ; A = this band's color; X is our own live counter
    TAY                     ; Y = the color: this painter takes it in Y
    JSR PaintBandSafe       ; X is used up inside — and restored before the RTS
    DEX                     ; next band down: 3, 2, 1, 0
    BPL BandLoop            ; N clear -> still 0..127: another band to paint
    RTS

; =============================================================================
; PaintBandSafe — paint LINES scanlines of the color in Y; X is preserved
; =============================================================================
; Contract: Y = color on entry; on return the caller's X is untouched.
; The painter uses X as its line counter, so it borrows X from the stack.
; =============================================================================
PaintBandSafe:
    TXA                     ; A = the caller's X ...
    PHA                     ; ... saved on the stack
    TYA                     ; A = the color (Y is free again after this)
    LDX #LINES              ; X = 48: the line counter (this clobbers X)
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEX                     ; one line fewer to go: 48, 47, ... 1
    BNE -                   ; loop until the line counter reaches 0
    PLA                     ; A = the caller's X back ...
    TAX                     ; ... into X, as the contract promises
    RTS

; =============================================================================
; DATA — indexed by the DOWN-counting band index: X = 3 is the top band
; =============================================================================
BandColors:
    !byte GOLD, BLUE, GREEN, RED        ; X = 0 (bottom) ... X = 3 (top)

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
