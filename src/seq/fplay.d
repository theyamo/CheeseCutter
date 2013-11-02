module seq.fplay;
import ui.ui;
import seq.sequencer;
import seq.seqtable;
import ui.input;
import ct.base;
import derelict.sdl.sdl;

private int mode;

protected class FPlayVoice : SeqVoice {
	this(VoiceInit v) { 
		super(v); 
		assert(pos !is null);
	}

	protected void scroll(int steps) {
		int lasttrk = tracks.getListLength();
		int seqofs = pos.seqOffset + steps;
		int trkofs2 = pos.trkOffset;
		Sequence seq;
		Track trk;
		int getRows() {
			Sequence seq = song.seqs[tracks[trkofs2].no];
			int r = seq.rows;
			if(tracks[trkofs2].trans >= 0xf0)
				r = 1;
			return r;
		}
		// FIX: will not work when step > 1 && track wraps
		pos.rowCounter = pos.rowCounter + steps;

		while(seqofs >= getRows()) {
			seqofs -= getRows();
			trkofs2++;
			trk = tracks[trkofs2];
			if(trk.trans >= 0xf0) {
				if(song.ver >= 6)
					jump(Jump.ToWrapMark);
				else 
					jump(mode);
				trkofs2 = pos.trkOffset;
				trk = tracks[trkofs2];
				assert(trk.trans < 0xf0);
			}
			seq = song.seqs[trk.no];
			assert(seqofs >= 0);

		}
		pos.seqOffset = seqofs;
		pos.trkOffset = trkofs2;
	}
}

protected class FPlayVoiceTable : SequenceTable {
	this(Rectangle a) {
		super(a, fpPos);
		int x = 5 + com.fb.border + a.x;
		for(int v=0;v<3;v++) {
			Rectangle na = Rectangle(x, a.y, a.height, 13 + com.fb.border);
			x += 13 + com.fb.border;
			voices[v] = new FPlayVoice(VoiceInit(song.tracks[v],
												 na, fpPos[v]));
		}
	}

	void step(int st) {
		foreach(v; cast(FPlayVoice[])voices) {
			v.scroll(st);
		}
	}
}

class Fplay : Window {
	private {
		FPlayVoiceTable ftable;
	}
	this(Rectangle a) { 
		assert(fpPos !is null);
		ftable = new FPlayVoiceTable(a);
		super(a); 
	}

	void timerEvent() {
		if(!audio.player.isPlaying) return;
		int c = audio.timer.readRowTick();
		if(c > 0) ftable.step(c);
	}

	void update() {
		ftable.update();
	}

	int keypress(Keyinfo key) {
		switch(key.raw)
		{
		case SDLK_HOME:
			int m1, m2, m3;
			if(!key.mods & KMOD_CTRL) break;
			m1 = fpPos.pos[0].mark;
			m2 = fpPos.pos[1].mark;
			m3 = fpPos.pos[2].mark;
			stop();
			audio.player.start([m1, m2, m3], [0, 0, 0]);
			ftable.jump(Jump.ToMark,true);
			break;
		/+ jump forward/backward disabled for now ...
		case SDLK_PLUS:
			int m1, m2, m3;
			m1 = ++fpPos.pos[0].trkOffset;
			m2 = ++fpPos.pos[1].trkOffset;
			m3 = ++fpPos.pos[2].trkOffset;
			stop();
			audio.player.start([m1, m2, m3], [0, 0, 0]);
			int[] m = [m1 , m2, m3];
			ftable.jump(m1,true);
			update();
			break;
		case SDLK_MINUS:
			int m1, m2, m3;
			m1 = --fpPos.pos[0].trkOffset;
			m2 = --fpPos.pos[1].trkOffset;
			m3 = --fpPos.pos[2].trkOffset;
			stop();
			audio.player.start([m1, m2, m3], [0, 0, 0]);
			int[] m = [m1 , m2, m3];
			ftable.jump(m1,true);
			update();
			break;			
		+/
		case SDLK_SPACE:
			audio.player.fastForward(25);
			break;
		default:
			break;
		}
		return OK;
	}

	void start(int p) {
		fpPos.dup(tPos);
		ftable.jump(p,true);
		mode = p;
	}

	void startFromCursor() {
		fpPos.dup(tPos);
		ftable.centerTo(0);
		mode = Jump.ToBeginning;
	}

	void stop() {
	}
}

