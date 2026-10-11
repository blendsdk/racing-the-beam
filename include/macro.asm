; =============================================================================
; MACRO.ASM — Common Macros for Atari 2600 (ACME Assembler)
; =============================================================================
;
; These macros handle the boilerplate that every 2600 program needs.
; Usage: !source "include/macro.asm"
;
; Macros defined:
;   +clean_start       — Zero all RAM and TIA registers on startup
;   +vsync             — Generate the 3-scanline VSYNC signal
;   +set_timer .ticks  — Set RIOT timer (64-cycle intervals)
;   +wait_timer        — Wait for RIOT timer to expire
;
; =============================================================================

; -----------------------------------------------------------------------------
; +clean_start
; -----------------------------------------------------------------------------
; Call this at the very beginning of your program (after the reset vector
; jumps here). It:
;   1. Disables interrupts and decimal mode
;   2. Zeros out ALL TIA registers ($00-$2C) and all RAM ($80-$FF)
;   3. Sets the stack pointer to $FF (top of the 128-byte RAM)
;
; This ensures a known, clean state on every startup — important because
; the 2600 has no BIOS or OS to initialize things for you!
; -----------------------------------------------------------------------------
!macro clean_start {
    SEI             ; Disable interrupts (6507 doesn't use them, but be safe)
    CLD             ; Clear decimal mode (important! 6502 powers on in unknown state)
    LDX #$00        ; X = 0
    TXA             ; A = 0
    TAY             ; Y = 0
-                   ; anonymous label for loop
    STA $00,X       ; Store 0 at address X (covers $00-$FF)
    DEX             ; X = X - 1  (wraps: $00 -> $FF -> $FE -> ... -> $01 -> $00)
    BNE -           ; Loop until X wraps back to 0
                    ; This zeros TIA ($00-$3F), mirrors, and RAM ($80-$FF)
    LDX #$FF        ; Set stack pointer to top of RAM
    TXS             ; S = $FF -> stack lives in page $01 (mirrors to $80-$FF)
}

; -----------------------------------------------------------------------------
; +vsync
; -----------------------------------------------------------------------------
; Generates the 3-scanline VSYNC signal that tells the TV "new frame!"
;
; The process:
;   1. Set VSYNC bit (register $00, bit 1)
;   2. Wait 3 scanlines (3 x STA WSYNC)
;   3. Clear VSYNC bit
;
; WSYNC halts the CPU until the end of the current scanline, so each
; STA WSYNC = exactly 1 scanline of waiting.
; -----------------------------------------------------------------------------
!macro vsync {
    LDA #$02        ; Bit 1 = VSYNC on
    STA VSYNC       ; Turn on VSYNC
    STA WSYNC       ; Wait for end of scanline 1
    STA WSYNC       ; Wait for end of scanline 2
    STA WSYNC       ; Wait for end of scanline 3
    LDA #$00
    STA VSYNC       ; Turn off VSYNC — 3 lines complete!
}

; -----------------------------------------------------------------------------
; +set_timer .ticks
; -----------------------------------------------------------------------------
; Set the RIOT 64-cycle interval timer.
; Each tick = 64 CPU cycles. One scanline = 76 CPU cycles.
;
; Common values (the first decrement lands one cycle after the write, so
; t ticks cover 1 + (t-1) x 64 cycles):
;   44 ticks = 1 + 43 x 64 = 2753 cycles = the 37-line VBLANK, exactly
;   36 ticks = 1 + 35 x 64 = 2241 cycles = the 30-line overscan, exactly
;   43/35 are the classic community values: one tick short — 36/29 lines
;   and a 260-line frame; usually invisible, never the nominal periods.
;
; The poll and a final WSYNC anchor absorb what remains of the last
; blanked line — the timer just needs to expire before that line ends
; (Lesson 15 derives the whole arithmetic).
; -----------------------------------------------------------------------------
!macro set_timer .ticks {
    LDA #.ticks
    STA TIM64T      ; Start countdown: .ticks x 64 cycles
}

; -----------------------------------------------------------------------------
; +wait_timer
; -----------------------------------------------------------------------------
; Busy-wait until the RIOT timer reaches zero.
; Use this after setting the timer and doing your game logic.
; When it returns, the timed period is complete.
; Also does a WSYNC to align to the start of the next scanline.
; -----------------------------------------------------------------------------
!macro wait_timer {
-                   ; anonymous label
    LDA INTIM       ; Read current timer value
    BNE -           ; Loop if not zero yet
    STA WSYNC       ; Align to scanline boundary
}
