# Autokbisw - Automatic keyboard input source switcher
## This project has migrated

@ohueter has taken upon himself to fix the build on newer versions of OSX, 
the most up to date version of autokbisw can now be found on his fork 
https://github.com/ohueter/autokbisw

This repository is no longer maintained

## Motivation

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

## Installation 

### From Binaries

Download one of the binary packages from this repository releases, unzip its
content to whatever folder suits you and run it. 

If you want the program to start automatically when you log in,
you can copy the provided plist file to `~/Library/LaunchAgents` and load it
manually for the first run: 
```
cp eu.byjean.autokbisw.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/eu.byjean.autokbisw.plist
```

### Via [Homebrew](https://brew.sh)

`brew install jeantil/autokbisw/autokbisw`

### From Source

Clone this repository, make sure you have xcode installed and run the following command:
```
swift build --configuration release
```
In the output will be the path to the built program, something like `${PWD}/.build/release/autokbisw`.

You can run it as is or _install_ it : 

```
cp ${PWD}/.build/release/autokbisw /usr/local/bin/
cp autokbisw/eu.byjean.autokbisw.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/eu.byjean.autokbisw.plist
```
