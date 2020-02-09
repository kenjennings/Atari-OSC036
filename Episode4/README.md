# Atari-OSC036 Episode 4
Atari port of OldSkoolCoder's C64 Tutorial 36, Episode 4

---

[![Atari Version Episode 4](https://github.com/kenjennings/Atari-OSC036/raw/master/Episode4/AtariScreenGrab.png "Atari Version Episode 4")](#features1)

Assembly program that implements fine scrolling by shifting bitmapped images through a character set for the VIC-20.  This is fundamentally the same as the C64 version in [**Episode 3**](https://github.com/kenjennings/Atari-OSC036/tree/master/Episode3 "**Episode 3**"), but the VIC-20 has a smaller screen geometry.

In the Atari's case this is using ANTIC Mode 6 text (BASIC GRAPHICS MODE 1) which uses characters twice the width of normal text modes, and so displays 20 characters per line, similar to the VIC-20.  In this text mode only half the character set (64 characters) is availabe, but only 21 ae needed to perform the scroll.  

Since the number of characters on the line is half the normal text mode, the scrolling code shifting character set data now completes reasonably quickly in much less less than one video frame.

Mode 6 and 7 are the only modes on the Atari that vaguely approach color table feature.  The highest two bits of the character control the color register used, and the remaining six bits identify the internal character code.  The demo includes gradient color values and scrolls the text images through the color changes. 

***HiResTextScroller.asm*** - The original VIC-20 and C64 assembly with modifications for the Atari and optimizations.  C64/VIC-20-specific code is present and commented out.

***HiResTextScrollerAt8.asm*** - The same as the  "HiResTextScroller.asm" file, but with all the unused code and some useless comments deleted.

---

[Back to Home](https://github.com/kenjennings/Atari-OSC036/blob/master/README.md "Home") 
