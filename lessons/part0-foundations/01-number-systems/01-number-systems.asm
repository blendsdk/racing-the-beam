; =============================================================================
; LESSON 01: Number Systems — Binary, Hexadecimal, and You
; =============================================================================
; Part 0: Foundations
;
; What this program does:
;   Stores hex values in RAM, applies AND/OR/EOR bitmasks, and displays
;   the results as background colors. Each scanline zone shows a different
;   value so you can SEE the connection between hex numbers and colors.
;
; What you'll learn:
;   - How hex values map to Atari 2600 colors
;   - How AND masks extract parts of a byte
;   - How OR and EOR modify bytes
;
; Build: acme -f plain -o build/lesson01.bin lessons/part0-foundations/01-number-systems/01-number-systems.asm
; Run:   stella build/lesson01.bin
;
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES
; =============================================================================

OriginalValue   = $80    ; The value we start with ($1A = orange)
MaskedLower     = $81    ; After AND #$0F — lower nibble only
MaskedUpper     = $82    ; After AND #$F0 — upper nibble only
OrResult        = $83    ; After ORA #$44 — bits set
EorResult       = $84    ; After EOR #$FF — bits toggled (inverted)
FrameCount      = $85    ; Frame counter (increments each frame)

; =============================================================================
; ROM START
; =============================================================================

    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start

    ; --- Initialize our demo values ---
    ; We pick $1A (orange, medium brightness) as our starting value.
    ; Then we apply different bitmask operations and store each result
    ; in its own RAM address. You can inspect these in the Stella debugger!

    ; Store the original value
    LDA #$1A             ; $1A = %00011010 = orange (hue 1, luminance 5)
    STA OriginalValue    ; RAM $80 = $1A

    ; AND mask: extract lower nibble (bits 3-0)
    ; This isolates the luminance portion of the color byte
    AND #$0F             ; $1A AND $0F = %00001010 = $0A
    STA MaskedLower      ; RAM $81 = $0A

    ; AND mask: extract upper nibble (bits 7-4)
    ; This isolates the hue portion of the color byte
    LDA OriginalValue    ; Reload original ($1A)
    AND #$F0             ; $1A AND $F0 = %00010000 = $10
    STA MaskedUpper      ; RAM $82 = $10

    ; OR: set additional bits
    ; ORA combines bits from both values — any bit that's 1 in EITHER
    ; the original OR the mask becomes 1 in the result
    LDA OriginalValue    ; Reload original ($1A)
    ORA #$44             ; $1A ORA $44 = %01011110 = $5E
    STA OrResult         ; RAM $83 = $5E

    ; EOR: toggle (flip) all bits
    ; EOR flips every bit where the mask has a 1.
    ; Using $FF as the mask flips ALL bits — this is a bitwise NOT.
    LDA OriginalValue    ; Reload original ($1A)
    EOR #$FF             ; $1A EOR $FF = %11100101 = $E5
    STA EorResult        ; RAM $84 = $E5

; =============================================================================
; MAIN LOOP — One iteration = one TV frame (1/60th second NTSC)
; =============================================================================

StartFrame:

; --- VSYNC (3 scanlines) ---
    +vsync

; --- VBLANK (37 scanlines) ---
    LDA #$02
    STA VBLANK           ; Turn on screen blanking
    +set_timer 43        ; Timer for ~37 scanlines

    ; === GAME LOGIC ===
    INC FrameCount       ; Count frames (just for reference)
    ; === END GAME LOGIC ===

    +wait_timer          ; Wait for VBLANK period to end
    LDA #$00
    STA VBLANK           ; Turn off screen blanking — visible area starts!

; --- KERNEL (192 visible scanlines) ---
; We divide the screen into 5 colored zones, one for each value:
;   Zone 1: Original value    ($1A = orange)          — 38 lines
;   Zone 2: AND lower nibble  ($0A = dark gold)       — 38 lines
;   Zone 3: AND upper nibble  ($10 = dark yellow)     — 38 lines
;   Zone 4: OR result         ($5E = bright pink)     — 40 lines
;   Zone 5: EOR result        ($E5 = light blue)      — 38 lines
;                                              Total: 192 lines ✓

; #region kernel

    ; --- Zone 1: Original value $1A (38 scanlines) ---
    LDA OriginalValue    ; Load $1A (orange)
    STA COLUBK           ; Set as background color
    LDX #38              ; 38 scanlines for this zone
-   STA WSYNC            ; Wait for end of current scanline
    DEX                  ; Decrement counter
    BNE -                ; Loop until zone is complete

    ; --- Zone 2: AND lower nibble $0A (38 scanlines) ---
    LDA MaskedLower      ; Load $0A (dark gold)
    STA COLUBK           ; Set as background color
    LDX #38
-   STA WSYNC
    DEX
    BNE -

    ; --- Zone 3: AND upper nibble $10 (38 scanlines) ---
    LDA MaskedUpper      ; Load $10 (dark yellow-orange)
    STA COLUBK           ; Set as background color
    LDX #38
-   STA WSYNC
    DEX
    BNE -

    ; --- Zone 4: OR result $5E (40 scanlines) ---
    LDA OrResult         ; Load $5E (bright pink/magenta)
    STA COLUBK           ; Set as background color
    LDX #40              ; 40 lines (2 extra to reach 192 total)
-   STA WSYNC
    DEX
    BNE -

    ; --- Zone 5: EOR result $E5 (38 scanlines) ---
    LDA EorResult        ; Load $E5 (light blue-green)
    STA COLUBK           ; Set as background color
    LDX #38
-   STA WSYNC
    DEX
    BNE -

; #endregion kernel

; --- OVERSCAN (30 scanlines) ---
    LDA #$02
    STA VBLANK           ; Blank the screen again
    +set_timer 35        ; Timer for ~30 scanlines

    ; No additional logic needed in overscan for this lesson

    +wait_timer          ; Wait for overscan to complete

    JMP StartFrame       ; Back to the top — next frame!

; =============================================================================
; VECTORS — Tell the CPU where to start
; =============================================================================
; The 6507 reads these addresses on power-on/reset:
;   $FFFA = NMI (not used on 2600)
;   $FFFC = RESET (our entry point!)
;   $FFFE = IRQ (not used on 2600)
; =============================================================================

    * = $FFFA
    !word Reset          ; NMI vector
    !word Reset          ; RESET vector — this is where execution begins
    !word Reset          ; IRQ vector
