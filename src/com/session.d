/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module com.session;
import ct.base;
import com.fb;
import ui.ui;
import seq.sequencer;

struct EditorState {
	__gshared Song song;
	PosDataTable fplayPos, seqPos;
	int octave = 3;
	int activeInstrument;
	bool autoinsertInstrument = true;
	bool shortTitles = true;
	bool displayHelp = true;
	bool keyjamStatus = false;
	bool allowInstabNavigation = true;
	string filename;
}

UI mainui;
Video video;
Screen screen;
EditorState state;

@property song() {
	return state.song;
}

@property seqPos() {
	return state.seqPos;
}

@property fplayPos() {
	return state.fplayPos;
}

void initSession() {
	state.song = new Song();
	state.seqPos = new PosDataTable();
	state.fplayPos = new PosDataTable();
	for(int i = 0; i < 3; i++) {
		state.seqPos[i].tracks = song.tracks[i];
		state.fplayPos[i].tracks = song.tracks[i];
	}
}
