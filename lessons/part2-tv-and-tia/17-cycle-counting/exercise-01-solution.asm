; =============================================================================
; LESSON 17 — EXERCISE 1 SOLUTION: The Counting Drill
; =============================================================================
; Part 2: TV & TIA
;
; Exercise: count the walkthrough drill by hand, then verify the count
;           with breakpoints.
;
; The drill (as printed in the lesson's walkthrough):
;
;   Drill:
;       LDY #$0A            ; 2 cycles
;   DrillLoop:
;       DEY                 ; 2 cycles
;       BNE DrillLoop       ; 3 taken / 2 not taken
;       JMP Drill           ; 3 cycles — run it again (the lesson's
;                           ;   snippet ends here; this ROM loops it so
;                           ;   the breakpoint log keeps running)
;
; The hand count (the exercise's answer):
;   prologue:  LDY #$0A                    2
;   loop:      9 x (DEY 2 + BNE taken 3)  45
;              + DEY 2 + BNE not taken 2    4
;   back edge: JMP Drill                   3
;   ------------------------------------------------------
;   one pass                              54 cycles
;
; Verifying with breakpoints (the recipe):
;   acme -f plain -o build/lesson17-ex1.bin \
;     lessons/part2-tv-and-tia/17-cycle-counting/exercise-01-solution.asm
;   stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F010' \
;     build/lesson17-ex1.bin
;   ($F010 is DrillLoop in this build; a symbol list prints it again if
;   the source changes.)
;
;   Sequential hits are the DEY instruction, once per loop pass.
;   Expected gap pattern (cycles between consecutive hits):
;     nine gaps of 5 (DEY + BNE taken), then one gap of 9
;     (DEY 2 + BNE not 2 + JMP 3 + LDY 2), repeating.
;   The gaps add up to the hand count: 9 x 5 + 9 = 54.
;   That is the exercise's point: the machine prints the count.
;
; This ROM has no picture — it is a counting tool; the screen stays
; black.  Its whole job is to make a loop's cost observable.
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

; =============================================================================
; THE DRILL  —  54 cycles per pass; verify with a breakpoint on DrillLoop
; =============================================================================
Drill:
    LDY #$0A                ; 2 — the loop runs ten times
DrillLoop:
    DEY                     ; 2 — breakpoint here: one hit per iteration
    BNE DrillLoop           ; 3 taken / 2 not taken
    JMP Drill               ; 3 — and around again

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
