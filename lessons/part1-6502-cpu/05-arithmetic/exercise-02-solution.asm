; =============================================================================
; LESSON 05 - EXERCISE 2 SOLUTION: A Countdown Timer Variable
; =============================================================================
; Challenge: Keep a "timer" byte in RAM that counts DOWN by one each frame.
;            When it reaches zero, reload it to the starting value so it loops
;            forever. Show the timer value as the background color so you can
;            watch it ramp down and snap back, over and over.
; Solution:  DEC the timer every frame. After DEC, the zero flag tells us if
;            we hit 0; BNE skips the reload, otherwise we LDA #start / STA.
;
; Build: acme -f plain -o build/lesson05-ex2.bin \
;        lessons/part1-6502-cpu/05-arithmetic/exercise-02-solution.asm
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- RAM ---
Timer       = $80   ; counts down each frame
START_VALUE = $9E   ; value the timer reloads to when it hits zero

    * = $F000

Reset:
    +clean_start

    LDA #START_VALUE    ; prime the timer with its starting value
    STA Timer

StartFrame:
    +vsync

    LDA #$02
    STA VBLANK
    +set_timer 43

    ; === GAME LOGIC: tick the countdown once per frame ===
    DEC Timer           ; Timer = Timer - 1   (sets Z flag if result is 0)
    BNE +               ; not zero yet? skip the reload
    LDA #START_VALUE    ; hit zero — reload to the top
    STA Timer
+                       ; (anonymous forward label = "continue here")
    ; === END GAME LOGIC ===

    +wait_timer
    LDA #$00
    STA VBLANK

; --- KERNEL: paint the whole screen with the current timer value ---
; #region kernel
    LDA Timer
    STA COLUBK
    LDX #192
-   STA WSYNC
    DEX
    BNE -
; #endregion kernel

    LDA #$02
    STA VBLANK
    +set_timer 35
    +wait_timer

    JMP StartFrame

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
