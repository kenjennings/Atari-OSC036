# Atari-OSC036 Episode 5
Atari port of OldSkoolCoders C64 Tutorial 36, Episode 5 -  ***WORK IN PROGRESS***

---

***Files Ending .asm*** - The original C64 assembly with modifications for the Atari and optimizations where possible.  C64-specific code is present and commented out.

***Files Ending At8.asm*** - The same as the  "*.asm" file, but with all the unused code and some useless comments deleted leaving just the working Atari parts.

Additions in these demos --  In the fully 100% machine language versions of the demos (versions 2 through 5) the text being scrolled is also shown at the top of the screen.  The code also swaps the screen colors to green during the time it is executing the coarse scrolling code to illustrate how much CPU time it takes.

---

Assembly program that implements fine scrolling using the video hardware's fine scrolling feature and display-oriented interrupts.

What to do about this Episode...  The several examples presented in the C64 Episode illustrate evolution of display-oriented interrupts used to support fine scrolling a subset of the screen.  Both hardware fine scrolling and display-oriented interrupts work very differently on the Atari and in most cases presenting an Atari version of doing the same thing the same way sort of, kind of, almost approaches pointless, suboptimal, or even incorrect from the Atari programming point of view.

Display-oriented Interrupts on the Atari -- An Atari program adds a Display List Interrupt flag to the Display List instruction BEFORE the screen location where the change must be visible.  This can be done multiple times on the display and the same interrupt can execute at each occurrence or an interrupt can change the Display List Interrupt vector to point to a different interrupt for the next occurrence.  Changing the Display List instructions to different graphics modes or adding more blank lines automatically shifts the visible results of subsequent instructions and along with them the starting position of any interrupts.  Thus, for display-oriented interrupts an Atari program need not even be aware of the scan line where the interrupt occurs.

Hardware fine scrolling is also fundamentally different.  The C64 fine scrolling effects appear on the display wherever the video chip's fine scrolling hardware register value is set and continues globally for the entire display or until reset.  On the Atari fine scrolling is first designated by setting the Fine Scrolling flags in the Display List Instructions for the line or lines in the scrolling region.  The Atari's fine scrolling register value then affects only those display lines designated for fine scrolling.  The Display List effectively accomplishes the locality that the C64 implements by an interrupt.  No code is necessary on the Atari to turn fine scrolling on or off at different positions on the display.  

Use of Interrupts to support fine scrolling is in fact the opposite on the C64 and Atari.  The C64 requires an interrupt to occur at the specific location to engage scrolling, and the Atari requires the scrolling value be set away from the scrolling region.  Setting the scrolling values at any location before the scrolling region is fine for the Atari even up to the laziness of doing this in the main process without an interrupt as long as the code executing coincides with an earlier position on the display.

Other differences in horizontal fine scrolling is that the Atari does not lose any screen real-estate for fine scrolling.  The C64 uses the first and last displayed characters on a line as the buffer, and so removes those two characters reducing the visible screen width where fine scrolling is enabled.  When fine scrolling a line of graphics the Atari fetches more bytes from screen memory than it displays and buffers the excess bytes using this as the pool of imagery for pixel by pixel scrolling.  Note that by fetching more data for the scrolling line, the actual start of memory for all subsequent lines also changes accordingly.
 
These demos implement the coarse scrolling the same way as the C64 does by rewriting the entire line of screen memory.  On the Atari one would ordinarily use an LMS pointer in the Display List to change the memory read for the display and so apparently move the contents of the display to a different position.  This manipulates a two-byte pointer instead of 40 bytes of screen memory, and so, is much faster.

---

***InterruptTextScroller1***

[![Atari Version Episode 5.1](https://github.com/kenjennings/Atari-OSC036/raw/master/Episode5/AtariScreenGrab1.png "Atari Version Episode 5.1")](#features1)

No actual scrolling occurs in this demonstration.  This sets up the frame work for a scrolling line of text on the screen.

The first version establishes a Display List interrupt on the default text screen.  This is purposely organized as similar to the way the C64 does this -- the machine language is loaded into memory, but actually invoked to run by BASIC.  Subsequent versions will return to the Atari's auto-running binary load file mechanism.

HOW TO RUN THIS...
- Have BASIC present and DOS booted.
- In DOS, load (option L) the binary file.  
- Go to Basic (option B).
- enter X=USR(32768)

Characters typed into the position at the upper left corner of the screen affect the color of the border at the horizontal scrolling location on the screen.

---

***InterruptTextScroller2***

[![Atari Version Episode 5.2](https://github.com/kenjennings/Atari-OSC036/raw/master/Episode5/AtariScreenGrab2.png "Atari Version Episode 5.2")](#features1)

Since fudging about with part BASIC and part machine language is a bit painful, we're returning to the Atari's 100% machine language, auto-executing programs.

This version adds coarse scrolling to present text on the scrolling line.  Still no fine scrolling.

The determination of the border color on the scrolling text line has been changed.  In Version 1, the BASIC + machine language version, it used the character in the upper left corner of the screen as the color.  This version uses the Atari OS frame (jiffy) counter to set the border color. 

---

***InterruptTextScroller3***

[![Atari Version Episode 5.3](https://github.com/kenjennings/Atari-OSC036/raw/master/Episode5/AtariScreenGrab3.png "Atari Version Episode 5.3")](#features1)

This version adds fine scrolling the text the way the C64 does it.  

Notable differences -- The Atari fine scrolls in color clocks to maintain NTSC color consistency.  In order to scroll at the same visible speed as the C64 the Atari scrolls half as often.  Therefore the frame counter used on the C64 as the basis for the fine scroll setting is not used the same way on the Atari.  The Atari uses the frame counter to do scrolling every other frame. Then, when fine scrolling the Atari has another value for tracking the four fine scroll postions for one character 4, 3, 2, 1.

While this C64-like code design does work on the Atari, this is not the usual way for scrolling on the Atari.  The Atari buffers 16 color clocks -- up to the width of four text characters and so could coarse scroll once every fourth character rather than for each character.  Also, coarse scrolling on the Atari can be done very quickly by changing a 16-bit pointer reference in the Display List which alters where the ANTIC video chip reads memory for the screen rather than actually moving all 40 bytes of data around in screen memory.

---

***InterruptTextScroller4***

[![Atari Version Episode 5.4](https://github.com/kenjennings/Atari-OSC036/raw/master/Episode5/AtariScreenGrab4.png "Atari Version Episode 5.4")](#features1)

This version adds color raster color bars vertically scrolling within the horizontal text scrolling line.

The color cycling borders are removed.

---

***InterruptTextScroller5***

[![Atari Version Episode 5.5](https://github.com/kenjennings/Atari-OSC036/raw/master/Episode5/AtariScreenGrab5.png "Atari Version Episode 5.5")](#features1)

This version switches the color raster bars in the scrolling text to effect the text rather than the background.  This is done by displaying the text as inverse video showing the background color through where the text is.  

This effect could also be done on the Atari during the Display List Interrupt by setting the text background color to the raster color with luminance 0, and then setting the text luminance to the ramped value.

---

***InterruptTextScroller***

[![Atari Version Episode 5 Final](https://github.com/kenjennings/Atari-OSC036/raw/master/Episode5/AtariScreenGrab.png "Atari Version Episode 5 Final")](#features1)

This is performing the same effect as the Version 5 demonstration with the visible diagnostic information removed and the background and border colors set to black.   Since the static display is no longer visible, the program removes the excess spacing used to align the text for static display on the 40 column screen.

---

[Back to Home](https://github.com/kenjennings/Atari-OSC036/blob/master/README.md "Home") 
