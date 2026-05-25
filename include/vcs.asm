; =============================================================================
; VCS.ASM — Atari 2600 Hardware Register Definitions for ACME Assembler
; =============================================================================
;
; This file defines all the memory-mapped hardware registers for the
; Atari 2600's two custom chips:
;
;   TIA (Television Interface Adaptor) — graphics & sound  ($00-$3F)
;   RIOT (6532 RAM-I/O-Timer)          — RAM, I/O, timer   ($80-$FF)
;
; Usage: !source "include/vcs.asm"
;
; =============================================================================

; =============================================================================
; TIA WRITE REGISTERS ($00-$2C)
; =============================================================================
; These registers are ACTIVE — writing to them immediately affects the
; video output. Since the TIA has no frame buffer, you must update these
; in real-time as the TV beam scans across the screen.
; =============================================================================

; --- Vertical Sync & Blank ---
VSYNC   = $00   ; .... ..1. = start vertical sync (set bit 1)
VBLANK  = $01   ; 11.. ..1. = vertical blank control
                ;   bit 1: 1=blank screen, 0=show screen
                ;   bit 6: 1=latch paddle inputs
                ;   bit 7: 1=ground paddle capacitors

; --- Wait for Horizontal Sync ---
WSYNC   = $02   ; <strobe> Write ANY value to halt CPU until end of scanline
                ; This is how you "wait" for the beam to reach the right edge.
                ; The CPU literally stops running until the TIA signals HBLANK.

; --- Horizontal Sync Move ---
RSYNC   = $03   ; <strobe> Reset horizontal sync counter (rarely used)

; --- Player/Missile/Ball Size and Copies ---
NUSIZ0  = $04   ; Number-size for player 0 and missile 0
NUSIZ1  = $05   ; Number-size for player 1 and missile 1
                ;   bits 0-2: number of copies & spacing
                ;   bits 4-5: missile size (1,2,4,8 pixels)

; --- Color Registers ---
; Colors are encoded as: CCCCLLL0
;   C = color/hue (0-15), L = luminance (0-7), bit 0 unused
; NTSC has 128 colors, PAL has 104 colors.
COLUP0  = $06   ; Color for player 0 and missile 0
COLUP1  = $07   ; Color for player 1 and missile 1
COLUPF  = $08   ; Color for playfield and ball
COLUBK  = $09   ; Color for background
                ; This is the one you'll use first — it fills the whole screen!

; --- Playfield Control ---
CTRLPF  = $0A   ; Playfield control
                ;   bit 0: REF = 1: mirror right half, 0: repeat right half
                ;   bit 1: SCORE = 1: left half uses P0 color, right uses P1
                ;   bit 2: PFP = 1: playfield has priority over sprites
                ;   bits 4-5: ball size (1,2,4,8 pixels)

; --- Collision Enables ---
REFP0   = $0B   ; bit 3: reflect player 0 (flip horizontally)
REFP1   = $0C   ; bit 3: reflect player 1

; --- Playfield Registers ---
; The playfield is 20 bits wide (left half of screen), then mirrored or repeated.
; Each "pixel" is 4 color clocks wide = very chunky!
PF0     = $0D   ; Playfield 0: upper nibble used (bits 4-7), drawn LEFT to RIGHT
PF1     = $0E   ; Playfield 1: all 8 bits, drawn LEFT to RIGHT  (bit 7 first)
PF2     = $0F   ; Playfield 2: all 8 bits, drawn RIGHT to LEFT  (bit 0 first)

; --- Sprite Position Reset (Strobe) ---
; Writing to these sets the object's horizontal position to wherever the
; beam is RIGHT NOW. Then use HMxx + HMOVE to fine-tune.
RESP0   = $10   ; <strobe> Reset player 0 horizontal position
RESP1   = $11   ; <strobe> Reset player 1 horizontal position
RESM0   = $12   ; <strobe> Reset missile 0 horizontal position
RESM1   = $13   ; <strobe> Reset missile 1 horizontal position
RESBL   = $14   ; <strobe> Reset ball horizontal position

; --- Audio ---
AUDC0   = $15   ; Audio control channel 0 (tone/noise type, 0-15)
AUDC1   = $16   ; Audio control channel 1
AUDF0   = $17   ; Audio frequency channel 0 (0-31, lower = higher pitch)
AUDF1   = $18   ; Audio frequency channel 1
AUDV0   = $19   ; Audio volume channel 0 (0-15)
AUDV1   = $1A   ; Audio volume channel 1

; --- Sprite Graphics ---
GRP0    = $1B   ; Graphics pattern for player 0 (8 bits = 8 pixels)
GRP1    = $1C   ; Graphics pattern for player 1

; --- Missile/Ball Enable ---
ENAM0   = $1D   ; bit 1: enable missile 0
ENAM1   = $1E   ; bit 1: enable missile 1
ENABL   = $1F   ; bit 1: enable ball

; --- Horizontal Motion Registers ---
; Fine position adjustment: -8 to +7 pixels. Applied when HMOVE is strobed.
; Value is in upper nibble: $X0 where X is signed offset.
HMP0    = $20   ; Horizontal motion player 0
HMP1    = $21   ; Horizontal motion player 1
HMM0    = $22   ; Horizontal motion missile 0
HMM1    = $23   ; Horizontal motion missile 1
HMBL    = $24   ; Horizontal motion ball

; --- Vertical Delay ---
VDELP0  = $25   ; bit 0: delay player 0 by one line
VDELP1  = $26   ; bit 0: delay player 1 by one line
VDELBL  = $27   ; bit 0: delay ball by one line

; --- Missile-to-Player Reset ---
RESMP0  = $28   ; bit 1: lock missile 0 to center of player 0
RESMP1  = $29   ; bit 1: lock missile 1 to center of player 1

; --- Horizontal Move (Strobe) ---
HMOVE   = $2A   ; <strobe> Apply horizontal motion values (do during HBLANK!)
HMCLR   = $2B   ; <strobe> Clear all horizontal motion registers to zero

; --- Collision Clear ---
CXCLR   = $2C   ; <strobe> Clear all collision latches


; =============================================================================
; TIA READ REGISTERS ($00-$0D, active bits vary)
; =============================================================================
; These share addresses with write registers but are accessed via READ.
; Only certain bits are valid (usually bit 6 or 7).
; =============================================================================

; --- Collision Registers (active: bits 7,6) ---
CXM0P   = $00   ; Read: missile 0 / player collisions
CXM1P   = $01   ; Read: missile 1 / player collisions
CXP0FB  = $02   ; Read: player 0 / playfield-ball collisions
CXP1FB  = $03   ; Read: player 1 / playfield-ball collisions
CXM0FB  = $04   ; Read: missile 0 / playfield-ball collisions
CXM1FB  = $05   ; Read: missile 1 / playfield-ball collisions
CXBLPF  = $06   ; Read: ball / playfield collision (bit 7 only)
CXPPMM  = $07   ; Read: player-player, missile-missile collisions

; --- Input Ports (active: bit 7) ---
INPT0   = $08   ; Read: paddle 0 input
INPT1   = $09   ; Read: paddle 1 input
INPT2   = $0A   ; Read: paddle 2 input
INPT3   = $0B   ; Read: paddle 3 input
INPT4   = $0C   ; Read: player 0 fire button (bit 7: 0=pressed)
INPT5   = $0D   ; Read: player 1 fire button (bit 7: 0=pressed)


; =============================================================================
; RIOT REGISTERS (active at $0280-$0297)
; =============================================================================
; The 6532 RIOT chip provides:
;   - 128 bytes of RAM at $80-$FF (addressed directly, not listed here)
;   - Two 8-bit I/O ports (joystick + console switches)
;   - An interval timer (countdown with selectable prescaler)
; =============================================================================

; --- I/O Ports ---
SWCHA   = $0280  ; Port A: Joystick inputs (both players)
                 ;   P0: bits 4-7 (R=bit4, L=bit5, D=bit6, U=bit7... wait, 
                 ;       actually: bit4=P0 right, bit5=P0 left, 
                 ;       bit6=P0 down, bit7=P0 up — 0=pressed)
                 ;   P1: bits 0-3 (same pattern)
SWACNT  = $0281  ; Port A DDR (Data Direction Register) — usually $00 (all input)
SWCHB   = $0282  ; Port B: Console switches
                 ;   bit 0: RESET  (0=pressed)
                 ;   bit 1: SELECT (0=pressed)
                 ;   bit 3: Color/BW (1=color, 0=B&W)
                 ;   bit 6: P0 difficulty (0=expert/A, 1=novice/B)
                 ;   bit 7: P1 difficulty (0=expert/A, 1=novice/B)
SWBCNT  = $0283  ; Port B DDR — usually $00 (all input)

; --- Timer ---
; To SET the timer, write to one of these (value = number of intervals):
INTIM   = $0284  ; READ: current timer value (counts down to 0)
INSTAT  = $0285  ; READ: timer status (bit 7: 1=timer underflowed)

TIM1T   = $0294  ; Set timer: 1 clock per tick    (each tick = 1 cycle)
TIM8T   = $0295  ; Set timer: 8 clocks per tick
TIM64T  = $0296  ; Set timer: 64 clocks per tick   ← most commonly used!
T1024T  = $0297  ; Set timer: 1024 clocks per tick

; Timer usage pattern:
;   LDA #43         ; 43 × 64 = 2752 cycles ≈ 37 scanlines of VBLANK
;   STA TIM64T      ; Start counting down
;   ... do stuff ...
;   LDA INTIM       ; Check: is it zero yet?
;   BNE .-2         ; No? Keep waiting.
