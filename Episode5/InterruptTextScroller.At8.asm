;===============================================================================
; 6502 assembly on Atari.
; Built with eclipse/wudsn/atasm.
;
; Atari port of C64 program.  Final version.
; Effectively the same as the Version 5 demo with the visual diagnostics removed.
;
; On the C64 this is a raster interrupt to start horizontal scrolling and 
; change the border color based on the text character at the upper left 
; corner of the screen.  The text characters are displayed in inverse video, 
; so the bright visible color appears in the text.
;
; The Atari version generates its own custom screen to imitate the 
; appearance of the C64.  Fine scrolling occurs here, but only for one 
; character, then coarse scrolling is done as the C64 does by rewriting 
; screen memory, not the way the Atari usually would do it by updating 
; Display List LMS addresses.  The text color changes by converting each
; character to inverse video, and using zero luminance for the text color 
; allowing the inverted pixels to be dark, and the background color to 
; show through. 
;
; Version 1 was built as a machine language routine loaded by DOS which 
; BASIC would call via USR(). This is a regular, auto-running machine 
; language program run without BASIC.
;
; Cleaned up version with C64 and other unnecessary code and comments removed. 
;
; https://github.com/kenjennings/Atari-OSC036/blob/master/Episode5/InterruptTextScroller.asm
;
; Originally from:
; https://github.com/OldSkoolCoder/TEXTScrollers/blob/master/InterruptTextScroller.asm
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

; In version 4 and 5  the code fine scrolls one character before coarse
; scrolling.  However, the Atari hardware can fine scroll across four 
; characters before needing to coarse scroll. 
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

RasterTop       = $D0
RasterBottom    = $DB
NoOfRasterLines = $06
NoOfColours     = $40


;===============================================================================

INITIALIZATION
; Atari screen and interrupt setup...
; 0) Set default border color.
; 1) Turn off Display List Interrupts
; 2) Set Display List Interrupt Vector.
; 3) Set Display List. 
; 4) Enable Display List Interrupts.


; 0) Set default border color.

	lda #0
	sta COLOR1                  ; Set Everything to black/off.
	sta COLOR2
	sta COLOR4

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

COLORRAMP    ; Text background color ramp. 0 to 65.
	.byte 0 

VideoRamColour
; Second go-around for inverse video text.   
; 16 steps for brightness.
; 8 * 2 steps for color.
; Then shift and offset colors by half
; resulting in Candy Rainbows.....
	.by $06,$06,$16,$18,$28,$2a,$3c,$3e,$4e,$4c,$5a,$58,$68,$66,$76,$76 ; 0 to 15
	.by $86,$86,$96,$98,$a8,$aa,$bc,$be,$ce,$cc,$da,$d8,$e8,$e6,$f6,$f6 ; 16 to 31
	.by $46,$46,$56,$58,$68,$6a,$7c,$7e,$8e,$8c,$9a,$98,$a8,$a6,$b6,$b6 ; 32 to 47
	.by $c6,$c6,$d6,$d8,$e8,$ea,$fc,$fe,$0e,$0c,$1a,$18,$28,$26,$36,$36 ; 48 to 63
	.by $06,$06,$16,$18,$28,$2a,$3c                                     ; 64 to 70


;===============================================================================

INTERRUPT

;==============================================================================
;															DLI  
;==============================================================================
; Simulate what the C64 interrupt appears to be doing.
; Set fine scroll.
; Set each scan line of text a different color from the table.
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
	tya
	pha
	
	ldx #7         ; For the scan line loop later.
	ldy COLORRAMP
	lda SCROLX     ; On the Atari this must be set BEFORE displaying the scrolling line.
	sta HSCROL
	
	lda VideoRamColour,y   ; Get a new color for text background.
	sta COLPF2     ; = $D018 ; Text Background color in mode 2
	sta WSYNC

b_DLILoop
	iny
	lda VideoRamColour,y   ; Get a new color for text background.
	sta WSYNC      ; = $D40A ; Wait for Horizontal Sync to start scan line 7,6,5...0
	sta COLPF2     ; = $D018 ; Text Background color in mode 2
	dex
	bne b_DLILoop

	; DLI is done.   Clean up afterwards.  
	; Prep next scroll and complete coarse scroll if needed.

;	lda COLOR4     ; Get original OS shadow for the border 
;	sta COLBK      ; = $D01A ; Restore Border color in mode 2
	lda COLOR2     ; Get original OS shadow for the text background 
	sta WSYNC
	sta COLPF2     ; = $D018 ; Text Background color in mode 2

	; On the Atari the Frame Counter != scroll value.

; The Atari scrolls by color clocks for color consistency.
; This means scrolling is done half as often.  ALSO, the 
; Atari buffers 16 color clocks, or 4 characters, not just one,
; so this will need some tweaking to behave more like the C64.

	; On the Atari fine scrolling is every other frame to go at the same speed as the C64.
	
 	lda TEXT_FRAME_COUNTER
	eor #1
	sta TEXT_FRAME_COUNTER
	bne b_DLI_BypassScroller ; Skip coarse scroll when counter is not 0.

	inc COLORRAMP ; Increment color ramp every other frame.
	lda COLORRAMP
	and #63       ; The loop back to 0 occurs at magic number 64
	sta COLORRAMP
	
	dec SCROLX               ; Scroll 4, 3, 2, 1, at 0 then restart at 4
	bne b_DLI_BypassScroller ; Did not reach 0.
	
	lda #4              ; reset to show 4 color clocks from buffer.
	sta SCROLX
	
	jsr TextLooper      ; Coarse scroll.

b_DLI_BypassScroller
	
	pla                 ; Restore the regs used.
	tay
	pla
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
	bmi b_EndOfText   ; -1 is end of text sentinel.  rely on flag.  no CMP needed.
    ora #128          ; Add 128... Making it inverse video.
    sta SCREENROW+39

	inc TextLoader + 1  ; Increment the address pointing to the 
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
	.sb "This was a film from OldSkoolCoder (c) J" 
	.sb "un 2019. github:https://github.com/oldsk"
	.sb "oolcoder/ twitter:@oldskoolcoder email:o"
	.sb "ldskoolcoder@outlook.com Please support "
	.sb "me on patreon @ https://www.patreon.com/"
	.sb " oldskoolcoder, Thank you ;-)           " 
	.sb "Atari parody by Ken Jennings, Feb 2020. " 
	.sb "github:https://github.com/kenjennings/At" 
	.sb "ari-OSC036/                  The End...!" 

	; Adding 40 blanks to scroll the text off before restarting.
SCREENEMPTY ; 40 blank characters.  Line 2, 14 - 25 on screen.
	.sb "                                        " ; Line 12, 14 etc.
	.by 255  ; -1 does work as end of string flag for Atari and C64. (will not be displayed)

SCREENRAM ; This is 48, because ANTIC does more DMA on the scrolling line.
	:48 .byte $80  ; .ds [48] ; Top line that scrolls. 


;===============================================================================

	.align $0100 ; Go to next page boundary to make sure display list 
	             ; can't cross a 1K boundary.

; Imitate the C64 convention of a full-screen for a display mode.
; Sort of.  But not really.   It will only look like a 25-line text
; display.    Since the whole of the display is black there is
; no need to actually display any text other than the scrolling line.

DISPLAYLIST
	.by DL_BLANK_4   ; 4 scan lines to center, 25 lines of "text"
	
	:13 .by DL_BLANK_8                ; 2 lines * 8 blank at top and also Lines 1 to 11.
	
	.by DL_BLANK_8|DL_DLI                   ; Start the DLI ; Line 12
	
	mDL_LMS DL_TEXT_2|DL_HSCROLL, SCREENRAM ; mode 2 text and init memory scan. Line 13.
	; we do like a few legit lines to give time for the remaining DLI and coarse 
	; scrolling code to execute...
	:12 .by DL_BLANK_8                      ; Lines 14 to 25.
	
	mDL_JVB DISPLAYLIST ; End.  Wait for Vertical Blank.  Restart the Display List


;===============================================================================
; Store the program start location in the Atari DOS RUN Address.
; When DOS is done loading the executable file into memory it will 
; automatically jump to the address placed here in DOS_RUN_ADDR.

; DOS_RUN_ADDR =  $02e0 ; Execute at address stored here when file loading completes.

	mDiskDPoke DOS_RUN_ADDR, INITIALIZATION

; --------------------------------------------------------------------
	END ; finito
