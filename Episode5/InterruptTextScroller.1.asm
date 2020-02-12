;===============================================================================
; 6502 assembly on Atari.
; Built with eclipse/wudsn/atasm.
;
; Atari port of C64 program.  On the C64 this is a raster interrupt to start 
; horizontal scrolling and change the border color based on the text character 
; at the upper left corner of the screen, then it waits until the last scan 
; line of the text line, and turns scrolling off and returns the border 
; color to normal.
;
; The Atari version locates the current Display List and adds the horizontal 
; scrolling instruction to a line.
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
; Memory - Page 0.

ZRET =  $D4     ; this is FR0, $D4/$D5 aka Return Value from USR() to BASIC, 
				; so this is safe for machine language running with BASIC.

zwPointer1 = ZRET


;===============================================================================
; Following is N/A for Atari.  Auto start is done by the executable file 
; setting an address in the DOS_RUN_ADDR at load time.  
; We will not be doing the auto-run here, because it must run from BASIC. 

;; 10 SYS (2064)

;; *=$0801

;;    BYTE    $0E, $08, $0A, $00, $9E, $20, $28,  $32, $30, $36, $34, $29, $00, $00, $00

;; *=$0810

;; incasm "VIC II Constants.asm"


;===============================================================================
; An auto-running machine language program for the Atari depends on a little
; infrastructure to keep the Atari in the context of the program.  As soon as
; the program finishes (RTS) it goes back to DOS, or to the Memo Pad depending 
; on the Atari (or emulator) setup.  We do not want to do that here.  We want 
; this code to remain running and in effect during BASIC.
;
; The machine language can be loaded from DOS, but the change in display 
; when returning to BASIC means the DLI will stop due to a new Display List.
;
; Therefore, to install a Display List interrupt and keep it running while
; BASIC is operating is easier when it is loaded by DOS, but then installed 
; by BASIC.  i.e. USR(32768) typed by the user.  Alternatively, the same 
; BASIC program can POKE the assembled machine language into memory and then 
; call USR() to install the interrupt. 
; 
; It is possible to attach the machine language to the BASIC program so it 
; is automatically loaded by the BASIC LOAD. This is done by fudging the 
; BASIC pointers around before SAVEing the BASIC program when the machine 
; language routine resided in memory, but that is material for an entirely 
; different series of tutorials.
; 
; HOW TO RUN THIS...
; Have BASIC present and DOS booted.
; In DOS, load (option L) the binary file.  
; Go to Basic (option B).
; enter X=USR(32768)
; 
; The other demos will be written to autorun from DOS.


;===============================================================================
; Start "program" in high memory, so that the BASIC program, variable and 
; string tables, and possible MEMSAV don't clobber this.  This is good for 
; any 48K or larger memory Atari, which is nearly all the working models 
; in the current day.   DOS will be used to load the assembled machine 
; language, and BASIC will be used to execute USR(32768) to install it.

	ORG $8000 


;===============================================================================
; Initialization will be run by BASIC, so it requires the additional 
; environment handling that goes along with BASIC USR().

START_PROGRAM

	pla                ; pull USR() argument count from BASIC
	beq INITIALIZATION ; If this is 0, no other cleanup to do.
	tay                ; Copy argument count to Y for cleanup
DISPOSE                ; Dispose of any number of arguments to make it safe to return to BASIC
	pla                ; flush one byte of 16-bit int
	pla                ; flush one byte of 16-bit int
	dey                ; Minus one argument	
	bne DISPOSE        ; Loop if more to discard.
	
; INITIALIZATION:
; Much of the C64 code doesn't relate to how the Atari works.
; Atari screen and interrupt setup.
; 1) Turn off Display List Interrupts
; 2) Locate Display List. 
; 3) change specific instructions in display list:
; 3)a) location -1 = Add Display List Interrupt. 
; 3)b) location +0 = Add Horizontal Fine Scrolling
; 4) Set Display List Interrupt Vector.
; 5) Enable Display List Interrupts.
  
INITIALIZATION
;;; Initialisation Code $2000 - $206B
;;	;lda #$00
;;	;sta VICII_EXTCOL
;;	;sta VICII_BGCOL0

;;	sei
;;	lda #VICII_SCROLY_FineScroll_RasterNoCompareMask
;;	sta $DC0D
;;	and VICII_SCROLY
;;	sta VICII_SCROLY

;;	lda #$3A
;;	sta VICII_RASTER
;;	lda #<INTERRUPT
;;	sta $0314
;;	lda #>INTERRUPT
;;	sta $0315

;;	lda #VICII_IRQMASK_ENABLE_RASTER_COMPARE
;;	sta VICII_IRQMASK

;;	lda VICII_EXTCOL
;;	sta EXTCOL_BKUP  ; Create a shadow register for EXTCOL

;;	lda VICII_BGCOL0
;;	sta BGCOL_BKUP   ; Create a shadow register for BGCOL

;;	lda VICII_SCROLX
;;	sta SCROLX_BKUP  ; create a shadow register for SCROLX
;;	cli

; Atari...

	lda #[COLOR_PURPLE_BLUE|$C] ; Set a non-black border color, so the
	sta COLOR4                  ; DLI will look like it does something.

	lda #15                     ; No change in scrolling here, so just set
	sta HSCROL                  ; this once to show all buffered pixels. 

; 1) Turn off Display List Interrupts

	lda #NMI_VBI  ; Turn Off DLIs
	sta NMIEN

; 2) Locate Display List. 

	lda SDLSTL
	sta zwPointer1
	lda SDLSTH
	sta zwPointer1+1

; 3) change specific instructions in display list:

; 3)a) location  = Add Display List Interrupt. 

	ldy #20
	lda (zwPointer1),y
	ora #DL_DLI
	sta (zwPointer1),y

; 3)b) location +1 = Add Horizontal Fine Scrolling

	iny
	lda (zwPointer1),y
	ora #DL_HSCROLL
	sta (zwPointer1),y

; 4) Set Display List Interrupt Vector.

	lda #<INTERRUPT    ; DLI to change colors
	sta VDSLST         
	lda #>INTERRUPT        
	sta VDSLST+1

; 5) Enable Display List Interrupts.	

	lda #[NMI_DLI|NMI_VBI]  ; Turn On DLIs
	sta NMIEN

	rts ; Return to BASIC


;===============================================================================

; Make the backups of the hardware registers... something like the Atari's 
; OS shadow registers for the hardware registers.

;;EXTCOL_BKUP
;;	brk

;;BGCOL_BKUP
;;	brk

;;SCROLX_BKUP
;;	brk

; Do not need to make any Atari versions, as there are already 
; shadow registeres for playfield colors, and the scroll value 
; need not change in this version.

INTERRUPT

;;	lda VICII_EXTCOL
;;	sta EXTCOL_BKUP
;;	;lda #$CE
;;	;sta VICII_RASTER
    
;;	lda #$d2
;;@Loop
;;	cmp VICII_RASTER
;;	bne @Loop

;;	lda $0400
;;	sta VICII_EXTCOL
;;	lda #$04
;;	sta VICII_SCROLX

;;	lda #$DB
;;@Loop1
;;	cmp VICII_RASTER
;;	bne @Loop1

;;	lda EXTCOL_BKUP
;;	sta VICII_EXTCOL
;;	lda #$c8
;;	sta VICII_SCROLX
;;	asl VICII_VICIRQ
;;	jmp $ea31


;==============================================================================
;															DLI  
;==============================================================================
; Simulate what the C64 interrupt appears to be doing.
; Set border to color of character in upper corner of screen memory.
; Reset to the original color at the end. 
;==============================================================================

	pha            ; Save the regs we're going to use.
	tya
	pha

	ldy #0
	lda (SAVMSC),y ; Get character at position 0,0 in screen RAM.
	sta WSYNC      ; = $D40A ; Wait for Horizontal Sync to start scan line 0
	sta COLBK      ; = $D01A ; Border color in mode 2
	lda COLOR4     ; Get original OS shadow for the border later

	ldy #8
b_DLILoop
	sta WSYNC      ; = $D40A ; Wait for Horizontal Sync to start scan line 7,6,5...0
	dey
	bne b_DLILoop

	sta COLBK      ; = $D01A ; Border color in mode 2

	pla            ; Restore the regs used.
	tya
	pla

	rti


; --------------------------------------------------------------------
	END ; finito


