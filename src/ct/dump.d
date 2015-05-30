/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

/** date to source dumper. very ugly quick and dirty hack
 */

module ct.dump;

import ct.base;
import com.util;
import std.string;
import std.array;

private const string byteOp = "!byte", wordOp = "!word";

string dumpData(Song sng) {
	auto app = appender!string();

	int getHighestUsed(ubyte[] array) {
		for(int i = cast(int)array.length - 1; i >= 0; i--) {
			if(array[i] > 0)
				return cast(int)i;
		}
		return 0;
	}

	void append(string s) {
		app.put(s);
	}
	
	void hexdump(ubyte[] buf, int rowlen) {
		int c;
		append("\t\t" ~ byteOp ~ " ");
		foreach(i, b; buf) {
			append(format("$%02x", b));
			c++;
			if(c >= rowlen) {
				c = 0;
				if(i < buf.length - 1)
					append("\n\t\t" ~ byteOp ~ " ");
			}
			else if(i < buf.length - 1) append(",");
		}
		append("\n");
	}
	int tablen;
	ushort[][] trackpointers = new ushort[][sng.subtunes.numOf];
	sng.subtunes.activate(0);
	auto packedTracks = sng.subtunes.compact();	
	
	append( "arp1 = *\n");
	tablen = getHighestUsed(sng.wave1Table) + 1;
	hexdump(sng.wave1Table[0 .. tablen], 16);
	append( "arp2 = *\n");
	hexdump(sng.wave2Table[0 .. tablen], 16);
	append( "filttab = *\n");
	hexdump(sng.filterTable[0 .. getHighestUsed(sng.filterTable) + 4], 4);
	append( "pulstab = *\n");
	hexdump(sng.pulseTable[0 .. getHighestUsed(sng.pulseTable) + 4], 4);
	append( "inst = *\n");
	ubyte[512] instab = 0;

	int maxInsno;
	sng.seqIterator((Sequence s, Element e) { 
			int insval = e.instr.value;
			if(insval > 0x2f) return;
			if(insval > maxInsno) maxInsno = insval; });
	for(int i = 0; i < 8; i++) {
		append( format("\ninst%d = *\n",i));
		hexdump(sng.instrumentTable[i * 48 .. i * 48 + (maxInsno+1)], 16);
	}

	// cmd ----------------------------------------
	
	tablen = 1;
	append( "\nseqlo = *\n\t\t!8 ");
	for(int i = 0; i < sng.numOfSeqs(); i++) {
		append(format("<s%02x", i));
		if(i < sng.numOfSeqs() - 1)
			append(",");
	}
	append( "\nseqhi = *\n\t\t!8 ");
	for(int i = 0; i < sng.numOfSeqs(); i++) {
		append(format(">s%02x", i));
		if(i < sng.numOfSeqs() - 1)
			append(",");
	}
	
	sng.seqIterator((Sequence s, Element e) { 
			int val = e.cmd.value;
			if(val == 0) return;
			if(val < 0x40 && val > tablen) {
				tablen = val;
			}
		});

	++tablen;
	
	append( "\ncmd1 = *\n");
	hexdump(sng.superTable[0..tablen], 16);
	append( "cmd2 = *\n");
	hexdump(sng.superTable[64..64+tablen], 16);
	append( "cmd3 = *\n");
	hexdump(sng.superTable[128..128+tablen], 16);

	// songsets ------------------------------------

	append( "songsets = *\n");
	for(int i = 0; i < sng.subtunes.numOf; i++) {
		append(wordOp ~ "\t");
		for(int voice = 0; voice < 3; voice++) {
			if(voice > 0)
				append(",");
			append(" " ~ format("track%d_%d", i, voice));
		}
		append( format("\n\t\t" ~ byteOp ~ " %d, 7\n", sng.songspeeds[i]));
	}
	
	// tracks -------------------------------------
	
	foreach(i, ref subtune; packedTracks) {
		foreach(j, voice; subtune) {
			append(format("track%d_%d = *\n", i, j));
			hexdump(voice, 16);
		}
	}

	for(int i = 0; i < sng.numOfSeqs(); i++) {
		append( format("s%02x = *\n", i));
		Sequence s = sng.seqs[i];
		hexdump(s.compact(), 16);
	}

	// chords -------------------------------------
	
	tablen = getHighestUsed(sng.chordTable) + 1;
	append("\nchord");
	if(tablen < 1) tablen = 1;
	hexdump(sng.chordTable[0..tablen], 16);
	append("\nchordindex");
	int highestChord = 0;
	sng.seqIterator((Sequence s, Element e) { 				
			if(e.cmd.value >= 0x80 && e.cmd.value <= 0x9f &&
			   (e.cmd.value & 0x1f) > highestChord)
				highestChord = e.cmd.value & 0x1f;
		});
	hexdump(sng.chordIndexTable[0..highestChord+1], 16);
	return app.data;
}
