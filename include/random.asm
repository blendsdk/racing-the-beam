; =============================================================================
; RANDOM.ASM — An 8-bit Galois LFSR for the Atari 2600
; =============================================================================
;
; This library produces pseudo-random bytes with a Galois linear feedback
; shift register (LFSR).  It is the shared random-number source used by
; Lesson 43.  Source it inside the ROM area (after * = $F000) so its routines
; get an address.  The lesson sources it before Reset so the kernel can use
; RandomSeed and RandomHistory without forward declarations; ACME needs a
; zero-page symbol to be defined before its first use to pick the two-byte
; addressing mode.
;
; -----------------------------------------------------------------------------
; API
; -----------------------------------------------------------------------------
;   RandomInit   A = the seed.  Stores it in RandomSeed.  A zero seed is
;                replaced by $5A, because an LFSR locked at zero stays at
;                zero forever.  Returns A = the seed actually stored.
;
;   Random       One Galois step.  Returns A = the new seed.  The sequence
;                has period 255 for every nonzero seed and never reaches
;                zero from a nonzero seed.
;
;   RandomMask   A = the mask.  Returns A = RandomSeed AND the mask.  A mask
;                of $01, $03, $07, or $0F selects a power-of-two range
;                without a division (the 6502 has no divide instruction).
;
;   RandomPush   Shift RandomHistory down one byte (entry 6 becomes entry 7,
;                ...) and store RandomSeed at RandomHistory+0.  Returns
;                A = the seed.  The lesson's 8-row history grid reads these
;                eight bytes: row 0 is the newest seed, row 7 the oldest.
;
; -----------------------------------------------------------------------------
; RAM
; -----------------------------------------------------------------------------
; The library owns $A0-$A8.  `+clean_start` zeroes all of it.
;
;   $A0      RandomSeed      the 8-bit state; must be nonzero
;   $A1-$A8  RandomHistory   the eight most recent seeds, newest at +0
;
; -----------------------------------------------------------------------------
; THE POLYNOMIAL
; -----------------------------------------------------------------------------
; One step is:
;
;       LDA RandomSeed
;       ASL                 ; bit 7 -> carry; bit 0 becomes 0
;       BCC RandomNoEor
;       EOR #$1D            ; the taps: bits 0, 2, 3, and 4
; RandomNoEor:
;       STA RandomSeed
;
; The $1D polynomial is maximal-length for the 8-bit Galois form: starting
; from any nonzero seed, the register visits all 255 nonzero bytes and then
; returns to the start.  Zero is the one fixed point (0 -> 0), which is why
; the seed-accepting entry points guard it: RandomInit substitutes $5A, and
; the lesson's fire and joystick paths never store zero.
;
; -----------------------------------------------------------------------------
; WHY THE GALOIS FORM?
; -----------------------------------------------------------------------------
; The Fibonacci form XORs several bits of the state on every step.  The Galois
; form shifts the whole register and XORs the polynomial only when a one falls
; off the end.  On the 6502 the step core is LDA (3), ASL (2), BCC (3 taken or
; 2 not taken), and STA (3): 11 cycles when the branch is taken (no feedback)
; and 12 when the EOR (2) also runs.  The JSR and RTS add 12 more.  The
; lesson's 16-bit exercise keeps the same shape: ASL lo / ROL hi / EOR #$2D on
; the low byte.
; =============================================================================

; -----------------------------------------------------------------------------
; RAM MAP
; -----------------------------------------------------------------------------
RandomSeed    = $A0     ; the 8-bit state; zero would freeze the sequence
RandomHistory = $A1     ; eight bytes: the newest seed is at +0

; =============================================================================
; RandomInit — A = seed; a zero seed becomes $5A.
; =============================================================================
; The zero guard is not decoration.  Every other value is a valid state, but
; zero is the fixed point: 0 << 1 is 0, the carry is clear, and the EOR never
; runs.  A seed of zero would therefore show the same byte forever.
RandomInit:
    STA RandomSeed
    BNE RandomInitDone      ; nonzero: keep it
    LDA #$5A                ; zero: use the lesson's default seed
    STA RandomSeed
RandomInitDone:
    RTS                     ; A = the seed that was stored

; =============================================================================
; Random — one Galois step; A = the new seed.
; =============================================================================
Random:
    LDA RandomSeed
    ASL                     ; shift left; the old bit 7 lands in the carry
    BCC RandomNoEor         ; a zero fell off the end: no feedback
    EOR #$1D                ; a one fell off: apply the polynomial
RandomNoEor:
    STA RandomSeed
    RTS

; =============================================================================
; RandomMask — A = mask; returns A = RandomSeed AND the mask.
; =============================================================================
; The 6502 has no divide, and a general modulo needs a loop of subtracts.
; A power-of-two-minus-one mask is one AND.  $07 gives 0-7, $0F gives 0-15,
; and $03 gives 0-3.
RandomMask:
    AND RandomSeed
RandomMaskDone:             ; checkpoint: A = RandomSeed AND the mask
    RTS

; =============================================================================
; RandomPush — shift the history down and store the seed at +0.
; =============================================================================
; Entry 6 moves to 7, 5 to 6, ... and 0 to 1; then the current seed becomes
; the new entry 0.  The oldest byte (entry 7) is discarded.  Zero-page,X with
; the base RandomHistory-1 lets one index walk the source byte one below the
; destination, so the copy never overwrites a byte it has not read yet.
RandomPush:
    LDX #7
RandomPushLoop:
    LDA RandomHistory-1,X   ; X=7: entry 6; ...; X=1: entry 0
    STA RandomHistory,X     ; X=7: entry 7; ...; X=1: entry 1
    DEX
    BNE RandomPushLoop
    LDA RandomSeed
    STA RandomHistory       ; entry 0 = the newest seed
RandomPushDone:             ; checkpoint: A = the seed stored at +0
    RTS
