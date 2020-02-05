;===============================================================================
; 6502 assembly on Atari.
; Built with eclipse/wudsn/atasm.
;
; Atari port of C64 program to horizontally scroll text via character 
; bitmap shifting.   Clean version of code - C64-specific code and 
; anything deprecated by optimization are all deleted.
;
; https://github.com/kenjennings/Atari-OSC036/blob/master/Episode3/HiResTextScrollerAt8.asm
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


	ORG $80 ; Evilness.  Loading code into Page 0 to speed up the scroll.


;===============================================================================
; ScrollOverOnePixel - Relocated from elsewhere to help with optimizations.
; This is in Page 0 which speeds up assignment of the ChrByteLoc value.
; This matters when it has to be repeated 40 more times.

ScrollOverOnePixel
	ldy #40                 ; Y = 40th char, the buffered end of scrolling line.
	
	; The table lookup is not needed here.  This initialization always 
	; starts with the index value 40.  So, then just insert values directly 
	; which is two bytes less, and a few cycles saved....
	
	lda #<[ChrArea+$140]    ; get address of character image in RAM
	sta ChrByteLoc + 1      ; and self-modify the code below.
	lda #>[ChrArea+$140]
	sta ChrByteLoc + 2

	lda #0                  ; A = 0 = stack of carry bits to roll in.
	clc
	
b_SOOP_RotateTheNextCharacter
	ldx #7           ; Work in reverse from 7 to 0 removes the need for CMP

; The following is the guts.   This eventually loops 328 times 
; to shift the character set image by one bit.	
b_SOOP_Rotatethe8Bytes
	pha                     ; (3) Save current carry bits in A now.
	rol                     ; (2) A << Roll bits Left. (high bit out into carry)
ChrByteLoc ; <- Self-modifying code changes the address used below.
	rol ChrArea,x           ; (7) Roll a byte of character image, insert carry from A
	pla                     ; (4) get the carry bit collection for A again.
	rol                     ; (2) A<< Roll bits left, dump top bit, insert new carry bit.
	dex                     ; (2) next value for loop
	bpl b_SOOP_Rotatethe8Bytes ; (3) No, loop for the remaining bytes of the character.
	;                          ; (23) * 7 + 22 = 183 per byte.
	;                          ; 183 * 41 = 7,503 per scroll.

	; Accumulator now contains the vertical pixel pattern from the previous 
	; 8 bytes to apply to the next character in the RAM character set.
	pha                     ; (3) Save the new stack of rolled carry bits.

	; Y handling moved from below, because decrement is needed 
	; before using the table. ...
	dey                      ; (2) Y = Y - 1
	bmi  b_SOOP_ExitScrolling ; (3) When Y rolls from 0 to -1, then stop.

	lda ChrAreaLo,y         ; (4)
	sta ChrByteLoc + 1      ; (4) (but only 3 in page 0)
	lda ChrAreaHi,y         ; (4)
	sta ChrByteLoc + 2      ; (4) (but only 3 in page 0)
	;                       ; (16 cycles for table lookup)
	; or for 41 bytes this is 656 cycles per scroll)

	pla                     ; (4) Retrieve the stack of carry bits.
	jmp b_SOOP_RotateTheNextCharacter


b_SOOP_ExitScrolling
	pla                     ; tidy, clean stack for return.
	
	rts


;===============================================================================
; LOMEM_DOS_DUP = $3308 ; First usable memory after DOS and DUP 

	ORG LOMEM_DOS_DUP ; Overdoing the niceness.  Start "program" after DOS and DUP 


; Atari OS Character set ROM ...
ChrRom = $E000          ; ChrSet Rom Area


	.align $0100 	; forcing alignment so the data does not cross page border 

; This table below was previously commented out, but 
; on consideration of optimization I determined the code 
; would work slightly faster using table lookups rather 
; than subtracting 8 from the pointers.

; Table of 40 + 1 bytes of the low bytes, progressively increasing by 8.
ChrAreaLo
	:41 .byte <[ChrArea+#*8]

; Table of 40 + 1 bytes of the high bytes, progressively increasing by 8.
ChrAreaHi
	:41 .byte >[ChrArea+#*8]


;===============================================================================
; Main Routine
;===============================================================================

StartScroller ; This is where Atari will automatically jump when the program loads.
	jsr InitCharacterArea
	jsr InitScreen
	jsr TextScroller

	rts ; bye.  Exit to DOS/Memo Pad as applicable.


;===============================================================================
; Initialize the User Defined Character Area
; Zeroing only the first two pages.
; 42 characters * 8 = 336 bytes, so 2 pages.

InitCharacterArea
	ldy #0              ; Y = 0
	tya                 ; A = 0

b_ICA_InnerLoop
	sta ChrArea,y       ; Set First Bank
	sta ChrArea+$100,y  ; Set Second Bank
	
	iny             ; Roll over from $FF to $00 will automatically clear Z flag 

	bne b_ICA_InnerLoop

	rts


;===============================================================================
; Initialise the Screen.  
; Screen clear not needed for Atari, since we are building the screen to suit.
; Also, since internal screen byte codes are used for the data, there's no 
; need to add 64 to the byte values.
; In fact, because the value 0 used for all blank spaces only appears once, 
; it is safe to use that as target scroll characters in the character set.
; This is made safe, because a DLI on the scrolling line resets the CHBAS
; hardware register to the OS character set in ROM, so the static text on 
; screen is always readable.

InitScreen
	; Reverse counting does not require a CMP
	ldy #39         ; 39 to 0 is 40 bytes.
	
b_IS_Looper
	tya             ; A = Y counter.
	sta SCREENRAM,y ; Wherever the assembler put the screen ram below.
	dey
	bpl b_IS_Looper ; Loop while positive.  At -1/$FF/255 it falls through.
	
	lda #>ChrArea      ; Tell Atari OS where the new character set is.
	sta CHBAS          ; = $02F4 ; CHBASE OS shadow register
	
	jsr libScreenWaitFrame ; Make sure the display list update below 
	                       ; cannot be interrupted by the vertical blank.

	lda #<DISPLAYLIST      ; Tell the system where to find the new display list.
	sta SDLSTL
	lda #>DISPLAYLIST
	sta SDLSTH
	
	lda #<MyDLI        ; DLI to reset the character set to the ROM version 
	sta VDSLST         ; making the static text on screen legible.
	lda #>MyDLI        
	sta VDSLST+1
	
	lda #[NMI_DLI|NMI_VBI]  ; Turn On DLIs
	sta NMIEN
	
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
	; therefore, CMP is not necessary.  Use negative flag.

	inc TextLoader + 1    ; Increment the address pointing to the 
	bne b_GCIM_SkipHiByte ; input buffer of text to scroll.
	inc TextLoader + 2
b_GCIM_SkipHiByte

	pla                ; Get the text byte back.  A = next character

	rts


;===============================================================================
; Grab the Character definition from ROM and copy to the 
; 40th character position in the scrolling buffer (which is the 
; character set in RAM).
; Called once per character coarse scroll.  (Every 8th scroll)

GrabCharacter               ; Register Y has Character Code to Copy
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

	; Copy the 8 bytes in reverse and eliminate doing CMP.
	
	ldy #$07  
b_GC_Loop
CharacterLoc ; <- Self-modifying code changes the address used below.
	lda ChrRom,y             ; Atari's ROM set is in a different place.  $E000
	sta ChrArea+$140,y       ; write to the RAM Character + 40  (40 * 8 = 320)
	dey
	bpl b_GC_Loop            ; 7 to 0 positive, then FF is negative.

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
	bpl b_TS_StillGoing

	jsr TestOff ; Restore hardware colors when the work is over.

	rts

b_TS_StillGoing
	tay               ; Y = A = next character.
	jsr GrabCharacter ; Load ROM image into RAM at position 40 (per Y)

; Using a page 0 variable to eliminate the math on the Accumulator 
; and an explicit comparison.  Also, no need to save A state, either.
	lda #7
	sta zbCounter

b_TS_DoNextPixel
	jsr WaitForScanLineStart; start work AFTER the scrolling line.
	jsr TestOn ; Set new hardware colors to indicate when the work starts.

	jsr ScrollOverOnePixel
	
	jsr TestOff ; Restore hardware colors when the work is over.

	dec zbCounter          ; Decrement.  Has it counted 8 pixels?
	bpl b_TS_DoNextPixel   ; No.  Let's shift  again.
	
	jmp TextScroller


;===============================================================================
; ScrollOverOnePixel -- relocated to page 0 to assist with optimizations.

	
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
	sta COLPF2 ; = $D018 ; Playfield 2 color - the text background.
	sta COLBK  ; = $D01A ; Playfield Background color - The border color
	
	lda #COLOR_BLACK
	sta COLPF1 ; = $D017 ; Playfield 1 color - Text color

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
	
	lda COLOR4 ; = $02C8 ; COLBK  - Playfield Background color (Border for modes 2, 3, and F)
	sta COLBK  ; = $D01A ; Playfield Background color - The border color

	lda COLOR2 ; = $02C6 ; COLPF2 - Playfield 2 color (Background for ANTIC modes 2, 3, and F)
	sta COLPF2 ; = $D018 ; Playfield 2 color - the text background.

	lda COLOR1 ; = $02C5 ; COLPF1 - Playfield 1 color (Text for modes 2, 3, pixels for mode F)
	sta COLPF1 ; = $D017 ; Playfield 1 color - Text color

	pla ; restore for the caller.
	rts


;==============================================================================
; Wait for the scan line AFTER the scrolling line.
; 
; Preserve A to not interfere with caller.

WaitForScanLineStart
	pha           ; save so the caller is not disrupted.

	lda #18
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
	lda #>ChrRom ; = $E0000 
	sta WSYNC    ; = $D40A ; Wait for Horizontal Sync
	sta CHBASE   ; = $D409 ; Character Set Base Address (high)
	pla
	rti
	
	
;===============================================================================
; Let the assembler decide where the 1K character set resides.

	.align $0400

ChrArea  ; == CHARACTER SET == someplace in RAM.
    .ds $0400  ; Save 1K here.


;===============================================================================
; The C64 has screen memory fixed at $0400 by default and the code directly
; refers to it by numeric value.  The Atari could have screen memory located 
; anywhere in 16-bit space.  The official way to find the screen created by
; the Operating system is through a pointer on page 0 (SAVEMSC/$58).  
; Conforming to this would significantly change the code to more flexible,
; but slower zero page indirect addressing.  So, to keep within the originally
; supplied addressing modes define a custom screen at a specific location that 
; looks like the system default.  (or, rather, looks like the 25 lines for the 
; C64 default text display).

;===============================================================================
; Let the assembler decide where the screen resides.
	
	.align $0400 ; start at 1K boundary, somewhere.

SCREENRAM ; Imitate the C64 convention of a full-screen for a display mode.
		  ; Sort of.  But not really.   It will only look like a 25-line text
		  ; display.   But, screen memory can be whatever we want it to be.
		  ; The first line is the 40 scrolling characters.  
		  ; The rest of the screen redisplays the scrolling text statically, 
		  ; or blank lines.		  
	.ds [40] ; Top line that scrolls.  ; Line 1

TEXTToScroll
;;    TEXT 'this was a film from oldskoolcoder (c) jun 2019. '
;;    TEXT 'github : https://github.com/oldskoolcoder/ '
;;    TEXT 'twitter : @oldskoolcoder email : oldskoolcoder@outlook.com '
;;    TEXT 'please support me on patreon @ https://www.patreon.com/'
;;    TEXT 'oldskoolcoder thank you ;-)'
; Atari works in screen code values. So .sb instead of .by
; Also, realign text to fit better on screen lines...
	.sb "  This was a film from OldSkoolCoder    " ; line 3
	.sb "           (c) Jun 2019.                " ; line 4
	.sb "github:https://github.com/oldskoolcoder/" ; line 5
	.sb "       twitter:@oldskoolcoder           " ; line 6
	.sb "   email:oldskoolcoder@outlook.com      " ; line 7
	.sb "     Please support me on patreon       " ; line 8
	.sb "      @ https://www.patreon.com/        " ; line 9
	.sb "     oldskoolcoder, Thank you ;-)       " ; line 10
	.sb "Atari parody by Ken Jennings, Jan 2020. " ; line 11
	.sb "github:https://github.com/kenjennings/At" ; line 12
	.sb "ari-OSC036/                  The End...!" ; line 13
	
	; Adding 40 blanks to scroll the text off before restarting,
	; which also doubles as an empty line for the screen memory.
SCREENEMPTY ; 40 blank characters.  Line 2, 14 - 25 on screen.
	.sb "                                        " ; Line 2, 14, etc.
	.by 255  ; -1 does work as end of string flag for Atari and C64. (will not be displayed)	

EXPLAINTHIS
	.sb "The green part of the screen shows when " ; line 15
	.sb "the CPU is executing the scroll shift   " ; line 16 
	.sb "algorithm.   The credit text above is   " ; line 17
	.sb "declared once and used as the screen    " ; line 18
	.sb "data you see, and the data driving the  " ; line 19
	.sb "scrolling text message.                 " ; Line 20


;===============================================================================

	.align $0100 ; Go to next page boundary to make sure display list 
	             ; can't cross a 1K boundary.

DISPLAYLIST
	.by DL_BLANK_8   ; extra 8 blank to center 25 text lines
	.by DL_BLANK_8   ; 8 blank scan lines
	.by DL_BLANK_4   ; 

	mDL_LMS DL_TEXT_2|DL_DLI, SCREENRAM ; mode 2 text and init memory scan. Line 1

	mDL_LMS DL_TEXT_2, SCREENEMPTY ; mode 2 text and init memory scan. Line 2.

	mDL_LMS DL_TEXT_2, TEXTToScroll ; mode 2 text and init memory scan. Line 3 

	.rept 11                                                   ; Lines 4 to 14.
	.by DL_TEXT_2   ;  11 more lines displaying from TextToScroll automatically. 
	.endr
	
	mDL_LMS DL_TEXT_2, EXPLAINTHIS ; mode 2 text and init memory scan. Line 15
		
	.rept 5                                                   ; Lines 16 to 20.
	.by DL_TEXT_2   ;  5 more lines displaying from EXPLAINTHIS automatically. 
	.endr
	
	.rept 5            ; keep displaying the same empty line for Lines 21 - 25
	mDL_LMS DL_TEXT_2, SCREENEMPTY ; mode 2 text and init memory scan
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

