/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module seq.tracktable;
import main;
import seq.sequencer;
import seq.seqtable;
import com.fb;
import com.session;
import com.util;
import ui.ui;
import ui.dialogs;
import ui.input;
import derelict.sdl2.sdl;
import ct.base;


class TrackVoice : SeqVoice {
	InputTrack trackinput;
	bool displayTracklist = false;
	this(VoiceInitParams v) {		
		super(v);
		refreshPointer(0);
		trackinput = new InputTrack(activeRow, &(cast(BaseTrackTable)v.voiceTable).trackValueChanged);
		trackinput.setCoord(area.x,0);
		activeInput = trackinput;
	}

	override void trackFlush(int y) {
		trackinput.flush();
		refreshPointer(y);
	}

	override int keypress(Keyinfo key) {
		return trackinput.keypress(key);
	}

	override void deactivate() {
		super.deactivate();
		with(pos) {
			if(trkOffset >= tracks.trackLength) {
				trkOffset = 0; rowCounter = seqOffset;
			}
		}
	}

	override void update() {
		super.update();
		RowData wseq, cseq;
		int h = area.y + area.h + 1;
		int y,i;
		int trkofs = pos.trkOffset;
		int rows = 0;
		int lasttrk = tracks.trackLength;
 		int counter;
		int scry = area.y + 1; 

		void printTrack() {
			if(!displayTracklist) return;

			screen.cprint(area.x - 1, scry, 1, 0,
						  " " ~ formatTrackValue(wseq.track.smashedValue));

			if(trkofs == pos.mark) {
				for(int i = 0; i < 13; i++) {
					int xpos = area.x + i;
					if(screen.getbg(xpos, scry) == 0)
						screen.setbg(xpos, scry, playbackBarColor);
				}
			}
			if(trkofs == tracks.wrapOffset) {
				for(int i = 0; i < 15; i++) {
					int xpos = area.x + i - 1;
					if(screen.getbg(xpos, scry) == 0)
						screen.setbg(xpos, scry, wrapBarColor);
				}
			}

		}

		trkofs -= pos.pointerOffset + seq.sequencer.anchor;
		counter = getRowcounter(trkofs);

		if(trkofs >= 0)
			wseq = getRowData(trkofs);
		y = area.y + 1;

		while(scry <= area.y + area.height) {
			if(trkofs < 0) {
				scry++;
			}
			else if(trkofs >= lasttrk+1) {
				scry++; trkofs++;
				continue;
			}
			else {
				printTrack(); 
				counter += wseq.seq.rows;
				scry++;
			}
			trkofs++;
			if(trkofs >= 0 && trkofs <= lasttrk) {
				wseq = getRowData(trkofs, 0);
			}
		}
	}

protected:
	
	void refreshTrack(int po) {
		refreshPointer(po);
		trackinput.refresh(activeRow);
		refreshPointer(po);
	}

	void trackInsert(bool doInsert) {
		Track trk = activeRow.track; 
		trackinput.flush();
		{
			if(!doInsert) {
				tracks.expand();
			}
			else {
				tracks.insertAt(activeRow.trkOffset);
				if(pos.trkOffset <= pos.mark)
					pos.mark++;
			}
		}
		trackinput.init(activeRow);
	}
	
	void trackDelete(bool doDelete) {
		trackinput.flush();
		{
			if(!doDelete) {
				
				if(tracks.trackLength == 1) {
					tracks[0].setValue(0xa0, 0);
				}
				tracks.shrink();
			}
			else {
				if(tracks.trackLength == 1) {
					tracks[0].setValue(0xa0, 00);
				}
				else {
					tracks.deleteAt(activeRow.trkOffset);

					// TODO: add check that tracklist hasn't been shrunk below trkOffset
					/+
					if(pos.trkOffset >= tracks.trackLength-1) 
						super.step(-1);+/
				}
			}
		}
		trackinput.init(activeRow);
		if(pos.mark > pos.trkOffset)
			pos.mark--;
		if(pos.mark < 0) pos.mark = 0;
		if(pos.mark >= tracks.trackLength) {
			pos.mark = tracks.trackLength - 1;
		}
	}

	void trackTrans(int d) {
		trackinput.flush();
		{
			tracks.transposeAt(activeRow.trkOffset, tracks.length, d);
		}
		trackinput.init(activeRow);
	}
}

abstract class BaseTrackTable : VoiceTable, Undoable {
	QueryDialog queryClip;

	protected Clip[] clip;
    
	this(Rectangle a, PosDataTable pi) {
		super(a, pi);
		queryClip = new QueryDialog("Copy number of tracks to clipboard: $",
									&clipCallback, 0x80);
		
	}

	void trackValueChanged() {
		saveState(false);
	}
	
	override int keypress(Keyinfo key) {
		if(key.mods & KMOD_CTRL) {
			switch(key.raw)
			{
			case SDLK_INSERT, SDLK_RETURN:
				if(key.mods & KMOD_SHIFT) {
					saveState(true);
					for(int i = 0; i < voices.length; i++) {
						auto v = cast(TrackVoice)voices[i];
						v.trackInsert(true);
					}
				} 
				else {
					saveState(false);
					(cast(TrackVoice)activeVoice).trackInsert(false);
					jump(Jump.toEnd,true);
				}
				return OK;
			case SDLK_DELETE:
				saveState(true);
				if(key.mods & KMOD_SHIFT) {
					for(int i = 0; i < voices.length; i++) {
						auto v = cast(TrackVoice)voices[i];
						v.trackDelete((key.mods & KMOD_SHIFT) > 0);
					} 
				}
				else { 
					(cast(TrackVoice)activeVoice).trackDelete(false);
					jump(Jump.toEnd,true);
				}
				return OK;
			case SDLK_q:
				saveState(true);
				(cast(TrackVoice)activeVoice).trackTrans(1);
				break;
			case SDLK_a:
				saveState(true);
				(cast(TrackVoice)activeVoice).trackTrans(-1);
				break;
			case SDLK_c:
				mainui.activateDialog(queryClip);
				return OK;
			case SDLK_v:
				mainui.activateDialog(new ConfirmationDialog("Paste tracks; insert or overwrite? (i/o) ",
															 &pasteCallback,
															 "oi", 1));
				return OK;
			case SDLK_i:
				pasteTracks(clip, true);
				return OK;
			case SDLK_o:
				pasteTracks(clip, false);
				return OK;
			default:
				break;
			}	
		}
		else if(key.mods & KMOD_ALT) {
			switch(key.key) {
			case SDLK_z:
				mainui.activateDialog(queryClip);
				return OK;
			case SDLK_b:
				pasteTracks(clip, true);
				return OK;
			default:
				break;
			}
		}

		if((key.mods & KMOD_CTRL) && (key.mods & KMOD_ALT)) {
			switch(key.raw)
			{
			case SDLK_1:
				trackSwap(0);
				break;
			case SDLK_2:
				trackSwap(1);
				break;
			case SDLK_3:
				trackSwap(2);
				break;
			default: break;
			}
		}
		else switch(key.raw)
			 {
			 case SDLK_INSERT:
				 saveState(false);
				 auto v = (cast(TrackVoice)activeVoice);
				 v.trackInsert(true);
				 return OK;
			 case SDLK_DELETE:	
				 saveState(false);
				 auto v = (cast(TrackVoice)activeVoice);
				 v.trackDelete(true);
				 if(v.pos.trkOffset >= v.tracks.trackLength-1) 
					 jump(Jump.toEnd,true);
				 return OK;
			 default: break;
			 }
		
		super.keypress(key);
	
		switch(activeVoice.keypress(key))
		{
		case WRAPL:
			stepVoice(-1);
			break;
		case WRAPR:
			stepVoice(1);
			break;
		default:
			break;
		}

		return OK;
	}

	override void toSeqEnd() {
		return;
	}

	override void toSeqStart() {
		return;
	}

	override void refresh() {
		foreach(v; voices) {
			(cast(TrackVoice)v).refreshTrack(posTable.pointerOffset);
			v.refresh();
		}
	}
	
	override void jump(int jumpto, bool center) { 
	  activeVoice.trackFlush(posTable.pointerOffset); 
	  super.jump(jumpto,center); 
	}

	override void activate() {
		super.activate();
	}	

	override void deactivate() {
		super.deactivate();
		activeVoice.deactivate();
	}

	/* custom voicestepper: voice resync needed because
	 * tracks may not be aligned */
	override void stepVoice(int i) {
		int nib = 3 ^ 3 - activeVoice.activeInput.nibble;
		super.stepVoice(i);
		super.step(-activeVoice.activeRow.seqOffset,0);
		activeVoice.activeInput.nibble = nib;
	}

	override void step(int st, int extra, int height) {
		activeVoice.trackFlush(posTable.pointerOffset);
		doStep(true, st);
	}

	protected void trackSwap(int withVoice) {
		saveState(true);
		Tracklist from = getTracklist(activeVoice);
		Tracklist to = getTracklist(voices[withVoice]);
		// TODO: calc new wrap points...
		/+
		int wrap1, wrap2, pos1, pos2;
		pos1 = activeVoice.pos.trkOffset;
		pos2 = voices[withVoice].pos.trkOffset;
		wrap1 = from.wrapOffset - pos1;
		wrap2 = to.wrapOffset - pos2;
		+/
		/+
		int temp = voices[withVoice].pos.trkOffset;
		voices[withVoice].pos.trkOffset = activeVoice.pos.trkOffset;
		activeVoice.pos.trkOffset = temp;
		+/
		for(int i = 0; i < from.length; i++) {
			if(i >= to.length) break;
			int temptrans, tempno;
			temptrans = to[i].trans;
			tempno = to[i].number;
			to[i].setValue(from[i].trans, from[i].number);
			from[i].setValue(temptrans, tempno);
		}
		refresh();
	}

	void clipCallback(int num) {
		const int trackLength = activeVoice.tracks.trackLength;
		int curTrkOffset = activeVoice.activeRow.trkOffset;
		Tracklist tl = getTracklist(activeVoice)[0..num];
		int length = tl.length;
		
		if(curTrkOffset + num >= trackLength)
			length = trackLength - curTrkOffset;
		assert(length >= 0);
		clip.length = length;
		for(int i = 0; i < length; i++) {
			clip[i].trans = tl[i].trans;
			clip[i].no = tl[i].number;
		}
	}

	void pasteCallback(int value) {
		pasteTracks(clip, value > 0);
	}
	
	private void pasteTracks(Clip[] clip, bool doInsert) {
		saveState(false);
		if(doInsert) {
			for(int i = 0; i < clip.length; i++) {
				auto v = cast(TrackVoice)activeVoice;
				v.trackInsert(true);
			}
		}
		Tracklist vtr = getTracklist(activeVoice)[0..clip.length];
		// FIX: ADD .dup operator to Tracklist
		for(int i = 0; i < clip.length; i++) {
			vtr[i].setValue(clip[i].trans,clip[i].no);
		}
		// reinitialize trackinput for voices
		refresh();
		// make sure cursor not past track end
		step(0,0,0);

		clip.length = 0;
	}

	protected void saveState(bool allVoices) {
		com.session.insertUndo(this, createState(allVoices));
	}

	private UndoValue createState(bool allVoices) {
		import std.typecons;
		UndoValue v;

		v.trackValue = (cast(InputTrack)input).trk.dup;
		v.track = (cast(InputTrack)input).trk;

		if(allVoices) {
			for(int i = 0; i < voices.length; i++) {
				auto tl = getTracklist(voices[i]);
				auto t = TracklistStore(tl.deepcopy, tl);
				v.trackLists ~= t;
			}
		}
		else {
			auto tl = getTracklist(activeVoice);
			auto t = TracklistStore(tl.deepcopy, tl);
			v.trackLists = [t];
		}
		v.posTable = posTable.dup();
		v.subtuneNum = song.subtune;
		v.allVoices = allVoices;
		return v;
	}

	override protected final void undo(UndoValue v) {
		if(v.subtuneNum != song.subtune)
			return;
		
		foreach(t; v.trackLists) {
			t.source.overwriteFrom(t.store);
		}

		v.track = v.trackValue;

		posTable.copyFrom(v.posTable);
		refresh();
		// make sure cursor not past track end
		step(0,0,0);
	}

	override protected UndoValue createRedoState(UndoValue value) {
		return createState(value.allVoices);
	}
}


class TrackTable : BaseTrackTable {
	this(Rectangle a, PosDataTable pi) {
		int x = 5 + com.fb.border + a.x;
		for(int v=0;v<3;v++) {
			Rectangle na = Rectangle(x, a.y, a.height, 13 + com.fb.border);
			x += 13 + com.fb.border;

			voices[v] = new TrackVoice(VoiceInitParams(song.tracks[v],
													   na, pi.pos[v], this));
		}
		super(a, pi);
	}

	override void refresh() {
		foreach(v; voices) {
			(cast(TrackVoice)v).refreshTrack(posTable.pointerOffset);
			v.refresh();
		}
	}

	override protected void doStep(bool wrapOk, int r) {
		foreach(v; voices) {
			bool wrap = wrapOk;
			v.scroll(r,wrap);
		}
	}

	override int keypress(Keyinfo key) {
		if(key.mods & KMOD_CTRL) {
			switch(key.raw)
			{
			default:
				break;
			}
		}
		switch(key.raw)
		{
		case SDLK_DOWN, SDLK_PAGEDOWN:
			activeVoice.trackFlush(posTable.pointerOffset);
			if(activeVoice.atEnd()) return OK;
			int r = activeVoice.activeRow.seq.rows;
			step(r,area.height - 1,area.height);
			centerTo(tableBot);
			refresh();
			return OK;
		case SDLK_UP, SDLK_PAGEUP:
			activeVoice.trackFlush(posTable.pointerOffset);
			int t = activeVoice.activeRow.trkOffset;
			if(t == 0) t = activeVoice.tracks.trackLength;
			RowData s = activeVoice.getRowData(t - 1, 0);
			step(-s.seq.rows, 0, area.height);
			centerTo(tableBot);
			refresh();
			return OK;
		default:
			return super.keypress(key);
		}
	}

	@property void displayTracklist(bool toggleOrDisable) {
		foreach(voice; voices) {
			TrackVoice tv = cast(TrackVoice)voice;
			if(!toggleOrDisable)
				tv.displayTracklist = false;
			else tv.displayTracklist ^= 1;
		}
	}
}
