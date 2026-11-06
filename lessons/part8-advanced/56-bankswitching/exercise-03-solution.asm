; =============================================================================
; LESSON 56 — EXERCISE 3 SOLUTION: The Data Bank — Racing the Beam
; =============================================================================
; Part 8: Advanced Topics
;
; EXERCISE 3: put the scene data in its own bank.  Bank 0 holds the 192-byte
;   PF2 table, the scene colours, and the 1-line kernel that draws the table.
;   Bank 1 holds the frame skeleton: the reset, VSYNC, VBLANK, the overscan,
;   and the per-frame switch into bank 0.  Bank 0 draws the visible lines and
;   switches back; bank 1 finishes the overscan.
;
;   The table is read directly in bank 0:
;
;     DataMain:
;         +wait_timer         ; bank 1 set the 37-line VBLANK timer
;         LDA #$00
;         STA VBLANK
;         LDY #0
;     DataRow:
;         LDA DataPF2,Y       ; read the table in bank 0 — no RAM copy
;         STA PF2
;         STA WSYNC
;         INY
;         CPY #192
;         BNE DataRow
;         LDA $1FF9           ; select bank 1
;         JMP $F080           ; bank 1's frame dispatcher
;
;   There is NO 192-byte copy in RIOT RAM: the kernel runs in bank 0, where
;   the table is visible, so the bytes never move.
;
; The two banks:
;   bank 0 (real $E000, !pseudopc $F000)  the data bank:
;       $F000  Bank0Reset      JMP $F060  (a reset while bank 0 is selected
;                              returns through the duplicated trampoline)
;       $F060  Bank0Switch1    LDA $1FF9 / JMP $F080
;       $F070  Bank0Switch0    LDA $1FF8 / JMP $F080
;       $F080  DataMain        colours, timer wait, the 192-line kernel
;       $F200  DataPF2         192 bytes of cave
;       $F2C0  DataColors      3 bytes: COLUBK, COLUPF, COLUP0
;   bank 1 (real $F000, !pseudopc $F000)  the frame skeleton:
;       $F000  Bank1Reset      +clean_start, Phase=0, JMP $F080
;       $F060  Bank1Switch1    LDA $1FF9 / JMP $F080
;       $F070  Bank1Switch0    LDA $1FF8 / JMP $F080
;       $F080  FrameMain       LDA Phase / BNE OverscanMain
;       $F084  StartFrame      +vsync, VBLANK, Phase=1, JMP $F070
;       $F0xx  OverscanMain    Phase=0, 30-line overscan, JMP StartFrame
;
; F8 starts in BANK 1: bank 1's reset vector at $FFFC is used at power-on.
; Bank 0's reset vector is valid for the case where the console is reset
; while the data bank is selected.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0; the data kernel draws visible 37-228; the
;   overscan starts at 229 after the switch back to bank 1.
;
; Checkpoints:
;   StartFrame (259/3), VblankStart (0/5), Frame (A = the new frame count);
;   DataMain (bank 0's kernel entry), DataRow (A = the PF2 byte read from
;   bank 0), BackToBank1 (the switch back), OverscanMain (bank 1's overscan).
;
; RAM map (+clean_start zeroes every byte):
;   $80   Phase      0 = the frame starts in bank 1, 1 = the kernel has run
;   $81   FrameCount frames since reset, wraps at 256
;   $82-$9F free (30 bytes)
;   $F8-$FF stack
;
; Build: acme -f plain -o build/exercise-03.bin \
;        lessons/part8-advanced/56-bankswitching/exercise-03-solution.asm
; Run:   stella build/exercise-03.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 35      ; 30-line overscan; the switch back from bank 0
                         ; costs 15 cycles, so the timer is one tick shorter
                         ; than the base lesson's 36 (see the note below)
SCREEN_LINES   = 192

; =============================================================================
; THE FIXED DATA ADDRESSES (bank 0)
; =============================================================================
DataPF2    = $F200       ; 192 bytes, one PF2 byte per visible line
DataColors = $F2C0       ; 3 bytes: COLUBK, COLUPF, COLUP0

; =============================================================================
; RAM ALLOCATION ($80-$81)
; =============================================================================
Phase      = $80    ; 0 = start in bank 1, 1 = the kernel has run
FrameCount = $81    ; frames since reset, wraps at 256
;
; $82-$9F are free (30 bytes).  The stack is $F8-$FF.

; =============================================================================
; BANK 0 — real $E000, virtual $F000.  THE DATA BANK.
; =============================================================================
    * = $E000
    !pseudopc $F000 {

; -----------------------------------------------------------------------------
; Bank0Reset — a reset while the data bank is selected returns to bank 1
; -----------------------------------------------------------------------------
; Bank 0 is only selected during the visible kernel.  If the console's RESET
; switch is pressed then, the vector sends the CPU here.  A direct
; LDA $1FF9 / JMP $F000 would be unsafe: the JMP opcode would be fetched from
; bank 1 at an address where bank 1 has different bytes.  The duplicated
; trampoline at $F060 is safe, so the stub jumps there and lets it select
; bank 1 and continue at $F080.
Bank0Reset:
    JMP $F060               ; the duplicated switch-to-bank-1 trampoline

    !if * > $F060 {
        !error "bank 0's reset must fit before $F060"
    }
    !fill $F060 - *, $EA

; -----------------------------------------------------------------------------
; The duplicated trampolines
; -----------------------------------------------------------------------------
Bank0Switch1:
    LDA $1FF9               ; select bank 1
    JMP $F080               ; bank 1's frame dispatcher
    !fill $F070 - *, $EA
Bank0Switch0:
    LDA $1FF8               ; select bank 0
    JMP $F080               ; bank 0's data kernel
    !fill $F080 - *, $EA

; -----------------------------------------------------------------------------
; DataMain — the data bank's visible kernel ($F080)
; -----------------------------------------------------------------------------
; Bank 1 has already set the 37-line VBLANK timer and stayed in VBLANK.  This
; code sets the scene colours, waits for the timer, turns the picture on, and
; draws the 192 rows from DataPF2.  The table is read directly: no RAM copy.
DataMain:
    LDA DataColors+0
    STA COLUBK
    LDA DataColors+1
    STA COLUPF
    LDA DataColors+2
    STA COLUP0

    +wait_timer
    LDA #$00
    STA VBLANK

    LDY #0
DataRow:                    ; checkpoint: A = the PF2 byte read from bank 0
    LDA DataPF2,Y
    STA PF2
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE DataRow

; The last WSYNC releases the CPU on scanline 229.  Switch back to bank 1 so
; its dispatcher can run the overscan and start the next frame.  The direct
; LDA $1FF9 / JMP $F080 form would fetch the JMP from bank 1 at an address
; where bank 1 has different bytes, so the switch goes through the duplicated
; trampoline at $F060 instead.
BackToBank1:
    JMP $F060               ; the duplicated switch-to-bank-1 trampoline

; -----------------------------------------------------------------------------
; Bank 0's data
; -----------------------------------------------------------------------------
    !if * > DataPF2 {
        !error "bank 0's code must end before $F200"
    }
    !fill DataPF2 - *, $EA

    !fill 8,  $00           ; the first eight rows stay blank
    !fill 8,  $FF           ; visible 8-15:  the ceiling
    !fill 16, $F0
    !fill 32, $E0
    !fill 32, $70
    !fill 32, $38
    !fill 32, $1C
    !fill 24, $0E
    !fill 8,  $FF           ; visible 184-191: the floor

    !fill DataColors - *, $EA
    !byte $28, $44, $1A     ; orange background, red rock, gold marker

    !fill $FFFA - *, $EA
    * = $FFFA
    !word Bank0Reset, Bank0Reset, Bank0Reset
}

; =============================================================================
; BANK 1 — real $F000, virtual $F000.  THE FRAME SKELETON.
; =============================================================================
    * = $F000
    !pseudopc $F000 {

; -----------------------------------------------------------------------------
; Bank1Reset — the power-on entry (F8 starts in bank 1)
; -----------------------------------------------------------------------------
Bank1Reset:
    +clean_start
    LDA #$00
    STA SWACNT
    STA Phase
    STA FrameCount
    LDA #$01
    STA CTRLPF
    JMP $F080

    !if * > $F060 {
        !error "bank 1's reset must fit before $F060"
    }
    !fill $F060 - *, $EA

; -----------------------------------------------------------------------------
; The duplicated trampolines
; -----------------------------------------------------------------------------
Bank1Switch1:
    LDA $1FF9               ; select bank 1
    JMP $F080
    !fill $F070 - *, $EA
Bank1Switch0:
    LDA $1FF8               ; select bank 0
    JMP $F080
    !fill $F080 - *, $EA

; -----------------------------------------------------------------------------
; FrameMain — the dispatcher ($F080)
; -----------------------------------------------------------------------------
; Entry 0 (power-on or a new frame): Phase=0, so run VSYNC and VBLANK.
; Entry 1 (the return from the data bank): Phase=1, so run the overscan.
FrameMain:
    LDA Phase
    BNE OverscanMain

; -----------------------------------------------------------------------------
; StartFrame / VblankStart — the frame's first 37 lines
; -----------------------------------------------------------------------------
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    INC FrameCount
    LDA FrameCount
Frame:                      ; checkpoint: A = the new frame count

    LDA #$01
    STA Phase               ; the return from bank 0 goes to the overscan
    JMP $F070               ; select bank 0 and draw the data scene

; -----------------------------------------------------------------------------
; OverscanMain — bank 1's tail of the frame
; -----------------------------------------------------------------------------
; The data bank's last WSYNC released the CPU on scanline 229.  The switch
; back to bank 1 runs these few cycles, then the 30-line overscan.  Phase is
; cleared so the next frame starts at StartFrame.
;
; The switch costs 15 cycles (JMP $F060, the trampoline's LDA/JMP, the
; dispatcher's LDA/BNE), so OverscanMain starts at 229/21 instead of 229/6.
; A 36-tick timer would expire at 259/0 and the final WSYNC would wait until
; 260, making the frame 263 lines; the 35-tick timer expires before the final WSYNC, the
; WSYNC lands on 259/0, and StartFrame stays at 259/3.
OverscanMain:
    LDA #$00
    STA Phase
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

    !fill $FFFA - *, $EA
    * = $FFFA
    !word Bank1Reset, Bank1Reset, Bank1Reset
}
