# Atari-OSC036 Episode 3
Atari port of OldSkoolCoder's C64 Tutorial 36, Episode 3

---

Assembly program that implements fine scrolling by shifting bitmapped images through a character set for the C64, which is essentially nearly identical to the way the Atari works.

The original code takes longer than a full NTSC frame to execute.  After a number of optimizations to eliminate some comparisons, branches, etc. it takes about 2/3 of a frame to complete one fine scroll step on the Atari.

The timing is on an NTSC Atari which has a lot more CPU time per frame than a C64.  The optimized code exectution time may not be short enough to re-port this back to the NTSC C64.  Maybe it would work on a PAL C64 which has more CPU time during a frame than the NTSC C64.

***HiResTextScroller.asm*** - The original C64 assembly with modifications for the Atari and attempted optimizations.  C64-specific code is present and commented out.

***HiResTextScrollerAt8.asm*** - The same as the  "HiResTextScroller.asm" file, but with all the C64 code removed.

---

[Back to Home](https://github.com/kenjennings/Atari-OSC036/blob/master/README.md "Home") 
