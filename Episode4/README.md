# Atari-OSC036 Episode 4
Atari port of OldSkoolCoder's C64 Tutorial 36, Episode 4 -  ***WORK IN PROGRESS***

---

Assembly program that implements fine scrolling by shifting bitmapped images through a character set for the VIC-20.  This is fundamentally the same as the C64 version, but the VIC-20 has a smaller screen geometry.

In the Atari's case this is using ANTIC Mode 7 text (BASIC GRAPHICS MODE 1) which uses half the character set of a normal text mode.  Since the number of characters on the line is also half, the scrolling code shifting character set data now completes reasonably quickly in less than one video frame.

---

[Back to Home](https://github.com/kenjennings/Atari-OSC036/blob/master/README.md "Home") 
