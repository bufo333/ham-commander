; ACIA SwiftLink Driver for Ham Commander v2.0
; Assembles to $C000 (49152) — loaded by BASIC DATA statements (lines 2900-2909)
;
; Memory map:
;   $C000-$C09F  Driver code (160 bytes)
;   $C0F0        Data byte (shared with BASIC via PEEK/POKE)
;   $C0F1        Ring buffer read pointer
;   $C0F2        Ring buffer write pointer
;   $C0F4-$C0F5  Saved NMI vector
;   $C0F6-$C0F7  Timeout counters (used by readline)
;   $C0F8        Temp X save (used by readline)
;   $C100-$C1FF  256-byte NMI receive ring buffer
;   $C200-$C2FF  Readline string buffer
;   $C300-$C35F  Readline routine (96 bytes)
;
; ACIA registers (SwiftLink at $DE00):
;   $DE00  Data register (read/write)
;   $DE01  Status register (read clears IRQ, write = programmed reset)
;   $DE02  Command register
;   $DE03  Control register
;
; Entry points:
;   SYS 49152  = INIT   — detect ACIA, install NMI handler, set 9600/8N1
;   SYS 49203  = PUT    — send byte from $C0F0 (POKE 49392,byte then SYS 49203)
;   SYS 49217  = GET    — get byte into $C0F0 (SYS 49217 then PEEK(49392))
;                          checks ring buffer first, falls back to direct ACIA poll
;   SYS 49920  = READLINE — read complete line into $C200, length in $C0F0
;
; BASIC auto-detection (line 1):
;   POKE 56835,42: HW=-(PEEK(56835)=42): POKE 56835,0
;   If HW=1, SwiftLink detected. If HW=0, fall back to KERNAL userport RS232.

ACIA_DATA   = $DE00
ACIA_STATUS = $DE01
ACIA_CMD    = $DE02
ACIA_CTRL   = $DE03

DATABYTE    = $C0F0     ; shared data byte
RDPTR       = $C0F1     ; ring buffer read pointer
WRPTR       = $C0F2     ; ring buffer write pointer
SAVNMI_LO   = $C0F4     ; saved NMI vector low byte
SAVNMI_HI   = $C0F5     ; saved NMI vector high byte
TMOUT_LO    = $C0F6     ; timeout counter low (readline)
TMOUT_HI    = $C0F7     ; timeout counter high (readline)
TMPX        = $C0F8     ; temp X storage (readline)

RINGBUF     = $C100     ; 256-byte ring buffer
LINEBUF     = $C200     ; readline output buffer
NMI_VEC     = $0318     ; KERNAL NMI vector

; ============================================================
; INIT ($C000 / 49152) — 51 bytes
; Programmed reset, save old NMI, install NMI handler, set 9600/8N1
; ============================================================
        * = $C000

init:
        lda #$00
        sta ACIA_STATUS         ; programmed reset

        lda NMI_VEC             ; save current NMI vector
        sta SAVNMI_LO
        lda NMI_VEC+1
        sta SAVNMI_HI

        lda #$00                ; clear data byte and pointers
        sta DATABYTE
        sta RDPTR
        sta WRPTR

        sei
        lda #<nmi_handler       ; install NMI handler
        sta NMI_VEC
        lda #>nmi_handler
        sta NMI_VEC+1
        cli

        lda #$1E                ; control: 9600 baud, 8N1, internal clock
        sta ACIA_CTRL
        lda #$09                ; command: DTR active, RX NMI enabled, TX IRQ disabled
        sta ACIA_CMD
        rts

; ============================================================
; PUT ($C033 / 49203) — 14 bytes
; Send byte in DATABYTE. Waits for transmit register empty.
; Usage: POKE 49392,byte: SYS 49203
; ============================================================
put:
        lda ACIA_STATUS
        and #$10                ; bit 4 = transmit data register empty
        beq put                 ; wait until ready
        lda DATABYTE
        sta ACIA_DATA           ; send byte
        rts

; ============================================================
; GET ($C041 / 49217) — 42 bytes
; Hybrid get: checks NMI ring buffer first, then direct ACIA poll.
; Result in DATABYTE (0 = no data available).
; Usage: SYS 49217: A=PEEK(49392)
; ============================================================
get:
        lda WRPTR               ; check if ring buffer has data
        cmp RDPTR
        beq .direct_poll        ; buffer empty — try direct ACIA

        ; Read from ring buffer
        ldx RDPTR
        lda RINGBUF,x
        sta DATABYTE
        inx
        stx RDPTR               ; advance read pointer (wraps at 256)
        rts

.direct_poll:
        ; Buffer empty — poll ACIA status register directly
        lda ACIA_STATUS
        and #$08                ; bit 3 = receive data register full (RDRF)
        beq .no_data
        lda ACIA_DATA           ; read received byte
        sta DATABYTE
        rts

.no_data:
        lda #$00
        sta DATABYTE
        rts

; ============================================================
; CLEANUP ($C06B / 49259) — 20 bytes
; Restore original NMI vector, disable ACIA interrupts.
; ============================================================
cleanup:
        sei
        lda SAVNMI_LO           ; restore saved NMI vector
        sta NMI_VEC
        lda SAVNMI_HI
        sta NMI_VEC+1
        cli
        lda #$02                ; disable ACIA (no interrupts, DTR inactive)
        sta ACIA_CMD
        rts

; ============================================================
; NMI HANDLER ($C07F / 49279) — 33 bytes
; Called on each received byte. Stores in ring buffer.
; If NMI was not from ACIA, chains to original NMI handler.
; ============================================================
nmi_handler:
        pha
        txa
        pha

        lda ACIA_STATUS
        and #$08                ; RDRF — did ACIA receive a byte?
        beq .not_acia           ; no — chain to old handler

        lda ACIA_DATA           ; read received byte
        ldx WRPTR
        sta RINGBUF,x           ; store in ring buffer
        inx
        stx WRPTR               ; advance write pointer (wraps at 256)

        pla
        tax
        pla
        rti

.not_acia:
        pla
        tax
        pla
        jmp (SAVNMI_LO)         ; chain to original NMI handler


; ============================================================
; READLINE ($C300 / 49920) — 96 bytes
; Loaded separately by BASIC DATA statements (lines 2910-2915)
;
; Reads a complete line (until CR) from ACIA into LINEBUF ($C200).
; Skips NUL and LF bytes. Stores line length in DATABYTE ($C0F0).
; Timeout: ~350ms of no data → returns with length 0.
; BASIC retries up to 20 times for ~7 second total timeout.
;
; Uses hybrid read: checks NMI ring buffer first, falls back
; to direct ACIA status register poll if buffer is empty.
;
; Usage: SYS 49920: LN=PEEK(49392)
;        FOR I=0 TO LN-1: RL$=RL$+CHR$(PEEK(49664+I)): NEXT
; ============================================================
        * = $C300

readline:
        ldx #$00                ; X = string length / buffer index
        ldy #$00
        sty TMOUT_LO            ; reset timeout counters
        sty TMOUT_HI

.poll:
        lda WRPTR               ; check ring buffer
        cmp RDPTR
        beq .rl_direct          ; buffer empty → try direct poll

        ; Read from ring buffer
        stx TMPX                ; save string index
        ldy RDPTR
        lda RINGBUF,y
        iny
        sty RDPTR               ; advance read pointer
        ldx TMPX                ; restore string index
        jmp .process

.rl_direct:
        lda ACIA_STATUS         ; direct ACIA poll
        and #$08                ; RDRF?
        beq .empty              ; no data anywhere
        lda ACIA_DATA           ; read byte directly

.process:
        ldy #$00                ; reset timeout on any received byte
        sty TMOUT_LO
        sty TMOUT_HI

        cmp #$00                ; skip NUL
        beq .poll
        cmp #$0A                ; skip LF
        beq .poll
        cmp #$0D                ; CR = end of line
        beq .done

        sta LINEBUF,x           ; store byte in output buffer
        inx
        cpx #250                ; overflow guard (max 250 chars)
        bcc .poll
        bcs .done               ; buffer full → return what we have

.empty:
        inc TMOUT_LO            ; increment 16-bit timeout counter
        bne .poll               ; low byte didn't roll over → keep polling
        inc TMOUT_HI
        lda TMOUT_HI
        cmp #$40                ; 64*256 = 16384 empty polls ≈ 350ms
        bcc .poll               ; not timed out yet

.done:
        stx DATABYTE            ; store line length
        rts
