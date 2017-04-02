/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module seq.seqtable;
import main;
import ui.ui;
import com.fb;
import com.util;
import seq.sequencer;
import com.session;
import ct.base;
import ui.input;
import derelict.sdl.sdl;
import std.string;

class SeqVoice : Voice, Undoable {
	InputSeq seqinput;

	this(VoiceInitParams v) {		
		super(v);
		activeRow = getRowData(0, 0);
		seqinput = new InputSeq();
		(cast(InputSeq)seqinput).setElement(activeRow.element);
		seqinput.setCoord(area.x + 4, 0);
		(cast(InputSeq)seqinput).setPointer(area.x + 4, 0);
		activeInput = seqinput;
	}

	override int keyrelease(Keyinfo key) {
		return seqinput.keyrelease(key);
	}
	
	override int keypress(Keyinfo key) {
		if(key.mods & KMOD_SHIFT) {
			switch(key.raw)
			{
			case SDLK_RETURN:
				saveState();
				int r = activeRow.seq.rows;
				int t = 4 * song.highlight;
				activeRow.seq.expand(activeRow.seqOffset,
								   (t - (r + t) % t));
				break;
			case SDLK_INSERT:
				saveState();
				activeRow.seq.expand(activeRow.seqOffset, 1);
				break;
			case SDLK_DELETE:
				saveState();
				activeRow.seq.shrink(activeRow.seqOffset, 1, true);
				break;
			default:
				return seqinput.keypress(key);
			}
		}
		else if(key.mods & KMOD_CTRL) {
			switch(key.raw)
			{
			case SDLK_INSERT:
				saveState();
				activeRow.seq.expand(0, 1, false);
				break;
			case SDLK_DELETE:
				saveState();
				if(activeRow.seqOffset < activeRow.seq.rows - 1)
					activeRow.seq.shrink(0, 1, false);
				break;	
			case SDLK_q:
				saveState();
				activeRow.seq.transpose(activeRow.seqOffset, 1);
				break;
			case SDLK_a:
				saveState();
				activeRow.seq.transpose(activeRow.seqOffset, -1);
				break;
			case SDLK_w:
				saveState();
				activeRow.seq.transpose(activeRow.seqOffset, 12);
				break;
			case SDLK_s:
				saveState();
				activeRow.seq.transpose(activeRow.seqOffset, -12);
				break;
				
			default:
				return seqinput.keypress(key);
			}
		}
		else switch(key.raw)
			 {
			 case SDLK_LEFT:
				 return seqinput.step(-1);
			 case SDLK_RIGHT:
				 return seqinput.step(1);
			 case SDLK_INSERT:
				 saveState();
				 activeRow.seq.insert(activeRow.seqOffset);
				 break;
			 case SDLK_DELETE:
				 saveState();
				 activeRow.seq.remove(activeRow.seqOffset);
				 break;
			 default:
				 return seqinput.keypress(key);				
			 }
		return OK;
	}
	
	override void refreshPointer(int y) {
		assert(seqinput !is null);
		assert(pos !is null);
		activeRow = getRowData(pos.trkOffset, pos.seqOffset + y);
		activeInput.setCoord(0, 1 + area.y + y + anchor);
		(cast(InputSeq)seqinput).setElement(activeRow.element);
	}

	override void update() {
		RowData wseq;
		int scry = area.y + area.height;
		int trkofs = pos.trkOffset, seqofs = pos.seqOffset - anchor;
		int lasttrk = tracks.trackLength;
		int hcount = pos.rowCounter - anchor + area.height - 1;
		int row = area.height;
		Sequence seq;

		seqofs += area.height;// - pos.delta;
		wseq = getRowData(trkofs, seqofs);
		trkofs = wseq.trkOffset2;
		seqofs = wseq.seqOffset;
		seq = new Sequence(wseq.seq.data.raw[0 .. $], seqofs);
		void printEmpty() {
			import std.array;
			
			screen.cprint(area.x - 1, scry, 1, 0, 
						  replicate(" ", 16));
		}
		
		void printTrack() {
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
		
		int rows = seq.rows;
		while(scry >= area.y + 1) {
			if(trkofs < 0) {
				printEmpty();
				scry--; row--;
			}
			else if(trkofs >= lasttrk+1) {
				printEmpty();
				if(trkofs == lasttrk+1) {
					wseq = getRowData(trkofs, 0);
					printTrack();
				}
				hcount--; scry--; trkofs--;
				if(trkofs >= 0) rows = 0;
				continue;
			}
			else {
				for(int i = rows - 1; i >= 0; 
					i--, scry--, hcount--, row--) {
					printEmpty();
					if(scry < area.y + 1) break;
					Element d = seq.data[i];
					screen.fprint(area.x + 4, scry, d.toString(wseq.element.transpose));
					if(i == 0) printTrack();
					else {
						if(.seq.sequencer.displaySequenceRowcounter == true) {
							int c = (hcount - song.highlightOffset) %
								song.highlight ? 11 : 12;
							screen.cprint(area.x, scry, c, 0, format(" %02X ", i));
						}
						else screen.cprint(area.x, scry, 0, 0, "    ");
					}
				}
			}
			trkofs--;
			if(trkofs >= 0) {
				wseq = getRowData(trkofs, 0);
				seq = wseq.seq;
				rows = seq.rows;
			}
		}

	}

protected:

	override final void undo(UndoValue entry) {
		auto data = entry.array.target;
		auto target = entry.array.source;
		target[] = data;
		assert(parent !is null);
		entry.seq.refresh();
		parent.step(0);
	}

	void saveState() {
		UndoValue v;
		import std.typecons;
		v.array = UndoValue.Array(activeRow.seq.data.raw.dup,
								  activeRow.seq.data.raw);
		v.seq = activeRow.seq;
		com.session.insertUndo(this, v);
	}

	override final UndoValue createRedoState(UndoValue value) {
		value.array.target = value.array.source.dup;
		return value;
	}
}

class SequenceTable : VoiceTable {
	this(Rectangle a, PosDataTable pi) { 
		int x = 5 + com.fb.border + a.x;
		for(int v=0;v<3;v++) {
			Rectangle na = Rectangle(x, a.y, a.height, 13 + com.fb.border);
			x += 13 + com.fb.border;
			voices[v] = new SeqVoice(VoiceInitParams(song.tracks[v],
													 na, pi[v], this));
		}
		super(a, pi); 
	}

	override void activate() { 
		super.activate();
		// works as scroll(1) would but does not store variables 
		int steps = 0;
		foreach(Voice v; voices) {
			with(v.pos) {
				RowData s = v.getRowData(trkOffset);
				if(trkOffset >= v.tracks.trackLength) {
					trkOffset = 0;
					rowCounter = -pointerOffset;
				}
			}
			
		}

	}

	override void update() {
		super.update();
		if(!audio.player.isPlaying || audio.player.keyjamEnabled) return;
		// trackbar
		for(int i = 0 ; i < 3; i++) {
			PosData fp = fplayPos[i];
			PosData vp = posTable[i];
			int tp = fp.rowCounter - vp.rowCounter + anchor;
			if(tp >= 0 && tp < area.height) {
				for(int x = voices[i].area.x;
					x < voices[i].area.x + voices[i].area.width; x++) {
					screen.setColor(x, 1 + area.y + tp, 1,0);
				}
			}
		}
		
	}

	override void stepVoice(int i) {
		int n = activeVoiceNum + i;
		int c = (n - activeVoiceNum) > 0 ? 0 : 1;
		n = umod(n, 0, 2);
		if(!voices[n].atEnd())
			super.stepVoice(i);

		SeqVoice v = cast(SeqVoice)voices[n];
		(cast(InputSeq)v.seqinput).columnReset(-c);
	}		

	// for positioning the cursor using mouse. x is not used
	override void clickedAt(int x, int y, int button) {
		y -= 1;
		step(y-posTable.normalPointerOffset);
	}

	override int keypress(Keyinfo key) {
		// globals
		super.keypress(key);
		if(!key.mods) {
			switch(key.raw)
			{
			case SDLK_HOME:
				SeqVoice v = cast(SeqVoice)activeVoice;
				InputSeq i = cast(InputSeq)v.seqinput;
				if(i.activeColumn > 0) {
					(cast(InputSeq)v.seqinput).columnReset(0);
					break;
				}
				int ofs = activeVoice.activeRow.seqOffset;
				int cy = posTable.normalPointerOffset;
				int m;
				if(cy == 0) m = 1;
				else if(ofs == 0) break;
				else if(ofs > 0 && ofs > cy)  {
					m = 0;
				}
				else m = 1;

				if(m) {
					toSeqStart();
				}
				else
					toScreenTop();

				break;
			case SDLK_END:
				SeqVoice v = cast(SeqVoice)activeVoice;
				InputSeq i = cast(InputSeq)v.seqinput;
				if(i.activeColumn < i.columns) {
					(cast(InputSeq)v.seqinput).columnReset(i.columns,0);
					break;
				}
				// something might be wrong here...
				int scrend = tableTop - posTable.pointerOffset - 1;
				assert(scrend >= 0);

				int rows = activeVoice.activeRow.seq.rows;
				int seqend = rows -
					activeVoice.activeRow.seqOffset - 1;

				int m;
				if(scrend == 0) toSeqEnd();
				else if(seqend == 0) toScreenBot();
				else if(seqend >= scrend) {
					toScreenBot();
				}
				else {
					toSeqEnd();
				}
				break;
			case SDLK_KP0:
				audio.player.playRow(voices);
				step(1);
				break;
			default:
				break;
			}
			
		}
		else if(key.mods & KMOD_CTRL) {
			switch(key.raw) {
			case SDLK_p:
				RowData r = activeVoice.activeRow;
				// bad coding because all the rowcountergetters are flawed one way or another
				int rowcount = activeVoice.getRowcounter(r.trkOffset) + r.seqOffset;
				song.splitSequence(r.track.number, r.seqOffset);
				jump(Jump.toBeginning,false);
				step(rowcount);
				centerTo(0);
				break;
			default:
				break;
			}
		}
		int r;
		if((r = activeVoice.keypress(key)) != OK) {
			switch(r) {
			case WRAPL:
				stepVoice(-1);
				break;
			case WRAPR:
				stepVoice(1);
				break;
			default:
				step(stepValue);
				break;
			}
		}
		return OK;
	}
}
