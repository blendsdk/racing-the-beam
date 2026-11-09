; =============================================================================
; LESSON 78 — EXERCISE 2 SOLUTION: A Behaviour Flag and a Third Object
; =============================================================================
; Part 11: Legendary Techniques
;
; The exercise adds two things to the engine:
;
;   1. A second static behaviour, BEH_LOCKED = 2.  Room 2's door uses it.
;      Without a carried object the door is solid: the P0/ball collision
;      (CXP0FB bit 6) reverts the move, exactly like the wall collision.
;      With the carried object the same collision opens the door: DoorOpen
;      is set and the ball is suppressed after LoadRoom.
;
;   2. A third object, a gem (graphic index 1, violet), in room 1 at x=40.
;      The auto-demo walks to it and picks it up; the gem is carried in P1,
;      and the room-1 key record is skipped and NOT DRAWN while the gem is
;      carried (the engine carries one object at a time).  The gem is the
;      "key" that opens room 2's locked door, so the demo shows both a
;      pickup with a different graphic and the locked-door behaviour.
;
; The ROM is still 4,096 bytes and the frame is still 262 lines.  The
; door-block state is checked by the host ledger in the lesson: without a
; carried object the room-2 door stops the player before it; with the gem
; the door opens and the demo stops at x=140.
;
; What this program does (the lesson source with the exercise applied):
;   "the engine": a four-room adventure.  The screen is 192 scanlines in
;   three bands:
;
;     visible   0- 23    the status band   24 lines   room gauge + key block
;     visible  24-167    the room         144 lines   36 rows x 4 lines
;     visible 168-191    the lower band    24 lines   the floor
;                       ----------------
;                       24 + 144 + 24 = 192
;
;   THE PICTURE IS DATA.  There is no per-room code.  Two tables in the
;   cartridge describe the whole world:
;
;     RoomTable    one 8-byte record per room:
;                    +0 PF0        the left wall pattern's first byte
;                    +1 PF1
;                    +2 PF2
;                    +3 colour     the playfield (and the door's base) colour
;                    +4 left exit  the room to the left, or $FF for none
;                    +5 right exit the room to the right, or $FF for none
;                    +6 first object index into ObjectTable
;                    +7 object count
;
;     ObjectTable  one 6-byte record per object:
;                    +0 x          the object's left edge, 0..152
;                    +1 y          the object's top edge, a multiple of 4
;                    +2 graphic    a sprite-table index or a ball size
;                    +3 colour
;                    +4 behaviour  0 = static, 1 = pickup, 2 = locked
;                    +5 room       the room that owns the object
;
;   The engine reads a record, stages its fields into RAM during VBLANK,
;   and the same kernel draws every room.  Changing a byte in a table
;   changes the game; adding a room is one more record (Exercise 1 adds a
;   fifth room and a second, vertical exit).  This is Warren Robinett's
;   Adventure architecture in miniature: the cartridge stores a description
;   of the world and one interpreter, not a program per room.
;
;   THE PLAYER IS P0, THE KEY IS P1, THE DOOR IS THE BALL.  P0 is an 8x16
;   adventurer; P1 is the pickup graphic (an 8x16 key, or the gem the second
;   exercise adds) and sits on the floor until the player touches it.  The
;   TIA's P0/P1 collision latch (CXPPMM bit 7) is the
;   pickup: the hardware does the overlap test, the engine changes the
;   state.  Once carried, the key is drawn four 4-line rows above the
;   player, so its x follows the player and its y sits on the player's
;   head.  The ball is a rectangle, not a bitmap: its width comes from
;   CTRLPF bits 4-5 and its height from the rows the kernel enables it.
;   The door's record is a static object; its colour is applied for the
;   whole exit corridor, which has no playfield at all, so COLUPF colours
;   only the ball.  The wall colour is restored on the row after the
;   corridor, and the boundary line can show a one-scanline seam.
;
;   THE ROOM IS 36 ROWS OF FOUR SCANLINES.  The course's default is a
;   2-line kernel; this engine pays for its three dynamic objects with
;   4-line rows.  That gives 295 cycles per row for the object compare
;   and the playfield bookkeeping, and the vertical resolution is four
;   scanlines, which is the price.  Adventure's own objects move in coarse
;   steps, so the trade is in character.  The status and lower bands use
;   the same 4-line rhythm: 6 + 36 + 6 = 48 rows x 4 = 192 lines.
;
;   THE EXIT IS A HOLE IN THE WALL.  Every room's pattern has a left/right
;   side wall (PF0 = $10, mirrored by REFLECT).  Rows 10-17 of every room
;   are the exit corridor: the kernel zeroes PF0/PF1/PF2 there, so the
;   side walls, the pillars and the door's background all open into a
;   32-line gap.  The player walks out at x=152 (or x=0) only when its
;   4-row body is fully inside the corridor.  The room record's exit
;   bytes decide what happens next; $FF is a solid end.
;
;   THE STATUS BAND SHOWS THE ROOM AND THE KEY.  M0 is the room gauge:
;   a 2-pixel bar whose height is 4 x (room index + 1) scanlines, so room
;   0 is 4 lines, room 1 is 8, room 2 is 12 and room 3 is 16.  M1 is the
;   key block: a 4x8 block, lit while the key is carried.  Both are
;   positioned once at power-on; their fine registers are zeroed in the
;   first VBLANK before the per-frame HMOVE (which applies all five HM
;   registers), so the status missiles never drift.
;
;   THE AUTO-DEMO walks P0 right from room 0 at x=145, row 13.  It leaves
;   room 0 at x=152, enters room 1 at x=4 and picks the gem up there,
;   carries it through room 1's right exit, opens room 2's locked door
;   with it, and stops at x=140.  Counting frames from power-on: room 0
;   for 1-7, room 1 for 8-156, room 2 from 157.  The gem is carried from
;   the first room-1 frame; the room-1 key record is skipped and not drawn
;   while the gem is carried.  Any joystick direction cancels the
;   demo and hands P0 to the reader; SELECT restarts the whole state.
;
;   THE FRAME (NTSC): 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262.
;   The visible body is six status rows, thirty-six room rows and six
;   lower rows of four scanlines each.  The checkpoints in the source are
;   the line/cycle anchors the lesson's ledger uses:
;
;     StartFrame      259/3    the first VSYNC line
;     VblankStart       0/5    the first VBLANK line
;     BodyStart        37/5    visible line 0
;     RoomStart        60/63   the status band's last line; the room's first
;                              line follows at 61/0
;     LowerStart      209/13   the lower loop's first WSYNC; the lower band's
;                              first line is 205/0
;     OverscanStart   229/6    the STA VBLANK that blanks the first overscan
;                              line (its store completes at 229/9)
;
;   RAM map (the exact map; +clean_start zeroes every byte):
;     $80 Room         0..3, the current room index
;     $81 PlayerX      P0's left edge, 0..152
;     $82 PlayerRow    P0's top row, 0..32 (four scanlines per row)
;     $83 PrevX        the position before the last move (wall collision)
;     $84 PrevRow
;     $85 KeyHeld      1 while the key is carried
;     $86 KeyX         P1's left edge (or the floor key's)
;     $87 KeyRow       P1's top row
;     $88 KeyGfxOffset the carried/floor key's graphic * 4
;     $89 KeyOn        1 if P1 has something to draw
;     $8A DoorX        the ball's left edge
;     $8B DoorRow      the ball's top row
;     $8C DoorGfx      the ball-size index
;     $8D DoorOn       1 if the ball is enabled
;     $8E DoorColor    the door's COLUPF colour
;     $8F KeyColor     P1's COLUP1 colour
;     $90 WallPF0      the room's staged playfield bytes
;     $91 WallPF1
;     $92 WallPF2
;     $93 WallColor
;     $94 LeftExit     $FF = none
;     $95 RightExit    $FF = none
;     $96 FirstObj     the room's first object index
;     $97 ObjCount
;     $98 PrevSelect   SELECT edge latch
;     $99 AutoDemo     1 until a joystick direction is pressed
;     $9A DemoDone     1 once the scripted walk has stopped
;     $9B FrameLo      frame counter, one increment per frame
;     $9C FrameHi
;     $9D RoomRow      the room kernel's row counter
;     $9E StatusRow    the status kernel's row counter
;     $9F TmpP0        the row compute's three results
;     $A0 TmpP1
;     $A1 TmpBL
;     $A2 Tmp          scratch
;     $A3 TmpCount     the object scan's counter
;     $A4 ObjIndex     the object scan's index
;     $A5 TmpM0        the status compute's two enables
;     $A6 TmpM1
;     $A7 CurP0        the room row's held graphics values
;     $A8 CurP1
;     $A9 CurBL
;     $AA CurM0        the status row's held enables
;     $AB CurM1
;     $AC DoorLocked   1 if the current door is locked
;     $AD DoorOpen     1 once the locked door has opened
;     $AE CarryGfxOffset  the carried object's graphic * 4
;     $AF CarryColor   the carried object's colour
;     $B0-$F7          free (72 bytes)
;     $F8-$FF          the stack (the deepest call is one level)
;
; Build: acme -f plain -o build/exercise-02.bin \
;        lessons/part11-legendary/78-room-object-engine/exercise-02-solution.asm
; Run:   stella build/exercise-02.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK (Lesson 15)
OVERSCAN_TIMER = 36      ; 30-line overscan (Lesson 15)

STATUS_ROWS    = 6       ; 6 x 4 = 24 visible lines
ROOM_ROWS      = 36      ; 36 x 4 = 144 visible lines
LOWER_ROWS     = 6       ; 6 x 4 = 24 visible lines
ROW_LINES      = 4       ; one row is four scanlines
VISIBLE_LINES  = (STATUS_ROWS + ROOM_ROWS + LOWER_ROWS) * ROW_LINES

; The exit corridor, in room rows.  The room's PF is zero from EXIT_TOP
; through EXIT_BOTTOM, so the 32-line opening is a hole in the side walls.
EXIT_TOP       = 10
EXIT_BOTTOM    = 17
EXIT_MIN_ROW   = EXIT_TOP          ; the player's 4-row body must be inside
EXIT_MAX_ROW   = EXIT_BOTTOM - 3   ; row + 3 <= EXIT_BOTTOM

PLAYER_MIN_X   = 0
PLAYER_MAX_X   = 152                 ; 160 - 8
PLAYER_MIN_ROW = 0
PLAYER_MAX_ROW = 32                  ; 32 + 3 = 35, the last room row

POS_BIAS       = 3                   ; the Lesson 26 player output delay
DOOR_BIAS      = 3                   ; calibrated after the first Stella run

; Object record offsets (six bytes per record).
OBJ_X          = 0
OBJ_Y          = 1
OBJ_GFX        = 2
OBJ_COLOR      = 3
OBJ_BEH        = 4
OBJ_ROOM       = 5
OBJ_SIZE       = 6
OBJ_COUNT      = 7                   ; seven objects in this ROM

; Behaviours the interpreter understands.
BEH_STATIC     = 0                   ; a door: draw the ball, no state change
BEH_PICKUP     = 1                   ; a key: P0/P1 collision picks it up
BEH_LOCKED     = 2                   ; a door that opens with the carried object

; Object graphics: four bytes per graphic, drawn on four scanlines each.
GFX_KEY        = 0
GFX_GEM        = 1                   ; the second pickup's 8x16 bitmap
GFX_DOOR       = 1                   ; the ball's 8-pixel size index

; Colours (TIA %HHHHLLL0).
C_PLAYER       = $9A     ; P0: light blue
C_KEY          = $1A     ; P1: gold
C_GEM          = $7A     ; the gem: violet
C_DOOR         = $36     ; the door: brown-red
C_STATUS_M0    = $C8     ; the room gauge: green
C_STATUS_M1    = $1A     ; the key block: gold
C_FLOOR        = $02     ; the lower band: very dark grey

; Room wall colours.
C_WALL0        = $46     ; red (hue 4)
C_WALL1        = $C6     ; green
C_WALL2        = $26     ; orange
C_WALL3        = $86     ; blue

; The band arithmetic is a build-time assertion, not a comment.
!if (STATUS_ROWS + ROOM_ROWS + LOWER_ROWS) * ROW_LINES != 192 {
    !error "the three bands must total 192 visible lines"
}

; =============================================================================
; RAM ALLOCATION ($80-$AF; +clean_start zeroes every byte)
; =============================================================================
Room         = $80   ; the current room index, 0..3
PlayerX      = $81   ; P0's left edge, 0..152
PlayerRow    = $82   ; P0's top row, 0..32
PrevX        = $83   ; the position before the last move
PrevRow      = $84
KeyHeld      = $85   ; 1 while the key is carried
KeyX         = $86   ; P1's left edge
KeyRow       = $87   ; P1's top row
KeyGfxOffset = $88   ; the key's graphic table offset (index * 4)
KeyOn        = $89   ; 1 if P1 has a graphic to draw
DoorX        = $8A   ; the ball's left edge
DoorRow      = $8B   ; the ball's top row
DoorGfx      = $8C   ; the ball-size index
DoorOn       = $8D   ; 1 if the ball is enabled
DoorColor    = $8E   ; the door's own colour
KeyColor     = $8F   ; P1's colour
WallPF0      = $90   ; the room's staged playfield pattern
WallPF1      = $91
WallPF2      = $92
WallColor    = $93
LeftExit     = $94   ; $FF = no left exit
RightExit    = $95   ; $FF = no right exit
FirstObj     = $96   ; the room's first object index
ObjCount     = $97
PrevSelect   = $98   ; SELECT edge latch
AutoDemo     = $99   ; 1 until the reader touches the joystick
DemoDone     = $9A   ; 1 once the scripted walk has stopped
FrameLo      = $9B   ; frame counter, one increment per frame
FrameHi      = $9C
RoomRow      = $9D   ; the room kernel's row counter, 0..35
StatusRow    = $9E   ; the status kernel's row counter, 0..5
TmpP0        = $9F   ; the row compute's three results
TmpP1        = $A0
TmpBL        = $A1
Tmp          = $A2   ; scratch
TmpCount     = $A3   ; the object scan's counter
ObjIndex     = $A4   ; the object scan's index
TmpM0        = $A5   ; the status compute's two enables
TmpM1        = $A6
CurP0        = $A7   ; the values being held on the current room row
CurP1        = $A8
CurBL        = $A9
CurM0        = $AA   ; the status band's two enables for the current row
CurM1        = $AB
DoorLocked   = $AC   ; 1 if the current room's door has BEH_LOCKED
DoorOpen     = $AD   ; 1 once the carried object has opened that door
CarryGfxOffset = $AE ; the carried object's graphic table offset
CarryColor   = $AF   ; the carried object's colour
;
; $B0-$F7 are free (72 bytes).  The stack lives at $F8-$FF; the deepest
; call is LoadRoom or ComputeP0, one level, two bytes.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start

    LDA #$00
    STA SWACNT              ; port A is an input port
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA COLUBK              ; black until the first band writes

    LDA #$10
    STA NUSIZ0              ; M0 is 2 pixels wide; P0 is one copy
    LDA #$20
    STA NUSIZ1              ; M1 is 4 pixels wide; P1 is one copy
    LDA #$01
    STA CTRLPF              ; REFLECT the playfield; a 1-pixel ball
    LDA #C_STATUS_M0
    STA COLUP0              ; the status gauge's colour
    LDA #C_STATUS_M1
    STA COLUP1              ; the status key block's colour

    LDA #$01
    STA AutoDemo
    LDA #$00
    STA DemoDone
    STA PrevSelect
    STA FrameLo
    STA FrameHi
    STA KeyHeld
    JSR ResetGame

; --- position the two status missiles once -----------------------------------
; M0 and M1 are fixed objects: their coarse positions are strobed here and
; their fine registers are zeroed in the first VBLANK, before the per-frame
; HMOVE (which applies all five HM registers), so the status missiles cannot
; drift.
    LDA #(20 + POS_BIAS)
    JSR SetCoarseM0
    LDA #(40 + POS_BIAS)
    JSR SetCoarseM1
    STA WSYNC
    STA HMOVE

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    INC FrameLo
    BNE .frameHiDone
    INC FrameHi
.frameHiDone:

; -----------------------------------------------------------------------------
; 1. SELECT — restart the adventure
; -----------------------------------------------------------------------------
; SELECT is SWCHB bit 1, active low.  The edge latch makes it one reset per
; press: the demo, the room, the key and the player all return to power-on.
    LDA SWCHB
    AND #$02
    BNE .selectReleased
    LDA PrevSelect
    BNE .selectDone
    LDA #$01
    STA PrevSelect
    JSR ResetGame
    JMP .selectDone
.selectReleased:
    LDA #$00
    STA PrevSelect
.selectDone:

; -----------------------------------------------------------------------------
; 2. INPUT — any joystick direction surrenders the auto-demo
; -----------------------------------------------------------------------------
; SWCHA bits 7,6,5,4 are P0 right, left, down, up, all active low.  If any
; is pressed the scripted walk stops for good; SELECT starts it again.
    LDA SWCHA
    AND #$F0
    CMP #$F0
    BEQ .noManual
    LDA #$00
    STA AutoDemo
.noManual:

; -----------------------------------------------------------------------------
; 3. WALL COLLISION — the previous frame's P0/PF latch, tested and undone
; -----------------------------------------------------------------------------
; The TIA latches P0-over-playfield in CXP0FB bit 7.  The latch describes the
; picture that was just drawn; if it is set, the last move walked into a wall,
; so the player returns to PrevX/PrevRow.  The corridor is zeroed playfield,
; so the exit itself never collides.
    LDA CXP0FB
    AND #$80
    BEQ .noWall
    LDA PrevX
    STA PlayerX
    LDA PrevRow
    STA PlayerRow
.noWall:

; --- the locked door: block without the carry, open with it ------------------
; CXP0FB bit 6 is P0/ball.  A locked door without a carried object reverts
; the last move (the same PrevX/PrevRow dance as the wall); with a carried
; object it sets DoorOpen and the ball is suppressed after LoadRoom.
    LDA CXP0FB
    AND #$40
    BEQ .noDoorHit
    LDA DoorLocked
    BEQ .noDoorHit
    LDA KeyHeld
    BNE .openDoor
    LDA PrevX
    STA PlayerX
    LDA PrevRow
    STA PlayerRow
    JMP .noDoorHit
.openDoor:
    LDA #$01
    STA DoorOpen
.noDoorHit:

    LDA PlayerX
    STA PrevX
    LDA PlayerRow
    STA PrevRow

; -----------------------------------------------------------------------------
; 4. MOVE — the scripted walk, or the joystick
; -----------------------------------------------------------------------------
    LDA AutoDemo
    BEQ .manual
    LDA DemoDone
    BNE .moved
    LDA Room
    CMP #2
    BCC .autoRight
    LDA PlayerX
    CMP #140
    BCS .autoStop
.autoRight:
    JMP .moveRight
.autoStop:
    LDA #$01
    STA DemoDone
    JMP .moved

.manual:
    LDA SWCHA
    AND #$40                ; left?
    BNE .manualRight
    LDA PlayerX
    BNE .decX
    JSR TryLeftExit
    JMP .manualY
.decX:
    DEC PlayerX
    JMP .manualY
.manualRight:
    LDA SWCHA
    AND #$80                ; right?
    BNE .manualY
    LDA PlayerX
    CMP #PLAYER_MAX_X
    BNE .incX
    JSR TryRightExit
    JMP .manualY
.incX:
    INC PlayerX
    JMP .manualY

.manualY:
    LDA SWCHA
    AND #$20                ; down?
    BNE .manualUp
    LDA PlayerRow
    CMP #PLAYER_MAX_ROW
    BEQ .moved
    INC PlayerRow
    JMP .moved
.manualUp:
    LDA SWCHA
    AND #$10                ; up?
    BNE .moved
    LDA PlayerRow
    BEQ .moved
    DEC PlayerRow
    JMP .moved

.moveRight:
    LDA PlayerX
    CMP #PLAYER_MAX_X
    BNE .incX2
    JSR TryRightExit
    JMP .moved
.incX2:
    INC PlayerX
    JMP .moved
.moved:

; -----------------------------------------------------------------------------
; 5. PICKUP — the hardware's P0/P1 latch picks the key up
; -----------------------------------------------------------------------------
; CXPPMM bit 7 is the P0/P1 collision.  If it is set and the key is not
; already held, the key changes state: from now on it is drawn above P0 and
; its record is ignored.  CXCLR then clears every latch for the next frame.
    LDA CXPPMM
    AND #$80
    BEQ .noPickup
    LDA KeyHeld
    BNE .noPickup
    LDA #$01
    STA KeyHeld
.noPickup:
    LDA #$00
    STA CXCLR

; -----------------------------------------------------------------------------
; 6. LOAD THE ROOM — the one interpreter, pointed at the new record
; -----------------------------------------------------------------------------
    JSR LoadRoom

; --- an opened locked door stays open for the rest of the room visit --------
    LDA DoorOpen
    BEQ .noDoorOverride
    LDA #$00
    STA DoorOn
.noDoorOverride:

; --- the ball's width comes from the door object's graphic index ------------
    LDA #$01
    STA CTRLPF              ; REFLECT, 1-pixel ball by default
    LDA DoorOn
    BEQ .noDoorSize
    LDX DoorGfx
    LDA BallSizeTable,X
    ORA #$01
    STA CTRLPF
.noDoorSize:

; --- compute the room's row 0 before the picture starts ----------------------
; The room band starts with row 0, so its three values must be ready before
; the first room line.  Computing them here (rather than in the band's first
; line) keeps the band's four-line budget intact and means a player at
; PlayerRow=0 draws its top four scanlines instead of losing them.
    LDA #$00
    STA RoomRow
    JSR ComputeP0
    JSR ComputeP1
    JSR ComputeBL

; --- clear the status missiles' fine registers outside the HMOVE window ----
; The reset HMOVE positioned M0/M1 with their fine offsets; the per-frame
; HMOVE applies all five HM registers, so HMM0/HMM1 must be zero before it.
; These writes are in VBLANK, far outside the 24-cycle HMOVE window.
    LDA #$00
    STA HMM0
    STA HMM1

; -----------------------------------------------------------------------------
; 7. POSITION P0/P1/BL — three coarse strobes, one HMOVE
; -----------------------------------------------------------------------------
; The Lesson 29 rule: every object's coarse position is set first, then one
; HMOVE applies all five fine registers.  A second HMOVE would re-apply them
; and walk the objects left; there is exactly one per frame.
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA KeyX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
    LDA DoorX
    CLC
    ADC #DOOR_BIAS
    JSR SetCoarseBL
    STA WSYNC
    STA HMOVE

; --- the status band's colours and clear playfield are latched now -----------
; The room band writes its own colours and walls after the status band; the
; status band must start from a clean PF and its own two indicator colours.
; Setting them in VBLANK (rather than after the picture starts) is what lets
; the status band's first line be line 0 instead of a wasted setup line.
    LDA #$00
    STA COLUBK
    STA PF0
    STA PF1
    STA PF2
    LDA #C_STATUS_M0
    STA COLUP0
    LDA #C_STATUS_M1
    STA COLUP1

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
BodyStart:                  ; checkpoint: scanline 37/5, visible line 0

; =============================================================================
; VISIBLE LINES 0-23: THE STATUS BAND (the room gauge and the key block)
; =============================================================================
; Six rows of four lines.  M0 is enabled for rows 1 .. Room+1 (4 lines per
; room step); M1 for rows 1-2 while the key is held.  Both are missiles, so
; they are independent of the P0/P1 graphics the room band uses.  The band's
; colours and clear playfield were latched in VBLANK, so the first line can
; store its enables here; the first line's stores complete at cycle 18, well
; before the beam reaches pixel 0 at 22.67.  Row 0 then needs only three
; more lines, and rows 1-5 use the four-line compute split.
    LDA #$00
    STA StatusRow
    STA ENAM0
    TAY                     ; Y = 0 for all of row 0's prelude stores
    STY ENAM1
; --- row 0 is blank: every prelude store is zero, never the next enable ------
; The two computes fill TmpM0/TmpM1 for row 1, but they must not reach the
; missile registers until row 1 starts.  STY stores Y = 0 on lines 2-4, so
; row 0 is four blank lines; M0 is computed on line 0, M1 on line 1, and the
; loop enters with row 1's values after line 4.
    LDA #$01
    STA StatusRow
    JSR ComputeM0
    STA WSYNC               ; row 0, line 2
    STY ENAM0
    STY ENAM1
    JSR ComputeM1
    STA WSYNC               ; row 0, line 3
    STY ENAM0
    STY ENAM1
    STA WSYNC               ; row 0, line 4
    STY ENAM0
    STY ENAM1
; --- rows 1-5: four lines each, M0 on line 1 and M1 on line 2 --------------
    LDA TmpM0
    LDY TmpM1
    LDX #$05                ; rows 1-5
StatusLoop:
    STA WSYNC
    STA ENAM0
    STY ENAM1
    STA CurM0
    STY CurM1
    INC StatusRow
    JSR ComputeM0
    LDA CurM0
    LDY CurM1
    STA WSYNC
    STA ENAM0
    STY ENAM1
    JSR ComputeM1
    LDA CurM0
    LDY CurM1
    STA WSYNC
    STA ENAM0
    STY ENAM1
    LDA CurM0
    LDY CurM1
    STA WSYNC
    STA ENAM0
    STY ENAM1
    DEX
    BEQ StatusDone
    LDA TmpM0
    LDY TmpM1
    JMP StatusLoop
StatusDone:
; Do NOT clear the missiles here: the write would land before pixel 0 of the
; last status line and blank its missile pixel.  Room 4's gauge would lose
; its twentieth line.  The clear belongs in the room setup, after this
; line's pixel 0 (see the room band's setup).

; =============================================================================
; VISIBLE LINES 24-167: THE ROOM (36 rows x 4 lines)
; =============================================================================
; The room's colour and playfield are staged by LoadRoom.  The setup below
; runs on the status band's last line after pixel 0; its COLUPF/PF writes can
; show on the right part of that line (a one-line top seam), and COLUP0 is
; written last so room 4's gauge keeps its status green.  Each row is drawn
; on four lines, and the four lines are also the engine's four compute slots:
;
;   line 1   store row N, save the values, compute row N+1's P0
;   line 2   store row N, compute row N+1's P1
;   line 3   store row N, compute row N+1's BL
;   line 4   store row N, apply row N+1's playfield/colour effects,
;            load row N+1 into A/X/Y
;
; The split is what keeps every row exactly four lines: the whole compute is
; about 100 cycles, which does not fit in one 76-cycle line, but each quarter
; does.  Row 0 is computed in VBLANK (after LoadRoom) and loaded here; the
; loop's first line stores row 0, then increments to 1 and computes row 1.
    LDA WallColor
    STA COLUPF
    LDA KeyColor
    STA COLUP1
    LDA WallPF0
    STA PF0
    LDA WallPF1
    STA PF1
    LDA WallPF2
    STA PF2
; COLUP0 is written last on purpose: the M0 gauge uses COLUP0, and room 4's
; gauge runs through this line.  Writing COLUP0 after the PF writes leaves
; the gauge's last-line pixels their status green; the room's first line
; still gets the player colour (the write lands after this line's pixel 0).
    LDA #C_PLAYER
    STA COLUP0
; The status band's last line has now passed pixel 0, so this clear lands on
; the room's first line: the last gauge line keeps its missile pixel, and the
; room never inherits M0/M1.  (A room-line clear after STA WSYNC would either
; clobber A or push the graphics stores past pixel 0.)
    LDA #$00
    STA ENAM0
    STA ENAM1
    LDA TmpP0
    LDX TmpP1
    LDY TmpBL               ; row 0's values, computed in VBLANK
RoomStart:                  ; checkpoint: the status band ends here; the first
                            ; room line follows (visible line 24)
RoomLoop:
    STA WSYNC
    STA GRP0
    STX GRP1
    STY ENABL
    STA CurP0
    STX CurP1
    STY CurBL
    INC RoomRow
    JSR ComputeP0
    LDA CurP0
    LDX CurP1
    LDY CurBL
    STA WSYNC
    STA GRP0
    STX GRP1
    STY ENABL
    JSR ComputeP1
    LDA CurP0
    LDX CurP1
    LDY CurBL
    STA WSYNC
    STA GRP0
    STX GRP1
    STY ENABL
    JSR ComputeBL
    LDA CurP0
    LDX CurP1
    LDY CurBL
    STA WSYNC
    STA GRP0
    STX GRP1
    STY ENABL
    JSR RowEffects
    LDA RoomRow
    CMP #ROOM_ROWS
    BEQ RoomDone
    LDA TmpP0
    LDX TmpP1
    LDY TmpBL
    JMP RoomLoop
RoomDone:

; =============================================================================
; VISIBLE LINES 168-191: THE LOWER BAND (the floor and its edge line)
; =============================================================================
; The last room row may still be holding the player's row-35 graphics, so
; the first lower line clears GRP0/GRP1/ENABL before its visible pixels.
; The edge line is a true 160-pixel line for three of the first lower row's
; four lines: PF0/PF1/PF2 = $FF for all 20 playfield blocks, mirrored by
; REFLECT.  The PF clear runs at the start of the fourth line, so that line
; is already floor; the rest of the band is the floor colour.
    LDA #$FF
    STA PF0
    STA PF1
    STA PF2
    LDA #C_FLOOR
    STA COLUBK
    STA WSYNC               ; first lower line
    LDA #$00
    STA GRP0
    STA GRP1
    STA ENABL
    STA WSYNC
    STA WSYNC
    STA WSYNC
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDX #(LOWER_ROWS - 1)
LowerStart:                 ; checkpoint: the lower loop's first WSYNC (visible line 172)
LowerLoop:
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    DEX
    BNE LowerLoop

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
    LDA #$02
OverscanStart:              ; checkpoint: scanline 229/6, the first blanked line
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; RESETGAME — the power-on state, also the SELECT reset
; =============================================================================
ResetGame:
    LDA #$00
    STA Room
    STA KeyHeld
    STA KeyOn
    STA DoorOn
    STA DoorOpen
    STA DoorLocked
    STA CarryGfxOffset
    STA DemoDone
    STA FrameLo
    STA FrameHi
    LDA #C_KEY              ; the default carried colour is the key's gold;
    STA CarryColor          ; a pickup overwrites it with the object's colour
    LDA #$01
    STA AutoDemo
    LDA #145
    STA PlayerX
    LDA #13
    STA PlayerRow
    LDA PlayerX
    STA PrevX
    LDA PlayerRow
    STA PrevRow
    LDA #$00
    STA CXCLR
    RTS

; =============================================================================
; TRYLEFTEXIT / TRYRIGHTEXIT — the room record's exit bytes, applied
; =============================================================================
; The exit works only when the player's four-row body is fully inside the
; corridor: rows 10..14 (row + 3 <= 17).  $FF means the room is the end of
; the corridor in that direction.
TryLeftExit:
    LDA LeftExit
    CMP #$FF
    BEQ .lno
    LDA PlayerRow
    CMP #EXIT_MIN_ROW
    BCC .lno
    CMP #(EXIT_MAX_ROW + 1)
    BCS .lno
    LDA LeftExit
    STA Room
    LDA #$00
    STA DoorOpen
    LDA #148                ; enter from the right edge
    STA PlayerX
    STA PrevX
    LDA PlayerRow
    STA PrevRow
.lno:
    RTS

TryRightExit:
    LDA RightExit
    CMP #$FF
    BEQ .rno
    LDA PlayerRow
    CMP #EXIT_MIN_ROW
    BCC .rno
    CMP #(EXIT_MAX_ROW + 1)
    BCS .rno
    LDA RightExit
    STA Room
    LDA #$00
    STA DoorOpen
    LDA #4                  ; enter from the left edge
    STA PlayerX
    STA PrevX
    LDA PlayerRow
    STA PrevRow
.rno:
    RTS

; =============================================================================
; LOADROOM — read one room record and point the engine at its objects
; =============================================================================
; RoomTable is eight bytes per record, so the base is Room * 8.  The
; object scan uses the room record's first index and count; the room byte in
; each object record is a second check, so a record with the wrong room is
; skipped while the first/count slice keeps the scan short.
; The carried key is not a room object: it is placed above the player here,
; and the scan skips pickups while KeyHeld is set.
LoadRoom:
    LDA Room
    ASL
    ASL
    ASL
    TAX                     ; X = Room * 8
    LDA RoomTable+0,X
    STA WallPF0
    LDA RoomTable+1,X
    STA WallPF1
    LDA RoomTable+2,X
    STA WallPF2
    LDA RoomTable+3,X
    STA WallColor
    LDA RoomTable+4,X
    STA LeftExit
    LDA RoomTable+5,X
    STA RightExit
    LDA RoomTable+6,X
    STA FirstObj
    LDA RoomTable+7,X
    STA ObjCount

; --- the defaults before the scan --------------------------------------------
    LDA #$00
    STA KeyOn
    STA DoorOn
    STA DoorLocked
    STA KeyX
    STA DoorX
    LDA #C_KEY
    STA KeyColor
    LDA #C_DOOR
    STA DoorColor
    LDA #GFX_DOOR
    STA DoorGfx

; --- the carried key is drawn above the player, not from a record ------------
    LDA KeyHeld
    BEQ .scan
    LDA #$01
    STA KeyOn
    LDA PlayerX
    STA KeyX
    LDA PlayerRow
    SEC
    SBC #4                  ; four rows above the player
    BCS .haveRow
    LDA #$00
.haveRow:
    STA KeyRow
    LDA CarryGfxOffset
    STA KeyGfxOffset
    LDA CarryColor
    STA KeyColor

; --- the room's own objects --------------------------------------------------
.scan:
    LDA FirstObj
    STA ObjIndex
    LDA ObjCount
    STA TmpCount
    BEQ .lrDone
.scanLoop:
    LDX ObjIndex
    LDA ObjectBase,X
    TAX                     ; X = object index * 6
    LDA ObjectTable+OBJ_ROOM,X
    CMP Room
    BNE .next
    LDA ObjectTable+OBJ_BEH,X
    CMP #BEH_PICKUP
    BNE .checkStatic
    LDA KeyHeld
    BNE .next               ; one carried object at a time
    LDA KeyOn
    BNE .next
    LDA #$01
    STA KeyOn
    LDA ObjectTable+OBJ_X,X
    STA KeyX
    LDA ObjectTable+OBJ_Y,X
    LSR
    LSR                     ; pixels / 4 = the 4-line row
    STA KeyRow
    LDA ObjectTable+OBJ_GFX,X
    ASL
    ASL                     ; graphic index * 4 bytes
    STA KeyGfxOffset
    STA CarryGfxOffset
    LDA ObjectTable+OBJ_COLOR,X
    STA KeyColor
    STA CarryColor
    JMP .next

.checkStatic:
    CMP #BEH_STATIC
    BEQ .staticDoor
    CMP #BEH_LOCKED
    BNE .next
    LDA #$01
    STA DoorLocked
    JMP .doorRecord
.staticDoor:
    LDA #$00
    STA DoorLocked
.doorRecord:
    LDA DoorOn
    BNE .next
    LDA #$01
    STA DoorOn
    LDA ObjectTable+OBJ_X,X
    STA DoorX
    LDA ObjectTable+OBJ_Y,X
    LSR
    LSR
    STA DoorRow
    LDA ObjectTable+OBJ_GFX,X
    STA DoorGfx
    LDA ObjectTable+OBJ_COLOR,X
    STA DoorColor
.next:
    INC ObjIndex
    DEC TmpCount
    BNE .scanLoop
.lrDone:
    RTS

; =============================================================================
; COMPUTEP0 / COMPUTEP1 / COMPUTEBL — one graphic byte each for a room row
; =============================================================================
; A = the P0 graphic byte, X = the P1 graphic byte, Y = the ball enable.
; The three routines are the skipdraw idea from Lesson 74 with a relaxed
; budget: row - top, and a carry test for "outside".  The playfield gap and
; the door colour are RowEffects' job, not these routines'.
ComputeP0:
    LDA RoomRow
    SEC
    SBC PlayerRow
    CMP #4
    BCS .cp0Blank
    TAY
    LDA PlayerGfx,Y
    STA TmpP0
    RTS
.cp0Blank:
    LDA #$00
    STA TmpP0
    RTS

ComputeP1:
    LDA KeyOn
    BEQ .cp1Blank
    LDA RoomRow
    SEC
    SBC KeyRow
    CMP #4
    BCS .cp1Blank
    CLC
    ADC KeyGfxOffset
    TAY
    LDA ObjGfxTable,Y
    STA TmpP1
    RTS
.cp1Blank:
    LDA #$00
    STA TmpP1
    RTS

ComputeBL:
    LDA DoorOn
    BEQ .cbBlank
    LDA RoomRow
    SEC
    SBC DoorRow
    CMP #4
    BCS .cbBlank
    LDA #$02
    STA TmpBL
    RTS
.cbBlank:
    LDA #$00
    STA TmpBL
    RTS

; RowEffects applies the row's playfield and colour side effects on the
; fourth line of the previous row.  The writes complete before the next
; row's first line, so the next row is fully correct; the fourth line
; itself can show the old value for its first pixels because the write
; lands after pixel 0 (a one-scanline seam at the boundary).  The door's
; colour is set for the whole exit corridor, not row by row: the corridor
; has no playfield, so only the ball shows COLUPF there, and the two
; checks replace a per-row door compare that did not fit the line.
RowEffects:
    LDA RoomRow
    CMP #EXIT_TOP
    BEQ .reGap
    CMP #(EXIT_BOTTOM + 1)
    BEQ .reRestore
    RTS
.reGap:
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA DoorOn
    BEQ .reGapDone
    LDA DoorColor
    STA COLUPF
.reGapDone:
    RTS
.reRestore:
    LDA WallPF0
    STA PF0
    LDA WallPF1
    STA PF1
    LDA WallPF2
    STA PF2
    LDA WallColor
    STA COLUPF
    RTS

; =============================================================================
; COMPUTEM0 / COMPUTEM1 — one enable each, for the next status row
; =============================================================================
; Row 0 is blank; the gauge runs for rows 1 .. Room+1, the key block for
; rows 1-2 while the key is held.  The split lets each compute live on its
; own scanline inside the 76-cycle budget.
ComputeM0:
    LDA #$00
    STA TmpM0
    LDA StatusRow
    CMP #1
    BCC .cm0Done
    LDA Room
    CLC
    ADC #2                  ; Room + 2: the first row past the gauge
    STA Tmp
    LDA StatusRow
    CMP Tmp
    BCS .cm0Done
    LDA #$02
    STA TmpM0
.cm0Done:
    RTS

ComputeM1:
    LDA #$00
    STA TmpM1
    LDA StatusRow
    CMP #1
    BCC .cm1Done
    CMP #3
    BCS .cm1Done
    LDA KeyHeld
    BEQ .cm1Done
    LDA #$02
    STA TmpM1
.cm1Done:
    RTS

; =============================================================================
; COARSE POSITIONING — five routines, no HMOVE here
; =============================================================================
; Input: A = the biased target (target + 3).  The routines are separate
; because each one writes a different RESxx/HMxx pair; the caller runs all
; of them and then strobes HMOVE once.  The divide-by-15 loop spends five
; cycles per 15 colour clocks; the remainder becomes the high nibble of the
; fine register.
SetCoarseP0:
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

SetCoarseP1:
    STA WSYNC
    SEC
.divP1:
    SBC #15
    BCS .divP1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
    STA RESP1
    RTS

SetCoarseBL:
    STA WSYNC
    SEC
.divBL:
    SBC #15
    BCS .divBL
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMBL
    STA RESBL
    RTS

SetCoarseM0:
    STA WSYNC
    SEC
.divM0:
    SBC #15
    BCS .divM0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMM0
    STA RESM0
    RTS

SetCoarseM1:
    STA WSYNC
    SEC
.divM1:
    SBC #15
    BCS .divM1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMM1
    STA RESM1
    RTS

; =============================================================================
; THE ROOM TABLE — four 8-byte records (index = Room * 8)
; =============================================================================
; Read down a column.  The playfield patterns are all built from PF0=$10
; (a four-pixel side wall, mirrored to the right edge) plus interior pillars;
; the exit corridor zeroes all three bytes for rows 10-17.  The colours are
; the room's identity: red, green, orange, blue.
RoomTable:
    ; room 0: side walls + pillars at blocks 4 and 11
    !byte $10, $81, $00, C_WALL0, $FF, $01, 0, 1
    ; room 1: side walls + a central pair; gem, key, door
    !byte $10, $00, $18, C_WALL1, $00, $02, 1, 3
    ; room 2: side walls + pillars; the locked door
    !byte $10, $24, $00, C_WALL2, $01, $03, 4, 1
    ; room 3: side walls + a four-block band; key and door
    !byte $10, $C3, $00, C_WALL3, $02, $FF, 5, 2

; =============================================================================
; THE OBJECT TABLE — seven 6-byte records
; =============================================================================
; x, y, graphic, colour, behaviour, room.
; The room-0 record is the door in the corridor; room 1 has the gem, the key
; and a door; room 2 has the locked door; room 3 has a second key and a door.
; Room 1 has TWO pickup records, but the scan takes the first (the gem): the
; P1 slot is then full, and the key record is skipped and not drawn while the
; gem is carried.  Every drawn room still uses one pickup and one static
; object, which is what the P1/ball pair can show without flicker.
ObjectTable:
    ; room 0: the first door
    !byte 128, 40, GFX_DOOR, C_DOOR, BEH_STATIC, 0
    ; room 1: the gem, the key and the door
    !byte 40,  52, GFX_GEM,  C_GEM,  BEH_PICKUP, 1
    !byte 112, 52, GFX_KEY,  C_KEY,  BEH_PICKUP, 1
    !byte 128, 40, GFX_DOOR, C_DOOR, BEH_STATIC, 1
    ; room 2: the locked door ahead of the demo
    !byte 112, 48, GFX_DOOR, C_DOOR, BEH_LOCKED, 2
    ; room 3: the second key and its door
    !byte 96,  48, GFX_KEY,  C_KEY,  BEH_PICKUP, 3
    !byte 128, 40, GFX_DOOR, C_DOOR, BEH_STATIC, 3

; ObjectBase is the record index times six: ObjectTable is an array of
; six-byte records, and the 6502 has no multiply, so the table does it.
ObjectBase:
    !byte 0, 6, 12, 18, 24, 30, 36

; The ball is the door.  CTRLPF bits 4-5 choose 1/2/4/8 pixels; the high
; nibble of each entry is ORed with the REFLECT bit.
BallSizeTable:
    !byte $00               ; index 0 unused (the key's sprite index)
    !byte $30               ; index 1: 8 pixels
    !byte $20               ; index 2: 4 pixels

; The sprite graphics are four bytes, one byte per 4-line row.  Index 0 is
; the key; index 1 is the gem the stretch exercise adds.
ObjGfxTable:
    ; index 0: the key
    !byte %00111100
    !byte %01100110
    !byte %00011000
    !byte %00010100
    ; index 1: the gem
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %00111100

; P0's graphic: an 8x16 adventurer, four 4-line rows.
PlayerGfx:
    !byte %00111100
    !byte %01111110
    !byte %01111110
    !byte %00100100

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
