; =============================================================================
; LESSON 04: Registers and Memory — The CPU's Workspace
; =============================================================================
; Part 1: The 6502 CPU
;
; What this program does:
;   Demonstrates the three working registers (A, X, Y) and the load/store
;   instructions that move bytes between them and RAM. We:
;     1. LOAD a color value into each register (A, X, Y) using three
;        different addressing modes (immediate, then later zero-page).
;     2. STORE each register into its own RAM byte ($80, $81, $82).
;     3. READ the values back out of RAM and paint three colored screen
;        zones — one per register — so you can SEE that the round trip
;        (register -> RAM -> register -> screen) worked.
;
;   Open the Stella debugger and watch $80/$81/$82: the three bytes you
;   stored are sitting right there, and they match the three colors on
;   screen.
;
; What you'll learn:
;   - The A (accumulator), X and Y (index) registers
;   - LDA/LDX/LDY (load) and STA/STX/STY (store)
;   - Immediate (#$xx), zero-page ($xx), and absolute ($xxxx) addressing
;
; Build: acme -f plain -o build/lesson04.bin \
;        lessons/part1-6502-cpu/04-registers-and-memory/04-registers-and-memory.asm
; Run:   stella build/lesson04.bin
;
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES  —  these live in the RIOT chip ($80-$FF)
; =============================================================================
; A "variable" on the 2600 is just a RAM address you decide to use. There is
; no `let` keyword and no allocator — you pick an address and give it a name.
; We claim three consecutive bytes, one to hold each register's value.

ColorA      = $80    ; holds the value we put in the A register (accumulator)
ColorX      = $81    ; holds the value we put in the X register (index)
ColorY      = $82    ; holds the value we put in the Y register (index)

; =============================================================================
; ROM START  —  this code lives in the cartridge ($F000-$FFFF)
; =============================================================================

    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
; On power-up the 6507 reads the RESET vector at $FFFC/$FFFD and jumps here.
Reset:
    +clean_start            ; zero all TIA registers and RAM, set the stack

; =============================================================================
; REGISTER & MEMORY DEMO  —  the heart of this lesson
; =============================================================================
; This runs ONCE at startup. It is pure 6502 CPU work: three loads, three
; stores. By the time we reach the main loop, RAM $80/$81/$82 each hold a
; color byte that we put there via a register.

    ; --- Step 1: LOAD a value into each register (immediate addressing) ---
    ; "Immediate" means the value is written right inside the instruction,
    ; after a '#'. LDA #$42 means "put the literal number $42 into A."
    LDA #$42            ; A = $42  (a red color byte)        [immediate]
    LDX #$C8            ; X = $C8  (a green color byte)       [immediate]
    LDY #$96            ; Y = $96  (a blue color byte)        [immediate]

    ; --- Step 2: STORE each register into RAM (zero-page addressing) ---
    ; "Zero page" is the fast block of memory $00-$FF. Because our RAM lives
    ; at $80-$FF, every variable we use is a zero-page address. STA writes
    ; the accumulator; STX writes X; STY writes Y.
    STA ColorA          ; RAM $80 = A = $42                   [zero-page]
    STX ColorX          ; RAM $81 = X = $C8                   [zero-page]
    STY ColorY          ; RAM $82 = Y = $96                   [zero-page]

    ; At this point the registers have done their job. The three colors now
    ; live in RAM. In the kernel below we will READ them back out — proving
    ; that data survives in memory even after the registers get reused.

; =============================================================================
; MAIN LOOP  —  one pass through here draws exactly one TV frame
; =============================================================================
StartFrame:

; --- VSYNC (3 scanlines) ---
    +vsync                  ; tell the TV "new frame starts now"

; --- VBLANK (37 scanlines) ---
    LDA #$02                ; A = VBLANK bit
    STA VBLANK              ; blank the beam during the top margin
    +set_timer 43           ; start the timer to fill the VBLANK period

    ; === GAME LOGIC ===
    ; Nothing changes frame-to-frame in this lesson — the colors are fixed.
    ; === END GAME LOGIC ===

    +wait_timer             ; wait for the timer (end of VBLANK)
    LDA #$00                ; A = 0
    STA VBLANK              ; un-blank — the visible picture starts now

; --- KERNEL (192 visible scanlines) ---
; We split the screen into three equal 64-line zones. Each zone reads ONE of
; our RAM variables back into a register and paints it as the background
; color. This is the "read it back" half of the round trip.
;
;   Zone 1 (top)    : ColorA  ($42 red)    read with LDA (zero-page)
;   Zone 2 (middle) : ColorX  ($C8 green)  read with LDX (zero-page)
;   Zone 3 (bottom) : ColorY  ($96 blue)   read with LDY (zero-page)
;
;   3 x 64 = 192 visible lines.
; #region kernel

    ; --- Zone 1: read ColorA back via the accumulator ---
    LDA ColorA          ; A = RAM $80 ($42)   — load FROM memory  [zero-page]
    STA COLUBK          ; set background color for this zone
    LDX #64             ; 64 scanlines in this zone
-   STA WSYNC           ; wait for the end of the current scanline
    DEX                 ; one fewer line to go
    BNE -               ; loop until the zone is filled

    ; --- Zone 2: read ColorX back via the X index register ---
    LDX ColorX          ; X = RAM $81 ($C8)                       [zero-page]
    STX COLUBK          ; STX can write straight to a TIA register
    LDX #64             ; reuse X as the line counter (its color is set now)
-   STA WSYNC
    DEX
    BNE -

    ; --- Zone 3: read ColorY back via the Y index register ---
    LDY ColorY          ; Y = RAM $82 ($96)                       [zero-page]
    STY COLUBK          ; STY writes Y to the background register
    LDX #64             ; X counts the lines again
-   STA WSYNC
    DEX
    BNE -

; #endregion kernel

; --- OVERSCAN (30 scanlines) ---
    LDA #$02                ; A = VBLANK bit
    STA VBLANK              ; blank the beam for the bottom margin
    +set_timer 35           ; timer fills the overscan period
    +wait_timer             ; wait it out

    JMP StartFrame          ; back to the top — one loop = one frame

; =============================================================================
; VECTORS  —  the 6507 reads these three 16-bit addresses from the top of ROM
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI    vector (unused on the 2600)
    !word Reset     ; RESET  vector — where the CPU starts on power-up
    !word Reset     ; IRQ    vector (unused on the 2600)
