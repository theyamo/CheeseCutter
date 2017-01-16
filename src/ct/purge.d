/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

/*
  TODO: make all purge funcs public so user can optimize selected tables.
  requires writing proper initialization for each func so they can be run
  independently.
 */

module ct.purge;
import ct.base;
import com.util;
import std.string;
import std.stdio;

final class Purge {
	Song song;
	private {
		// song.seqIterator does not care if seq is in use or not
		// therefore purgeSeqs must be done always 1st on purgeAll - unused seqs get cleared
		bool[0x80] seqUsed;
		bool[0x30] instrUsed;
		bool[0x40] super_used, pulse_used, filter_used;
		bool verbose, initialized;
	}

	this(Song song) {
		this.song = song;
	}

	this(Song song, bool v) {
		verbose = v;
		this(song);
	}

	void purgeAll() {
		initialize(true);
		purgeSeqs();
		purgeInstruments();
		purgeWavetable();
		purgeChordtable();
		purgeCmdtable();
		purgePulseFilter();
		initialized = false;
	}
	
	void deleteInstrument(int insno) {
		initialize(false);
		int waveptr = song.wavetablePointer(insno);
		int pulseptr = song.pulsetablePointer(insno);
		int filtptr = song.filtertablePointer(insno);

		// ugly hack to not clear defined but unused instruments
		for(int i = 47; i >= 0; i--) {
			if(instrUsed[i] == false)
				instrUsed[i] = !instrIsEmpty(i);
		}
		instrUsed[insno] = false;

		purgeWavetable();
		purgePulseFilter();

		for(int i = 0; i < 8; i++) {
			song.instrumentTable[i * 48 + insno] = 0;
		}
		song.insLabels[insno][] = ' ';
		initialized = false;
	}

private:
	bool instrIsEmpty(int insno) {
		for(int i = 0; i < 8; i++) {
			if(song.instrumentTable[i * 48 + insno] != 0)
				return false;
		}
		return true;
	}
	
	// marking unused seqs optional in case you only want to optimize some tables
	void initialize(bool markUnusedSeqs) {
		if(initialized) return;
		if(markUnusedSeqs) {
			seqUsed[] = false;
			song.trackIterator((Track t) {
					seqUsed[t.number] = true;
				});
		}
		else seqUsed[] = true;

		instrUsed[] = false;
		// find out which instruments are in use
		foreach(i, n; seqUsed) {
			if(!n) continue;
			Sequence s = song.seqs[i];
			for(int j = 0; j < s.rows; j++) {
				Element e = s.data[j];
				if(!e.instr.hasValue()) continue;
				instrUsed[e.instr.value] = true;
			}
		}
	
		initialized = true;
	}
	

	private void purgeSeqs() {
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

	private void purgeInstruments() {
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

	private void purgeWavetable() {
		Song.Chunk[] chunks = song.tWave.getChunks();

		for(int i = 0; i < 48; i++) {
			if(!instrUsed[i]) continue;
			int ptr = song.wavetablePointer(i);
			int cell = song.tWave.whichCell(chunks, ptr);
			if(cell < 0) continue;
			song.tWave.markCells(chunks, cell);
		}

		int numcleared;
		// compact
		for(int i = cast(int)(chunks.length - 1); i >= 0; i--) {
			Song.Chunk chunk = chunks[i];
			if(chunk.used) continue;
			song.tWave.deleteRow(song, chunk.offset, cast(int)chunk.wave1.length);
			numcleared++;
		}
		explain(format("%d wave programs removed.", numcleared));
	}

	private void purgePulseFilter() {
		int i;
		pulse_used[] = false;
		filter_used[] = false;
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
				seekNMark(song.pulseTable, &pulse_used[0], song.pulsetablePointer(i));
				seekNMark(song.filterTable, &filter_used[0], song.filtertablePointer(i));
			}
			catch(Exception e) {
				explain(format("Could not purge pulse / filter table: %s", e.toString()));
				return;
			}
		}

		song.seqIterator((Sequence s, Element e) {
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

		// compact filter & pulse table. this is EXTREMELY slow.
		for(i = 0; i < 0x3e; i++) {
			int seek = i + 1;
			while(!filter_used[i] && seek < 64) {
				{
					filterDeleteRow(song, i);
					filter_used[i .. $-1] = filter_used[i+1 .. $].dup;
				}
				seek++;
			}
		}

		for(i = 0; i < 0x3e; i++) {
			int seek = i + 1;
			while(!pulse_used[i] && seek < 64) {
				{
					pulseDeleteRow(song, i);
					pulse_used[i .. $-1] = pulse_used[i+1 .. $].dup;
				}
				seek++;
			}
		}
	}
	
	private void purgeChordtable() {
		bool[0x20] chordsUsed;
		song.seqIterator((Sequence s, Element e) {
				if(e.cmd.value >= 0x80 && e.cmd.value <= 0x9f) {
					chordsUsed[e.cmd.value & 0x1f] = true;
				}
			});

		struct Chunk {
			ubyte[] data;
			int oldOffset;
		}

		int getidx2(int cmdidx, int idx) {
			for(int i = idx; i < 128; i++) {
				if(song.chordTable[i] >= 0x80) return i;
			}
			throw new PurgeException(format("Could not find valid chord for value %x", cmdidx));
		}

		song.generateChordIndex();
		Chunk[] chunks;
		chunks ~= Chunk(song.chordTable[0 .. song.chordIndexTable[1]].dup, 0);
		int tablestart = 1;
		// TODO: find out if swingtepo is used and purge first chunk too if needed
		for(int i = tablestart; i < 0x20; i++) {
			if(chordsUsed[i]) {
				int idx = song.chordIndexTable[i];
				int idx2 = getidx2(i,idx)+1; // FIX: check... might cause problems
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
						int idx2 = getidx2(j, idx)+1;
						
						replaceCmdColumnvalue(song, 0x80 + j, 0x80 + i);
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
		int np;

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

	private void purgeCmdtable() {
		song.seqIterator((Sequence s, Element e) {
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
					replaceCmdColumnvalue(song, j, i);
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

	void replaceInsvalue(int seek, int repl) {
		int skipped;
		song.seqIterator((Sequence s, Element e) {
				if(!e.instr.hasValue()) return;
				if(e.instr.value() == seek)
					e.instr = cast(ubyte)repl;
			});
	}

	void replaceTrackvalue(int find, int rep) {
		song.trackIterator((Track t) {
				if(t.number == find)
					t.number = cast(ubyte)rep;
			});
	}

	void explain(string s) {
		if(verbose) writefln(s);
	}
}

// TODO: move to tFilter
void filterDeleteRow(Song song, int row) {
	genericDeleteRow(song, song.filterTable, row);

	song.seqIterator((Sequence s, Element e) {
			if(row > 0x1f) return;
			if(e.cmd.value == 0) return;
			if(e.cmd.value() >= (0x60 + (row & 0x1f) + 1) && e.cmd.value() < 0x80)
				e.cmd = cast(ubyte)(e.cmd.value - 1);
		});
			
	for(int j = 0; j < 48; j++) {
		int fptr = song.instrumentTable[4 * 48 + j];
		if(fptr >= row && fptr < 0x40 && fptr > 0)
			song.instrumentTable[4 * 48 + j]--;
	}
}

// TODO: move to tPulse
void pulseDeleteRow(Song song, int row) {
	genericDeleteRow(song, song.pulseTable, row);

	song.seqIterator((Sequence s, Element e) {
			if(row > 0x1f) return;
			if(e.cmd.value == 0) return;
			if(e.cmd.value() >= (0x40 + (row & 0x1f) + 1) && e.cmd.value() < 0x60)
				e.cmd = cast(ubyte)(e.cmd.value - 1);
		});

	for(int j = 0; j < 48; j++) {
		int pptr = song.instrumentTable[5 * 48 + j];
		if(pptr >= row && pptr < 0x40 && pptr > 0)
			song.instrumentTable[5 * 48 + j]--;
	}
}

// TODO: move to tFilter
void filterInsertRow(Song song, int row) {
	genericInsertRow(song, song.filterTable, row);

	song.seqIterator((Sequence s, Element e) {
			if(row > 0x1f) return;
			if(e.cmd.value == 0) return;
			if(e.cmd.value() >= (0x60 + (row & 0x1f)) && e.cmd.value() < 0x80)
				e.cmd = cast(ubyte)(e.cmd.value + 1);
		});

	for(int j = 0; j < 48; j++) {
		int fptr = song.instrumentTable[4 * 48 + j];
		if(fptr >= row && fptr < 0x40)
			song.instrumentTable[4 * 48 + j]++;
	}
	
}

// TODO: move to tPulse
void pulseInsertRow(Song song, int row) {
	genericInsertRow(song, song.pulseTable, row);

	song.seqIterator((Sequence s, Element e) {
			if(row > 0x1f) return;
			if(e.cmd.value == 0) return;
			if(e.cmd.value() >= (0x40 + (row & 0x1f)) && e.cmd.value() < 0x60)
				e.cmd = cast(ubyte)(e.cmd.value + 1);
		});

	for(int j = 0; j < 48; j++) {
		int pptr = song.instrumentTable[5 * 48 + j];
		if(pptr >= row && pptr < 0x40 && pptr > 0)
			song.instrumentTable[5 * 48 + j]++;
	}
}

private void replaceCmdColumnvalue(Song song, int seek, int repl) {
	int skipped;

	song.seqIterator((Sequence s, Element e) {
			if(e.cmd.value == 0) return;
			if(e.cmd.value() == seek)
				e.cmd = cast(ubyte)repl;
		});
}

// TODO: move to Table
private void genericDeleteRow(Song song, ubyte[] table, int row) {
	assert(row < 64 && row >= 0);
		
	int row4 = row * 4;
	table[row4 .. $ - 4] =
		table[row4 + 4 .. $].dup;

	for(int j = 0; j < 64; j++) {
		int fptr = table[j * 4 + 3];
		if(fptr > 0 && fptr < 0x40) {
			if(fptr >= row) table[j * 4 + 3]--;
		}
	}
}

// TODO: move to Table
private void genericInsertRow(Song song, ubyte[] table, int row) {
	assert(row < 64 && row >= 0);
		
	int row4 = row * 4;
	table[row4 + 4 .. $] =
		table[row4 .. $ - 4].dup;

	table[row4 .. row4+4] = 0;

	for(int j = 0; j < 64; j++) {
		int fptr = table[j * 4 + 3];
		if(fptr > 0 && fptr < 0x40) {
			if(fptr >= row) table[j * 4 + 3]++;
		}
	}
}

class PurgeException : Exception {
	this(string msg) {
		super(msg);
	}

	override string toString() {
		return "Purge error: " ~ msg;
	}
}
