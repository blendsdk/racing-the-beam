; =============================================================================
; LESSON 56 — EXERCISE 1 SOLUTION: Swap the Scenes — Racing the Beam
; =============================================================================
; Part 8: Advanced Topics
;
; EXERCISE 1: swap the scenes.  Bank 1 (the start bank) now draws the cave and
;   bank 0 now draws the forest.  Only the two data blocks at $F200-$F2C3 are
;   swapped; the code, the trampolines, the player strip and the vectors are
;   unchanged.  The indicator follows the bank number, so bank 1 still lights
;   the left cell and bank 0 the right cell.
;
; The Cave*/Forest* labels stay with their banks: they are bank-local names
;   inherited from the base source, and this exercise changes the data, not
;   the bank layout.
;
; What this program does:
;   "the two worlds": an 8,192-byte F8 cartridge.  The 6507 sees one 4K
;   window at $F000-$FFFF; the F8 mapper hides two 4K banks behind it.  This
;   exercise swaps the scenes: bank 1 (the start bank) draws the red cave on
;   an orange background; bank 0 draws the green forest on a blue sky.  An
;   auto-demo switches every 120 frames and fire switches immediately.  A
;   two-cell indicator in the first eight lines still shows which bank is
;   selected (the indicator follows the bank number, not the scene).
;
; The F8 layout (the flat file is bank 0 then bank 1):
;   file offset $0000-$0FFF   bank 0, real $E000, assembled with !pseudopc $F000
;   file offset $1000-$1FFF   bank 1, real $F000
;
; F8 starts in BANK 1.  At power-on the CPU reads the reset vector from bank
; 1's $FFFC, so bank 1's ForestReset is the first instruction that runs.
; Bank 0's code never runs at power-on; it is reached by the switch.
;
; The switch-and-jump trampolines, byte-identical in both banks:
;   $F060  Switch1  LDA $1FF9   select bank 1   JMP $F080
;   $F070  Switch0  LDA $1FF8   select bank 0   JMP $F080
; The hotspot read changes the bank; the JMP that follows is fetched from the
; new bank.  Its bytes and its target therefore have to be valid in both banks,
; which is why the two stubs sit at the same fixed addresses in both banks.
;
; Each bank's virtual layout ($F000-$FFFF):
;   $F000   the bank's reset (this source ends it before $F060)
;   $F060   Switch1
;   $F070   Switch0
;   $F080   the bank's main: LDA SceneInit / BankEntry / NOP / StartFrame
;   $F200   ScenePF2    192 bytes: one PF2 byte per visible line
;   $F2C0   SceneColors  3 bytes: COLUBK, COLUPF, COLUP0
;   $F2C3   SceneInit    1 byte: the bank number (1 in bank 1, 0 in bank 0)
;   $F300   ScenePlayer 192 bytes: an 8-line diamond at visible rows 96-103
;   $FFFA   the vectors: Reset, Reset, Reset
;
; The two banks carry the same code at the same virtual addresses.  The only
; difference is the data block at $F200-$F2C3 (the player strip at $F300 is the
; same in both banks), so the switch changes the world without changing the
; program.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;
; The 1-line kernel: 31 cycles on a scene row (LDA 4 + CPY 2 + BCS 4 + STA 3 +
; LDA 4 + STA 3 + WSYNC 3 + INY 2 + CPY 2 + BNE 4; the taken branches cross
; pages); a bank-1 indicator row is 40 and a bank-0 row is 37.  The 76-cycle
; line leaves at least 36 cycles.
;
; Checkpoints (Stella scanline numbers in parentheses; the bank 0 copies sit at
; the same virtual addresses):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   OverscanStart (229/6); Frame (A = the new frame count);
;   BankEntry (A = 1 at power-on, A = 0 after the switch to bank 0);
;   BankWrite (A = the new bank: 0 or 1); SwitchRead1/SwitchRead0 (the
;   hotspot reads at $F060/$F070; the log's bank field is the old bank).
;
; RAM map (+clean_start zeroes every byte):
;   $80   Bank        the selected bank: 1 at power-on, 0 after the switch
;   $81   BankTimer   frames left before the auto-demo switches (120)
;   $82   FrameCount  frames since reset, wraps at 256
;   $83   SwitchFlag  1 = switch at the end of this frame, 0 = stay
;   $84   PrevFire    fire state last frame (1 = pressed)
;   $85   NewFire     this frame's fire 0 -> 1 edge
;   $86   Startup     frames left before the fire line is trusted
;   $87-$9F free (25 bytes)
;   $F8-$FF stack
;
; Build: acme -f plain -o build/exercise-01.bin \
;        lessons/part8-advanced/56-bankswitching/exercise-01-solution.asm
; Run:   stella build/exercise-01.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan
POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

SCREEN_LINES   = 192     ; the 1-line kernel draws every visible line
INDICATOR_ROWS = 8       ; the two-cell indicator occupies the first 8 lines
DEMO_PERIOD    = 120     ; frames between auto-demo switches (about 2 seconds)
PLAYER_X       = 72      ; the diamond's left edge, TIA X 72..79
PLAYER_TOP     = 96      ; the diamond's first visible row

INDICATOR_1    = $03     ; bank 1: PF2 bits 0-1, pixels 48-55 (the left cell)
INDICATOR_0    = $30     ; bank 0: PF2 bits 4-5, pixels 64-71 (the right cell)

C_FOREST_BG    = $84     ; bank 1 background: blue
C_FOREST_PF    = $C8     ; bank 1 playfield: green
C_FOREST_P0    = $0E     ; bank 1 marker: white
C_CAVE_BG      = $28     ; bank 0 background: orange
C_CAVE_PF      = $44     ; bank 0 playfield: red
C_CAVE_P0      = $1A     ; bank 0 marker: gold

; =============================================================================
; THE FIXED DATA ADDRESSES — the same in both banks
; =============================================================================
; The code uses these absolute addresses, not per-bank labels, so both banks
; assemble the same instructions.  The bytes behind them differ per bank.
ScenePF2    = $F200      ; 192 bytes, one PF2 byte per visible line
SceneColors = $F2C0      ; 3 bytes: COLUBK, COLUPF, COLUP0
SceneInit   = $F2C3      ; 1 byte: the bank number
ScenePlayer = $F300      ; 192 bytes, one GRP0 byte per visible line

; =============================================================================
; RAM ALLOCATION ($80-$86; +clean_start zeroes every byte)
; =============================================================================
Bank        = $80    ; the selected bank: 1 at power-on, 0 after the switch
BankTimer   = $81    ; frames left before the auto-demo switches
FrameCount  = $82    ; frames since reset, wraps at 256 (the Frame checkpoint)
SwitchFlag  = $83    ; 1 = switch at the end of this frame
PrevFire    = $84    ; fire state last frame (1 = pressed)
NewFire     = $85    ; this frame's fire 0 -> 1 edge
Startup     = $86    ; frames left before the fire line is trusted
;
; $87-$9F are free (25 bytes).  The stack lives at $F8-$FF; the call depth
; stays at one level (SetCoarseP0).

; =============================================================================
; BANK 0 — real $E000, virtual $F000.  THE FOREST (exercise 1).
; =============================================================================
; The flat ROM starts here.  !pseudopc assembles the code as if it sat at
; $F000, while the bytes go to the real $E000-$EFFF.  A label defined here
; has the same address as its twin in bank 1, which is exactly what the
; trampolines need.
    * = $E000
    !pseudopc $F000 {

; -----------------------------------------------------------------------------
; CaveReset — bank 0's entry (not used at power-on; the F8 mapper starts in
; bank 1, and this vector only runs if the console is reset while bank 0 is
; selected)
; -----------------------------------------------------------------------------
CaveReset:
    +clean_start            ; zero TIA and RAM, set the stack to $FF
    LDA #$00
    STA SWACNT              ; port A is an input port (the joystick)

    LDA SceneInit           ; bank 0's own data: $00
    STA Bank
    LDA #DEMO_PERIOD
    STA BankTimer
    LDA #$00
    STA FrameCount
    LDA #$08
    STA Startup             ; ignore fire while the console settles

; --- bank 0's palette: the exercise's forest ---------------------------------
    LDA SceneColors+0
    STA COLUBK              ; blue background
    LDA SceneColors+1
    STA COLUPF              ; green trees
    LDA SceneColors+2
    STA COLUP0              ; white marker
    LDA #$01
    STA CTRLPF              ; reflect the playfield: the right half mirrors

    JMP CaveMain            ; $F080 is the same address in both banks

; The reset must end before the fixed trampoline at $F060.  The !if turns
; that rule into a build failure instead of a silent overlap.
    !if * > $F060 {
        !error "bank 0's reset must fit before $F060"
    }
    !fill $F060 - *, $EA

; -----------------------------------------------------------------------------
; The fixed trampolines — THE SAME SIX BYTES AS BANK 1
; -----------------------------------------------------------------------------
; A read from $1FF9 selects bank 1.  The JMP that follows is fetched from the
; new bank at $F063, so the bytes at $F060-$F065 must be identical in both
; banks; they are.  The target $F080 is also the same in both banks.
CaveSwitch1:
    LDA $1FF9               ; select bank 1 (the hotspot read)
    JMP $F080               ; continue in bank 1's main
    !fill $F070 - *, $EA

CaveSwitch0:
    LDA $1FF8               ; select bank 0 (the hotspot read)
    JMP $F080               ; continue in bank 0's main
    !fill $F080 - *, $EA

; -----------------------------------------------------------------------------
; CaveMain — the bank's main ($F080)
; -----------------------------------------------------------------------------
; The reset and the trampoline both land here.  The LDA is three cycles and
; sets A to the bank number, so BankEntry reports A=0 in this bank.  The NOP
; keeps BankEntry and StartFrame as separate breakpoints; the frame loop
; jumps straight to StartFrame, so only a real bank entry runs the LDA/NOP.
CaveMain:
    LDA SceneInit           ; A = 0 (bank 0)
CaveBankEntry:
    NOP
CaveStartFrame:
    +vsync                  ; 3 VSYNC lines: 259, 260, 261

CaveVblankStart:
    LDA #$02
    STA VBLANK              ; blank the picture
    +set_timer VBLANK_TIMER

; --- the palette is read every frame, so a switch changes the world ----------
    LDA SceneColors+0
    STA COLUBK
    LDA SceneColors+1
    STA COLUPF
    LDA SceneColors+2
    STA COLUP0

; --- the frame counter -------------------------------------------------------
    INC FrameCount
    LDA FrameCount
CaveFrame:                  ; checkpoint: A = the new frame count

; --- fire: a new press asks for a switch at the end of this frame ------------
; INPT4 bit 7 is 0 while fire is held.  EOR turns that into a 1, and the
; EOR/AND pair keeps only the 0 -> 1 edge, so holding the button switches
; once.  The first eight frames are ignored: INPT4 can read low while the
; console settles.
    LDA INPT4
    AND #$80
    EOR #$80                ; 1 = pressed
    STA NewFire
    EOR PrevFire
    AND NewFire
    STA NewFire             ; NewFire = pressed & ~wasPressed
    LDA Startup
    BEQ CaveFireReady
    DEC Startup
    LDA #$00
    STA NewFire
CaveFireReady:
    LDA NewFire
    BEQ CaveNoFire
    LDA #$01
    STA SwitchFlag
CaveNoFire:
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire

; --- the auto-demo: one switch every 120 frames ------------------------------
    DEC BankTimer
    BNE CaveTimerDone
    LDA #DEMO_PERIOD
    STA BankTimer
    LDA #$01
    STA SwitchFlag
CaveTimerDone:

; --- position P0: one divide-by-15 dance and one HMOVE -----------------------
; SetCoarseP0 sets HMP0 and strobes RESP0.  The WSYNC starts a fresh line and
; the HMOVE applies the fine offset in its HBLANK.  This is the frame's only
; HMOVE, and it falls inside VBLANK, so its left-edge blanking is unseen.
    LDA #(PLAYER_X + POS_BIAS)
    JSR CaveSetCoarseP0
    STA WSYNC
    STA HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; -----------------------------------------------------------------------------
; The visible kernel — 192 lines, one PF2 byte and one GRP0 byte per line
; -----------------------------------------------------------------------------
; The first eight rows show the two-cell bank indicator instead of the scene.
; Bank 0 lights the right cell ($30); the playfield is reflected, so the cell
; and its mirror both appear.  The table's own first eight bytes are blank.
CaveBodyStart:              ; checkpoint: scanline 37, visible line 0
    LDY #0
CaveKernelRow:
    LDA ScenePF2,Y
    CPY #INDICATOR_ROWS
    BCS CaveNoIndicator
    LDA Bank
    BEQ CaveCell0
    LDA #INDICATOR_1
    BNE CaveCellDone
CaveCell0:
    LDA #INDICATOR_0
CaveCellDone:
CaveNoIndicator:
    STA PF2
    LDA ScenePlayer,Y
    STA GRP0
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE CaveKernelRow

; -----------------------------------------------------------------------------
; Overscan — 30 lines, then either the next frame or the switch
; -----------------------------------------------------------------------------
; The switch decision was made in VBLANK.  The branch happens before the final
; timer wait, so the normal path still reaches StartFrame at 259/3; the switch
; path spends the trampoline's cycles on scanline 259 and the +vsync macro's
; three WSYNCs absorb them before VblankStart.
CaveOverscanStart:          ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    LDA SwitchFlag
    BNE CaveSwitchOverscan
    +wait_timer
    JMP CaveStartFrame
CaveSwitchOverscan:
    +wait_timer
    LDA #$00
    STA SwitchFlag
    LDA Bank
    EOR #$01                ; 0 -> 1, 1 -> 0
CaveBankWrite:              ; checkpoint: A = the new bank
    STA Bank
    LDA #DEMO_PERIOD        ; the new bank gets a full demo window
    STA BankTimer
    LDA Bank
    BNE CaveSwitchOne
    JMP $F070               ; select bank 0 and continue at $F080
CaveSwitchOne:
    JMP $F060               ; select bank 1 and continue at $F080

; -----------------------------------------------------------------------------
; CaveSetCoarseP0 — the Lesson 26 divide-by-15 positioning dance
; -----------------------------------------------------------------------------
; A = the desired left edge + POS_BIAS.  Each loop pass is 5 cycles = 15
; colour clocks, which is why dividing by 15 works.  The remainder becomes
; HMP0's fine value and RESP0 strobes the coarse position.
CaveSetCoarseP0:
    STA WSYNC
    SEC
CaveDivP0:
    SBC #15
    BCS CaveDivP0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    RTS

; -----------------------------------------------------------------------------
; Bank 0's data — the exercise's forest
; -----------------------------------------------------------------------------
    !if * > ScenePF2 {
        !error "bank 0's code must end before $F200"
    }
    !fill ScenePF2 - *, $EA

; The first eight bytes are blank: the kernel replaces them with the indicator.
; The table begins at ScenePF2 ($F200); the constant is the address, so the
; data needs no label of its own.
    !fill INDICATOR_ROWS, $00
    !fill 24, $FF           ; visible 8-31:  the canopy
    !fill 32, $C3           ; visible 32-63: wide trunks
    !fill 32, $81           ; visible 64-95: thin trunks
    !fill 32, $C3
    !fill 32, $81
    !fill 32, $C3

    !fill SceneColors - *, $EA
    !byte C_FOREST_BG, C_FOREST_PF, C_FOREST_P0
    !byte $00               ; SceneInit: bank 0

    !fill ScenePlayer - *, $EA
    !fill PLAYER_TOP, $00
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !fill SCREEN_LINES - PLAYER_TOP - 8, $00

    !fill $FFFA - *, $EA
    * = $FFFA
    !word CaveReset, CaveReset, CaveReset
}

; =============================================================================
; BANK 1 — real $F000, virtual $F000.  THE CAVE (exercise 1).
; =============================================================================
; This is the start bank: the F8 mapper selects it at power-on, so its reset
; vector at $FFFC is the one the CPU uses.  The code below is the same program
; as bank 0; only the data at $F200-$F2C3 differs (the player strip at $F300
; is the same).
    * = $F000
    !pseudopc $F000 {

; -----------------------------------------------------------------------------
; ForestReset — bank 1's entry (the power-on entry)
; -----------------------------------------------------------------------------
ForestReset:
    +clean_start
    LDA #$00
    STA SWACNT

    LDA SceneInit           ; bank 1's own data: $01
    STA Bank
    LDA #DEMO_PERIOD
    STA BankTimer
    LDA #$00
    STA FrameCount
    LDA #$08
    STA Startup

; --- bank 1's palette: the exercise's cave ---------------------------------
    LDA SceneColors+0
    STA COLUBK              ; orange background
    LDA SceneColors+1
    STA COLUPF              ; red rock
    LDA SceneColors+2
    STA COLUP0              ; gold marker
    LDA #$01
    STA CTRLPF              ; reflect the playfield

    JMP ForestMain

    !if * > $F060 {
        !error "bank 1's reset must fit before $F060"
    }
    !fill $F060 - *, $EA

; -----------------------------------------------------------------------------
; The fixed trampolines — THE SAME SIX BYTES AS BANK 0
; -----------------------------------------------------------------------------
Switch1:
SwitchRead1:                ; checkpoint: the bank-1 hotspot read ($F060)
    LDA $1FF9               ; select bank 1
    JMP $F080
    !fill $F070 - *, $EA

Switch0:
SwitchRead0:                ; checkpoint: the bank-0 hotspot read ($F070)
    LDA $1FF8               ; select bank 0
    JMP $F080
    !fill $F080 - *, $EA

; -----------------------------------------------------------------------------
; ForestMain — the bank's main ($F080)
; -----------------------------------------------------------------------------
ForestMain:
    LDA SceneInit           ; A = 1 (bank 1)
BankEntry:                  ; checkpoint: A = 1 at power-on, 0 after a switch
    NOP
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the palette is read every frame, so a switch changes the world ----------
    LDA SceneColors+0
    STA COLUBK
    LDA SceneColors+1
    STA COLUPF
    LDA SceneColors+2
    STA COLUP0

; --- the frame counter -------------------------------------------------------
    INC FrameCount
    LDA FrameCount
Frame:                      ; checkpoint: A = the new frame count

; --- fire --------------------------------------------------------------------
    LDA INPT4
    AND #$80
    EOR #$80
    STA NewFire
    EOR PrevFire
    AND NewFire
    STA NewFire
    LDA Startup
    BEQ FireReady
    DEC Startup
    LDA #$00
    STA NewFire
FireReady:
    LDA NewFire
    BEQ NoFire
    LDA #$01
    STA SwitchFlag
NoFire:
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire

; --- the auto-demo -----------------------------------------------------------
    DEC BankTimer
    BNE TimerDone
    LDA #DEMO_PERIOD
    STA BankTimer
    LDA #$01
    STA SwitchFlag
TimerDone:

; --- position P0: one divide-by-15 dance and one HMOVE -----------------------
    LDA #(PLAYER_X + POS_BIAS)
    JSR SetCoarseP0
    STA WSYNC
    STA HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK

; -----------------------------------------------------------------------------
; The visible kernel
; -----------------------------------------------------------------------------
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDY #0
KernelRow:
    LDA ScenePF2,Y
    CPY #INDICATOR_ROWS
    BCS NoIndicator
    LDA Bank
    BEQ Cell0
    LDA #INDICATOR_1
    BNE CellDone
Cell0:
    LDA #INDICATOR_0
CellDone:
NoIndicator:
    STA PF2
    LDA ScenePlayer,Y
    STA GRP0
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE KernelRow

; -----------------------------------------------------------------------------
; Overscan
; -----------------------------------------------------------------------------
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    LDA SwitchFlag
    BNE SwitchOverscan
    +wait_timer
    JMP StartFrame
SwitchOverscan:
    +wait_timer
    LDA #$00
    STA SwitchFlag
    LDA Bank
    EOR #$01
BankWrite:                  ; checkpoint: A = the new bank (0 or 1)
    STA Bank
    LDA #DEMO_PERIOD
    STA BankTimer
    LDA Bank
    BNE SwitchOne
    JMP $F070
SwitchOne:
    JMP $F060

; -----------------------------------------------------------------------------
; SetCoarseP0
; -----------------------------------------------------------------------------
SetCoarseP0:
    STA WSYNC
    SEC
DivP0:
    SBC #15
    BCS DivP0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    RTS

; -----------------------------------------------------------------------------
; Bank 1's data — the exercise's cave
; -----------------------------------------------------------------------------
    !if * > ScenePF2 {
        !error "bank 1's code must end before $F200"
    }
    !fill ScenePF2 - *, $EA

; The first eight bytes are blank: the kernel replaces them with the indicator.
    !fill INDICATOR_ROWS, $00
    !fill 8,  $FF           ; visible 8-15:  a solid ceiling
    !fill 16, $F0           ; visible 16-31: the ceiling's right half
    !fill 32, $E0
    !fill 32, $70
    !fill 32, $38
    !fill 32, $1C
    !fill 24, $0E
    !fill 8,  $FF           ; visible 184-191: the floor

    !fill SceneColors - *, $EA
    !byte C_CAVE_BG, C_CAVE_PF, C_CAVE_P0
    !byte $01               ; SceneInit: bank 1

    !fill ScenePlayer - *, $EA
    !fill PLAYER_TOP, $00
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !fill SCREEN_LINES - PLAYER_TOP - 8, $00

    !fill $FFFA - *, $EA
    * = $FFFA
    !word ForestReset, ForestReset, ForestReset
}
