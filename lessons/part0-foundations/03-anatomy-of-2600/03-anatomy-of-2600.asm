; =============================================================================
; LESSON 03: Anatomy of the Atari 2600
; =============================================================================
; Part 0: Foundations
;
; What this program does:
;   This is a "tour ROM." Every instruction is annotated with WHICH of the
;   three chips it talks to — the 6507 CPU, the TIA, or the RIOT. As it runs
;   it paints a smoothly shifting rainbow: each scanline gets a different
;   background color, and the whole pattern scrolls down the screen one step
;   per frame. The rainbow exists purely so there is obvious visible output;
;   the real lesson is in the comments and in the memory map below.
;
;   Read this file top-to-bottom alongside the lesson text. Each block is
;   tagged like this:
;
;       [CPU ]  — the 6507 is doing work in its own registers (A/X/Y/PC...)
;       [TIA ]  — we are writing to the graphics+sound chip ($00-$3F)
;       [RIOT]  — we are talking to the RAM-I/O-Timer chip (RAM + $0280-$0297)
;
; THE MEMORY MAP (the heart of this lesson):
;   $00-$3F   TIA registers      (graphics & sound — the "video card")
;   $80-$FF   RIOT RAM           (your 128 bytes of variable storage)
;   $0280-$0297 RIOT I/O & timer (joysticks, console switches, interval timer)
;   $F000-$FFFF ROM              (your cartridge — this very program)
;
;   The 6507 only has 13 address lines (A0-A12), so it can "see" just 8 KB
;   of address space at once. That is why the same chip appears at many
;   addresses (mirroring) and why ROM is anchored at $F000 with the 6502
;   reset/interrupt vectors living at $FFFA-$FFFF.
;
; Build: acme -f plain -o build/lesson03.bin lessons/part0-foundations/03-anatomy-of-2600/03-anatomy-of-2600.asm
; Run:   stella build/lesson03.bin
;
; =============================================================================

    !cpu 6502                       ; [CPU ] 6507 is a 6502 core in a 28-pin package

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"       ; TIA + RIOT register names ($00-$3F, $0280+)
    !source "include/macro.asm"     ; +clean_start, +vsync, +set_timer, +wait_timer

; =============================================================================
; RAM VARIABLES  —  these live in the RIOT chip ($80-$FF)
; =============================================================================
; There is no malloc, no stack frame of locals — a "variable" is simply a
; RIOT RAM address you decide to use. We pick $80 for our one variable.

RainbowOffset   = $80    ; [RIOT] shifts the rainbow down by 1 each frame

; =============================================================================
; ROM START  —  this code lives in the cartridge ($F000-$FFFF)
; =============================================================================

    * = $F000               ; Place everything from here at ROM address $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
; On power-up the 6507 reads the RESET vector at $FFFC/$FFFD and jumps here.
Reset:
    +clean_start            ; [CPU+TIA+RIOT] zero TIA regs AND RIOT RAM, set stack
                            ; (the macro's STA $00,X loop sweeps right through the
                            ;  TIA register block and its mirrors — a live demo of
                            ;  the memory map you'll explore in the exercises)

; =============================================================================
; MAIN LOOP  —  one pass through here draws exactly one TV frame
; =============================================================================
StartFrame:

; --- VSYNC (3 scanlines) ---
    +vsync                  ; [TIA ] pulse the VSYNC register — "new frame" to the TV

; --- VBLANK (37 scanlines) ---
    LDA #$02                ; [CPU ] A = %00000010 (VBLANK bit)
    STA VBLANK              ; [TIA ] blank the beam during the top margin
    +set_timer 43           ; [RIOT] start the interval timer to fill VBLANK

    ; === GAME LOGIC (runs while the RIOT timer counts down) ===
    INC RainbowOffset       ; [RIOT] bump our scroll offset in RAM — this is the
                            ;        only thing that changes frame-to-frame, and
                            ;        it makes the rainbow appear to flow downward
    ; === END GAME LOGIC ===

    +wait_timer             ; [RIOT] wait for the timer to hit zero (end of VBLANK)
    LDA #$00                ; [CPU ] A = 0
    STA VBLANK              ; [TIA ] un-blank — the visible picture starts now

; --- KERNEL (192 visible scanlines) ---
; The TIA has NO frame buffer. To draw a rainbow we must hand it a fresh
; background color on every single scanline, in real time, as the beam races
; across. We use X as both our line counter (192 -> 0) and, combined with the
; RAM offset, as the color value itself.
; #region kernel
    LDX #192                ; [CPU ] 192 visible scanlines to draw
-                           ;        (anonymous loop label)
    TXA                     ; [CPU ] A = current line number
    CLC                     ; [CPU ] clear carry before adding
    ADC RainbowOffset       ; [CPU+RIOT] A = line + scroll offset (read from RAM)
    STA COLUBK              ; [TIA ] set the background color for THIS scanline
    STA WSYNC               ; [TIA ] halt the 6507 until the beam finishes the line
    DEX                     ; [CPU ] one fewer line to go
    BNE -                   ; [CPU ] loop until all 192 lines are painted
; #endregion kernel

; --- OVERSCAN (30 scanlines) ---
    LDA #$02                ; [CPU ] A = VBLANK bit
    STA VBLANK              ; [TIA ] blank the beam for the bottom margin
    +set_timer 35           ; [RIOT] timer fills the overscan period
    +wait_timer             ; [RIOT] wait it out

    JMP StartFrame          ; [CPU ] back to the top — one loop = one frame

; =============================================================================
; VECTORS  —  the 6507 reads these three 16-bit addresses from the top of ROM
; =============================================================================
; This is WHY ROM must end at $FFFF: the CPU hard-wires these addresses.
    * = $FFFA
    !word Reset     ; NMI    vector (unused on the 2600)
    !word Reset     ; RESET  vector — where the CPU starts on power-up
    !word Reset     ; IRQ    vector (unused on the 2600)
