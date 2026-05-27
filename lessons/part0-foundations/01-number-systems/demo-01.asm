; =============================================================================
; LESSON 01 DEMO: Hex Color Chart — All 128 NTSC Colors
; =============================================================================
; Part 0: Foundations
;
; What this program does:
;   Displays all 128 NTSC colors as horizontal stripes on screen.
;   The screen shows 16 hues (rows) × 8 luminance levels (each stripe
;   cycles through luminance within its hue group).
;
;   This is a visual reference — you can see how hex color values
;   ($00, $02, $04... $FE) map to actual colors on the Atari 2600.
;
; Color encoding reminder:
;   CCCC LLL0
;   ││││ │││└── Bit 0: unused (always 0)
;   ││││ └└└─── Bits 1-3: Luminance (0-7, higher = brighter)
;   └└└└─────── Bits 4-7: Hue (0-15)
;
; Build: acme -f plain -o build/demo01.bin lessons/part0-foundations/01-number-systems/demo-01.asm
; Run:   stella build/demo01.bin
;
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES
; =============================================================================

ColorValue  = $80        ; Current color value being displayed
HueCount    = $81        ; Counter for hue groups (0-15)
LumCount    = $82        ; Counter for luminance levels within a hue
LineCount   = $83        ; Scanline counter within each color stripe

; =============================================================================
; ROM START
; =============================================================================

    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start

; =============================================================================
; MAIN LOOP
; =============================================================================

StartFrame:

; --- VSYNC (3 scanlines) ---
    +vsync

; --- VBLANK (37 scanlines) ---
    LDA #$02
    STA VBLANK
    +set_timer 43

    ; Reset color to $00 for each frame
    LDA #$00
    STA ColorValue

    +wait_timer
    LDA #$00
    STA VBLANK

; --- KERNEL (192 visible scanlines) ---
; Display all 128 colors: 16 hues × 8 luminances
; Each color gets 1.5 scanlines (192 / 128 = 1.5)
; We approximate: alternate between 1-line and 2-line stripes
; Actually: 16 hues × 12 lines each = 192 lines
; Within each hue: 8 luminances × 1.5 lines each
; Simplification: each hue gets 12 lines, 
; with luminance changing every 1-2 lines

; #region kernel

    ; We'll iterate through 16 hues, 12 scanlines per hue
    LDX #16              ; 16 hue groups
    LDA #$00             ; Start at color $00

.hue_loop:
    ; Save hue counter
    STX HueCount

    ; Display 8 luminance levels within this hue
    ; We have 12 scanlines per hue:
    ;   - First 4 luminances get 1 line each (4 lines)
    ;   - Last 4 luminances get 2 lines each (8 lines)
    ; Total: 4 + 8 = 12 lines per hue ✓

    ; --- Luminance 0: 1 scanline ---
    STA COLUBK           ; Set color
    STA WSYNC
    CLC
    ADC #$02             ; Next luminance (bit 1 increments luminance)

    ; --- Luminance 1: 1 scanline ---
    STA COLUBK
    STA WSYNC
    CLC
    ADC #$02

    ; --- Luminance 2: 1 scanline ---
    STA COLUBK
    STA WSYNC
    CLC
    ADC #$02

    ; --- Luminance 3: 1 scanline ---
    STA COLUBK
    STA WSYNC
    CLC
    ADC #$02

    ; --- Luminance 4: 2 scanlines ---
    STA COLUBK
    STA WSYNC
    STA WSYNC
    CLC
    ADC #$02

    ; --- Luminance 5: 2 scanlines ---
    STA COLUBK
    STA WSYNC
    STA WSYNC
    CLC
    ADC #$02

    ; --- Luminance 6: 2 scanlines ---
    STA COLUBK
    STA WSYNC
    STA WSYNC
    CLC
    ADC #$02

    ; --- Luminance 7: 2 scanlines ---
    STA COLUBK
    STA WSYNC
    STA WSYNC
    CLC
    ADC #$02             ; This advances to the next hue (luminance wraps)

    ; A now points to the start of the next hue
    ; (Because after $x0E + $02 = $x10, which is the next hue at luminance 0)

    LDX HueCount         ; Restore hue counter
    DEX                  ; Next hue
    BNE .hue_loop        ; Loop for all 16 hues

; #endregion kernel

; --- OVERSCAN (30 scanlines) ---
    LDA #$02
    STA VBLANK
    +set_timer 35

    +wait_timer

    JMP StartFrame

; =============================================================================
; VECTORS
; =============================================================================

    * = $FFFA
    !word Reset          ; NMI
    !word Reset          ; RESET
    !word Reset          ; IRQ
