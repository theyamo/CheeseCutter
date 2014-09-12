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
int octave = 3;
int activeInstrument;
bool autoinsertInstrument = true;
bool shortTitles = true;
bool displayHelp = true;

void initSession() {
	song = new Song();
	seqPos = new PosinfoTable();
	fplayPos = new PosinfoTable();
	for(int i = 0; i < 3; i++) {
		seqPos[i].tracks = song.tracks[i];
		fplayPos[i].tracks = song.tracks[i];
	}
}