# Atari-OSC036 Episode 3
Atari port of OldSchoolCoders C64 Tutorial 36, Episode 3

---

The original looping code takes longer than a full NTSC frame to execute.  After a number of optimizations to eliminate some comparisons, branches, etc. I managed to just barely squeeze the processing time into one NTSC frame.

The timing is on an NTSC Atari which has a lot more CPU time per frame than a C64, so it is unlikely even these optimizations can be re-port in a practical way back to the C64.

---

[Back to Home](https://github.com/kenjennings/Atari-OSC036/blob/master/README.md "Home") 
