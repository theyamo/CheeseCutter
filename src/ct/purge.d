module ct.purge;
import ct.base;
import ct.base : Sequence;
import std.stdio;
import std.string;

alias writefln w;

class Purger {
	Song song;
	private {
		bool[0x80] seqUsed;
		bool[0x30] instrUsed;
		bool[0x40] super_used, pulse_used, filter_used;
	}
	bool verbose;

	this(Song sng) {
		song = sng;
	}

	this(Song sng, bool v) {
		verbose = v;
		this(sng);
	}

	void purgeAll() {
		// get unused seqs
		trackIterator((Track t) {
				seqUsed[t.no] = true;
			});
		purgeSeqs();
		purgeInstruments();
		purgeWavetable();
		purgeChordtable();
		purgeCmdtable();
		purgePulseFilter();
	}

	void purgeSeqs() {
		int counter;
		
		for(int i = 0x7f; i >= 1; i--) {
			if(!seqUsed[i]) continue;
			for(int j = 1; j < i; j++) {
				Sequence s1 = song.seqs[i];
				Sequence s2 = song.seqs[j];
				
				if (s1 == s2) {
					seqUsed[j] = false;
					replaceTrackvalue(j, i);
					counter++;
				}
			}
		}
		explain(format("%d identical seqs found.",counter));

		counter = 0;
		for(int i = 0x7f; i >= 1; i--) {
			if(!seqUsed[i]) {
				song.seqs[i].clear();
				continue;
			}
			
			for(int j = 1; j < i; j++) {
				if(!seqUsed[j]) {
					song.seqs[j].copyFrom(song.seqs[i]);
					song.seqs[i].clear();
					seqUsed[j] = true;
					seqUsed[i] = false;
					replaceTrackvalue(i, j);
					counter++;
					break;
				}
			}
		}
		explain(format("%d unused sequences removed.",counter));
	}

	void purgeInstruments() {
		foreach(i, n; seqUsed) {
			if(!n) continue;
			Sequence s = song.seqs[i];
			for(int j = 0; j < s.rows; j++) {
				Element e = s.data[j];
				if(!e.instr.hasValue()) continue;
				instrUsed[e.instr.value] = true;
			}
		}

		int counter;

		// clear unused
		for(int i = 0; i < 48; i++) {
			if(instrUsed[i]) {
				counter++; continue;
			}
			//instrtab[i*8 .. i*8 + 8] = 0;
			for(int j = 0; j < 8; j++) {
				song.instrumentTable[i + j * 48] = 0;
			}
			song.insLabels[i][] = ' ';
		}

		// compact
		for(int i = 0; i < 48; i++) {
			if(instrUsed[i]) continue;
			for(int j = i + 1; j < 48; j++) {
				if(instrUsed[j]) {
					for(int cidx = 0; cidx < 8; cidx++) {
						int o = cidx * 48;
						song.instrumentTable[i + o] =
							song.instrumentTable[j + o];
					}
					song.insLabels[i][] = song.insLabels[j][];
					replaceInsvalue(j, i);
					
					instrUsed[i] = true;
					instrUsed[j] = false;

					for(int k = 0; k < 8; k++) {
						song.instrumentTable[j + k * 48] = 0;
					}
					song.insLabels[j][] = ' ';
					break;
				}
			}
		}
		explain(format("%d instruments used.", counter));
	}

	void purgeWavetable() {
		ubyte[] wavetab = song.waveTable;
		struct Chunk {
			int offset;
			ubyte[] wave1, wave2;
			bool used;
			string toString() { return format("%x", offset); }
		}
		Chunk[] chunks;
		int counter;
		chunks.length = 256;
		for(int i = 0, b; i < 256; i++) {
			if(wavetab[i] == 0x7f || wavetab[i] == 0x7e) {
				chunks[counter] = Chunk(b, wavetab[b .. i + 1], wavetab[b + 256 .. i + 256 + 1]);
				b = i + 1;
				counter++;
			}
		}
		chunks.length = counter;

		int whichCell(int ptr) {
			foreach(idx, chunk; chunks) {
				int b = chunk.offset,
					e = cast(int)(chunk.offset + chunk.wave1.length);
				if(ptr >= b && ptr < e) {
					return cast(int)idx;
				}
			}
			return -1;
		}

		void markCells(int cell) {
			assert(cell >= 0 && cell < chunks.length);
			for(;;) {
				if(chunks[cell].used) break;
				chunks[cell].used = true;
				Chunk c = chunks[cell];
				cell = whichCell(c.wave2[$-1]);
				if(cell < 0) break;
			}
		}
	
		for(int i = 0; i < 48; i++) {
			if(!instrUsed[i]) continue;
			int ptr = song.getWavetablePointer(i);
			int cell = whichCell(ptr);
			if(cell < 0) continue;
			markCells(cell);
		}

		int numcleared;
		// compact
		for(int i = cast(int)(chunks.length - 1); i >= 0; i--) {
			Chunk chunk = chunks[i];
			if(chunk.used) continue;
			song.wavetableRemove(chunk.offset, cast(int)chunk.wave1.length);
			numcleared++;
		}
		explain(format("%d wave programs removed.", numcleared));
	}

	void purgePulseFilter() {
		int i;
		filter_used[0] = true;
		pulse_used[0] = true;
		void seekNMark(ref ubyte[] table, bool* usedflags, int pointer) {
			int pp = pointer;
			for(;;) {
				if(usedflags[pp]) break;
				usedflags[pp] = true;
				int newptr = table[pp*4 + 3];
				if(newptr == 0x7f) break;
				if(newptr == 0) pp++;
				else pp = newptr;
			}
		}

		for(i = 0; i < 48; i++) {
			if(!instrUsed[i]) continue;
			try {
				seekNMark(song.pulseTable, &pulse_used[0], song.getPulsetablePointer(i));
				seekNMark(song.filterTable, &filter_used[0], song.getFiltertablePointer(i));
			}
			catch(Exception e) {
				explain(format("Could not purge pulse / filter table: ", e.toString));
				return;
			}
		}

		seqIterator((Sequence s, Element e) {
				if(e.cmd.value >= 0x40 && e.cmd.value < 0x60)
					seekNMark(song.pulseTable, &pulse_used[0], e.cmd.value - 0x40);
				if(e.cmd.value >= 0x60 && e.cmd.value < 0x80)
					seekNMark(song.filterTable, &filter_used[0], e.cmd.value - 0x60);
				
			});

		for(i = 0; i < 64; i++) {
			if(!pulse_used[i]) 
				song.pulseTable[i * 4 .. i * 4 + 4] = 0;
			if(!filter_used[i])
				song.filterTable[i * 4 .. i * 4 + 4] = 0;
		}
	}

	void purgeChordtable() {
		bool chordsUsed[0x20];
		ubyte[] newtable;
		newtable.length = 256;
		seqIterator((Sequence s, Element e) { 				
				if(e.cmd.value >= 0x80 && e.cmd.value <= 0x9f)
					chordsUsed[e.cmd.value & 0x1f] = true;
			});

		struct Chunk {
			ubyte[] data;
			int oldOffset;
		}

		int getidx2(int idx) {
			for(int i = idx; i < 128; i++) {
				if(song.chordTable[i] >= 0x80) return i;
			}
			assert(0);
		}
		int np;
		Chunk[] chunks;
		chunks ~= Chunk(song.chordTable[0 .. song.chordIndexTable[1]].dup, 0);
		int tablestart = 1;
		// TODO: find out if swingtepo is used and purge first chunk too if needed
		for(int i = tablestart; i < 0x20; i++) {
			if(chordsUsed[i]) {
				int idx = song.chordIndexTable[i];
				int idx2 = getidx2(idx)+1; // FIX: check... might cause problems
				//int idx2 = song.chordIndexTable[i+1];
				assert(idx != 0);
				if(idx2 == 0) break;
				ubyte[] chord = song.chordTable[idx .. idx2].dup;
				chunks ~= Chunk(chord, idx);
			}
			else {
				for(int j = i + 1; j < 0x20; j++) {
					if(chordsUsed[j]) {
						int idx = song.chordIndexTable[j];
						int idx2 = getidx2(idx)+1;
						
						replaceCmdColumnvalue(0x80 + j, 0x80 + i);
						ubyte[] chord = song.chordTable[idx .. idx2].dup;

						chunks ~= Chunk(chord, idx);

						chordsUsed[i] = true;
						chordsUsed[j] = false;
						break;
					}
				}
			}
		}

		int counter;
		int idx;

		foreach(chunk; chunks) {
			if(chunk.data.length == 0) continue;
			int oldwrap = (chunk.data[$-1] - 0x80) - chunk.oldOffset;
			assert(chunk.data[$-1] >= 0x80);
			chunk.data[$-1] = cast(ubyte)(idx + oldwrap + 0x80);
			idx += chunk.data.length;
			counter++;
		}
		
		song.chordTable[] = 0;
		foreach(chunk; chunks) {
			song.chordTable[np .. np + chunk.data.length] = chunk.data;
			np += chunk.data.length;
		}
		song.generateChordIndex();
		explain(format("%d chords used.",counter));
	}

	void purgeCmdtable() {
		seqIterator((Sequence s, Element e) {
				if(e.cmd.value == 0) return;
				if(e.cmd.value < 0x40)
					super_used[e.cmd.value] = true;
			});
		
		int counter;

		for(int i = 1; i < 64; i++) {
			if(super_used[i]) {
				counter++; continue;
			}
			song.superTable[i] = 0;
			song.superTable[i+64] = 0;
			song.superTable[i+128] = 0;

			for(int j = i + 1; j < 64; j++) {
				if(super_used[j]) {
					song.superTable[i] = song.superTable[j];
					song.superTable[i+64] = song.superTable[j+64];
					song.superTable[i+128] = song.superTable[j+128];
					replaceCmdColumnvalue(j, i);
					super_used[i] = true;
					super_used[j] = false;
					song.superTable[j] = 0;
					song.superTable[j+64] = 0;
					song.superTable[j+128] = 0;
					break;
				}
			}
		}
	}
	
private:
	void seqIterator(void delegate(Sequence s, Element e) dg) {
		foreach(i, n; seqUsed) {
			if(!n) continue;
			Sequence s = song.seqs[i];
			for(int j = 0; j < s.rows; j++) {
				Element e = s.data[j];
				dg(s, e);
			}
		}
	}

	void trackIterator(void delegate(Track t) dg) {
		for(int sidx = 0; sidx < 32; sidx++) {
			Tracklist[] subtune = song.subtunes[sidx];
			foreach(voice; subtune) {
				foreach(track; voice) {
					dg(track);
				}
			}
		}
	}

	void replaceInsvalue(int seek, int repl) {
		int skipped;
		seqIterator((Sequence s, Element e) {
				if(!e.instr.hasValue()) return;
				if(e.instr.value() == seek)
					e.instr = cast(ubyte)repl;
			});
	}

	void replaceCmdColumnvalue(int seek, int repl) {
		int skipped;

		seqIterator((Sequence s, Element e) {
				if(e.cmd.value == 0) return;
				if(e.cmd.value() == seek)
					e.cmd = cast(ubyte)repl;
			});
	}

	void replaceTrackvalue(int find, int rep) {
		trackIterator((Track t) {
				if(t.no == find)
					t.setNo(cast(ubyte)rep);
			});
	}

	void explain(string s) {
		if(verbose) writefln(s);
	}
}
