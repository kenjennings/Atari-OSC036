;===============================================================================
; 6502 assembly on Atari.
; Built with eclipse/wudsn/atasm.
;
; Atari port of C64 program to horizontally scroll text via 
; character bitmap shifting.
;
; Original C64 code that is unused or modified is commented out with two semicolons ;;
;
; https://github.com/kenjennings/Atari-OSC036/blob/master/Episode3/HiResTextScroller.asm
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
; Following is N/A for Atari.  Auto start is done by the executable file 
; setting an address in the DOS_RUN_ADDR at load time.  See end of source.

;; 10 SYS (2064)

;; *=$0801

;;    BYTE    $0E, $08, $0A, $00, $9E, $20, $28,  $32, $30, $36, $34, $29, $00, $00, $00

;; *=$0810

;;	jmp StartScroller

;===============================================================================
; LOMEM_DOS_DUP = $3308 ; First usable memory after DOS and DUP 

	ORG LOMEM_DOS_DUP ; Overdoing the niceness.  Start "program" after DOS and DUP 

;; ChrArea =$3200       ; User Defined Character Area
; Moving this for Atari, since we started waaaay up in memory.
ChrArea = CHARACTERSET  ; User Defined Character Area declared later

;; ChrRom  =$D000       ; ChrSet Rom Area
; Atari has this elsewhere...
ChrRom  = $E000          ; ChrSet Rom Area


; 40 character mapping table (for MADS changed BYTE to .byte) 
; Actually, 42 entries here, because of start and end.
ChrAreaLo
	.byte $00,$08,$10,$18,$20,$28,$30,$38,$40,$48
	.byte $50,$58,$60,$68,$70,$78,$80,$88,$90,$98
	.byte $A0,$A8,$B0,$B8,$C0,$C8,$D0,$D8,$E0,$E8
	.byte $F0,$F8,$00,$08,$10,$18,$20,$28,$30,$38
	.byte $40,$48

ChrAreaHi
	.byte >ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea
	.byte >ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea
	.byte >ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea,>ChrArea
	.byte >ChrArea,>ChrArea,>ChrArea+1,>ChrArea+1,>ChrArea+1,>ChrArea+1,>ChrArea+1,>ChrArea+1,>ChrArea+1,>ChrArea+1
	.byte >ChrArea+1,>ChrArea+1

; Text to Scroll
; This data to put in the scroller has been moved into the screen RAM declaration 
; so the data can be re-used as the static text shown on screen. 


;===============================================================================
; Main Routine
;===============================================================================
StartScroller ; This is where Atari will automatically jump when the program loads.
	jsr InitCharacterArea
	jsr InitScreen
;;	jsr InitTextScroller
	jsr TextScroller
	
	rts ; bye.


;===============================================================================
; Initialize the User Defined Character Area
; Zeroing only the first two pages.
; 42 characters * 8 = 336 bytes, so 2 pages.
InitCharacterArea
	ldy #0
	lda #0
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
; Also, since internal screen byte codes are used for the data, there's no 
; need to add 64 to the byte values.
; In fact, because the value 0 used for all blank spaces only appears once, 
; it is safe to use that as target scroll characters in the character set.
; This is made safe, because a DLI on the scrolling line resets the CHBAS
; hardware register to the OS character set in ROM, so the static text on 
; screen is always readable.

InitScreen
;;    lda #$93    ; Clear Screen
;;    jsr $FFD2   ; Output Character

;;	ldy #0
;;@Looper
;;	tya
;;	ora #64         ; Add 64 to Character
;;	sta $0400,y     ; C64 fixed address for screen.    SCREENRAM = $0400
;;	sta SCREENRAM,y ; Wherever the assembler put the screen ram.
;;	iny
;;	cpy #40         ; 40 Characters in 1 Line
;;	bne @looper 

	; Reverse counting does not require a CMP
	ldy #39         ; 39 to 0 is 40 bytes.
b_IS_Looper
	tya
	sta SCREENRAM,y ; Wherever the assembler put the screen ram below.
	dey
	bpl b_IS_Looper ; Loop while positive.  At -1/$FF/255 it falls through.
	
;;	lda #28         ; Set VIC Chip To Right Character Mapping Memory    
;;	sta $d018       ;

	lda #>CHARACTERSET ; Tell Atari OS where the new character set is.
	sta CHBAS          ; = $02F4 ; CHBASE
	
	jsr libScreenWaitFrame ; Make sure the display list update below 
	                       ; cannot be interrupted by the vertical blank.
	lda #<DISPLAYLIST  ; Tell the system where the new display list is.
	sta SDLSTL
	lda #>DISPLAYLIST
	sta SDLSTH
	
	lda #<MyDLI        ; DLI to reset the character set to the ROM version 
	sta VDSLST
	lda #>MyDLI        
	sta VDSLST+1
	
	lda #[NMI_DLI|NMI_VBI]     ; Turn On DLIs
	sta NMIEN
	
	rts


;===============================================================================	
; Initialise The Text Scroller Pointers
; Unused code
;; InitTextScroller
;;    ldy #<TEXTToScroll
;;    sty TextLoader + 1
;;    ldy #>TEXTToScroll
;;    sty TextLoader + 2
	
;;    rts

	
;===============================================================================
; Grab the Character Definition From CHR Rom
GrabCharacter
    ; Register Y has Character Code to Copy
    lda #0
    sta CharacterLoc + 1
    sta CharacterLoc + 2
    tya
    asl                     ; x2
    rol CharacterLoc + 2
    asl                     ; x4
    rol CharacterLoc + 2
    asl                     ; x8
    rol CharacterLoc + 2
    sta CharacterLoc + 1
    clc
;;  lda #$D0
	lda #$E0                 ; Atari's ROM set is in a different place.
    adc CharacterLoc + 2
    sta CharacterLoc + 2
; Atari does not need the bank switching bit twiddling.
;;  sei                     ; disable interrupts while we copy
;;  lda #$33                ; make the CPU see the Character Generator ROM...
;;  sta $01                 ; ...at $D000 by storing %00110011 into location $01
    ldy #$00                
;;GCLoop
b_GC_Loop
CharacterLoc
;;  lda $D000,y
	lda ChrRom,y             ; Atari's ROM set is in a different place.  $E000
;;  sta CHARACTERSET+$3340,y            ; write to the RAM Character 40
    sta CHARACTERSET+$140,y             ; write to the RAM Character 40 
    iny
    cpy #8
;;	bne GCLoop              ; ..for low byte $00 to $FF
	bne b_GC_Loop           ; ..for low byte $00 to $FF
; Atari does not need the back switching bit twiddling.
;;  lda #$37                ; switch in I/O mapped registers again...
;;  sta $01                 ; ... with %00110111 so CPU can see them
;;  cli                     ; turn off interrupt disable flag

    rts


;===============================================================================	
; Get the Next Character in the Message
GetCharacterInMessage
TextLoader
	lda TEXTToScroll
	pha                     ; Save for later.
	; -1 should be the end of string sentinel.  
	; No other character has the high bit set.
	; therefore, the CMP is not necessary.  Use negative flag.
;;	cmp #255
;;  beq @EndOfText
	bmi b_GCIM_EndOfText

	clc
	lda TextLoader + 1
	adc #1
	sta TextLoader + 1
	lda TextLoader + 2
	adc #0
	sta TextLoader + 2
;;@EndOfText
b_GCIM_EndOfText
	pla                     ; Get the text byte back.
	
	rts


;===============================================================================
; The Main Text Smooth Scrolling Routine  
; For the Atari the code waits until just after the display passes the scrolling
; line and then it starts. 
TextScroller

    jsr GetCharacterInMessage
	; -1 should be the end of string sentinel.  
	; No other character has the high bit set.
	; therefore, the CMP is not necessary.  Use negative flag.
;;	cmp #255
;;	bne @StillGoing
	bpl b_TS_StillGoing
	
	jsr TestOff ; Restore colors when the work is over.
	
	rts

;;@StillGoing
b_TS_StillGoing	
	tay
	jsr GrabCharacter
	lda #0

	jsr WaitForScanLineStart
	jsr TestOn ; Set colors to indicate when the work starts.
	
;;@DoNextPixel
b_TS_DoNextPixel
	pha                    
	jsr ScrollOverOnePixel

;;@loop
;;	lda #200               ; Scanline -> A
;;	cmp $D012              ; Compare A to current raster line
;;	bne @loop              ; Loop if raster line not reached 255

	pla
	clc
	adc #1
	cmp #8
;;	bne @DoNextPixel
	bne b_TS_DoNextPixel
	
	jsr TestOff ; Restore colors when the work is over.
	
	jmp TextScroller


;===============================================================================
ScrollOverOnePixel
	ldy #40
	lda ChrAreaLo,y
	sta ChrByteLoc + 1
	lda ChrAreaHi,y
	sta ChrByteLoc + 2
	lda #0
	clc
;; RotateTheNextCharacter
b_SOOP_RotateTheNextCharacter
	ldx #0

;; Rotatethe8Bytes
b_SOOP_Rotatethe8Bytes
	pha
	rol
ChrByteLoc
	rol ChrByteLoc,x
	pla
	rol
	inx
	cpx #8
;;	bne Rotatethe8Bytes
	bne b_SOOP_Rotatethe8Bytes

    ; Accumulator now contains the vertical pixel pattern
    ; now to apply to previous 8 bytes
	pha
	sec
	lda ChrByteLoc + 1
	sbc #8
	sta ChrByteLoc + 1
	lda ChrByteLoc + 2
	sbc #0
	sta ChrByteLoc + 2
	pla
	dey
;;	cpy #255
;;	bne RotateTheNextCharacter
	bmi b_SOOP_RotateTheNextCharacter
	
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

	lda #20
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
	lda #$E0
	sta WSYNC  ; = $D40A ; Wait for Horizontal Sync
	sta CHBASE ; = $D409 ; Character Set Base Address (high)
	pla
	rti
	
	
;===============================================================================
; Let the assembler decide where the 1K character set resides.
	
	.align $0400

CHARACTERSET
;	.ds $0400  Since an ORG immediately follows this, nothing needs to be here.


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

	ORG $4000

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
	.sb "ari-OSC036/                            !" ; line 13
	
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
	             ; doesn't cross the 1K boundary.

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

	