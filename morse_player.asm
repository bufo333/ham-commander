; Morse Code Player for Ham Commander v2.1 Splash Screen
; Assembles to $C200 (49664) — loaded by BASIC DATA statements (lines 2760-2769)
;
; Plays "HAM" in Morse code at 20 WPM (60ms dit) using SID voice 1.
; Loops continuously until a key is pressed, then returns to BASIC.
; Also cycles the title bar color (color RAM row 2) after each element.
;
; Temporary — only used during splash screen. The $C200-$C2FF region is
; later reused as the readline string buffer during online operations.
;
; Memory map:
;   $C200-$C28B  Morse player code + data (150 bytes)
;   $FB          Color cycle index (zero page temp)
;   $FC          Saved X register (zero page temp)
;   $FD          Dit/element counter (zero page temp)
;
; SID setup (done by BASIC before SYS 49664):
;   POKE 54296,15     ; volume max
;   POKE 54272,212    ; freq low  ($D4) \  700 Hz
;   POKE 54273,44     ; freq high ($2C) /  triangle wave
;   POKE 54277,0      ; attack=0, decay=0 (instant)
;   POKE 54278,240    ; sustain=15 (max), release=0
;
; SID cleanup (done by BASIC after return):
;   POKE 54296,0      ; volume off
;   POKE 54276,0      ; gate off
;
; Morse timing at 20 WPM:
;   Dit  = 60ms  (1 unit)
;   Dah  = 180ms (3 units)
;   Inter-element gap = 60ms  (1 unit)
;   Inter-letter gap  = 180ms (3 units = 1 from post-tone + 2 extra)
;   Inter-word gap    = 420ms (7 units = 1 from post-tone + 6 extra)
;
; Keyboard detection:
;   Checks $C5 (197) — KERNAL LSTX register (current key matrix code).
;   Value $40 (64) = no key pressed. Any other value = key pressed.
;
; Entry point:
;   SYS 49664  = PLAY — loops "HAM" in Morse until keypress
;
; Usage from BASIC:
;   2735 FOR I=0TO149:READ A:POKE 49664+I,A:NEXT
;   2736 POKE 54276,0:POKE 54296,15:POKE 54272,212:POKE 54273,44:POKE 54277,0:POKE 54278,240
;   2737 IF PEEK(197)<>64 THEN 2737
;   2738 SYS 49664:GET W$
;   2750 POKE 54296,0:POKE 54276,0:RETURN

SID_CTRL    = $D404     ; SID voice 1 control register
KBDMATRIX   = $C5       ; KERNAL current key matrix code ($40 = no key)
NO_KEY      = $40       ; no key pressed value

COLOR_IDX   = $FB       ; zero page: color cycle index
SAVE_X      = $FC       ; zero page: saved X (pattern index)
COUNTER     = $FD       ; zero page: dit/element counter

COLOR_RAM   = $D851     ; color RAM row 2, col 1 (title bar)

; ============================================================
; PLAY ($C200 / 49664) — main entry point
; Loops "HAM" in Morse until a key is pressed.
; ============================================================
        * = $C200

play:
        ldx #$00                ; X = pattern index
        stx COLOR_IDX           ; reset color cycle

next_elem:
        lda pattern,x           ; load next pattern element
        cmp #$FF                ; end of word marker?
        beq word_gap
        cmp #$00                ; letter gap marker?
        beq letter_gap

        ; --- Tone element (dit or dah) ---
        sta COUNTER             ; save dit count (1=dit, 3=dah)

        lda #$11                ; triangle waveform + gate on
        sta SID_CTRL

tone_loop:
        jsr dit_delay           ; wait 1 dit-length (~60ms)
        dec COUNTER
        bne tone_loop           ; repeat for dah (3x)

        lda #$10                ; triangle waveform, gate off
        sta SID_CTRL

        jsr dit_delay           ; inter-element gap (1 dit)
        jsr do_color            ; cycle title bar color

        lda KBDMATRIX           ; check for keypress
        cmp #NO_KEY
        bne key_exit            ; key pressed — exit

        inx                     ; advance to next element
        bne next_elem           ; always branches (pattern < 256)

; --- Letter gap: 2 extra dits of silence (total 3 with post-tone) ---
letter_gap:
        jsr dit_delay
        jsr dit_delay

        lda KBDMATRIX
        cmp #NO_KEY
        bne key_exit

        inx
        bne next_elem

; --- Word gap: 6 extra dits of silence (total 7 with post-tone) ---
word_gap:
        lda #6
        sta COUNTER
wg_loop:
        jsr dit_delay
        dec COUNTER
        bne wg_loop
        jsr do_color

        lda KBDMATRIX
        cmp #NO_KEY
        bne key_exit

        ldx #$00                ; restart pattern from beginning
        beq next_elem           ; always branches (Z set by LDX #0)

; --- Exit: silence SID and return to BASIC ---
key_exit:
        lda #$10                ; gate off
        sta SID_CTRL
        rts

; ============================================================
; DO_COLOR — cycle through 6 colors on title bar
; Preserves X (pattern index). Modifies A, Y.
; Colors: yellow, white, light green, cyan, light blue, light grey
; ============================================================
do_color:
        stx SAVE_X              ; preserve pattern index
        ldy COLOR_IDX
        iny
        cpy #6
        bcc .no_wrap
        ldy #0
.no_wrap:
        sty COLOR_IDX
        lda colors,y            ; get next color
        ldy #36                 ; 37 cells (col 1-37 of row 2)
.color_loop:
        sta COLOR_RAM,y
        dey
        bpl .color_loop
        ldx SAVE_X              ; restore pattern index
        rts

; ============================================================
; DIT_DELAY — precise ~60ms delay (1 dit at 20 WPM)
;
; Timing: 48 outer * 256 inner * 5 cycles = 61,440 cycles
;         61,440 / 1,022,727 Hz = 60.1ms
; ============================================================
dit_delay:
        lda #48                 ; outer loop count
.del_outer:
        ldy #0                  ; inner loop: 256 iterations (Y wraps)
.del_inner:
        dey                     ; 2 cycles
        bne .del_inner          ; 3 cycles (taken) = 5 cycles/iteration
        sbc #1                  ; decrement outer counter
        bne .del_outer
        rts

; ============================================================
; DATA — color table and Morse pattern
; ============================================================
colors:
        .byte 7, 1, 13, 3, 14, 15       ; C64 color codes

; Morse pattern for "HAM":
;   H = ....  (dit dit dit dit)
;   A = .-    (dit dah)
;   M = --    (dah dah)
;
; Encoding: 1=dit, 3=dah, 0=letter gap, $FF=word end (loops)
pattern:
        .byte 1, 1, 1, 1       ; H
        .byte 0                 ; letter gap
        .byte 1, 3             ; A
        .byte 0                 ; letter gap
        .byte 3, 3             ; M
        .byte $FF               ; end — triggers word gap + restart
