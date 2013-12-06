/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module com.session;
import ct.base;
import com.fb;
import ui.ui;
import seq.sequencer;

__gshared Song song;

UI mainui;
Video video;
Screen screen;
PosinfoTable fplayPos, seqPos;
int highlight = 4;
int highlightOffset = 0;

void initSession() {
	song = new Song();
	seqPos = new PosinfoTable();
	fplayPos = new PosinfoTable();
	highlight = 4;
	highlightOffset = 0;
	for(int i = 0; i < 3; i++) {
		seqPos[i].tracks = song.tracks[i];
		fplayPos[i].tracks = song.tracks[i];
	}
}