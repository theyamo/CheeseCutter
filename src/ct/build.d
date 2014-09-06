module ct.build;
import ct.base;
import ct.dump;
import com.cpu;
import com.util;
import std.stdio;
import std.string;
import std.file;
import std.conv;
import std.c.string;
import std.c.stdlib;

extern(C) {
	extern char* acme_assemble(const char*,int*,char*);
}

static const string playerCode = import("player_v4_export.acme");
static const auto SIDDriver = cast(ubyte[])import("custplay.bin");

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


ubyte[] generatePSIDFile(Song insong, ubyte[] data, int relocTo, int defaultSubtune, bool verbose) {
	int custBase, custInit, custPlay, custTimerlo, custTimerhi;
	/+ SID default tune indicatior starts from value 1... +/
	if(defaultSubtune > insong.subtunes.numOf)
		throw new UserException(format("This song only has %d subtunes", insong.subtunes.numOf));
	if(insong.multiplier > 1) {
		ubyte[] custplay = SIDDriver.dup; 
		int clock = PAL_CLOCK / insong.multiplier;
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
	char[32] title = insong.title; title[paddedStringLength(title,' ') .. $] = '\0';
	char[32] author = insong.author; author[paddedStringLength(author,' ') .. $] = '\0';
	char[32] release = insong.release; release[paddedStringLength(release,' ') .. $] = '\0';
	outstr(title,PSID_TITLE_OFFSET);
	outstr(author,PSID_TITLE_OFFSET + 0x20);
	outstr(release,PSID_TITLE_OFFSET + 0x40); 
	data[PSID_NUM_SONGS + 1] = cast(ubyte)insong.subtunes.numOf();
	data[PSID_START_SONG + 1] = cast(ubyte)defaultSubtune;
	if(insong.multiplier > 1) {
		if(relocTo != 0x1000) throw new UserException("Relocating multispeed tunes not supported.");
		// mask speed bits to use custom cia
		data[PSID_SPEED_OFFSET .. PSID_SPEED_OFFSET + 4] = 255;
		data[PSID_INIT_OFFSET .. PSID_INIT_OFFSET + 2] = cast(ubyte[])[ custInit >> 8, custInit & 255 ];
		data[PSID_PLAY_OFFSET .. PSID_PLAY_OFFSET + 2] = cast(ubyte[])[ custPlay >> 8, custPlay & 255 ];
		data[PSID_DATA_START + 2 + custTimerlo - custBase] = cast(ubyte)((PAL_CLOCK / insong.multiplier) & 255);
		data[PSID_DATA_START + 2 + custTimerhi - custBase] = cast(ubyte)((PAL_CLOCK / insong.multiplier) >> 8);
		data[PSID_DATA_START + 2 + custPlay - custBase + 5] = cast(ubyte)(insong.multiplier - 1);
	}
	else {
		data[PSID_INIT_OFFSET .. PSID_INIT_OFFSET + 2] = cast(ubyte[])[ relocTo >> 8, relocTo & 255 ];
		data[PSID_PLAY_OFFSET .. PSID_PLAY_OFFSET + 2] = cast(ubyte[])[ (relocTo + 3) >> 8, (relocTo + 3) & 255 ];
		int endAddr = cast(int)(relocTo + data.length);
		if(endAddr > 0xfff9) throw new UserException(format("The relocated tune goes past $fff9 (by $%x bytes).",endAddr-0xfff9));
	}
	data[PSID_FLAGS_OFFSET + 1] 
		= cast(ubyte)(0x04 /+ PAL +/ | (insong.sidModel ? 0x20 : 0x10));

	return data;
}

private char[] assemble(string source) {
	int length;
	char error_message[1024];
	memset(&error_message, '\0', 1024);
	char* input = acme_assemble(toStringz(source), &length, &error_message[0]);
	
	if(input is null) {
		string msg = to!string(&error_message[0]);
		throw new Error(format("Could not assemble player. Message:\n%s", msg));
	}
	char[] output = new char[length];
	memcpy(output.ptr, input, length);
	free(input);
	return output;
}


ubyte[] doBuild(Song song) {
	string input = playerCode;
	input ~= dumpData(song, "");
	writeln("Assembling...");
	int maxInsno;
	song.seqIterator((Sequence s, Element e) { 
			int insval = e.instr.value;
			if(insval > 0x2f) return;
			if(insval > maxInsno) maxInsno = insval; });
	input = setArgumentValue("INSNO", format("%d", maxInsno+1), input);
	bool chordUsed, swingUsed, filterUsed, vibratoUsed, setAttUsed, setDecUsed, setSusUsed, setRelUsed, setVolUsed, setSpeedUsed, offsetUsed;
	bool slideUpUsed, slideDnUsed, lovibUsed, portaUsed, setADSRUsed;
	
	song.seqIterator((Sequence s, Element e) { 
			int val = e.cmd.value;
			int cmdval = -1;
			if(val == 0) return;
			if(val < 0x40) {
				cmdval = song.superTable[val];
				if(cmdval < 1)
					slideUpUsed = true;
				else if(cmdval == 1)
					slideDnUsed = true;
				else if(cmdval == 2)
					vibratoUsed = true;
				else if(cmdval == 3)
					offsetUsed = true;
				else if(cmdval == 4)
					lovibUsed = true;
				else if(cmdval == 5)
					setADSRUsed = true;
				else if(cmdval == 7)
					portaUsed = true;
				return;
			}
			else if(val < 0x60)
				return;
			else if(val < 0x80)
				return;
			else if(val < 0xa0)
				chordUsed = true;
			else if(val < 0xb0)
				setAttUsed = true;
			else if(val < 0xc0)
				setDecUsed = true;
			else if(val < 0xd0)
				setSusUsed = true;
			else if(val < 0xe0)
				setRelUsed = true;
			else if(val < 0xf0)
				setVolUsed = true;
			else setSpeedUsed = true;
		});
	input = setArgumentValue("INCLUDE_CMD_SLUP", slideUpUsed ? "TRUE" : "FALSE", input);
	input = setArgumentValue("INCLUDE_CMD_SLDOWN", slideDnUsed ? "TRUE" : "FALSE", input);
	input = setArgumentValue("INCLUDE_CMD_VIBR", vibratoUsed ? "TRUE" : "FALSE", input);
	input = setArgumentValue("INCLUDE_CMD_PORTA", portaUsed ? "TRUE" : "FALSE", input);
	input = setArgumentValue("INCLUDE_CMD_SET_ADSR", setADSRUsed ? "TRUE" : "FALSE", input);
	input = setArgumentValue("INCLUDE_SEQ_SET_CHORD", chordUsed ? "TRUE" : "FALSE", input);
	input = setArgumentValue("INCLUDE_CHORD", chordUsed ? "TRUE" : "FALSE", input);
	input = setArgumentValue("INCLUDE_CMD_SET_OFFSET", offsetUsed ? "TRUE" : "FALSE", input);
	input = setArgumentValue("INCLUDE_CMD_SET_LOVIB", lovibUsed ? "TRUE" : "FALSE", input);
	input = setArgumentValue("INCLUDE_SEQ_SET_ATT", setAttUsed ? "TRUE" : "FALSE", input);
	input = setArgumentValue("INCLUDE_SEQ_SET_DEC", setDecUsed ? "TRUE" : "FALSE", input);
	input = setArgumentValue("INCLUDE_SEQ_SET_SUS", setSusUsed ? "TRUE" : "FALSE", input);
	input = setArgumentValue("INCLUDE_SEQ_SET_REL", setRelUsed ? "TRUE" : "FALSE", input);
	input = setArgumentValue("INCLUDE_SEQ_SET_VOL", setVolUsed ? "TRUE" : "FALSE", input);
	input = setArgumentValue("INCLUDE_SEQ_SET_SPEED", setSpeedUsed ? "TRUE" : "FALSE", input);
	writeln(input);
	ubyte[] output = cast(ubyte[])assemble(input);
	writeln(format("Size %d bytes.", output.length));
	return generatePSIDFile(song, output, 0x1000, 1, true);
}

// quick and ugly hack to circumvent D2 phobos weirdness
int paddedStringLength(char[] s, char padchar) {
	int i;
	for(i = cast(int)(s.length - 1); i >= 0; i--) {
		if(s[i] != padchar) return cast(int)(i+1);
	}
	return 0;
}
