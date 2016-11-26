Autokbisw - Automatic keyboard input source switcher
=========

Motivation
---------

This small utility was born out of frustation after a mob programming sesssion.
The session took place on a french mac book pro, using a pair of french pc
keyboards. Some programmers were used to eclipse, others to intellij on linux,
others to intellij on mac. 

While OSx automatically switches the layout when a keyboard is activated it
doesn't change the keymap, meaning we had to remember changing both the os _and_
the IDE keymap each time we switched developper. 

This software removes one of the switches: it memorizes the last active osx
input source for a given keyboard and restores it automatically when that
keyboard becomes the active keyboard. 

Installation 
---------

Until someone contributes a better way, either build from source using 
```
xcodebuild -scheme autokbis build
```
and run the resulting program

*or*

Download one of the binary packages from this repository releases, unzip its
content to whatever folder suits you and run it. 


