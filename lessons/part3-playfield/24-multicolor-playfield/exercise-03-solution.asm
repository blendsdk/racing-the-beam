; =============================================================================
; LESSON 24 — EXERCISE 3 SOLUTION: A Data-Colored Maze (Stretch Goal)
; =============================================================================
; Part 3: Playfield
;
; Exercise: combine Lesson 23's row tables with Lesson 24's per-line color.
;
; The technique: add a fourth parallel table per level — a 192-byte color
; table — and a fourth pointer.  The color is $C8 for a wall row (PF1 or
; PF2 nonzero) and $02 for an open row (both zero), so the corridors
; disappear into the background and the walls turn green.  The kernel
; stores COLUPF at the top of the line and prefetches the next row's color
; with the other three bytes.
;
; The decision is made once per row, when the table is authored; the kernel
; just reads the fourth byte.  Four tables x 192 bytes x 2 levels = 1,536
; bytes, still inside 4K.
;
; Debugger checkpoints: LevelSwitch (frames 240/480, A=1/0), ColorStore
; (one hit per line, A = $C8 or $02), RowStore (the PF2 byte).
;
; Build: acme -f plain -o build/lesson24-ex3.bin \
;        lessons/part3-playfield/24-multicolor-playfield/exercise-03-solution.asm
; Run:   stella build/lesson24-ex3.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines
VISIBLE_LINES  = 192
LEVEL_FRAMES   = 240    ; ~4 seconds per level

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
FrameCounter   = $80
Level          = $81    ; 0 = Level1 tables, 1 = Level2 tables
Ptr0           = $82    ; 2 bytes each: the PF0/PF1/PF2 table bases
Ptr1           = $84
Ptr2           = $86
Tmp0           = $88    ; the current row's three bytes
Tmp1           = $89
Tmp2           = $8A
TmpColor       = $8B    ; the current row's playfield color
PtrColor       = $8C    ; 2 bytes: the per-row color table

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM; Level = 0 (Level 1)

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
    +vsync

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the level tick: switch every LEVEL_FRAMES frames ---
    INC FrameCounter
    LDA FrameCounter
    CMP #LEVEL_FRAMES
    BNE VblankSetLevel
    LDA #$00
    STA FrameCounter
    LDA Level
    EOR #$01
LevelSwitch:                ; debugger checkpoint: A = the new level (flip only)
    STA Level

; --- point the three tables at the current level ---
VblankSetLevel:
    LDA Level
    BEQ VblankLevel1
    LDA #<Level2PF0
    STA Ptr0
    LDA #>Level2PF0
    STA Ptr0+1
    LDA #<Level2PF1
    STA Ptr1
    LDA #>Level2PF1
    STA Ptr1+1
    LDA #<Level2PF2
    STA Ptr2
    LDA #>Level2PF2
    STA Ptr2+1
    LDA #<Level2Color
    STA PtrColor
    LDA #>Level2Color
    STA PtrColor+1
    JMP VblankPreload

VblankLevel1:
    LDA #<Level1PF0
    STA Ptr0
    LDA #>Level1PF0
    STA Ptr0+1
    LDA #<Level1PF1
    STA Ptr1
    LDA #>Level1PF1
    STA Ptr1+1
    LDA #<Level1PF2
    STA Ptr2
    LDA #>Level1PF2
    STA Ptr2+1
    LDA #<Level1Color
    STA PtrColor
    LDA #>Level1Color
    STA PtrColor+1

; --- preload row 0 into the row temps ---
VblankPreload:
    LDY #0
    LDA (Ptr0),Y
    STA Tmp0
    LDA (Ptr1),Y
    STA Tmp1
    LDA (Ptr2),Y
    STA Tmp2
    LDA (PtrColor),Y
    STA TmpColor

    LDA #$C8
    STA COLUPF              ; green
    LDA #$02
    STA COLUBK              ; dark neutral
    LDA #$01
    STA CTRLPF              ; reflect: the maze is symmetric

    LDX #VISIBLE_LINES
    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — one table row per line
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam on line 37
VisibleStart:               ; debugger checkpoint: the picture's first line (37)
    LDA TmpColor
    STA COLUPF
ColorStore:                 ; debugger checkpoint: A = this row's color
    LDA Tmp0
    STA PF0
    LDA Tmp1
    STA PF1
    LDA Tmp2
    STA PF2
RowStore:                   ; debugger checkpoint: A = the PF2 byte
    INY                     ; the next row
    LDA (Ptr0),Y
    STA Tmp0
    LDA (Ptr1),Y
    STA Tmp1
    LDA (Ptr2),Y
    STA Tmp2
    LDA (PtrColor),Y
    STA TmpColor
    STA WSYNC               ; park the rest of this line
    DEX
    BNE VisibleStart

; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines; blank-on lands in line 229's HBLANK
; -----------------------------------------------------------------------------
OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; LEVEL 1 — "the keep"
; =============================================================================
Level1PF0:
    !byte $F0,$F0,$F0,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$F0,$F0,$F0
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$F0,$F0,$F0,$F0,$F0,$F0

Level1PF1:
    !byte $FF,$FF,$FF,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$FF,$FF,$FF
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$FF,$FF,$FF,$FF,$FF,$FF

Level1PF2:
    !byte $FF,$FF,$FF,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$3F,$3F,$3F
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$FF,$FF,$FF,$FF,$FF,$FF

Level1Color:
    !byte $C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$02,$02,$02,$02,$02
    !byte $02,$02,$02,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$02,$02,$02,$02,$02
    !byte $02,$02,$02,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$02,$02,$02,$02,$02
    !byte $02,$02,$02,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$02,$02,$02,$02,$02
    !byte $02,$02,$02,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$02,$02,$02,$02,$02
    !byte $02,$02,$02,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8
    !byte $C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8
    !byte $C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8
    !byte $C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8
    !byte $C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8
    !byte $C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8
    !byte $C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8

; =============================================================================
; LEVEL 2 — "the labyrinth"
; =============================================================================
Level2PF0:
    !byte $F0,$F0,$F0,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$F0,$F0,$F0
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$F0,$F0,$F0

Level2PF1:
    !byte $FF,$FF,$FF,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$FF,$FF,$FF
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$00,$00,$00,$00,$00,$00,$00,$00,$81,$81,$81,$81,$81
    !byte $81,$81,$81,$00,$00,$00,$00,$00,$00,$00,$00,$81,$81,$81,$81,$81
    !byte $81,$81,$81,$00,$00,$00,$00,$00,$00,$00,$00,$81,$81,$81,$81,$81
    !byte $81,$81,$81,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF

Level2PF2:
    !byte $FF,$FF,$FF,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$3F,$3F,$3F
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$00,$00,$00,$00,$00,$00,$00,$00,$81,$81,$81,$81,$81
    !byte $81,$81,$81,$00,$00,$00,$00,$00,$00,$00,$00,$81,$81,$81,$81,$81
    !byte $81,$81,$81,$00,$00,$00,$00,$00,$00,$00,$00,$81,$81,$81,$81,$81
    !byte $81,$81,$81,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF

Level2Color:
    !byte $C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$02,$02,$02,$02,$02
    !byte $02,$02,$02,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$02,$02,$02,$02,$02
    !byte $02,$02,$02,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$02,$02,$02,$02,$02
    !byte $02,$02,$02,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8
    !byte $C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8
    !byte $C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8
    !byte $C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8
    !byte $C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8,$C8
    !byte $C8,$C8,$C8,$02,$02,$02,$02,$02,$02,$02,$02,$C8,$C8,$C8,$C8,$C8
    !byte $C8,$C8,$C8,$02,$02,$02,$02,$02,$02,$02,$02,$C8,$C8,$C8,$C8,$C8
    !byte $C8,$C8,$C8,$02,$02,$02,$02,$02,$02,$02,$02,$C8,$C8,$C8,$C8,$C8
    !byte $C8,$C8,$C8,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$C8,$C8,$C8

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
