; =============================================================================
; LESSON 09 — EXERCISE 2 SOLUTION: Packing Two Nibbles into a Color
; =============================================================================
;
; Challenge: a color's two nibbles arrive in two separate bytes, each nibble
; parked in the TOP half of its byte:
;
;   NibbleHi ($80) = %11000000   the color's hue nibble, $C
;   NibbleLo ($81) = %01000000   the color's luminance nibble, $4
;
; Pack them into one color byte ($C4) with AND, LSR and ORA, and paint the
; picture with the result:
;
;   LDA NibbleHi    ; %11000000
;   AND #$F0        ; AND keeps only the top nibble -> %11000000
;   STA Packed      ; the high half of the color is ready
;   LDA NibbleLo    ; %01000000
;   LSR             ; ÷ 2  each shift moves the nibble down one bit ...
;   LSR
;   LSR
;   LSR             ; ... four shifts = ÷ 16 -> %00000100
;   ORA Packed      ; ORA sets the bits of both halves -> %11000100
;   STA Packed      ; $C4: one color byte
;
; Why this works: a nibble parked at the top is the same nibble multiplied
; by 16, and LSR is division by 2 — four of them undo the ×16.  AND throws
; away whatever lived below the nibble, and ORA merges the two halves because
; their set bits never overlap.  (NTSC color bytes are CCCCLLL0: hue C,
; luminance 4 here.)
;
; The packing runs once per frame, during VBLANK, so you can edit $80 or $81
; in the debugger and watch the picture change on the next frame: try $80 =
; %10000000 ($8, dark violet-blue) and the packed byte becomes $84.
;
; Expected screen: the whole picture in the packed color $C4 — a dimmer green
; (same hue as the ladder's bright green, lower luminance).  The packed byte
; is readable at RAM $82.
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- RAM variables ---
NibbleHi    = $80       ; the color's high nibble, parked at the top: %11000000
NibbleLo    = $81       ; the color's low nibble,  parked at the top: %01000000
Packed      = $82       ; the packed color byte: %11000100 = $C4, packed here

; --- Program constants ---
BANDS       = 8         ; the lesson's eight bands ...
LINES       = 24        ; ... of 24 scanlines = 192 visible lines

    * = $F000

Reset:
    +clean_start

    LDA #%11000000          ; the color's high nibble (hue C) ...
    STA NibbleHi
    LDA #%01000000          ; ... and its low nibble (luminance 4)
    STA NibbleLo

; =============================================================================
; MAIN LOOP — one pass = one frame
; =============================================================================
StartFrame:
    +vsync

    LDA #$02
    STA VBLANK
    +set_timer 43

    ; --- pack the nibbles while the beam is blanked ---
    LDA NibbleHi            ; %11000000
    AND #$F0                ; keep only the top nibble
    STA Packed              ; the color's high half
    LDA NibbleLo            ; %01000000
    LSR                     ; shift right: bit 7 -> bit 6 ...
    LSR
    LSR
    LSR                     ; ... four shifts: ÷ 16 -> %00000100
    ORA Packed              ; merge the halves (%11000000 OR %00000100)
PackedDone:                 ; debugger checkpoint: A = the packed color byte
    STA Packed              ; $C4 — one color byte, readable in the debugger
    STA COLUBK              ; ready before the beam is released, so the
                            ; release line already carries the packed color
    +wait_timer

    LDA #$00
    STA VBLANK              ; release the beam

; -----------------------------------------------------------------------------
; KERNEL — the whole picture is the packed color
; -----------------------------------------------------------------------------
; The release line already carries the color, so one countdown paints the
; remaining 191 lines: release + 191 = 192 lines = eight 24-line bands.
    LDA Packed              ; A = the packed color
    LDX #LINES*BANDS-1      ; 191 = 192 - the release line
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the packed color
    DEX
    BNE -

    ; --- overscan; WSYNC keeps the blank-on out of the last picture line ---
    STA WSYNC
    LDA #$02
    STA VBLANK
    +set_timer 35
    +wait_timer

    JMP StartFrame

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
