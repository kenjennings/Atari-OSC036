;===============================================================================
; 6502 assembly on Atari.
; Built with eclipse/wudsn/atasm.
;
; Atari port of C64 program.  On the C64 this is a raster interrupt to start 
; horizontal scrolling and change the border color based on the text character 
; at the upper left corner of the screen, then it waits until the last scan 
; line of the text line, and turns scrolling off and returns the border 
; color to normal.  The text is fine scrolled.
;
; The Atari version generates its own custom screen to imitate the 
; appearance of the C64.  It does the border color change based on 
; the value of the OS jiffy clock.  Fine scrolling occurs here, but only 
; for one character, then coarse scrolling is done  as the C64 does by 
; rewriting screen memory, not the way the Atari usually would do it by 
; updating Display List LMS addresses.
;
; Version 1 was built as a machine language routine loaded by DOS which 
; BASIC would call via USR(). This as Version 3 is a regular, auto-running
; machine language program run without BASIC.
;
; Cleaned up version with C64 and other unnecessary code and comments removed. 
;
; https://github.com/kenjennings/Atari-OSC036/blob/master/Episode5/InterruptTextScroller.3.asm
;
; Originally from:
; https://github.com/OldSkoolCoder/TEXTScrollers/blob/master/InterruptTextScroller.3.asm
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
; LOMEM_DOS_DUP = $3308 ; First usable memory after DOS and DUP 

	ORG LOMEM_DOS_DUP ; Overdoing the niceness. Start "program" after DOS and DUP 


; This program fine scrolls the text, but it does it like the C64 where it 
; fine scrolls one character position, and then executes coarse scrolling 
; by rewriting the screen memory.  On the C64, the scroll value must be set in 
; the register when the scan line reaches the place on the screen where 
; scrolling occurs.  On the Atari once the HSCROL value is set it applies 
; globally to all lines in the Display List that have the horizontal 
; scrolling option set.  
;
; In version 2 the text was only coarse scrolled using a static fine scroll 
; position, so I just used the fixed HSCROLL value 12 which allows a full 
; character at the start of the line and displays 3 characters from the 
; color clock buffer.

; In version 3 here the code fine scrolls one character before coarse scrolling.
; However, the Atari hardware can fine scroll across four characters before 
; needing to coarse scroll. 
;
; Let's explain the Atari scroll value and what I've chosen to use for 
; fine scrolling...
; Where the C64 has a one character buffer, the Atari has a 4 character buffer
; storing the color clocks for four, Mode 2 characters.  Each Mode 2 character
; is four color clocks wide, so this is a total of 16 color clocks.  OR:
; 16 Buffered color clocks -> FEDC BA98 7654 3210.  (or four characters.)
;
; The HSCROL value tells ANTIC how many color clocks from the buffer will be
; output. Value 0 means no color clocks are output, so the buffered characters
; are entirely invisible and the first visible character is the character AFTER
; the buffer -- or, the FOURTH character in screen memory (counting from 0). OR:
; 16 Buffered color clocks -> FEDC BA98 7654 3210 | <- display begins here. 
;
; If HSCROL is set to 6, then six color clocks, or 1.5 characters from the right
; end of the buffer become visible. OR:
; 16 Buffered color clocks -> FEDC BA98 76 | 54 3210 <- these are visible. 
;
; The maximum value of HSCROL is 15.  This means only three complete characters
; from the buffer can appear, and the last color clock in the buffer cannot be 
; displayed.  OR:
; 16 Buffered color clocks -> F | EDC BA98 7654 3210 <- these are visible. 
; (This is not a problem or a bug.  It is intentional. The next scroll step 
; after this is to shift the buffer to read the previous four characters, and 
; adjust HSCROL to output 0 color clocks.  Thus the character from the buffer 
; that had its color clocks shorted is now the first character displayed AFTER 
; the buffered characters and it appears with all four visible color clocks.)
; 
; Thus only the HSCROL values 0, 4, 8, 12 will result in a display that begins 
; at a full character.
;  
; To emulate the C64 behavior I decided to use only the last character in the 
; four-character buffer which allows moving the horizontal scroll through 
; values 4, 3, 2, 1, and then 0 becomes the trigger (BEQ) to engage coarse 
; scrolling and reset the fine scroll back to 4.
;
; Therefore, the program ignores the first three characters in the buffer 
; using only the last one.  The three ignored characters is why the SCREENROW
; coarse scrolling address is declared below as the value of the "displayed" 
; SCREENRAM location (where the scrolling buffer will be) plus 3 characters 
; offset.

SCREENROW = SCREENRAM+3  ;    C64 = 1824 ; (20 rows down)


;===============================================================================

INITIALIZATION

; Atari screen and interrupt setup...
; 0) Set default border color.
; 1) Turn off Display List Interrupts
; 2) Set Display List Interrupt Vector.
; 3) Set Display List. 
; 4) Enable Display List Interrupts.

; 0) Set default border color.

	lda #[COLOR_PURPLE_BLUE|$C] ; Set a non-black border color, so the
	sta COLOR4                  ; DLI will look like it does something.

; 1) Turn off Display List Interrupts

	lda #NMI_VBI  ; Turn Off DLIs
	sta NMIEN

; 2) Set Display List Interrupt Vector.

	lda #<INTERRUPT    ; DLI to change colors
	sta VDSLST         
	lda #>INTERRUPT        
	sta VDSLST+1

; 3) Set Display List. 

	jsr libScreenWaitFrame ; Make sure the display list update below 
	                       ; cannot be interrupted by the vertical blank.

	lda #<DISPLAYLIST      ; Tell the system where to find the new display list.
	sta SDLSTL
	lda #>DISPLAYLIST
	sta SDLSTH

; 4) Enable Display List Interrupts.	

	lda #[NMI_DLI|NMI_VBI]  ; Turn On DLIs
	sta NMIEN

	; More -- load up the self-modifying code to start displaying the scrolling text.
	lda #<TEXTToScroll
	sta TextLoader + 1
	lda #>TEXTToScroll
	sta TextLoader + 2

; Atari machine language run from DOS can't exit or this will 
; return to DOS and reset the screen.   So, loop. Forever.

Do_While_More_Electricity
	jmp Do_While_More_Electricity


;===============================================================================

TEXT_FRAME_COUNTER
	.byte $00

SCROLX       ; Current X scroll value.
	.byte $04


;===============================================================================

INTERRUPT

;==============================================================================
;															DLI  
;==============================================================================
; Simulate what the C64 interrupt appears to be doing.
; Set fine scroll.
; Set border to color.   In this case, use the OS frame counter instead of 
; pulling a character value from the screen.
; Reset to the original color at the end. 
; The ANTIC chip isolates scrolling to specific lines on the 
; Display List. The act of setting scroll values and coarse scrolling is 
; done before the scan line reaches the scrolling area, or after the 
; scrolling region has been displayed.
; Here we're trying to do this the C64 way including coarse scrolling 
; text bytes through screen memory at the end of the interrupt.
;==============================================================================

	pha            ; Save the regs we're going to use.
	txa
	pha

	ldx #8         ; For the scan line loop later.
	lda SCROLX     ; On the Atari this must be set BEFORE displaying the scrolling line.
	sta HSCROL
	
	lda RTCLOK60   ; Get a new color for border.
	sta WSYNC      ; = $D40A ; Wait for Horizontal Sync to start scan line 0
	sta COLBK      ; = $D01A ; Border color in mode 2
	lda COLOR4     ; Get original OS shadow for the border later

b_DLILoop
	sta WSYNC      ; = $D40A ; Wait for Horizontal Sync to start scan line 7,6,5...0
	dex
	bne b_DLILoop

	sta COLBK      ; = $D01A ; Restore Border color in mode 2

	; On the Atari the Frame Counter != scroll value.

; The Atari scrolls by color clocks for color consistency.
; This means scrolling is done half as often.  ALSO, the 
; Atari buffers 16 color clocks, or 4 characters, not just one,
; so this will need some tweaking to behave more like the C64.

	; Fine scrolling is every other frame to go at the same speed as the C64.

	lda TEXT_FRAME_COUNTER
	eor #1
	sta TEXT_FRAME_COUNTER
	bne b_DLI_BypassScroller ; Skip coarse scroll when counter is not 0.

	dec SCROLX               ; Scroll 4, 3, 2, 1, at 0 then restart at 4
	bne b_DLI_BypassScroller ; Did not reach 0.

	lda #4              ; reset to show 4 color clocks from buffer.
	sta SCROLX

	jsr TestOn          ; Turn on green colors to identify coarse scrolling time.
	jsr TextLooper      ; Coarse scroll.
	jsr TestOff         ; turn off the green colors.
b_DLI_BypassScroller

	pla                 ; Restore the regs used.
	tax
	pla
	rti


;===============================================================================
; Coarse scroll the line of text.

TextLooper
	ldx #0

TextMover
	lda SCREENROW+1,x ; Shift screen row 
	sta SCREENROW,x
	inx
	cpx #39
	bne TextMover

TextLoader
	lda TEXTToScroll
	bmi b_EndOfText   ; end of text flag is -1
	sta SCREENROW+39

	inc TextLoader + 1    ; Increment the address pointing to the 
	bne b_TL_SkipHiByte ; input buffer of text to scroll.
	inc TextLoader + 2

b_TL_SkipHiByte
	rts


b_EndOfText              ; Reset the scroll to the start.
	lda #<TEXTToScroll
	sta TextLoader + 1
	lda #>TEXTToScroll
	sta TextLoader + 2

	rts


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
	lda #[COLOR_GREEN+$0C]
	sta COLPF2 ; = $D018 ; Playfield 2 color - the text background.
	sta COLBK  ; = $D01A ; Playfield Background color - The border color
	lda #COLOR_BLACK
	sta COLPF1 ; = $D017 ; Playfield 1 color - Text color

	rts

	
;==============================================================================
;														           TESTOFF  A  
;==============================================================================
; Subroutine to change the hardware color registers back to the values 
; in the OS Shadow registers to identify where the compute time ends. 
;
; TestOff uses  A .
;==============================================================================

TestOff
	lda COLOR4 ; = $02C8 ; COLBK  - Playfield Background color (Border for modes 2, 3, and F)
	sta COLBK  ; = $D01A ; Playfield Background color - The border color
	lda COLOR2 ; = $02C6 ; COLPF2 - Playfield 2 color (Background for ANTIC modes 2, 3, and F)
	sta COLPF2 ; = $D018 ; Playfield 2 color - the text background.
	lda COLOR1 ; = $02C5 ; COLPF1 - Playfield 1 color (Text for modes 2, 3, pixels for mode F)
	sta COLPF1 ; = $D017 ; Playfield 1 color - Text color

	rts


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
	lda RTCLOK60  ; Read the jiffy clock incremented during vertical blank.

bLoopWaitFrame
	cmp RTCLOK60      ; Is it still the same?
	beq bLoopWaitFrame ; Yes.  Then the frame has not ended.

	rts ; No.  Clock changed means frame ended.  exit.


;===============================================================================
; Let the assembler decide where the screen memory resides.

	.align $0400 ; start at 1K boundary, somewhere.

TEXTToScroll
; Atari works in screen code values. So .sb instead of .by
; Also, realign text to fit better on screen lines...
	.sb "  This was a film from OldSkoolCoder    " ; line 1
	.sb "           (c) Jun 2019.                " ; line 2
	.sb "github:https://github.com/oldskoolcoder/" ; line 3
	.sb "       twitter:@oldskoolcoder           " ; line 4
	.sb "   email:oldskoolcoder@outlook.com      " ; line 5
	.sb "     Please support me on patreon       " ; line 6
	.sb "      @ https://www.patreon.com/        " ; line 7
	.sb "     oldskoolcoder, Thank you ;-)       " ; line 8
	.sb "Atari parody by Ken Jennings, Jan 2020. " ; line 9
	.sb "github:https://github.com/kenjennings/At" ; line 10
	.sb "ari-OSC036/                  The End...!" ; line 11

	; Adding 40 blanks to scroll the text off before restarting,
	; which also doubles as an empty line for the screen memory.
SCREENEMPTY ; 40 blank characters.  Line 2, 14 - 25 on screen.
	.sb "                                        " ; Line 12, 14 etc.
	.by 255  ; -1 does work as end of string flag for Atari and C64. (will not be displayed)

SCREENRAM ; This is 48, because ANTIC does more DMA on the scrolling line.
	.ds [48] ; Top line that scrolls.  ; Line 13

EXPLAINTHIS
	.sb "The green part of the screen shows when " ; line 15
	.sb "the CPU is executing the coarse scroll. " ; line 16
	.sb "The credit text is declared once and    " ; line 17
	.sb "used both as the static text seen above " ; line 18
	.sb "and as the data for the scrolling text  " ; line 19
	.sb "message.                                " ; Line 20


;===============================================================================

	.align $0100 ; Go to next page boundary to make sure display list 
	             ; can't cross a 1K boundary.

; Imitate the C64 convention of a full-screen for a display mode.
; Sort of.  But not really.   It will only look like a 25-line text
; display.   But, screen memory can be whatever we want it to be.
; The screen redisplays the scrolling text statically, 
; or blank lines.		  

DISPLAYLIST
	.by DL_BLANK_8   ; extra 8 blank to center 25 text lines
	.by DL_BLANK_8   ; 8 blank scan lines
	.by DL_BLANK_4   ; 

	mDL_LMS DL_TEXT_2, TEXTToScroll ; mode 2 text and init memory scan. Line 1

	.rept 10                                                   ; Lines 2 to 11.
	.by DL_TEXT_2   ;  11 more lines displaying from TEXTTTOSCROLL automatically. 
	.endr

	.by DL_TEXT_2|DL_DLI ; Display SCREENEMPTY and start the DLI ; Line 12

	mDL_LMS DL_TEXT_2|DL_HSCROLL, SCREENRAM ; mode 2 text and init memory scan. Line 13.

	mDL_LMS DL_TEXT_2, SCREENEMPTY ; mode 2 text and init memory scan. Line 14.

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

	mDiskDPoke DOS_RUN_ADDR, INITIALIZATION

; --------------------------------------------------------------------
	END ; finito

