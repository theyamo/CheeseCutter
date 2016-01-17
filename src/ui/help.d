/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module ui.help;

import std.string : format;
import com.util;

struct ContextHelp {
	string title;
	string[] text;
}

ContextHelp HELPMAIN = ContextHelp("Main help", 
["
Escape (x2).....Quit program
F10.............Open the Load song dialog
F11.............Open the Save song dialog
F9..............Open the About dialog
Ctrl-F11........Quick save song (doesn't ask a filename)

`+dPlayback\n
F1..............Play from playback mark
Shift-F1........Play / resume from mark with tracking
F2..............Play from the start
Shift-F2........Play / resume from the start with tracking
F3..............Play from cursor position
F4..............Stop playback
F8..............Fast forward (w/ Shift = Fast forward more)
Scroll Lock.....Start/stop tracking (works only when playing)
Ctrl-1,2,3......Toggle voices on/off
Ctrl-F9.........Show/hide playback info (works only when playing)

`+dSong variables\n
Ctrl-Keypad - +.........Decrease/increase default song speed
[ ] (AltGr-8 / AltGr-9).Decrease/increase default song speed
Alt-Keypad - +..........Decrease/increase multispeed framecall counter 
{ } (AltGr-7 / AltGr-0).Decrease/increase multispeed framecall counter
Ctrl-F3.................Toggle SID type (6581/8580)
Ctrl-F8.................Select next SID filter preset
Ctrl-Shift-F8...........Select previous SID filter preset
Alt-T...................Edit title / author / release info
Ctrl-Alt-C..............Clear sequences (press TWICE to activate)
Ctrl-Alt-O..............Optimize (clear unused sequences & data)
", "
`+dMoving between tables\n
Tab.....................Move cursor between subwindows
Ctrl-Tab................Move cursor between main windows
                        (sequencer, instrument table, subtables)
Alt-V...................Jump to Sequencer
Alt-I...................Jump to Instrument table
Alt-M...................Jump to Cmd table
Alt-P...................Jump to Pulse table
Alt-F...................Jump to Filter table
Alt-D...................Jump to Chord table
Alt-1, 2, 3.............Jump to voice 1, 2 or 3
Alt-4-8 can also move between tables (in the aforementioned order,
so Alt-4 = Sequencer, Alt-5 = Ins, ...)

`+dInstrument table functions\n
Ctrl-L..................Load current insturment from disk
Ctrl-S..................Save current instrument to disk
Ctrl-D..................Delete current instrument
Ctrl-C..................Copy instrument to clipboard
Ctrl-V..................Paste instrument from clipboard

`+dPlayer reference\n
Check out the player reference guide from the CheeseCutter homepage.

`+dCheeseCutter homepage:
http://theyamo.kapsi.fi/ccutter

"]);

ContextHelp HELPSEQUENCER = ContextHelp("Sequencer help",
["`+1Press F12 again to see the global help.

`+dGeneral

Alt-1,2,3...............Jump to voice 1, 2 or 3
Tab.....................Move cursor to the next voice

Keypad / *..............Decrease/increase base octave value
Ctrl-Keypad - +.........Decrease/increase default song speed
[ ] (AltGr-8 / AltGr-9).Decrease/increase default song speed
Keypad - +..............Decrease/increase active instrument number
Keypad 1-9..............Set cursor step value (used when entering notes)
Alt-Left/Right..........Activate previous/next subtune

F5......................Enter to the track column
Shift-F5................Display tracks alongside the sequences
F6......................Enter to the note column
F7......................Display tracks only ('overview mode')

Home/End................Move cursor to SEQ start/end OR screen top/bottom
Shift-Home/End..........Move cursor to song start/end
Backspace...............Set playback start mark (the blue bar) to current position
Ctrl-Home/Ctrl-H........Jump to playback mark position (also realigns the voices)

Alt-C...................Ask for a SEQ number and copy contents over current SEQ
Alt-A...................Ask for a SEQ number and insert contents to cursor pos
(Shift-)Insert/Delete...Insert/delete a row (Shift=w/ sequence expand/shrink)
Ctrl-Insert/Delete......Expand/shrink the sequence
Shift-Enter.............Quick expand sequence (expands by highlight value * 4)
Ctrl-Q/A................Transpose semitone up/down
","Ctrl-W/S................Transpose octave up/down
Ctrl-M/N................Increase/decrease row highlight value
Ctrl-0(zero)............Reset highlighting to current row
Ctrl-R..................Show/hide row counters for sequences
Ctrl-T..................Toggle notes relative to current transpose
Keypad 0................Play notes for all voices in current row
Ctrl-P..................Split current sequence into two from cursor pos.
                        `+dUse with caution.


`+dIn the note column (F6)

 2 3   5 6 7   9 0
Q W E R T Y U I O P.....Enter notes (base octave+1)
 S D   G H J
Z X C V B N M...........Enter notes (base octave)

1.......................Enter a gate off (===)
A or !..................Enter a gate on (+++)
Space or '.'............Clear
Space...................Insert previously entered instrument/command value
                        (in instrument/command column only)
- +.....................Decrease/increase base octave
';'.....................Toggle insert instrument value automatically-mode
','.....................Change the note in current row to a tie note
Enter...................Grab the instrument value in the current row

`+dIn the track column (F5)

Ctrl-F..................Find next unused sequence starting from current value
< >.....................Select previous/next sequence
Ctrl-Q/A................Transpose all tracks up/down from cursor down
", "`+dIn the track column (F5) (cont.)

Ctrl-C..................Ask for a number and copy the N of tracks into clipboard
Ctrl-V..................Paste copied tracks from the clipboard
Space...................Write the cached sequence number to the track value
Shift-Insert/Delete.....Insert empty track (A000) or delete track from cursor
                        pos down
Ctrl-Enter..............Insert a track to end of voice and move cursor there
Ctrl-Insert/Delete......Insert/delete track to end of voice and move cursor there
Ctrl-Shift-Insert/Del...Insert/delete a track for all voices
Ctrl-Alt-1..............Swap voice's track with voice 1's tracks from crsr down
Ctrl-Alt-2..............Swap voice's track with voice 2's tracks from crsr down
Ctrl-Alt-3..............Swap voice's track with voice 3's tracks from crsr down
"]);


ContextHelp genPlayerContextHelp(string title, char*[] descriptions) {
	string text;
	text = "`+1Press F12 again to see the global help.\n\n`+d" ~ title ~ "\n";
	foreach(idx, char* line; descriptions) {
		text ~= format("\n`0fByte %d: %s", idx + 1, petscii2D(line));
	}
	text ~= "\n\nPress Alt-H to turn the byte descriptions off.";
	ContextHelp ctx = ContextHelp(title, [text]);
	return ctx;
}

