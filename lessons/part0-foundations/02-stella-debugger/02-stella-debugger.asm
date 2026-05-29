; =============================================================================
; LESSON 02: Meet Stella — Your Debugger and Best Friend
; =============================================================================
; Part 0: Foundations
;
; What this program does:
;   This is a "landmark" ROM — its whole purpose is to give you recognizable
;   values to hunt for inside the Stella debugger. It stores a set of easy-to-
;   spot hex bytes in specific RAM addresses, keeps a running frame counter,
;   and hides one secret value at a higher address for you to find.
;
;   On screen it draws three colored bands so there is visible output and an
;   obvious place to set a breakpoint. The real action, though, happens in the
;   debugger: you will pause the program, read these RAM bytes, watch the
;   registers change, and step through the frame loop one instruction at a time.
;
; What you'll learn (by inspecting this ROM in the debugger):
;   - How to read RAM ($80-$FF) and find known "landmark" values
;   - How to watch the A/X/Y/SP/PC registers change as code runs
;   - How to set breakpoints and step / scanline-advance / frame-advance
;   - How to count the scanlines that make up a single NTSC frame
;
; RAM landmark map (what you should find in the debugger):
;   $80 = $DE   ; "DEAD" landmark byte 1
;   $81 = $AD   ; "DEAD" landmark byte 2
;   $82 = $BE   ; "BEEF" landmark byte 1
;   $83 = $EF   ; "BEEF" landmark byte 2
;   $84        ; FrameCounter — increments once per frame (watch it climb!)
;   $A5 = $42   ; SecretValue — the "hidden" byte (Exercise 2)
;
; Build: acme -f plain -o build/lesson02.bin lessons/part0-foundations/02-stella-debugger/02-stella-debugger.asm
; Run:   stella build/lesson02.bin
;
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES
; =============================================================================
; We deliberately place memorable values at low, easy-to-find addresses so
; that when you open the debugger's RAM view, the bytes jump out at you.
; "DEAD" and "BEEF" are classic programmer landmark values precisely because
; they are valid hex AND spell something — impossible to miss in a hex dump.

DeadHi          = $80    ; Will hold $DE  — first half of "DEAD"
DeadLo          = $81    ; Will hold $AD  — second half of "DEAD"
BeefHi          = $82    ; Will hold $BE  — first half of "BEEF"
BeefLo          = $83    ; Will hold $EF  — second half of "BEEF"
FrameCounter    = $84    ; Increments once per frame — your "is it running?" proof

; The secret value lives higher up in RAM, away from the landmarks above, so
; that finding it in Exercise 2 takes a little hunting through the RAM view.
SecretValue     = $A5    ; Will hold $42  — the "hidden" byte to discover

; =============================================================================
; ROM START
; =============================================================================

    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start         ; Zero all RAM/TIA, set up stack (see include/macro.asm)

    ; --- Plant the landmark values in RAM ---
    ; Set a breakpoint on the first STA below (Exercise 1) and step through
    ; these instructions one at a time. Watch the A register load each value,
    ; then watch the matching RAM address change in the debugger's RAM view.

    LDA #$DE             ; A = $DE  (first "DEAD" byte)
    STA DeadHi           ; $80 = $DE

    LDA #$AD             ; A = $AD  (second "DEAD" byte)
    STA DeadLo           ; $81 = $AD

    LDA #$BE             ; A = $BE  (first "BEEF" byte)
    STA BeefHi           ; $82 = $BE

    LDA #$EF             ; A = $EF  (second "BEEF" byte)
    STA BeefLo           ; $83 = $EF

    ; --- Plant the hidden value ---
    LDA #$42             ; A = $42  (the secret — ASCII 'B', the answer to a lot)
    STA SecretValue      ; $A5 = $42

; =============================================================================
; MAIN LOOP
; =============================================================================
; Every iteration of this loop draws exactly one NTSC frame. The FrameCounter
; increments once per pass, so in the debugger you can prove the loop is alive
; by watching $84 tick upward — and you can use "frame advance" to step one
; whole frame at a time.

StartFrame:

; --- VSYNC (3 scanlines) ---
    +vsync               ; Tell the TV "new frame" (3 scanlines)

; --- VBLANK (37 scanlines) ---
    LDA #$02
    STA VBLANK           ; Blank the screen during the top margin
    +set_timer 43        ; Start RIOT timer to fill the VBLANK period

    ; === GAME LOGIC ===
    ; Increment our frame counter. This single instruction is the easiest way
    ; to confirm in the debugger that the program is running: pause, note $84,
    ; frame-advance once, and watch it go up by exactly 1.
    INC FrameCounter     ; $84 = $84 + 1
    ; === END GAME LOGIC ===

    +wait_timer          ; Wait out the rest of VBLANK
    LDA #$00
    STA VBLANK           ; Turn the screen back on

; --- KERNEL (192 visible scanlines) ---
; Three equal color bands (64 scanlines each). This gives us visible output
; and three natural "zones" where you can set breakpoints to see exactly where
; the beam is when the debugger pauses.
; #region kernel

    ; --- Band 1: red (64 lines) ---
    LDA #$44             ; $44 = red, medium luminance
    STA COLUBK
    LDX #64              ; 64 scanlines in this band
-   STA WSYNC            ; Wait one scanline
    DEX
    BNE -

    ; --- Band 2: green (64 lines) ---
    LDA #$C4             ; $C4 = green, medium luminance
    STA COLUBK
    LDX #64
-   STA WSYNC
    DEX
    BNE -

    ; --- Band 3: blue (64 lines) ---
    LDA #$94             ; $94 = blue, medium luminance
    STA COLUBK
    LDX #64
-   STA WSYNC
    DEX
    BNE -

; #endregion kernel

; --- OVERSCAN (30 scanlines) ---
    LDA #$02
    STA VBLANK           ; Blank the screen during the bottom margin
    +set_timer 35        ; Start RIOT timer to fill the overscan period

    +wait_timer          ; Wait out the rest of overscan

    JMP StartFrame       ; Round and round — one pass = one frame

; =============================================================================
; VECTORS
; =============================================================================

    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
