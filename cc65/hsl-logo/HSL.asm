.segment "HEADER"
	
	.byte	"NES", $1A	; iNES header identifier
	.byte	2		; 2x 16KB PRG code
	.byte	1		; 1x  8KB CHR data
	.byte	$01, $00	; mapper 0, vertical mirroring
	.byte   $02 		; PRG RAMSIZE in 8K
	.byte   $00		; PAL mode
;;;;;;;;;;;;;;;

;;; "nes" linker config requires a STARTUP section, even if it's empty
.segment "STARTUP"

.segment "CODE"
reset:

	sei			; disable IRQs
	cld			; disable decimal mode
	ldx	#$40
	stx	$4017		; disable APU frame IRQ
	ldx	#$ff		; set up stack
	txs			;  .
	inx			; now X = 0
	stx	$2000		; disable NMI
	stx	$2001		; disable rendering
	stx	$4010		; disable DMC IRQs

	;; first wait for vblank to make sure PPU is ready
vblankwait1:
	bit	$2002   ; when bit 7 is true sets negative flag to positive
	bpl	vblankwait1 ; continue when negative flag is set to true

clear_memory:
	lda	#$00
	sta	$0000, x
	sta	$0100, x
	sta	$0300, x
	sta	$0400, x
	sta	$0500, x
	sta	$0600, x
	sta	$0700, x
	lda	#$fe
	sta	$0200, x	; move all sprites off screen
	inx
	bne	clear_memory

	;; second wait for vblank, PPU is ready after this
vblankwait2:
	bit	$2002
	bpl	vblankwait2

clear_nametables:
	lda	$2002		; read PPU status to reset the high/low latch
	lda	#$20		; write the high byte of $2000
	sta	$2006		;  .
	lda	#$20		; write the low byte of $2000
	sta	$2006		;  .
	ldx	#$08		; prepare to fill 8 pages ($800 bytes)
	ldy	#$00		;  x/y is 16-bit counter, high byte in x
	lda	#$FE		; fill with tile $27 (empty box tile)
@loop:
	sta	$2007
	dey
	bne	@loop
	dex
	bne	@loop
	
load_palettes:
	lda	$2002		; read PPU status to reset the high/low latch
	lda	#$3f		; write the high byte of $3f00
	sta	$2006		;  .
	lda	#$00		; write the low byte of $3f00
	sta	$2006		;  .
	ldx	#$20
@loop:
	lda	palette, x	; load palette byte
	sta	$2007		; write to PPU
	inx			; set index to next byte
	cpx	#$20
	bne	@loop		; if x = $20, 32 bytes copied, all done
	
vblankwait3:	
	bit	$2002
	bpl	vblankwait3
	
load_background:
	lda	$2002		; read PPU status to reset the high/low latch
	lda	#$20
	sta	$2006		; write the high byte of $2000 address
	lda	#$00
	sta	$2006		; write the low byte of $2000 address
	ldx	#$04		; start out at 0
    ldy #$00        ; loop 4 times to load 960 bytes
    lda #<background
    sta $10
    lda #>background
    sta $11
@loop:
	lda	($10), y	; load data from address (background + x)
	sta	$2007		; write to PPU
	iny
    bne @loop			
    inc $11
    dex
	bne	@loop

init_sprite0:
    LDA #$00
@loop:
    lda     sprites, x      ; load byte from ROM address (sprites + x)
    sta     $0200, x        ; store into RAM address ($0200 + x)
    inx                     ; x = x + 1
    cpx     #$04            ; x == $04? // 1 sprite aka sprite 0
    bne     @loop           ; No, jump to @loop, yes, fall through

;    .include "delay.s"  ; macros need to be fixed not compat with my ca65



	lda #%10000000  ; enable nmi sprites from pattern table 0
	sta	$2000		;  background from pattern table 0
;	lda	#%00011110	; enable sprites, enable background,
;	sta	$2001		;  no clipping on left

forever:
	jmp	forever
;;; 
;;; NMI handler
;;; 

.align 256 ; align on pages otherwise our cycle count will be inaccurate 
nmi:
    ; save registers to stack
    pha ; 3 cycles
    txa ; 2 cycles
    pha ; 3 cycles
    tya ; 2 cycles
    pha ; 3 cycles = 13 cycles so far...
        
    ; enable nmi turn on sprites and background
    lda #%10000000  ; enable nmi sprites from pattern table 0  2 cycles
    sta $2000       ;  background from pattern table 0  ; 4 cycles  = 18 cycles
    lda #%00011110  ; enable sprites, enable background,
    sta $2001       ;  no clipping on left

    ;copy sprite data to OAM RAM via DMA register
    lda #$00    ; low byte  ram addr - 2 cycles
    sta $2003   ; 4 cycles
    lda #$02    ; high byte ram addr - 2 cycles
    sta $4014   ; start xfer  4 cycles + 512 cycles, total cycle count so far 18 + 16 + 512 = 546
                ; which is into scanline 2, not viewable which is good.

WaitNotSprite0:
    lda $2002       ; read PPUSCROLL
    and #%01000000
    bne WaitNotSprite0   ; wait until sprite 0 not hit

WaitSprite0:
    lda $2002
    and #%01000000
    beq WaitSprite0      ; wait until sprite 0 is hit

    ldx #$D0
WaitScanline:
    dex
    bne WaitScanline

;    nop
;    nop
;    nop
;    nop
;    nop
;    nop

;enabling this loop updates us past the cycle we need to flip at
;    ldx #$10
;WaitFineScanline:
;    dex
;   bne WaitFineScanline

    LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
    STA $2000

    ;pull off stack 
    pla
    tay
    pla
    tax
    pla

	rti			; return from interrupt

background:
	.incbin "FullNTHSL.nam"  ; one row is not correct in the middle, will fix later

palette:
	;; Background palette
	.byte 	$0D,$05,$27,$0F
	.byte 	$0D,$05,$27,$0F
	.byte 	$0D,$05,$27,$0F
	.byte 	$0D,$05,$27,$0F
	;; Sprite palette
	.byte	$22,$2A,$27,$18
	.byte	$22,$1C,$15,$14
 	.byte	$22,$02,$38,$3C
	.byte	$22,$1C,$15,$14

sprites:  ; 6F             C0 gives 1 row incorrect.  
    .byte   $6B, $FF, $00, $C0 ; sprite 0  ; a single pixel in the lower right corner
    ; 78, , , C0   gives 1/2 the tiles drawn from each bank.
;;;;;;;;;;;;;;  
  
.segment "VECTORS"

	.word	0, 0, 0		; Unused, but needed to advance PC to $fffa.
	;; When an NMI happens (once per frame if enabled) the label nmi:
	.word	nmi
	;; When the processor first turns on or is reset, it will jump
	;; to the label reset:
	.word	reset
	;; External interrupt IRQ is not used in this tutorial 
	.word	0
  
;;;;;;;;;;;;;;  
  
.segment "CHARS"
;    .incbin "HSLTop0.chr"   ; $FF file has 1 pixel for sprite0 detection
;	.incbin	"HSLBot.chr"	; includes 8KB graphics we need
    .incbin "HSLtopbot.chr" ; both patterns
