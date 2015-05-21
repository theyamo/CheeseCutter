/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module ct.build;
import ct.base;
import ct.dump;
import com.cpu;
import com.util;
import std.stdio;
import std.string;
import std.conv;
import std.c.string;
import std.c.stdlib;

extern(C) {
	extern char* acme_assemble(const char*,int*,char*);
}

static const string playerSource = import("player_v4.acme");

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

// quick and ugly hack to circumvent D2 phobos weirdness
private int paddedStringLength(char[] s, char padchar) {
	int i;
	for(i = cast(int)(s.length - 1); i >= 0; i--) {
		if(s[i] != padchar) return cast(int)(i+1);
	}
	return 0;
}

private char[] assemble(string source) {
	int length;
	char error_message[1024];
	memset(&error_message, '\0', 1024);
	char* input = acme_assemble(toStringz(source), &length, &error_message[0]);
	
	if(input is null) {
		string msg = to!string(&error_message[0]);
		throw new UserException(format("Could not assemble player. Message:\n%s", msg));
	}
	char[] assembled = new char[length];
	memcpy(assembled.ptr, input, length);
	free(input);
	return assembled;
}

private ubyte[] generatePSIDHeader(Song insong, ubyte[] data, int initAddress,
								   int playAddress, int defaultSubtune) {
	/+ SID default tune indicatior starts from value 1... +/
	if(defaultSubtune > insong.subtunes.numOf)
		throw new UserException(format("This song has only %d subtunes", insong.subtunes.numOf));
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
	data[PSID_NUM_SONGS + 1] = cast(ubyte)insong.subtunes.numOf;
	data[PSID_START_SONG + 1] = cast(ubyte)defaultSubtune;
	if(insong.multiplier > 1) {
		data[PSID_SPEED_OFFSET .. PSID_SPEED_OFFSET + 4] = 255;
	}
	data[PSID_INIT_OFFSET .. PSID_INIT_OFFSET + 2] = cast(ubyte[])[ initAddress >> 8, initAddress & 255 ];
	data[PSID_PLAY_OFFSET .. PSID_PLAY_OFFSET + 2] = cast(ubyte[])[ playAddress >> 8, playAddress & 255 ];
	int endAddr = cast(int)(initAddress + data.length);
	if(endAddr > 0xfff9)
		throw new UserException(format("The relocated tune goes past $fff9 (by $%x bytes).",endAddr-0xfff9));
	
	data[PSID_FLAGS_OFFSET + 1] 
		= cast(ubyte)(0x04 /+ PAL +/ | (insong.sidModel ? 0x20 : 0x10));

	return data;
}

ubyte[] doBuild(Song song, int address, bool genPSID,
				int defaultSubtune, bool verbose) {
	// Valid range for subtunes is 1 - 32.
	if(!(defaultSubtune >= 1 && defaultSubtune <= ct.base.SUBTUNE_MAX))
		throw new UserException(format("Valid range for subtunes is 1 - %d.", ct.base.SUBTUNE_MAX));

	// Dump data to asm source
	string input = dumpOptimized(song, address, genPSID, verbose);

	if(verbose)
		writeln("Assembling...");

	ubyte[] assembled = cast(ubyte[])assemble(input);
	
	if(verbose)
		writeln(format("Size %d bytes ($%04x-$%04x).", assembled.length - 2,
					   address, address + assembled.length - 2));

	return genPSID ? generatePSIDHeader(song, assembled, address, address + 3,
										defaultSubtune) : assembled;
}

string dumpOptimized(Song song, int address, bool genPSID, bool verbose) {
	string input = playerSource;
	input ~= dumpData(song);
	input = setArgumentValue("INSNO", format("%d", song.numInstr+1), input);
	char[] linkedPlayerID = (new Song()).playerID;
	if(song.playerID[0..6] != linkedPlayerID[0..6] && verbose) {
		writeln("Warning: your song uses an old version of the player!\n",
				"The assembled song may sound different.\nSong player: ",
				to!string(song.playerID[0..6]), ", linked player: ",
				to!string(linkedPlayerID[0..6]));
	}
	
	bool chordUsed, swingUsed, filterUsed, vibratoUsed;
	bool setAttUsed, setDecUsed, setSusUsed, setRelUsed, setVolUsed, setSpeedUsed;
	bool offsetUsed, slideUpUsed, slideDnUsed, lovibUsed, portaUsed, setADSRUsed;
	
	song.seqIterator((Sequence s, Element e) { 
			int val = e.cmd.value;
			int cmdval = -1;
			if(val == 0) return;
			if(val < 0x40) {
				cmdval = song.superTable[val];
				if(cmdval < 1) slideUpUsed = true;
				else if(cmdval == 1)
					slideDnUsed = true;
				else if(cmdval == 2)
					vibratoUsed = true;
				else if(cmdval == 3)
					offsetUsed = true;
				else if(cmdval == 4)
					setADSRUsed = true;
				else if(cmdval == 5)
					lovibUsed = true;
				else if(cmdval == 7)
					portaUsed = true;
				return;
			}
			else if(val < 0x60)
				return;
			else if(val < 0x80)
				filterUsed = true;
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
			else {
				if(val == 0xf0 || val == 0xf1) swingUsed = true;
				setSpeedUsed = true;
			}
		});
	for(int i = 0; i < song.subtunes.numOf; i++) {
		if(song.songspeeds[i] < 2) swingUsed = true;
	}
	for(int i = 0; i < 48; i++) {
		if(song.filtertablePointer(i) > 0)
			filterUsed = true;
	}

	if(verbose) {
		string[] fxdescr =
			[ "slup", "sldn", "vib", "porta", "adsr",
			  "8x", "offset", "lovib", "Ax", "Bx", "Cx", "Dx",
			  "Ex", "Fx", "swing", "filter" ];
		auto fxused = std.array.appender!string();
		foreach(idx, used; [slideUpUsed, slideDnUsed, vibratoUsed, portaUsed,
							setADSRUsed, chordUsed, offsetUsed, lovibUsed,
							setAttUsed, setDecUsed, setSusUsed, setRelUsed,
							setVolUsed, setSpeedUsed, swingUsed, filterUsed]) {
			if(used)
				fxused.put(fxdescr[idx] ~ " ");
		}
		if(fxused.data.length > 0) {
			writeln("Effects used: " ~ fxused.data);
		}
	}
	
	void setArgVal(string arg, string val) {
		input = setArgumentValue(arg, val, input);
	}

	input = setArgumentValue("EXPORT", "TRUE", input);
	setArgVal("INCLUDE_CMD_SLUP", slideUpUsed ? "TRUE" : "FALSE");
	setArgVal("INCLUDE_CMD_SLDOWN", slideDnUsed ? "TRUE" : "FALSE");
	setArgVal("INCLUDE_CMD_VIBR", vibratoUsed ? "TRUE" : "FALSE");
	setArgVal("INCLUDE_CMD_PORTA", portaUsed ? "TRUE" : "FALSE");
	setArgVal("INCLUDE_CMD_SET_ADSR", setADSRUsed ? "TRUE" : "FALSE");
	setArgVal("INCLUDE_SEQ_SET_CHORD", chordUsed ? "TRUE" : "FALSE");
	setArgVal("INCLUDE_CHORD", chordUsed ? "TRUE" : "FALSE");
	setArgVal("INCLUDE_CMD_SET_OFFSET", offsetUsed ? "TRUE" : "FALSE");
	setArgVal("INCLUDE_CMD_SET_LOVIB", lovibUsed ? "TRUE" : "FALSE");
	setArgVal("INCLUDE_SEQ_SET_ATT", setAttUsed ? "TRUE" : "FALSE");
	setArgVal("INCLUDE_SEQ_SET_DEC", setDecUsed ? "TRUE" : "FALSE");
	setArgVal("INCLUDE_SEQ_SET_SUS", setSusUsed ? "TRUE" : "FALSE");
	setArgVal("INCLUDE_SEQ_SET_REL", setRelUsed ? "TRUE" : "FALSE");
	setArgVal("INCLUDE_SEQ_SET_VOL", setVolUsed ? "TRUE" : "FALSE");
	setArgVal("INCLUDE_SEQ_SET_SPEED", setSpeedUsed ? "TRUE" : "FALSE");
	setArgVal("INCLUDE_BREAKSPEED", swingUsed ? "TRUE" : "FALSE");
	setArgVal("INCLUDE_FILTER", filterUsed ? "TRUE" : "FALSE");
	setArgVal("MULTISPEED", song.multiplier > 1 ? "TRUE" : "FALSE");
	if(song.multiplier > 1) {
		setArgVal("USE_MDRIVER", genPSID ? "TRUE" : "FALSE");
		setArgVal("CIA_VALUE",
				  format("$%04x", PAL_CLOCK / song.multiplier));
		setArgVal("MULTIPLIER", format("%d", song.multiplier - 1));
	}
	setArgVal("BASEADDRESS", format("$%04x", address), );

	return input;
}
