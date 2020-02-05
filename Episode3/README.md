# Atari-OSC036 Episode 3
Atari port of OldSkoolCoder's C64 Tutorial 36, Episode 3

---

Assembly program that implements fine scrolling by shifting bitmapped images through a character set for the C64, which is essentially nearly identical to the way the Atari works.

The original code takes longer than a full NTSC frame to execute.  After a number of optimizations to eliminate some comparisons, branches, etc. it still takes just over 1 frame. 

The timing is on an NTSC Atari which has a lot more CPU time per frame than a C64.  The optimized code exectution time probably isn't short enough to be re-port in a practical way back to the NTSC C64.  Maybe it would work on a PAL C64 which has more CPU time during a frame than the NTSC C64.

---

[Back to Home](https://github.com/kenjennings/Atari-OSC036/blob/master/README.md "Home") 
