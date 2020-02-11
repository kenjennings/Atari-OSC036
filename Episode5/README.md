# Atari-OSC036 Episode 5
Atari port of OldSkoolCoders C64 Tutorial 36, Episode 5 -  ***WORK IN PROGRESS***

---

Assembly program that implements fine scrolling using the video hardware's fine scrolling feature and display-oriented interrupts.

What to do about this Episode...  The several examples presented in the C64 Episode illustrate evolution of display-oriented interrupts used to support fine scrolling a subset of the screen.  Both hardware fine scrolling and display-oriented interrupts work very differently on the Atari and in most cases presenting an Atari version of doing the same thing the same way sort of, kind of, almost approaches pointless, suboptimal, or even incorrect from the Atari programming point of view.

Display-oriented Interrupts on the Atari -- An Atari program adds a Display List Interrupt flag to the Display List instruction BEFORE the screen location where the change must be visible.  This can be done multiple times on the display and the same interrupt can execute at each occurrence or an interrupt can change the Display List Interrupt vector to point to a different interrupt for the next occurrence.  Changing the Display List instructions to different graphics modes or adding more blank lines automatically shifts the visible results of subsequent instructions and along with them the starting position of any interrupts.  Thus, for display-oriented interrupts an Atari program need not even be aware of the scan line where the interrupt occurs.

Hardware fine scrolling is also fundamentally different.  The C64 fine scrolling effects appear on the display wherever the video chip's fine scrolling hardware register value is set and continues globally for the entire display or until reset.  On the Atari fine scrolling is first designated by setting the Fine Scrolling flags in the Display List Instructions for the line or lines in the scrolling region.  The Atari's fine scrolling register value then affects only those display lines designated for fine scrolling.  The Display List effectively accomplishes the locality that the C64 implements by an interrupt.  No code is necessary on the Atari to turn fine scrolling on or off at different positions on the display.  

Use of Interrupts to support fine scrolling is in fact the opposite on the C64 and Atari.  The C64 requires an interrupt to occur at the specific location to engage scrolling, and the Atari requires the scrolling value be set away from the scrolling region.  Setting the scrolling values at any location before the scrolling region is fine for the Atari even up to the laziness of doing this in the main process without an interrupt as long as the code executing coincides with an earlier position on the display.

Other differences in horizontal fine scrolling is that the Atari does not lose any screen real-estate for fine scrolling.  The C64 uses the first and last displayed characters on a line as the buffer, and so removes those two characters reducing the visible screen width where fine scrolling is enabled.  When fine scrolling a line of graphics the Atari fetches more bytes from screen memory than it displays and buffers the excess bytes using this as the pool of imagery for pixel by pixel scrolling.  Note that by fetching more data for the scrolling line, the actual start of memory for all subsequent lines also changes accordingly.
 
These demos implement the coarse scrolling the same way as the C64 does by rewriting the entire line of screen memory.  On the Atari one would ordinarily use an LMS pointer in the Display List to change the memory read for the display and so apparently move the contents of the display to a different position.  This manipulates a two-byte pointer instead of 40 bytes of screen memory, and so, is much faster.

---

[Back to Home](https://github.com/kenjennings/Atari-OSC036/blob/master/README.md "Home") 
