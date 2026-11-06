; =============================================================================
; LESSON 57 — EXERCISE 3 SOLUTION: Persistence Across a Bank Switch — Racing the Beam
; =============================================================================
; Part 8: Advanced Topics
;
; EXERCISE 3: write a value in bank 1, switch to bank 0, read it back, and
;   show that the Superchip RAM persists.
;
;   Bank 1 owns the write: its init zeroes the 128 bytes, writes $A5 to
;   $1000, and runs 64 frames with a blue background.  It then switches to
;   bank 0 through the $F200 stub.  Bank 0 never writes the value it checks:
;   it reads $1080, compares the byte with $A5, and sets the background green
;   when the byte survived the bank switch (red when it did not).  Bank 0
;   then stays in bank 0; there is no switch back.  The value is read once,
;   after the switch, which is the whole proof.
;
;   The point is the address: $1000/$1080 are the cartridge's 128-byte RAM,
;   not a bank's ROM.  The mapper changes which 4K ROM bank is visible; it
;   does not touch the RAM.  Bank 0 therefore reads the byte bank 1 wrote.
;
;   The one-way switch also keeps the frame exact.  Bank 0's main starts with
;   +vsync at $F206, before the read and the colour setup, so the VSYNC is
;   asserted immediately on the switch frame.  There is no bank-1 re-entry,
;   so there is no +clean_start and no 128-byte zero loop between the switch
;   and the next VSYNC.  The switch frame stays 262 lines, and the steady
;   frames are StartFrame 259/3, VblankStart 0/5, BodyStart 37/5,
;   OverscanStart 229/6.  The read and the colour setup then run in VBLANK
;   on every bank-0 frame, so the green page is re-confirmed each frame.
;
; The two banks (the flat file is bank 0 then bank 1):
;   bank 0: real $E000, !pseudopc $F000
;   bank 1: real $F000
;   Each bank's first 256 bytes are the F8SC signature (128 bytes twice).
;   The shared stubs, byte-identical in both banks:
;       $F100  LDA $1FF9 / JMP $F106   select bank 1, run bank 1's main
;       $F200  LDA $1FF8 / JMP $F206   select bank 0, run bank 0's main
;   $F200 is used instead of $F110 because bank 1's main at $F106 needs the
;   space; the first 256 bytes are the RAM window and cannot hold a stub.
;   Both banks' vectors at $FFFA-$FFFF point to $F100, so a console reset in
;   bank 0 selects bank 1 and runs its init.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   Bank 1 switches to bank 0 in the blanked overscan after 64 frames.
;
; Checkpoints:
;   B1StartFrame/B1VblankStart/B1BodyStart/B1OverscanStart;
;   B1Write (A = $A5, the byte written in bank 1);
;   B1Read (A = the byte read back in bank 1);
;   B0Read (A = $A5, the byte read in bank 0);
;   B0Color (A = $C8 green when the byte matched, $44 red when it did not);
;   B0StartFrame/B0VblankStart/B0BodyStart/B0OverscanStart.
;   Bank 0's first B0StartFrame is the switch frame (a few cycles after
;   259/0); the following frames are 259/3.  B0VblankStart is 0/5 on every
;   frame, including the switch frame.
;
; RAM map (RIOT):
;   $80 B1Frame    bank 1's 64-frame counter
;   $82 SwitchFlag 1 = switch at the end of this frame
;   $F8-$FF stack
;
; Build: acme -f plain -o build/exercise-03.bin \
;        lessons/part8-advanced/57-superchip/exercise-03-solution.asm
; Run:   stella build/exercise-03.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan
SCREEN_LINES   = 192

C_BLUE         = $84     ; bank 1's page
C_GREEN        = $C8     ; bank 0's page when the byte matches
C_RED          = $44     ; bank 0's page when it does not

VALUE          = $A5     ; the byte bank 1 writes and bank 0 must find
PERIOD         = 64      ; frames bank 1 shows before the switch

; =============================================================================
; RAM
; =============================================================================
B1Frame     = $80
SwitchFlag  = $82

; =============================================================================
; BANK 0 — real $E000, virtual $F000.  THE READER.
; =============================================================================
    * = $E000
    !pseudopc $F000 {
    !fill 128, $EA
    !fill 128, $EA

; --- the shared stubs ---------------------------------------------------------
; $F100 selects bank 1; $F200 selects bank 0.  Both are byte-identical in the
; two banks, so the JMP that follows a select is safe whichever bank runs it.
    * = $F100
Stub1:
    LDA $1FF9               ; select bank 1
    JMP $F106
    !fill $F200 - *, $EA    ; bank 0's $F106-$F1FF is unused
Stub0:
    LDA $1FF8               ; select bank 0
    JMP $F206

; --- bank 0's main at $F206 ---------------------------------------------------
; The first instruction is the +vsync's LDA, so the switch frame asserts VSYNC
; immediately.  Bank 0 never leaves this bank; the read and the colour setup
; run in VBLANK on every frame, and the frame loop follows.
    * = $F206
B0StartFrame:               ; checkpoint: bank 0's first VSYNC line
    +vsync
B0VblankStart:              ; checkpoint: 0/5, including the switch frame
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- read the byte bank 1 wrote ----------------------------------------------
; $1080 is the read window.  No write to $1000 happens in this bank: the
; value can only be the one bank 1 left in the cartridge RAM.
    LDX #0
    LDA $1080,X
B0Read:                     ; checkpoint: A = the byte read in bank 0
    CMP #VALUE
    BNE B0Bad
    LDA #C_GREEN
    JMP B0Color
B0Bad:
    LDA #C_RED
B0Color:                    ; checkpoint: A = $C8 or $44
    STA COLUBK
    LDA #$00
    STA COLUPF
    STA COLUP0
    STA CTRLPF
    STA GRP0
    STA PF0
    STA PF1
    STA PF2

    +wait_timer
    LDA #$00
    STA VBLANK
B0BodyStart:                ; checkpoint: bank 0's first visible line (37/5)
    LDY #0
B0Row:
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE B0Row
B0OverscanStart:            ; checkpoint: bank 0's first overscan line (229/6)
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP B0StartFrame

    !fill $FFFA - *, $EA
    * = $FFFA
    !word Stub1, Stub1, Stub1
}

; =============================================================================
; BANK 1 — real $F000, virtual $F000.  THE WRITER.
; =============================================================================
    * = $F000
    !pseudopc $F000 {
    !fill 128, $EA
    !fill 128, $EA

; --- the shared stubs ---------------------------------------------------------
    * = $F100
Entry:
    LDA $1FF9               ; select bank 1
    JMP $F106

; --- bank 1's main at $F106 ---------------------------------------------------
    * = $F106
B1Main:
    +clean_start
    LDA #$00
    STA SWACNT

; --- zero the RAM explicitly, then write the value ---------------------------
    LDX #0
    LDA #$00
B1Zero:
    STA $1000,X             ; the write window
    INX
    CPX #128
    BNE B1Zero
    LDA #VALUE
    LDX #0
    STA $1000,X             ; write byte 0
B1Write:                    ; checkpoint: A = $A5, X = 0
    LDA $1080,X
B1Read:                     ; checkpoint: A = $A5, read back in bank 1

; --- the page stays blue while bank 1 is visible -----------------------------
    LDA #C_BLUE
    STA COLUBK
    LDA #$00
    STA COLUPF
    STA COLUP0
    STA CTRLPF
    STA GRP0
    STA PF0
    STA PF1
    STA PF2
    STA B1Frame
    STA SwitchFlag

; --- the frame loop: 64 frames, then the one-way switch ----------------------
B1StartFrame:               ; checkpoint: bank 1's first VSYNC line
    +vsync
B1VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    INC B1Frame
    LDA B1Frame
    AND #(PERIOD-1)
    BNE B1NoSwitch
    LDA #$01
    STA SwitchFlag
B1NoSwitch:
    +wait_timer
    LDA #$00
    STA VBLANK
B1BodyStart:                ; checkpoint: bank 1's first visible line
    LDY #0
B1Row:
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE B1Row
B1OverscanStart:            ; checkpoint: bank 1's first overscan line
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    LDA SwitchFlag
    BNE B1Switch
    +wait_timer
    JMP B1StartFrame
B1Switch:
    +wait_timer
    LDA #$00
    STA SwitchFlag
    JMP $F200               ; select bank 0; bank 0 asserts VSYNC and stays

    !if * > $F200 {
        !error "bank 1's main must end before the $F200 stub"
    }
    !fill $F200 - *, $EA
Bank0Stub:
    LDA $1FF8               ; select bank 0
    JMP $F206

    !fill $FFFA - *, $EA
    * = $FFFA
    !word Entry, Entry, Entry
}
