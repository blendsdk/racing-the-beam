; =============================================================================
; LESSON 56 — EXERCISE 2 SOLUTION: 16K F6, Four Banks — Racing the Beam
; =============================================================================
; Part 8: Advanced Topics
;
; EXERCISE 2: build a 16,384-byte F6 cartridge with four 4K banks and four
;   scenes.  F6 starts in BANK 0 (the reset vector in bank 0's $FFFC is the
;   one the CPU uses at power-on).  The four hotspots are $1FF6-$1FF9:
;   $1FF6 = bank 0, $1FF7 = bank 1, $1FF8 = bank 2, $1FF9 = bank 3.
;
;   The single trampoline at $F060 uses an INDEXED hotspot read:
;
;     $F060  LDX NextBank      X = the target bank, 0..3
;     $F062  LDA $1FF6,X       read the hotspot: select bank X
;     $F065  JMP $F080         continue in the new bank
;
;   The trampoline is byte-identical in all four banks.  The code at $F080
;   reloads A from the bank's own SceneInit, so BankEntry reports the bank
;   number (0, 1, 2 or 3).
;
; The F6 layout (the flat file is bank 0, 1, 2, 3):
;   file offset $0000-$0FFF   bank 0, real $C000, !pseudopc $F000
;   file offset $1000-$1FFF   bank 1, real $D000, !pseudopc $F000
;   file offset $2000-$2FFF   bank 2, real $E000, !pseudopc $F000
;   file offset $3000-$3FFF   bank 3, real $F000, !pseudopc $F000
;
; The four scenes:
;   bank 0  forest   green trees on a blue sky
;   bank 1  cave     red rock on an orange background
;   bank 2  desert   amber dunes on a brown background
;   bank 3  sea      teal waves on a dark blue background
;
; A four-cell indicator in the first eight lines lights one cell per bank:
; PF2 $03 (bank 0), $0C (bank 1), $30 (bank 2), $C0 (bank 3).  The reflected
; playfield mirrors each cell, so a single lit cell appears twice.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;
; Checkpoints (the four banks share the virtual addresses; the labels below
; are bank 0's):
;   StartFrame0 (259/3), Vblank0 (0/5), Body0 (37/5), Overscan0 (229/6);
;   Frame0 (A = the new frame count); BankEntry0 (A = the bank number);
;   BankWrite0 (A = the new bank, 0..3); SwitchRead ($F062, the indexed
;   hotspot read; the log's bank field is the old bank).
;
; RAM map (+clean_start zeroes every byte):
;   $80   Bank         the selected bank, 0..3
;   $81   NextBank     the bank the trampoline will select, 0..3
;   $82   BankTimer    frames left before the auto-demo switches (120)
;   $83   FrameCount   frames since reset, wraps at 256
;   $84   SwitchFlag   1 = switch at the end of this frame
;   $85   PrevFire     fire state last frame (1 = pressed)
;   $86   NewFire      this frame's fire 0 -> 1 edge
;   $87   Startup      frames left before the fire line is trusted
;   $88-$9F free (24 bytes)
;   $F8-$FF stack
;
; Build: acme -f plain -o build/exercise-02.bin \
;        lessons/part8-advanced/56-bankswitching/exercise-02-solution.asm
; Run:   stella build/exercise-02.bin
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

SCREEN_LINES   = 192
INDICATOR_ROWS = 8
DEMO_PERIOD    = 120
PLAYER_X       = 72
PLAYER_TOP     = 96
BANK_COUNT     = 4

; The fixed data addresses — the same in all four banks.
ScenePF2       = $F200   ; 192 bytes, one PF2 byte per visible line
SceneColors    = $F2C0   ; 3 bytes: COLUBK, COLUPF, COLUP0
SceneInit      = $F2C3   ; 1 byte: the bank number, 0..3
ScenePlayer    = $F300   ; 192 bytes, one GRP0 byte per visible line
IndicatorCells = $F1E8   ; 4 bytes: the four indicator patterns
SwitchRead     = $F062   ; the indexed hotspot read in the trampoline

; =============================================================================
; RAM ALLOCATION ($80-$87)
; =============================================================================
Bank        = $80    ; the selected bank, 0..3
NextBank    = $81    ; the bank the trampoline will select
BankTimer   = $82    ; frames left before the auto-demo switches
FrameCount  = $83    ; frames since reset, wraps at 256
SwitchFlag  = $84    ; 1 = switch at the end of this frame
PrevFire    = $85    ; fire state last frame (1 = pressed)
NewFire     = $86    ; this frame's fire 0 -> 1 edge
Startup     = $87    ; frames left before the fire line is trusted
;
; $88-$9F are free (24 bytes).  The stack is $F8-$FF.

; =============================================================================
; THE SHARED BANK SKELETON
; =============================================================================
; The four banks carry the same code at the same virtual addresses.  The
; macros below expand that code four times; the ~ parameters name the labels,
; so each bank gets its own Reset/Main/BankEntry/... symbol while the bytes
; stay identical.
!macro BankReset ~.reset, ~.main {
.reset = *
    +clean_start
    LDA #$00
    STA SWACNT

    LDA SceneInit           ; the bank's own number
    STA Bank
    LDA #DEMO_PERIOD
    STA BankTimer
    LDA #$00
    STA FrameCount
    LDA #$08
    STA Startup

    LDA SceneColors+0
    STA COLUBK
    LDA SceneColors+1
    STA COLUPF
    LDA SceneColors+2
    STA COLUP0
    LDA #$01
    STA CTRLPF

    JMP .main
}

!macro BankFrame ~.main, ~.bankentry, ~.startframe, ~.vblank, ~.frame, ~.body, ~.overscan, ~.bankwrite, ~.setcoarse {
.main = *
    LDA SceneInit           ; A = the bank number
.bankentry = *
    NOP
.startframe = *
    +vsync

.vblank = *
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the palette changes with the bank ---------------------------------------
    LDA SceneColors+0
    STA COLUBK
    LDA SceneColors+1
    STA COLUPF
    LDA SceneColors+2
    STA COLUP0

; --- the frame counter -------------------------------------------------------
    INC FrameCount
    LDA FrameCount
.frame = *

; --- fire --------------------------------------------------------------------
    LDA INPT4
    AND #$80
    EOR #$80
    STA NewFire
    EOR PrevFire
    AND NewFire
    STA NewFire
    LDA Startup
    BEQ .fireReady
    DEC Startup
    LDA #$00
    STA NewFire
.fireReady:
    LDA NewFire
    BEQ .noFire
    LDA #$01
    STA SwitchFlag
.noFire:
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire

; --- the auto-demo -----------------------------------------------------------
    DEC BankTimer
    BNE .timerDone
    LDA #DEMO_PERIOD
    STA BankTimer
    LDA #$01
    STA SwitchFlag
.timerDone:

; --- one HMOVE ---------------------------------------------------------------
    LDA #(PLAYER_X + POS_BIAS)
    JSR .setcoarse
    STA WSYNC
    STA HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK

; --- the 192-line kernel -----------------------------------------------------
.body = *
    LDY #0
.kernelRow:
    LDA ScenePF2,Y
    CPY #INDICATOR_ROWS
    BCS .noCell
    LDX Bank
    LDA IndicatorCells,X
.noCell:
    STA PF2
    LDA ScenePlayer,Y
    STA GRP0
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE .kernelRow

; --- overscan and the switch -------------------------------------------------
.overscan = *
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    LDA SwitchFlag
    BNE .switchOverscan
    +wait_timer
    JMP .startframe
.switchOverscan:
    +wait_timer
    LDA #$00
    STA SwitchFlag
    LDA Bank
    CLC
    ADC #$01
    AND #(BANK_COUNT - 1)   ; 0, 1, 2, 3, 0, ...
    STA NextBank
.bankwrite = *              ; A = the new bank
    STA Bank
    LDA #DEMO_PERIOD
    STA BankTimer
    JMP $F060

; --- the Lesson 26 positioning dance ----------------------------------------
.setcoarse = *
    STA WSYNC
    SEC
.divP0:
    SBC #15
    BCS .divP0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    RTS
}

; =============================================================================
; BANK 0 — real $C000, virtual $F000.  THE FOREST.  (The start bank.)
; =============================================================================
    * = $C000
    !pseudopc $F000 {
    +BankReset ~Reset0, ~Main0
    !if * > $F060 {
        !error "bank 0's reset must fit before $F060"
    }
    !fill $F060 - *, $EA

; The single trampoline: an indexed hotspot read selects bank X.
    LDX NextBank
    LDA $1FF6,X
    JMP $F080
    !fill $F080 - *, $EA

    +BankFrame ~Main0, ~BankEntry0, ~StartFrame0, ~Vblank0, ~Frame0, ~Body0, ~Overscan0, ~BankWrite0, ~SetCoarse0

    !if * > IndicatorCells {
        !error "bank 0's frame code must end before the indicator table"
    }
    !fill IndicatorCells - *, $EA
    !byte $03, $0C, $30, $C0
    !fill ScenePF2 - *, $EA
    !fill INDICATOR_ROWS, $00
    !fill 24, $FF           ; visible 8-31:  the canopy
    !fill 32, $C3           ; visible 32-63: wide trunks
    !fill 32, $81           ; visible 64-95: thin trunks
    !fill 32, $C3
    !fill 32, $81
    !fill 32, $C3
    !fill SceneColors - *, $EA
    !byte $84, $C8, $0E
    !byte $00               ; SceneInit: bank 0
    !fill ScenePlayer - *, $EA
    !fill PLAYER_TOP, $00
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !fill SCREEN_LINES - PLAYER_TOP - 8, $00
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset0, Reset0, Reset0
}

; =============================================================================
; BANK 1 — real $D000, virtual $F000.  THE CAVE.
; =============================================================================
    * = $D000
    !pseudopc $F000 {
    +BankReset ~Reset1, ~Main1
    !if * > $F060 {
        !error "bank 1's reset must fit before $F060"
    }
    !fill $F060 - *, $EA
    LDX NextBank
    LDA $1FF6,X
    JMP $F080
    !fill $F080 - *, $EA
    +BankFrame ~Main1, ~BankEntry1, ~StartFrame1, ~Vblank1, ~Frame1, ~Body1, ~Overscan1, ~BankWrite1, ~SetCoarse1
    !if * > IndicatorCells {
        !error "bank 1's frame code must end before the indicator table"
    }
    !fill IndicatorCells - *, $EA
    !byte $03, $0C, $30, $C0
    !fill ScenePF2 - *, $EA
    !fill INDICATOR_ROWS, $00
    !fill 8,  $FF           ; visible 8-15:  a solid ceiling
    !fill 16, $F0
    !fill 32, $E0
    !fill 32, $70
    !fill 32, $38
    !fill 32, $1C
    !fill 24, $0E
    !fill 8,  $FF           ; visible 184-191: the floor
    !fill SceneColors - *, $EA
    !byte $28, $44, $1A
    !byte $01               ; SceneInit: bank 1
    !fill ScenePlayer - *, $EA
    !fill PLAYER_TOP, $00
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !fill SCREEN_LINES - PLAYER_TOP - 8, $00
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset1, Reset1, Reset1
}

; =============================================================================
; BANK 2 — real $E000, virtual $F000.  THE DESERT.
; =============================================================================
    * = $E000
    !pseudopc $F000 {
    +BankReset ~Reset2, ~Main2
    !if * > $F060 {
        !error "bank 2's reset must fit before $F060"
    }
    !fill $F060 - *, $EA
    LDX NextBank
    LDA $1FF6,X
    JMP $F080
    !fill $F080 - *, $EA
    +BankFrame ~Main2, ~BankEntry2, ~StartFrame2, ~Vblank2, ~Frame2, ~Body2, ~Overscan2, ~BankWrite2, ~SetCoarse2
    !if * > IndicatorCells {
        !error "bank 2's frame code must end before the indicator table"
    }
    !fill IndicatorCells - *, $EA
    !byte $03, $0C, $30, $C0
    !fill ScenePF2 - *, $EA
    !fill INDICATOR_ROWS, $00
    !fill 24, $FF           ; visible 8-31:  the bright sky
    !fill 32, $3C           ; visible 32-63: a wide dune
    !fill 32, $18
    !fill 32, $3C
    !fill 32, $18
    !fill 32, $3C
    !fill SceneColors - *, $EA
    !byte $18, $2A, $0E
    !byte $02               ; SceneInit: bank 2
    !fill ScenePlayer - *, $EA
    !fill PLAYER_TOP, $00
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !fill SCREEN_LINES - PLAYER_TOP - 8, $00
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset2, Reset2, Reset2
}

; =============================================================================
; BANK 3 — real $F000, virtual $F000.  THE SEA.
; =============================================================================
    * = $F000
    !pseudopc $F000 {
    +BankReset ~Reset3, ~Main3
    !if * > $F060 {
        !error "bank 3's reset must fit before $F060"
    }
    !fill $F060 - *, $EA
    LDX NextBank
    LDA $1FF6,X
    JMP $F080
    !fill $F080 - *, $EA
    +BankFrame ~Main3, ~BankEntry3, ~StartFrame3, ~Vblank3, ~Frame3, ~Body3, ~Overscan3, ~BankWrite3, ~SetCoarse3
    !if * > IndicatorCells {
        !error "bank 3's frame code must end before the indicator table"
    }
    !fill IndicatorCells - *, $EA
    !byte $03, $0C, $30, $C0
    !fill ScenePF2 - *, $EA
    !fill INDICATOR_ROWS, $00
    !fill 24, $FF           ; visible 8-31:  the bright surface
    !fill 32, $C3           ; visible 32-63: a wave
    !fill 32, $3C
    !fill 32, $C3
    !fill 32, $3C
    !fill 32, $C3
    !fill SceneColors - *, $EA
    !byte $86, $B8, $0E
    !byte $03               ; SceneInit: bank 3
    !fill ScenePlayer - *, $EA
    !fill PLAYER_TOP, $00
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !fill SCREEN_LINES - PLAYER_TOP - 8, $00
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset3, Reset3, Reset3
}
