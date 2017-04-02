/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module com.session;
import ct.base;
import com.fb;
import com.util;
import ui.ui;
import seq.sequencer;
import std.typecons;

interface Undoable {
	void undo(UndoValue);
	UndoValue createRedoState(UndoValue);
}

struct TracklistStore {
	Tracklist store, source;
}

struct UndoValue {
	import ct.base;

	alias Array = Tuple!(ubyte[], "target", ubyte[], "source");

	// undo data needed by sequencer
	Array array;
	Sequence seq;
	// undo data needed by track editor
	TracklistStore[] trackLists;
	ushort trackValue;
	Track track;
	ubyte[][] tableData;
	int subtuneNum;
	PosDataTable posTable;
	bool allVoices;
}

struct UndoState {
	Undoable func;
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

void insertUndo(Undoable undoable, UndoValue value) {
	state.undoQueue.insert(UndoState(undoable, value));
}

void executeUndo() {
	if(state.undoQueue.empty) return;
	auto u = state.undoQueue.pop();
	// make entry for redo (copy current state)
	auto redo = makeRedoOrUndo(u);
	state.redoQueue.insert(redo);
	u.func.undo(u.value);
}

void executeRedo() {
	if(state.redoQueue.empty) return;
	auto r = state.redoQueue.pop();
	// make entry for undo (copy current state)
	auto undo = makeRedoOrUndo(r);
	state.undoQueue.insert(undo);
	r.func.undo(r.value);
}

private UndoState makeRedoOrUndo(UndoState state) {
	state.value = state.func.createRedoState(state.value);
	return state;
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
	for(int i = 0; i < 3; i++) {
		state.seqPos[i].tracks = song.tracks[i];
		state.fplayPos[i].tracks = song.tracks[i];
	}
}
