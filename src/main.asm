; =============================================================================
; MAIN.ASM — Atari 2600 Starter ROM: Rainbow Background
; =============================================================================
;
; This is a minimal but complete Atari 2600 program that displays a
; rainbow-colored screen. The colors shift each frame, creating a
; smooth animated effect.
;
; Build:  acme -f plain -o build/game.bin src/main.asm
; Run:    stella build/game.bin
;
; NTSC frame structure (262 scanlines total):
;   - 3 lines   VSYNC    (tell TV: "new frame starts here!")
;   - 37 lines  VBLANK   (screen is blanked; do game logic here)
;   - 192 lines KERNEL   (visible picture; draw graphics here)
;   - 30 lines  OVERSCAN (screen is blanked; more game logic time)
;
; =============================================================================

    ; Tell ACME we're writing 6502 code (the 6507 is a 6502 subset)
    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES ($80-$FF — only 128 bytes available!)
; =============================================================================
; We define our variables by assigning addresses in the zero page RAM.
; On the 2600, RAM lives at $80-$FF. That's it. 128 bytes for everything:
; your game state, counters, positions, scores... everything.
; =============================================================================

BGColor     = $80       ; Background color — we'll increment this each frame
FrameCount  = $81       ; Frame counter (for fun, counts 0-255 and wraps)

; =============================================================================
; ROM START
; =============================================================================
; The Atari 2600 ROM cartridge is mapped at $F000-$FFFF (4KB).
; We set the program counter to $F000 so our code ends up at the right address.
; The reset vector at $FFFC will point to our entry point.
; =============================================================================

    * = $F000           ; Set program counter to start of ROM

; =============================================================================
; ENTRY POINT — Called on power-on and reset
; =============================================================================
Reset:
    +clean_start        ; Zero all RAM and TIA registers, set up stack

; =============================================================================
; MAIN LOOP — One iteration = one TV frame (1/60th of a second for NTSC)
; =============================================================================
; Every frame follows the same structure:
;   1. VSYNC    — 3 scanlines to signal start of frame
;   2. VBLANK   — 37 scanlines of blanked screen (game logic time)
;   3. KERNEL   — 192 visible scanlines (drawing time!)
;   4. OVERSCAN — 30 scanlines of blanked screen (more logic time)
; =============================================================================

StartFrame:

; -----------------------------------------------------------------------------
; VSYNC — 3 scanlines
; -----------------------------------------------------------------------------
; The TV needs a vertical sync pulse to know where the top of the picture is.
; Our macro handles this: set VSYNC register, wait 3 lines, clear it.
; -----------------------------------------------------------------------------
    +vsync

; -----------------------------------------------------------------------------
; VBLANK — 37 scanlines
; -----------------------------------------------------------------------------
; The screen is blanked (VBLANK register is already set from clean_start).
; We use a timer to measure 37 scanlines worth of time, and spend that
; time doing game logic. When the timer expires, VBLANK is over.
; -----------------------------------------------------------------------------

    ; Turn on VBLANK (blank the screen while we do logic)
    LDA #$02
    STA VBLANK

    ; Set timer for ~37 scanlines (43 x 64 = 2752 cycles)
    +set_timer 43

    ; === GAME LOGIC GOES HERE ===
    ; This is where you'd read joystick, update positions, check collisions, etc.
    ; For now, we just increment the background color each frame.

    INC FrameCount      ; Count frames (0, 1, 2, ... 255, 0, 1, ...)
    INC BGColor         ; Next color in the palette each frame

    ; === END GAME LOGIC ===

    ; Wait for VBLANK timer to expire
    +wait_timer

    ; Turn off VBLANK — the visible part of the screen starts NOW!
    LDA #$00
    STA VBLANK

; -----------------------------------------------------------------------------
; KERNEL — 192 visible scanlines
; -----------------------------------------------------------------------------
; This is where you draw the picture! The electron beam is scanning across
; the TV screen, and you must feed the TIA data in real-time.
;
; For this starter, we'll create a rainbow effect: each scanline gets a
; different background color based on our BGColor variable + the line number.
;
; In a real game, this is where you'd set up player sprites, playfield
; graphics, and carefully time everything to the beam position.
; -----------------------------------------------------------------------------

    LDX #192            ; 192 visible scanlines to draw
    LDA BGColor         ; Start with our current background color

.kernel_loop:           ; ACME local label (starts with dot)
    STA WSYNC           ; Wait for the START of the next scanline
    STA COLUBK          ; Set background color for this scanline
                        ; (A still has our color value)
    CLC
    ADC #$01            ; Next color for next line (creates gradient)
    DEX                 ; One less scanline to do
    BNE .kernel_loop    ; Loop until all 192 lines are drawn

    ; Done drawing! The visible part is over.

; -----------------------------------------------------------------------------
; OVERSCAN — 30 scanlines
; -----------------------------------------------------------------------------
; The beam is past the visible area. We blank the screen again and have
; ~30 scanlines worth of time for additional game logic.
; -----------------------------------------------------------------------------

    ; Turn on VBLANK again (blank the screen)
    LDA #$02
    STA VBLANK

    ; Set timer for ~30 scanlines (35 x 64 = 2240 cycles)
    +set_timer 35

    ; === ADDITIONAL GAME LOGIC GOES HERE ===
    ; You could do score calculations, sound updates, etc.

    ; === END ADDITIONAL LOGIC ===

    ; Wait for overscan timer to expire
    +wait_timer

    ; Jump back to start the next frame!
    JMP StartFrame

; =============================================================================
; INTERRUPT VECTORS
; =============================================================================
; The 6502/6507 reads three 16-bit vectors from the top of memory:
;   $FFFA-$FFFB = NMI   (Non-Maskable Interrupt — not used on 2600)
;   $FFFC-$FFFD = RESET (where to start on power-on/reset)
;   $FFFE-$FFFF = IRQ   (Interrupt Request — not used on 2600)
;
; We pad the ROM to exactly 4KB and place the vectors at the end.
; =============================================================================

    ; Pad ROM to fill 4KB minus 6 bytes for vectors
    * = $FFFA

    !word Reset         ; NMI vector    — just point to Reset
    !word Reset         ; RESET vector  — this is the real entry point!
    !word Reset         ; IRQ vector    — just point to Reset
