/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module seq.sequencer;
import main;
import com.fb;
import ui.ui;
import ct.base;
import com.session;
import com.util;
import ui.input;
import ui.dialogs;

	import seq.fplay;
	import seq.tracktable;
	import seq.seqtable;
	import seq.trackmap;

import derelict.sdl.sdl;
import std.string;
import std.stdio;

enum PAGESTEP = 2;
enum Jump { toBeginning = 0, toMark = -1, toEnd = -2, toWrapMark = -3 };

enum playbackBarColor = 6;
enum wrapBarColor = 4;

bool displaySequenceRowcounter = true;
int stepValue = 1;
int activeVoiceNum;
private int stepCounter;
int tableTop = 15, tableBot = -16;
enum anchor = 16;
Clip[] clip;

private {
	bool useRelativeNotes = true;
}

struct RowData {
	Track trk; 
	alias trk track;
	// offset in tracklist, checked against endmark
	int trkOffset; 
	// offset in tracklist, not checked
	int trkOffset2;
	int seqOffset;
	Sequence seq; // full sequence, cursor is at seq[seqOffset]
	//Sequence clipped; // clipped sequence, from cursor downwards
	int clippedRows;
	Element element; // data entry under cursor
}

struct VoiceInitParams {
	Tracklist t;
	Rectangle a;
	PosData p;
	VoiceTable voiceTable;
}

class PosData {
	int pointerOffsetValue = anchor;
	int trkOffset = 0;
	int seqOffset;
	int mark; 
	int rowCounter;
	Tracklist tracks;

	@property int pointerOffset() {
		return pointerOffsetValue - anchor;
	}
	
	@property int pointerOffset(int i) {
		return pointerOffsetValue = i + anchor;
	}
	
	@property int rowOnCursor() {
		return seqOffset + pointerOffset;
	}
	
	int getRowCounter() {
		int counter;
		for(int i = 0; i <= trkOffset; i++) {
			Track t = tracks[i];
			counter += song.sequence(t).rows;
		}
		return counter + seqOffset;
	}
	
}

class PosDataTable {
	PosData[] pos;

	PosData opIndex(int idx) {
		return pos[idx];
	}

	this() {
		pos.length = 3;
		foreach(ref p; pos) p = new PosData;
	}
	
	@property int pointerOffset(int o) { 
		foreach(ref p; pos) { p.pointerOffset = o; }
		return 0;
	}
	
	@property int pointerOffset() {
		return pos[0].pointerOffset;
	}
	
	@property int normalPointerOffset() { 
		int r = tableTop + pos[0].pointerOffset;
		return r;
	}
			
	@property int rowCounter() { 
		return pos[0].rowCounter; 
	}
	
	@property int rowCounter(int o) { 
		foreach(ref p; pos) { p.rowCounter = o; }
		return 0;
	}

	PosDataTable dup() {
		auto pt = new PosDataTable();
		pt.copyFrom(this);
		return pt;
	}
	
	void copyFrom(PosDataTable pt) {
		for(int i = 0 ; i < 3; i++) {
			PosData p = pos[i];
			PosData t = pt[i];
			p.pointerOffset = t.pointerOffset;
			p.seqOffset = t.seqOffset;
			p.trkOffset = t.trkOffset;
			p.rowCounter = t.rowCounter;
			p.mark = t.mark;
		}
	}
}

// ------------------------------------------------------------------------
// ------------------------------------------------------------------------

abstract class Voice : Window {
	Tracklist tracks;
	PosData pos;
	RowData activeRow;
	Input input;
	alias input activeInput;
	VoiceTable parent;
	
	this(ref VoiceInitParams v) {
		super(v.a);
		tracks = v.t; pos = v.p;
		parent = v.voiceTable;
	}

public:

	bool atBeg() { 
		return pos.trkOffset <= 0
			&& (pos.seqOffset + pos.pointerOffset) <= 0;
	}

	bool atEnd() {
		RowData s = getRowData(pos.trkOffset, 
									   pos.seqOffset + pos.pointerOffset);
		return (s.trk.trans >= 0xf0);
	}
	
	bool pastEnd() { return pastEnd(0); }
	
	bool pastEnd(int y) {
		RowData s = getRowData(pos.trkOffset,
							   pos.seqOffset + y);
		int t = s.trkOffset2 - 1;
		if(t < 0) return false;
		Track trk = tracks[t];
		return (trk.trans >= 0xf0);
	}

	void trackFlush(int y) { return; }

	override void refresh() { refreshPointer(0); }

	RowData getRowData(int trkofs, int seqofs) {
		static RowData s;
		int trkofs2 = trkofs;
		Sequence seq;
		int lasttrk = tracks.trackLength;
		Sequence getSeq(Track t) {
			if(t.trans >= 0xf0) return song.seqs[0];
			else return song.seqs[t.number];
		}
		int numRowsInSeq() {
			if(tracks[trkofs2].trans >= 0xf0)
				return 1;
			return getSeq(tracks[trkofs2]).rows;
		}

		if(trkofs > lasttrk) trkofs = lasttrk;
		s.trk = tracks[trkofs];

		seq = getSeq(s.trk);

		while (seqofs < 0)  {
			seqofs += numRowsInSeq();
			if(--trkofs < 0) {
				trkofs = 0;
				seqofs = 0;
				break;
			}
			--trkofs2;
			s.trk = tracks[trkofs];
			seq = song.seqs[s.trk.number];
		} 
		assert(seqofs >= 0);

		while(seqofs >= numRowsInSeq()) {
			seqofs -= numRowsInSeq();
			if(trkofs < lasttrk)
				trkofs++;
			trkofs2++;
			s.trk = tracks[trkofs2];
			seq = getSeq(s.trk);
		}
		s.seqOffset = seqofs;
		s.clippedRows = seq.rows - seqofs;
		s.trkOffset = trkofs;
		s.trkOffset2 = trkofs2;
		s.element = seq.data[seqofs];
		if(useRelativeNotes) {
			int t = trkofs;
			while(t >= 0 && tracks[t].trans == 0x80) t--;
			if(t >= 0)
				s.element.transpose = tracks[t].trans - 0xa0;
		}
		s.seq = seq;
		return s;
	}
	
	RowData getRowData(int tofs) {
		return getRowData(tofs, 0);
	}

	void scroll(int steps) {
		scroll(steps, true);
	}

 	void scroll(int steps, bool canWrap) {
		int oldRowcounter;
		RowData s = getRowData(pos.trkOffset);
		assert(s.seq.rows == s.clippedRows);
		with(pos) {
			seqOffset = seqOffset + steps;
			oldRowcounter = rowCounter;
			rowCounter += steps;
			while(seqOffset + pointerOffset < 0) {
				if(--trkOffset < 0) {
					if(canWrap) {
						trkOffset = tracks.trackLength - 1;
						rowCounter = getRowCounter();
					}
					else trkOffset = 0;
				} 
				s = getRowData(trkOffset);
				seqOffset += s.clippedRows;
				steps += s.clippedRows;
			}
			while(seqOffset + pointerOffset >= s.clippedRows) {
				seqOffset -= s.clippedRows;
				steps -= s.clippedRows;
				if(++trkOffset >= tracks.trackLength) {
					if(canWrap) {
						trkOffset = 0;
						rowCounter = seqOffset;
					}
					else { 
						trkOffset = tracks.trackLength - 1; 
						rowCounter = oldRowcounter;
					}
				}
				s = getRowData(trkOffset);
			}
		}
	}

	// TODO: move elsewhere...
	int getRowcounter(int trkofs) {
		int counter = 0;
		for(int i = 0; i < trkofs; i++) {
			Track t = tracks[i];
			counter += song.sequence(t).rows;
		}
		return counter;
	}


protected:
	
	override void update();
	
	void refreshPointer() {
		refreshPointer(pos.pointerOffset);
	}
	
	void refreshPointer(int y);

	void jump(int jumpto) {
		if(jumpto == Jump.toMark) jumpto = pos.mark;
		else if(jumpto == Jump.toWrapMark) jumpto = tracks.wrapOffset;
		assert(jumpto >= 0);
		pos.trkOffset = jumpto;
		pos.seqOffset = 0;
		pos.rowCounter = getRowcounter(jumpto);
	}    

	void setMark() {
		setMark(1);
	}
	
	// when m == 1, sets mark to current trkOffsets
	// when m == 0, zeroes it out
	void setMark(int m) {
		pos.mark = m ? activeRow.trkOffset : 0;
	}
	alias setMark setPositionMark;

	void setWrapMark() {
		tracks.wrapOffset = cast(ushort) (activeRow.trkOffset);
	}

	string formatTrackValue(int trknum) {
		if(trknum >= 0xf000)
			return "LOOP";
		return format("%04X", trknum);
	}
}

abstract class VoiceTable : Window {
	Voice[3] voices;
	Voice active;
	alias active activeVoice;
	PosDataTable posTable;
	
	this(Rectangle a, PosDataTable pi) {
		super(a);
		posTable = pi;
		activeVoice = voices[0];
	}

	override void activate() {
		activeVoice = voices[activeVoiceNum];
		input = activeVoice.activeInput;
		refresh();
	}

	override void deactivate() {
		activeVoice.trackFlush(posTable.pointerOffset);
	}

	override void refresh() {
		foreach(v; voices) {
			v.refresh(); 
		}
	}

	void centralize() {
		jump(activeVoice.activeRow.trkOffset,true);
	}

	override int keypress(Keyinfo key) {
		if(key.mods & KMOD_SHIFT) {
			switch(key.raw)
			{
			case SDLK_HOME:
				jump(Jump.toBeginning,true);
				break;
			case SDLK_END:
				jump(Jump.toEnd,true);
				break;
			case SDLK_PAGEUP:
				step(-PAGESTEP * 2 * song.highlight);
				break;
			case SDLK_PAGEDOWN:
				step(PAGESTEP * 2 * song.highlight);
				break;
			default:
				break;
			}
		}
		else if(key.mods & KMOD_CTRL) {
			switch(key.raw)
			{
			case SDLK_h, SDLK_HOME:
				jump(Jump.toMark,true);
				break;
			case SDLK_l:
				centralize();
				break;
			case SDLK_m:
				if(song.highlight < 16) 
					song.highlight++;
				break;
			case SDLK_n:
				if(song.highlight > 1)
					song.highlight--;
				break;
			case SDLK_0:
				song.highlightOffset = posTable.rowCounter+posTable.pointerOffset;
				break;
			case SDLK_e:
				displaySequenceRowcounter ^= 1;
				break;
			case SDLK_t:
				useRelativeNotes ^= 1;
				UI.statusline.display(format("Relative notes %s.", useRelativeNotes ?  "enabled" : "disabled"));
				break;
			case SDLK_F1:
				setPositionMark();
				break;
			case SDLK_BACKSPACE:
				setWrapMark();
				break;
			default:
				break;
			}
		}
		else switch(key.raw)
			 {
			 case SDLK_BACKSPACE, SDLK_PLUS:
				 setPositionMark();
				 break;
			 default:
				 break;
			 }

		// we don't care about mods with these keys
		switch(key.raw)
		{
		case SDLK_DOWN:
			if(key.mods & KMOD_SHIFT) 
				goto case SDLK_PAGEDOWN;
			else if(key.mods & KMOD_CTRL) {
				scroll(1);
				step(-1);
			}
			else step(1);
			break;
		case SDLK_UP:
			if(key.mods & KMOD_SHIFT)
				goto case SDLK_PAGEUP;
			else if(key.mods & KMOD_CTRL) {
				scroll(-1);
				step(1);
			}
			else step(-1);
			break;
		case SDLK_PAGEUP:
			step(-PAGESTEP * song.highlight);
			break;
		case SDLK_PAGEDOWN:
			step(PAGESTEP * song.highlight);
			break;
		case SDLK_TAB:
			foreach(v; voices) { v.input.nibble = 0; }
			if(key.mods & KMOD_SHIFT)
				stepVoice(-1);
			else stepVoice();
			break;
		default:
			break;
		}
		return OK;
	}

	void stepVoice() { stepVoice(1); }
	
	void stepVoice(int i) {
		// safety check - if we're past endmark on all voices,
		// exit the method -- can happen if all tracklists
		// contain only FF00
		bool pastAll = true;
		foreach(voice; voices) {
			if(!voice.pastEnd(posTable.pointerOffset))
				pastAll = false;
		}
		if(pastAll) return;
		int nv = umod(activeVoiceNum + i, 0, 2);
		while(voices[nv].pastEnd(posTable.pointerOffset)) {
			nv = umod(nv + i, 0, 2);
		}
		activateVoice(nv);
	}

	void scroll(int st) {
		foreach(v; voices) { v.scroll(st); }
	}

	void activateVoice(int voice) {
		deactivate();
		activeVoiceNum = voice;
		activate();
		voices[voice].refreshPointer();
		step(0);
	}

	void jumpToVoice(int voice) {
		deactivate();
		activeVoiceNum = voice;
		activate();
		// making sure cursor is not past endmark
		step(0);
	}
	
	override void update() {
		input = activeVoice.activeInput; 
		foreach(v; voices) { 
			v.refreshPointer(posTable.pointerOffset);
			v.update(); 
			
		}
		// statusline
		screen.cprint(area.x + 1, area.y, 1, 0, format("#%02X",song.subtune));
		for(int i = 0, x = area.x + 5 + com.fb.border; i < 3; i++) {
			Voice v = voices[i];
			RowData c = v.activeRow;
			screen.cprint(x, area.y, 1, 0,
				format("+%03X %02X %s", c.trkOffset, c.trk.number,
					   audio.player.muted[i] ? "Off" : "   ") );
			x += 13 + com.fb.border;
		}
		// row counter
		int r = activeVoice.pos.rowCounter - anchor;
		for(int y = 0; y < area.height; y++) {
			string s = "    ";
			if(r >= 0) s = format("%+4X", r);
			r++;
			screen.cprint(area.x, area.y + y + 1, 12, 0, s);
		}

	}
	
	void setPositionMark() {
		int rows = -1;
		foreach(v; voices) {
			if(rows < 0)
				rows = v.pos.rowOnCursor;
			if(rows != v.pos.rowOnCursor)
				UI.statusline.display("Warning: The start point is not aligned! The song will play incorrectly.");

			v.setPositionMark();
		}
	}

	void setWrapMark() {
		int rows = -1;
		foreach(v; voices) {
			if(rows < 0)
				rows = v.pos.rowOnCursor;
			if(rows != v.pos.rowOnCursor)
				UI.statusline.display("Warning: The loop point is not aligned! The song will loop incorrectly.");

			v.setWrapMark();
		}
	}

	void jump(int to, bool doCtr) {
		switch(to) {
		case Jump.toBeginning:
			posTable.pointerOffset = 0;
			foreach(v; voices) {
				v.jump(Jump.toBeginning);
			}
			if(doCtr) centerTo(0);
			break;
		case Jump.toMark:
			posTable.pointerOffset = 0;
			foreach(v; voices) {
				v.jump(Jump.toBeginning);
				v.jump(v.pos.mark);
			}
			if(doCtr) centerTo(0);
			break;
		case Jump.toWrapMark:
			posTable.pointerOffset = 0;
			foreach(v; voices) {
				v.jump(Jump.toBeginning);
				v.jump(v.tracks.wrapOffset);
			}
			if(doCtr) centerTo(0);
			break;
		case Jump.toEnd:
			centralize();
			toSeqStart();

			foreach(v; voices) {
				v.jump(Jump.toBeginning);
			}

			int e = activeVoice.tracks.trackLength - 1;
			
			for(int i = 0; i < e; i++) {
				activeVoice.refreshPointer(posTable.pointerOffset);
				RowData s = activeVoice.getRowData(i);
				step(s.seq.rows);
			}
			activeVoice.refreshPointer(posTable.pointerOffset);
			toSeqEnd();
			break;
		default:
			if(to < 0) {
				to = activeVoice.pos.mark;
			}
			foreach(v; voices) {
				v.jump(Jump.toBeginning);
			}
			Voice v = activeVoice;
			posTable.pointerOffset = 0;
			for(int i = 0; i < to; i++) {
				activeVoice.refreshPointer(0);
				int trk = v.tracks[i].number;
				Sequence s = song.seqs[trk];
				step(s.rows);
			}
			if(doCtr) centerTo(0);
			break;
		}
		refresh();
	}

	void toSeqStart() {
		int st = -activeVoice.activeRow.seqOffset;
		this.step(st,0);
	}

	void toSeqEnd() {
		int rows = activeVoice.activeRow.seq.rows;
		int seqend = rows -
			activeVoice.activeRow.seqOffset - 1;
		step(seqend);
	}

	void toScreenTop() {
		step(-posTable.normalPointerOffset);
	}
	
	void toScreenBot() {
		int scrend = tableTop - posTable.pointerOffset - 1;
		step(scrend);
	}

	void centerTo(int center) {
		assert(center < tableTop && center >= tableBot);
		int steps = center - posTable.pointerOffset;
		foreach(v; voices) {
			v.scroll(-steps);
		}
		posTable.pointerOffset = center;
		step(0,1,1);
	}

	void step(int s) { step(s, 0); }
	void step(int s, int e) {
		step(s, e, area.height);
	}

	void step(int st, int extra, int height) {
		bool wrapOk = true;
		bool atBeg = activeVoice.atBeg();
		if(st < 0 && atBeg && stepCounter > 0) {
			st = 0;
			wrapOk = false;
		}
	
		posTable.pointerOffset = 
			posTable.pointerOffset + st;

		bool atEnd = activeVoice.atEnd();

		if(atEnd && stepCounter > 1) {
			posTable.pointerOffset = 
				posTable.pointerOffset - st;
			st = 0;
			wrapOk = false;
		}
		int r;
		if(posTable.pointerOffset >= tableTop) {
			r = -(height/2-posTable.pointerOffset-1);
			posTable.pointerOffset = tableTop - 1;
		}
		else if(posTable.pointerOffset < tableBot) {
			r = (posTable.pointerOffset+height/2);
			posTable.pointerOffset = tableBot;

		}

 		stepCounter++;

		int d = r > 0 ? 1 : - 1;
		if(r == 0) d = 0;
		int i;

		doStep(wrapOk,r);

		if(d <= 0) return;
		assert(extra >= 0);
		posTable.pointerOffset = 
			posTable.pointerOffset - extra;

		doStep(true,extra);
	}

	protected void doStep(bool wrapOk, int r) {
		foreach(v; voices) {
			bool wrap = wrapOk;
			v.scroll(r,wrap);
		}
	}

	// for seq copy/insert/etc 
	RowData getRowData() {
		return activeVoice.activeRow;
	}

	Sequence getActiveSequence() {
		return activeVoice.activeRow.seq;
	}

	// helper for trackcopy/paste
	Tracklist getTracklist(Voice v) {
		return v.tracks[v.activeRow.trkOffset .. v.tracks.length];
	}
}

// -------------------------------------------------------------------

final class Sequencer : Window, Undoable {
	private {
		VoiceTable[] voiceTables;
		TrackmapTable trackmapTable;
		SequenceTable sequenceTable;
		TrackTable trackTable;
		QueryDialog queryCopy, queryAppend;
		PosDataTable[] postables;
	}
	VoiceTable activeView;
	//private Clip[] clip;
	
	this(Rectangle a) {
		int h = screen.height - 10;
		super(a,ui.help.HELPSEQUENCER);
		trackmapTable = new TrackmapTable(a, seqPos);
		sequenceTable = new SequenceTable(a, seqPos);
		trackTable = new TrackTable(a, seqPos);
		voiceTables = [cast(VoiceTable)trackmapTable, sequenceTable, trackTable];
		activeView = sequenceTable;
		activeView.activate();
		activateVoice(0);
		
		queryAppend = new QueryDialog("Insert this sequence to cursor pos: $",
								  &insertCallback, 0x80);
								  
		queryCopy = new QueryDialog("Copy this sequence to cursor seq: $",
								&copyCallback, 0x80);
		
		// top & bottom
		tableBot = -area.height / 2;
		tableTop = area.height / 2;
		sequenceTable.centerTo(0);

		postables.length = 32;
		foreach(ref p; postables) {
			p = new PosDataTable;
		}
		
	}

	void activateVoice(int n) {
		activeView.jumpToVoice(n);
		input = activeView.input;
	}
	
	void reset() { reset(true); }
	
	void reset(bool tostart) {
		activeView.deactivate();
		if(tostart) {
			foreach(b; voiceTables) {
				b.toSeqStart();
			}
			sequenceTable.jump(Jump.toBeginning,true);

			foreach(ref p; postables) {
				p = new PosDataTable;
			}
		}
		activeView = sequenceTable;
		activeView.activate();
	}

	void resetMark() {
		foreach(v; activeView.voices) {
			v.setPositionMark(0);
		}
	}

	Voice[] getVoices() {
		return activeView.voices;
	}

	override int keypress(Keyinfo key) {
		if(key.raw >= SDLK_KP0 && key.raw <= SDLK_KP9) {
			stepValue = key.raw - SDLK_KP0;
			return OK;
		}
		if(key.mods & KMOD_ALT) {
			switch(key.raw) {
			case SDLK_a:
				mainui.activateDialog(queryAppend);
				break;
			case SDLK_c:
				mainui.activateDialog(queryCopy);
				break;
			case SDLK_RIGHT:
				changeSubtune(1);
				break;
			case SDLK_LEFT:
				changeSubtune(0);
				break;
			default:
				return activeView.keypress(key);
			}
		}
		else if(key.mods & KMOD_CTRL) {
			switch(key.raw) {
			case SDLK_F12:
				mainui.activateDialog(
					new DebugDialog(activeView.activeVoice.activeRow.seq));
				break;
			default:
				return activeView.keypress(key);
			 }
		}
		else switch(key.raw)
			 {
			 case SDLK_F5:
				 void activateTracktable() {
					 activeView.deactivate();
					 activeView.toSeqStart();
					 activeView = trackTable;
					 activeView.activate();
				 }
				 if(activeView != trackTable) {
					 activateTracktable();
					 trackTable.displayTracklist = (key.mods & KMOD_SHIFT) > 0;
					 break;
				 }
				 if(key.mods & KMOD_SHIFT) {
					 activateTracktable();
					 trackTable.displayTracklist(true);
					 break;
				 }
				 goto case SDLK_F6;
			 case SDLK_F6:
				 activeView.deactivate();
				 activeView = sequenceTable;
				 activeView.activate();
				 // making sure cursor is not past endmark
				 activeView.step(0);
				 break;
			 case SDLK_F7:
				 activeView.deactivate();
				 if(activeView == trackmapTable) {
					 activeView.toSeqStart();
					 activeView = trackTable;
				 } 
				 else {
					 activeView.toSeqStart();
					 activeView.centerTo(0); // scroll to upmost pos
					 activeView = trackmapTable;
				 }
				 activeView.activate();
				 break;
/+
			 case SDLK_MINUS:
				 if(octave > 0)
					 octave--;
				 break;
			 case SDLK_PLUS:
				 if(octave < 6)
					 octave++;
				 break;
+/
			 default:
				 return activeView.keypress(key);
			 }
		return OK;
	}

	override int keyrelease(Keyinfo key) {
		stepCounter = 0;
		// lazily skipping the "view" layer (so no keyrelease event ever gets there at the moment)
		activeView.activeVoice.keyrelease(key);
		return OK;
	}

	override void clickedAt(int x, int y, int button) {
		foreach(idx, Voice v; activeView.voices) {
			if(v.area.overlaps(x, y)) {
				activateVoice(cast(int)idx);
				activeView.clickedAt(x - area.x, y - area.y, button);
			}
		}
	}

protected:

	void changeSubtune(int direction) {
		postables[song.subtune].copyFrom(activeView.posTable);
		
		refresh();
		mainui.stop();
		activeView.jump(0,false);
		resetMark();

		direction > 0 ?
			song.incSubtune() :
			song.decSubtune();

		activeView.posTable.copyFrom(postables[song.subtune]);
		activeView.activate();
		refresh();
		activeView.step(0);
	}
	
	override void update() {
		activeView.update();
		input = activeView.input;
	}

	override void activate() {}

	override void deactivate() {
		activeView.deactivate();
	}

	override void refresh() {
	  foreach(b; voiceTables) {
	    b.refresh();
	  }
	}

	override final void undo(UndoValue entry) {
		if(entry.subtuneNum != song.subtune)
			return;

		with(entry) {
			auto data = array.target;
			auto target = array.source;
			target[] = data;
			seq.refresh();
			activeView.posTable.copyFrom(entry.posTable);
		}
		refresh();
		activeView.step(0);
	}

	override final UndoValue createRedoState(UndoValue value) {
		value.array.target = value.array.source.dup;
		return value;
	}

private:

	void saveState() {
		UndoValue v;
		import std.typecons;
		RowData s = activeView.getRowData();
		v.array = UndoValue.Array(s.seq.data.raw.dup,
								  s.seq.data.raw);
		v.seq = s.seq;
		v.posTable = activeView.posTable.dup();
		v.subtuneNum = song.subtune;
		com.session.insertUndo(this, v);
	}

	void insertCallback(int param) {
		saveState();
		if(param >= MAX_SEQ_NUM) return;
		RowData s = activeView.getRowData();
		Sequence fr = song.seqs[param];
		Sequence to = s.seq;
		to.insertFrom(fr, s.seqOffset);
		activeView.step(0);
	}

	void copyCallback(int param) {
		saveState();
		if(param >= MAX_SEQ_NUM) return;
		RowData s = activeView.getRowData();
		Sequence fr = song.seqs[param];
		Sequence to = s.seq; 
		to.copyFrom(fr);
		activeView.step(0);
	}
}
