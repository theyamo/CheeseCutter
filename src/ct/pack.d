module ct.pack;
import ct.base;
import com.cpu;
import std.stdio;
import std.string;

const ubyte[] SIDHEADER = [
  0x50, 0x53, 0x49, 0x44, 0x00, 0x02, 0x00, 0x7c, 0x00, 0x00, 0x10, 0x00,
  0x10, 0x03, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x53, 0x77,
  0x61, 0x6d, 0x70, 0x20, 0x50, 0x6f, 0x6f, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x54, 0x68, 0x6f, 0x6d, 0x61, 0x73,
  0x20, 0x4d, 0x6f, 0x67, 0x65, 0x6e, 0x73, 0x65, 0x6e, 0x20, 0x28, 0x44,
  0x52, 0x41, 0x58, 0x29, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x32, 0x30, 0x30, 0x34, 0x20, 0x4d, 0x61, 0x6e, 0x69, 0x61,
  0x63, 0x73, 0x20, 0x6f, 0x66, 0x20, 0x4e, 0x6f, 0x69, 0x73, 0x65, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x14,
  0x00, 0x00, 0x00, 0x00 
];

enum {
	PSID_LOAD_ADDR_OFFSET = 0x08,
	PSID_INIT_OFFSET = 0x0a,
	PSID_PLAY_OFFSET = 0x0c,
	PSID_TITLE_OFFSET = 0x16,
	PSID_FLAGS_OFFSET = 0x76,
	PSID_NUM_SONGS = 0x0e,
	PSID_START_SONG = 0x10,
	PSID_SPEED_OFFSET = 0x12,
//	CIA_OFFSET = 0x09,
//	DIV_COUNTER = 0x1b,
	PAL_CLOCK = 0x4cc7,
	PSID_DATA_START = 0x7c 
}


void hexdump(ubyte[] buf, int rowlen) {
	int c;
	foreach(b; buf) {
		writef("%02X ", b);
		c++;
		if(c >= rowlen) {
			c = 0;
			writef("\n");
		}
	}
	writef("\n");
}

// quick and ugly hack to circumvent D2 phobos weirdness
int paddedStringLength(char[] s, char padchar) {
	int i;
	for(i = cast(int)(s.length - 1); i >= 0; i--) {
		if(s[i] != padchar) return cast(int)(i+1);
	}
	return 0;
}
	
	

static const auto SIDDriver = cast(ubyte[])import("custplay.bin");

private class DataRelocator : CPU {
	address exec;
	address relocUpto;
	address relocFrom, relocTo;

	this(ubyte[] mem) {
		super(mem);
	}

	void relocate(address ex, address from, address to, address upto) {
		exec = ex; relocFrom = from; relocTo = to; relocUpto = upto;
		reset();
		execute(ex, false);
	}

	override void handleBreak() {
		return;
	}

	protected void rewriteAddress(ubyte[] chunk) {
		address addr = toAddress(chunk[1..$]);
		if(addr < relocFrom || (relocUpto > 0 && addr >= relocUpto)) return;
		if(chunk[2] >= 0xd0 && chunk[2] < 0xe0) return;
		address baseOld = relocFrom, baseNew = relocTo;
		int oldHi = baseOld; 
		int newBaseHi = baseNew;
		int delta = newBaseHi - oldHi;
		int newaddr = chunk[2] * 256 + delta + chunk[1];
		
		chunk[1] = lowbyte(cast(ushort)newaddr);
		chunk[2] = highbyte(cast(ushort)newaddr);
	}

	override ushort fetch(State st) {
		ushort arg = cast(ushort)st.arg;
		switch(st.addrmode) {
		case Am.ABSOLUTE:
			rewriteAddress(st.chunk);
			return memory[arg];
	    case Am.ABSOLUTE_X:
			rewriteAddress(st.chunk);
			return memory[(arg + regs.x) & 65535];
	    case Am.ZY, Am.ABSOLUTE_Y:
			rewriteAddress(st.chunk);
			return memory[(arg + regs.y) & 65535];
		case Am.RELATIVE:
			return cast(ushort)(regs.pc + 2);
		default:
			return super.fetch(st);
		}
	}	

	override void executeOp(ref State stat) {
		switch(stat.opcode) {
		case Op.JMP:
			regs.pc += 3;
			break;
		case Op.RTS:
			regs.pc += 1;
			break;
		default:
			super.executeOp(stat);
		}
	}
}

					   
private void explain(string s) {
	if(beVerbose) writefln(s);
}

private Song sng;
private DataRelocator relocator;
private bool beVerbose = false;

ubyte[] pack(Song insong, address relocTo, bool verbose) {
	sng = insong;
	memspace = sng.memspace.dup;
	if(relocator is null)
		relocator = new DataRelocator(memspace);

	beVerbose = verbose;
	ubyte[] data = packSongdata(relocTo);
	data = cast(ubyte[])toArr(relocTo) ~ data;
	
	return data;
}



/** PSID TODO:
	- handle NTSC files
	- handle speeds & voiceflags set from commandline
	- handle SID filter revision
   maybe:
    - optimize freqtable
*/

ubyte[] packToSid(Song insong, address relocTo, int defaultSubtune, bool verbose) {
	ubyte[] data = pack(insong, relocTo, verbose);
	int custBase, custInit, custPlay, custTimerlo, custTimerhi;
	/+ SID default tune indicatior starts from value 1... +/
	if(defaultSubtune > sng.subtunes.numOf)
		throw new Error(format("This song only has %d subtunes", sng.subtunes.numOf));
	if(sng.multiplier > 1) {
		ubyte[] custplay = SIDDriver.dup; 
		int clock = PAL_CLOCK / sng.multiplier;
		custBase = toAddress([custplay[0], custplay[1]]) + 6;
		custInit = custBase + custplay[2 + 3] - 4;
		custPlay = custBase + custplay[2 + 2] - 4;
		custTimerlo = custBase + custplay[2 + 0] - 4;
		custTimerhi = custBase + custplay[2 + 1] - 4;
		custplay = [lowbyte(cast(ushort)custBase), highbyte(cast(ushort)custBase)] ~ custplay[6 .. $];
		data = custplay ~ data[0 .. $];
	}
	data = SIDHEADER ~ data;
	void outstr(char[] s, int offset) {
		data[offset .. offset + s.length] = cast(ubyte[])s;
	}
	data[PSID_TITLE_OFFSET .. PSID_TITLE_OFFSET + 0x20] = '\0';
	data[PSID_TITLE_OFFSET + 0x20 .. PSID_TITLE_OFFSET + 0x40] = '\0';
	data[PSID_TITLE_OFFSET + 0x40 .. PSID_TITLE_OFFSET + 0x60] = '\0';

	// circumventing D2 phobos weirdness
	char[32] title = sng.title;	title[paddedStringLength(title,' ') .. $] = '\0';
	char[32] author = sng.author; author[paddedStringLength(author,' ') .. $] = '\0';
	char[32] release = sng.release; release[paddedStringLength(release,' ') .. $] = '\0';
	outstr(title,PSID_TITLE_OFFSET);
	outstr(author,PSID_TITLE_OFFSET + 0x20);
	outstr(release,PSID_TITLE_OFFSET + 0x40); 
	data[PSID_NUM_SONGS + 1] = cast(ubyte)sng.subtunes.numOf();
	data[PSID_START_SONG + 1] = cast(ubyte)defaultSubtune;
	if(sng.multiplier > 1) {
		if(relocTo != 0x1000) throw new Error("Relocating multispeed tunes not supported.");
		// mask speed bits to use custom cia
		data[PSID_SPEED_OFFSET .. PSID_SPEED_OFFSET + 4] = 255;
		data[PSID_INIT_OFFSET .. PSID_INIT_OFFSET + 2] = cast(ubyte[])[ custInit >> 8, custInit & 255 ];
		data[PSID_PLAY_OFFSET .. PSID_PLAY_OFFSET + 2] = cast(ubyte[])[ custPlay >> 8, custPlay & 255 ];
		data[PSID_DATA_START + 2 + custTimerlo - custBase] = cast(ubyte)((PAL_CLOCK / sng.multiplier) & 255);
		data[PSID_DATA_START + 2 + custTimerhi - custBase] = cast(ubyte)((PAL_CLOCK / sng.multiplier) >> 8);
		data[PSID_DATA_START + 2 + custPlay - custBase + 5] = cast(ubyte)(sng.multiplier - 1);
	}
	else {
		data[PSID_INIT_OFFSET .. PSID_INIT_OFFSET + 2] = cast(ubyte[])[ relocTo >> 8, relocTo & 255 ];
		data[PSID_PLAY_OFFSET .. PSID_PLAY_OFFSET + 2] = cast(ubyte[])[ (relocTo + 3) >> 8, (relocTo + 3) & 255 ];
		int endAddr = cast(int)(relocTo + data.length);
		if(endAddr > 0xfff9) throw new Error(format("The relocated tune goes past $fff9 (by $%x bytes).",endAddr-0xfff9));
	}
	data[PSID_FLAGS_OFFSET + 1] 
		= cast(ubyte)(0x04 /+ PAL +/ | (sng.sidModel ? 0x20 : 0x10));

	return data;
}

private:
	ubyte[] memspace;
	struct Songset {
		address[3] voices;
		ubyte speed, mask;
	}
	ubyte[][][] packedTracks;
	address[][] trackpointers;
	ubyte[][] packedSeqs;
	ubyte[] packedData;
	Songset[] songsets;
	address[] seqpointers;
	ubyte[] playerCode;
	address dataStart, dataOffset;
	address inputStart, inputOffset;
	address codeStart;
	int numOfSeqs;

/*
  NOTE: the packer assumes that the first jmp in the jumptable points
  to the lowest address in the player code. This is done so
  that players can place some data between the jump table and
  the player code. Placing data in the middle of the player code
  will crash the packer.

  FIX: the relocator must relocate the jump table separately.

  returns the packed song.
*/
ubyte[] packSongdata(address reloc) {
	numOfSeqs = sng.numOfSeqs();

	void output(ubyte[] data) {
		memspace[dataOffset .. dataOffset + data.length] = data;
		dataOffset += data.length;
	}

	// initialize packer
	// seek code end signature $fc, $3c

	int endsig = hunt(memspace[0x1000 .. 0x2000], [0xfc, 0x3c]);
	if(endsig < 0) {
		throw new Error("Could not determine player code end address."); 
	}
					  
	dataStart = cast(ushort)(0x1000 + endsig);
	dataOffset = dataStart;
	playerCode = memspace[0x1000 .. dataStart];
	codeStart = toAddress(memspace[0x1001 .. 0x1003]);
	inputOffset = sng.offsets[Offsets.Songsets];

	// pack seqs & tracks

	packedSeqs.length = numOfSeqs; 
	foreach(idx, seq; sng.seqs[0..numOfSeqs]) {
		packedSeqs[idx] = seq.compact();
	}

	sng.subtunes.activate(0);

	trackpointers.length = sng.subtunes.numOf();
	packedTracks = sng.subtunes.compact();
	ushort trkOffset;
	foreach(i, ref subtune; packedTracks) {
		trackpointers[i].length = 3;
		foreach(j, ref voice; subtune) {
			trackpointers[i][j] = trkOffset;
			trkOffset += voice.length;
		}
	}

	// generate seqpointers (data offset will be added later)

	seqpointers.length = numOfSeqs; 
	{
		ushort offset;
		foreach(idx, seq; packedSeqs) {
			seqpointers[idx] = offset;
			offset += seq.length;
		}
	}

	// generate songsets
		
	songsets.length = sng.subtunes.numOf;
	address trackDataStart = cast(ushort)(dataStart + songsets.length * Songset.sizeof);
	ushort trackDataOffset = trackDataStart;
	foreach(sidx, ref songset; songsets) {
		ubyte[][] subtuneTracks = packedTracks[sidx];
		foreach(vidx, ref voiceAddr; songset.voices) {
			voiceAddr = trackDataOffset;
			trackDataOffset += subtuneTracks[vidx].length;
		}
		songset.speed = sng.songspeeds[sidx];
		songset.mask = 7;
	}

	// output songsets & tracks

	foreach(songset; songsets) {
		foreach(idx, voiceAddr; songset.voices) {
			output(addr2arr(cast(ushort)(voiceAddr + reloc - 0x1000)));
		}
		output([songset.speed, songset.mask]);
	}
	foreach(subtune; packedTracks) {
		foreach(voice; subtune) {
			output(voice);
		}
	}

	inputOffset += sng.tSongsets.length;
	relocator.relocate(codeStart, sng.offsets[Offsets.Songsets], dataStart,
					   inputOffset);

	// pack & output instrument table
	
	int maxInsno;
	sng.seqIterator((Sequence s, Element e) { 
			int insval = e.instr.value;
			if(insval > 0x2f) return;
			if(insval > maxInsno) maxInsno = insval; });
	ubyte[] packedInstable;

	maxInsno += 1;
	packedInstable.length = maxInsno * 8;

	for(int j = 0; j < maxInsno; j++) {
		for(int i = 0; i < 8; i++) {
			packedInstable[i * maxInsno + j] = sng.tInstr.data[i * 48 + j];
		}
	}
	for(ushort i = 0; i < 8; i++) {
		relocator.relocate(codeStart, cast(ushort)(sng.tInstr.offset + 48 * i), cast(ushort)(dataOffset + maxInsno * i), cast(ushort)( sng.tInstr.offset + 48 * i + 1));
	}
	output(packedInstable.dup);

	// pack & output cmdtable

	int maxCmdno;
	sng.seqIterator((Sequence s, Element e) { 
			int cmdval = e.cmd.value;
			if(cmdval > 63) return;
			if(cmdval > maxCmdno) maxCmdno = cmdval; });
	ubyte[] packedCmdtable;
	maxCmdno += 1;
	packedCmdtable.length = maxCmdno * 3;
	for(int j = 0; j < maxCmdno; j++) {
		for(int i = 0; i < 3; i++) {
			packedCmdtable[i * maxCmdno + j] = sng.tSuper.data[i * 64 + j];
		}
	}
	for(int i = 0; i < 3; i++) {
		relocator.relocate(codeStart, cast(ushort)(sng.tSuper.offset + 64 * i), cast(ushort)( dataOffset + maxCmdno * i), cast(ushort)( sng.tSuper.offset + 64 * i + 1));
	}
	output(packedCmdtable.dup);

	// pack tables

	inputOffset = sng.offsets[Offsets.Arp1];
	with(sng) {
		foreach(idx, table; [tPulse, tFilter, tWave1, tWave2, tChord, tChordIndex]) {
			inputOffset = cast(ushort)table.offset;
			relocator.relocate(codeStart, inputOffset, dataOffset, cast(ushort)(inputOffset + table.length));
			output(table.data[0..table.size].dup);
			//inputOffset += table.length;
		}
	}

	// output seqpointers

	address seqdataStart = cast(address)(dataOffset + seqpointers.length * 2);
	address seqptraddrlo = dataOffset;
	address seqptraddrhi = cast(address)(dataOffset + seqpointers.length);

	foreach(idx, ptr; seqpointers) {
		ptr += seqdataStart + reloc - 0x1000;
		memspace[seqptraddrlo] = lowbyte(ptr);
		memspace[seqptraddrhi] = highbyte(ptr);
		
		seqptraddrlo++;
		seqptraddrhi++;
	}

	// relocate seqlos

	inputOffset = sng.offsets[Offsets.SeqLO];
	assert(inputOffset == sng.offsets[Offsets.SeqLO]);
	relocator.relocate(codeStart, sng.offsets[Offsets.SeqLO], dataOffset, cast(ushort)(inputOffset + 128));

	dataOffset += cast(ushort) seqpointers.length;

	// relocate seqhis

	inputOffset = sng.offsets[Offsets.SeqHI];
	assert(inputOffset == sng.offsets[Offsets.SeqHI]);
	relocator.relocate(codeStart, sng.offsets[Offsets.SeqHI], dataOffset, cast(ushort)(inputOffset + 128));

	dataOffset += cast(ushort)seqpointers.length;
	assert(dataOffset == seqdataStart);
	inputOffset = sng.offsets[Offsets.S00];

	// output seqs

	foreach(seq; packedSeqs) {
		output(seq);
		inputOffset += cast(ushort)256; // each full seq
	}

	// finalize

	if(sng.ver >= 6) {
		memspace[sng.offsets[Offsets.Editorflag]] = 1;
	}

	// relocate 

	{
		// relocate code
		ushort dataEnd = dataOffset;
		relocator.relocate(cast(ushort)(0x1000 /+ code start +/), cast(ushort)0x1000, reloc, dataEnd);

	}
	explain(format("Packed data length is $%x bytes", dataOffset - 0x1000));

	return cast(ubyte[])memspace[0x1000 .. dataOffset];
}

private int hunt(ubyte[] arr, ubyte[] cmp) {
	for(int i = 0; i < arr.length - 1; i++) {
		if(arr[i .. i + cmp.length] == cmp)
			return i;
	}
	return -1;
}

