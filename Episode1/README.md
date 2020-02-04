# Atari-OSC036 Episode 1
Atari port of OldSkoolCoder's C64 Tutorial 36, Episode 1 

---

Atari BASIC program that scrolls text on the top line of the screen.

In the Atari BASIC program the original C64 BASIC code is included, but commented out with REMarks.  This is usually followed on the next line by the equivalent Atari BASIC commands.   Three file formats are provided: 

**TEXTSCRL.BAS** - Tokenized Atari BASIC program.  

**TEXTSCRL.LIS** - LIST'ed Atari BASIC program which includes ATASCII End of Line chracters.

**TEXTSCRL.TXT** - LIST'ed Atari BASIC program which uses normal unix end of line characters.


The example is also present in OSS BASIC XL with the code cleaned up.   The C64 code is no longer included and the file is renumbered.

**TEXTSCRL.BXL** - Tokenized OSS BASIC XL program.  

**TEXTSCRL.LXL** - LIST'ed OSS BASIC XL program which includes ATASCII End of Line chracters.

**TEXTSCRL.TXL** - LIST'ed OSS BASIC XL program which uses normal unix end of line characters.


Notable difference - The C64 version deletes a character at the start of the top line, then uses 39 arrow-right characters to move to the last position on the line to print the next character of the scrolling text.   On the Atari, the full screen editor cursor can move the cursor off the left edge of the screen to then reappear on the same line at the right edge.   (I kind of expected the C64 could do the same thing... Yes?  No? ??)  So, the Atari version only prints two chracters before printing the next character of the scrolling text - delete character to remove the character at the start of the line, then arrow left character to wrap around to the right side of the screen. 

---

[Back to Home](https://github.com/kenjennings/Atari-OSC036/blob/master/README.md "Home") 
