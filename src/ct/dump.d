/** date to source dumper. very ugly quick and dirty hack
 */

module ct.dump;

import ct.base;
import std.file;
import std.string;


// confirming acme standard
private const string byteOp = "!byte", wordOp = "!word";

/** TODO:
	- subtunes!
	- pack insturment table
	- inform user about player version used
*/

string dumpData(Song sng, string title) {
	string output;

	int getHighestUsed(ubyte[] array) {
		for(int i = cast(int)(array.length - 1); i >= 0; i--) {
			if(array[i] > 0)
				return i;
		}
		return -1;
	}

	void append(string s) {
		output ~= s;
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
	append(format("; data dump for %s \n", title));
	append( "songsets\t" ~ wordOp ~ " track1,track2,track3\n");
	append( format("\t\t" ~ byteOp ~ " %d, 7\n", sng.speed()));
	append( "arp1 = *\n");
	tablen = getHighestUsed(sng.wave1Table) + 1;
	hexdump(sng.wave1Table[0 .. tablen], 16);
	append( "arp2 = *\n");
	hexdump(sng.wave2Table[0 .. tablen], 16);
	append( "filttab = *\n");
	hexdump(sng.filterTable[0 .. getHighestUsed(sng.filterTable) + 3], 3);
	append( "pulstab = *\n");
	hexdump(sng.pulseTable[0 .. getHighestUsed(sng.pulseTable) + 3], 3);
	append( "inst = *\n");
	ubyte[512] instab = 0;
	// FIX: find out which instrs are in use
//	hexdump(sng.instrumentTable[0 .. (getHighestUsed(sng.instrumentTable[0..256]) | 8) + 1], 8);
//	hexdump(sng.instrumentTable[0 .. 48*8], 16);
	for(int i = 0; i < 8; i++) {
		append( format("\ninst%d = *\n",i));
		hexdump(sng.instrumentTable[i * 48 .. i * 48 + 48], 16);
	}


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

	tablen = getHighestUsed(sng.superTable[0..64]) + 1;
	append( "\ncmd1 = *\n");
	hexdump(sng.superTable[0..tablen], 16);
	append( "cmd2 = *\n");
	hexdump(sng.superTable[64..64+tablen], 16);
	append( "cmd3 = *\n");
	hexdump(sng.superTable[128..128+tablen], 16);

	/+
	int toffset;
	ubyte[] tracks;

	toffset = sng.offsets[Offsets.Track1];
	tracks = sng.memspace[toffset .. toffset + 512];
	tablen = sng.getTracklistLength(0);
	append( "track1 = *\n");
	hexdump(tracks[0..tablen], 16);

	toffset = sng.offsets[Offsets.Track2];
	tracks = sng.memspace[toffset .. toffset + 512];
	tablen = sng.getTracklistLength(1);
	append( "track2 = *\n");
	hexdump(tracks[0..tablen], 16);

	toffset = sng.offsets[Offsets.Track3];
	tracks = sng.memspace[toffset .. toffset + 512];
	tablen = sng.getTracklistLength(2);
	append( "track3 = *\n");
	hexdump(tracks[0..tablen], 16);

	+/

	append( "track1 = *\n");
	hexdump(sng.tracks[0].compact(), 16);
	append( "track2 = *\n");
	hexdump(sng.tracks[1].compact(), 16);
	append( "track3 = *\n");
	hexdump(sng.tracks[2].compact(), 16);


	for(int i = 0; i < sng.numOfSeqs(); i++) {
		append( format("s%02x = *\n", i));
		Sequence s = sng.seqs[i];
		hexdump(s.compact(), 16);
	}

	tablen = getHighestUsed(sng.chordTable) + 1;
	append("\nchord");
	hexdump(sng.chordTable[0..tablen], 16);
	append("\nchordindex");
	hexdump(sng.chordIndexTable[0..16], 16);

	return output;
}
