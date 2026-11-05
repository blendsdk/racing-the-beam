; =============================================================================
; SCORE.ASM — A six-digit, 48-pixel score for the Atari 2600
; =============================================================================
;
; This library draws six digits with two players in three-copy close mode and
; keeps the score as six decimal digits.  It is the shared scoreboard used by
; Lessons 39 and 40.  Source it AFTER include/vcs.asm, because it uses the TIA
; register names defined there.
;
; -----------------------------------------------------------------------------
; API
; -----------------------------------------------------------------------------
;   ScoreInit                 Zero ScoreDigits and ScoreBuf.  The screen is
;                             blank after this call; call ScoreClear to draw
;                             six zeros.
;   ScoreClear                Set all six digits to 0 and rebuild the buffer,
;                             so the display reads 000000.
;   ScoreSetup                NUSIZ0=NUSIZ1=3 (three copies, close),
;                             VDELP0=VDELP1=1, position P0 at TIA X=56 and
;                             P1 at X=64, then strobe ONE HMOVE.  The caller
;                             sets COLUP0 and COLUP1 (the lesson uses white).
;   ScoreSetDigit             A = position 0-5 (0 = leftmost), X = digit 0-9.
;                             Stores the digit in ScoreDigits and copies all
;                             eight bytes of that column from
;                             ScoreFont + digit*8.
;   ScoreAddOne               Add 1 to the six-digit decimal number.  Returns
;                             C=1 on 999999 -> 000000, C=0 otherwise.
;   ScoreDraw                 Draw the 8 rows of the score.  Consumes NINE
;                             visible lines: line 0 is the setup/blank line,
;                             lines 1-8 are the eight rows, and the cleanup
;                             shares line 8.  Call it once per frame at the
;                             top of the visible area.
;   ScoreFont                 Ten glyphs x eight bytes, bottom-up.
;
; -----------------------------------------------------------------------------
; RAM
; -----------------------------------------------------------------------------
; The library owns $A0-$D7.  `+clean_start` zeroes all of it.
;
;   $A0-$A5  ScoreDigits   six binary digits, left to right
;   $A6      ScoreRow      scratch: the row counter inside ScoreDraw
;   $A7      ScoreTmp      scratch: the third column's byte in ScoreDraw,
;                          and the digit saved while ScoreSetDigit copies
;   $A8-$D7  ScoreBuf      48 bytes: six columns x eight rows, column-major,
;                          bottom-up (column 0 row 0 is $A8; column 1 row 0
;                          is $B0; ...; column 5 row 7 is $D7)
;
; ScoreRow and ScoreTmp hold no state between calls.  The caller's persistent
; state is ScoreDigits and ScoreBuf.
;
; -----------------------------------------------------------------------------
; WHY "BOTTOM-UP"?
; -----------------------------------------------------------------------------
; ScoreDraw counts Y down from 7 to 0 because the Staugas kernel is timed from
; the top row of the display to the bottom.  Font byte 0 is the bottom row and
; font byte 7 is the top row, so ScoreSetDigit can copy a glyph straight into
; a column without reversing it.  Every glyph's byte 0 is $00: the cell is
; 8 pixels tall but the bottom row is empty, so the lit part of a digit is
; seven scanlines.
;
; -----------------------------------------------------------------------------
; THE 48-PIXEL TRICK
; -----------------------------------------------------------------------------
; A player is 8 pixels wide.  NUSIZ=3 gives three close copies at X, X+16 and
; X+32.  With P0 at 56 and P1 at 64 the copies interleave:
;
;   P0 copy 0  X=56   P1 copy 0  X=64
;   P0 copy 1  X=72   P1 copy 1  X=80
;   P0 copy 2  X=88   P1 copy 2  X=96
;
; That is six 8-pixel digits across 48 pixels.  The kernel changes GRP0/GRP1
; between the copies so each copy shows a different column.  VDELP0/VDELP1
; keep the writes from tearing: a write stages a pending byte and the other
; player's write commits it, so each column can be placed just before its copy.
; Without VDEL, a store that landed inside a copy's eight-pixel window would
; change the byte halfway through that cell and tear it.
;
; The six data stores and the final flush are the whole trick.  The order and
; the cycle count are not decoration: moving one instruction changes which
; copy receives which byte.  Do not "clean up" the NOP or the CPX.
; =============================================================================

; -----------------------------------------------------------------------------
; RAM MAP
; -----------------------------------------------------------------------------
ScoreDigits = $A0       ; six digits, 0 = leftmost, 5 = rightmost
ScoreRow    = $A6       ; scratch: the kernel's row counter (7..0)
ScoreTmp    = $A7       ; scratch: column 3's byte / a saved digit
ScoreBuf    = $A8       ; 48 bytes: column-major, bottom-up

SCORE_P0_X  = 56        ; the leftmost digit's TIA X
SCORE_P1_X  = 64        ; 8 pixels right: the second digit
SCORE_BIAS  = 3         ; the SetHorizPos output-delay bias from Lesson 26

; =============================================================================
; ScoreInit — zero the six digits and the 48-byte buffer.
; =============================================================================
; The display is blank after this call.  ScoreClear turns the blank buffer
; into six zero glyphs.
ScoreInit:                  ; checkpoint: runs once at reset
    LDA #0
    LDX #6
ScoreInitDigits:
    DEX
    STA ScoreDigits,X
    BNE ScoreInitDigits

    LDX #48
ScoreInitBuf:
    DEX
    STA ScoreBuf,X
    BNE ScoreInitBuf
    RTS

; =============================================================================
; ScoreClear — set every digit to 0 and rebuild the buffer, so it reads 000000.
; =============================================================================
ScoreClear:
    LDA #0
    LDX #6
ScoreClearDigits:
    DEX
    STA ScoreDigits,X
    BNE ScoreClearDigits

    LDX #0
ScoreClearLoop:
    TXA
    PHA                     ; save the position
    PHA                     ; and a second copy for the call
    LDA #0
    TAX                     ; X = digit 0
    PLA                     ; A = position
    JSR ScoreSetDigit
    PLA                     ; A = position
    TAX
    INX
    CPX #6
    BNE ScoreClearLoop
    RTS

; =============================================================================
; ScoreSetup — three-copy close mode, VDEL on, P0 at 56 and P1 at 64.
; =============================================================================
; The caller sets COLUP0/COLUP1.  Both coarse RESxx strobes and both fine
; HMPx values are set first, then ONE HMOVE applies both offsets in one
; HBLANK (the one-HMOVE rule from Lessons 28 and 29).  If the lesson also
; positions the ball in this frame, it sets HMBL/RESBL before this call and
; the same HMOVE applies the ball's fine offset too.
ScoreSetup:
    LDA #$03                ; NUSIZ 3 = three copies, close spacing
    STA NUSIZ0
    STA NUSIZ1
    LDA #$01                ; VDEL bit 0 = delay this player one line
    STA VDELP0
    STA VDELP1
    LDA #(SCORE_P0_X + SCORE_BIAS)
    JSR ScoreSetupP0
    LDA #(SCORE_P1_X + SCORE_BIAS)
    JSR ScoreSetupP1
    RTS

; --- the divide-by-15 positioning routine, one copy per player --------------
; A = the target TIA X plus SCORE_BIAS.  Each routine starts on a fresh line.
ScoreSetupP0:
    STA WSYNC
    SEC
ScoreSetupDiv0:
    SBC #15
    BCS ScoreSetupDiv0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    RTS

ScoreSetupP1:
    STA WSYNC
    SEC
ScoreSetupDiv1:
    SBC #15
    BCS ScoreSetupDiv1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
    STA RESP1
    STA WSYNC               ; the last coarse strobe is done; wait one line
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE               ; apply HMP0 and HMP1 in this HBLANK
HmoveDone:                  ; checkpoint: the store has executed (next line, cycle 3)
    RTS

; =============================================================================
; ScoreSetDigit — A = position 0-5, X = digit 0-9.
; =============================================================================
; Stores the digit in ScoreDigits[position] and copies the glyph's eight
; bytes from ScoreFont + digit*8 into ScoreBuf + position*8.
;
; The copy uses absolute,X for the font and absolute,Y for the buffer, so
; both offsets can move at once without a zero-page pointer:
;
;   LDA ScoreFont,X   ; X counts through the eight font bytes
;   STA ScoreBuf,Y    ; Y counts through the eight buffer bytes
;
; The loop stops when the low three bits of X wrap to 0, i.e. after exactly
; eight bytes, because X started at a multiple of eight.
ScoreDigitWrite:            ; checkpoint: A = position, X = digit
ScoreSetDigit:
    PHA                     ; save the position
    TXA
    PHA                     ; save the digit
    ASL
    ASL
    ASL
    TAX                     ; X = digit * 8 (the font offset)
    PLA                     ; A = digit
    STA ScoreTmp            ; keep the digit while we compute the position
    PLA                     ; A = position
    TAY                     ; Y = position
    LDA ScoreTmp
    STA ScoreDigits,Y       ; ScoreDigits[position] = digit
    TYA
    ASL
    ASL
    ASL
    TAY                     ; Y = position * 8 (the buffer offset)

ScoreSetCopy:
    LDA ScoreFont,X
    STA ScoreBuf,Y
    INX
    INY
    TXA
    AND #7
    BNE ScoreSetCopy
    RTS

; =============================================================================
; ScoreAddOne — add 1 to the six-digit decimal number.
; =============================================================================
; Starts at the rightmost digit (position 5).  A digit that reaches 10 wraps
; to 0 and carries one position left.  Every digit that changes is redrawn
; immediately, so ScoreBuf is always the picture of ScoreDigits.
;
; Returns C=1 on the 999999 -> 000000 overflow, C=0 otherwise.  The caller
; can use the carry to flash a "rollover" indicator (Lesson 40 does).
ScoreAddOne:
    LDX #5                  ; the rightmost digit
ScoreAddLoop:
    INC ScoreDigits,X
    LDA ScoreDigits,X
    CMP #10
    BCC ScoreAddStore
    LDA #0                  ; 9 + 1 = 10: write 0 and carry left
ScoreAddStore:
    STA ScoreDigits,X
ScoreAdd:                   ; checkpoint: A = the digit after the add
    ; Rebuild this column.  A = digit, X = position; ScoreSetDigit wants
    ; A = position, X = digit, so swap them through Y and the stack.
    TAY                     ; Y = digit
    TXA                     ; A = position
    PHA                     ; save the position for the carry test
    PHA                     ; and a second copy to pass to ScoreSetDigit
    TYA                     ; A = digit
    TAX                     ; X = digit
    PLA                     ; A = position
    JSR ScoreSetDigit
    PLA                     ; A = position
    TAX                     ; X = position
    LDA ScoreDigits,X       ; 0 means this digit wrapped: carry left
    BEQ ScoreAddCarry
    CLC                     ; no carry: the number did not overflow
    RTS
ScoreAddCarry:
    DEX
    BPL ScoreAddLoop
    SEC                     ; all six digits carried: 999999 -> 000000
    RTS

; =============================================================================
; ScoreDraw — the 8-row Staugas kernel.
; =============================================================================
; Preconditions: ScoreSetup has put P0/P1 in three-copy close mode, turned
; VDEL on, and positioned them at 56/64; ScoreBuf holds the six columns.
;
; The kernel consumes NINE visible lines.  On entry the CPU is at the start
; of visible line 0.  The first iteration loads the row-7 bytes and waits,
; so line 0 is a setup/blank line.  The row stores execute on visible lines
; 1-8 and are displayed on those same lines.  The cleanup (GRP0=0, GRP1=0,
; VDEL off) runs after line 8's copies and shares that line, so the caller's
; next code starts on visible line 9.
;
; The six stores, in column order:
;   col 0 -> GRP0   col 1 -> GRP1   col 2 -> GRP0
;   col 3 -> GRP1   col 4 -> GRP0   col 5 -> GRP1
; followed by the seventh STA GRP0 that commits column 5 to P1 through the
; cross-latch.
;
; The NOP and CPX are timing.  CPX reads ScoreRow only to burn three cycles;
; its flags are not used.  Removing either one moves the columns.
ScoreDraw:
    LDA #7
    STA ScoreRow            ; rows are drawn top (7) to bottom (0)
ScoreDrawLine:
    LDY ScoreRow
    LDA ScoreBuf+0,Y        ; column 0
    STA WSYNC               ; line 0: the setup/blank line
ScoreDrawRow:               ; checkpoint: the first row's stores (shown on line 1)
    STA GRP0                ; col 0
    LDA ScoreBuf+8,Y        ; column 1
    STA GRP1                ; col 1
    LDA ScoreBuf+16,Y       ; column 2
    STA GRP0                ; col 2
    LDA ScoreBuf+24,Y       ; column 3
    STA ScoreTmp            ; hold it: Y is needed for column 4's index
    LDA ScoreBuf+32,Y       ; column 4
    TAX
    LDA ScoreBuf+40,Y       ; column 5
    LDY ScoreTmp
    NOP                     ; timing: one cycle short of the copy window
    CPX ScoreRow            ; timing only; the flags are discarded
    STY GRP1                ; col 3
    STX GRP0                ; col 4
    STA GRP1                ; col 5
    STA GRP0                ; the seventh store: commit column 5 through the cross-latch
    DEC ScoreRow
    BPL ScoreDrawLine

    LDA #0
    STA GRP0                ; blank the players before the game zone
    STA GRP1
    STA VDELP0              ; VDEL is a score-only tool
    STA VDELP1
    RTS

; =============================================================================
; ScoreFont — ten glyphs, eight bytes each, stored bottom-up.
; =============================================================================
; Byte 0 is the bottom row; byte 7 is the top row.  Bit 7 is the leftmost
; pixel of the 8-pixel cell.  Every glyph's byte 0 is $00, so the visible
; part of a digit is seven scanlines tall.
ScoreFont:
    ; 0: a closed loop
    !byte $00, $3C, $66, $66, $76, $6E, $66, $3C
    ; 1: a stem with a wide base
    !byte $00, $7E, $18, $18, $18, $18, $38, $18
    ; 2: a top curve, a diagonal, and a wide base
    !byte $00, $7E, $30, $18, $0C, $06, $66, $3C
    ; 3: two curves joined in the middle
    !byte $00, $3C, $66, $06, $0C, $18, $0C, $7E
    ; 4: a diagonal and a crossbar
    !byte $00, $0C, $0C, $7E, $6C, $3C, $1C, $0C
    ; 5: a top bar, a middle curve, and a bottom curve
    !byte $00, $3C, $66, $06, $06, $7C, $60, $7E
    ; 6: a top curve and a closed bottom loop
    !byte $00, $3C, $66, $66, $7C, $60, $66, $3C
    ; 7: a wide top and a diagonal stem
    !byte $00, $18, $18, $18, $18, $0C, $66, $7E
    ; 8: two loops
    !byte $00, $3C, $66, $66, $3C, $66, $66, $3C
    ; 9: a closed top loop and a stem
    !byte $00, $3C, $66, $06, $3E, $66, $66, $3C
