;===============================================================================
; 6502 assembly on Atari.
; Built with eclipse/wudsn/atasm.
;
; Atari port of C64 program to horizontally scroll text on the top 
; line of the regular text mode.  This is the assembly version of 
; Episode 1 which was a coarse scrolling textline in BASIC.
;
; Clean version of code - C64-specific code and anything deprecated 
; by optimization are all deleted.
;
; Yes, on the Atari you can coarse scroll using Display List LMS 
; pointer manipulation virtually for free.  This is copying the way the 
; C64 does coarse scrolling (redraw screen memory) with the addition of
; moving the top line of text by going through the OS pointer to screen 
; memory which should allow this to run on any memory configuration.
;
; https://github.com/kenjennings/Atari-OSC036/blob/master/Episode2/TextScrolling.asm
;
; Originally from:
; https://github.com/OldSkoolCoder/TEXTScrollers/blob/master/TextScrolling.asm
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

	ORG LOMEM_DOS_DUP ; Overdoing the niceness.  Start "program" after DOS and DUP 


SCREENPOINTER = $FE ; a copy of SAVMSC for writing to screen memory.
TEXTPOINTER   = $FC ; a pointer to the text block.


SCREENEMPTY         ; 40 blank characters. 
	.sb "                                        " ; Line 2

TEXTToScroll
;;	TEXT 'this was a film from oldskoolcoder (c) jun 2019. '
;;	TEXT 'github : https://github.com/oldskoolcoder/ '
;;	TEXT 'twitter : @oldskoolcoder email : oldskoolcoder@outlook.com '
;;	TEXT 'please support me on patreon @ https://www.patreon.com/'
;;	TEXT 'oldskoolcoder thank you ;-)'
;;	BYTE 255
	.sb "  This was a film from OldSkoolCoder    " ; line 3
	.sb "           (c) Jun 2019.                " ; line 4
	.sb "github:https://github.com/oldskoolcoder/" ; line 5
	.sb "       twitter:@oldskoolcoder           " ; line 6
	.sb "   email:oldskoolcoder@outlook.com      " ; line 7
	.sb "     Please support me on patreon       " ; line 8
	.sb "      @ https://www.patreon.com/        " ; line 9
	.sb "     oldskoolcoder, Thank you ;-)       " ; line 10
	.sb "Atari parody by Ken Jennings, Feb 2020. " ; line 11
	.sb "github:https://github.com/kenjennings/At" ; line 12
	.sb "ari-OSC036/                  The End...!" ; line 13
	.sb "                                        " ; Line 14  ; 40 blank characters.
	.byte 255 ; -1 does work as end of string flag for Atari and C64. (will not be displayed)


;===============================================================================
; Automatic start point.
; Nicety-niceness added for Atari to write the static text version 
; of the scrolling text lower on the screen. 
;
; Populating the screen using the OS SAVMSC pointer makes this usable in all 
; memory configurations.
; 
; The top line will be cleared naturally by the act of coarse scrolling,
; so the text copy routine adds 40 to the screen pointer to determine 
; the starting position...

StartScroller
	lda SAVMSC            ; Get OS pointer to screen memory
	clc
	adc #40               ; Add 40 to start at the second line
	sta SCREENPOINTER
	lda SAVMSC+1          ; And take care of carry/high byte if needed.
	adc #0
	sta SCREENPOINTER+1

	; Set up pointer to source data.  Starting at the empty line to 
	; leave a blank line after the scrolling line.
	lda #<SCREENEMPTY     
	sta TEXTPOINTER
	lda #>SCREENEMPTY     
	sta TEXTPOINTER+1

	ldy #0

bSSLoopCopyScreen	
	lda (TEXTPOINTER),y      ; Get a byte.
	bmi bSSEndOfInit         ; If negative, this is the end of looping
	sta (SCREENPOINTER),y    ; Write a byte

	inc TEXTPOINTER          ; The data to write is more than a full page. 
	bne bSSSkipTextHiByte    ; Rather than increment Y, 
	inc TEXTPOINTER+1        ; increment the pointers...
bSSSkipTextHiByte

	inc SCREENPOINTER
	bne bSSSkipScreenHiByte
	inc SCREENPOINTER+1
bSSSkipScreenHiByte

	jmp bSSLoopCopyScreen

bSSEndOfInit	

;===============================================================================

StartScrolling

TextLooper 
	ldy #0  ; Atari version is going through OS Page 0 pointer, so it needs Y.

; Part 1, shift 39 characters of the top line to the left.
TextMover
	iny
	lda (SAVMSC),y    ; Get from pointer + 1
	dey
	sta (SAVMSC),y    ; Put to pointer + 0
	iny               ; Next position

	cpy #39           ; End of text line
	bne TextMover

; Part 2, load the next new character in at the end of the line.
TextLoader
	lda TEXTToScroll  ; <-- Self-modified to change source location.
	bmi EndOfText     ; End char #255, so just use the negative flag to end.
	
	sta (SAVMSC),Y   ; From loop above, Y ended at 39, so SAVEMSC+39 = end of line.

	; Increment the pointer to text. 
	inc TextLoader + 1
	bne bTLSkipHiByte
	inc TextLoader + 2
bTLSkipHiByte

;===============================================================================

; Pause to make moving text readable.
	ldx #10                   ; 10 frames per scroll seems reasonable.

bLoopWaitForNextClock
	lda RTCLOK60              ; Get 1/60th (NTSC) jiffy counter

bLoopForFrame
	cmp RTCLOK60              ; Do while more electricity until 
	beq bLoopForFrame         ; the jiffy clock changes.

	dex                       ; count down to zero.
	bne bLoopWaitForNextClock ; If not zero go wait for another frame.
	
	
    jmp TextLooper            ; Scroll the next character.

	
EndOfText

    rts


;===============================================================================
; Store the program start location in the Atari DOS RUN Address.
; When DOS is done loading the executable file into memory it will 
; automatically jump to the address placed here in DOS_RUN_ADDR.

; DOS_RUN_ADDR =  $02e0 ; Execute at address stored here when file loading completes.

	mDiskDPoke DOS_RUN_ADDR, StartScroller

; --------------------------------------------------------------------
	END ; finito











;===============================================================================
; 6502 assembly on Atari.
; Built with eclipse/wudsn/atasm.
;
; Atari port of C64 program to horizontally scroll text on the top 
; line of the regular text mode.  This is the assembly version of 
; Episode 1 which was a coarse scrolling textline in BASIC.
;
; Clean version of code - C64-specific code and anything deprecated 
; by optimization are all deleted.
;
; Yes, on the Atari you can coarse scroll using Display List LMS 
; pointer manipulation virtually for free.  This is copying the way the 
; C64 does coarse scrolling (redraw screen memory) with the addition of
; moving the top line of text by going through the OS pointer to screen 
; memory which should allow this to run on any memory configuration.
;
; Original C64 code that is unused or modified is commented out with two semicolons ;;
;
; https://github.com/kenjennings/Atari-OSC036/blob/master/Episode2/TextScrolling.asm
;
; Originally from:
; https://github.com/OldSkoolCoder/TEXTScrollers/blob/master/TextScrolling.asm
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

	ORG LOMEM_DOS_DUP ; Overdoing the niceness.  Start "program" after DOS and DUP 


SCREENPOINTER = $FE ; a copy of SAVMSC for writing to screen memory.
TEXTPOINTER   = $FC ; a pointer to the text block.


SCREENEMPTY         ; 40 blank characters. 
	.sb "                                        " ; Line 2

TEXTToScroll
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
	.sb "                                        " ; Line 14  ; 40 blank characters.
	.byte 255 ; -1 does work as end of string flag for Atari and C64. (will not be displayed)


;===============================================================================
; Automatic start point.
; Nicety-niceness added for Atari to write the static text version 
; of the scrolling text lower on the screen. 
;
; Populating the screen using the OS SAVMSC pointer makes this usable in all 
; memory configurations.
; 
; The top line will be cleared naturally by the act of coarse scrolling,
; so the text copy routine adds 40 to the screen pointer to determine 
; the starting position...

StartScroller
	lda SAVMSC            ; Get OS pointer to screen memory
	clc
	adc #40               ; Add 40 to start at the second line
	sta SCREENPOINTER
	lda SAVMSC+1          ; And take care of carry/high byte if needed.
	adc #0
	sta SCREENPOINTER+1

	; Set up pointer to source data.  Starting at the empty line to 
	; leave a blank line after the scrolling line.
	lda #<SCREENEMPTY     
	sta TEXTPOINTER
	lda #>SCREENEMPTY     
	sta TEXTPOINTER+1

	ldy #0

bSSLoopCopyScreen	
	lda (TEXTPOINTER),y      ; Get a byte.
	bmi bSSEndOfInit         ; If negative, this is the end of looping
	sta (SCREENPOINTER),y    ; Write a byte
	
	inc TEXTPOINTER          ; The data to write is more than a full page. 
	bne bSSSkipTextHiByte    ; Rather than increment Y, 
	inc TEXTPOINTER+1        ; increment the pointers...
bSSSkipTextHiByte

	inc SCREENPOINTER
	bne bSSSkipScreenHiByte
	inc SCREENPOINTER+1
bSSSkipScreenHiByte

	jmp bSSLoopCopyScreen

bSSEndOfInit	

;===============================================================================

StartScrolling
	ldy #<SCREENEMPTY      ; Atari version adds some blank padding.
	sty TextLoader + 1     ; Setting up the self-modifying code...
	ldy #>SCREENEMPTY 
	sty TextLoader + 2

;===============================================================================

TextLooper 
; Atari version is going through OS Page 0 pointer, so it needs Y.
	ldy #0
	
; Part 1, shift 39 characters of the top line to the left.
TextMover
	iny
	lda (SAVMSC),y      ; Get from pointer + 1
	dey
	sta (SAVMSC),y      ; Put to pointer + 0
	iny                 ; Next position
	
	cpy #39             ; End of text line
	bne TextMover

; Part 2, load the next new character in at the end of the line.
TextLoader
	lda TEXTToScroll    ; <-- Self-modified to change source location.
	bmi EndOfText       ; End of string is the only negative character.
	
	sta (SAVEMSC),Y     ; From loop above, Y ended at 39, so SAVEMSC+39 = end of line.


	inc TextLoader + 1 	; Increment the pointer to text. 
	bne bTLSkipHiByte
	inc TextLoader + 2
bTLSkipHiByte

;===============================================================================

	ldx #8                    ; 8 frames per scroll seems reasonable.

bLoopWaitForNextClock
	lda RTCLOK60              ; Get 1/60th (NTSC) jiffy counter

bLoopForFrame
	cmp RTCLOK60              ; Do while more electricity until 
	beq bLoopForFrame         ; the jiffy clock changes.

	dex                       ; count down to zero.
	bne bLoopWaitForNextClock ; If not zero go wait for another frame.
	
	
    jmp TextLooper            ; Scroll the next character.

	
EndOfText

    rts


;===============================================================================
; Store the program start location in the Atari DOS RUN Address.
; When DOS is done loading the executable file into memory it will 
; automatically jump to the address placed here in DOS_RUN_ADDR.

; DOS_RUN_ADDR =  $02e0 ; Execute at address stored here when file loading completes.

	mDiskDPoke DOS_RUN_ADDR, StartScroller

; --------------------------------------------------------------------
	END ; finito
