;===============================================================================
; 6502 assembly on Atari.
; Built with eclipse/wudsn/atasm.
;
; Atari port of VIC-20 program to horizontally scroll text via 
; character bitmap shifting.  Essentially the same code as for the 
; C64 wil the locations changed.
;
; Original VIC/C64 code that is unused or modified is commented out 
; with two semicolons ;;
;
; https://github.com/kenjennings/Atari-OSC036/blob/master/Episode4/HiResTextScroller.asm
;
; Originally from:
; https://github.com/OldSkoolCoder/TEXTScrollers/blob/master/HiResTextScroller.asm
;
;===============================================================================
 
;===============================================================================
;   ATARI SYSTEM INCLUDES
;===============================================================================
; Various Include files that provide equates defining 
; registers and the values used for the registers.
;
; For these include files refer to 
; https://github.com/kenjennings/Atari-Atasm-Includes
;
	icl "ANTIC.asm" 
	icl "GTIA.asm"
;	include "POKEY.asm"
;	include "PIA.asm"
	icl "OS.asm"
	icl "DOS.asm" 

	icl "macros.asm"

;===============================================================================
; Memory - Page 0.
; Declaring one variable here to use for a loop counter 
; rather than using A.

zbCounter = $FF ; at the end of page 0, so 127 bytes are available for code. 


;===============================================================================
; Following is N/A for Atari.  Auto start is done by the executable file 
; setting an address in the DOS_RUN_ADDR at load time.  See end of source.

;;ifdef TGT_C64
;;; 10 SYS (2064)
;;*=$0801

;;	BYTE    $0E, $08, $0A, $00, $9E, $20, $28,  $32, $30, $36, $34, $29, $00, $00, $00

;;*=$0810
;;Endif

;;ifdef TGT_VIC20
;;; 10 SYS (4112)

;;*=$1001

;;	BYTE    $0E, $10, $0A, $00, $9E, $20, $28,  $34, $31, $31, $32, $29, $00, $00, $00

;;*=$1010
;;endif

;;    jmp StartScroller



;;ifdef TGT_C64
;;ChrArea     = $3200     ; User Definded Character Area
;;ChrRom      = $D000     ; ChrSet Rom Area
;;ScreenStart = $0400     ; Screen
;;LineSize    = 40
;;endif

;;ifdef TGT_VIC20
;;ChrArea     = $1A00     ; User Definded Character Area
;;ChrRom      = $8000     ; ChrSet Rom Area
;;ScreenStart = $1E00     ; Screen
;;LineSize    = 22
;;endif

; The Atari version...

;ChrArea     = $TBD       ; User Definded Character Area - assembler will determine it later
ChrRom      = $E000       ; ChrSet Rom Area
ScreenStart = SCREENRAM   ; Screen
LineSize    = 20          ; ANTIC Text Mode 6.


	ORG $80 ; Evilness.  Loading code into Page 0 to speed up the scroll.


;===============================================================================
; ScrollOverOnePixel - Relocated from elsewhere to help eith optimizations.

ScrollOverOnePixel
	ldy #LineSize           ; Y = 20th char, the buffered end of scrolling line.

;;	lda ChrAreaLo,y         ; get address of character image in RAM
;;	sta ChrByteLoc + 1      ; and self-modify code below.
;;	lda ChrAreaHi,y
;;	sta ChrByteLoc + 2

	; The table lookup above is not needed here.  This initialization always 
	; starts with the index value 20.  So, then just insert values directly 
	; which is two bytes less, and a few cycles saved....
	
	lda #<[ChrArea+$A0]    ; get address of character image in RAM
	sta ChrByteLoc + 1     ; and self-modify the code below.
	lda #>[ChrArea+$A0]
	sta ChrByteLoc + 2

	lda #0                  ; A = 0 = stack of carry bits to roll in.
	clc
	
;; RotateTheNextCharacter
b_SOOP_RotateTheNextCharacter
;;	ldx #0                  ; X = 0
; Work in reverse from 7 to 0 removes the need for CMP
	ldx #7

; The following is the guts.   This eventually loops 328 times 
; to shift the character set image by one bit.	
;; Rotatethe8Bytes
b_SOOP_Rotatethe8Bytes
	pha                     ; (3) Save current carry bits in A now.
	rol                     ; (2) A << Roll bits Left. (high bit out into carry)
ChrByteLoc ; <- Self-modifying code changes the address used below.
	rol ChrArea,x           ; (7) Roll a byte of character image, insert carry from A
	pla                     ; (4) get the carry bit collection for A again.
	rol                     ; (2) A<< Roll bits left, dump top bit, insert new carry bit.
;;	inx                     ; next value for loop
	dex                     ; (2) next value for loop
;;	cpx #8                  ; Have we done 8 bytes?
;;	bne Rotatethe8Bytes
;	bne b_SOOP_Rotatethe8Bytes ; No, loop for the remaining bytes of the character.
	bpl b_SOOP_Rotatethe8Bytes ; (3) No, loop for the remaining bytes of the character.
	;                          ; (23) * 7 + 22 = 183 cycles per char.
	;                          ; 183 * 21 = 3,843 per scroll.

	; Accumulator now contains the vertical pixel pattern from the previous 
	; 8 bytes to apply to the next character in the RAM character set.
	pha                     ; (3) Save the new stack of rolled carry bits.

;;	sec                     ; (2) Subtract 8 from the pointer to the character 
;;	lda ChrByteLoc + 1      ; (4) image in RAM and self-modify above.
;;	sbc #8                  ; (2)
;;	sta ChrByteLoc + 1      ; (4)
;;	lda ChrByteLoc + 2      ; (4)
;;	sbc #0                  ; (2)
;;	sta ChrByteLoc + 2      ; (4)
	;                       ; (22 cycles for math above)
	; Or for 21 bytes, this is 462 cycles per scroll

	; Y handling moved up from below, because decrement is needed 
	; before using the table. ...
	dey                      ; (2) Y = Y - 1
	bmi b_SOOP_ExitScrolling ; (3) When Y rolls from 0 to -1, then stop.

	lda ChrAreaLo,y         ; (4)
	sta ChrByteLoc + 1      ; (4) (but only 3 in page 0)
	lda ChrAreaHi,y         ; (4)
	sta ChrByteLoc + 2      ; (4) (but only 3 in page 0)
                           ; (16 cycles for table lookup)
	; or for 21 bytes this is 336 cycles per scroll)
	; therefore, I cannot tell why the math was used above instead of the 
	; table lookup that was originally in place to initialize this routine.

	; The next optimization would be if the entire 
	; code of RotateTheNextCharacter itself were in 
	; Page 0, then the internal self-references to
	; ChrByteLoc would be page 0 references and one
	; cycle faster (2 LDA are then 2 cycles * 21 = 
	; 42 cycles saved) and then 336 - 42 = 294 cycles per scroll.
	; In Page 0 the code would be about 24 bytes, 
	; so it should fit.

	pla                      ; (4) Retrieve the stack of carry bits.
;;	dey                      ; (2) Y = Y - 1
	jmp b_SOOP_RotateTheNextCharacter

;;	cpy #255
;;	bne RotateTheNextCharacter

;	bpl b_SOOP_RotateTheNextCharacter ; (3) When Y rolls from 0 to -1, then stop.
	;                            (9) 9 * 20 + 8 = 188.
	
	; So, the total is around 4,325 cycles per scroll.

	; tidy, clean stack for return.
b_SOOP_ExitScrolling
	pla

	rts


;===============================================================================
; LOMEM_DOS_DUP = $3308 ; First usable memory after DOS and DUP 

	ORG LOMEM_DOS_DUP ; Overdoing the niceness.  Start "program" after DOS and DUP 



;; 40 character mapping table

; These have 40 characters to accommodate the C64, but for Atari 
; mode 6 text (overscan) only 20 characters are visible, so the 
; table only needs 21 characters.

;;ChrAreaLo
;;	BYTE $00,$08,$10,$18,$20,$28,$30,$38,$40,$48
;;	BYTE $50,$58,$60,$68,$70,$78,$80,$88,$90,$98
;;	BYTE $A0,$A8,$B0,$B8,$C0,$C8,$D0,$D8,$E0,$E8,$F0,$F8
;;	BYTE $00,$08,$10,$18,$20,$28,$30,$38,$40,$48

ChrAreaLo
	:21 .byte <[ChrArea+#*8]

;;ChrAreaHi
;;	BYTE >ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea
;;	BYTE >ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea
;;	BYTE >ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea, >ChrArea,>ChrArea
;;	BYTE >ChrArea+1,>ChrArea+1,>ChrArea+1,>ChrArea+1,>ChrArea+1,>ChrArea+1,>ChrArea+1,>ChrArea+1,>ChrArea+1,>ChrArea+1

ChrAreaHi
	:21 .byte >[ChrArea+#*8]



; Text to Scroll
TEXTToScroll
;;    TEXT 'this was a film from oldskoolcoder (c) jun 2019. '
;;    TEXT 'github : https://github.com/oldskoolcoder/ '
;;    TEXT 'twitter : @oldskoolcoder email : oldskoolcoder@outlook.com '
;;    TEXT 'please support me on patreon @ https://www.patreon.com/'
;;    TEXT 'oldskoolcoder thank you ;-)'
;;    BYTE 255
;
; For this version the static text will be handled separately
; from the data for the scrolling, so the scrolling feed doesn't 
; need extra spaces to make lines fit.
;
; Atari works in screen code values. So .sb instead of .by
; The interesting thing here is that, because this is scrolling the 
; bitmapped images of characters, the scroller can use any/all 
; characters in the character set.   Ordinarily, mode 6 (and 7) 
; text use half the character set, 64 characters.

	.sb "This was a film from OldSkoolCoder (c) Jun 2019. "
	.sb "github: https://github.com/oldskoolcoder/ "
	.sb "twitter: @oldskoolcoder " 
	.sb "email: oldskoolcoder@outlook.com " 
	.sb "Please support me on patreon " 
	.sb "@ https://www.patreon.com/ " 
	.sb "oldskoolcoder, Thank you ;-)     "
	.sb "Atari parody by Ken Jennings, Feb 2020. " 
	.sb "github:https://github.com/kenjennings/Atari-OSC036/"
	.sb "           The End...!" 
	; Adding  blanks to scroll the text off. 
	.sb "                    "
	.by 255  ; -1 does work as end of string flag for Atari and C64 and VIC-20. (will not be displayed)



;===============================================================================
; Main Routine
;===============================================================================

StartScroller  ; This is where Atari will automatically jump when the program loads.
	jsr InitCharacterArea
	jsr InitScreen
	jsr TextScroller
	rts

;===============================================================================
; Initialize the User Defined Character Area
; Zeroing only the first two pages, because the
; character set in mode 6 is two, not 4 pages.

InitCharacterArea
	ldy #0
;;	lda #0
	tya
;;@Inner
b_ICA_InnerLoop
	sta ChrArea,y       ; Set First Bank
	sta ChrArea+$100,y  ; Set Second Bank
	iny
; Roll over from $FF to $00 will automatically set Z flag, 
; so cpy #0 is not needed.
;;	cpy #0             
;	bne @Inner
	bne b_ICA_InnerLoop

	rts


;===============================================================================
; Initialise the Screen.  
; Screen clear not needed for Atari, since we are building the screen to suit.
; Also, the first line of scrolling character values is also set in the 
; screen RAM declaration, so no need to set that up here.
; A DLI on the scrolling line resets the CHBAS; hardware register to the OS 
; character set in ROM for the remainder of the screen, so the static text on 
; screen is always readable.

InitScreen
;;	lda #$93    ; Clear Screen
;;	jsr $FFD2   ; Output Character

;;	ldy #0
;;@Looper
;;	tya
;;	ora #64     ; Add 64 to Character
;;	sta ScreenStart,y
;;	iny
;;	cpy #LineSize     ; xx Characters in 1 Line
;;	bne @looper
 
;;ifdef TGT_C64
;;	lda #28     ; Set VIC Chip To Right Charater Mapping Memory    
;;	sta $d018   ;
;;endif
;;ifdef TGT_VIC20
;;	lda #$FE
;;	sta $9005   ; Set VIC Chip
;;	lda #0
;;	sta $900F   ; Set Background to black
;;endif

; The Atari-specific startup. 

	lda #>ChrArea      ; Tell Atari OS where the new character set is.
	sta CHBAS          ; = $02F4 ; CHBASE
	
	jsr libScreenWaitFrame ; Make sure the display list update below 
	                       ; cannot be interrupted by the vertical blank.
	lda #<DISPLAYLIST  ; Tell the system where the new display list is.
	sta SDLSTL
	lda #>DISPLAYLIST
	sta SDLSTH
	
	lda #<MyDLI        ; DLI reset the character set to the ROM version 
	sta VDSLST         ; to keep the on screen text legible.
	lda #>MyDLI        
	sta VDSLST+1
	
	lda #[NMI_DLI|NMI_VBI]     ; Turn On DLIs
	sta NMIEN

	lda #COLOR_BLACK|$E ; White background
	sta COLOR4 ; = $02C8 ; COLBK  - Playfield Background color

	; Setting some text colors to make a color wave (ish)
	lda #COLOR_PURPLE|$C ; Light
	sta COLOR3           ; = $02C7 ; COLPF3  - Text color
	lda #COLOR_PURPLE|$8 ; Darker 
	sta COLOR2           ; = $02C6 ; COLPF2  - Text color
	lda #COLOR_PURPLE|$4 ; Darker 
	sta COLOR1           ; = $02C6 ; COLPF1  - Text color
	lda #COLOR_PURPLE|$0 ; Darkest 
	sta COLOR0           ; = $02C6 ; COLPF0  - Text color

	lda #[ENABLE_DL_DMA|PLAYFIELD_WIDTH_NORMAL] ; for mode 6
	sta SDMCTL

	rts


;===============================================================================	
;; Initialise The Text Scroller Pointers
; Unused code
;;InitTextScroller
;;	ldy #<TEXTToScroll
;;	sty TextLoader + 1
;;	ldy #>TEXTToScroll
;;	sty TextLoader + 2
;;	rts


;===============================================================================
; Grab the Character definition from ROM and copy to the 
; 22nd character position in the scrolling buffer (which is the 
; character set in RAM).
; Called once per character coarse scroll.  (Every 8th scroll)

GrabCharacter
	; Register Y has Character Code to Copy
	lda #0                  ; Zero the pointer to the ROM character.
	sta CharacterLoc + 1
	sta CharacterLoc + 2

	tya                     ; A = Y = character code

	asl                     ; x2
	rol CharacterLoc + 2
	asl                     ; x4
	rol CharacterLoc + 2
	asl                     ; x8
	rol CharacterLoc + 2
	sta CharacterLoc + 1
	clc                     ; Next add base address of ROM character set.
	lda #>ChrRom            ; Atari's ROM set is in a different place. $E000
	adc CharacterLoc + 2
	sta CharacterLoc + 2

; Atari does not need the bank switching bit twiddling.
;;ifdef TGT_C64
;;	sei                     ; disable interrupts while we copy
;;	lda #$33                ; make the CPU see the Character Generator ROM...
;;	sta $01                 ; ...at $D000 by storing %00110011 into location $01
;;endif

	; Copy 8 bytes from the ROM character set to the RAM character set.

;;	ldy #$00                
;;GCLoop
;;CharacterLoc
;;	lda ChrRom,y

;;ifdef TGT_C64             
;;	sta ChrArea + $0140,y             ; write to the RAM Charcter 40
;;endif

;;ifdef TGT_VIC20
;;	sta ChrArea + $B0,y
;;endif
;;	iny
;;	cpy #8
;;	bne GCLoop              ; ..for low byte $00 to $FF

	; Copy the 8 bytes in reverse and eliminate the CMP.

	ldy #$07  
b_GC_Loop
CharacterLoc ; <- Self-modifying code changes the address used below.
	lda ChrRom,y             ; Atari's ROM set is in a different place.  $E000
	sta ChrArea+$A0,y        ; write to the RAM Character + 20  (20 * 8 = 160 ($A0))
	dey
	bpl b_GC_Loop            ; 7 to 0 positive, then FF is negative.

; Atari does not need the back switching bit twiddling.

;;	lda #$37                ; switch in I/O mapped registers again...
;;ifdef TGT_C64
;;	sta $01                 ; ... with %00110111 so CPU can see them
;;	cli                     ; turn off interrupt disable flag
;;endif

	rts


;===============================================================================
;; Get the Next Character in the Message
; Called once per character coarse scroll.  (Every 8th scroll)

GetCharacterInMessage
TextLoader  ; <- Self-modifying code changes the address used below.
	lda TEXTToScroll     ; Get byte from the input data
	pha                  ; Save for later.
	; -1 should be the end of string sentinel.  
	; No other character has the high bit set.
	; therefore, the CMP is not necessary.  Use negative flag.
;;	cmp #255
;;  beq @EndOfText
	; On further consideration, this branch is not actually needed, 
	; because the PLA at the end will set the negative flag 
	; according to the $FF end of data byte. 
;	bmi b_GCIM_EndOfText

;;	clc                ; Increment the address pointing to the 
;;	lda TextLoader + 1 ; input buffer of text  to scroll.
;;	adc #1
;;	sta TextLoader + 1
;;	lda TextLoader + 2
;;	adc #0
;;	sta TextLoader + 2

	inc TextLoader + 1    ; Increment the address pointing to the 
	bne b_GCIM_SkipHiByte ; input buffer of text to scroll.
	inc TextLoader + 2
b_GCIM_SkipHiByte

;;@EndOfText
;b_GCIM_EndOfText
	pla                ; Get the text byte back.  A = next character

	rts


;===============================================================================
; The Main Text Smooth Scrolling Routine  
; For the Atari the code waits until just after the display passes the scrolling
; line and then it starts. 

TextScroller
	jsr GetCharacterInMessage ; A = next character to add
	; -1 should be the end of string sentinel and no other character  
	; character has the high bit set.  Therefore, the CMP is not 
	; necessary.  Use negative flag.
;;	cmp #255
;;	bne @StillGoing
	bpl b_TS_StillGoing

	jsr TestOff ; Restore hardware colors when the work is over.

	rts

;;@StillGoing
b_TS_StillGoing	
	tay               ; Y = A = next character.
	jsr GrabCharacter ; Load ROM image into RAM at position 22 (per Y)

;;	lda #0    ; Start work with A = 0
; Use a page 0 variable to eliminate the math on the Accumulator 
; and an explicit comparison.  Also, no need to save A state, either.
	lda #7
	sta zbCounter
	
;;@DoNextPixel
b_TS_DoNextPixel
;;	pha                    ; Save A counter value for later.
	jsr WaitForScanLineStart; start work AFTER the scrolling line.
	jsr TestOn ; Set new hardware colors to indicate when the work starts.

	jsr ScrollOverOnePixel

	jsr TestOff ; Restore hardware colors when the work is over.

;;@loop
;;ifdef TGT_C64
;;	lda #200               ; Scanline -> A
;;	cmp $D012              ; Compare A to current raster line
;;	bne @loop              ; Loop if raster line not reached 255
;;endif

;;ifdef TGT_VIC20
;;	lda #100               ; Scanline/2 -> A
;;	cmp $9004              ; Compare A to current raster line
;;	bne @loop              ; Loop if raster line not reached 255
;;endif

;;	pla                    ; Get working A value
;;	clc
;;	adc #1                 ; increment.
;;	cmp #8                 ; Has it counted 8 pixels?
	dec zbCounter          ; Decrement.  Has it counted 8 pixels.
;;	bne @DoNextPixel
;	bne b_TS_DoNextPixel   ; No.  Let's shift  again.
	bpl b_TS_DoNextPixel   ; No.  Let's shift  again.

	jmp TextScroller


;==============================================================================
;														           TESTON  A  
;==============================================================================
; Subroutine to change the hardware color registers to identify where the 
; compute time begins.  
;
; This is expected to be called immediately after pausing for the specific 
; scan line AFTER the scrolling line.
;
; TestOn uses  A .
;==============================================================================

TestOn
	pha           ; save so the caller is not disrupted.

	lda #[COLOR_GREEN+$0C]
	sta COLBK  ; = $D01A ; Playfield Background color - The border color
	
	lda #COLOR_BLACK
	sta COLPF0 ; = $D016 ; Playfield 0 color - Text color
	sta COLPF1 ; = $D017 ; Playfield 1 color - Text color
	sta COLPF2 ; = $D018 ; Playfield 2 color - Text color
	sta COLPF3 ; = $D019 ; Playfield 3 color - Text color

	pla ; restore for the caller.
	rts


;==============================================================================
;														           TESTOFF  A  
;==============================================================================
; Subroutine to change the hardware color registers back to the values 
; in the OS Shadow registers to identify where the compute time ends.  
; It does not need to change CHBASE, since at this point text is readable, 
; and the next VBI is going to reset CHBASE to the current OS Shadow value 
; automatically. 
;
; TestOff uses  A .
;==============================================================================

TestOff
	pha           ; save so the caller is not disrupted.

	lda COLOR4 ; = $02C8 ; COLBK  - Playfield Background color
	sta COLBK  ; = $D01A ; Playfield Background color

	lda #COLOR_AQUA|$4 ;  copy to all others...
	sta COLPF0 ; = $D016 ; Playfield 0 color - Text color
	sta COLPF1 ; = $D017 ; Playfield 1 color - Text color
	sta COLPF2 ; = $D018 ; Playfield 2 color - Text color
	sta COLPF3 ; = $D019 ; Playfield 3 color - Text color

	pla ; restore for the caller.
	rts


;==============================================================================
; Wait for a scan line AFTER the scrolling line.
; 
; Preserve A to not interfere with caller.

WaitForScanLineStart
	pha           ; save so the caller is not disrupted.

	lda #15
	jsr libScreenWaitScanLine

	pla ; restore for the caller.
	rts ; Yes.  We're there.  exit.


;==============================================================================
;														SCREENWAITSCANLINE  A  
;==============================================================================
; Subroutine to wait for ANTIC to reach a specific scanline in the display.
;
; ScreenWaitScanLine expects  A  to contain the target scanline.
;==============================================================================

libScreenWaitScanLine
	
bLoopWaitScanLine
	cmp VCOUNT           ; Does A match the scanline?
	bne bLoopWaitScanLine ; No. Then have not reached the line.

	rts ; Yes.  We're there.  exit.


;==============================================================================
;															SCREENWAITFRAME  A  
;==============================================================================
; Subroutine to wait for the current frame to finish display.
; At the end we know the electron beam is at the top of the screen, so there
; is reasonable assumption that code immediately following this will not be
; interrupted by the VBI.
;
; ScreenWaitFrame  uses A
;==============================================================================

libScreenWaitFrame
	pha           ; save so the caller is not disrupted.
	lda RTCLOK60  ; Read the jiffy clock incremented during vertical blank.

bLoopWaitFrame
	cmp RTCLOK60      ; Is it still the same?
	beq bLoopWaitFrame ; Yes.  Then the frame has not ended.

	pla ; restore for the caller.
	rts ; No.  Clock changed means frame ended.  exit.


;==============================================================================
;															DLI  
;==============================================================================
; Yeah, gratuitous bells and whistles for presentation.
; Given the way the code calls the scrolling it may not be possible 
; to guarantee the CHBAS correction occurs on every frame. 
; So, the scrolling line will fire off a DLI at the end to make 
; sure the visible text is using the ROM font.
;==============================================================================

MyDLI
	pha           
	lda #>ChrRom ; = $E000 
	sta WSYNC    ; = $D40A ; Wait for Horizontal Sync
	sta CHBASE   ; = $D409 ; Character Set Base Address (high)
	pla
	rti


;===============================================================================
; Let the assembler decide where the character set resides.
	
	.align $0400

ChrArea  ; == CHARACTER SET == someplace in RAM.
    .ds $0200  ; Save 1/2K (512 bytes) here.


;===============================================================================
; Let the assembler decide where the screen resides.
	
	.align $0400 ; start at 1K boundary, somewhere.

SCREENRAM ; Imitate the VIC-20 full-screen display mode.
		  ; Sort of.  But not really.   The VIC-20 has 22 characters per line,
		  ; and the Atari normally displays 20 characters in Mode 6 text.  

	; Another thing being done differently is that mode 6 (and 7) is the 
	; closest thing Atari has to a color map mode.  The top 2 bits of the 
	; internal character code specify the color register to use for the 
	; character.   So, we're going to decorate a little by using all 
	; four colors and applying different colors.   The text images will
	; scroll through each character and change color as they move.
	; Here define the color modifiers:
CCOL0=%00000000
CCOL1=%01000000
CCOL2=%10000000
CCOL3=%11000000

; Top line that scrolls. 20 chars  ; Line 1
	.byte CCOL0|0
	.byte CCOL0|1
	.byte CCOL1|2
	.byte CCOL2|3
	.byte CCOL3|4
	.byte CCOL3|5
	.byte CCOL2|6
	.byte CCOL1|7
	.byte CCOL0|8
	.byte CCOL0|9
	.byte CCOL1|10
	.byte CCOL2|11
	.byte CCOL3|12
	.byte CCOL3|13
	.byte CCOL2|14
	.byte CCOL1|15
	.byte CCOL0|16
	.byte CCOL0|17
	.byte CCOL1|18
	.byte CCOL2|19


; Line 2 is a blank line instruction.
; Also, realign text to fit better on screen lines...
	.sb "THIS WAS A FILM FROM" ; line 3
	.sb "OLDSKOOLCODER       " ; line 4
	.sb "(c) JUN 2019.       " ; line 5
	.sb "GITHUB:HTTPS://GITHU" ; line 6 
	.sb "B.COM/OLDSKOOLCODER/" ; line 7
	.sb "TWITTER:            " ; line 8
	.sb "@OLDSKOOLCODER      " ; line 9
	.sb "EMAIL:OLDSKOOLCODER " ; line 10
	.sb "@OUTLOOK.COM  PLEASE" ; line 11
	.sb "SUPPORT ME ON       " ; line 12
	.sb "PATREON @ HTTPS://  " ; line 13
	.sb "WWW.PATREON.COM/    " ; line 14 
	.sb "OLDSKOOLCODER, THANK" ; line 15
	.sb "YOU ;-)   ATARI PORT" ; line 16
	.sb "BY KEN JENNINGS, FEB" ; line 17
	.sb "2020.  GITHUB:HTTPS:" ; line 18
	.sb "//GITHUB.COM/KENJENN" ; line 19 
	.sb "INGS/ATARI-OSC036/  " ; line 20
	.sb "         THE END...!" ; line 21
;	.sb "                        " ; line 22 ; Blank line instruction instead
	.sb "THE GREEN IS WHERE  " ; line 23
	.sb "THE CPU RUNS THE    " ; line 24
	.sb "SCROLL CODE MOVING  " ; line 25
	.sb "THROUGH THE RAM     " ; line 26
	.sb "CHARACTER SET.      " ; line 27


;===============================================================================
	.align $0100 ; Go to next page boundary to make sure display list 
	             ; can't cross a 1K boundary.

DISPLAYLIST
	.by DL_BLANK_8   ; 8 blank scan lines
	.by DL_BLANK_4   ; 4 blank scan lines 

	mDL_LMS DL_TEXT_6|DL_DLI, SCREENRAM ; mode 6 text and init memory scan. Line 1

	.by DL_BLANK_8                      ; 8 blank scan lines.               Line 2

	.rept 19                                                   ; Lines 3 to 19.
	.by DL_TEXT_6   ;  17 more lines displaying from SCREENRAM automatically. 
	.endr
	
	.by DL_BLANK_8                      ; 8 blank scan lines.               Line 20
	
	.rept 5                                                        ; Lines 21 to 24
	.by DL_TEXT_6   ;  4 more lines displaying from SCREENRAM automatically. 
	.endr
	
	mDL_JVB DISPLAYLIST ; End.  Wait for Vertical Blank.  Restart the Display List


;===============================================================================
; Store the program start location in the Atari DOS RUN Address.
; When DOS is done loading the executable file into memory it will 
; automatically jump to the address placed here in DOS_RUN_ADDR.

; DOS_RUN_ADDR =  $02e0 ; Execute at address stored here when file loading completes.

	mDiskDPoke DOS_RUN_ADDR, StartScroller

; --------------------------------------------------------------------
	END ; finito
