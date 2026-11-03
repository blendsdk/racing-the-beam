; =============================================================================
; LESSON 23: Data-Driven Playfield — Levels from Tables — Racing the Beam
; =============================================================================
; Part 3: Playfield
;
; What this program does:
;   Draws a full maze, one playfield row per scanline, from ROM tables.
;   Two levels live in the cartridge; every ~4 seconds the program switches
;   to the other one by changing three table pointers.  The picture is 192
;   rows of 20 playfield bits, at full vertical resolution.
;
; Why tables:
;   Lessons 19-22 drew the same pattern on every line.  A maze needs a
;   different 20-bit row on each of the 192 lines.  Storing the rows in ROM
;   and reading one row per line turns the playfield into a level format:
;   three bytes per row, and a pointer decides which level is showing.
;
;   Each level is three PARALLEL tables of 192 bytes:
;
;     Level1PF0:  one PF0 byte per row  (only bits 4-7 are used)
;     Level1PF1:  one PF1 byte per row
;     Level1PF2:  one PF2 byte per row
;
;   3 x 192 = 576 bytes per level.  The kernel keeps three zero-page
;   pointers (Ptr0/Ptr1/Ptr2) at the three table bases and uses the same Y
;   (the row number) for all three reads.
;
; The one-line kernel:
;   The current row is held in Tmp0/Tmp1/Tmp2.  At the top of the line the
;   three bytes are stored to PF0/PF1/PF2; then Y advances and the NEXT
;   row is prefetched into the temps while the beam draws the current one.
;   The next line stores the prefetched row.  The stores end at cycle 22,
;   before every playfield slot; the prefetch finishes at cycle 48; WSYNC
;   parks the rest; DEX/BNE run at cycles 0-4 of the next line.
;
; The per-line ledger (body entered at cycle 5 every line):
;   LDA Tmp0 / STA PF0        6   5-10
;   LDA Tmp1 / STA PF1        6   11-16
;   LDA Tmp2 / STA PF2        6   17-22   (PF2 effect at clock 69 < 116)
;   INY                       2   23-24
;   LDA (Ptr0),Y / STA Tmp0   8   25-32
;   LDA (Ptr1),Y / STA Tmp1   8   33-40
;   LDA (Ptr2),Y / STA Tmp2   8   41-48
;   STA WSYNC                 3   49-51   (write 51, park 52-75)
;   DEX / BNE taken           5   next line 0-4; body re-entered at 5
;   ----------------------------------------------------------------
;   total                    52-55 of 76 cycles
;                            (a page-crossing (zp),Y read adds 1; WSYNC absorbs it)
;
; Level switching:
;   FrameCounter counts to 240 (~4 s); Level toggles and the VBLANK code
;   reloads Ptr0/Ptr1/Ptr2 from the new level's table bases.  Y resets to 0
;   and row 0 of the new level is preloaded before the release.  The
;   switch is invisible until the next frame; no mid-frame edits.
;
; The levels:
;   Level 1 "the keep": a full border, horizontal wall/open rows, a divider
;   at rows 93-95 with a central doorway, then chamber/pillar rows.
;   Level 2 "the labyrinth": the divider at rows 61-63, a central pillar,
;   and the open/wall blocks in the lower half.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), LevelSwitch (A = the new level, at
;   frames 240, 480, ...), VisibleStart (37), RowStore (one hit per line,
;   A = the PF2 byte just written), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson23.bin \
;        lessons/part3-playfield/23-data-driven-playfield/23-data-driven-playfield.asm
; Run:   stella build/lesson23.bin
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

; --- preload row 0 into the row temps ---
VblankPreload:
    LDY #0
    LDA (Ptr0),Y
    STA Tmp0
    LDA (Ptr1),Y
    STA Tmp1
    LDA (Ptr2),Y
    STA Tmp2

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
; LEVEL 1 — "the keep": 192 rows, three parallel tables
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

; =============================================================================
; LEVEL 2 — "the labyrinth": 192 rows, three parallel tables
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

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
