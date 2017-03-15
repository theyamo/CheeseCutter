/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module com.session;
import ct.base;
import com.fb;
import com.util;
import ui.ui;
import seq.sequencer;

struct UndoState {
	UndoFunc func;
	UndoValue value;
}

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
	auto undoQueue = Queue!UndoState();
	auto redoQueue = Queue!UndoState();
}

UI mainui;
Video video;
Screen screen;
EditorState state;

void insertUndo(UndoFunc fun, UndoValue value) {
	state.undoQueue.insert(UndoState(fun, value));
}

void executeUndo() {
	if(state.undoQueue.empty) return;
	auto u = state.undoQueue.pop();
	// make entry for redo (copy current state)
	auto redo = u;
	redo.value.dump[0] = redo.value.dump[1].dup;
	state.redoQueue.insert(redo);
	u.func(u.value);
}

void executeRedo() {
	if(state.redoQueue.empty) return;
	auto r = state.redoQueue.pop();
	// make entry for undo (copy current state)
	auto undo = r;
	undo.value.dump[0] = undo.value.dump[1].dup;
	state.undoQueue.insert(undo);
	r.func(r.value);
}

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
	for(int i = 0; i < 6; i++) {
		state.seqPos[i].tracks = song.tracks[i];
		state.fplayPos[i].tracks = song.tracks[i];
	}
}
